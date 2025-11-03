import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker/leak_tracker.dart';
import 'package:listen_it/listen_it.dart';
import 'package:listen_it/src/functional_value_notifiers.dart';

/// Chain Memory and Garbage Collection Tests
///
/// These tests verify memory management behavior of FunctionalValueNotifier chains.
///
/// ## Understanding Circular References and GC
///
/// Chains create a circular reference:
/// - source.listeners → internalHandler (closure) → chain → previousInChain → source
///
/// Modern GC (including Dart's) uses **reachability** from GC roots (stack, static vars, etc.),
/// not reference counting. If an entire cycle is unreachable from any root, it gets collected.
///
/// ## Key Findings:
///
/// 1. **Circular references are collected when unreachable from GC roots**
///    - When nothing external points into the cycle (no reference from stack, get_it, etc.),
///      Dart's GC collects the entire cycle despite internal circular references
///    - The circular reference only "leaks" if something external keeps any part reachable
///
/// 2. **Active listeners don't prevent GC of unreachable cycles**
///    - Even with listeners attached to a chain, if the entire cycle becomes unreachable
///      from GC roots, everything gets collected
///    - Listeners are part of the object graph and go with it when unreachable
///
/// 3. **Chains require explicit disposal when source stays reachable**
///    - When source is kept alive from a GC root (e.g., registered in get_it),
///      chains stay registered as listeners until explicitly disposed
///    - This is normal listener behavior - users must call dispose() on chains,
///      just like they dispose controllers, streams, or any other resource
///
/// ## GC Testing:
///
/// These tests use leak_tracker's forceGC() to reliably trigger garbage
/// collection during tests.

// Service class that owns BOTH source and chain (realistic scenario)
class ServiceWithChain {
  final source = ValueNotifier<int>(0);
  late final ValueListenable<int> chain;

  ServiceWithChain() {
    chain = source.map((x) => x * 2);
  }

  // This dispose method is intentionally not called in tests - it demonstrates
  // what users would do in real code when the source stays alive (e.g., in get_it).
  // The tests prove that dispose is NOT needed when the entire object becomes unreachable.
  // ignore: unreachable_from_main
  void dispose() {
    if (chain is FunctionalValueNotifier) {
      (chain as FunctionalValueNotifier).dispose();
    }
    source.dispose();
  }
}

void main() {
  group('Memory and Garbage Collection Tests', () {
    test(
        "service with source and chain - circular reference CAN be GC'd when unreachable from roots",
        () async {
      // This test proves a critical point about GC behavior:
      // Even though chains create circular references, Dart's GC collects them
      // when the entire cycle becomes unreachable from GC roots.
      ServiceWithChain? service = ServiceWithChain();
      final sourceWeakRef = WeakReference(service.source);
      final chainWeakRef = WeakReference(service.chain);

      // Add a listener to trigger lazy initialization
      service.chain.addListener(() {});

      // Verify it works
      service.source.value = 5;
      expect(service.chain.value, 10);

      // Set service to null - now NOTHING from GC roots points into the cycle
      // The circular reference (source -> chain -> source) still exists,
      // but it's an unreachable island in the object graph
      service = null;

      // Force garbage collection
      await forceGC();

      // Wait a bit after GC to ensure it completed
      await Future.delayed(const Duration(milliseconds: 100));

      // Both are collected! Dart's GC traces reachability from roots,
      // not just reference counts. Unreachable cycles get collected.
      expect(
        sourceWeakRef.target,
        isNull,
        reason:
            "Circular reference was GC'd because unreachable from any GC root",
      );
      expect(
        chainWeakRef.target,
        isNull,
        reason:
            "Circular reference was GC'd because unreachable from any GC root",
      );

      // Key takeaway: Circular references only "leak" if something external
      // (from a GC root) keeps any part of the cycle reachable.
    });

    test(
        "service with source and chain WITH active listener - still GC'd when unreachable!",
        () async {
      // Test variation: add a listener to the chain and DON'T remove it.
      // Does an active listener change GC behavior?
      ServiceWithChain? service = ServiceWithChain();
      final sourceWeakRef = WeakReference(service.source);
      final chainWeakRef = WeakReference(service.chain);

      // Add a listener to the chain
      var listenerCallCount = 0;
      void listener() {
        listenerCallCount++;
      }

      service.chain.addListener(listener);

      // Verify it works
      service.source.value = 5;
      expect(service.chain.value, 10);
      expect(listenerCallCount, 1);

      // DON'T remove the listener - just set service to null
      // Now the cycle includes: source -> chain -> listeners (including our listener function)
      // But still, nothing from GC roots points into this cycle
      service = null;

      // Force garbage collection
      await forceGC();

      // Wait a bit after GC to ensure it completed
      await Future.delayed(const Duration(milliseconds: 100));

      // Result: Both are STILL GC'd! The listener function is part of the
      // unreachable object graph. When the cycle is unreachable from GC roots,
      // everything in it (including listeners) gets collected together.
      expect(
        sourceWeakRef.target,
        isNull,
        reason:
            'Even with active listener, GC collected when unreachable from roots',
      );
      expect(
        chainWeakRef.target,
        isNull,
        reason:
            'Even with active listener, GC collected when unreachable from roots',
      );

      // This confirms: Active listeners are part of the object graph.
      // They don't prevent GC when the entire cycle is unreachable from roots.
      //
      // The important point: when source IS reachable (from get_it, etc.),
      // users must dispose chains explicitly, just like any other resource.
    });
  });
}
