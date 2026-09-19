<img align="left" src="https://github.com/flutter-it/listen_it/blob/main/listen_it.png?raw=true" alt="listen_it logo" width="150" style="margin-left: -10px;"/>

<div align="right">
  <a href="https://www.buymeacoffee.com/escamoteur"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee" height="28" width="120"/></a>
  <br/>
  <a href="https://github.com/sponsors/escamoteur"><img src="https://img.shields.io/badge/Sponsor-❤-ff69b4?style=for-the-badge" alt="Sponsor" height="28" width="120"/></a>
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

> 💡 **Chain lifecycle (v6.0.0+):** Operator chains subscribe to their source eagerly on creation (or on the first listener with `lazy: true`), **detach from the source when their last listener is removed** and re-attach on the next one. While a chain has no listeners its `.value` is derived from the current source value on read, so it is never stale, and a chain that nobody references any more can be garbage collected. For best practices, see the [complete documentation](https://flutter-it.dev/documentation/listen_it/best_practices).

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

### Chain Lifecycle: Attach, Detach and Derived Values (v6.0.0+)

An operator chain (`source.map(...)`, `a.combineLatest(b, ...)`, ...) is a `ValueListenable` that follows this lifecycle:

1. **Attach** - the chain subscribes to its source(s) when it is created (default) or, with `lazy: true`, when it gets its first listener.
2. **Detach** - when the *last* listener is removed, the chain unsubscribes from its source(s). In a longer chain this cascades down to the original source.
3. **Re-attach** - the next `addListener` subscribes again and refreshes the stored value *before* the new listener is registered, so nothing is missed and no spurious notification is sent.

While a chain is detached its `.value` is **derived from the current source value on read**, so it is never stale:

```dart
final source = ValueNotifier<int>(1);
final doubled = source.map((x) => x * 2);

void listener() {}
doubled.addListener(listener);
doubled.removeListener(listener); // last listener gone -> detached

source.value = 5;
print(doubled.value); // 10 ✓ derived on read, no subscription needed

doubled.addListener(listener); // re-attached, value already fresh
```

| Operator | `.value` while detached |
|---|---|
| `map`, `select` | transform / selector applied to the current source value |
| `where` | current source value if it passes the filter, otherwise the last passing value |
| `debounce`, `async` | current source value |
| `combineLatest` | combiner applied to the current source values |
| `mergeWith` | last received value (it can't know which source changed last) |

Because the transformation may run on read while detached, **keep transformation functions pure**.

**`lazy: true`** only changes step 1: the first subscription happens on the first listener instead of on creation. Before that, `.value` is derived on read exactly as for a detached chain, so `lazy: true` is a pure memory optimisation with no stale-value trade-off.


### Chain Lifecycle & Memory Management

Because a chain releases its source as soon as nobody listens to it any more, a chain that is created for a widget and discarded with it no longer leaves a dangling listener on the source. With watch_it, creating chains inline in a selector is therefore safe:

```dart
class MyWidget extends WatchingWidget {
  @override
  Widget build(BuildContext context) {
    // selector is cached (called once per widget instance); when the widget
    // is disposed the chain loses its listener and detaches from m.source
    final value = watchValue((Model m) => m.source.map((x) => x * 2));
    return Text('$value');
  }
}
```

Two things still matter:

❌ **Don't create chains on every rebuild** - each one is a new object doing work while it is attached:
```dart
Widget build(BuildContext context) {
  return ValueListenableBuilder(
    valueListenable: source.map((x) => x * 2), // NEW CHAIN EVERY REBUILD!
    builder: (context, value, _) => Text('$value'),
  );
}
```
Create the chain once instead (a field, `late final`, or `createOnce` with watch_it).

✅ **Chains you keep alive yourself** (e.g. as a field of a long-lived manager) stay attached while they have listeners and re-attach when needed - just like any other `ValueListenable`.

### Disposal & Garbage Collection

Chains don't require manual disposal in most cases. A chain without listeners holds no subscription on its source, so it is garbage collected as soon as nothing references it any more; and when the whole graph (source + chain) becomes unreachable, Dart's GC collects it regardless.

Call `dispose()` on a chain only when you want to end it explicitly while it still has listeners, or to be sure a pending `debounce` timer / `async` update is cancelled.

```dart
class MyService {
  final counter = ValueNotifier<int>(0);
  late final doubled = counter.map((x) => x * 2);

  void dispose() {
    counter.dispose(); // stops notifications; the chain is GC'd with the service
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

## AI-Assisted Development

This package ships an [Agent Skill](https://agentskills.io) for AI coding assistants
(Claude Code, Cursor, GitHub Copilot, Codex, Gemini CLI and others) in `skills/listen-it-expert/`.
It teaches them the critical rules, common patterns and anti-patterns of listen_it.
Install it into your project with the official Dart skills tool:

```bash
dart run skills@ get
```

For the ecosystem-wide skills (architecture guidance, feed/data-source patterns, overview)
and the skills of the other flutter_it packages run:

```bash
dart run skills@ add flutter-it/flutter_it
```

[Learn more about AI skills →](https://flutter-it.dev/misc/ai_skills)

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
