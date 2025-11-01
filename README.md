# listen_it

**Reactive primitives for Flutter - observable collections and powerful operators**

Extension functions on `ValueListenable` that let you work with them almost like synchronous streams, plus reactive collections (ListNotifier, MapNotifier, SetNotifier) that automatically notify listeners when their contents change.

Previously published as `functional_listener`. Now includes reactive collections from `listenable_collections`.

## ✨ Features

### Reactive Collections
- 🔔 **Automatic Notifications** - Collections notify listeners on every mutation
- 📦 **Three Collection Types** - `ListNotifier`, `MapNotifier`, `SetNotifier`
- 🎯 **Three Notification Modes** - Fine-grained control over when notifications fire
- ⚡ **Transaction Support** - Batch multiple operations into a single notification
- 🔒 **Immutability** - Value getters return unmodifiable views
- 🎨 **Flutter Integration** - Works with `ValueListenableBuilder` or `watch_it`

### ValueListenable Operators
- 🔗 **Chainable** - Transform, filter, combine, and react to changes
- 🎯 **Selective updates** - React only to specific property changes with `select()`
- ⏱️ **Debouncing** - Control rapid value changes
- 🔀 **Combining** - Merge multiple ValueListenables together
- 📡 **Listening** - Install handlers that react to value changes

## 📦 Installation

```yaml
dependencies:
  listen_it: ^5.1.0
```

## 🚀 Quick Start

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
Lets you work with a `ValueListenable` by installing a handler function that is called on any value change:

```dart
final listenable = ValueNotifier<int>(0);
final subscription = listenable.listen((x, _) => print(x));
```

The returned `subscription` can be used to deactivate the handler. You can also cancel from inside the handler:

```dart
listenable.listen((x, subscription) {
  print(x);
  if (x == 42) {
     subscription.cancel();
  }
});
```

#### map()
Converts the value of one `ValueListenable` to anything you want:

```dart
ValueNotifier<String> source;

final upperCaseSource = source.map((s) => s.toUpperCase());

// Or change the type:
ValueNotifier<int> intNotifier;
final stringNotifier = intNotifier.map<String>((i) => i.toString());
```

#### where()
Filters the values that a ValueListenable can have:

```dart
ValueNotifier<int> intNotifier;
bool onlyEven = false;

final filteredNotifier = intNotifier.where((i) => onlyEven ? i.isEven : true);
```

#### select()
React only to changes in selected properties:

```dart
ValueNotifier<User> notifier = ValueNotifier(User(age: 18, name: "John"));

final birthdayNotifier = notifier.select<int>((model) => model.age);
// Will only notify when age changes, not when other properties change
```

#### Chaining functions
All extension functions (except `listen`) return a new `ValueNotifier`, so you can chain them:

```dart
ValueNotifier<int> intNotifier;

intNotifier
    .where((x) => x.isEven)
    .map<String>((s) => s.toString())
    .listen((s, _) => print(s));
```

#### debounce()
Only propagate values if there's a pause after a value changes. Great for search inputs:

```dart
ValueNotifier<String> searchTerm;

searchTerm
    .debounce(const Duration(milliseconds: 500))
    .listen((s, _) => callRestApi(s));
```

#### combineLatest()
Combines two source `ValueListenables` into one that updates when any source changes:

```dart
ValueNotifier<int> intNotifier;
ValueNotifier<String> stringNotifier;

intNotifier
    .combineLatest<String, StringIntWrapper>(
        stringNotifier,
        (i, s) => StringIntWrapper(s, i))
    .listen((combined, _) => print(combined));
```

#### mergeWith()
Merges value changes from multiple `ValueListenables`:

```dart
final listenable1 = ValueNotifier<int>(0);
final listenable2 = ValueNotifier<int>(0);
final listenable3 = ValueNotifier<int>(0);

listenable1
    .mergeWith([listenable2, listenable3])
    .listen((x, _) => print(x));
```

## 🎯 Notification Modes (Collections)

Choose when your UI should update:

