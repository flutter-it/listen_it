// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listen_it/listen_it.dart';

void main() {
  group('Coverage improvements', () {
    test('MapValueNotifier lazy initialization on first addListener', () {
      final source = ValueNotifier<int>(0);
      final mapped = source.map((x) => x * 2, lazy: true);

      // Verify lazy initialization - source should not have listeners yet
      expect(source.hasListeners, false);

      // Adding a listener should trigger init()
      var callCount = 0;
      mapped.addListener(() => callCount++);

      // Now source should have a listener (chain initialized)
      expect(source.hasListeners, true);

      // Verify chain works after initialization
      source.value = 5;
      expect(mapped.value, 10);
      expect(callCount, 1);

      source.dispose();
    });

    test('DebouncedValueNotifier lazy initialization on first addListener',
        () async {
      final source = ValueNotifier<int>(0);
      final debounced =
          source.debounce(const Duration(milliseconds: 50), lazy: true);

      // Verify lazy initialization - source should not have listeners yet
      expect(source.hasListeners, false);

      // Adding a listener should trigger init()
      var callCount = 0;
      debounced.addListener(() => callCount++);

      // Now source should have a listener (chain initialized)
      expect(source.hasListeners, true);

      // Verify debounce works after initialization
      source.value = 1;
      source.value = 2;
      source.value = 3;

      // Wait for debounce
      await Future.delayed(const Duration(milliseconds: 100));

      expect(debounced.value, 3);
      expect(callCount, 1);

      source.dispose();
    });

    test('CombiningValueNotifier2 updates from both sources', () {
      final source1 = ValueNotifier<int>(1);
      final source2 = ValueNotifier<int>(2);
      final combined =
          source1.combineLatest<int, int>(source2, (a, b) => a + b);

      var callCount = 0;
      combined.addListener(() => callCount++);

      expect(combined.value, 3);

      // Update first source
      source1.value = 5;
      expect(combined.value, 7);
      expect(callCount, 1);

      // Update second source
      source2.value = 10;
      expect(combined.value, 15);
      expect(callCount, 2);

      source1.dispose();
      source2.dispose();
    });

    test('CombiningValueNotifier2 lazy initialization on first addListener',
        () {
      final source1 = ValueNotifier<int>(1);
      final source2 = ValueNotifier<String>('a');
      final combined = source1
          .combineLatest<String, String>(source2, (a, b) => '$a$b', lazy: true);

      // Verify lazy initialization - sources should not have listeners yet
      expect(source1.hasListeners, false);
      expect(source2.hasListeners, false);

      var callCount = 0;
      combined.addListener(() => callCount++);

      // Now it should be initialized - sources should have listeners
      expect(source1.hasListeners, true);
      expect(source2.hasListeners, true);

      // Verify it works
      source1.value = 2;
      expect(combined.value, '2a');
      expect(callCount, 1);

      source1.dispose();
      source2.dispose();
    });

    test('CustomValueNotifier hasListeners getter', () {
      final notifier = CustomValueNotifier<int>(
        0,
      );

      expect(notifier.hasListeners, false);

      final listener = () {};
      notifier.addListener(listener);
      expect(notifier.hasListeners, true);

      notifier.removeListener(listener);
      expect(notifier.hasListeners, false);

      notifier.dispose();
    });

    test('CustomValueNotifier with manual mode and notify', () {
      // Test manual notification mode
      final notifier = CustomValueNotifier<String>(
        'hello',
        mode: CustomNotifierMode.manual,
      );

      var callCount = 0;
      notifier.addListener(() => callCount++);

      // Should not notify automatically in manual mode
      notifier.value = 'world';
      expect(callCount, 0);

      // Manually trigger notification
      notifier.notifyListeners();
      expect(callCount, 1);

      notifier.dispose();
    });

    test('Debounce with timer cancellation', () async {
      final source = ValueNotifier<int>(0);
      final debounced = source.debounce(const Duration(milliseconds: 100));

      var callCount = 0;
      debounced.addListener(() => callCount++);

      // Rapidly change values - timer should be cancelled and restarted
      source.value = 1;
      await Future.delayed(const Duration(milliseconds: 50));
      source.value = 2;
      await Future.delayed(const Duration(milliseconds: 50));
      source.value = 3;

      // Wait for final debounce
      await Future.delayed(const Duration(milliseconds: 150));

      // Should only notify once with the last value
      expect(debounced.value, 3);
      expect(callCount, 1);

      source.dispose();
    });

    test('CombineLatest3 initialization and usage', () {
      final source1 = ValueNotifier<int>(1);
      final source2 = ValueNotifier<int>(2);
      final source3 = ValueNotifier<int>(3);

      final combined = source1.combineLatest3<int, int, int>(
        source2,
        source3,
        (a, b, c) => a + b + c,
      );

      var callCount = 0;
      combined.addListener(() => callCount++);

      expect(combined.value, 6);

      source1.value = 10;
      expect(combined.value, 15);
      expect(callCount, 1);

      source1.dispose();
      source2.dispose();
      source3.dispose();
    });

    test('CombineLatest4 initialization and usage', () {
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

      var callCount = 0;
      combined.addListener(() => callCount++);

      expect(combined.value, 10);

      source1.value = 10;
      expect(combined.value, 19);
      expect(callCount, 1);

      source1.dispose();
      source2.dispose();
      source3.dispose();
      source4.dispose();
    });

    test('CombineLatest5 initialization and usage', () {
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

      var callCount = 0;
      combined.addListener(() => callCount++);

      expect(combined.value, 15);

      source1.value = 10;
      expect(combined.value, 24);
      expect(callCount, 1);

      source1.dispose();
      source2.dispose();
      source3.dispose();
      source4.dispose();
      source5.dispose();
    });

    test('CombineLatest6 initialization and usage', () {
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

      var callCount = 0;
      combined.addListener(() => callCount++);

      expect(combined.value, 21);

      source1.value = 10;
      expect(combined.value, 30);
      expect(callCount, 1);

      source1.dispose();
      source2.dispose();
      source3.dispose();
      source4.dispose();
      source5.dispose();
      source6.dispose();
    });

    test('CombineLatest2 dispose removes listeners from both sources', () {
      final source1 = ValueNotifier<int>(1);
      final source2 = ValueNotifier<int>(2);
      final combined =
          source1.combineLatest<int, int>(source2, (a, b) => a + b);

      combined.addListener(() {});

      expect(source1.hasListeners, true);
      expect(source2.hasListeners, true);

      (combined as ValueNotifier<int>).dispose();

      expect(source1.hasListeners, false);
      expect(source2.hasListeners, false);

      source1.dispose();
      source2.dispose();
    });

    test('CombineLatest3 lazy init and dispose', () {
      final source1 = ValueNotifier<int>(1);
      final source2 = ValueNotifier<int>(2);
      final source3 = ValueNotifier<int>(3);

      final combined = source1.combineLatest3<int, int, int>(
        source2,
        source3,
        (a, b, c) => a + b + c,
        lazy: true,
      );

      // Lazy init - no listeners yet
      expect(source1.hasListeners, false);
      expect(source2.hasListeners, false);
      expect(source3.hasListeners, false);

      combined.addListener(() {});

      // Now initialized
      expect(source1.hasListeners, true);
      expect(source2.hasListeners, true);
      expect(source3.hasListeners, true);

      (combined as ValueNotifier<int>).dispose();

      expect(source1.hasListeners, false);
      expect(source2.hasListeners, false);
      expect(source3.hasListeners, false);

      source1.dispose();
      source2.dispose();
      source3.dispose();
    });

    test('CombineLatest4 lazy init and dispose', () {
      final source1 = ValueNotifier<int>(1);
      final source2 = ValueNotifier<int>(2);
      final source3 = ValueNotifier<int>(3);
      final source4 = ValueNotifier<int>(4);

      final combined = source1.combineLatest4<int, int, int, int>(
        source2,
        source3,
        source4,
        (a, b, c, d) => a + b + c + d,
        lazy: true,
      );

      // Lazy init
      expect(source1.hasListeners, false);

      combined.addListener(() {});

      // Now initialized
      expect(source1.hasListeners, true);

      (combined as ValueNotifier<int>).dispose();

      expect(source1.hasListeners, false);

      source1.dispose();
      source2.dispose();
      source3.dispose();
      source4.dispose();
    });

    test('CombineLatest5 lazy init and dispose', () {
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
        lazy: true,
      );

      // Lazy init
      expect(source1.hasListeners, false);

      combined.addListener(() {});

      // Now initialized
      expect(source1.hasListeners, true);

      (combined as ValueNotifier<int>).dispose();

      expect(source1.hasListeners, false);

      source1.dispose();
      source2.dispose();
      source3.dispose();
      source4.dispose();
      source5.dispose();
    });

    test('CombineLatest6 lazy init and dispose', () {
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
        lazy: true,
      );

      // Lazy init
      expect(source1.hasListeners, false);

      combined.addListener(() {});

      // Now initialized
      expect(source1.hasListeners, true);

      (combined as ValueNotifier<int>).dispose();

      expect(source1.hasListeners, false);

      source1.dispose();
      source2.dispose();
      source3.dispose();
      source4.dispose();
      source5.dispose();
      source6.dispose();
    });

    test('Multiple listener add/remove to trigger list compaction', () {
      final notifier = CustomValueNotifier<int>(
        0,
      );

      // Add many listeners to grow the list
      final listeners = List.generate(20, (_) => () {});
      for (final listener in listeners) {
        notifier.addListener(listener);
      }

      expect(notifier.hasListeners, true);

      // Remove every other listener to trigger compaction
      for (int i = 0; i < listeners.length; i += 2) {
        notifier.removeListener(listeners[i]);
      }

      expect(notifier.hasListeners, true);

      // Remove rest
      for (int i = 1; i < listeners.length; i += 2) {
        notifier.removeListener(listeners[i]);
      }

      expect(notifier.hasListeners, false);

      notifier.dispose();
    });

    test('Error in listener without error handler triggers FlutterError', () {
      final notifier = CustomValueNotifier<int>(
        0,
        mode: CustomNotifierMode.always,
      );

      // Add a listener that throws
      notifier.addListener(() {
        throw Exception('Test error');
      });

      // Should not throw, error is caught and reported via FlutterError
      expect(() => notifier.value = 1, returnsNormally);

      notifier.dispose();
    });

    test('Error in listener with error handler calls onError', () {
      Object? caughtError;
      StackTrace? caughtStack;

      final notifier = CustomValueNotifier<int>(
        0,
        mode: CustomNotifierMode.always,
        onError: (error, stack) {
          caughtError = error;
          caughtStack = stack;
        },
      );

      notifier.addListener(() {
        throw Exception('Test error');
      });

      notifier.value = 1;

      expect(caughtError, isA<Exception>());
      expect(caughtStack, isNotNull);

      notifier.dispose();
    });

    test('Removing listener during notification (reentrant removal)', () {
      final notifier = CustomValueNotifier<int>(
        0,
        mode: CustomNotifierMode.always,
      );

      late VoidCallback listener1;
      late VoidCallback listener2;
      late VoidCallback listener3;

      var call1 = 0;
      var call2 = 0;
      var call3 = 0;

      listener1 = () {
        call1++;
        // Remove listener3 during notification (comes after us)
        notifier.removeListener(listener3);
      };

      listener2 = () {
        call2++;
      };

      listener3 = () {
        call3++;
      };

      notifier.addListener(listener1);
      notifier.addListener(listener2);
      notifier.addListener(listener3);

      // Trigger notification - listener1 will remove listener3 during execution
      notifier.value = 1;

      expect(call1, 1);
      expect(call2, 1);
      expect(call3, 0); // Not called because removed before its turn

      // Next notification should not call listener3
      notifier.value = 2;

      expect(call1, 2);
      expect(call2, 2);
      expect(call3, 0); // Still not called

      notifier.dispose();
    });

    test('Reentrant removal with list compaction', () {
      final notifier = CustomValueNotifier<int>(
        0,
        mode: CustomNotifierMode.always,
      );

      // Add many listeners
      final listeners = <VoidCallback>[];
      for (int i = 0; i < 20; i++) {
        final listener = () {};
        listeners.add(listener);
        notifier.addListener(listener);
      }

      // Add a listener that removes multiple other listeners
      late VoidCallback remover;
      remover = () {
        // Remove every other listener during notification
        for (int i = 0; i < listeners.length; i += 2) {
          notifier.removeListener(listeners[i]);
        }
      };

      notifier.addListener(remover);

      // Trigger notification - should compact the list
      notifier.value = 1;

      expect(notifier.hasListeners, true);

      notifier.dispose();
    });

    test('MergeWith disposal removes all listeners', () {
      final source1 = ValueNotifier<int>(1);
      final source2 = ValueNotifier<int>(2);
      final source3 = ValueNotifier<int>(3);

      final merged = source1.mergeWith([source2, source3]);

      merged.addListener(() {});

      expect(source1.hasListeners, true);
      expect(source2.hasListeners, true);
      expect(source3.hasListeners, true);

      // Dispose merged - should remove all listeners
      (merged as ValueNotifier<int>).dispose();

      expect(source1.hasListeners, false);
      expect(source2.hasListeners, false);
      expect(source3.hasListeners, false);

      source1.dispose();
      source2.dispose();
      source3.dispose();
    });
  });
}
