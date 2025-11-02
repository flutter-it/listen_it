# Investigation: where() Initial Value Behavior

## Issue

The `where()` operator has a caveat where the initial value always passes through the filter without being checked against the predicate. This is documented in the source code and can lead to unexpected behavior.

## Current Behavior

```dart
final numbers = ValueNotifier<int>(1); // Odd number

final evenNumbers = numbers.where((n) => n.isEven);

print(evenNumbers.value); // 1 - passes through even though it's odd!

numbers.value = 2; // Now filter works correctly
print(evenNumbers.value); // 2

numbers.value = 3; // Blocked by filter
print(evenNumbers.value); // Still 2
```

**Verified**: The initial value of `1` (odd) passes through even though the predicate requires even numbers.

## Source Documentation

From `listen_it.dart` lines 145-167:

```dart
/// ATTENTION: Due to the nature of ValueListeners that they always have to have
/// a value the filter can't work on the initial value. Therefore it's not
/// advised to use [where] inside the Widget tree if you use `setState` because that
/// will recreate the underlying `WhereValueNotifier` again passing through the latest
/// value of the `this` even if it doesn't fulfill the [selector] condition.
/// Therefore it's better not to use it directly in the Widget tree but in
/// your state objects
```

## Why This Happens

Looking at `WhereValueNotifier` constructor:

```dart
WhereValueNotifier(
  T initialValue,
  ValueListenable<T> previousInChain,
  this.selector,
) : super(initialValue, previousInChain) {
  init(previousInChain);
}
```

The initial value is passed directly to the parent constructor WITHOUT being checked against the predicate. The predicate is only checked in the `internalHandler`:

```dart
@override
void init(ValueListenable<T> previousInChain) {
  internalHandler = () {
    if (selector(previousInChain.value)) {
      value = previousInChain.value;
    }
  };
  setupChain();
}
```

## Problem with setState Warning

The documentation warns about using `where()` in Widget trees with `setState`. The concern is:

1. Widget rebuilds due to `setState`
2. New `where()` chain is created inline in build method
3. New chain gets the current source value as initial value
4. That value passes through filter regardless of predicate

**Question**: Is this warning accurate? Does this actually cause issues in practice?

## Potential Solutions

### Option 1: Apply Filter to Initial Value

Modify `WhereValueNotifier` to check the initial value:

```dart
WhereValueNotifier(
  T initialValue,
  ValueListenable<T> previousInChain,
  this.selector,
) : super(
      selector(initialValue) ? initialValue : /* what here? */,
      previousInChain
    ) {
  init(previousInChain);
}
```

**Problem**: If initial value doesn't pass the filter, what do we use? We need SOME value because it's a ValueListenable.

### Option 2: Require Explicit Initial Value Parameter

Add an optional parameter to specify what value to use if the source's initial value doesn't pass:

```dart
ValueListenable<T> where(
  bool Function(T) selector, {
  T? fallbackInitialValue,
}) {
  final sourceValue = this.value;
  final initialValue = selector(sourceValue)
      ? sourceValue
      : (fallbackInitialValue ?? sourceValue);
  return WhereValueNotifier(initialValue, this, selector);
}
```

**Issue**: Still awkward, and throws if fallback not provided and initial doesn't pass.

### Option 3: Use a "No Value Yet" Pattern

Make the filtered ValueListenable nullable initially:

```dart
ValueListenable<T?> where(bool Function(T) selector)
```

**Problem**:
- Breaking change (changes return type)
- Forces users to handle null even if they know source is never null
- Doesn't match ValueListenable contract well

### Option 4: Document Better & Recommend Best Practices

Current approach - make the limitation clear and guide users to:

1. ✅ Create chains outside build methods (as fields or in constructors)
2. ✅ Use watch_it which handles lifecycle automatically
3. ✅ Use chains in model objects, not Widget tree

This is what we've done in the documentation.

### Option 5: Make where() Check Initial Value and Throw

```dart
WhereValueNotifier(
  T initialValue,
  ValueListenable<T> previousInChain,
  this.selector,
) : super(
      _validateInitial(initialValue, selector),
      previousInChain
    ) {
  init(previousInChain);
}

static T _validateInitial<T>(T value, bool Function(T) selector) {
  if (!selector(value)) {
    throw ArgumentError(
      'Initial value does not pass the where() predicate. '
      'Consider using select() or creating the chain after the source has a valid value.'
    );
  }
  return value;
}
```

**Pros**: Makes the issue explicit immediately
**Cons**: Runtime error instead of silently passing through

## Questions to Answer

1. **Is the setState warning accurate?**
   - Need to create a test case that demonstrates the problem
   - Is this a real issue users encounter?

2. **Is this worth fixing with a breaking change?**
   - How often does this cause problems in practice?
   - Would Option 5 (throw on invalid initial) be acceptable?

3. **Should we change the API?**
   - Add `whereOrNull()` variant that returns `ValueListenable<T?>`?
   - Add `whereWithFallback(predicate, fallbackValue)`?

4. **Current workarounds sufficient?**
   - watch_it handles this automatically
   - Creating chains outside build is good practice anyway
   - Is better documentation enough?

## Action Items

- [ ] Create test case demonstrating setState issue
- [ ] Check if this comes up in GitHub issues
- [ ] Discuss with maintainers about potential solutions
- [ ] Consider if this warrants a breaking change in next major version
- [ ] Update documentation if we decide current behavior is acceptable
- [ ] Consider adding a lint rule to catch inline chain creation?

## Related Code Locations

- `lib/listen_it.dart` lines 145-167 (where() documentation)
- `lib/src/functional_value_notifiers.dart` lines 86-106 (WhereValueNotifier implementation)
- `docs/docs/documentation/listen_it/operators/filter.md` lines 105-120 (documentation warning)

## Date Created

2025-11-02
