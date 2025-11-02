import 'package:flutter_test/flutter_test.dart';
import 'package:listen_it/listen_it.dart';

void main() {
  group("Tests for SetNotifier's methods", () {
    late SetNotifier<int> setNotifier;
    Set<int> result = {};
    int listenerCallCount = 0;

    setUp(() {
      setNotifier = SetNotifier(data: {1, 2, 3});
      result.clear();
      listenerCallCount = 0;
    });

    void buildListener() {
      setNotifier.addListener(() {
        listenerCallCount++;
        result = {...setNotifier.value};
      });
    }

    test("Listener is notified when new value is added", () {
      buildListener();

      final bool wasAdded = setNotifier.add(4);

      expect(listenerCallCount, 1);
      expect(wasAdded, true);
      expect(result, {1, 2, 3, 4});
    });

    test("Listener is notified on addAll", () {
      buildListener();

      setNotifier.addAll({4, 5, 6});

      expect(listenerCallCount, 1);
      expect(result, {1, 2, 3, 4, 5, 6});
    });

    test("Listener is notified when set is cleared", () {
      buildListener();

      setNotifier.clear();

      expect(listenerCallCount, 1);
      expect(result, isEmpty);
    });

    test("Listener is notified when value is removed", () {
      buildListener();

      final bool wasRemoved = setNotifier.remove(2);

      expect(listenerCallCount, 1);
      expect(wasRemoved, true);
      expect(result, {1, 3});
    });

    test("Listener is notified on removeAll", () {
      buildListener();

      setNotifier.removeAll({1, 3});

      expect(listenerCallCount, 1);
      expect(result, {2});
    });

    test("Listener is notified on removeWhere", () {
      buildListener();

      setNotifier.removeWhere((element) => element > 1);

      expect(listenerCallCount, 1);
      expect(result, {1});
    });

    test("Listener is notified on retainAll", () {
      buildListener();

      setNotifier.retainAll({1, 2});

      expect(listenerCallCount, 1);
      expect(result, {1, 2});
    });

    test("Listener is notified on retainWhere", () {
      buildListener();

      setNotifier.retainWhere((element) => element <= 2);

      expect(listenerCallCount, 1);
      expect(result, {1, 2});
    });
  });

  group('Tests for notification modes', () {
    group('when mode is normal', () {
      late SetNotifier<int> setNotifier;
      late int listenerCallCount;

      setUp(() {
        setNotifier = SetNotifier(
          data: {1, 2, 3},
          notificationMode: CustomNotifierMode.normal,
        );
        listenerCallCount = 0;
        setNotifier.addListener(() {
          listenerCallCount++;
        });
      });

      tearDown(() {
        setNotifier.dispose();
      });

      test('Adding existing value does not notify', () {
        final bool wasAdded = setNotifier.add(1);

        expect(wasAdded, false);
        expect(listenerCallCount, 0);
      });

      test('Adding new value notifies', () {
        final bool wasAdded = setNotifier.add(4);

        expect(wasAdded, true);
        expect(listenerCallCount, 1);
      });

      test('addAll always notifies even with existing values (bulk operation)',
          () {
        setNotifier.addAll({1, 2, 3});

        expect(listenerCallCount, 1);
      });

      test('addAll with empty set always notifies (bulk operation)', () {
        setNotifier.addAll({});

        expect(listenerCallCount, 1);
      });

      test('Removing existing value notifies', () {
        final bool wasRemoved = setNotifier.remove(1);

        expect(wasRemoved, true);
        expect(listenerCallCount, 1);
      });

      test('Removing non-existent value does not notify', () {
        final bool wasRemoved = setNotifier.remove(99);

        expect(wasRemoved, false);
        expect(listenerCallCount, 0);
      });

      test('removeAll with no matches does not notify', () {
        setNotifier.removeAll({99, 100});

        expect(listenerCallCount, 0);
      });

      test('removeAll with matches notifies', () {
        setNotifier.removeAll({1, 2});

        expect(listenerCallCount, 1);
        expect(setNotifier, {3});
      });

      test('removeWhere matching nothing does not notify', () {
        setNotifier.removeWhere((element) => element > 10);

        expect(listenerCallCount, 0);
      });

      test('removeWhere matching elements notifies', () {
        setNotifier.removeWhere((element) => element > 1);

        expect(listenerCallCount, 1);
        expect(setNotifier, {1});
      });

      test('retainAll keeping all does not notify', () {
        setNotifier.retainAll({1, 2, 3, 4, 5});

        expect(listenerCallCount, 0);
      });

      test('retainAll removing elements notifies', () {
        setNotifier.retainAll({1});

        expect(listenerCallCount, 1);
        expect(setNotifier, {1});
      });

      test('retainWhere keeping all does not notify', () {
        setNotifier.retainWhere((element) => element > 0);

        expect(listenerCallCount, 0);
      });

      test('retainWhere removing elements notifies', () {
        setNotifier.retainWhere((element) => element == 1);

        expect(listenerCallCount, 1);
        expect(setNotifier, {1});
      });

      test('clear on empty set does not notify', () {
        setNotifier.clear();
        expect(listenerCallCount, 1);

        setNotifier.clear();
        expect(listenerCallCount, 1);
      });

      test('clear on non-empty set notifies', () {
        setNotifier.clear();

        expect(listenerCallCount, 1);
        expect(setNotifier, isEmpty);
      });
    });

    group('when mode is always', () {
      late SetNotifier<int> setNotifier;
      late int listenerCallCount;

      setUp(() {
        setNotifier = SetNotifier(
          data: {1, 2, 3},
        );
        listenerCallCount = 0;
        setNotifier.addListener(() {
          listenerCallCount++;
        });
      });

      tearDown(() {
        setNotifier.dispose();
      });

      test('Adding existing value notifies', () {
        final bool wasAdded = setNotifier.add(1);

        expect(wasAdded, false);
        expect(listenerCallCount, 1);
      });

      test('Adding new value notifies', () {
        final bool wasAdded = setNotifier.add(4);

        expect(wasAdded, true);
        expect(listenerCallCount, 1);
      });

      test('addAll with existing values notifies', () {
        setNotifier.addAll({1, 2, 3});

        expect(listenerCallCount, 1);
      });

      test('Removing non-existent value notifies', () {
        final bool wasRemoved = setNotifier.remove(99);

        expect(wasRemoved, false);
        expect(listenerCallCount, 1);
      });

      test('removeAll with no matches notifies', () {
        setNotifier.removeAll({99, 100});

        expect(listenerCallCount, 1);
      });

      test('removeWhere matching nothing notifies', () {
        setNotifier.removeWhere((element) => element > 10);

        expect(listenerCallCount, 1);
      });

      test('retainAll keeping all notifies', () {
        setNotifier.retainAll({1, 2, 3, 4, 5});

        expect(listenerCallCount, 1);
      });

      test('retainWhere keeping all notifies', () {
        setNotifier.retainWhere((element) => element > 0);

        expect(listenerCallCount, 1);
      });

      test('clear on empty set notifies', () {
        setNotifier.clear();
        expect(listenerCallCount, 1);

        setNotifier.clear();
        expect(listenerCallCount, 2);
      });
    });

    group('when mode is manual', () {
      late SetNotifier<int> setNotifier;
      late int listenerCallCount;

      setUp(() {
        setNotifier = SetNotifier(
          data: {1, 2, 3},
          notificationMode: CustomNotifierMode.manual,
        );
        listenerCallCount = 0;
        setNotifier.addListener(() {
          listenerCallCount++;
        });
      });

      tearDown(() {
        setNotifier.dispose();
      });

      test('Operations do not trigger automatic notifications', () {
        setNotifier.add(4);
        setNotifier.remove(1);
        setNotifier.addAll({5, 6});

        expect(listenerCallCount, 0);

        setNotifier.notifyListeners();

        expect(listenerCallCount, 1);
      });

      test('Multiple operations then one manual notify', () {
        setNotifier.add(4);
        setNotifier.add(5);
        setNotifier.remove(1);

        expect(listenerCallCount, 0);
        expect(setNotifier, {2, 3, 4, 5});

        setNotifier.notifyListeners();
        expect(listenerCallCount, 1);
      });

      test('Manual mode works with transactions', () {
        setNotifier.startTransAction();
        setNotifier.add(4);
        setNotifier.add(5);
        setNotifier.endTransAction();

        expect(listenerCallCount, 0);

        setNotifier.notifyListeners();
        expect(listenerCallCount, 1);
      });
    });
  });

  group('Transaction tests', () {
    test('Transaction batches operations into one notification', () {
      final setNotifier = SetNotifier<int>(
        data: {1},
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      setNotifier.addListener(() {
        listenerCallCount++;
      });

      setNotifier.startTransAction();
      setNotifier.add(2);
      setNotifier.add(3);
      setNotifier.remove(1);
      expect(
        listenerCallCount,
        0,
        reason: 'No notification during transaction',
      );

      setNotifier.endTransAction();
      expect(
        listenerCallCount,
        1,
        reason: 'Single notification after transaction',
      );
      setNotifier.dispose();
    });

    test('Nested transactions are prevented', () {
      final setNotifier = SetNotifier<int>(data: {1, 2, 3});

      setNotifier.startTransAction();
      expect(
        () => setNotifier.startTransAction(),
        throwsAssertionError,
      );

      setNotifier.endTransAction();
      setNotifier.dispose();
    });

    test('Transaction respects _hasChanged flag', () {
      final setNotifier = SetNotifier<int>(
        data: {1, 2, 3},
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      setNotifier.addListener(() {
        listenerCallCount++;
      });

      setNotifier.startTransAction();
      // Trying to add existing elements doesn't change the set
      setNotifier.add(1);
      setNotifier.add(2);
      setNotifier.endTransAction();

      expect(listenerCallCount, 0, reason: 'No change occurred');
      setNotifier.dispose();
    });
  });

  group('Value getter immutability tests', () {
    test('value getter returns immutable view', () {
      final setNotifier = SetNotifier<int>(data: {1, 2, 3});
      final view = setNotifier.value;

      expect(() => view.add(4), throwsUnsupportedError);
      expect(() => view.remove(1), throwsUnsupportedError);
      expect(() => view.clear(), throwsUnsupportedError);
      setNotifier.dispose();
    });

    test('value getter reflects current state', () {
      final setNotifier = SetNotifier<int>(data: {1, 2, 3});

      expect(setNotifier.value, {1, 2, 3});

      setNotifier.add(4);
      expect(setNotifier.value, {1, 2, 3, 4});

      setNotifier.remove(1);
      expect(setNotifier.value, {2, 3, 4});

      setNotifier.dispose();
    });
  });

  group('Post-dispose tests', () {
    test('Operations after dispose throw on notify', () {
      final setNotifier = SetNotifier<int>(data: {1, 2, 3});
      setNotifier.dispose();

      // Operation modifies set but notification throws
      expect(() => setNotifier.add(4), throwsFlutterError);
    });
  });

  group('Edge case tests', () {
    test('Adding duplicate elements in normal mode', () {
      final setNotifier = SetNotifier<int>(
        data: {1, 2, 3},
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      setNotifier.addListener(() {
        listenerCallCount++;
      });

      // First add notifies
      setNotifier.add(4);
      expect(listenerCallCount, 1);

      // Second add of same element doesn't notify
      setNotifier.add(4);
      expect(listenerCallCount, 1);

      setNotifier.dispose();
    });

    test('addAll with all existing elements always notifies (bulk operation)',
        () {
      final setNotifier = SetNotifier<int>(
        data: {1, 2, 3},
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      setNotifier.addListener(() {
        listenerCallCount++;
      });

      // Even though no new elements added, bulk operations always notify
      setNotifier.addAll({1, 2, 3});
      expect(listenerCallCount, 1);

      setNotifier.dispose();
    });

    test('addAll with empty set always notifies (bulk operation)', () {
      final setNotifier = SetNotifier<int>(
        data: {1, 2, 3},
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      setNotifier.addListener(() {
        listenerCallCount++;
      });

      // Bulk operations always notify, even with empty input
      setNotifier.addAll({});
      expect(listenerCallCount, 1);

      setNotifier.dispose();
    });

    test('removeAll with no matching elements does not notify in normal mode',
        () {
      final setNotifier = SetNotifier<int>(
        data: {1, 2, 3},
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      setNotifier.addListener(() {
        listenerCallCount++;
      });

      setNotifier.removeAll({99, 100});
      expect(listenerCallCount, 0);

      setNotifier.dispose();
    });

    test('removeWhere with no matches does not notify in normal mode', () {
      final setNotifier = SetNotifier<int>(
        data: {1, 2, 3},
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      setNotifier.addListener(() {
        listenerCallCount++;
      });

      setNotifier.removeWhere((element) => element > 10);
      expect(listenerCallCount, 0);

      setNotifier.dispose();
    });

    test('retainAll keeping everything does not notify in normal mode', () {
      final setNotifier = SetNotifier<int>(
        data: {1, 2, 3},
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      setNotifier.addListener(() {
        listenerCallCount++;
      });

      setNotifier.retainAll({1, 2, 3, 4, 5});
      expect(listenerCallCount, 0);

      setNotifier.dispose();
    });

    test('retainWhere keeping everything does not notify in normal mode', () {
      final setNotifier = SetNotifier<int>(
        data: {1, 2, 3},
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      setNotifier.addListener(() {
        listenerCallCount++;
      });

      setNotifier.retainWhere((element) => true);
      expect(listenerCallCount, 0);

      setNotifier.dispose();
    });

    test('clear on empty set does not notify in normal mode', () {
      final setNotifier = SetNotifier<int>(
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      setNotifier.addListener(() {
        listenerCallCount++;
      });

      setNotifier.clear();
      expect(listenerCallCount, 0);

      setNotifier.dispose();
    });

    test('Set operations return new sets (read-only)', () {
      final setNotifier = SetNotifier<int>(data: {1, 2, 3});

      int listenerCallCount = 0;
      setNotifier.addListener(() {
        listenerCallCount++;
      });

      // These operations return NEW sets, don't modify current set
      final union = setNotifier.union({4, 5});
      final intersection = setNotifier.intersection({2, 3, 4});
      final difference = setNotifier.difference({3});

      expect(union, {1, 2, 3, 4, 5});
      expect(intersection, {2, 3});
      expect(difference, {1, 2});

      // Original set unchanged
      expect(setNotifier, {1, 2, 3});

      // No notifications triggered
      expect(listenerCallCount, 0);

      setNotifier.dispose();
    });

    test('Mixed operations in single transaction', () {
      final setNotifier = SetNotifier<int>(
        data: {1, 2, 3},
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      setNotifier.addListener(() {
        listenerCallCount++;
      });

      setNotifier.startTransAction();
      setNotifier.add(4);
      setNotifier.remove(1);
      setNotifier.addAll({5, 6});
      setNotifier.removeWhere((element) => element == 2);
      setNotifier.endTransAction();

      expect(listenerCallCount, 1);
      expect(setNotifier, {3, 4, 5, 6});

      setNotifier.dispose();
    });
  });
}
