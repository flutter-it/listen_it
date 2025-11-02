import 'package:flutter_test/flutter_test.dart';
import 'package:listen_it/listen_it.dart';

void main() {
  group('Tests for MapNotifier methods', () {
    late MapNotifier<String, int> mapNotifier;
    Map<String, int> result = {};
    final newValues = {'zero': 0, 'one': 1, 'two': 2, 'three': 3};

    setUp(() {
      mapNotifier = MapNotifier(data: {'zero': 0});
      mapNotifier.addListener(() {
        result = {...mapNotifier};
      });
    });

    tearDown(() {
      mapNotifier.dispose();
    });

    test('Notifies when a new value is added', () {
      /// Define new value to mapNotifier
      mapNotifier['one'] = 1;

      /// Get the value of mapNotifier key 'zero'
      expect(result['zero'], 0);

      /// Get the value of mapNotifier key 'one'
      expect(result['one'], 1);
    });

    test('Listener is notified on add all', () {
      /// The initial value of mapNotifier is {'zero': 0}
      mapNotifier.addAll(newValues);

      /// When we add newValues to mapNotifier, the same keys will be replaced with new values
      /// and the new keys will be added to mapNotifier
      expect(result, newValues);
    });

    test('Listener is notified on add entries', () {
      mapNotifier.addEntries(newValues.entries);
      expect(result, newValues);
    });

    test('Listener is notified on clear', () {
      mapNotifier.addAll(newValues);
      expect(result, newValues);

      /// Delete all the keys and values in mapNotifier
      mapNotifier.clear();

      /// Check if mapNotifier is empty
      expect(result.isEmpty, isTrue);
    });

    test('Listener is notified on putIfAbsent', () {
      for (final entry in newValues.entries) {
        /// If the key does not exist in mapNotifier, add the key and value to mapNotifier
        /// If the key already exists in mapNotifier, do nothing
        mapNotifier.putIfAbsent(entry.key, () => entry.value);
      }

      expect(result, newValues);
    });

    test('Listener is notified when a key is removed', () {
      const key = 'one';
      mapNotifier[key] = 1;
      expect(result[key], 1);

      /// Remove the key and value from mapNotifier
      mapNotifier.remove(key);
      expect(result[key], isNull);
    });

    test('Listener is notified when removeWhere is called', () {
      mapNotifier.addAll(newValues);

      /// Remove all the keys and values in mapNotifier where the condition is true
      mapNotifier.removeWhere((_, v) => v > 0);
      expect(result, {'zero': 0});
    });

    test('Listener is notified when update is called', () {
      mapNotifier.update('zero', (_) => 10);

      /// Update the value of key 'zero' to 10
      expect(result, {'zero': 10});
    });

    test('Listener is notified when updateAll is called', () {
      mapNotifier.addAll(newValues);

      /// Update all the values in mapNotifier to 1
      mapNotifier.updateAll((p0, p1) => 1);
      expect(result, {'zero': 1, 'one': 1, 'two': 1, 'three': 1});
    });
  });

  group('Tests for notifyIfEqual', () {
    late MapNotifier<String, int> mapNotifier;
    late int listenerCallCount;
    final newValues = {'zero': 0, 'one': 1};

    group('when notifyIfEqual is false', () {
      setUp(() {
        mapNotifier = MapNotifier(
          // notifyIfEqual: false,
          notificationMode: CustomNotifierMode.normal,
        );
        listenerCallCount = 0;
        mapNotifier.addListener(() {
          listenerCallCount++;
        });
      });

      tearDown(() {
        mapNotifier.dispose();
      });

      test('Listener is not notified if value is equal', () {
        mapNotifier['zero'] = 0;
        mapNotifier['zero'] = 0;

        /// The listener is called only once because the value is equal
        expect(listenerCallCount, 1);
      });

      test(
          'Listener is notified on addAll even with equal values (bulk operations always notify)',
          () {
        mapNotifier.addAll(newValues);
        mapNotifier.addAll(newValues);

        /// Bulk operations always notify, even in normal mode
        expect(listenerCallCount, 2);
      });

      test(
          'Listener is notified on addEntries even with equal values (bulk operations always notify)',
          () {
        mapNotifier.addEntries(newValues.entries);
        mapNotifier.addEntries(newValues.entries);

        /// Bulk operations always notify, even in normal mode
        expect(listenerCallCount, 2);
      });

      test('Calling clear on an empty map does not notify listeners', () {
        mapNotifier.clear();

        /// The listener is not called because the map is empty
        expect(listenerCallCount, 0);
      });

      test('putIfAbsent only notifies when key is added', () {
        /// First call adds the key, so it notifies
        mapNotifier.putIfAbsent('zero', () => 0);
        expect(listenerCallCount, 1);

        /// Subsequent calls don't add the key (it exists), so no notification
        /// Note: The callback is NOT called when key exists
        mapNotifier.putIfAbsent('zero', () => 0);
        mapNotifier.putIfAbsent('zero', () => 1);

        expect(listenerCallCount, 1);
      });

      test('Listener is not notified if no value is removed', () {
        mapNotifier.addAll(newValues);

        /// first call when addAll is called
        expect(listenerCallCount, 1);
        mapNotifier.remove('zero');

        /// second call when remove is called
        expect(listenerCallCount, 2);
        mapNotifier.remove('zero');

        /// The count is still 2 because removing non-existent key doesn't notify
        expect(listenerCallCount, 2);
      });

      test(
        'Listener is not notified if removeWhere does not remove any values',
        () {
          mapNotifier.addAll(newValues);

          /// first call when addAll is called
          expect(listenerCallCount, 1);
          mapNotifier.removeWhere((key, _) => key == 'ten');

          /// The count is still 1 because the value is not excited in mapNotifier
          expect(listenerCallCount, 1);
        },
      );

      test(
          'Listener is not notified when update is called and updates to the '
          'already existing value', () {
        /// First call: key doesn't exist, so ifAbsent is called - this SHOULD notify
        mapNotifier.update('zero', (_) => 10, ifAbsent: () => 10);
        expect(
          listenerCallCount,
          1,
          reason: 'Should notify when adding new key',
        );

        /// Second call: key exists with value 10, update returns 10 - no change, should NOT notify
        mapNotifier.update('zero', (_) => 10, ifAbsent: () => 10);
        expect(
          listenerCallCount,
          1,
          reason: 'Should not notify when value unchanged',
        );
      });

      test(
          'Listener is not notified when updateAll is called and updates to '
          'already existing value', () {
        mapNotifier.addAll(newValues); // {'zero': 0, 'one': 1}
        expect(listenerCallCount, 1, reason: 'addAll should notify');

        mapNotifier
            .updateAll((p0, p1) => 1); // {'zero': 1, 'one': 1} - zero changed!
        expect(
          listenerCallCount,
          2,
          reason: 'Should notify because zero changed from 0 to 1',
        );

        mapNotifier
            .updateAll((p0, p1) => 1); // {'zero': 1, 'one': 1} - no change
        expect(
          listenerCallCount,
          2,
          reason: 'Should not notify when values unchanged',
        );
      });
    });

    group('when notifyIfEqual is true', () {
      setUp(() {
        mapNotifier = MapNotifier();
        listenerCallCount = 0;
        mapNotifier.addListener(() {
          listenerCallCount++;
        });
      });

      tearDown(() {
        mapNotifier.dispose();
      });

      test(
        'Listener is notified if added value is equal',
        () {
          mapNotifier['zero'] = 0;
          mapNotifier['zero'] = 0;

          /// In every call, the listener is notified because the notificationMode is CustomNotifierMode.always
          expect(listenerCallCount, 2);
        },
      );

      test('Listener is notified on addAll values already exist', () {
        final newValues = {'zero': 0, 'one': 1};
        mapNotifier.addAll(newValues);
        mapNotifier.addAll(newValues);

        /// In every call, the listener is notified because the notificationMode is CustomNotifierMode.always
        expect(listenerCallCount, 2);
      });

      test('Listener is notified if addEntries results in equal value', () {
        mapNotifier.addEntries(newValues.entries);
        mapNotifier.addEntries(newValues.entries);

        /// In every call, the listener is notified because the notificationMode is CustomNotifierMode.always
        expect(listenerCallCount, 2);
      });

      test('Calling clear on an empty map notifies listeners', () {
        mapNotifier.clear();

        /// In every call, the listener is notified because the notificationMode is CustomNotifierMode.always
        expect(listenerCallCount, 1);
      });

      test('Listener is notified on putIfAbsent even when key exists', () {
        /// First call adds the key, so it notifies
        mapNotifier.putIfAbsent('zero', () => 0);
        expect(listenerCallCount, 1);

        /// In always mode, attempting to putIfAbsent on existing key also notifies
        mapNotifier.putIfAbsent('zero', () => 0);
        expect(listenerCallCount, 2);

        /// Third call also notifies in always mode
        mapNotifier.putIfAbsent('zero', () => 1);
        expect(listenerCallCount, 3);
      });

      test('Listener is notified if no value is removed', () {
        mapNotifier.addAll(newValues);

        /// In every call, the listener is notified because the notificationMode is CustomNotifierMode.always
        expect(listenerCallCount, 1);
        mapNotifier.remove('zero');
        expect(listenerCallCount, 2);
        mapNotifier.remove('zero');
        expect(listenerCallCount, 3);
      });

      test(
        'Listener is notified if removeWhere does not remove any values',
        () {
          mapNotifier.addAll(newValues);

          /// In every call, the listener is notified because the notificationMode is CustomNotifierMode.always
          expect(listenerCallCount, 1);
          mapNotifier.removeWhere((key, _) => key == 'ten');

          /// In every call, the listener is notified because the notificationMode is CustomNotifierMode.always
          expect(listenerCallCount, 2);
        },
      );

      test('Listener is notified when update is called', () {
        mapNotifier.update('zero', (_) => 10, ifAbsent: () => 10);
        expect(
          listenerCallCount,
          1,
          reason: 'First update adds key via ifAbsent',
        );
        mapNotifier.update('zero', (_) => 10, ifAbsent: () => 10);
        expect(
          listenerCallCount,
          2,
          reason: 'Should notify in always mode even when value unchanged',
        );
      });

      test(
          'Listener is notified when updateAll is called and updates to '
          'already existing value', () {
        mapNotifier.addAll(newValues);

        /// The first count is 1 because the mapNotifier is updated when addAll is called
        expect(listenerCallCount, 1);
        mapNotifier.updateAll((p0, p1) => 1);

        /// The second count is 2 because the mapNotifier is updated when updateAll is called
        expect(listenerCallCount, 2);
        mapNotifier.updateAll((p0, p1) => 1);

        /// The second count is 2 because the mapNotifier is updated when updateAll is called although the values are already updated
        expect(listenerCallCount, 3);
      });
    });
  });

  group('Custom equality tests', () {
    // Compare absolute values: -2 and 2 are considered equal
    final customEquality =
        (int? x, int? y) => (x?.abs() ?? 0) == (y?.abs() ?? 0);

    group('When notifyIfEqual is false', () {
      late MapNotifier<String, int> mapNotifier;
      late int listenerCallCount;

      setUp(() {
        mapNotifier = MapNotifier(
          data: {'one': 1, 'negTwo': -2},
          customEquality: customEquality,
          notificationMode: CustomNotifierMode.normal,
        );
        listenerCallCount = 0;
        mapNotifier.addListener(() {
          listenerCallCount++;
        });
      });

      tearDown(() {
        mapNotifier.dispose();
      });

      test(
        'Listener is not notified if customEquality returns true (are equal)',
        () {
          /// -2 -> 2: abs values are equal, should NOT notify
          mapNotifier['negTwo'] = 2;
          expect(listenerCallCount, 0);
          expect(mapNotifier['negTwo'], 2);
        },
      );

      test(
        'Listener is notified if customEquality returns false (are not equal)',
        () {
          /// 1 -> 5: abs values differ, should notify
          mapNotifier['one'] = 5;
          expect(listenerCallCount, 1);
          expect(mapNotifier['one'], 5);
        },
      );
    });

    group('When notifyIfEqual is true', () {
      late MapNotifier<String, int> mapNotifier;
      late int listenerCallCount;

      setUp(() {
        mapNotifier = MapNotifier(
          data: {'one': 1, 'negTwo': -2},
          customEquality: customEquality,
        );
        listenerCallCount = 0;
        mapNotifier.addListener(() {
          listenerCallCount++;
        });
      });

      tearDown(() {
        mapNotifier.dispose();
      });

      test(
        'Listener is notified even if customEquality returns true (are equal)',
        () {
          /// -2 -> 2: abs values equal, but in always mode it still notifies
          mapNotifier['negTwo'] = 2;
          expect(listenerCallCount, 1);
          expect(mapNotifier['negTwo'], 2);
        },
      );

      test(
        'Listener is notified if customEquality returns false (are not equal)',
        () {
          /// 1 -> 5: abs values differ, always mode notifies
          mapNotifier['one'] = 5;
          expect(listenerCallCount, 1);
          expect(mapNotifier['one'], 5);
        },
      );
    });
  });

  group('Bug tests for MapNotifier', () {
    test('addAll() always notifies even in normal mode (bulk operations)', () {
      final mapNotifier = MapNotifier<String, int>(
        data: {'a': 1, 'b': 2},
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      mapNotifier.addListener(() {
        listenerCallCount++;
      });

      // Bulk operations always notify, even when values are unchanged
      mapNotifier.addAll({'a': 1, 'b': 2});
      expect(listenerCallCount, 1, reason: 'Bulk operations always notify');

      // Second call also notifies
      mapNotifier.addAll({'a': 1, 'b': 3});
      expect(listenerCallCount, 2, reason: 'Bulk operations always notify');

      mapNotifier.dispose();
    });

    test('BUG: remove() should detect change even with null values', () {
      final mapNotifier = MapNotifier<String, int?>(
        data: {'a': 1, 'b': null},
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      mapNotifier.addListener(() {
        listenerCallCount++;
      });

      // Removing a null value should still notify in normal mode
      mapNotifier.remove('b');

      expect(listenerCallCount, 1);
      expect(mapNotifier.containsKey('b'), false);
      mapNotifier.dispose();
    });

    test('BUG: update() should work with null values', () {
      final mapNotifier = MapNotifier<String, int?>(
        data: {'a': null},
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      mapNotifier.addListener(() {
        listenerCallCount++;
      });

      // Updating a null value should use the custom logic, not fall back to super
      final result = mapNotifier.update('a', (value) => 5);

      expect(result, 5);
      expect(mapNotifier['a'], 5);
      expect(listenerCallCount, 1);
      mapNotifier.dispose();
    });

    test(
        'BUG: updateAll() should detect if ANY value changed, not just the last',
        () {
      final mapNotifier = MapNotifier<String, int>(
        data: {'a': 1, 'b': 2, 'c': 3},
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      mapNotifier.addListener(() {
        listenerCallCount++;
      });

      // Change first two values, but keep last one the same
      mapNotifier.updateAll((key, value) {
        if (key == 'a') return 10;
        if (key == 'b') return 20;
        return value; // 'c' stays as 3
      });

      // Should notify because 'a' and 'b' changed, even though 'c' didn't
      expect(listenerCallCount, 1);
      expect(mapNotifier['a'], 10);
      expect(mapNotifier['b'], 20);
      expect(mapNotifier['c'], 3);
      mapNotifier.dispose();
    });
  });

  group('Manual mode tests', () {
    test('Manual mode requires explicit notifyListeners', () {
      final mapNotifier = MapNotifier<String, int>(
        data: {'a': 1},
        notificationMode: CustomNotifierMode.manual,
      );

      int listenerCallCount = 0;
      mapNotifier.addListener(() {
        listenerCallCount++;
      });

      // Operations don't trigger notifications in manual mode
      mapNotifier['b'] = 2;
      mapNotifier['c'] = 3;
      mapNotifier.remove('a');

      expect(listenerCallCount, 0);

      // Must call notifyListeners manually
      mapNotifier.notifyListeners();

      expect(listenerCallCount, 1);
      mapNotifier.dispose();
    });

    test('Manual mode works with transactions', () {
      final mapNotifier = MapNotifier<String, int>(
        data: {'a': 1},
        notificationMode: CustomNotifierMode.manual,
      );

      int listenerCallCount = 0;
      mapNotifier.addListener(() {
        listenerCallCount++;
      });

      mapNotifier.startTransAction();
      mapNotifier['b'] = 2;
      mapNotifier['c'] = 3;
      mapNotifier.endTransAction();

      // Even after transaction, manual mode doesn't notify
      expect(listenerCallCount, 0);

      mapNotifier.notifyListeners();
      expect(listenerCallCount, 1);
      mapNotifier.dispose();
    });
  });

  group('Transaction tests', () {
    test('Transaction batches operations into one notification', () {
      final mapNotifier = MapNotifier<String, int>(
        data: {'a': 1},
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      mapNotifier.addListener(() {
        listenerCallCount++;
      });

      mapNotifier.startTransAction();
      mapNotifier['b'] = 2;
      mapNotifier['c'] = 3;
      mapNotifier['d'] = 4;
      expect(
        listenerCallCount,
        0,
        reason: 'No notification during transaction',
      );

      mapNotifier.endTransAction();
      expect(
        listenerCallCount,
        1,
        reason: 'Single notification after transaction',
      );
      mapNotifier.dispose();
    });

    test('Nested transactions are prevented', () {
      final mapNotifier = MapNotifier<String, int>(data: {'a': 1});

      mapNotifier.startTransAction();
      expect(
        () => mapNotifier.startTransAction(),
        throwsAssertionError,
      );

      mapNotifier.endTransAction();
      mapNotifier.dispose();
    });

    test('Transaction respects _hasChanged flag', () {
      final mapNotifier = MapNotifier<String, int>(
        data: {'a': 1},
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      mapNotifier.addListener(() {
        listenerCallCount++;
      });

      mapNotifier.startTransAction();
      // Setting same value shouldn't trigger notification
      mapNotifier['a'] = 1;
      mapNotifier['a'] = 1;
      mapNotifier.endTransAction();

      expect(listenerCallCount, 0, reason: 'No change occurred');
      mapNotifier.dispose();
    });
  });

  group('Value getter immutability tests', () {
    test('value getter returns immutable view', () {
      final mapNotifier = MapNotifier<String, int>(data: {'a': 1, 'b': 2});
      final view = mapNotifier.value;

      expect(() => view['c'] = 3, throwsUnsupportedError);
      expect(() => view.remove('a'), throwsUnsupportedError);
      expect(() => view.clear(), throwsUnsupportedError);
      mapNotifier.dispose();
    });

    test('value getter reflects current state', () {
      final mapNotifier = MapNotifier<String, int>(data: {'a': 1});

      expect(mapNotifier.value, {'a': 1});

      mapNotifier['b'] = 2;
      expect(mapNotifier.value, {'a': 1, 'b': 2});

      mapNotifier.remove('a');
      expect(mapNotifier.value, {'b': 2});

      mapNotifier.dispose();
    });
  });

  group('Post-dispose tests', () {
    test('Operations after dispose throw on notify', () {
      final mapNotifier = MapNotifier<String, int>(data: {'a': 1});
      mapNotifier.dispose();

      // Operation modifies map but notification throws
      expect(() => mapNotifier['b'] = 2, throwsFlutterError);
    });
  });

  group('Edge case tests', () {
    test('removeWhere on empty map does not notify in normal mode', () {
      final mapNotifier = MapNotifier<String, int>(
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      mapNotifier.addListener(() {
        listenerCallCount++;
      });

      mapNotifier.removeWhere((k, v) => v > 0);

      expect(listenerCallCount, 0);
      mapNotifier.dispose();
    });

    test('remove non-existent key does not notify in normal mode', () {
      final mapNotifier = MapNotifier<String, int>(
        data: {'a': 1},
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      mapNotifier.addListener(() {
        listenerCallCount++;
      });

      mapNotifier.remove('nonexistent');

      expect(listenerCallCount, 0);
      mapNotifier.dispose();
    });

    test('clear on empty map does not notify in normal mode', () {
      final mapNotifier = MapNotifier<String, int>(
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      mapNotifier.addListener(() {
        listenerCallCount++;
      });

      mapNotifier.clear();

      expect(listenerCallCount, 0);
      mapNotifier.dispose();
    });

    test('addAll with empty map always notifies', () {
      final mapNotifier = MapNotifier<String, int>(
        data: {'a': 1},
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      mapNotifier.addListener(() {
        listenerCallCount++;
      });

      // Bulk operations always notify, even with empty input
      mapNotifier.addAll({});

      expect(listenerCallCount, 1);
      mapNotifier.dispose();
    });

    test('addEntries with empty iterable always notifies', () {
      final mapNotifier = MapNotifier<String, int>(
        data: {'a': 1},
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      mapNotifier.addListener(() {
        listenerCallCount++;
      });

      // Bulk operations always notify, even with empty input
      mapNotifier.addEntries([]);

      expect(listenerCallCount, 1);
      mapNotifier.dispose();
    });
  });
}
