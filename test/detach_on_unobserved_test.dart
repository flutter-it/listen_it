// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listen_it/listen_it.dart';
import 'package:listen_it/src/functional_change_notifiers.dart';
import 'package:listen_it/src/functional_value_notifiers.dart';

/// Tests for the "detach on unobserved" chain lifecycle (v6.0.0):
///
/// - a chain detaches from its source(s) when its last listener is removed
///   and re-attaches on the next listener
/// - while detached `.value` is derived from the current source value(s) on
///   read (except `mergeWith`), so the scenario from
///   https://github.com/escamoteur/functional_listener/issues/13 works
void main() {
  group(
    'async - pending update after detach/dispose',
    _asyncPendingUpdateTests,
  );

  group('issue #13 - value stays correct after the last listener was removed',
      () {
    test('map', () {
      final original = ValueNotifier<int>(0);
      final mapped = original.map((v) => v + 1);
      void l() {}
      mapped.addListener(l);
      mapped.removeListener(l);

      original.value = 123;
      expect(mapped.value, 124);
    });

    test('select', () {
      final original = ValueNotifier<int>(0);
      final selected = original.select((v) => v.isEven);
      void l() {}
      selected.addListener(l);
      selected.removeListener(l);

      original.value = 123;
      expect(selected.value, false);
      original.value = 124;
      expect(selected.value, true);
    });

    test('where - passing current value', () {
      final original = ValueNotifier<int>(0);
      final evens = original.where((v) => v.isEven);
      void l() {}
      evens.addListener(l);
      evens.removeListener(l);

      original.value = 124;
      expect(evens.value, 124);
    });

    test('where - non-passing current value keeps last passing value', () {
      final original = ValueNotifier<int>(0);
      final evens = original.where((v) => v.isEven);
      void l() {}
      evens.addListener(l);
      original.value = 2;
      evens.removeListener(l);

      original.value = 123;
      expect(evens.value, 2);
    });

    test('debounce', () {
      final original = ValueNotifier<int>(0);
      final debounced = original.debounce(const Duration(seconds: 1));
      void l() {}
      debounced.addListener(l);
      debounced.removeListener(l);

      original.value = 123;
      expect(debounced.value, 123);
    });

    test('async', () {
      final original = ValueNotifier<int>(0);
      final async = original.async();
      void l() {}
      async.addListener(l);
      async.removeListener(l);

      original.value = 123;
      expect(async.value, 123);
    });

    test('combineLatest2', () {
      final a = ValueNotifier<int>(0);
      final b = ValueNotifier<int>(0);
      final combined = a.combineLatest<int, int>(b, (x, y) => x + y);
      void l() {}
      combined.addListener(l);
      combined.removeListener(l);

      a.value = 100;
      b.value = 23;
      expect(combined.value, 123);
    });

    test('3-operator chain', () {
      final original = ValueNotifier<int>(0);
      final chain = original
          .map((v) => v + 1)
          .where((v) => v.isEven)
          .select((v) => 'value: $v');
      void l() {}
      chain.addListener(l);
      chain.removeListener(l);

      original.value = 123;
      expect(chain.value, 'value: 124');

      // 125 doesn't pass the filter: where() falls back to its stored value,
      // which is still the initial one because 124 arrived while detached.
      original.value = 124;
      expect(chain.value, 'value: 1');
    });
  });

  group('attach / detach cascade', () {
    test('3-operator chain detaches and re-attaches through all levels', () {
      final source = ValueNotifier<int>(1);
      final mapped = source.map((v) => v * 10) as MapValueNotifier<int, int>;
      final filtered = mapped.where((v) => v > 5) as WhereValueNotifier<int>;
      final selected =
          filtered.select((v) => '$v') as SelectValueNotifier<int, String>;

      // Eager chains are attached on creation.
      expect(source.hasListeners, isTrue);
      expect(mapped.hasListeners, isTrue);
      expect(filtered.hasListeners, isTrue);
      expect(selected.hasListeners, isFalse);
      expect(source.hasListeners, isTrue);

      final values = <String>[];
      void l() => values.add(selected.value);
      selected.addListener(l);

      source.value = 2;
      expect(values, ['20']);

      // Removing the last outer listener cascades the detach down to the source.
      selected.removeListener(l);
      expect(selected.hasListeners, isFalse);
      expect(filtered.hasListeners, isFalse);
      expect(mapped.hasListeners, isFalse);
      expect(source.hasListeners, isFalse);
      expect(selected.chainInitialized, isFalse);
      expect(filtered.chainInitialized, isFalse);
      expect(mapped.chainInitialized, isFalse);

      // Detached values are derived on read through all levels.
      source.value = 3;
      expect(mapped.value, 30);
      expect(filtered.value, 30);
      expect(selected.value, '30');

      // Re-attach cascades up to the source and values are fresh.
      selected.addListener(l);
      expect(source.hasListeners, isTrue);
      expect(mapped.chainInitialized, isTrue);
      expect(filtered.chainInitialized, isTrue);
      expect(selected.chainInitialized, isTrue);
      expect(mapped.value, 30);
      expect(filtered.value, 30);
      expect(selected.value, '30');
      expect(values, ['20']); // resync didn't notify

      source.value = 4;
      expect(values, ['20', '40']);

      selected.removeListener(l);
      expect(source.hasListeners, isFalse);
    });

    test('combineLatest detaches from all sources', () {
      final a = ValueNotifier<int>(1);
      final b = ValueNotifier<int>(2);
      final combined = a.combineLatest<int, int>(b, (x, y) => x + y);

      expect(a.hasListeners, isTrue);
      expect(b.hasListeners, isTrue);

      void l() {}
      combined.addListener(l);
      combined.removeListener(l);

      expect(a.hasListeners, isFalse);
      expect(b.hasListeners, isFalse);

      combined.addListener(l);
      expect(a.hasListeners, isTrue);
      expect(b.hasListeners, isTrue);
      combined.removeListener(l);
    });

    test('mergeWith detaches from all sources', () {
      final a = ValueNotifier<int>(1);
      final b = ValueNotifier<int>(2);
      final c = ValueNotifier<int>(3);
      final merged = a.mergeWith([b, c]);

      expect(a.hasListeners, isTrue);
      expect(b.hasListeners, isTrue);
      expect(c.hasListeners, isTrue);

      void l() {}
      merged.addListener(l);
      merged.removeListener(l);

      expect(a.hasListeners, isFalse);
      expect(b.hasListeners, isFalse);
      expect(c.hasListeners, isFalse);

      merged.addListener(l);
      expect(a.hasListeners, isTrue);
      expect(b.hasListeners, isTrue);
      expect(c.hasListeners, isTrue);
      merged.removeListener(l);
    });

    test('Listenable.debounce detaches from its source', () async {
      final source = ChangeNotifier();
      final debounced = source.debounce(const Duration(milliseconds: 5))
          as DebouncedChangeNotifier;
      expect(source.hasListeners, isTrue);

      var count = 0;
      void l() => count++;
      debounced.addListener(l);
      source.notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(count, 1);

      debounced.removeListener(l);
      expect(source.hasListeners, isFalse);

      // A pending timer is cancelled on detach.
      debounced.addListener(l);
      source.notifyListeners();
      debounced.removeListener(l);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(count, 1);

      debounced.addListener(l);
      expect(source.hasListeners, isTrue);
      source.notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(count, 2);
      debounced.removeListener(l);
    });
  });

  group('notifications across detach / re-attach', () {
    test('resync does not notify the newly added listener', () {
      final source = ValueNotifier<int>(0);
      final mapped = source.map((v) => v * 2);
      void l1() {}
      mapped.addListener(l1);
      mapped.removeListener(l1);

      source.value = 5; // changes while detached

      var notified = 0;
      mapped.addListener(() => notified++);
      expect(mapped.value, 10);
      expect(notified, 0);
    });

    test('no notification is lost or duplicated', () {
      final source = ValueNotifier<int>(0);
      final mapped = source.map((v) => v * 2);

      final seen = <int>[];
      void l() => seen.add(mapped.value);
      mapped.addListener(l);
      source.value = 1;
      expect(seen, [2]);

      mapped.removeListener(l);
      source.value = 2; // detached: no notification, but value is derived
      expect(mapped.value, 4);
      expect(seen, [2]);

      mapped.addListener(l);
      expect(seen, [2]); // listener sees the new value via .value only
      expect(mapped.value, 4);

      source.value = 3; // notified exactly once on the NEXT change
      expect(seen, [2, 6]);
      mapped.removeListener(l);
    });

    test('select does not notify on re-attach when selected value is unchanged',
        () {
      final source = ValueNotifier<int>(0);
      final selected = source.select((v) => v.isEven);
      var notified = 0;
      void l() => notified++;
      selected.addListener(l);
      selected.removeListener(l);

      source.value = 2; // still even
      selected.addListener(l);
      expect(notified, 0);
      source.value = 3;
      expect(notified, 1);
      selected.removeListener(l);
    });

    test('listener that cancels itself during notification detaches the chain',
        () {
      final source = ValueNotifier<int>(0);
      final mapped = source.map((v) => v * 2);

      var calls = 0;
      mapped.listen((v, subscription) {
        calls++;
        subscription.cancel();
      });
      expect(source.hasListeners, isTrue);

      source.value = 1;
      expect(calls, 1);
      expect(source.hasListeners, isFalse);
      expect(mapped.value, 2);

      source.value = 2;
      expect(calls, 1);
      expect(mapped.value, 4);
    });
  });

  group('listen()', () {
    test('subscription keeps the chain attached until cancelled', () {
      final source = ValueNotifier<int>(0);
      final mapped = source.map((v) => v * 2);

      final seen = <int>[];
      final subscription = mapped.listen((v, _) => seen.add(v));
      expect(source.hasListeners, isTrue);

      source.value = 1;
      source.value = 2;
      expect(seen, [2, 4]);

      subscription.cancel();
      expect(source.hasListeners, isFalse);
      source.value = 3;
      expect(seen, [2, 4]);
    });

    test('fire-and-forget listen on an inline chain keeps working', () {
      final source = ValueNotifier<int>(0);
      final seen = <int>[];
      source
          .map((v) => v * 2)
          .where((v) => v > 2)
          .listen((v, _) => seen.add(v));

      source.value = 1;
      source.value = 2;
      source.value = 3;
      expect(seen, [4, 6]);
      expect(source.hasListeners, isTrue);
    });
  });

  group('dispose()', () {
    test('on an attached chain removes the source listener', () {
      final source = ValueNotifier<int>(0);
      final mapped = source.map((v) => v * 2) as MapValueNotifier<int, int>;
      mapped.addListener(() {});
      expect(source.hasListeners, isTrue);

      mapped.dispose();
      expect(source.hasListeners, isFalse);
    });

    test('on a detached chain does not throw', () {
      final source = ValueNotifier<int>(0);
      final mapped = source.map((v) => v * 2) as MapValueNotifier<int, int>;
      void l() {}
      mapped.addListener(l);
      mapped.removeListener(l);
      expect(source.hasListeners, isFalse);

      expect(mapped.dispose, returnsNormally);
      expect(source.hasListeners, isFalse);
    });

    test('on a never attached lazy chain does not throw', () {
      final source = ValueNotifier<int>(0);
      final mapped =
          source.map((v) => v * 2, lazy: true) as MapValueNotifier<int, int>;
      expect(mapped.dispose, returnsNormally);
    });

    test('on an attached debounce cancels the pending timer', () async {
      final source = ValueNotifier<int>(0);
      final debounced = source.debounce(const Duration(milliseconds: 5))
          as DebouncedValueNotifier<int>;
      debounced.addListener(() {});
      source.value = 1;
      debounced.dispose();
      // would throw "used after being disposed" if the timer still fired
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(source.hasListeners, isFalse);
    });

    test('on an attached combineLatest and mergeWith removes all listeners',
        () {
      final a = ValueNotifier<int>(0);
      final b = ValueNotifier<int>(0);
      final combined = a.combineLatest<int, int>(b, (x, y) => x + y)
          as CombiningValueNotifier<int, int, int>;
      final merged = a.mergeWith([b]) as MergingValueNotifiers<int>;
      combined.addListener(() {});
      merged.addListener(() {});

      combined.dispose();
      merged.dispose();
      expect(a.hasListeners, isFalse);
      expect(b.hasListeners, isFalse);
    });
  });

  group('lazy chains', () {
    test('behave the same after the first attach', () {
      final source = ValueNotifier<int>(1);
      final mapped = source.map((v) => v * 2, lazy: true);
      expect(source.hasListeners, isFalse);
      expect(mapped.value, 2); // derived on read while not attached

      source.value = 2;
      expect(mapped.value, 4);

      void l() {}
      mapped.addListener(l);
      expect(source.hasListeners, isTrue);
      expect(mapped.value, 4); // resynced on first attach

      mapped.removeListener(l);
      expect(source.hasListeners, isFalse);
      source.value = 3;
      expect(mapped.value, 6);

      mapped.addListener(l);
      expect(source.hasListeners, isTrue);
      expect(mapped.value, 6);
      mapped.removeListener(l);
    });

    test('lazy 3-operator chain', () {
      final source = ValueNotifier<int>(1);
      final chain = source
          .map((v) => v * 10, lazy: true)
          .where((v) => v > 5, lazy: true)
          .select((v) => '$v', lazy: true);
      expect(source.hasListeners, isFalse);
      source.value = 2;
      expect(chain.value, '20');

      void l() {}
      chain.addListener(l);
      expect(source.hasListeners, isTrue);
      expect(chain.value, '20');
      chain.removeListener(l);
      expect(source.hasListeners, isFalse);
    });
  });

  group('where() with fallbackValue', () {
    test('keeps fallback while no value passed, derives on read otherwise', () {
      final source = ValueNotifier<int>(1);
      final evens = source.where((v) => v.isEven, fallbackValue: 0);
      expect(evens.value, 0);

      void l() {}
      evens.addListener(l);
      evens.removeListener(l);

      source.value = 3; // still nothing passed
      expect(evens.value, 0);

      source.value = 4;
      expect(evens.value, 4);

      evens.addListener(l);
      expect(evens.value, 4);

      source.value = 5; // doesn't pass: keeps last passing value
      expect(evens.value, 4);
      evens.removeListener(l);

      source.value = 7;
      expect(evens.value, 4);
    });
  });

  group('mergeWith', () {
    test('keeps the last received value while detached (documented limitation)',
        () {
      final a = ValueNotifier<int>(1);
      final b = ValueNotifier<int>(2);
      final merged = a.mergeWith([b]);
      expect(merged.value, 1);

      void l() {}
      merged.addListener(l);
      b.value = 20;
      expect(merged.value, 20);
      merged.removeListener(l);

      // Can't know which source changed last while detached.
      a.value = 10;
      expect(merged.value, 20);

      // Re-attaching keeps the stored value; next change of any source updates.
      merged.addListener(l);
      expect(merged.value, 20);
      a.value = 11;
      expect(merged.value, 11);
      merged.removeListener(l);
    });
  });

  group('transformation functions', () {
    test('are called on read while detached and not on source changes', () {
      final source = ValueNotifier<int>(0);
      var calls = 0;
      final mapped = source.map((v) {
        calls++;
        return v * 2;
      });
      expect(calls, 1); // initial value

      void l() {}
      mapped.addListener(l);
      source.value = 1;
      expect(calls, 2);
      mapped.removeListener(l);

      source.value = 2;
      source.value = 3;
      expect(calls, 2); // not subscribed anymore
      expect(mapped.value, 6);
      expect(calls, 3); // derived on read
    });
  });
}

void _asyncPendingUpdateTests() {
  test('async: pending update after dispose does not throw', () async {
    final source = ValueNotifier<int>(0);
    final asyncChain = source.async() as AsyncValueNotifier<int>;
    asyncChain.addListener(() {});
    source.value = 1; // schedules the async update
    asyncChain.dispose(); // before the scheduled update runs
    await Future<void>.delayed(Duration.zero);
    // no "used after being disposed" assertion
    source.value = 2;
    await Future<void>.delayed(Duration.zero);
  });

  test('async: pending update after detach is ignored, re-attach resyncs',
      () async {
    final source = ValueNotifier<int>(0);
    final asyncChain = source.async();
    void l() {}
    asyncChain.addListener(l);
    source.value = 1; // schedules the async update
    asyncChain.removeListener(l); // detaches before the update runs
    await Future<void>.delayed(Duration.zero);
    expect(asyncChain.value, 1, reason: 'derived from source while detached');
    var notified = 0;
    asyncChain.addListener(() => notified++);
    expect(asyncChain.value, 1);
    expect(notified, 0, reason: 'resync must not notify the new listener');
    source.value = 2;
    await Future<void>.delayed(Duration.zero);
    expect(asyncChain.value, 2);
    expect(notified, 1);
  });
}
