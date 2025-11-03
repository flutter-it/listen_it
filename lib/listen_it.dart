// ignore_for_file: unnecessary_this, directives_ordering, require_trailing_commas

/// Reactive primitives for Flutter - observable collections and powerful operators
///
/// Provides rx-like extensions on `Listenable` and `ValueListenable`
/// to work with them almost as if it was a synchronous stream.
/// Each extension function returns a new `Listenable` that updates its value when the value of `this` changes
/// You can chain these functions to build complex processing pipelines from a simple `Listenable`
/// In the examples we use [listen] to react on value changes. Instead of applying [listen] you
/// could also pass the end of the function chain to a `ValueListenableBuilder`
///
/// Also includes reactive collections (ListNotifier, MapNotifier, SetNotifier) that automatically
/// notify listeners when their contents change.
///
/// previously published as functional_listener
library listen_it;

import 'package:flutter/foundation.dart';
import 'package:listen_it/src/functional_change_notifiers.dart';
import 'package:listen_it/src/functional_value_notifiers.dart';

// Export operators
export 'package:listen_it/src/custom_value_notifier.dart';

// Export collections
export 'package:listen_it/src/collections/list_notifier.dart';
export 'package:listen_it/src/collections/map_notifier.dart';
export 'package:listen_it/src/collections/set_notifier.dart';

extension FunctionaListener2 on Listenable {
  ///
  /// let you work with a `Listenable` as it should be by installing a
  /// [handler] function that is called on any value change of `this` and gets
  /// the new value passed as an argument.
  /// It returns a subscription object that lets you stop the [handler] from
  /// being called by calling [cancel()] on the subscription.
  /// The [handler] get the subscription object passed on every call so that it
  /// is possible to uninstall the [handler] from the [handler] itself.
  ///
  /// example:
  /// ```
  ///
  /// final listenable = ChangeNotifier;
  /// final subscription = listenable.listen((_) => print('Notified'));
  ///
  /// final subscription = listenable.listen((subscription) {
  ///   print('Notified');
  ///   subscription.cancel();
  /// }
  ///
  ListenableSubscription listen(
    void Function(ListenableSubscription) handler,
  ) {
    final subscription = ListenableSubscription(simpleListenble: this);
    subscription.handler = () => handler(subscription);
    addListener(subscription.handler);
    return subscription;
  }

  Listenable debounce(Duration timeOut) {
    return DebouncedChangeNotifier(this, timeOut);
  }
}

/// extension functions on `ValueListenable` that allows you to work with them almost
/// as if it was a synchronous stream. Each extension function returns a new
/// `ValueNotifier` that updates its value when the value of `this` changes
/// You can chain these functions to build complex processing
/// pipelines from a simple `ValueListenable`
/// In the examples we use [listen] to react on value changes. Instead of applying [listen] you
/// could also pass the end of the function chain to a `ValueListenableBuilder`
extension FunctionaListener<T> on ValueListenable<T> {
  ///
  /// let you work with a `ValueListenable` as it should be by installing a
  /// [handler] function that is called on any value change of `this` and gets
  /// the new value passed as an argument.
  /// It returns a subscription object that lets you stop the [handler] from
  /// being called by calling [cancel()] on the subscription.
  /// The [handler] get the subscription object passed on every call so that it
  /// is possible to uninstall the [handler] from the [handler] itself.
  ///
  /// example:
  /// ```
  ///
  /// final listenable = ValueNotifier<int>(0);
  /// final subscription = listenable.listen((x, _) => print(x));
  ///
  /// final subscription = listenable.listen((x, subscription) {
  ///   print(x);
  ///   if (x == 42){
  ///      subscription.cancel();
  ///   }
  /// }
  ///
  ListenableSubscription listen(
    void Function(T, ListenableSubscription) handler,
  ) {
    final subscription = ListenableSubscription(endOfPipe: this);
    subscription.handler = () => handler(this.value, subscription);
    this.addListener(subscription.handler);
    return subscription;
  }

