import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listen_it/listen_it.dart';
import 'package:listen_it/src/functional_value_notifiers.dart';
import 'package:watch_it/watch_it.dart';

/// Chain Lifecycle Tests
///
/// These tests verify critical behaviors of FunctionalValueNotifier chains:
///
/// ## Key Findings:
///
/// 1. **Constructors are called only once**
///    - Chain objects are created when the expression is evaluated
///    - They are NOT recreated on each event
///    - Same objects process all events throughout their lifetime
///
/// 2. **Chains are "hot" (eager), not "cold" (lazy)**
///    - Most operators call init() in their constructor
///    - Chains subscribe to their sources immediately upon creation
///    - This happens BEFORE any listener is added
///    - Chains stay subscribed even when they have zero listeners
///
/// 3. **Resubscription works correctly**
///    - You can remove all listeners and add new ones later
///    - The chain continues to track its source the whole time
///    - This was the reason for choosing hot subscription over lazy
///
/// 4. **Memory management considerations**
///    - Chains without dispose() stay in memory and keep processing events
///    - Must call dispose() to unsubscribe from source and free memory
///    - Variable assignment vs immediate .listen() creates different chain objects
///    - But both behave identically in terms of lifecycle
///
/// 5. **ValueListenableBuilder integration**
///    - Works seamlessly with chain objects
///    - Chain identity remains stable across rebuilds
///    - Multiple builders can share the same chain
///    - Filtering operators correctly prevent unnecessary rebuilds
///
/// ## Architecture Notes:
///
/// The "hot" subscription model was chosen to avoid a previous bug where
/// chains would not re-subscribe after all listeners were removed. This
/// ensures reliable resubscription behavior at the cost of keeping chains
/// active even without listeners.

// Test subclasses that track constructor and handler calls
// Global counter for ALL TrackedMapValueNotifier instances created
int _totalMapChainsCreated = 0;

class TrackedMapValueNotifier<TIn, TOut> extends MapValueNotifier<TIn, TOut> {
  static int constructorCallCount = 0;
  int handlerCallCount = 0;

  TrackedMapValueNotifier(
    super.initialValue,
    super.previousInChain,
    super.transformation,
  ) {
    constructorCallCount++;
    _totalMapChainsCreated++; // Track total instances created
  }

  @override
  void init(ValueListenable<TIn> previousInChain) {
    internalHandler = () {
      handlerCallCount++;
      value = transformation(previousInChain.value);
    };
    setupChain();
  }

  static void resetCounters() {
    constructorCallCount = 0;
  }
}

class TrackedWhereValueNotifier<T> extends WhereValueNotifier<T> {
  static int constructorCallCount = 0;
  int handlerCallCount = 0;

  TrackedWhereValueNotifier(
    super.initialValue,
    super.previousInChain,
    super.selector,
  ) {
    constructorCallCount++;
  }

  @override
  void init(ValueListenable<T> previousInChain) {
    internalHandler = () {
      handlerCallCount++;
      if (selector(previousInChain.value)) {
        value = previousInChain.value;
      }
    };
    setupChain();
  }

  static void resetCounters() {
    constructorCallCount = 0;
  }
}

class TrackedSelectValueNotifier<TIn, TOut>
    extends SelectValueNotifier<TIn, TOut> {
  static int constructorCallCount = 0;
  int handlerCallCount = 0;

  TrackedSelectValueNotifier(
    super.initialValue,
    super.previousInChain,
    super.selector,
  ) {
    constructorCallCount++;
  }

  @override
  void init(ValueListenable<TIn> previousInChain) {
    internalHandler = () {
      handlerCallCount++;
      final selected = selector(previousInChain.value);
      if (selected != value) {
        value = selected;
      }
    };
    setupChain();
  }

  static void resetCounters() {
    constructorCallCount = 0;
  }
}

// Test widgets for watch_it integration

// Model class for registerHandler testing
class ChainModel extends ChangeNotifier {
  final ValueListenable<int> chain;
  ChainModel(this.chain);
}

// Using watchValue() to watch chain property from get_it
class _TestWatchValueWidget extends WatchingWidget {
  final void Function(int identity, int value) onBuild;

  const _TestWatchValueWidget({required this.onBuild});

