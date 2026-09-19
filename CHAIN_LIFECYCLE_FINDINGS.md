# Chain Lifecycle Findings

## Summary

This document contains findings from comprehensive testing of FunctionalValueNotifier chain object lifecycle behavior in the listen_it package.

## Key Findings

### 1. Chain Objects Are Created Once and Reused

**Finding**: FunctionalValueNotifier chain objects are created exactly once when the expression is evaluated and are never recreated during event processing.

**Evidence**:
- Constructor call counts remain at 1 throughout multiple events
- `identityHashCode()` stays stable across multiple value changes
- Handler call counts increase, but constructor counts don't

**Implication**: The "hot" subscription model is working as designed - chains subscribe to their source immediately in the constructor and stay subscribed.

### 2. Subscription Model (updated for v6.0.0: detach when unobserved)

**Finding**: Chains subscribe to their source eagerly on creation (or on the first listener with `lazy: true`), **detach from the source when their last listener is removed** and re-attach on the next listener. In a longer chain the detach/attach cascades through all levels down to the original source.

**Evidence**:
- After removing all listeners from a chain, `source.hasListeners` is `false`
- `internalHandler` is no longer called on source changes while detached
- Adding a listener again re-subscribes and resyncs the stored value before the new listener is registered

**`.value` stays correct while detached**: the value getter derives the value from the current source value on read (`map` → `convert(source.value)`, `where` → source value if it passes, otherwise the last stored value, `combineLatest` → `combiner(...)`, etc.). Only `mergeWith` returns its last received value because it can't know which source changed last. This is what makes the v4.0.0 regression scenario (functional_listener #13) work despite the detach.

**History**: up to v4.0.0 (Sept 2024) chains detached on the last listener but `.value` went stale; v4.0.0 removed the detach ("hot" model, listeners accumulate); v6.0.0 re-introduced the detach together with derive-on-read.

### 3. Resubscription Works Correctly

**Finding**: After removing all listeners and then adding a new listener, the chain correctly receives updates without needing to be recreated.

**Evidence**:
- Listener removal doesn't break the chain
- Adding a new listener works immediately
- No need to recreate the chain object

### 4. Inline Chain Creation - Now Safe with watch_it!

**Major Update (2025-01-11)**: watch_it now provides **automatic protection** against inline chain creation memory leaks through selector caching.

#### watch_it Protection (v2.0+)

**✅ SAFE with watch_it (default behavior):**
```dart
@override
Widget build(BuildContext context) {
  // SAFE! Selector cached by default - chain created only once
  final value = watchValue((Model m) => m.source.map((x) => x * 2));
  return Text('$value');
}

@override
Widget build(BuildContext context) {
  // SAFE! Selector cached by default - chain created only once
  registerHandler(
    select: (Model m) => m.source.map((x) => x * 2),
    handler: (context, value, cancel) { ... },
  );
  return ...;
}
```

**How it works**:
- `watchValue` and `registerHandler` have `allowObservableChange: false` as default
- When `false`, the selector is called **only once** on the first build
- The returned observable (chain) is cached and reused on all subsequent builds
- This prevents chain recreation and eliminates the memory leak

**⚠️ Only unsafe if you override the default:**
```dart
// UNSAFE - explicitly disabling cache!
final value = watchValue(
  (Model m) => m.source.map((x) => x * 2),
  allowObservableChange: true,  // Creates new chain every rebuild - LEAK!
);
```

**When to use `allowObservableChange: true`:**
Only when you need to dynamically switch between different observables based on runtime state:
```dart
// Valid use case: switching observables based on condition
final colors = watchValue(
  (Settings s) => s.darkMode ? s.darkColors : s.lightColors,
  allowObservableChange: true,  // Needed because observable changes
);
```

#### ValueListenableBuilder - Still Requires Care

**❌ ValueListenableBuilder - Chain in valueListenable parameter:**
```dart
Widget build(BuildContext context) {
  return ValueListenableBuilder<int>(
    valueListenable: source.map((x) => x * 2),  // NEW CHAIN EVERY REBUILD!
    builder: (context, value, child) => Text('$value'),
  );
}
```

**❌ ValueListenableBuilder - Chain in builder function:**
```dart
Widget build(BuildContext context) {
  return ValueListenableBuilder<int>(
    valueListenable: source,
    builder: (context, value, child) {
      final chain = source.map((x) => x * 2);  // NEW CHAIN EVERY REBUILD!
      return Text('${chain.value}');
    },
  );
}
```