  ///
  /// converts a ValueListenable to another type [T] by returning a new connected
  /// `ValueListenable<T>`
  /// on each value change of `this` the conversion function
  /// [convert] is called to do the type conversion
  ///
  /// example (lets pretend that print wouldn't automatically call toString):
  /// ```
  /// final sourceListenable = ValueNotifier<int>(0);
  /// final subscription = sourceListenable.map<String>( (x)
  ///    => x.toString()).listen( (s,_) => print(x) );
  ///```
  ValueListenable<TResult> map<TResult>(TResult Function(T) convert,
      {bool lazy = false}) {
    return MapValueNotifier<T, TResult>(
      convert(this.value),
      this,
      convert,
      lazy: lazy,
    );
  }

  ///
  /// [select] allows you to set a filter on a `ValueListenable` like [where],
  /// and the returned `ValueListenable` only emit a new value when the returned value of [selector] function change.
  /// With this you can react on a specific value change of a property of the ValueListenable.
  ///
  /// example
  /// ```
  /// ValueNotifier<Size> sourceListenable = ValueNotifier<Size>(const Size(10, 10));
  /// int count = 0;
  /// var subscription = sourceListenable.select<double>((x)=> x.height).listen((_, __) => count++);
  ///
  /// sourceListenable.value = const Size(100,10);
  /// sourceListenable.value = const Size(200,200);
  ///```
  /// count will be just 1
  ValueListenable<TResult> select<TResult>(TResult Function(T) selector,
      {bool lazy = false}) {
    return SelectValueNotifier(
      selector(value),
      this,
      selector,
      lazy: lazy,
    );
  }

  ///
  /// [where] allows you to set a filter on a `ValueListenable` so that an installed
  /// handler function is only called if the passed
  /// [selector] function returns true. Because the selector function is called on
  /// every new value you can change the filter during runtime.
  ///
  /// [fallbackValue] is an optional parameter that provides a value to use when
  /// the initial value does not match the [selector] condition. If not provided,
  /// the initial value will be used regardless of whether it matches the filter
  /// (backward compatible behavior).
  ///
  /// ATTENTION: Due to the nature of ValueListeners that they always have to have
  /// a value, the filter can't prevent the initial value from being set unless
  /// you provide a [fallbackValue]. Therefore it's not advised to use [where]
  /// inside the Widget tree if you use `setState` because that will recreate the
  /// underlying `WhereValueNotifier` again passing through the latest value of
  /// `this` even if it doesn't fulfill the [selector] condition (unless you
  /// provide a [fallbackValue]).
  ///
  /// example: lets only print even values
  /// ```
  /// final sourceListenable = ValueNotifier<int>(0);
  /// final subscription = sourceListenable.where( (x)=>x.isEven )
  ///    .listen( (s,_) => print(x) );
  ///```
  ///
  /// example with fallbackValue:
  /// ```
  /// final sourceListenable = ValueNotifier<int>(5); // odd number
  /// final evens = sourceListenable.where(
  ///   (x) => x.isEven,
  ///   fallbackValue: 0,
  /// );
  /// print(evens.value); // 0 (fallback used because 5 is odd)
  ///```
  ValueListenable<T> where(
    bool Function(T) selector, {
    T? fallbackValue,
    bool lazy = false,
  }) {
    T initial;
    if (selector(this.value)) {
      // Initial value passes the filter - use it
      initial = this.value;
    } else if (fallbackValue != null) {
      // Initial value fails filter AND fallback provided - use fallback
      initial = fallbackValue;
    } else {
      // Initial value fails filter AND no fallback - use current value (backward compatible)
      initial = this.value;
    }
    return WhereValueNotifier(initial, this, selector, lazy: lazy);
  }

