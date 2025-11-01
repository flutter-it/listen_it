import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier, ValueListenable;
import 'package:listen_it/src/custom_value_notifier.dart';

/// A List that behaves like `ValueNotifier` if its data changes.
///
/// ## Notification Modes
///
/// - **[CustomNotifierMode.normal]**: Listeners are only notified when a value
///   actually changes. For example, setting an index to the same value it
///   already has will not notify listeners. No-op operations (like removing a
///   non-existent value) also won't notify.
///
/// - **[CustomNotifierMode.always]**: Listeners are notified on every operation,
///   even if the value doesn't change. This ensures UI always updates when
///   operations are attempted.
///
/// - **[CustomNotifierMode.manual]**: No automatic notifications. You must call
///   [notifyListeners] manually after making changes.
///
/// ## Bulk Operations
///
/// Two categories of bulk operations:
/// - **Append/Insert operations** ([addAll], [insertAll], [setAll], [setRange]):
///   Always notify listeners, even with empty input, regardless of notification
///   mode (except [manual]).
/// - **Replace operations** ([fillRange], [replaceRange]): Compare values in
///   normal mode and only notify if changes occurred.
///
/// ## Transactions
///
/// Use [startTransAction] and [endTransAction] to batch multiple operations
/// into a single notification. This is useful for atomic updates.
class ListNotifier<T> extends DelegatingList<T>
    with ChangeNotifier
    implements ValueListenable<List<T>> {
  ///
  /// Creates a new listenable List
  /// [data] optional list that should be used as initial value.
  /// [notificationMode] determines whether to notify listeners if an equal value
  /// is assigned. If set to [CustomNotifierMode.normal], `ListNotifier` will
  /// compare if a value passed is equal to the existing value (e.g., `list[5]=4`
  /// will only call `notifyListeners` if the content at index 5 is not equal to 4).
  /// To prevent users from wondering why their UI doesn't update if they haven't
  /// overridden the equality operator, the default is [CustomNotifierMode.always].
  /// [customEquality] can be used to set your own criteria for comparing when
  /// [notificationMode] is set to [CustomNotifierMode.normal].
  ListNotifier({
    List<T>? data,
    CustomNotifierMode notificationMode = CustomNotifierMode.always,
    this.customEquality,
  })  : _notificationMode = notificationMode,
        super(data ?? []);

  final CustomNotifierMode _notificationMode;
  final bool Function(T x, T y)? customEquality;

  /// if this is `true` no listener will be notified if the list changes.
  bool _inTransaction = false;
  bool _hasChanged = false;

  /// Starts a transaction that allows to make multiple changes to the List
  /// with only one notification at the end.
  ///
  /// During a transaction, operations update the list but don't trigger
  /// notifications until [endTransAction] is called. The [_hasChanged] flag
  /// tracks whether any actual changes occurred during the transaction.
  ///
  /// Nested transactions are not allowed and will cause an assertion error.
  ///
  /// Example:
  /// ```dart
  /// list.startTransAction();
  /// list.add(1);
  /// list.add(2);
  /// list.add(3);
  /// list.endTransAction();  // Single notification for all changes
  /// ```
  void startTransAction() {
    assert(!_inTransaction, 'Only one transaction at a time in ListNotifier');
    _inTransaction = true;
  }

  /// Ends a transaction
  void endTransAction({bool notify = true}) {
    assert(_inTransaction, 'No active transaction in ListNotifier');
    _inTransaction = false;
    _notify(endofTransaction: true);
  }

  /// Swaps elements at [index1] with [index2].
  ///
  /// If the elements are equal (according to [customEquality] or default
  /// equality), no notification is triggered as the list hasn't changed.
  ///
  /// The swap uses the superclass setter to avoid triggering intermediate
  /// notifications, then calls [_notify] once at the end.
  void swap(int index1, int index2) {
    final temp1 = this[index1];
    final temp2 = this[index2];
    if (customEquality?.call(temp1, temp2) ?? temp1 == temp2) {
      return;
    }
    // we use super here to avoid triggering the notify function
    super[index1] = temp2;
    super[index2] = temp1;
    _hasChanged = true;
    _notify();
  }

  void _notify({bool endofTransaction = false}) {
    if (_inTransaction && !endofTransaction) {
      return;
    }
    switch (_notificationMode) {
      case CustomNotifierMode.normal:
        if (_hasChanged) {
          notifyListeners();
        }
        break;
      case CustomNotifierMode.always:
        notifyListeners();
        break;
      case CustomNotifierMode.manual:
        break;
    }
    _hasChanged = false;
  }

  /// If needed you can notifiy all listeners manually
  void notifyListeners() => super.notifyListeners();

  /// Returns an immutable view of the current list state.
  ///
  /// This getter returns an [UnmodifiableListView], which prevents external
  /// code from modifying the list without going through the notification
  /// system. Any attempt to mutate the returned view will throw an
  /// [UnsupportedError].
  ///
  /// The view always reflects the current state of the list.
  @override
  List<T> get value => UnmodifiableListView<T>(this);

  /// from here all functions are equal to `List<T>` with the addition that all
  /// modifying functions will call `notifyListener` if not in a transaction.

  @override
  set length(int value) {
    _hasChanged = length != value;
    super.length = value;
    _notify();
  }

  @override
  T operator [](int index) => super[index];

  @override
  void operator []=(int index, T value) {
    final areEqual =
        customEquality?.call(super[index], value) ?? super[index] == value;
    super[index] = value;

    _hasChanged = !areEqual;
    _notify();
  }

  @override
  void add(T value) {
    super.add(value);
    _hasChanged = true;
    _notify();
  }

  @override
  void addAll(Iterable<T> iterable) {
    super.addAll(iterable);
    _hasChanged = true;
    _notify();
  }

  @override
  void clear() {
    _hasChanged = isNotEmpty;
    super.clear();
    _notify();
  }

  @override
  void fillRange(int start, int end, [T? fillValue]) {
    if (null is! T && fillValue == null) {
      throw ArgumentError.value(fillValue, 'fillValue', 'must not be null');
    }
    if (_notificationMode == CustomNotifierMode.normal) {
      /// we only need to check if the value is equal if we are in normal mode
      if (fillValue == null) {
        _hasChanged = sublist(start, end).any((element) => element != null);
      } else {
        _hasChanged = sublist(start, end).any((element) =>
            customEquality?.call(element, fillValue) ?? element != fillValue);
      }
    }
    super.fillRange(start, end, fillValue);
    _notify();
  }

  @override
  void insert(int index, T element) {
    super.insert(index, element);
    _hasChanged = true;
    _notify();
  }

  @override
  void insertAll(int index, Iterable<T> iterable) {
    super.insertAll(index, iterable);
    _hasChanged = true;
    _notify();
  }

  @override
  bool remove(Object? value) {
    final wasRemoved = super.remove(value);
    _hasChanged = wasRemoved;
    _notify();
    return wasRemoved;
  }

  @override
  T removeAt(int index) {
    final val = super.removeAt(index);
    _hasChanged = true;
    _notify();
    return val;
  }

  @override
  T removeLast() {
    final val = super.removeLast();
    _hasChanged = true;
    _notify();
    return val;
  }

  @override
  void removeRange(int start, int end) {
    super.removeRange(start, end);
    _hasChanged = true;
    _notify();
  }

  @override
  void removeWhere(bool Function(T) test) {
    super.removeWhere((element) {
      final result = test(element);
      if (result) {
        _hasChanged = true;
      }
      return result;
    });
    _notify();
  }

  @override
  void replaceRange(int start, int end, Iterable<T> iterable) {
    if (_notificationMode == CustomNotifierMode.normal) {
      /// we only need to check if the value is equal if we are in normal mode
      _hasChanged = !IterableEquality().equals(sublist(start, end), iterable);
    } else {
      _hasChanged = true;
    }
    super.replaceRange(start, end, iterable);
    _notify();
  }

  @override
  void retainWhere(bool Function(T) test) {
    super.retainWhere((element) {
      final result = test(element);
      if (!result) {
        _hasChanged = true;
      }
      return result;
    });
    _notify();
  }

  @override
  void setAll(int index, Iterable<T> iterable) {
    super.setAll(index, iterable);

    /// This function will always notify listeners unless [notificationMode] is set to [manual]
    _hasChanged = true;
    _notify();
  }

  @override
  void setRange(int start, int end, Iterable<T> iterable, [int skipCount = 0]) {
    super.setRange(start, end, iterable, skipCount);

    /// This function will always notify listeners unless [notificationMode] is set to [manual]
    _hasChanged = true;
    _notify();
  }

  @override
  void shuffle([math.Random? random]) {
    super.shuffle(random);

    /// This function will always notify listeners unless [notificationMode] is set to [manual]
    _hasChanged = true;
    _notify();
  }

  @override
  void sort([int Function(T, T)? compare]) {
    super.sort(compare);

    /// This function will always notify listeners unless [notificationMode] is set to [manual]
    _hasChanged = true;
    _notify();
  }
}
