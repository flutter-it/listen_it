import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listen_it/listen_it.dart';

void main() {
  group('Listenable.debounce() tests', () {
    test('debounce on regular Listenable delays notifications', () async {
      final notifier = ChangeNotifier();
      final debounced = notifier.debounce(const Duration(milliseconds: 100));
      int callCount = 0;

      debounced.addListener(() {
        callCount++;
      });

      // Trigger multiple rapid changes
      notifier.notifyListeners();
      notifier.notifyListeners();
      notifier.notifyListeners();

      // Should not have notified yet
      expect(callCount, 0);

      // Wait for debounce
      await Future.delayed(const Duration(milliseconds: 150));

      // Should have notified once
      expect(callCount, 1);
    });

    test('debounce cancels previous timer on rapid updates', () async {
      final notifier = ChangeNotifier();
      final debounced = notifier.debounce(const Duration(milliseconds: 200));
      int callCount = 0;

      debounced.addListener(() {
        callCount++;
      });

      // Rapid fire
      notifier.notifyListeners();
      await Future.delayed(const Duration(milliseconds: 50));
      notifier.notifyListeners();
      await Future.delayed(const Duration(milliseconds: 50));
      notifier.notifyListeners();
      await Future.delayed(const Duration(milliseconds: 50));

      // Still shouldn't have fired
      expect(callCount, 0);

      // Wait for final debounce
      await Future.delayed(const Duration(milliseconds: 250));

      // Should fire once
      expect(callCount, 1);
    });

    test('disposed debounced listener does not fire on new notifications',
        () async {
      final notifier = ChangeNotifier();
      final debounced = notifier.debounce(const Duration(milliseconds: 100));
      int callCount = 0;

      debounced.addListener(() {
        callCount++;
      });

      notifier.notifyListeners();

      // Wait for first debounce to fire
      await Future.delayed(const Duration(milliseconds: 150));
      expect(callCount, 1);

      // Dispose the debounced listener
      (debounced as ChangeNotifier).dispose();

      // Trigger more notifications on source
      notifier.notifyListeners();
      await Future.delayed(const Duration(milliseconds: 150));

      // Should still be 1 (not incremented after disposal)
      expect(callCount, 1);

      // Clean up
      notifier.dispose();
    });
  });

  group('CustomValueNotifier additional coverage', () {
    test('hasListeners property works correctly', () {
      final notifier = CustomValueNotifier<int>(0);

      expect(notifier.hasListeners, false);

      void listener() {}
      notifier.addListener(listener);

      expect(notifier.hasListeners, true);

      notifier.removeListener(listener);

      expect(notifier.hasListeners, false);

      notifier.dispose();
    });

    test('removeListener with non-existent listener does nothing', () {
      final notifier = CustomValueNotifier<int>(0);

      void listener1() {}
      void listener2() {}

      notifier.addListener(listener1);

      // Try to remove a listener that was never added
      expect(() => notifier.removeListener(listener2), returnsNormally);

      expect(notifier.hasListeners, true);

      notifier.dispose();
    });

    test('multiple listeners all get notified', () {
      final notifier = CustomValueNotifier<int>(0);
      int count1 = 0;
      int count2 = 0;
      int count3 = 0;

      notifier.addListener(() => count1++);
      notifier.addListener(() => count2++);
      notifier.addListener(() => count3++);

      notifier.value = 1;

      expect(count1, 1);
      expect(count2, 1);
      expect(count3, 1);

      notifier.dispose();
    });

    test('hasListeners returns false after dispose', () {
      final notifier = CustomValueNotifier<int>(0);

      void listener() {}
      notifier.addListener(listener);

      expect(notifier.hasListeners, true);

      notifier.dispose();

      // After dispose, hasListeners should return false
      expect(notifier.hasListeners, false);
    });

    test('removing all listeners then adding new ones works', () {
      final notifier = CustomValueNotifier<int>(0);
      int count1 = 0;
      int count2 = 0;

      void listener1() => count1++;
      void listener2() => count2++;

      // Add first listener
      notifier.addListener(listener1);
      notifier.value = 1;
      expect(count1, 1);

      // Remove it
      notifier.removeListener(listener1);
      notifier.value = 2;
      expect(count1, 1); // Should not have incremented

      // Add second listener
      notifier.addListener(listener2);
      notifier.value = 3;
      expect(count2, 1);

      notifier.dispose();
    });

    test('manual mode does not notify on value change', () {
      final notifier = CustomValueNotifier<int>(
        0,
        mode: CustomNotifierMode.manual,
      );
      int callCount = 0;

      notifier.addListener(() => callCount++);

      notifier.value = 1;
      notifier.value = 2;
      notifier.value = 3;

      // Should not have notified
      expect(callCount, 0);

      // Manual notify
      notifier.notifyListeners();

      // Now should have notified
      expect(callCount, 1);

      notifier.dispose();
    });

    test('always mode notifies even when value is same', () {
      final notifier = CustomValueNotifier<int>(
        0,
        mode: CustomNotifierMode.always,
      );
      int callCount = 0;

      notifier.addListener(() => callCount++);

      notifier.value = 0; // Same value
      notifier.value = 0; // Same value again

      // Should have notified twice
      expect(callCount, 2);

      notifier.dispose();
    });

    test('normal mode only notifies on actual change', () {
      final notifier = CustomValueNotifier<int>(
        0,
        mode: CustomNotifierMode.normal,
      );
      int callCount = 0;

      notifier.addListener(() => callCount++);

      notifier.value = 0; // Same value - no notify
      expect(callCount, 0);

      notifier.value = 1; // Different - notify
      expect(callCount, 1);

      notifier.value = 1; // Same again - no notify
      expect(callCount, 1);

      notifier.dispose();
    });
  });

  group('FunctionalValueNotifier edge cases', () {
    test('map chain with multiple listeners', () {
      final source = ValueNotifier<int>(0);
      final mapped = source.map((x) => x * 2);

      int count1 = 0;
      int count2 = 0;

      mapped.addListener(() => count1++);
      mapped.addListener(() => count2++);

      source.value = 5;

      expect(count1, 1);
      expect(count2, 1);
      expect(mapped.value, 10);

      source.dispose();
    });

    test('select does not notify when selected value is same', () {
      final source = ValueNotifier<User>(User('John', 25));
      final age = source.select<int>((u) => u.age);

      int callCount = 0;
      age.addListener(() => callCount++);

      // Change name but not age
      source.value = User('Jane', 25);

      // Should not notify
      expect(callCount, 0);

      // Change age
      source.value = User('Jane', 26);

      // Should notify
      expect(callCount, 1);

      source.dispose();
    });

    test('where with fallbackValue when initial does not match', () {
      final source = ValueNotifier<int>(5); // Doesn't match filter
      final filtered = source.where((x) => x > 10, fallbackValue: 0);

      expect(filtered.value, 0); // Uses fallback

      int callCount = 0;
      filtered.addListener(() => callCount++);

      source.value = 15; // Matches
      expect(filtered.value, 15);
      expect(callCount, 1);

      source.value = 3; // Doesn't match - should not notify
      expect(filtered.value, 15); // Keeps last value
      expect(callCount, 1);

      source.dispose();
    });

    test('combineLatest updates when any source changes', () {
      final source1 = ValueNotifier<int>(1);
      final source2 = ValueNotifier<int>(2);

      final combined = source1.combineLatest<int, int>(
        source2,
        (a, b) => a + b,
      );

      expect(combined.value, 3);

      int callCount = 0;
      combined.addListener(() => callCount++);

      source1.value = 10;
      expect(combined.value, 12);
      expect(callCount, 1);

      source2.value = 20;
      expect(combined.value, 30);
      expect(callCount, 2);

      source1.dispose();
      source2.dispose();
    });

    test('mergeWith emits from both sources', () {
      final source1 = ValueNotifier<int>(1);
      final source2 = ValueNotifier<int>(2);

      final merged = source1.mergeWith([source2]);

      expect(merged.value, 1);

      final values = <int>[];
      merged.addListener(() => values.add(merged.value));

      source1.value = 10;
      source2.value = 20;
      source1.value = 30;

      expect(values, [10, 20, 30]);

      source1.dispose();
      source2.dispose();
    });

    test('async ValueNotifier defers notification', () async {
      final source = ValueNotifier<int>(0);
      final asyncNotifier = source.async();

      int callCount = 0;
      int receivedValue = 0;
      asyncNotifier.addListener(() {
        callCount++;
        receivedValue = asyncNotifier.value;
      });

      source.value = 42;

      // Should not have notified yet
      expect(callCount, 0);

      // Wait for next frame
      await Future.delayed(Duration.zero);

      // Now should have notified
      expect(callCount, 1);
      expect(receivedValue, 42);

      source.dispose();
    });

    test('chained operations work correctly', () {
      final source = ValueNotifier<int>(5);
      final chain = source
          .map((x) => x * 2) // 10
          .where((x) => x > 5) // passes
          .map((x) => x + 1); // 11

      expect(chain.value, 11);

      final values = <int>[];
      chain.addListener(() => values.add(chain.value));

      source.value = 10; // *2 = 20, >5 = true, +1 = 21
      source.value = 2; // *2 = 4, >5 = false, no notification

      expect(values, [21]);

      source.dispose();
    });
  });
}

// Helper class for testing
class User {
  final String name;
  final int age;

  User(this.name, this.age);
}