  ///
  /// If you get too much value changes during a short time period and you don't
  /// want or can handle them all [debounce] can help you.
  /// If you add a [debounce] to your listenable processing pipeline the returned
  /// `ValueListenable` will not emit an updated value before at least
  /// [timpeout] time has passed since the last value change. All value changes
  /// before will be discarded.
  ///
  /// ATTENTION: If you use [debounce] inside the Widget tree in combination with
  /// `setState` it can happen that debounce doesn't have any effect. Better to use it
  /// inside your model objects
  ///
  /// example:
  /// ```
  /// final listenable = ValueNotifier<int>(0);
  ///
  /// listenable
  ///     .debounce(const Duration(milliseconds: 500))
  ///     .listen((x, _) => print(x));
  ///
  /// listenable.value = 42;
  /// await Future.delayed(const Duration(milliseconds: 100));
  /// listenable.value = 43;
  /// await Future.delayed(const Duration(milliseconds: 100));
  /// listenable.value = 44;
  /// await Future.delayed(const Duration(milliseconds: 350));
  /// listenable.value = 45;
  /// await Future.delayed(const Duration(milliseconds: 550));
  /// listenable.value = 46;
  ///
  /// ```
  ///  will print out 45
  ///
  ValueListenable<T> debounce(Duration timeOut, {bool lazy = false}) {
    return DebouncedValueNotifier(this.value, this, timeOut, lazy: lazy);
  }

  /// ValueListenable are inherently synchronous. In most cases this is what you
  /// want. But if for example your ValueListenable gets updated inside a build
  /// method of a widget which would trigger a rebuild because your widgets is
  /// listening to the ValueListenable you get an exception that you called setState
  /// inside a build method.
  /// By using [async] you push the update of the ValueListenable to the next
  /// frame. This way you can update the ValueListenable inside a build method
  /// without getting an exception.
  ValueListenable<T> async({bool lazy = false}) {
    return AsyncValueNotifier(
      this.value,
      this,
      lazy: lazy,
    );
  }

  ///
  /// Imagine having two `ValueNotifier` in you model and you want to update
  /// a certain region of the screen with their values every time one of them
  /// get updated.
  /// [combineLatest] combines two `ValueListenable` in that way that it returns
  /// a new `ValueNotifier` that changes its value of [TOut] whenever one of the
  /// input listenables [this] or [combineWith] updates its value. This new value
  /// is built by the [combiner] function that is called on any value change of
  /// the input listenables.
  ///
  /// example:
  /// ```
  ///    class StringIntWrapper {
  ///      final String s;
  ///      final int i;
  ///
  ///      StringIntWrapper(this.s, this.i);
  ///
  ///      @override
  ///      String toString() {
  ///        return '$s:$i';
  ///      }
  ///    }
  ///
  ///    final listenable1 = ValueNotifier<int>(0);
  ///    final listenable2 = ValueNotifier<String>('Start');
  ///
  ///    final destValues = <StringIntWrapper>[];
  ///    final subscription = listenable1
  ///        .combineLatest<String, StringIntWrapper>(
  ///            listenable2, (i, s) => StringIntWrapper(s, i))
  ///        .listen((x, _) {
  ///      destValues.add(x);
  ///    });
  ///
  ///    listenable1.value = 42;
  ///    listenable1.value = 43;
  ///    listenable2.value = 'First';
  ///    listenable1.value = 45;
  ///
  ///    expect(destValues[0].toString(), 'Start:42');
  ///    expect(destValues[1].toString(), 'Start:43');
  ///    expect(destValues[2].toString(), 'First:43');
  ///    expect(destValues[3].toString(), 'First:45');
  ///  ```
  ///
  ValueListenable<TOut> combineLatest<TIn2, TOut>(
    ValueListenable<TIn2> combineWith,
    CombiningFunction2<T, TIn2, TOut> combiner, {
    bool lazy = false,
  }) {
    return CombiningValueNotifier<T, TIn2, TOut>(
      combiner(this.value, combineWith.value),
      this,
      combineWith,
      combiner,
      lazy: lazy,
    );
  }

