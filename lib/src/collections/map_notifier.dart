import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:listen_it/src/custom_value_notifier.dart';

/// A Map that behaves like `ValueNotifier` if its data changes.
///
/// ## Notification Modes
///
/// - **[CustomNotifierMode.normal]**: Listeners are only notified when a value
///   actually changes. For example, setting a key to the same value it already
///   has will not notify listeners. No-op operations (like removing a
///   non-existent key) also won't notify.
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
/// Bulk operations like [addAll] and [addEntries] always notify listeners,
/// even with empty input, regardless of notification mode (except [manual]).
/// This ensures consistent behavior and prevents subtle bugs.
///
/// ## Transactions
///
/// Use [startTransAction] and [endTransAction] to batch multiple operations
/// into a single notification. This is useful for atomic updates.
///
/// ## Examples
///
/// ```dart
/// // Normal mode - only notifies on actual changes
/// final mapNotifier = MapNotifier(
///   data: {'one': 1},
///   notificationMode: CustomNotifierMode.normal,
/// );
/// mapNotifier['one'] = 1;  // No notification (same value)
/// mapNotifier['one'] = 2;  // Notifies (value changed)
/// mapNotifier.remove('missing');  // No notification (key doesn't exist)
///
/// // Always mode - notifies on every operation
/// final alwaysMap = MapNotifier(
///   data: {'one': 1},
///   notificationMode: CustomNotifierMode.always,
/// );
/// alwaysMap['one'] = 1;  // Notifies even though value is same
/// ```
class MapNotifier<K, V> extends DelegatingMap<K, V>
    with ChangeNotifier
    implements ValueListenable<Map<K, V>> {
  /// Creates a new listenable Map
  /// [data] optional map that should be used as initial value
  /// [notificationMode] determines whether to notify listeners if an equal value is assigned to
  /// a key. To not make users wonder why their UI doesn't update if they
  /// assign the same value to a key, the default is [always].
  /// [customEquality] can be used to set your own criteria for comparing
  /// values, which might be important notificationMode is set to [normal].
  MapNotifier({
    Map<K, V>? data,
    CustomNotifierMode notificationMode = CustomNotifierMode.always,
    this.customEquality,
  })  : _notificationMode = notificationMode,
        super(data ?? {});

  /// Determines whether to notify listeners if an equal value is assigned to
  /// a key.
  /// For example, if set to [normal] , the code below will not notify
  /// listeners:
  /// '''
  ///   final mapNotifier = MapNotifier(data: {'one': 1});
  ///   mapNotifier['one'] = 1
  /// '''
  /// If set to [always], listeners would be notified of any values that are
  /// assigned, even when equal.
  /// If set to [manual], listeners would not be notified of any values that are
  /// assigned, even when not equal. You have to call [notifyListeners] manually
  final CustomNotifierMode _notificationMode;

  /// [customEquality] can be used to set your own criteria for comparing
  /// values, which might be important if [notificationMode] is set to [normal].
  /// The function should return a bool that represents if, when compared, two
  /// values are equal. If null, the default values equality [==] is used.
  final bool Function(V? x, V? y)? customEquality;

  /// if this is `true` no listener will be notified if the map changes.
  bool _inTransaction = false;
  bool _hasChanged = false;

  /// Starts a transaction that allows to make multiple changes to the Map
  /// with only one notification at the end.
  ///
  /// During a transaction, operations update the map but don't trigger
  /// notifications until [endTransAction] is called. The [_hasChanged] flag
  /// tracks whether any actual changes occurred during the transaction.
  ///
  /// Nested transactions are not allowed and will cause an assertion error.
  ///
  /// Example:
  /// ```dart
  /// mapNotifier.startTransAction();
  /// mapNotifier['a'] = 1;
  /// mapNotifier['b'] = 2;
  /// mapNotifier['c'] = 3;
  /// mapNotifier.endTransAction();  // Single notification for all changes
  /// ```
  void startTransAction() {
    assert(!_inTransaction, 'Only one transaction at a time in a MapNotifier');
    _inTransaction = true;
  }

  /// Ends a transaction
  void endTransAction() {
    assert(_inTransaction, 'No active transaction in a MapNotifier');
    _inTransaction = false;
    _notify(endofTransaction: true);
  }

  /// Returns an immutable view of the current map state.
  ///
  /// This getter returns an [UnmodifiableMapView], which prevents external
  /// code from modifying the map without going through the notification
  /// system. Any attempt to mutate the returned view will throw an
  /// [UnsupportedError].
  ///
  /// The view always reflects the current state of the map.
  @override
  Map<K, V> get value => UnmodifiableMapView(this);

  @override
  V? operator [](Object? key) => super[key];

  @override
  void operator []=(K key, V value) {
    final areEqual = customEquality == null
        ? super[key] == value
        : customEquality!(super[key], value);
    super[key] = value;

    _hasChanged = !areEqual;
    _notify();
  }

  @override
  void addAll(Map<K, V> other) {
    super.addAll(other);
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
      case CustomNotifierMode.always:
        notifyListeners();
      case CustomNotifierMode.manual:
        break;
    }
    _hasChanged = false;
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
  }

  @override
  void addEntries(Iterable<MapEntry<K, V>> entries) {
    super.addEntries(entries);
    _hasChanged = true;
    _notify();
  }

  @override
  void clear() {
    _hasChanged = isNotEmpty;
    super.clear();
    _notify();
  }

  /// Adds [key]/[value] pair to the map if [key] is not already present.
  ///
  /// If the key doesn't exist, [ifAbsent] is called to generate the value,
  /// which is then added to the map. This triggers a notification.
  ///
  /// If the key already exists:
  /// - In [CustomNotifierMode.normal]: No notification (no change occurred)
  /// - In [CustomNotifierMode.always]: Notifies (operation was attempted)
  /// - In [CustomNotifierMode.manual]: No notification
  ///
  /// Note: When the key exists, [ifAbsent] is NOT called.
  @override
  V putIfAbsent(K key, V Function() ifAbsent) {
    final exists = containsKey(key);
    if (!exists) {
      final value = ifAbsent();
      super[key] = value;
      _hasChanged = true;
      _notify();
      return value;
    }
    // In always mode, notify even when key exists (operation was attempted)
    if (_notificationMode == CustomNotifierMode.always) {
      _notify();
    }
    return this[key]!;
  }

  @override
  V? remove(Object? key) {
    final exists = containsKey(key);
    final lookedUpValue = this[key];
    _hasChanged = exists;
    super.remove(key);
    _notify();

    return lookedUpValue;
  }

  @override
  void removeWhere(bool Function(K, V) test) {
    super.removeWhere((key, value) {
      final result = test(key, value);
      if (result) {
        _hasChanged = true;
      }
      return result;
    });

    _notify();
  }

  @override
  V update(K key, V Function(V) update, {V Function()? ifAbsent}) {
    if (containsKey(key)) {
      final lookedUpValue = this[key] as V;
      final newValue = update(lookedUpValue);
      super[key] = newValue;
      _hasChanged = customEquality?.call(newValue, lookedUpValue) == false ||
          (customEquality == null && newValue != lookedUpValue);
      _notify();
      return newValue;
    }

    if (ifAbsent != null) {
      final newValue = ifAbsent();
      super[key] = newValue;
      _hasChanged = true;
      _notify();
      return newValue;
    }

    throw ArgumentError.value(key, 'key', 'Key not in map');
  }

  @override
  void updateAll(V Function(K, V) update) {
    super.updateAll((key, value) {
      final newValue = update(key, value);
      final areEqual =
          customEquality?.call(newValue, value) ?? newValue == value;
      _hasChanged = _hasChanged || !areEqual;
      return newValue;
    });

    _notify();
  }
}
