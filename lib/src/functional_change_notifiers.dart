import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:listen_it/src/functional_value_notifiers.dart'
    show ChainLifecycle;

abstract class FunctionalChangeNotifier extends ChangeNotifier
    with ChainLifecycle {
  final Listenable previousInChain;
  late VoidCallback internalHandler;

  FunctionalChangeNotifier(
    this.previousInChain,
  );

  void init(Listenable previousInChain);

  @protected
  void setupChain() {
    previousInChain.addListener(internalHandler);
    chainInitialized = true;
  }

  @override
  void attach() => init(previousInChain);

  @override
  void detach() => previousInChain.removeListener(internalHandler);

  /// A plain `Listenable` has no value that could be resynced.
  @override
  void resync() {}
}

class DebouncedChangeNotifier extends FunctionalChangeNotifier {
  Timer? debounceTimer;
  final Duration debounceDuration;

  DebouncedChangeNotifier(
    Listenable previousInChain,
    this.debounceDuration,
  ) : super(previousInChain) {
    init(previousInChain);
  }

  @override
  void init(Listenable previousInChain) {
    internalHandler = () {
      debounceTimer?.cancel();
      debounceTimer = Timer(debounceDuration, notifyListeners);
    };
    setupChain();
  }

  @override
  void detach() {
    debounceTimer?.cancel();
    debounceTimer = null;
    super.detach();
  }
}