  ///
  /// Similar to what [combineLatest] does. Only change is you can listen to 3 ValueNotifiers together
  /// usage e.g:
  /// final subscription = listenable1
  //         .combineLatest3<String, String, String>(
  //             listenable2, listenable3, (i, j, s) => "$i:$j:$s")
  //         .listen((x, _) {
  //       print(x);
  //     });
  ValueListenable<TOut> combineLatest3<TIn2, TIn3, TOut>(
      ValueListenable<TIn2> combineWith2,
      ValueListenable<TIn3> combineWith3,
      CombiningFunction3<T, TIn2, TIn3, TOut> combiner,
      {bool lazy = false}) {
    return CombiningValueNotifier3<T, TIn2, TIn3, TOut>(
      combiner(this.value, combineWith2.value, combineWith3.value),
      this,
      combineWith2,
      combineWith3,
      combiner,
      lazy: lazy,
    );
  }

  ///
  /// Similar to what [combineLatest] does. Only change is you can listen to 4 ValueNotifiers together
  /// usage e.g:
  /// final subscription = listenable1
  //         .combineLatest4<String, String, String, String>(
  //             listenable2, listenable3, listenable4, (i, j, k, s) => "$i:$j:$k:$s")
  //         .listen((x, _) {
  //       print(x);
  //     });
  ValueListenable<TOut> combineLatest4<TIn2, TIn3, TIn4, TOut>(
      ValueListenable<TIn2> combineWith2,
      ValueListenable<TIn3> combineWith3,
      ValueListenable<TIn4> combineWith4,
      CombiningFunction4<T, TIn2, TIn3, TIn4, TOut> combiner,
      {bool lazy = false}) {
    return CombiningValueNotifier4<T, TIn2, TIn3, TIn4, TOut>(
      combiner(this.value, combineWith2.value, combineWith3.value,
          combineWith4.value),
      this,
      combineWith2,
      combineWith3,
      combineWith4,
      combiner,
      lazy: lazy,
    );
  }

  ///
  /// Similar to what [combineLatest] does. Only change is you can listen to 5 ValueNotifiers together
  /// usage e.g:
  /// final subscription = listenable1
  //         .combineLatest5<String, String, String, String, String>(
  //             listenable2,
  //             listenable3,
  //             listenable4,
  //             listenable5,
  //             (i, j, k, l, s) => "$i:$j:$k:$l:$s")
  //         .listen((x, _) {
  //       print(x);
  //     });
  ValueListenable<TOut> combineLatest5<TIn2, TIn3, TIn4, TIn5, TOut>(
      ValueListenable<TIn2> combineWith2,
      ValueListenable<TIn3> combineWith3,
      ValueListenable<TIn4> combineWith4,
      ValueListenable<TIn5> combineWith5,
      CombiningFunction5<T, TIn2, TIn3, TIn4, TIn5, TOut> combiner,
      {bool lazy = false}) {
    return CombiningValueNotifier5<T, TIn2, TIn3, TIn4, TIn5, TOut>(
      combiner(this.value, combineWith2.value, combineWith3.value,
          combineWith4.value, combineWith5.value),
      this,
      combineWith2,
      combineWith3,
      combineWith4,
      combineWith5,
      combiner,
      lazy: lazy,
    );
  }