**Why ValueListenableBuilder is still unsafe:**
ValueListenableBuilder doesn't have selector caching - it's a plain Flutter widget that rebuilds normally.

#### Why Uncached Inline Creation Is Bad:

1. **Wasted work**: Each rebuild creates a new chain object that subscribes to the source eagerly
2. **Since v6.0.0 old chains do unsubscribe** once their last listener is removed (e.g. when the widget that listened is disposed); chains that were created but never listened to detach on the first source notification (the `notifyListeners` re-check sees no listeners) and stay correct via derive-on-read
3. **Before v6.0.0**: all old chains stayed subscribed forever, causing unbounded memory growth and every old chain processing every event

#### Correct Patterns:

**✅ Best: Use watch_it with inline chains (automatic caching):**

```dart
class MyWidget extends WatchingWidget {
  @override
  Widget build(BuildContext context) {
    // SAFE! Selector cached automatically, chain created only once
    final value = watchValue((Model m) => m.source.map((x) => x * 2));
    return Text('$value');
  }
}
```

**✅ Alternative: Create chain in model (explicit management):**

```dart
class ChainModel {
  final ValueNotifier<int> source;
  late final ValueListenable<int> chain;

  ChainModel(this.source) {
    chain = source.map((x) => x * 2);  // Created once
  }
}

class MyWidget extends WatchingWidget {
  @override
  Widget build(BuildContext context) {
    final value = watchValue((ChainModel m) => m.chain);  // Gets existing chain
    return Text('$value');
  }
}
```

**✅ For ValueListenableBuilder: Create chain OUTSIDE build:**

```dart
class MyWidget extends StatelessWidget {
  final ValueNotifier<int> source;
  late final ValueListenable<int> chain;  // Created once

  MyWidget(this.source) {
    chain = source.map((x) => x * 2);  // Created in constructor
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: chain,  // Same object every rebuild
      builder: (context, value, child) => Text('$value'),
    );
  }
}
```

### 5. Circular References and Garbage Collection

**Finding**: Chains create circular references, but Dart's GC handles them correctly when the entire cycle becomes unreachable from GC roots.

**Understanding Circular References**:
Chains create a circular reference cycle:
- source.listeners → internalHandler (closure) → chain → previousInChain → source

The `internalHandler` is a closure that captures `this` (the chain object) because it references `value`:
```dart
internalHandler = () {
  value = transformation(previousInChain.value);  // 'value' is 'this.value'
};
```