```dart
// Normal mode - only notify on actual changes
final cart = SetNotifier<String>(
  notificationMode: CustomNotifierMode.normal,
);
cart.add('item1');    // ✅ Notifies (new item)
cart.add('item1');    // ❌ No notification (already exists)

// Always mode - notify on every operation (default)
final cart = SetNotifier<String>(
  notificationMode: CustomNotifierMode.always,
);
cart.add('item1');    // ✅ Notifies
cart.add('item1');    // ✅ Notifies (even though already exists)

// Manual mode - you control when to notify
final cart = SetNotifier<String>(
  notificationMode: CustomNotifierMode.manual,
);
cart.add('item1');
cart.add('item2');
cart.notifyListeners(); // ✅ Single notification for both adds
```

**Why the default is `always`?**
If users haven't overridden `==` operator, they expect UI updates even when setting the "same" value.

## 📊 Choosing the Right Collection

| Collection | Use When | Example Use Case |
|------------|----------|------------------|
| `ListNotifier<T>` | Order matters, duplicates allowed | Todo list, chat messages, search history |
| `MapNotifier<K,V>` | Need key-value lookups | User preferences, caches, form data |
| `SetNotifier<T>` | Unique items only, fast membership tests | Selected item IDs, active filters, tags |

## ⚡ Batch Updates with Transactions

Avoid unnecessary rebuilds by batching operations:

```dart
final products = ListNotifier<Product>();

// Without transaction: 3 UI updates
products.add(product1);
products.add(product2);
products.add(product3);

// With transaction: 1 UI update
products.startTransAction();
products.add(product1);
products.add(product2);
products.add(product3);
products.endTransAction();
```

## 🔍 Real-World Examples

### Shopping Cart Manager

```dart
class ShoppingCart {
  final items = MapNotifier<String, CartItem>();

  void addItem(Product product) {
    items[product.id] = CartItem(product: product, quantity: 1);
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      items.remove(productId);
    } else {
      items[productId] = items[productId]!.copyWith(quantity: quantity);
    }
  }

  double get total => items.values
      .fold(0.0, (sum, item) => sum + item.price * item.quantity);
}
```

### Reactive Search with Debounce

```dart
class SearchViewModel {
  final searchTerm = ValueNotifier<String>('');
  final results = ListNotifier<SearchResult>();

  SearchViewModel() {
    // Debounce search input to avoid excessive API calls
    searchTerm
        .debounce(const Duration(milliseconds: 300))
        .where((term) => term.length >= 3)
        .listen((term, _) => _performSearch(term));
  }

  Future<void> _performSearch(String term) async {
    final apiResults = await searchApi(term);
    results.startTransAction();
    results.clear();
    results.addAll(apiResults);
    results.endTransAction();
  }
}
```

## CustomValueNotifier

Sometimes you want a ValueNotifier where you can control when its listeners are notified:

```dart
enum CustomNotifierMode { normal, manual, always }

// Always mode - notify on every assignment
final notifier = CustomValueNotifier<int>(
  0,
  mode: CustomNotifierMode.always,
);

// Manual mode - only notify when you call notifyListeners()
final manualNotifier = CustomValueNotifier<int>(
  0,
  mode: CustomNotifierMode.manual,
);
manualNotifier.value = 42;
manualNotifier.value = 43;
manualNotifier.notifyListeners(); // Only now do listeners get notified
```

## 📚 Learn More

For more detailed examples and API documentation:
- [API Documentation](https://pub.dev/documentation/listen_it/latest/)
- [flutter-it.dev](https://flutter-it.dev) - Complete documentation for the entire flutter_it ecosystem

## 🔗 Part of the flutter_it Ecosystem

`listen_it` is part of the [flutter_it](https://flutter-it.dev) ecosystem:
- **get_it** - Dependency injection without the framework
- **watch_it** - Reactive UI updates, automatically (works great with listen_it!)
- **command_it** - Encapsulate actions with built-in state
- **listen_it** - Reactive primitives (you are here!)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

MIT License
