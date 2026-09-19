// ignore_for_file: invalid_use_of_protected_member
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listen_it/listen_it.dart';

void main() {
  test('eager chain that never gets a listener detaches on first source change',
      () {
    final source = ValueNotifier<int>(1);
    var calls = 0;
    final mapped = source.map((v) {
      calls++;
      return v * 2;
    });
    expect(source.hasListeners, true, reason: 'eager: attached on creation');

    source.value = 2;
    expect(
      source.hasListeners,
      false,
      reason: 'no listener on the chain -> detached after first notification',
    );
    expect(mapped.value, 4, reason: 'derive-on-read keeps value correct');

    calls = 0;
    source.value = 3;
    expect(calls, 0, reason: 'detached chain does no work on source change');
    expect(mapped.value, 6);
    expect(calls, 1, reason: 'transform runs on read while detached');
  });
}
