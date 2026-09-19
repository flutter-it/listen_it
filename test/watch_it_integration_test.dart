// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listen_it/listen_it.dart';
import 'package:watch_it/watch_it.dart';

/// The motivating scenario for detach-on-unobserved: a chain that is created
/// per widget instance inside a watch_it selector. Every widget instance
/// creates its own chain on a long-lived source; once the widget is disposed
/// the chain must not keep a listener on the source.
class Manager {
  final counter = ValueNotifier<int>(0);
  int mapCalls = 0;
}

class _CounterWidget extends WatchingWidget {
  const _CounterWidget();

  @override
  Widget build(BuildContext context) {
    final doubled = watchValue(
      (Manager m) => m.counter.map((v) {
        m.mapCalls++;
        return v * 2;
      }),
    );
    return Text('$doubled', textDirection: TextDirection.ltr);
  }
}

void main() {
  testWidgets(
      'chains created in watch_it selectors release the source on dispose',
      (tester) async {
    final manager = Manager();
    di.registerSingleton(manager);
    addTearDown(di.reset);

    for (var i = 0; i < 3; i++) {
      await tester.pumpWidget(const _CounterWidget());
      expect(manager.counter.hasListeners, isTrue);
      expect(find.text('${manager.counter.value * 2}'), findsOneWidget);

      manager.counter.value++;
      await tester.pump();
      expect(find.text('${manager.counter.value * 2}'), findsOneWidget);

      // Dispose the widget (and with it its chain).
      await tester.pumpWidget(const SizedBox());
      expect(manager.counter.hasListeners, isFalse);
    }

    final callsBefore = manager.mapCalls;
    manager.counter.value = 100;
    expect(manager.mapCalls, callsBefore);
  });
}