  @override
  Widget build(BuildContext context) {
    // watchValue automatically gets ChainModel from get_it
    // We need to get the chain identity too, so access the model explicitly
    final model = watchIt<ChainModel>();
    final chainIdentity = identityHashCode(model.chain);

    // watchValue gets the value from the chain
    final value = watchValue((ChainModel m) => m.chain);

    onBuild(chainIdentity, value);
    return Text('Value: $value');
  }
}

class _TestInlineChainWidget extends WatchingWidget {
  final void Function(int identity) onBuild;

  const _TestInlineChainWidget({required this.onBuild});

  @override
  Widget build(BuildContext context) {
    // Get source from get_it
    final source = watchIt<ValueNotifier<int>>();

    // ANTI-PATTERN: Create chain inline!
    final chain = source.map((x) => x * 2);
    onBuild(identityHashCode(chain));

    // Use the chain (this will be a different object each rebuild)
    return Text('Value: ${chain.value}');
  }
}

class _TestValueListenableBuilderInlineWidget extends StatefulWidget {
  final ValueNotifier<int> source;
  final void Function(int identity) onBuild;

  const _TestValueListenableBuilderInlineWidget({
    required this.source,
    required this.onBuild,
  });

  @override
  State<_TestValueListenableBuilderInlineWidget> createState() =>
      _TestValueListenableBuilderInlineWidgetState();
}

class _TestValueListenableBuilderInlineWidgetState
    extends State<_TestValueListenableBuilderInlineWidget> {
  @override
  void initState() {
    super.initState();
    // Listen to source to trigger rebuilds
    widget.source.addListener(_onSourceChanged);
  }

  @override
  void dispose() {
    widget.source.removeListener(_onSourceChanged);
    super.dispose();
  }

  void _onSourceChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Track identity of inline chain creation, then create it again inline
    widget.onBuild(identityHashCode(widget.source.map((x) => x * 2)));

    // ANTI-PATTERN: Creating chain inline in valueListenable parameter!
    return ValueListenableBuilder<int>(
      valueListenable: widget.source.map((x) => x * 2),
      builder: (context, value, child) {
        return Text('Value: $value');
      },
    );
  }
}

class _TestWatchValueInlineWidget extends WatchingWidget {
  final ValueNotifier<int> source;
  final void Function(int value) onBuild;
  final bool allowObservableChange;

  const _TestWatchValueInlineWidget({
    required this.source,
    required this.onBuild,
    this.allowObservableChange = false,
  });

  @override
  Widget build(BuildContext context) {
    // watchValue with chain created inline - uses TrackedMapValueNotifier to count instances
    final value = watchValue(
      (ChainModel m) => TrackedMapValueNotifier<int, int>(
        source.value * 2,
        source,
        (x) => x * 2,
      ),
      allowObservableChange: allowObservableChange,
    );
    onBuild(value);
    return Text('Value: $value');
  }
}

class _RegisterHandlerTestWidget extends WatchingWidget {
  final VoidCallback onBuild;
  final void Function(int value) onHandler;

  const _RegisterHandlerTestWidget({
    required this.onBuild,
    required this.onHandler,
  });

  @override
  Widget build(BuildContext context) {
    onBuild();
    registerHandler(
      select: (ChainModel model) => model.chain,
      handler: (context, value, cancel) {
        onHandler(value);
      },
    );
    return Text('Build: $hashCode');
  }
}

class _TestRegisterHandlerInlineWidget extends WatchingWidget {
  final ValueNotifier<int> source;
  final ValueNotifier<int> rebuildTrigger;
  final VoidCallback onBuild;
  final void Function(int value) onHandler;
  final bool allowObservableChange;

  const _TestRegisterHandlerInlineWidget({
    required this.source,
    required this.rebuildTrigger,
    required this.onBuild,
    required this.onHandler,
    this.allowObservableChange = false,
  });

  @override
  Widget build(BuildContext context) {
    // Watch rebuild trigger to force external rebuilds
    final rebuildCount = watchValue((ChainModel m) => rebuildTrigger);

    // Create chain inline using TrackedMapValueNotifier
    // registerHandler doesn't cause rebuilds, but if something else does
    // (like watchValue above), inline chains leak unless caching is enabled.
    onBuild();
    registerHandler(
      select: (ChainModel m) => TrackedMapValueNotifier<int, int>(
        source.value * 2,
        source,
        (x) => x * 2,
      ),
      handler: (context, value, cancel) {
        onHandler(value);
      },
      allowObservableChange: allowObservableChange,
    );
    return Text('Build: $rebuildCount');
  }
}

