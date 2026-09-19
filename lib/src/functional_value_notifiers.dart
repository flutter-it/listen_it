import 'dart:async';

import 'package:flutter/foundation.dart';

/// Shared attach/detach lifecycle of all operator notifiers.
///
/// A chain node subscribes to its source(s) ("attaches") either eagerly in its
/// constructor or, when created with `lazy: true`, on its first listener.
/// When its last listener is removed it detaches from its source(s) again so
/// that an unobserved chain never keeps a listener registered on a long-lived
/// source. The next [addListener] attaches again and [resync]s the stored
/// value from the source(s) before the new listener is registered, so the
/// resync itself never notifies the newly added listener.
///
/// While detached the stored value is not updated. Implementers override the
/// `value` getter to derive the value from the source(s) on read instead (see
/// [FunctionalValueNotifier] and [CombiningValueNotifierBase]), so reading
/// `.value` of an unobserved chain is always correct.
mixin ChainLifecycle on ChangeNotifier {
  /// `true` while this node is subscribed to its source(s).
  @protected
  bool chainInitialized = false;

  /// `true` while [addListener] attaches and resyncs, i.e. before the new
  /// listener is registered. Prevents [notifyListeners] from tearing the chain
  /// down again because of the (expected) missing listener during [resync].
  bool _attaching = false;

  /// Subscribes to the source(s).
  @protected
  void attach();

  /// Unsubscribes from the source(s).
  @protected
  void detach();

  /// Re-derives the stored value from the source(s). Called right after a
  /// node has been attached by [addListener] (lazy first attach or re-attach
  /// after a detach), before the listener is added, because the stored value
  /// may be stale from the time the node was not subscribed.
  @protected
  void resync();

  /// Detaches from the source(s). Called automatically when the last listener
  /// is removed.
  @protected
  @mustCallSuper
  void teardownChain() {
    detach();
    chainInitialized = false;
  }

  @override
  void addListener(VoidCallback listener) {
    if (!chainInitialized) {
      _attaching = true;
      try {
        attach();
        chainInitialized = true;
        resync();
      } finally {
        _attaching = false;
      }
    }
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (chainInitialized && !hasListeners) {
      teardownChain();
    }
  }

  /// Listeners that remove themselves while being notified (e.g. a
  /// `subscription.cancel()` inside a `listen` handler) are only removed
  /// after the notification has finished, so we have to re-check here.
  @override
  void notifyListeners() {
    super.notifyListeners();
    if (chainInitialized && !_attaching && !hasListeners) {
      teardownChain();
    }
  }

  @override
  void dispose() {
    if (chainInitialized) {
      detach();
      chainInitialized = false;
    }
    super.dispose();
  }
}

/// These classes are used to implement the listen_it implementation
///
abstract class FunctionalValueNotifier<TIn, TOut> extends ValueNotifier<TOut>
    with ChainLifecycle {
  final ValueListenable<TIn> previousInChain;
  late VoidCallback internalHandler;

  FunctionalValueNotifier(
    super.initialValue,
    this.previousInChain, {
    bool lazy = false,
  }) {
    if (!lazy) {
      // Eager initialization: subscribe immediately
      init(previousInChain);
    }
  }

  /// Assigns [internalHandler] and subscribes to [previousInChain] by calling
  /// [setupChain].
  void init(ValueListenable<TIn> previousInChain);

  @protected
  void setupChain() {
    previousInChain.addListener(internalHandler);
    chainInitialized = true;
  }

  /// The last value that was stored via the `value` setter.
  @protected
  TOut get storedValue => super.value;

  /// The value derived from the current value of [previousInChain]. Used by
  /// the `value` getter while this node is detached from its source.
  @protected
  TOut get derivedValue;

  @override
  TOut get value => chainInitialized ? storedValue : derivedValue;

  @override
  void attach() => init(previousInChain);

  @override
  void detach() => previousInChain.removeListener(internalHandler);

  @override
  void resync() => internalHandler();
}

class SelectValueNotifier<TIn, TOut>
    extends FunctionalValueNotifier<TIn, TOut> {
  final TOut Function(TIn) selector;

  SelectValueNotifier(
    super.initialValue,
    super.previousInChain,
    this.selector, {
    super.lazy,
  });

  @override
  void init(ValueListenable<TIn> previousInChain) {
    internalHandler = () {
      final selected = selector(previousInChain.value);
      if (selected != value) {
        value = selected;
      }
    };
    setupChain();
  }

  @override
  TOut get derivedValue => selector(previousInChain.value);
}

class MapValueNotifier<TIn, TOut> extends FunctionalValueNotifier<TIn, TOut> {
  final TOut Function(TIn) transformation;

  MapValueNotifier(
    super.initialValue,
    super.previousInChain,
    this.transformation, {
    super.lazy,
  });

  @override
  void init(ValueListenable<TIn> previousInChain) {
    internalHandler = () {
      value = transformation(previousInChain.value);
    };
    setupChain();
  }

  @override
  TOut get derivedValue => transformation(previousInChain.value);
}

class WhereValueNotifier<T> extends FunctionalValueNotifier<T, T> {
  final bool Function(T) selector;

