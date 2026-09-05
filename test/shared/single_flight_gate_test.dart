import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:omm/shared/single_flight_gate.dart';

void main() {
  test('只执行第一个操作，并在完成后允许下一次执行', () async {
    final gate = SingleFlightGate();
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    var runs = 0;

    final first = gate.run(() async {
      runs++;
      firstStarted.complete();
      await releaseFirst.future;
    });
    await firstStarted.future;
    await gate.run(() async => runs++);

    expect(runs, 1);
    releaseFirst.complete();
    await first;
    await gate.run(() async => runs++);
    expect(runs, 2);
  });

  test('操作抛错后会释放闸门', () async {
    final gate = SingleFlightGate();

    await expectLater(
      gate.run(() async => throw StateError('failed')),
      throwsStateError,
    );
    expect(gate.isRunning, isFalse);
  });
}
