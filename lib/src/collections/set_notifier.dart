import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier, ValueListenable;
import 'package:listen_it/src/custom_value_notifier.dart';

/// A Set that behaves like `ValueNotifier` if its data changes.
///
/// ## Notification Modes
///
/// - **[CustomNotifierMode.normal]**: Listeners are only notified when a value
///   actually changes. For example, adding an element that already exists in
///   the set will not notify listeners. No-op operations (like removing a
///   non-existent element) also won't notify.
///
/// - **[CustomNotifierMode.always]**: Listeners are notified on every operation,
///   even if the set doesn't change. This ensures UI always updates when
///   operations are attempted.
///
/// - **[CustomNotifierMode.manual]**: No automatic notifications. You must call
///   [notifyListeners] manually after making changes.
///
/// ## Bulk Operations
///
/// Bulk operations like [addAll], [removeAll], and [retainAll] always notify
/// listeners, even with empty input, regardless of notification mode (except
/// [manual]). This ensures consistent behavior and prevents subtle bugs.
///
/// ## Transactions
///
/// Use [startTransAction] and [endTransAction] to batch multiple operations
/// into a single notification. This is useful for atomic updates.
///
/// ## Set Operations
///
/// Set operations like `union()`, `intersection()`, and `difference()` return
/// new sets and don't modify the current set, so they don't trigger
/// notifications and are not overridden.
///
/// ## Note on Equality
///
/// Unlike [ListNotifier] and [MapNotifier], SetNotifier does NOT support
/// custom equality functions. Sets inherently use `==` and `hashCode` for
/// membership testing, and custom equality would only apply to notification
/// decisions, which could be confusing. Use the built-in equality behavior.
///
/// ## Examples
///
/// ```dart
/// // Normal mode - only notifies on actual changes
/// final setNotifier = SetNotifier<int>(
///   data: {1, 2, 3},
///   notificationMode: CustomNotifierMode.normal,
/// );
/// setNotifier.add(1);  // No notification (already exists)
/// setNotifier.add(4);  // Notifies (new element added)
/// setNotifier.remove(99);  // No notification (doesn't exist)
///
/// // Always mode - notifies on every operation
/// final alwaysSet = SetNotifier<int>(
///   data: {1, 2, 3},
///   notificationMode: CustomNotifierMode.always,
/// );
/// alwaysSet.add(1);  // Notifies even though element exists
/// ```
class SetNotifier<T> extends DelegatingSet<T>
    with ChangeNotifier
    implements ValueListenable<Set<T>> {
  /// Creates a new listenable Set.
  ///
  /// [data] optional set that should be used as initial value.
  ///
  /// [notificationMode] determines whether to notify listeners if an operation
  /// doesn't change the set. To prevent users from wondering why their UI
  /// doesn't update if they haven't overridden the equality operator, the
  /// default is [CustomNotifierMode.always].
  SetNotifier({
    Set<T>? data,
    CustomNotifierMode notificationMode = CustomNotifierMode.always,
  })  : _notificationMode = notificationMode,
        super(data ?? {});

  /// Determines whether to notify listeners if an operation doesn't change
  /// the set.
  ///
  /// For example, if set to [CustomNotifierMode.normal], the code below will
  /// not notify listeners:
  /// ```dart
  ///   final setNotifier = SetNotifier<int>(
  ///     data: {1, 2, 3},
  ///     notificationMode: CustomNotifierMode.normal,
  ///   );
  ///   setNotifier.add(1);  // No notification - already exists
  /// ```
  ///
  /// If set to [CustomNotifierMode.always], listeners would be notified of any
  /// operation attempts, even when the set doesn't change.
  ///
  /// If set to [CustomNotifierMode.manual], listeners would not be notified
  /// automatically. You have to call [notifyListeners] manually.
  final CustomNotifierMode _notificationMode;

  /// if this is `true` no listener will be notified if the set changes.
  bool _inTransaction = false;
  bool _hasChanged = false;

  /// Starts a transaction that allows to make multiple changes to the Set
  /// with only one notification at the end.
  ///
  /// During a transaction, operations update the set but don't trigger
  /// notifications until [endTransAction] is called. The [_hasChanged] flag
  /// tracks whether any actual changes occurred during the transaction.
  ///
  /// Nested transactions are not allowed and will cause an assertion error.
  ///
  /// Example:
  /// ```dart
  /// setNotifier.startTransAction();
  /// setNotifier.add(1);
  /// setNotifier.add(2);
  /// setNotifier.add(3);
  /// setNotifier.endTransAction();  // Single notification for all changes
  /// ```
  void startTransAction() {
    assert(!_inTransaction, 'Only one transaction at a time in SetNotifier');
    _inTransaction = true;
  }

  /// Ends a transaction.
  void endTransAction() {
    assert(_inTransaction, 'No active transaction in SetNotifier');
    _inTransaction = false;
    _notify(endofTransaction: true);
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
      case CustomNotifierMode.always:
        notifyListeners();
      case CustomNotifierMode.manual:
        break;
    }
    _hasChanged = false;
  }

  /// If needed you can notify all listeners manually.
  @override
  void notifyListeners() => super.notifyListeners();

  /// Returns an immutable view of the current set state.
  ///
  /// This getter returns an [UnmodifiableSetView], which prevents external
  /// code from modifying the set without going through the notification
  /// system. Any attempt to mutate the returned view will throw an
  /// [UnsupportedError].
  ///
  /// The view always reflects the current state of the set.
  @override
  Set<T> get value => UnmodifiableSetView<T>(this);

  /// from here all functions are equal to `Set<T>` with the addition that all
  /// modifying functions will call `notifyListener` if not in a transaction.

  @override
  bool add(T value) {
    final wasAdded = super.add(value);
    _hasChanged = wasAdded;
    _notify();
    return wasAdded;
  }

  @override
  void addAll(Iterable<T> elements) {
    super.addAll(elements);

    /// This function will always notify listeners unless [notificationMode]
    /// is set to [CustomNotifierMode.manual]
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
  bool remove(Object? value) {
    final wasRemoved = super.remove(value);
    _hasChanged = wasRemoved;
    _notify();
    return wasRemoved;
  }

  @override
  void removeAll(Iterable<Object?> elements) {
    final initialLength = length;
    super.removeAll(elements);
    _hasChanged = length != initialLength;
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
  void retainAll(Iterable<Object?> elements) {
    final initialLength = length;
    super.retainAll(elements);
    _hasChanged = length != initialLength;
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
}