  WhereValueNotifier(
    super.initialValue,
    super.previousInChain,
    this.selector, {
    super.lazy,
  });

  @override
  void init(ValueListenable<T> previousInChain) {
    internalHandler = () {
      if (selector(previousInChain.value)) {
        value = previousInChain.value;
      }
    };
    setupChain();
  }

  /// A source value that doesn't pass the filter is never exposed; in that
  /// case the last passing value (or the initial/fallback value) is kept.
  @override
  T get derivedValue {
    final current = previousInChain.value;
    return selector(current) ? current : storedValue;
  }
}

class DebouncedValueNotifier<T> extends FunctionalValueNotifier<T, T> {
  Timer? debounceTimer;
  final Duration debounceDuration;

  DebouncedValueNotifier(
    super.initialValue,
    super.previousInChain,
    this.debounceDuration, {
    super.lazy,
  });

  @override
  void init(ValueListenable<T> previousInChain) {
    internalHandler = () {
      debounceTimer?.cancel();
      debounceTimer = //
          Timer(debounceDuration, () => value = previousInChain.value);
    };
    setupChain();
  }

  @override
  T get derivedValue => previousInChain.value;

  @override
  void detach() {
    debounceTimer?.cancel();
    debounceTimer = null;
    super.detach();
  }

  /// On re-attach the current source value is taken over immediately instead
  /// of after [debounceDuration].
  @override
  void resync() => value = previousInChain.value;
}

class AsyncValueNotifier<T> extends FunctionalValueNotifier<T, T> {
  AsyncValueNotifier(
    super.initialValue,
    super.previousInChain, {
    super.lazy,
  });

  bool _disposed = false;