// Test controller class that holds chains
class TestController {
  final ValueNotifier<int> source;
  late final ValueListenable<String> chain;
  bool _disposed = false;

  TestController(this.source) {
    chain = source.where((x) => x.isEven).map((x) => 'Value: $x');
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (chain is FunctionalValueNotifier) {
      (chain as FunctionalValueNotifier).dispose();
    }
  }
}

void main() {
  group('Constructor Call Counting Tests', () {
    setUp(() {
      TrackedMapValueNotifier.resetCounters();
      TrackedWhereValueNotifier.resetCounters();
      TrackedSelectValueNotifier.resetCounters();
    });

    test('constructors are called only once when building chain', () {
      final source = ValueNotifier<int>(0);

      // Build chain manually with tracked notifiers
      final whereNotifier = TrackedWhereValueNotifier(
        source.value,
        source,
        (x) => x.isEven,
      );
      final mapNotifier = TrackedMapValueNotifier(
        'Value: ${whereNotifier.value}',
        whereNotifier,
        (x) => 'Value: $x',
      );
      final selectNotifier = TrackedSelectValueNotifier(
        mapNotifier.value.length,
        mapNotifier,
        (s) => s.length,
      );

      // Verify constructors called exactly once
      expect(TrackedWhereValueNotifier.constructorCallCount, 1);
      expect(TrackedMapValueNotifier.constructorCallCount, 1);
      expect(TrackedSelectValueNotifier.constructorCallCount, 1);

      // Add a listener
      selectNotifier.addListener(() {});

      // Constructor counts should remain the same
      expect(TrackedWhereValueNotifier.constructorCallCount, 1);
      expect(TrackedMapValueNotifier.constructorCallCount, 1);
      expect(TrackedSelectValueNotifier.constructorCallCount, 1);

      // Fire multiple events
      for (int i = 0; i < 10; i++) {
        source.value = i * 2; // Only even numbers
      }

      // Constructor counts should STILL be 1
      expect(TrackedWhereValueNotifier.constructorCallCount, 1);
      expect(TrackedMapValueNotifier.constructorCallCount, 1);
      expect(TrackedSelectValueNotifier.constructorCallCount, 1);

      // But handlers should have been called
      expect(whereNotifier.handlerCallCount, greaterThan(0));
      expect(mapNotifier.handlerCallCount, greaterThan(0));
      expect(selectNotifier.handlerCallCount, greaterThan(0));

      selectNotifier.dispose();
      mapNotifier.dispose();
      whereNotifier.dispose();
      source.dispose();
    });

    test('chain objects have stable identity across events', () {
      final source = ValueNotifier<int>(0);
      final chain = source.where((x) => x.isEven).map((x) => 'Value: $x');

      // Store the identity hash
      final chainIdentity = identityHashCode(chain);

      // Add listener
      final values = <String>[];
      chain.addListener(() => values.add(chain.value));

      // Fire multiple events
      source.value = 2;
      source.value = 4;
      source.value = 6;

      // Chain identity should remain the same
      expect(identityHashCode(chain), chainIdentity);
      expect(values, ['Value: 2', 'Value: 4', 'Value: 6']);

      if (chain is FunctionalValueNotifier) {
        (chain as FunctionalValueNotifier).dispose();
      }
      source.dispose();
    });
  });

  group('Variable Assignment vs Immediate Listen', () {
    test('variable assignment allows multiple listeners', () {
      final source = ValueNotifier<int>(0);
      final chain = source.map((x) => x * 2);

      final values1 = <int>[];
      final values2 = <int>[];

      // Add two listeners to the same chain
      chain.addListener(() => values1.add(chain.value));
      chain.addListener(() => values2.add(chain.value));

      source.value = 5;
      source.value = 10;

      // Both listeners receive the same values
      expect(values1, [10, 20]);
      expect(values2, [10, 20]);

      if (chain is FunctionalValueNotifier) {
        (chain as FunctionalValueNotifier).dispose();
      }
      source.dispose();
    });
  });

  group('Parent Object Disposal Tests', () {
    test('disposing chain unsubscribes from source', () {
      final source = ValueNotifier<int>(0);
      final controller = TestController(source);

      final values = <String>[];
      controller.chain.addListener(() => values.add(controller.chain.value));

      // Fire events before disposal
      source.value = 2;
      source.value = 4;
      expect(values, ['Value: 2', 'Value: 4']);

      // Dispose the chain
      controller.dispose();

      // Fire events after disposal - chain should not update
      values.clear();
      source.value = 6;
      source.value = 8;

      // Values list should remain empty (no notifications)
      expect(values, isEmpty);

      source.dispose();
    });

    test('chain stays subscribed even with zero listeners', () {
      final source = ValueNotifier<int>(0);
      final chain = source.map((x) => x * 2);

      // Add and then remove listener
      void listener() {}
      chain.addListener(listener);
      source.value = 5;
      expect(chain.value, 10);

      chain.removeListener(listener);

      // Chain still updates even with no listeners!
      source.value = 7;
      expect(chain.value, 14); // Chain still tracking source

      if (chain is FunctionalValueNotifier) {
        (chain as FunctionalValueNotifier).dispose();
      }
      source.dispose();
    });
  });

  group('Resubscription Tests', () {
    test('can add listener after removing all listeners', () {
      final source = ValueNotifier<int>(0);
      final chain = source.map((x) => x * 2);

      // First subscription
      final values1 = <int>[];
      void listener1() => values1.add(chain.value);
      chain.addListener(listener1);

      source.value = 5;
      expect(values1, [10]);

      // Remove listener
      chain.removeListener(listener1);

      // Add new listener (resubscribe)
      final values2 = <int>[];
      void listener2() => values2.add(chain.value);
      chain.addListener(listener2);

      source.value = 7;
      expect(values2, [14]); // Should work!

      if (chain is FunctionalValueNotifier) {
        (chain as FunctionalValueNotifier).dispose();
      }
      source.dispose();
    });
  });

  group('Chain Stays Hot Tests', () {
    test('intermediate chain nodes process events', () {
      final source = ValueNotifier<int>(0);
      final whereChain = source.where((x) => x.isEven);
      final mapChain = whereChain.map((x) => x * 2);

      // Add listener only to the end
      final values = <int>[];
      mapChain.addListener(() => values.add(mapChain.value));

      // Fire mixed events
      source.value = 1; // Filtered out
      source.value = 2; // Passes
      source.value = 3; // Filtered out
      source.value = 4; // Passes

      expect(values, [4, 8]);

      // Both intermediate nodes stayed hot
      expect(whereChain.value, 4); // Last even value
      expect(mapChain.value, 8); // Last even value * 2

      if (mapChain is FunctionalValueNotifier) {
        (mapChain as FunctionalValueNotifier).dispose();
      }
      if (whereChain is FunctionalValueNotifier) {
        (whereChain as FunctionalValueNotifier).dispose();
      }
      source.dispose();
    });
  });

  group('ValueListenableBuilder Integration Tests', () {
    testWidgets('chain objects remain stable with ValueListenableBuilder',
        (WidgetTester tester) async {
      final source = ValueNotifier<int>(0);
      final chain = source.where((x) => x.isEven).map((x) => 'Value: $x');

      final chainIdentity = identityHashCode(chain);
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: chain,
              builder: (context, value, child) {
                buildCount++;
                return Text(value);
              },
            ),
          ),
        ),
      );

      // Initial build
      expect(buildCount, 1);
      expect(find.text('Value: 0'), findsOneWidget);
      expect(identityHashCode(chain), chainIdentity);

      // Fire multiple events
      source.value = 2;
      await tester.pump();
      expect(buildCount, 2);
      expect(find.text('Value: 2'), findsOneWidget);
      expect(identityHashCode(chain), chainIdentity);

      source.value = 4;
      await tester.pump();
      expect(buildCount, 3);
      expect(find.text('Value: 4'), findsOneWidget);

      // Chain identity never changed
      expect(identityHashCode(chain), chainIdentity);

      if (chain is FunctionalValueNotifier) {
        (chain as FunctionalValueNotifier).dispose();
      }
      source.dispose();
    });

    testWidgets('chain with filter only rebuilds when condition passes',
        (WidgetTester tester) async {
      final source = ValueNotifier<int>(0);
      final chain = source.where((x) => x.isEven);

      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<int>(
              valueListenable: chain,
              builder: (context, value, child) {
                buildCount++;
                return Text('Value: $value');
              },
            ),
          ),
        ),
      );

      // Initial build
      expect(buildCount, 1);
      expect(find.text('Value: 0'), findsOneWidget);

      // Odd number - filtered out, no rebuild
      source.value = 1;
      await tester.pump();
      expect(buildCount, 1); // No rebuild!
      expect(find.text('Value: 0'), findsOneWidget); // Still shows 0

      // Even number - passes filter, rebuilds
      source.value = 2;
      await tester.pump();
      expect(buildCount, 2);
      expect(find.text('Value: 2'), findsOneWidget);

      // Another odd - no rebuild
      source.value = 3;
      await tester.pump();
      expect(buildCount, 2); // No rebuild!

      // Another even - rebuilds
      source.value = 4;
      await tester.pump();
      expect(buildCount, 3);
      expect(find.text('Value: 4'), findsOneWidget);

      if (chain is FunctionalValueNotifier) {
        (chain as FunctionalValueNotifier).dispose();
      }
      source.dispose();
    });

    testWidgets(
        'chain created INSIDE builder recreates on each rebuild (anti-pattern)',
        (WidgetTester tester) async {
      final source = ValueNotifier<int>(0);
      final chainIdentities = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<int>(
              valueListenable: source,
              builder: (context, value, child) {
                // ANTI-PATTERN: Creating chain inside builder!
                final chain = source.map((x) => x * 2);
                chainIdentities.add(identityHashCode(chain));
                return Text('Value: ${chain.value}');
              },
            ),
          ),
        ),
      );

      // Initial build creates first chain
      expect(chainIdentities.length, 1);
      final firstIdentity = chainIdentities[0];

      // Trigger rebuild
      source.value = 1;
      await tester.pump();

      // New chain created!
      expect(chainIdentities.length, 2);
      expect(chainIdentities[1], isNot(firstIdentity)); // Different object!

      // Another rebuild
      source.value = 2;
      await tester.pump();

      // Another new chain!
      expect(chainIdentities.length, 3);
      expect(chainIdentities[2], isNot(firstIdentity));
      expect(chainIdentities[2], isNot(chainIdentities[1]));

      // All three identities are different - memory leak!
      expect(chainIdentities.toSet().length, 3);

      source.dispose();
    });

    testWidgets(
        'chain created inline in valueListenable parameter (anti-pattern)',
        (WidgetTester tester) async {
      final source = ValueNotifier<int>(0);
      final chainIdentities = <int>[];
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestValueListenableBuilderInlineWidget(
              source: source,
              onBuild: (identity) {
                buildCount++;
                chainIdentities.add(identity);
              },
            ),
          ),
        ),
      );

      // Initial build
      expect(buildCount, 1);
      expect(chainIdentities.length, 1);
      final firstIdentity = chainIdentities[0];
      expect(find.text('Value: 0'), findsOneWidget);

      // Fire events - each rebuild creates new chain
      source.value = 5;
      await tester.pump();

      // New chain created!
      expect(buildCount, 2);
      expect(chainIdentities.length, 2);
      expect(chainIdentities[1], isNot(firstIdentity)); // Different object!
      expect(find.text('Value: 10'), findsOneWidget);

      // Another rebuild
      source.value = 7;
      await tester.pump();

      // Another new chain!
      expect(buildCount, 3);
      expect(chainIdentities.length, 3);
      expect(chainIdentities[2], isNot(firstIdentity));
      expect(chainIdentities[2], isNot(chainIdentities[1]));
      expect(find.text('Value: 14'), findsOneWidget);

      // All three identities are different - memory leak!
      expect(chainIdentities.toSet().length, 3);

      source.dispose();
    });
  });

  group('watch_it Integration Tests', () {
    tearDown(() {
      // Clean up get_it after each test
      if (di.isRegistered<ChainModel>()) {
        di.unregister<ChainModel>();
      }
    });

    testWidgets('watchValue with chain created outside build',
        (WidgetTester tester) async {
      final source = ValueNotifier<int>(0);
      final chain = source.map((x) => x * 2);
      final chainIdentity = identityHashCode(chain);

      // Register model in get_it so watchValue can access it
      final model = ChainModel(chain);
      di.registerSingleton<ChainModel>(model);

      int buildCount = 0;
      final capturedIdentities = <int>[];
      final capturedValues = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestWatchValueWidget(
              onBuild: (identity, value) {
                buildCount++;
                capturedIdentities.add(identity);
                capturedValues.add(value);
              },
            ),
          ),
        ),
      );

      // Initial build
      expect(buildCount, 1);
      expect(capturedIdentities[0], chainIdentity);
      expect(capturedValues[0], 0);

      // Fire events
      source.value = 5;
      await tester.pump();
      expect(buildCount, 2);
      expect(capturedIdentities[1], chainIdentity); // Same identity!
      expect(capturedValues[1], 10);

      source.value = 7;
      await tester.pump();
      expect(buildCount, 3);
      expect(capturedIdentities[2], chainIdentity); // Still same!
      expect(capturedValues[2], 14);

      // All captured identities are the same
      expect(capturedIdentities.toSet().length, 1);

      if (chain is FunctionalValueNotifier) {
        (chain as FunctionalValueNotifier).dispose();
      }
      source.dispose();
    });

    testWidgets('watchValue with chain created INSIDE build (anti-pattern)',
        (WidgetTester tester) async {
      final source = ValueNotifier<int>(0);

      // Register source in get_it so the widget can access it
      di.registerSingleton<ValueNotifier<int>>(source);

      final capturedIdentities = <int>[];
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestInlineChainWidget(
              onBuild: (identity) {
                buildCount++;
                capturedIdentities.add(identity);
              },
            ),
          ),
        ),
      );

      // Initial build
      expect(buildCount, 1);
      final firstIdentity = capturedIdentities[0];

      // Fire events
      source.value = 5;
      await tester.pump();
      expect(buildCount, 2);
      expect(capturedIdentities[1], isNot(firstIdentity)); // New chain!

      source.value = 7;
      await tester.pump();
      expect(buildCount, 3);
      expect(capturedIdentities[2], isNot(firstIdentity));
      expect(capturedIdentities[2], isNot(capturedIdentities[1]));

      // All identities are different - memory leak!
      expect(capturedIdentities.toSet().length, 3);

      di.unregister<ValueNotifier<int>>();
      source.dispose();
    });

    testWidgets(
        'watchValue with chain created inline - default caching prevents leak',
        (WidgetTester tester) async {
      final source = ValueNotifier<int>(0);
      _totalMapChainsCreated = 0; // Reset counter

      // Register source and model in get_it
      di.registerSingleton<ValueNotifier<int>>(source);
      final model = ChainModel(source.map((x) => x * 2));
      di.registerSingleton<ChainModel>(model);

      final capturedValues = <int>[];
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestWatchValueInlineWidget(
              source: source,
              onBuild: (value) {
                buildCount++;
                capturedValues.add(value);
              },
              // allowObservableChange defaults to false - caching enabled
            ),
          ),
        ),
      );

      // Initial build - one chain created
      expect(buildCount, 1);
      expect(capturedValues[0], 0);
      expect(
        _totalMapChainsCreated,
        1,
        reason: 'First build creates one chain',
      );

      // Fire events - selector cached, NO new chains created
      source.value = 5;
      await tester.pump();
      expect(buildCount, 2);
      expect(capturedValues[1], 10);
      expect(
        _totalMapChainsCreated,
        1,
        reason: 'Caching prevents new chain creation',
      );

      source.value = 7;
      await tester.pump();
      expect(buildCount, 3);
      expect(capturedValues[2], 14);
      expect(
        _totalMapChainsCreated,
        1,
        reason: 'Still only one chain - no memory leak!',
      );

      di.unregister<ChainModel>();
      di.unregister<ValueNotifier<int>>();
      source.dispose();
    });

    testWidgets(
        'watchValue with chain created inline + allowObservableChange=true - DOES leak',
        (WidgetTester tester) async {
      final source = ValueNotifier<int>(0);
      _totalMapChainsCreated = 0; // Reset counter

      // Register source and model in get_it
      di.registerSingleton<ValueNotifier<int>>(source);
      final model = ChainModel(source.map((x) => x * 2));
      di.registerSingleton<ChainModel>(model);

      final capturedValues = <int>[];
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestWatchValueInlineWidget(
              source: source,
              onBuild: (value) {
                buildCount++;
                capturedValues.add(value);
              },
              allowObservableChange: true, // Disable caching - anti-pattern!
            ),
          ),
        ),
      );

      // Initial build - one chain created
      expect(buildCount, 1);
      expect(capturedValues[0], 0);
      expect(
        _totalMapChainsCreated,
        1,
        reason: 'First build creates one chain',
      );

      // Fire events - selector called every build, NEW chains created
      source.value = 5;
      await tester.pump();
      expect(buildCount, 2);
      expect(capturedValues[1], 10);
      expect(
        _totalMapChainsCreated,
        2,
        reason: 'Without caching, second build creates new chain',
      );

      source.value = 7;
      await tester.pump();
      expect(buildCount, 3);
      expect(capturedValues[2], 14);
      expect(
        _totalMapChainsCreated,
        3,
        reason: 'Third build creates third chain - memory leak!',
      );

      di.unregister<ChainModel>();
      di.unregister<ValueNotifier<int>>();
      source.dispose();
    });

    testWidgets('registerHandler with chain created outside',
        (WidgetTester tester) async {
      final source = ValueNotifier<int>(0);
      final chain = source.map((x) => x * 2);
      final chainIdentity = identityHashCode(chain);

      // Register model in get_it
      final model = ChainModel(chain);
      di.registerSingleton<ChainModel>(model);

      int buildCount = 0;
      final capturedIdentities = <int>[];
      final handlerValues = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _RegisterHandlerTestWidget(
              onBuild: () {
                buildCount++;
                capturedIdentities.add(identityHashCode(chain));
              },
              onHandler: (value) {
                handlerValues.add(value);
              },
            ),
          ),
        ),
      );

      // Initial build
      expect(buildCount, 1);
      expect(capturedIdentities[0], chainIdentity);

      // Fire events - registerHandler doesn't cause rebuilds, just calls handler
      source.value = 5;
      await tester.pump();
      expect(handlerValues, [10]);
      expect(
        buildCount,
        1,
      ); // No rebuild, registerHandler doesn't trigger rebuilds!

      source.value = 7;
      await tester.pump();
      expect(handlerValues, [10, 14]);
      expect(buildCount, 1); // Still no rebuild

      // Chain identity captured once on initial build
      expect(capturedIdentities.length, 1);
      expect(capturedIdentities[0], chainIdentity);

      // Cleanup
      di.unregister<ChainModel>();
      if (chain is FunctionalValueNotifier) {
        (chain as FunctionalValueNotifier).dispose();
      }
      source.dispose();
    });

    testWidgets(
        'registerHandler with inline chain + allowObservableChange=true - DOES leak when widget rebuilds',
        (WidgetTester tester) async {
      final source = ValueNotifier<int>(0);
      final rebuildTrigger = ValueNotifier<int>(0);
      _totalMapChainsCreated = 0; // Reset counter

      // Register model in get_it
      final model = ChainModel(rebuildTrigger);
      di.registerSingleton<ChainModel>(model);

      int buildCount = 0;
      final handlerValues = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestRegisterHandlerInlineWidget(
              source: source,
              rebuildTrigger: rebuildTrigger,
              onBuild: () {
                buildCount++;
              },
              onHandler: (value) {
                handlerValues.add(value);
              },
              allowObservableChange: true, // Disable caching - anti-pattern!
            ),
          ),
        ),
      );

      // Initial build
      expect(buildCount, 1);
      expect(
        _totalMapChainsCreated,
        1,
        reason: 'First build creates one chain',
      );

      // Fire events - registerHandler doesn't cause rebuilds, just calls handler
      source.value = 5;
      await tester.pump();
      expect(handlerValues, [10]); // Handler called
      expect(buildCount, 1); // Still no rebuild from registerHandler
      expect(
        _totalMapChainsCreated,
        1,
        reason: 'No rebuild, so no new chain created',
      );

      // Now trigger a rebuild externally using rebuildTrigger
      rebuildTrigger.value = 1;
      await tester.pump();
      expect(buildCount, 2); // Rebuild happened!
      expect(
        _totalMapChainsCreated,
        2,
        reason: 'Rebuild without caching creates new chain - leak!',
      );

      // Trigger another rebuild
      rebuildTrigger.value = 2;
      await tester.pump();
      expect(buildCount, 3); // Another rebuild
      expect(
        _totalMapChainsCreated,
        3,
        reason: 'Third rebuild creates third chain - memory leak!',
      );

      // Fire source event - handler still works
      source.value = 7;
      await tester.pump();
      expect(handlerValues, [10, 14]); // Handler called

      // IMPORTANT: registerHandler with allowObservableChange=true causes leaks
      // when widgets rebuild from ANY source (watchValue, setState, etc.)

      // Cleanup
      di.unregister<ChainModel>();
      source.dispose();
      rebuildTrigger.dispose();
    });
  });
}
