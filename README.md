<img align="left" src="https://github.com/flutter-it/listen_it/blob/main/listen_it.png?raw=true" alt="listen_it logo" width="150" style="margin-left: -10px;"/>

<div align="right">
  <a href="https://www.buymeacoffee.com/escamoteur"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee" style="height: 28px !important; width: 120px !important;"/></a>
  <br/>
  <a href="https://github.com/sponsors/escamoteur"><img src="https://img.shields.io/badge/Sponsor-❤-ff69b4?style=for-the-badge" alt="Sponsor" style="height: 28px; width: 120px;"/></a>
</div>

<br clear="both"/>

# listen_it <a href="https://codecov.io/gh/flutter-it/listen_it"><img align="right" src="https://codecov.io/gh/flutter-it/listen_it/branch/main/graph/badge.svg?style=for-the-badge" alt="codecov" width="200"/></a>

> 📚 **[Complete documentation available at flutter-it.dev](https://flutter-it.dev/documentation/listen_it/listen_it)**
> Check out the comprehensive docs with detailed guides, examples, and best practices!

**Reactive primitives for Flutter - observable collections and powerful operators for ValueListenable.**

Managing reactive state in Flutter can be complex. You need collections that notify listeners when they change, operators to transform and combine observables, and patterns that don't cause memory leaks. `listen_it` provides two powerful primitives: reactive collections (ListNotifier, MapNotifier, SetNotifier) that automatically notify on mutations, and extension operators on ValueListenable (map, select, where, debounce, combineLatest) that let you build reactive data pipelines.

Previously published as `functional_listener`. Now includes reactive collections from `listenable_collections`.

> **flutter_it is a construction set** — listen_it works perfectly standalone or combine it with other packages like [watch_it](https://pub.dev/packages/watch_it) (which provides automatic selector caching for safe inline chain creation!), [get_it](https://pub.dev/packages/get_it) (dependency injection), or [command_it](https://pub.dev/packages/command_it) (which uses listen_it internally). Use what you need, when you need it.

## Why listen_it?

- **🔔 Reactive Collections** — ListNotifier, MapNotifier, SetNotifier that automatically notify listeners on mutations. No manual notifyListeners() calls needed.
- **🔗 Chainable Operators** — Transform, filter, combine ValueListenables with map(), select(), where(), debounce(), combineLatest(), mergeWith().
- **🎯 Selective Updates** — React only to specific property changes with select(). Avoid unnecessary rebuilds.
- **⚡ Transaction Support** — Batch multiple operations into a single notification for optimal performance.
- **🔒 Type Safe** — Full compile-time type checking. No runtime surprises.
- **📦 Pure Dart Core** — Operators work in pure Dart (collections require Flutter for ChangeNotifier).

[Learn more about listen_it →](https://flutter-it.dev/documentation/listen_it/listen_it)

> 💡 **Eager Initialization (v5.3.0+):** Operator chains now use **eager initialization by default** - they subscribe to sources immediately, ensuring `.value` is always correct even before adding listeners. This fixes stale value issues but uses slightly more memory. For memory-constrained scenarios, pass `lazy: true` to delay subscription until the first listener is added. Once initialized, chains stay subscribed for efficiency. For best practices, see the [complete documentation](https://flutter-it.dev/documentation/listen_it/best_practices).

## Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  listen_it: ^5.1.0
```

### Reactive Collections

Simply wrap your collection type with a notifier:

```dart
// Instead of:
final items = <String>[];

// Use:
final items = ListNotifier<String>();

// With initial data:
final items = ListNotifier<String>(data: ['item1', 'item2']);
```

All standard collection methods work as expected - the difference is they now notify listeners!

### Integration with Flutter

```dart
class TodoListWidget extends StatelessWidget {
  final todos = ListNotifier<String>();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>>(
      valueListenable: todos,
      builder: (context, items, _) {
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) => Text(items[index]),
        );
      },
    );
  }
}
```

### ValueListenable Operators

#### listen()

Lets you work with a `ValueListenable` (and `Listenable`) as it should be by installing a handler function that is called on any value change and gets the new value passed as an argument. **This gives you the same pattern as with Streams**, making it natural and consistent.

```dart
final listenable = ValueNotifier<int>(0);
final subscription = listenable.listen((x, _) => print(x));
```

The returned `subscription` can be used to deactivate the handler. As you might need to uninstall the handler from inside the handler you get the subscription object passed to the handler function as second parameter:

```dart
listenable.listen((x, subscription) {
  print(x);
  if (x == 42) {
     subscription.cancel();
  }
});
```

This is particularly useful when you want a handler to run only once or a certain number of times:

```dart
// Run only once
listenable.listen((x, subscription) {
  print('First value: $x');
  subscription.cancel();
});

// Run exactly 3 times
var count = 0;
listenable.listen((x, subscription) {
  print('Value: $x');
  if (++count >= 3) subscription.cancel();
});
```

For regular `Listenable` (not `ValueListenable`), the handler only receives the subscription parameter since there's no value to access:

```dart
final listenable = ChangeNotifier();
listenable.listen((subscription) => print('Changed!'));
```

#### Chaining Operators

Chain operators to build reactive data pipelines:

```dart
final searchTerm = ValueNotifier<String>('');

searchTerm
    .debounce(const Duration(milliseconds: 300))
    .where((term) => term.length >= 3)
    .listen((term, _) => callSearchApi(term));
```

**That's it!** Collections notify automatically, operators let you transform data reactively.

## Key Features

### Reactive Collections

Choose the collection that fits your needs:

- **ListNotifier<T>** — Order matters, duplicates allowed. Perfect for: todo lists, chat messages, search history.
  [Read more →](https://flutter-it.dev/documentation/listen_it/collections/list_notifier)

- **MapNotifier<K,V>** — Key-value lookups. Perfect for: user preferences, caches, form data.
  [Read more →](https://flutter-it.dev/documentation/listen_it/collections/map_notifier)

- **SetNotifier<T>** — Unique items only, fast membership tests. Perfect for: selected item IDs, active filters, tags.
  [Read more →](https://flutter-it.dev/documentation/listen_it/collections/set_notifier)

**Notification Modes:**
- `always` (default) — Notify on every operation
- `normal` — Only notify on actual changes
- `manual` — You control when to notify

[Read more about notification modes →](https://flutter-it.dev/documentation/listen_it/collections/notification_modes)

**Transactions** — Batch operations into single notification:
```dart
products.startTransAction();
products.add(item1);
products.add(item2);
products.add(item3);
products.endTransAction(); // Single notification
```
[Read more →](https://flutter-it.dev/documentation/listen_it/collections/transactions)

### ValueListenable Operators

Transform and combine observables:

- **listen()** — Install handlers that react to value changes. The foundation for reactive programming with ValueListenables.
  ```dart
  listenable.listen((value, subscription) => print(value));
  ```

- **map()** — Transform values to different types
- **select()** — React only when specific properties change
- **where()** — Filter which values propagate (now with optional fallbackValue for initial value handling!)
- **debounce()** — Control rapid value changes (great for search!)
- **async()** — Defer updates to next frame to avoid setState-during-build
- **combineLatest()** — Merge multiple ValueListenables (supports 2-6 sources)
- **mergeWith()** — Combine value changes from multiple sources

[Read operator documentation →](https://flutter-it.dev/documentation/listen_it/operators/overview)

### Eager vs Lazy Initialization (v5.3.0+)

All operators now support a `lazy` parameter to control when chains subscribe to their sources:

```dart
// Default: Eager initialization (lazy=false)
final eager = source.map((x) => x * 2);
print(eager.value); // Always correct, even without listeners ✓

source.value = 5;
print(eager.value); // Immediately updated to 10 ✓

// Explicit: Lazy initialization (lazy=true)
final lazy = source.map((x) => x * 2, lazy: true);
print(lazy.value); // Computed from initial source value

source.value = 5;
print(lazy.value); // STALE! Not updated until listener is added ⚠️

lazy.addListener(() {}); // Now subscribes and future updates work
source.value = 7;
print(lazy.value); // Now correctly updates to 14 ✓
```

**When to use eager (default):**
- ✅ When you need `.value` to always be correct
- ✅ When using ValueListenableBuilder (ensures correct initial render)
- ✅ In most application code (convenience over memory)

**When to use lazy (`lazy: true`):**
- ✅ Memory-constrained environments (many chains, few listeners)
- ✅ When chains might not be used
- ✅ Performance-critical scenarios where subscription cost matters

#### Mixing Lazy and Eager in Chains

Each operator in a chain is independent. You can mix lazy and eager, but this can lead to confusing behavior:

```dart
final source = ValueNotifier<int>(5);
final eager = source.map((x) => x * 2);           // Default: eager
final lazy = eager.map((x) => x + 1, lazy: true); // Explicit: lazy

source.value = 7;
print(eager.value); // 14 ✓ (eager subscribed, updates immediately)
print(lazy.value);  // 11 ⚠️ (STALE! lazy not subscribed yet)

lazy.addListener(() {}); // Subscribe lazy to eager
print(lazy.value);  // 11 ⚠️ (STILL STALE! Doesn't retroactively update)

source.value = 10;
print(lazy.value);  // 21 ✓ (NOW updates on next change)
```

**Key behaviors:**

- **Eager → Lazy**: Eager part updates, lazy part can be stale until listener added
- **Lazy → Eager**: Eager subscribes to lazy immediately, which triggers lazy to initialize the whole chain
- **All eager (default)**: Entire chain subscribes immediately, `.value` always correct ✓
- **All lazy**: Chain doesn't subscribe until end gets a listener

**Recommendation**: Don't mix. Use all-eager (default, simple) or all-lazy (memory optimization). Mixing can cause hard-to-debug stale values.

### ⚠️ Important: Chain Lifecycle & Memory Management

Operator chains (like `source.map(...).where(...)`) use **eager initialization by default (v5.3.0+)** - they subscribe to sources immediately and stay subscribed for efficiency. While this ensures `.value` is always correct, it means chains consume resources even without listeners.

**This can cause memory leaks if chains are created inline in build methods!**

✅ **SAFE Patterns:**
```dart
// Best: Use watch_it (automatic caching)
class MyWidget extends WatchingWidget {
  @override
  Widget build(BuildContext context) {
    final value = watchValue((Model m) => m.source.map((x) => x * 2));
    return Text('$value');
  }
}

// Alternative: Create chain outside build
class MyWidget extends StatelessWidget {
  late final chain = source.map((x) => x * 2);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: chain, // Same object every rebuild
      builder: (context, value, _) => Text('$value'),
    );
  }
}
```

❌ **UNSAFE Pattern:**
```dart
// DON'T: Chain inline in ValueListenableBuilder
Widget build(BuildContext context) {
  return ValueListenableBuilder(
    valueListenable: source.map((x) => x * 2), // NEW CHAIN EVERY REBUILD!
    builder: (context, value, _) => Text('$value'),
  );
}
```

**Why watch_it is recommended:** watch_it v2.0+ provides automatic selector caching (`allowObservableChange: false` by default), making inline chain creation completely safe!

### Disposal & Garbage Collection

**Good news:** Chains don't require manual disposal in most cases! Dart's garbage collector automatically cleans up circular references when the entire object graph (source + chain) becomes unreachable.

**You only need to:**
- ✅ Dispose the source ValueNotifier to stop notifications
- ✅ Manually dispose chains ONLY if the source outlives the chain (e.g., source registered in get_it)

```dart
class MyService {
  final counter = ValueNotifier<int>(0);
  late final doubled = counter.map((x) => x * 2);

