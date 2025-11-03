// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listen_it/listen_it.dart';

void main() {
  group('Lazy initialization with chains', () {
    test('Single map operator - no subscription until listener added', () {
      final source = ValueNotifier<int>(10);
      final mapped = source.map((x) => x * 2);

      // Should not have listeners yet (lazy)
      expect(source.hasListeners, false);

      // Add listener triggers init
      final listener = () {};
      mapped.addListener(listener);

      expect(source.hasListeners, true);
      expect(mapped.value, 20);

      // Remove listener
      mapped.removeListener(listener);

      source.dispose();
    });

    test('Chain of 3 operators - no subscription until listener added', () {
      final source = ValueNotifier<int>(10);
      final mapped = source.map((x) => x * 2);
      final selected = mapped.select((x) => x + 5);
      final filtered = selected.where((x) => x > 20);

      // None should have listeners yet (lazy)
      expect(source.hasListeners, false);

      // Add listener to end of chain triggers all inits
      final listener = () {};
      filtered.addListener(listener);

      expect(source.hasListeners, true);
      expect(filtered.value, 25); // 10 * 2 + 5 = 25

      // Change source propagates through chain
      source.value = 20;
      expect(filtered.value, 45); // 20 * 2 + 5 = 45

      filtered.removeListener(listener);
      source.dispose();
    });

    test('Removing and re-adding listener works correctly', () {
      final source = ValueNotifier<int>(5);
      final chain = source.map((x) => x * 10).where((x) => x > 20);

      expect(source.hasListeners, false);

      // Add listener
      var callCount = 0;
      final listener = () => callCount++;
      chain.addListener(listener);

      expect(source.hasListeners, true);
      expect(chain.value, 50);

      // Trigger update
      source.value = 3; // 30 passes where()
      expect(callCount, 1);

      // Remove listener - should unsubscribe from source
      chain.removeListener(listener);

      // Re-add listener - should re-subscribe
      chain.addListener(listener);
      expect(source.hasListeners, true);

      // Verify it still works
      source.value = 4; // 40 passes where()
      expect(callCount, 2);

      chain.removeListener(listener);
      source.dispose();
    });

    test('combineLatest2 - lazy init until listener added', () {
      final source1 = ValueNotifier<int>(1);
      final source2 = ValueNotifier<int>(2);

      final combined =
          source1.combineLatest<int, int>(source2, (a, b) => a + b);

      // Should not have listeners yet (lazy)
      expect(source1.hasListeners, false);
      expect(source2.hasListeners, false);

      // Add listener triggers init
      var callCount = 0;
      final listener = () => callCount++;
      combined.addListener(listener);

      expect(source1.hasListeners, true);
      expect(source2.hasListeners, true);
      expect(combined.value, 3);

      // Updates trigger notifications
      source1.value = 10;
      expect(combined.value, 12);
      expect(callCount, 1);

      source2.value = 20;
      expect(combined.value, 30);
      expect(callCount, 2);

      combined.removeListener(listener);
      source1.dispose();
      source2.dispose();
    });

    test('combineLatest3 - lazy init', () {
      final source1 = ValueNotifier<int>(1);
      final source2 = ValueNotifier<int>(2);
      final source3 = ValueNotifier<int>(3);

      final combined = source1.combineLatest3<int, int, int>(
        source2,
        source3,
        (a, b, c) => a + b + c,
      );

      // Lazy - no listeners yet
      expect(source1.hasListeners, false);
      expect(source2.hasListeners, false);
      expect(source3.hasListeners, false);

      combined.addListener(() {});

      expect(source1.hasListeners, true);
      expect(source2.hasListeners, true);
      expect(source3.hasListeners, true);
      expect(combined.value, 6);

      source1.dispose();
      source2.dispose();
      source3.dispose();
    });

    test('combineLatest4 - lazy init', () {
      final source1 = ValueNotifier<int>(1);
      final source2 = ValueNotifier<int>(2);
      final source3 = ValueNotifier<int>(3);
      final source4 = ValueNotifier<int>(4);

      final combined = source1.combineLatest4<int, int, int, int>(
        source2,
        source3,
        source4,
        (a, b, c, d) => a + b + c + d,
      );

      expect(source1.hasListeners, false);

      combined.addListener(() {});

      expect(source1.hasListeners, true);
      expect(combined.value, 10);

      source1.dispose();
      source2.dispose();
      source3.dispose();
      source4.dispose();
    });

    test('combineLatest5 - lazy init', () {
      final source1 = ValueNotifier<int>(1);
      final source2 = ValueNotifier<int>(2);
      final source3 = ValueNotifier<int>(3);
      final source4 = ValueNotifier<int>(4);
      final source5 = ValueNotifier<int>(5);

      final combined = source1.combineLatest5<int, int, int, int, int>(
        source2,
        source3,
        source4,
        source5,
        (a, b, c, d, e) => a + b + c + d + e,
      );

      expect(source1.hasListeners, false);

      combined.addListener(() {});

      expect(source1.hasListeners, true);
      expect(combined.value, 15);

      source1.dispose();
      source2.dispose();
      source3.dispose();
      source4.dispose();
      source5.dispose();
    });

    test('combineLatest6 - lazy init', () {
      final source1 = ValueNotifier<int>(1);
      final source2 = ValueNotifier<int>(2);
      final source3 = ValueNotifier<int>(3);
      final source4 = ValueNotifier<int>(4);
      final source5 = ValueNotifier<int>(5);
      final source6 = ValueNotifier<int>(6);

      final combined = source1.combineLatest6<int, int, int, int, int, int>(
        source2,
        source3,
        source4,
        source5,
        source6,
        (a, b, c, d, e, f) => a + b + c + d + e + f,
      );

      expect(source1.hasListeners, false);

      combined.addListener(() {});

      expect(source1.hasListeners, true);
      expect(combined.value, 21);

      source1.dispose();
      source2.dispose();
      source3.dispose();
      source4.dispose();
      source5.dispose();
      source6.dispose();
    });

    test('mergeWith - lazy init', () {
      final source1 = ValueNotifier<int>(1);
      final source2 = ValueNotifier<int>(2);
      final source3 = ValueNotifier<int>(3);

      final merged = source1.mergeWith([source2, source3]);

      // Lazy - no listeners
      expect(source1.hasListeners, false);
      expect(source2.hasListeners, false);
      expect(source3.hasListeners, false);

      merged.addListener(() {});

      expect(source1.hasListeners, true);
      expect(source2.hasListeners, true);
      expect(source3.hasListeners, true);

      source1.dispose();
      source2.dispose();
      source3.dispose();
    });

    test('debounce - lazy init', () async {
      final source = ValueNotifier<int>(1);
      final debounced = source.debounce(const Duration(milliseconds: 50));

      // Lazy - no listeners
      expect(source.hasListeners, false);

      debounced.addListener(() {});

      expect(source.hasListeners, true);

      source.dispose();
    });

    test('async - lazy init', () {
      final source = ValueNotifier<int>(1);
      final async = source.async();

      // Lazy - no listeners
      expect(source.hasListeners, false);

      async.addListener(() {});

      expect(source.hasListeners, true);

      source.dispose();
    });

    test('Complex chain with multiple operators', () {
      final source = ValueNotifier<int>(10);

      // Create complex chain: map -> combineLatest -> select -> where
      final mapped = source.map((x) => x * 2);
      final other = ValueNotifier<int>(5);
      final combined = mapped.combineLatest<int, int>(other, (a, b) => a + b);
      final selected = combined.select((x) => x ~/ 5);
      final filtered = selected.where((x) => x > 3);

      // Nothing should have listeners (all lazy)
      expect(source.hasListeners, false);
      expect(other.hasListeners, false);

      // Add listener to end of chain
      var callCount = 0;
      filtered.addListener(() => callCount++);

      // Now everything should be connected
      expect(source.hasListeners, true);
      expect(other.hasListeners, true);
      expect(filtered.value, 5); // (10 * 2 + 5) / 5 = 5

      // Change source
      source.value = 15; // (15 * 2 + 5) / 5 = 7
      expect(filtered.value, 7);
      expect(callCount, 1);

      // Change other source
      other.value = 15; // (15 * 2 + 15) / 5 = 9
      expect(filtered.value, 9);
      expect(callCount, 2);

      source.dispose();
      other.dispose();
    });

    test('Removing all listeners and re-adding', () {
      final source = ValueNotifier<int>(5);
      final chain = source.map((x) => x * 2).map((x) => x + 1);

      // Add first listener
      final listener1 = () {};
      chain.addListener(listener1);
      expect(source.hasListeners, true);
      expect(chain.value, 11);

      // Add second listener
      final listener2 = () {};
      chain.addListener(listener2);
      expect(source.hasListeners, true);

      // Remove first listener - should still have subscription
      chain.removeListener(listener1);
      expect(source.hasListeners, true);

      // Remove second listener - should unsubscribe from source
      chain.removeListener(listener2);

      // Re-add listener - should re-init
      chain.addListener(listener1);
      expect(source.hasListeners, true);

      // Verify it still works
      source.value = 10;
      expect(chain.value, 21);

      chain.removeListener(listener1);
      source.dispose();
    });
  });
}
