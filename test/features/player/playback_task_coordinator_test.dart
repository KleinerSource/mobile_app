import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/player/common/player_launch_gate.dart';

void main() {
  group('PlaybackTaskCoordinator', () {
    test('stopAll invokes every registered callback once', () async {
      final coordinator = PlaybackTaskCoordinator();
      var firstCalls = 0;
      var secondCalls = 0;

      coordinator.register(() async {
        firstCalls++;
      });
      coordinator.register(() async {
        secondCalls++;
      });

      await coordinator.stopAll();

      expect(firstCalls, 1);
      expect(secondCalls, 1);
    });

    test('unregistered callbacks are not invoked', () async {
      final coordinator = PlaybackTaskCoordinator();
      var removedCalls = 0;
      var retainedCalls = 0;
      final unregister = coordinator.register(() async {
        removedCalls++;
      });
      coordinator.register(() async {
        retainedCalls++;
      });

      unregister();
      await coordinator.stopAll();

      expect(removedCalls, 0);
      expect(retainedCalls, 1);
    });

    test('each stopAll call invokes registered callbacks once', () async {
      final coordinator = PlaybackTaskCoordinator();
      var calls = 0;
      coordinator.register(() async {
        calls++;
      });

      await coordinator.stopAll();
      await coordinator.stopAll();

      expect(calls, 2);
    });

    test('stopAll waits for registered cleanup to finish', () async {
      final coordinator = PlaybackTaskCoordinator();
      final cleanup = Completer<void>();
      var completed = false;
      coordinator.register(() => cleanup.future);

      final stopping = coordinator.stopAll().then((_) => completed = true);
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);

      cleanup.complete();
      await stopping;
      expect(completed, isTrue);
    });

    test('concurrent stopAll calls share the same cleanup', () async {
      final coordinator = PlaybackTaskCoordinator();
      final cleanup = Completer<void>();
      var calls = 0;
      coordinator.register(() {
        calls++;
        return cleanup.future;
      });

      final first = coordinator.stopAll();
      final second = coordinator.stopAll();
      expect(calls, 1);

      cleanup.complete();
      await Future.wait([first, second]);
      expect(calls, 1);
    });
  });
}
