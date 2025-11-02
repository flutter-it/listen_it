# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Package Overview

**listen_it** provides reactive primitives for Flutter:
- **ValueListenable operators**: Extension methods that enable RxJS-like functional programming (map, where, select, debounce, combineLatest, mergeWith, etc.)
- **Reactive collections**: ListNotifier, MapNotifier, SetNotifier that automatically notify listeners on mutations
- **CustomValueNotifier**: A ValueNotifier with configurable notification modes

Previously published as `functional_listener`. Now includes reactive collections from `listenable_collections`.

## Development Commands

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/listenable_pipe_test.dart
flutter test test/collections/list_notifier_test.dart

# Analyze code
flutter analyze

# Format code (REQUIRED before commits)
dart format .

# Run example app
cd example && flutter run

# Publish (dry run)
flutter pub publish --dry-run
```

## Architecture & Design Principles

### Core Concepts

1. **Lazy Chain Initialization**
   - Operator chains (map, where, select, etc.) don't subscribe to sources until a listener is added
   - `FunctionalValueNotifier` base class implements lazy initialization via `addListener` override
   - `chainInitialized` flag prevents double subscription

2. **ValueListenable-Based**
   - All operators return new `ValueListenable` instances (not ValueNotifier)
   - Operators can be chained: `source.where(test).map(transform).debounce(duration)`
   - Each operator in the chain maintains a reference to `previousInChain`

3. **Subscription Management**
   - `ListenableSubscription` object returned by `.listen()` allows cancellation
   - Subscriptions can be canceled from within the handler itself
   - Handler receives subscription as parameter for self-cancellation

### Reactive Collections Design

**Three notification modes** (CustomNotifierMode):
- `normal`: Only notify on actual value changes (compares using `==` or customEquality)
- `always`: Notify on every operation (default to avoid UI update confusion)
- `manual`: No automatic notifications - must call `notifyListeners()` manually

**Why `always` is default**: If users haven't overridden `==` operator, they expect UI updates even when setting the "same" value.

**Transaction support**:
- `startTransAction()` / `endTransAction()` batch operations into single notification
- `_inTransaction` flag suppresses notifications during transaction
- `_hasChanged` tracks whether changes occurred

**Collections extend DelegatingList/Map/Set** from package:collection
- Override mutation methods to trigger notifications
- Provide `.value` getter returning unmodifiable view
- Implement `ValueListenable<List<T>>` / `ValueListenable<Map<K,V>>` / `ValueListenable<Set<T>>`

### ValueListenable Operators

**Key operator implementations**:

- `map<TResult>`: Creates `MapValueNotifier<TIn, TOut>` that transforms values
- `select<TResult>`: Creates `SelectValueNotifier` that only notifies when selector result changes
- `where`: Creates `WhereValueNotifier` that filters updates (initial value always passes)
- `debounce`: Creates `DebouncedValueNotifier` with Timer to delay notifications
- `async`: Creates `AsyncValueNotifier` that defers updates to next frame (prevents setState-during-build)
- `combineLatest`: Creates `CombiningValueNotifier` that merges 2-6 ValueListenables
- `mergeWith`: Creates `MergingValueNotifiers` that merges list of ValueListenables

**Disposal chain**:
- All `FunctionalValueNotifier` subclasses override `dispose()` to remove listener from `previousInChain`
- Proper cleanup prevents memory leaks in operator chains

## File Structure

```
lib/
├── listen_it.dart              # Main library (operators + collections)
├── collections.dart            # Collections-only library
└── src/
    ├── functional_value_notifiers.dart    # Operator implementations (Map, Select, Where, etc.)
    ├── functional_change_notifiers.dart   # Listenable operators (debounce on ChangeNotifier)
    ├── custom_value_notifier.dart         # CustomValueNotifier + CustomNotifierMode enum
    └── collections/
        ├── list_notifier.dart
        ├── map_notifier.dart
        └── set_notifier.dart

test/
├── listenable_pipe_test.dart              # Tests for ValueListenable operators
└── collections/
    ├── list_notifier_test.dart
    ├── map_notifier_test.dart
    └── set_notifier_test.dart
```

## Common Patterns

### Using Operators

```dart
// Chain operators together
final source = ValueNotifier<int>(0);

source
    .where((x) => x.isEven)
    .map<String>((x) => x.toString())
    .debounce(Duration(milliseconds: 500))
    .listen((value, subscription) {
      print(value);
      if (value == "100") subscription.cancel();
    });
```

### Using Reactive Collections

```dart
// Create collection with notification mode
final items = ListNotifier<String>(
  data: ['initial'],
  notificationMode: CustomNotifierMode.normal,
);

// Use transactions for bulk operations
items.startTransAction();
items.add('item1');
items.add('item2');
items.add('item3');
items.endTransAction();  // Single notification

// Use with ValueListenableBuilder
ValueListenableBuilder<List<String>>(
  valueListenable: items,
  builder: (context, list, _) => ListView(
    children: list.map((item) => Text(item)).toList(),
  ),
);
```

### select() vs where()

- `select()`: Only propagates when the **selected property** changes (even if object changes)
- `where()`: Filters which values propagate based on predicate

```dart
final user = ValueNotifier(User(age: 18, name: "John"));

// Only notifies when age changes
final age = user.select<int>((u) => u.age);

// Only notifies when age is even
final evenAge = user.where((u) => u.age.isEven);
```

## Testing Patterns

- Test operator chains by adding listeners and verifying values
- Test that operators properly filter/transform notifications
- Test disposal cleanup by checking that listeners are removed
- Test collections in all three notification modes
- Test transaction behavior for collections

## Important Constraints

1. **where() initial value caveat**: The filter can't work on initial value, so it always passes through. Not recommended inside Widget tree with `setState` as it recreates the notifier.

2. **debounce() with setState caveat**: Using debounce inside Widget tree with `setState` can cause issues. Better to use in model objects.

3. **Pure Dart**: This package works without Flutter dependency for core operators (only collections use Flutter's ChangeNotifier)

4. **Type safety**: All operators maintain compile-time type checking

5. **No code generation**: Entire package avoids build_runner

## Integration with flutter_it Ecosystem

- **watch_it**: Use listen_it operators with watch_it's reactive widgets
- **command_it**: Commands use listen_it internally for ValueListenable operations
- **get_it**: Often combined - register ValueNotifiers in get_it, use listen_it operators to transform them

## Version History Notes

- v5.1.0: Merged listenable_collections into listen_it
- Previously: `functional_listener` (old package name)
- Collections were: `listenable_collections` (now integrated)
