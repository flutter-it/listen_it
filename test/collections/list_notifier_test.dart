import 'package:flutter_test/flutter_test.dart';
import 'package:listen_it/listen_it.dart';

void main() {
  group("Tests for the ListNotifier's methods", () {
    late ListNotifier<int> list;
    List result = [];
    int listenerCallCount = 0;

    setUp(() {
      list = ListNotifier(data: [1, 2, 3]);
      result.clear();
      listenerCallCount = 0;
    });

    void buildListener() {
      list.addListener(() {
        listenerCallCount++;
        result = [...list.value];
      });
    }

    test("Elements get swapped correctly", () {
      buildListener();

      list.swap(0, 2);

      expect(listenerCallCount, 1);
      expect(result, [3, 2, 1]);
    });

    test("Listeners get updated if a value gets added", () {
      buildListener();

      list.add(4);

      expect(listenerCallCount, 1);
      expect(result, [1, 2, 3, 4]);
    });

    test("Listeners get notified if an iterable is added", () {
      buildListener();

      list.addAll([4, 5]);

      expect(listenerCallCount, 1);
      expect(result, [1, 2, 3, 4, 5]);
    });

    test("Listeners get notified if the list is cleared", () {
      buildListener();

      list.clear();

      expect(listenerCallCount, 1);
      expect(result, []);
    });

    test("Listeners get notified on fillRange", () {
      buildListener();

      list.fillRange(0, list.length, 1);

      expect(listenerCallCount, 1);
      expect(result, [1, 1, 1]);
    });

    test("Listeners get notified on value insertion", () {
      buildListener();

      list.insert(1, 1);

      expect(listenerCallCount, 1);
      expect(result, [1, 1, 2, 3]);
    });

    test("Listeners get notified on iterable insertion", () {
      buildListener();

      list.insertAll(1, [1, 2]);

      expect(listenerCallCount, 1);
      expect(result, [1, 1, 2, 2, 3]);
    });

    test("Listeners get notified on value removal", () {
      buildListener();

      final itemIsRemoved = list.remove(2);

      expect(listenerCallCount, 1);
      expect(result, [1, 3]);
      expect(itemIsRemoved, true);
    });

    test("Listeners get notified on index removal", () {
      buildListener();

      final removedItem = list.removeAt(1);

      expect(listenerCallCount, 1);
      expect(result, [1, 3]);
      expect(removedItem, 2);
    });

    test("Listeners get notified on last element removal", () {
      buildListener();

      final itemRemoved = list.removeLast();

      expect(listenerCallCount, 1);
      expect(result, [1, 2]);
      expect(itemRemoved, 3);
    });

    test("Listeners get notified on range removal", () {
      buildListener();

      list.removeRange(0, 2);

      expect(listenerCallCount, 1);
      expect(result, [3]);
    });

    test("Listeners get notified on removeWhere", () {
      buildListener();

      list.removeWhere((element) => element == 1);

      expect(listenerCallCount, 1);
      expect(result, [2, 3]);
    });

    test("Listeners get notified on replaceRange", () {
      buildListener();

      list.replaceRange(0, 2, [3, 3]);

      expect(listenerCallCount, 1);
      expect(result, [3, 3, 3]);
    });

    test("Listeners get notified on retainWhere", () {
      buildListener();

      list.retainWhere((element) => element == 1);

      expect(listenerCallCount, 1);
      expect(result, [1]);
    });

    test("Listeners get notified on setAll", () {
      buildListener();

      list.setAll(2, [2]);

      expect(listenerCallCount, 1);
      expect(result, [1, 2, 2]);
    });

    test("Listeners get notified on setRange", () {
      buildListener();

      list.setRange(2, list.length, [2]);

      expect(listenerCallCount, 1);
      expect(result, [1, 2, 2]);
    });

    test("Listeners get notified on shuffle", () {
      buildListener();

      list.shuffle();

      expect(listenerCallCount, 1);
      expect(result.toSet(), {1, 2, 3}); // Verify same elements
    });

    test("Listeners get notified on sort", () {
      buildListener();

      list.sort((value1, value2) => value2.compareTo(value1));

      expect(listenerCallCount, 1);
      expect(result, [3, 2, 1]);
    });
  });

  group("Tests for the ListNotifier's equality", () {
    List? result;

    setUp(() {
      result = null;
    });

    test("The listener isn't notified if the value is equal", () {
      final ListNotifier list = ListNotifier(
        data: [1, 2, 3],
        notificationMode: CustomNotifierMode.normal,
      );

      list.addListener(() {
        result = [...list.value];
      });

      list[0] = 1;

      expect(result, null);
    });

    test("customEquality works correctly", () {
      // Compare absolute values: -2 and 2 are considered equal
      final ListNotifier<int> list = ListNotifier(
        data: [1, -2, 3],
        notificationMode: CustomNotifierMode.normal,
        customEquality: (x, y) => x.abs() == y.abs(),
      );

      int listenerCallCount = 0;
      list.addListener(() {
        listenerCallCount++;
      });

      // -2 -> 2: abs values are equal, should NOT notify
      list[1] = 2;
      expect(listenerCallCount, 0);

      // 2 -> 5: abs values differ, should notify
      list[1] = 5;
      expect(listenerCallCount, 1);
    });
  });

  group('Notification behavior tests', () {
    test('BUG: removeAt() should set _hasChanged BEFORE calling _notify()', () {
      final list = ListNotifier<int>(
        data: [1, 2, 3],
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      list.addListener(() {
        listenerCallCount++;
      });

      // This should notify because we're removing an element
      list.removeAt(1);

      expect(listenerCallCount, 1);
      expect(list, [1, 3]);
    });

    test('BUG: removeLast() should set _hasChanged BEFORE calling _notify()',
        () {
      final list = ListNotifier<int>(
        data: [1, 2, 3],
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      list.addListener(() {
        listenerCallCount++;
      });

      // This should notify because we're removing an element
      list.removeLast();

      expect(listenerCallCount, 1);
      expect(list, [1, 2]);
    });

    test('BUG: replaceRange() has inverted equality logic', () {
      final list = ListNotifier<int>(
        data: [1, 2, 3, 4, 5],
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      list.addListener(() {
        listenerCallCount++;
      });

      // Replace with SAME values - should NOT notify
      list.replaceRange(1, 3, [2, 3]);
      expect(listenerCallCount, 0, reason: 'Should not notify when unchanged');

      // Replace with DIFFERENT values - SHOULD notify
      list.replaceRange(1, 3, [20, 30]);
      expect(listenerCallCount, 1, reason: 'Should notify when changed');
      expect(list, [1, 20, 30, 4, 5]);
    });
  });

  group('Manual mode tests', () {
    test('Manual mode requires explicit notifyListeners', () {
      final list = ListNotifier<int>(
        data: [1, 2, 3],
        notificationMode: CustomNotifierMode.manual,
      );

      int listenerCallCount = 0;
      list.addListener(() {
        listenerCallCount++;
      });

      // Operations don't trigger notifications in manual mode
      list.add(4);
      list[0] = 10;
      list.remove(2);

      expect(listenerCallCount, 0);

      // Must call notifyListeners manually
      list.notifyListeners();

      expect(listenerCallCount, 1);
      list.dispose();
    });

    test('Multiple operations then one manual notify', () {
      final list = ListNotifier<int>(
        data: [1, 2, 3],
        notificationMode: CustomNotifierMode.manual,
      );

      int listenerCallCount = 0;
      list.addListener(() {
        listenerCallCount++;
      });

      list.addAll([4, 5, 6]);
      list.removeAt(0);
      list[0] = 20;

      expect(listenerCallCount, 0);

      list.notifyListeners();
      expect(listenerCallCount, 1);
      expect(list, [20, 3, 4, 5, 6]);
      list.dispose();
    });
  });

  group('Transaction tests', () {
    test('Transaction batches operations into one notification', () {
      final list = ListNotifier<int>(
        data: [1, 2, 3],
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      list.addListener(() {
        listenerCallCount++;
      });

      list.startTransAction();
      list.add(4);
      list.add(5);
      list.remove(1);
      expect(
        listenerCallCount,
        0,
        reason: 'No notification during transaction',
      );

      list.endTransAction();
      expect(
        listenerCallCount,
        1,
        reason: 'Single notification after transaction',
      );
      list.dispose();
    });

    test('Nested transactions are prevented', () {
      final list = ListNotifier<int>(data: [1, 2, 3]);

      list.startTransAction();
      expect(
        () => list.startTransAction(),
        throwsAssertionError,
      );

      list.endTransAction();
      list.dispose();
    });
  });

  group('Value getter immutability tests', () {
    test('value getter returns immutable view', () {
      final list = ListNotifier<int>(data: [1, 2, 3]);
      final view = list.value;

      expect(() => view.add(4), throwsUnsupportedError);
      expect(() => view[0] = 5, throwsUnsupportedError);
      expect(() => view.clear(), throwsUnsupportedError);
      list.dispose();
    });

    test('value getter reflects current state', () {
      final list = ListNotifier<int>(data: [1, 2, 3]);

      expect(list.value, [1, 2, 3]);

      list.add(4);
      expect(list.value, [1, 2, 3, 4]);

      list.remove(1);
      expect(list.value, [2, 3, 4]);

      list.dispose();
    });
  });

  group('Post-dispose tests', () {
    test('Operations after dispose throw on notify', () {
      final list = ListNotifier<int>(data: [1, 2, 3]);
      list.dispose();

      // Operation modifies list but notification throws
      expect(() => list.add(4), throwsFlutterError);
    });
  });

  group('Edge case tests', () {
    test('removeWhere matching nothing does not notify in normal mode', () {
      final list = ListNotifier<int>(
        data: [1, 2, 3],
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      list.addListener(() {
        listenerCallCount++;
      });

      list.removeWhere((element) => element > 10);

      expect(listenerCallCount, 0);
      list.dispose();
    });

    test('retainWhere retaining all does not notify in normal mode', () {
      final list = ListNotifier<int>(
        data: [1, 2, 3],
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      list.addListener(() {
        listenerCallCount++;
      });

      list.retainWhere((element) => element > 0);

      expect(listenerCallCount, 0);
      list.dispose();
    });

    test('fillRange with same values does not notify in normal mode', () {
      final list = ListNotifier<int>(
        data: [1, 1, 1],
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      list.addListener(() {
        listenerCallCount++;
      });

      list.fillRange(0, 3, 1);

      expect(listenerCallCount, 0);
      list.dispose();
    });

    test('replaceRange with same values does not notify in normal mode', () {
      final list = ListNotifier<int>(
        data: [1, 2, 3, 4, 5],
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      list.addListener(() {
        listenerCallCount++;
      });

      list.replaceRange(1, 3, [2, 3]);

      expect(listenerCallCount, 0);
      list.dispose();
    });

    test('remove non-existent value does not notify in normal mode', () {
      final list = ListNotifier<int>(
        data: [1, 2, 3],
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      list.addListener(() {
        listenerCallCount++;
      });

      list.remove(99);

      expect(listenerCallCount, 0);
      list.dispose();
    });

    test('clear on empty list does not notify in normal mode', () {
      final list = ListNotifier<int>(
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      list.addListener(() {
        listenerCallCount++;
      });

      list.clear();

      expect(listenerCallCount, 0);
      list.dispose();
    });

    test('addAll empty list always notifies', () {
      final list = ListNotifier<int>(
        data: [1, 2, 3],
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      list.addListener(() {
        listenerCallCount++;
      });

      // Bulk operations always notify, even with empty input
      list.addAll([]);

      expect(listenerCallCount, 1);
      list.dispose();
    });

    test('insertAll empty list always notifies', () {
      final list = ListNotifier<int>(
        data: [1, 2, 3],
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      list.addListener(() {
        listenerCallCount++;
      });

      // Bulk operations always notify, even with empty input
      list.insertAll(0, []);

      expect(listenerCallCount, 1);
      list.dispose();
    });

    test('setAll empty list always notifies', () {
      final list = ListNotifier<int>(
        data: [1, 2, 3],
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      list.addListener(() {
        listenerCallCount++;
      });

      // Bulk operations always notify, even with empty input
      list.setAll(0, []);

      expect(listenerCallCount, 1);
      list.dispose();
    });

    test('swap identical elements does not notify', () {
      final list = ListNotifier<int>(
        data: [1, 2, 1],
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      list.addListener(() {
        listenerCallCount++;
      });

      // Swapping identical elements (1 with 1) doesn't change the list
      list.swap(0, 2);

      expect(listenerCallCount, 0);
      list.dispose();
    });

    test('swap different elements notifies', () {
      final list = ListNotifier<int>(
        data: [1, 2, 3],
        notificationMode: CustomNotifierMode.normal,
      );

      int listenerCallCount = 0;
      list.addListener(() {
        listenerCallCount++;
      });

      list.swap(0, 2);

      expect(listenerCallCount, 1);
      expect(list, [3, 2, 1]);
      list.dispose();
    });
  });
}
