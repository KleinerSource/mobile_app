import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omm/features/player/audio/audio_now_playing_view.dart';
import 'package:omm/features/player/common/playback_engine.dart';
import 'package:omm/features/player/common/player_session_controller.dart';

import '../common/fake_playback_engine.dart';

void main() {
  testWidgets('中心区域使用圆形黑胶唱片和圆形封面标签', (tester) async {
    final engine = FakePlaybackEngine(PlaybackEngineKind.audio);
    final controller = PlayerSessionController(engine: engine);
    try {
      await tester.pumpWidget(_app(controller));

      expect(
        find.byKey(const ValueKey<String>('audio-vinyl-record')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('audio-vinyl-surface')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('audio-vinyl-painter')),
        findsOneWidget,
      );
      expect(find.byType(ClipOval), findsNWidgets(2));
      expect(find.byType(ClipRRect), findsNothing);
    } finally {
      await _dispose(tester, controller);
    }
  });

  testWidgets('唱片尺寸固定，播放缓慢启动和暂停缓慢停止', (tester) async {
    final engine = FakePlaybackEngine(
      PlaybackEngineKind.audio,
      initialState: const PlaybackViewState(
        engineKind: PlaybackEngineKind.audio,
        lifecycle: PlaybackLifecycle.ready,
        playing: false,
      ),
    );
    final controller = PlayerSessionController(engine: engine);
    try {
      await tester.pumpWidget(_app(controller));
      final record = find.byKey(const ValueKey<String>('audio-vinyl-record'));
      final recordSize = tester.getSize(record);
      final rotation = tester.widget<RotationTransition>(
        find.byKey(const ValueKey<String>('audio-vinyl-rotation')),
      );

      await controller.play();
      await tester.pump(const Duration(milliseconds: 120));
      final earlyStart = rotation.turns.value;
      await tester.pump(const Duration(milliseconds: 780));
      await tester.pump(const Duration(milliseconds: 16));
      final fullStart = rotation.turns.value;
      expect(fullStart, greaterThan(earlyStart));
      expect(tester.getSize(record), recordSize);

      await controller.pause();
      await tester.pump();
      final earlyStop = rotation.turns.value;
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump(const Duration(milliseconds: 16));
      final lateStop = rotation.turns.value;
      expect(lateStop, greaterThan(earlyStop));
      await tester.pump(const Duration(milliseconds: 600));
      final stopped = rotation.turns.value;
      await tester.pump(const Duration(milliseconds: 300));
      expect(rotation.turns.value, closeTo(stopped, 0.0001));
      expect(tester.getSize(record), recordSize);

      await controller.play();
      await tester.pump();
      final beforeResume = rotation.turns.value;
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 16));
      final afterResume = rotation.turns.value;
      expect(afterResume, greaterThan(beforeResume));
      expect(tester.getSize(record), recordSize);
    } finally {
      await _dispose(tester, controller);
    }
  });

  testWidgets('切歌时只切换中心封面，唱片保持原位置和旋转相位', (tester) async {
    final engine = FakePlaybackEngine(
      PlaybackEngineKind.audio,
      initialState: const PlaybackViewState(
        engineKind: PlaybackEngineKind.audio,
        lifecycle: PlaybackLifecycle.ready,
        playing: true,
      ),
    );
    final controller = PlayerSessionController(engine: engine);
    try {
      await tester.pumpWidget(_app(controller, artworkPath: 'old-cover.jpg'));
      await tester.pump(const Duration(milliseconds: 300));
      final recordSize = tester.getSize(
        find.byKey(const ValueKey<String>('audio-vinyl-record')),
      );
      final rotation = tester.widget<RotationTransition>(
        find.byKey(const ValueKey<String>('audio-vinyl-rotation')),
      );
      final beforeSwitch = rotation.turns.value;

      await tester.pumpWidget(_app(controller, artworkPath: 'new-cover.jpg'));
      await tester.pump(const Duration(milliseconds: 80));

      expect(
        find.byKey(const ValueKey<String>('audio-vinyl-record')),
        findsOneWidget,
      );
      expect(
        tester.getSize(
          find.byKey(const ValueKey<String>('audio-vinyl-record')),
        ),
        recordSize,
      );
      expect(
        find.byKey(const ValueKey<String>('old-cover.jpg')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('new-cover.jpg')),
        findsOneWidget,
      );
      expect(_forwardDelta(beforeSwitch, rotation.turns.value), greaterThan(0));
    } finally {
      await _dispose(tester, controller);
    }
  });

  testWidgets('关闭动效时唱片不旋转但封面切换仍能快速完成', (tester) async {
    final engine = FakePlaybackEngine(
      PlaybackEngineKind.audio,
      initialState: const PlaybackViewState(
        engineKind: PlaybackEngineKind.audio,
        lifecycle: PlaybackLifecycle.ready,
        playing: true,
      ),
    );
    final controller = PlayerSessionController(engine: engine);
    try {
      await tester.pumpWidget(
        _app(controller, artworkPath: 'old-cover.jpg', disableAnimations: true),
      );
      final rotation = tester.widget<RotationTransition>(
        find.byKey(const ValueKey<String>('audio-vinyl-rotation')),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(rotation.turns.value, closeTo(0, 0.0001));

      await tester.pumpWidget(
        _app(controller, artworkPath: 'new-cover.jpg', disableAnimations: true),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byKey(const ValueKey<String>('new-cover.jpg')),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey<String>('old-cover.jpg')), findsNothing);
    } finally {
      await _dispose(tester, controller);
    }
  });
}

Widget _app(
  PlayerSessionController controller, {
  String? artworkPath,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(
          size: const Size(800, 600),
          disableAnimations: disableAnimations,
        ),
        child: AudioNowPlayingView(
          controller: controller,
          artworkPath: artworkPath,
          lyrics: null,
        ),
      ),
    ),
  );
}

double _forwardDelta(double from, double to) => (to - from) % 1.0;

Future<void> _dispose(
  WidgetTester tester,
  PlayerSessionController controller,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await controller.dispose();
}