  ///
  /// Similar to what [combineLatest] does. Only change is you can listen to 6 ValueNotifiers together
  /// usage e.g:
  /// final subscription = listenable1
  ///         .combineLatest6<String, String, String, String, String, String>(
  ///             listenable2,
  ///             listenable3,
  ///             listenable4,
  ///             listenable5,
  ///             listenable6,
  ///             (i, j, k, l, m, s) => "$i:$j:$k:$l:$m:$s")
  ///         .listen((x, _) {
  ///       print(x);
  ///     });
  ValueListenable<TOut> combineLatest6<TIn2, TIn3, TIn4, TIn5, TIn6, TOut>(
      ValueListenable<TIn2> combineWith2,
      ValueListenable<TIn3> combineWith3,
      ValueListenable<TIn4> combineWith4,
      ValueListenable<TIn5> combineWith5,
      ValueListenable<TIn6> combineWith6,
      CombiningFunction6<T, TIn2, TIn3, TIn4, TIn5, TIn6, TOut> combiner,
      {bool lazy = false}) {
    return CombiningValueNotifier6<T, TIn2, TIn3, TIn4, TIn5, TIn6, TOut>(
      combiner(this.value, combineWith2.value, combineWith3.value,
          combineWith4.value, combineWith5.value, combineWith6.value),
      this,
      combineWith2,
      combineWith3,
      combineWith4,
      combineWith5,
      combineWith6,
      combiner,
      lazy: lazy,
    );
  }

  /// Merges value changes of [this] together with value changes of a List of
  /// `ValueListenables` so that when ever any of them changes the result of
  /// [mergeWith] will change too.
  ///
  /// By default, [mergeWith] uses eager initialization ([lazy] = false), meaning
  /// it subscribes to all sources immediately and the `.value` getter will always
  /// reflect the most recent value from any source, even before adding a listener.
  ///
  /// If [lazy] is true, subscription to sources is delayed until the first listener
  /// is added. This can improve performance when creating many merges that might
  /// not be used, but `.value` will be stale until a listener is added.
  ///
  /// ```
  ///     final listenable1 = ValueNotifier<int>(0);
  ///     final listenable2 = ValueNotifier<int>(0);
  ///     final listenable3 = ValueNotifier<int>(0);
  ///     final listenable4 = ValueNotifier<int>(0);
  ///
  ///     listenable1.mergeWith([listenable2, listenable3, listenable4])
  ///          .listen((x, _) => print(x));
  ///
  ///     listenable2.value = 42;
  ///     listenable1.value = 43;
  ///     listenable4.value = 44;
  ///     listenable3.value = 45;
  ///     listenable1.value = 46;
  ///     ```
  ///   Will print 42,43,44,45,46
  ///
  /// Example with eager initialization (default):
  /// ```dart
  /// final notifier1 = ValueNotifier<int>(0);
  /// final notifier2 = ValueNotifier<int>(100);
  /// final merged = notifier1.mergeWith([notifier2]);
  /// print(merged.value); // Prints 100 (most recent value across all sources)
  /// ```
  ///
  /// Example with lazy initialization:
  /// ```dart
  /// final notifier1 = ValueNotifier<int>(0);
  /// final notifier2 = ValueNotifier<int>(100);
  /// final merged = notifier1.mergeWith([notifier2], lazy: true);
  /// print(merged.value); // Prints 0 (only knows about notifier1 at creation)
  /// merged.addListener(() {});
  /// print(merged.value); // Now prints 100 (subscribed to all sources)
  /// ```
  ///
  ValueListenable<T> mergeWith(
    List<ValueListenable<T>> mergeWith, {
    bool lazy = false,
  }) =>
      MergingValueNotifiers<T>(this, mergeWith, this.value, lazy: lazy);
}

/// Object that is returned by [listen] that allows you to stop the calling of the
/// handler that you passed to it.
class ListenableSubscription {
  final ValueListenable? endOfPipe;
  final Listenable? simpleListenble;
  late VoidCallback handler;
  bool canceled = false;

  ListenableSubscription({this.endOfPipe, this.simpleListenble})
      : assert(endOfPipe != null || simpleListenble != null),
        assert(!(endOfPipe != null && simpleListenble != null));

  /// Removes the handler that you installed with [listen]
  /// It's save to call cancel on an already canceled subscription
  void cancel() {
    if (!canceled) {
      simpleListenble?.removeListener(handler);
      endOfPipe?.removeListener(handler);
      canceled = true;
    }
  }
}
