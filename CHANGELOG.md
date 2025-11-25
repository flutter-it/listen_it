## [5.3.4] - 2025-11-25

- Restored working example project (was corrupted with memory test code)
- Memory test example preserved in `memory_test/` folder

## [5.3.3] - 2025-01-12

- Use absolute GitHub URL for logo in README

## [5.3.2] - 2025-01-12

- Fixed logo display on pub.dev by using relative path

## [5.3.1] - 2025-01-12

- Fixed button sizing in README for pub.dev display

## [5.3.0] - 2025-01-12

### New Feature

- **Added `lazy` parameter to all operators** (addresses [issue #1](https://github.com/flutter-it/listen_it/issues/1))
  - All operators now support an optional `lazy` parameter to control when chains subscribe to sources
  - **All operators default to eager initialization** (`lazy=false`) to ensure `.value` is always correct
  - Eager initialization subscribes to sources immediately, making `.value` reliable even before adding listeners
  - Lazy initialization (`lazy=true`) delays subscription until first listener is added (memory optimization)
  - **Breaking change**: Chains now initialize eagerly by default (opt-in to lazy with `lazy: true`)

### Bug Fix

- **Fixed `mergeWith` stale value issue**
  - Previously, `mergeWith` only subscribed to sources when a listener was added
  - This meant `.value` could be stale if sources changed before adding a listener
  - Now with eager initialization (default), all sources are immediately subscribed
  - `.value` updates immediately when any source changes, even without listeners
  - Example that now works correctly:
    ```dart
    final notifier1 = ValueNotifier<int>(0);
    final notifier2 = ValueNotifier<int>(100);
    final merged = notifier1.mergeWith([notifier2]);

    notifier2.value = 200; // Change source WITHOUT listener
    print(merged.value); // Now correctly prints 200 (was 0 in v5.2.1)
    ```

### Implementation Details

- Added `lazy` parameter to `FunctionalValueNotifier` base class
- Updated all operator classes: `SelectValueNotifier`, `MapValueNotifier`, `WhereValueNotifier`, `DebouncedValueNotifier`, `AsyncValueNotifier`
- Updated `CombiningValueNotifier` classes (2-6 sources) with `lazy` parameter
- Added `chainInitialized` check in all `dispose()` methods to prevent errors when disposing uninitialized chains

### Tests

- Fixed test in `lazy_init_chain_test.dart` to pass `lazy: true` for mergeWith
- `lazy_value_test.dart` demonstrates the fix with output showing correct eager initialization
- All 200+ tests pass ✓

## [5.2.1] - 2025-01-12

### Internal Changes

- **Removed eager initialization from operator chains**
  - Chains now use true lazy initialization - they only subscribe to sources when the first listener is added
  - Removed redundant `init()` calls from constructors (leftover from v2.0.2 workaround)
  - This cleanup was possible after v4.0.0 removed automatic unsubscribe propagation
  - No behavior changes - chains still maintain persistent subscriptions after initialization

### Documentation

- **Updated terminology throughout documentation**
  - Changed "hot subscription model" to "lazy initialization with persistent subscriptions"
  - Updated README.md, best_practices.md, and operators/overview.md
  - Clearer explanation of chain lifecycle behavior

### Tests

- **Improved test coverage from 83.7% to 97.6%** (+13.9 percentage points)
  - Added comprehensive lazy initialization tests
  - Added tests for timer cancellation in debounce
  - Added tests for error handling, disposal, and reentrant listener removal
  - Fixed misleading test names to accurately describe what they test
  - All 199 tests pass ✓

## [5.2.0] - 2025-01-11

### New Feature

- **Added `fallbackValue` parameter to `where()` operator**
  - Solves the long-standing issue where the initial value always passes through the filter
  - When provided, `fallbackValue` is used if the initial value doesn't match the filter condition
  - Backward compatible - existing code continues to work without changes
  - Example: `source.where((x) => x.isEven, fallbackValue: 0)`

### Tests

- Added 3 new tests for `fallbackValue` behavior:
  - Fallback ignored when initial value matches filter
  - Fallback used when initial value doesn't match filter
  - Backward compatibility: no fallback provided (old behavior)
- All 119 tests pass ✓

## [5.1.1] - 2025-01-11

### Documentation & Testing Updates

- **Major documentation update**: Comprehensive chain lifecycle findings document added
- **Memory leak investigation**: Verified watch_it v2.0+ automatic protection against inline chain creation memory leaks
- **Test improvements**:
  - Added 19 comprehensive tests (17 lifecycle + 2 memory) proving chain behavior
  - Tests verify that `allowObservableChange: false` (watch_it default) prevents memory leaks from inline chain creation
  - Tests confirm inline chains are SAFE when using watch_it's default settings
- **Key finding**: Creating chains inline in watch_it selectors (e.g., `watchValue((m) => m.source.map(...))`) is now documented as SAFE due to automatic selector caching
- **Important**: ValueListenableBuilder with inline chains still requires manual chain storage outside build method

See `CHAIN_LIFECYCLE_FINDINGS.md` for complete details.

## [5.1.0] - 2025-11-01

**NEW FEATURE: Merged with listenable_collections**

This release merges the `listenable_collections` package into `listen_it`, creating a unified package for reactive primitives in Flutter.

### Breaking Changes
- None! This is a backward-compatible feature addition
- All existing `listen_it` functionality remains unchanged

### New Features
- **Reactive Collections**: Added `ListNotifier`, `MapNotifier`, and `SetNotifier` from listenable_collections
  - Lists, Maps, and Sets that automatically notify listeners when their contents change
  - Support for different notification modes (normal, always, manual)
  - Transaction support for batching multiple operations
  - Full compatibility with `ValueListenable` and `ValueListenableBuilder`

### Migration from listenable_collections
If you were using `listenable_collections`, migration is simple:
1. Update `pubspec.yaml`: Replace `listenable_collections` with `listen_it: ^5.1.0`
2. Update imports: Change `import 'package:listenable_collections/listenable_collections.dart';` to `import 'package:listen_it/listen_it.dart';`
3. All APIs remain identical - no code changes needed!

### Exports
- Main export (`listen_it.dart`): Includes both operators and collections
- Selective export (`collections.dart`): Collections only
- All existing exports remain unchanged

### Dependencies
- Added `collection: ^1.17.2` dependency (required for collections)

## [5.0.0] - 19.07.2035
* Although this version doesn't add any new functionality but is just the rebranding of the original functional_listener package I decided to keep the version numbers so it is is easy for anyone switching to the new package and to preserve the history.  

## [4.1.0] - 02.10.2024  >> all entries from here on relate to the original package
* adding debounce as extenstion method on `Listenable`
## [4.0.0] - 29.9.2024
* Following the findings of https://github.com/escamoteur/functional_listener/issues/13 we no longer destroy the listener chain when the last listener is removed. Because this might change the behavior of your app this is seen as a breaking change and therefore the change to 4.0.0. Please observe if this leads to increasing memory usage
## [3.0.0] - 19.07.2024
* added optional error handler for CustomValueNotifier in case one of the listeners throws an Exception
* added` `listen() extension method for normal Listenable
## [2.3.1] - 28.02.2023

* stupid bug fix
## [2.3.0] - 28.02.2023
* added `async()` extension method

```dart

  /// ValueListenable are inherently synchronous. In most cases this is what you
  /// want. But if for example your ValueListenable gets updated inside a build
  /// method of a widget which would trigger a rebuild because your widgets is
  /// listening to the ValueListenable you get an exception that you called setState
  /// inside a build method.
  /// By using [async] you push the update of the ValueListenable to the next
  /// frame. This way you can update the ValueListenable inside a build method
  /// without getting an exception.
  ValueListenable<T> async();
```
* `CustomValueNotifier` got a new property `asyncNotification` which if set to true postpones the notifications of listeners to the end of the frame which can be helpful if you run into Exceptions about 'calling setState inside a build function' e.g. if you monitor the `CustomValueNotifier` with the get_it_mixin and you update it inside the build function. Default is false.

## [2.2.0] - 24.02.2023

* added listenerCount to CustomValueNotfier

# [2.1.0] - 29.01.2022

* merged several PRs with bugfixes
* adds the `select()` method see the readme
* adds more `combineLates()` variants up to 6 input Listenables
## [2.0.2] - 07.05.2021

* Bugfix: If you resubscribed to one of the Listenables that are returned from the extension functions in this package and then resubscribed it did not rebuild the subcription to it's previous in chain.

## [2.0.1] - 05.05.2021

* Added public `notifyListeners` to `CustomValueNotfier` 

## [2.0.0] - 15.02.2021

* Added `CustomValueNotfier` 
## [1.1.1] - 30.11.2020

* Fixes in documentation and tests 
## [1.1.0] - 05.10.2020

* Added mergeWith() function

## [1.0.1] - 03.08.2020

* Added package description

## [1.0.0] - 03.08.2020

* Added Example and some bug fixes

## [0.8.0] - 30.07.2020

* Initial release