  void dispose() {
    counter.dispose(); // Stops notifications
    // Chain is automatically GC'd when service becomes unreachable
  }
}
```

[Read complete disposal guide →](https://flutter-it.dev/documentation/listen_it/best_practices#disposal)

[Read complete best practices guide →](https://flutter-it.dev/documentation/listen_it/best_practices)

## Ecosystem Integration

**listen_it works independently** — Use it standalone for reactive collections and operators in any Dart or Flutter project.

**Want more?** Combine with other packages from the flutter_it ecosystem:

- **Optional: [watch_it](https://pub.dev/packages/watch_it)** — Reactive state management with **automatic selector caching**. Makes inline chain creation safe! Highly recommended for listen_it operator chains.

- **Optional: [get_it](https://pub.dev/packages/get_it)** — Dependency injection. Register your ListNotifiers, ValueNotifiers, and chains in get_it for global access.

- **Optional: [command_it](https://pub.dev/packages/command_it)** — Command pattern with automatic state tracking. Uses listen_it operators internally.

**Remember:** flutter_it is a construction set. Each package works independently. Pick what you need, combine as you grow.

[Learn about the ecosystem →](https://flutter-it.dev)

## Learn More

### Documentation

- **[Getting Started](https://flutter-it.dev/documentation/listen_it/listen_it)** — Overview, installation, when to use what
- **[Operators](https://flutter-it.dev/documentation/listen_it/operators/overview)** — All operators with examples
- **[Collections](https://flutter-it.dev/documentation/listen_it/collections/introduction)** — Reactive collections guide
- **[Best Practices](https://flutter-it.dev/documentation/listen_it/best_practices)** — Chain lifecycle, memory management, disposal patterns
- **[API Documentation](https://pub.dev/documentation/listen_it/latest/)** — Complete API reference

### Community & Support

- **[Discord](https://discord.gg/ZHYHYCM38h)** — Get help, share ideas, connect with other developers
- **[GitHub Issues](https://github.com/flutter-it/listen_it/issues)** — Report bugs, request features
- **[GitHub Discussions](https://github.com/flutter-it/listen_it/discussions)** — Ask questions, share patterns

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

**Part of the [flutter_it ecosystem](https://flutter-it.dev)** — Build reactive Flutter apps the easy way. No codegen, no boilerplate, just code.