  @override
  void init(ValueListenable<T> previousInChain) {
    internalHandler = () {
      Future(() {
        // The chain may have been detached or disposed while the update was
        // pending. While detached `value` derives from the source anyway, and
        // writing to a disposed notifier would throw.
        if (_disposed || !chainInitialized) return;
        value = previousInChain.value;
      });
    };
    setupChain();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  T get derivedValue => previousInChain.value;

  /// On re-attach the current source value is taken over synchronously.
  @override
  void resync() => value = previousInChain.value;
}

/// Base of the `combineLatest` notifiers. Subclasses provide the [sources]
/// and how to [combine] their current values.
abstract class CombiningValueNotifierBase<TOut> extends ValueNotifier<TOut>
    with ChainLifecycle {
  late VoidCallback internalHandler;

  CombiningValueNotifierBase(super.initialValue, {bool lazy = false}) {
    if (!lazy) {
      // Eager initialization: subscribe immediately
      init();
    }
  }

  @protected
  List<Listenable> get sources;

  /// Combines the current values of all [sources].
  @protected
  TOut combine();

  void init() {
    internalHandler = () => value = combine();
    for (final source in sources) {
      source.addListener(internalHandler);
    }
    chainInitialized = true;
  }

  @override
  TOut get value => chainInitialized ? super.value : combine();

  @override
  void attach() => init();

  @override
  void detach() {
    for (final source in sources) {
      source.removeListener(internalHandler);
    }
  }

  @override
  void resync() => internalHandler();
}

typedef CombiningFunction2<TIn1, TIn2, TOut> = TOut Function(TIn1, TIn2);

class CombiningValueNotifier<TIn1, TIn2, TOut>
    extends CombiningValueNotifierBase<TOut> {
  final ValueListenable<TIn1> previousInChain1;
  final ValueListenable<TIn2> previousInChain2;
  final CombiningFunction2<TIn1, TIn2, TOut> combiner;

  CombiningValueNotifier(
    super.initialValue,
    this.previousInChain1,
    this.previousInChain2,
    this.combiner, {
    super.lazy,
  });

  @override
  List<Listenable> get sources => [previousInChain1, previousInChain2];

  @override
  TOut combine() => combiner(previousInChain1.value, previousInChain2.value);
}

typedef CombiningFunction3<TIn1, TIn2, TIn3, TOut> = TOut Function(
  TIn1,
  TIn2,
  TIn3,
);

class CombiningValueNotifier3<TIn1, TIn2, TIn3, TOut>
    extends CombiningValueNotifierBase<TOut> {
  final ValueListenable<TIn1> previousInChain1;
  final ValueListenable<TIn2> previousInChain2;
  final ValueListenable<TIn3> previousInChain3;
  final CombiningFunction3<TIn1, TIn2, TIn3, TOut> combiner;

  CombiningValueNotifier3(
    super.initialValue,
    this.previousInChain1,
    this.previousInChain2,
    this.previousInChain3,
    this.combiner, {
    super.lazy,
  });

  @override
  List<Listenable> get sources => [
        previousInChain1,
        previousInChain2,
        previousInChain3,
      ];

  @override
  TOut combine() => combiner(
        previousInChain1.value,
        previousInChain2.value,
        previousInChain3.value,
      );
}

typedef CombiningFunction4<TIn1, TIn2, TIn3, TIn4, TOut> = TOut Function(
  TIn1,
  TIn2,
  TIn3,
  TIn4,
);

class CombiningValueNotifier4<TIn1, TIn2, TIn3, TIn4, TOut>
    extends CombiningValueNotifierBase<TOut> {
  final ValueListenable<TIn1> previousInChain1;
  final ValueListenable<TIn2> previousInChain2;
  final ValueListenable<TIn3> previousInChain3;
  final ValueListenable<TIn4> previousInChain4;
  final CombiningFunction4<TIn1, TIn2, TIn3, TIn4, TOut> combiner;

  CombiningValueNotifier4(
    super.initialValue,
    this.previousInChain1,
    this.previousInChain2,
    this.previousInChain3,
    this.previousInChain4,
    this.combiner, {
    super.lazy,
  });

  @override
  List<Listenable> get sources => [
        previousInChain1,
        previousInChain2,
        previousInChain3,
        previousInChain4,
      ];

  @override
  TOut combine() => combiner(
        previousInChain1.value,
        previousInChain2.value,
        previousInChain3.value,
        previousInChain4.value,
      );
}

typedef CombiningFunction5<TIn1, TIn2, TIn3, TIn4, TIn5, TOut> = TOut Function(
  TIn1,
  TIn2,
  TIn3,
  TIn4,
  TIn5,
);

class CombiningValueNotifier5<TIn1, TIn2, TIn3, TIn4, TIn5, TOut>
    extends CombiningValueNotifierBase<TOut> {
  final ValueListenable<TIn1> previousInChain1;
  final ValueListenable<TIn2> previousInChain2;
  final ValueListenable<TIn3> previousInChain3;
  final ValueListenable<TIn4> previousInChain4;
  final ValueListenable<TIn5> previousInChain5;
  final CombiningFunction5<TIn1, TIn2, TIn3, TIn4, TIn5, TOut> combiner;

  CombiningValueNotifier5(
    super.initialValue,
    this.previousInChain1,
    this.previousInChain2,
    this.previousInChain3,
    this.previousInChain4,
    this.previousInChain5,
    this.combiner, {
    super.lazy,
  });

  @override
  List<Listenable> get sources => [
        previousInChain1,
        previousInChain2,
        previousInChain3,
        previousInChain4,
        previousInChain5,
      ];

  @override
  TOut combine() => combiner(
        previousInChain1.value,
        previousInChain2.value,
        previousInChain3.value,
        previousInChain4.value,
        previousInChain5.value,
      );
}

typedef CombiningFunction6<TIn1, TIn2, TIn3, TIn4, TIn5, TIn6, TOut> = TOut
    Function(TIn1, TIn2, TIn3, TIn4, TIn5, TIn6);

class CombiningValueNotifier6<TIn1, TIn2, TIn3, TIn4, TIn5, TIn6, TOut>
    extends CombiningValueNotifierBase<TOut> {
  final ValueListenable<TIn1> previousInChain1;
  final ValueListenable<TIn2> previousInChain2;
  final ValueListenable<TIn3> previousInChain3;
  final ValueListenable<TIn4> previousInChain4;
  final ValueListenable<TIn5> previousInChain5;
  final ValueListenable<TIn6> previousInChain6;
  final CombiningFunction6<TIn1, TIn2, TIn3, TIn4, TIn5, TIn6, TOut> combiner;

  CombiningValueNotifier6(
    super.initialValue,
    this.previousInChain1,
    this.previousInChain2,
    this.previousInChain3,
    this.previousInChain4,
    this.previousInChain5,
    this.previousInChain6,
    this.combiner, {
    super.lazy,
  });

  @override
  List<Listenable> get sources => [
        previousInChain1,
        previousInChain2,
        previousInChain3,
        previousInChain4,
        previousInChain5,
        previousInChain6,
      ];

  @override
  TOut combine() => combiner(
        previousInChain1.value,
        previousInChain2.value,
        previousInChain3.value,
        previousInChain4.value,
        previousInChain5.value,
        previousInChain6.value,
      );
}

class MergingValueNotifiers<T> extends FunctionalValueNotifier<T, T> {
  final List<ValueListenable<T>> mergeWith;
  late List<VoidCallback> disposeFuncs;

  MergingValueNotifiers(
    ValueListenable<T> previousInChain,
    this.mergeWith,
    T initialValue, {
    super.lazy = false, // mergeWith defaults to eager initialization
  }) : super(initialValue, previousInChain);

  @override
  void init(ValueListenable<T> previousInChain) {
    disposeFuncs = mergeWith.map<VoidCallback>(
      (notifier) {
        final notifyHandler = () => value = notifier.value;
        notifier.addListener(notifyHandler);
        return () => notifier.removeListener(notifyHandler);
      },
    ).toList();

    internalHandler = () => value = previousInChain.value;
    setupChain();
  }

  /// A merge can't know which of its sources changed last while it was
  /// detached, so it keeps the last value it received.
  @override
  T get derivedValue => storedValue;

  /// See [derivedValue]: nothing to resync from, the stored value is kept
  /// until the next change of any source.
  @override
  void resync() {}

  void _callSelf(VoidCallback handler) => handler.call();

  @override
  void detach() {
    disposeFuncs.forEach(_callSelf);
    super.detach();
  }
}
