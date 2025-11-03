// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listen_it/listen_it.dart';

void main() {
  test('map() with eager initialization (default) - value always correct', () {
    final source = ValueNotifier<int>(5);
    final mapped = source.map((x) => x * 2); // Default: lazy=false (eager)

    print('1. Initial: mapped.value = ${mapped.value}'); // Should be 10
    expect(mapped.value, 10);

    source.value =
        7; // Change source WITHOUT listener - eager means it updates!
    print(
      '2. After source.value = 7 (no listener): mapped.value = ${mapped.value}',
    );
    expect(mapped.value, 14); // Eager: value is correct even without listener!

    // Add listener
    mapped.addListener(() {});
    print('3. After adding listener: mapped.value = ${mapped.value}');

    source.value = 10; // Change source WITH listener
    print(
      '4. After source.value = 10 (with listener): mapped.value = ${mapped.value}',
    );
    expect(mapped.value, 20);

    source.dispose();
  });

  test(
      'mergeWith() with eager initialization (default) - updates without listener',
      () {
    final notifier1 = ValueNotifier<int>(0);
    final notifier2 = ValueNotifier<int>(100);

    final merged =
        notifier1.mergeWith([notifier2]); // Default: lazy=false (eager)
    print('5. Initial: merged.value = ${merged.value}');
    // Note: Initial value is notifier1's value (0), not notifier2's (100)
    // because mergeWith doesn't know which source has the "most recent" value
    expect(merged.value, 0);

    notifier2.value = 200; // Change notifier2 WITHOUT listener - eager updates!
    print(
      '6. After notifier2.value = 200 (no listener): merged.value = ${merged.value}',
    );
    expect(merged.value, 200); // Eager: value is correct even without listener!

    merged.addListener(() {});
    print('7. After adding listener: merged.value = ${merged.value}');
    expect(merged.value, 200);

    notifier2.value = 300; // Change WITH listener
    print(
      '8. After notifier2.value = 300 (with listener): merged.value = ${merged.value}',
    );
    expect(merged.value, 300);

    notifier1.dispose();
    notifier2.dispose();
  });

  test('map() with lazy initialization - value is stale without listener', () {
    final source = ValueNotifier<int>(5);
    final mapped = source.map((x) => x * 2, lazy: true); // Explicit lazy

    expect(mapped.value, 10); // Initial computed value

    source.value = 7; // Change source WITHOUT listener
    expect(mapped.value, 10); // STALE! Lazy means no subscription, so no update

    // Add listener - subscribes but doesn't retroactively update the value
    mapped.addListener(() {});
    expect(
      mapped.value,
      10,
    ); // STILL STALE! Lazy init doesn't retroactively update

    source.value = 10; // Change WITH listener - NOW it updates
    expect(mapped.value, 20); // Finally updates on next source change

    source.dispose();
  });

  test('mergeWith() with lazy initialization - value is stale without listener',
      () {
    final notifier1 = ValueNotifier<int>(0);
    final notifier2 = ValueNotifier<int>(100);

    final merged =
        notifier1.mergeWith([notifier2], lazy: true); // Explicit lazy

    expect(merged.value, 0); // Initial value from primary source

    notifier2.value = 200; // Change notifier2 WITHOUT listener
    expect(
      merged.value,
      0,
    ); // STALE! Lazy means no subscription to merged sources

    // Add listener - subscribes but doesn't retroactively update
    merged.addListener(() {});
    expect(
      merged.value,
      0,
    ); // STILL STALE! Lazy init doesn't retroactively update

    notifier2.value = 300; // Change WITH listener - NOW it updates
    expect(merged.value, 300); // Finally updates on next source change

    notifier1.dispose();
    notifier2.dispose();
  });
}