**Critical Discovery About GC**:
- Modern garbage collectors (including Dart's) use **reachability tracing from GC roots**, not reference counting
- GC roots include: stack variables, static variables, registered objects (like in get_it), etc.
- When an entire cycle becomes unreachable from any GC root, the GC collects everything in that cycle
- Circular references only "leak" when something external keeps any part of the cycle reachable

**Evidence**:
- Test: "service with source and chain - circular reference CAN be GC'd when unreachable from roots"
- When service owning both source and chain is set to null, both are GC'd despite circular reference
- Test: "service with source and chain WITH active listener - still GC'd when unreachable!"
- Even with active listeners, if nothing from GC roots points into the cycle, everything is collected
- The listener functions are part of the unreachable object graph and go with it

**When Chains Stay Alive**:
- When source is kept alive from a GC root (e.g., registered in get_it, held by long-lived object)
- Chains stay registered as listeners on the source
- This is **normal listener behavior**, not a memory leak
- Setting parent object to null doesn't help if source is still reachable from another root

**Best Practice**:
- **ALWAYS** call `dispose()` on chains when you're done with them
- Implement proper disposal in parent object's `dispose()` method
- Use lifecycle-aware patterns (StatefulWidget disposal, get_it disposal callbacks, etc.)
- Don't rely on "parent going away" to clean up chains if source is kept alive externally
- Treat chains like any other resource (controllers, streams, subscriptions) - explicit disposal required

**Why This Happens**:
```dart
// In FunctionalValueNotifier constructor:
void setupChain() {
  previousInChain.addListener(internalHandler);  // Circular ref: source -> closure -> chain
  chainInitialized = true;
}

// Disposal breaks the cycle:
void dispose() {
  previousInChain.removeListener(internalHandler);  // Breaks: source -> closure
  super.dispose();
}
```

### 6. Multiple Listeners on Same Chain

**Finding**: A single chain object can have multiple listeners, and all receive updates correctly.

**Evidence**:
- Adding multiple listeners to the same chain works correctly
- All listeners receive the same values
- No duplicate subscriptions to the source (chain subscribes once)

**Benefit**: This is efficient - the chain only needs one subscription to the source, regardless of how many consumers are listening.

### 7. Different Chain Types Behave Consistently

**Finding**: All chain types (map, where, select, debounce, async, combineLatest, mergeWith) follow the same lifecycle pattern.

**Evidence**:
- All use the same `FunctionalValueNotifier` base class
- All initialize in constructor (hot subscription)
- All maintain stable identity across events
- All dispose correctly

### 8. ValueListenableBuilder Behavior

**Finding**: When a chain is created outside the widget and passed to ValueListenableBuilder, the chain object identity remains stable even as the builder rebuilds.

**Evidence**:
- Multiple rebuilds don't recreate the chain
- Same `identityHashCode()` across all rebuilds
- Only the builder function executes, not chain creation

**Implication**: The correct pattern (chain created outside) is safe and efficient.

### 9. watch_it Integration

**Finding**: Both `watchValue` and `registerHandler` work correctly with chains when the chain is retrieved from get_it.

**Key Points**:
- `watchValue` automatically gets objects from get_it via the selector
- `registerHandler` also gets objects from get_it via the `select` parameter
- Both trigger rebuilds/handlers when the chain value changes
- `registerHandler` doesn't cause widget rebuilds, only calls the handler function

## Testing Methodology

All findings are backed by comprehensive tests:

### Test Files:
- **`test/chain_lifecycle_test.dart`**: 16 tests covering chain lifecycle behavior
- **`test/chain_memory_test.dart`**: 2 tests covering memory and garbage collection

### Test Approach:
- **Tracked implementations**: Exact copies of original classes with only tracking counters added
- **Dedicated test widgets**: Separate widget classes for each integration scenario
- **Widget integration tests**: Testing with ValueListenableBuilder, watchValue, and registerHandler
- **Anti-pattern tests**: Explicit tests demonstrating memory leak scenarios
- **GC testing**: Force garbage collection to verify memory leak behavior

### Test Widgets Created:

**For testing correct patterns:**
1. `_TestWatchValueWidget` - Uses `watchValue` with chain from get_it (correct)
2. `_RegisterHandlerTestWidget` - Uses `registerHandler` with chain from get_it (correct)

**For testing inline chain behavior:**
1. `_TestInlineChainWidget` - Creates chain in build method, uses chain.value directly (always leaks)
2. `_TestValueListenableBuilderInlineWidget` - Creates chain inline in `valueListenable: source.map(...)` parameter (always leaks)
3. `_TestWatchValueInlineWidget` - Creates chain inline in `watchValue((m) => source.map(...))` selector with configurable `allowObservableChange`
4. `_TestRegisterHandlerInlineWidget` - Creates chain inline in `select: (m) => source.map(...)` parameter with configurable `allowObservableChange`

**Key findings from tests:**
- ValueListenableBuilder inline chains: Always leak (no caching)
- watch_it with `allowObservableChange: false` (default): Safe - only 1 chain created
- watch_it with `allowObservableChange: true`: Leaks - new chain every rebuild
- Tests use `TrackedMapValueNotifier` with global counter to track total instances created

### Test Coverage:

**chain_lifecycle_test.dart (17 tests):**
1. Constructor call counting and identity stability (2 tests)
2. Variable assignment - multiple listeners (1 test)
3. Parent object disposal (2 tests)
4. Resubscription after listener removal (1 test)
5. Hot subscription verification - intermediate nodes (1 test)
6. ValueListenableBuilder integration (4 tests - including 2 anti-patterns showing always leak)
7. watch_it integration (6 tests):
   - watchValue with chain created outside (safe)
   - watchValue with chain created inside build (anti-pattern - always leaks)
   - **watchValue inline with default caching** - proves safe (1 chain created)
   - **watchValue inline with allowObservableChange=true** - proves leak (3 chains created)
   - registerHandler with chain from get_it (safe)
   - **registerHandler inline with allowObservableChange=true** - proves leak when rebuilds occur

**chain_memory_test.dart (2 tests):**
1. Service with source and chain - circular reference CAN be GC'd when unreachable from roots (1 test)
2. Service with source and chain WITH active listener - still GC'd when unreachable! (1 test)

These tests prove that Dart's GC correctly handles circular references when the entire cycle becomes unreachable from GC roots.

## Recommendations for Users

### DO ✅

1. **Use watch_it for reactive widgets** - automatic selector caching prevents inline chain leaks
2. **Create inline chains in watch_it selectors** - safe with default `allowObservableChange: false`
3. **Store chains outside build** when using ValueListenableBuilder
4. **Dispose chains** when the parent object is destroyed
5. **Reuse chain objects** across multiple listeners

### DON'T ❌

1. **Don't create chains inline in ValueListenableBuilder** - no caching, always leaks
2. **Don't create chains in builder functions** - recreated on every build
3. **Don't use `allowObservableChange: true`** unless you need dynamic observable switching
4. **Don't ignore disposal** - `dispose()` is still the explicit way to end a chain; a chain that was created but never listened to only detaches once the source notifies for the first time
5. **Don't create chains in StatefulWidget build** without storing them in State

### watch_it Specific ✅

1. **Default is safe** - `allowObservableChange: false` caches selectors automatically
2. **Inline chains work perfectly** - `watchValue((m) => m.source.map(...))` is safe
3. **Only set `allowObservableChange: true`** when observable identity actually changes between builds

## Documentation Impact

These findings should be prominently documented in:

1. **Package README**: Add warning about inline chain creation
2. **API Documentation**: Document on each operator method
3. **Migration Guide**: Warn users migrating from other reactive frameworks
4. **Best Practices Guide**: Dedicated section on chain lifecycle management
5. **AI Assistant Docs**: Critical rules for AI-assisted development

## Example Warning Message

```dart
/// ⚠️ IMPORTANT: Chain Lifecycle Warning
///
/// Do NOT create chains inside widget build methods or selector functions.
/// This creates a new chain object on every rebuild, causing memory leaks
/// because all chains stay subscribed ("hot") even after rebuild.
///
/// ❌ WRONG:
/// ```dart
/// Widget build(BuildContext context) {
///   return ValueListenableBuilder(
///     valueListenable: source.map((x) => x * 2),  // NEW CHAIN EVERY BUILD!
///     builder: ...
///   );
/// }
/// ```
///
/// ✅ CORRECT:
/// ```dart
/// class MyWidget extends StatelessWidget {
///   late final chain = source.map((x) => x * 2);  // Created once
///
///   Widget build(BuildContext context) {
///     return ValueListenableBuilder(
///       valueListenable: chain,  // Same object every build
///       builder: ...
///     );
///   }
/// }
/// ```
```

## Conclusion

Chain objects are created once and maintain stable identity throughout their lifecycle.

**Update (2026-09-19, v6.0.0)**: chains now detach from their source when their last listener is removed and re-attach on the next one, while `.value` is derived from the source on read while detached. A chain that is discarded after its listener is gone (e.g. with the widget that watched it) no longer leaks a listener on the source. See section 2 and `test/detach_on_unobserved_test.dart`, `test/watch_it_integration_test.dart`.

**Major breakthrough (2025-01-11)**: The inline chain creation memory leak issue is **SOLVED** for watch_it users! With watch_it v2.0+, the default `allowObservableChange: false` parameter provides automatic selector caching, making inline chain creation completely safe:

✅ **Safe**: `watchValue((m) => m.source.map(...))` - chain created only once, cached for all subsequent builds

⚠️ **Still unsafe**: ValueListenableBuilder with inline chains - no caching mechanism available

🎯 **Best practice**: Use watch_it for reactive widgets - it provides the best developer experience with automatic memory leak prevention.

---

**Test Files**:
- `test/chain_lifecycle_test.dart` (17 tests)
- `test/chain_memory_test.dart` (2 tests)

**Total Tests**: 19 (17 lifecycle + 2 memory)

**Date**: 2025-01-11

**Package Versions**:
- listen_it: 5.2.0
- watch_it: 2.0+ (with `allowObservableChange` caching support)

**Major Update**: watch_it v2.0+ provides automatic protection against inline chain memory leaks through selector caching with `allowObservableChange: false` as default.
