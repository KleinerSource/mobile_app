import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omm/features/player/audio/audio_now_playing_view.dart';
import 'package:omm/features/player/audio/lrc_parser.dart';
import 'package:omm/features/player/common/playback_engine.dart';
import 'package:omm/features/player/common/player_session_controller.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

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

  testWidgets('点按唱片切换播放状态', (tester) async {
    final engine = FakePlaybackEngine(
      PlaybackEngineKind.audio,
      initialState: const PlaybackViewState(
        engineKind: PlaybackEngineKind.audio,
        lifecycle: PlaybackLifecycle.ready,
        playing: true,
        duration: Duration(minutes: 2),
      ),
    );
    final controller = PlayerSessionController(engine: engine);
    try {
      await tester.pumpWidget(_app(controller));
      final record = find.byKey(const ValueKey<String>('audio-vinyl-record'));

      await tester.tap(record);
      await tester.pump();
      expect(engine.commands, contains('pause'));

      await tester.tap(record);
      await tester.pump();
      expect(engine.commands, contains('play'));
    } finally {
      await _dispose(tester, controller);
    }
  });

  testWidgets('顺逆时针旋拧唱片定位并恢复拖动前的播放状态', (tester) async {
    final engine = FakePlaybackEngine(
      PlaybackEngineKind.audio,
      initialState: const PlaybackViewState(
        engineKind: PlaybackEngineKind.audio,
        lifecycle: PlaybackLifecycle.ready,
        playing: true,
        position: Duration(seconds: 30),
        duration: Duration(minutes: 1),
      ),
    );
    final controller = PlayerSessionController(engine: engine);
    try {
      await tester.pumpWidget(_app(controller));
      final record = find.byKey(const ValueKey<String>('audio-vinyl-record'));
      final center = tester.getCenter(record);

      final clockwise = await tester.startGesture(
        center + const Offset(0, -120),
      );
      await clockwise.moveTo(center + const Offset(120, 0));
      await clockwise.up();
      await tester.pump();

      expect(engine.commands, isNot(contains('pause')));
      expect(engine.commands, contains('seek'));
      expect(engine.commands, contains('play'));
      expect(
        engine.seekPositions.last,
        greaterThan(const Duration(seconds: 30)),
      );

      final seekCount = engine.seekPositions.length;
      final counterClockwise = await tester.startGesture(
        center + const Offset(120, 0),
      );
      await counterClockwise.moveTo(center + const Offset(0, -120));
      await counterClockwise.up();
      await tester.pump();

      expect(engine.seekPositions.length, greaterThan(seekCount));
      expect(
        engine.commands.where((command) => command == 'play').length,
        greaterThan(1),
      );
      expect(
        engine.seekPositions.last,
        lessThan(engine.seekPositions[seekCount - 1]),
      );
      expect(engine.commands.last, 'play');
    } finally {
      await _dispose(tester, controller);
    }
  });

  testWidgets('甩碟释放后唱片不额外惯性旋转，恢复后跟随主音轨', (tester) async {
    final engine = FakePlaybackEngine(
      PlaybackEngineKind.audio,
      seekDelay: const Duration(milliseconds: 300),
      initialState: const PlaybackViewState(
        engineKind: PlaybackEngineKind.audio,
        lifecycle: PlaybackLifecycle.ready,
        playing: true,
        position: Duration(seconds: 30),
        duration: Duration(minutes: 1),
      ),
    );
    final controller = PlayerSessionController(engine: engine);
    try {
      await tester.pumpWidget(_app(controller));
      final record = find.byKey(const ValueKey<String>('audio-vinyl-record'));
      final rotation = tester.widget<RotationTransition>(
        find.byKey(const ValueKey<String>('audio-vinyl-rotation')),
      );
      final center = tester.getCenter(record);
      final gesture = await tester.startGesture(center + const Offset(0, -120));
      await gesture.moveTo(
        center + const Offset(120, 0),
        timeStamp: const Duration(milliseconds: 80),
      );
      await gesture.up();
      await tester.pump();
      final afterRelease = rotation.turns.value;

      await tester.pump(const Duration(milliseconds: 100));

      expect(rotation.turns.value, closeTo(afterRelease, 0.0001));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 16));
      expect(rotation.turns.value, greaterThan(afterRelease));
    } finally {
      await _dispose(tester, controller);
    }
  });

  testWidgets('搓碟恢复播放不等待后台 play Future 完成', (tester) async {
    final playCompletion = Completer<void>();
    final engine = FakePlaybackEngine(
      PlaybackEngineKind.audio,
      playCompletion: playCompletion.future,
      initialState: const PlaybackViewState(
        engineKind: PlaybackEngineKind.audio,
        lifecycle: PlaybackLifecycle.ready,
        playing: true,
        position: Duration(seconds: 30),
        duration: Duration(minutes: 1),
      ),
    );
    final controller = PlayerSessionController(engine: engine);
    try {
      await tester.pumpWidget(_app(controller));
      final record = find.byKey(const ValueKey<String>('audio-vinyl-record'));
      final rotation = tester.widget<RotationTransition>(
        find.byKey(const ValueKey<String>('audio-vinyl-rotation')),
      );
      final center = tester.getCenter(record);
      final gesture = await tester.startGesture(center + const Offset(0, -120));
      await gesture.moveTo(center + const Offset(120, 0));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      final afterMomentum = rotation.turns.value;
      await tester.pump(const Duration(milliseconds: 300));

      expect(engine.commands, contains('play'));
      expect(rotation.turns.value, greaterThan(afterMomentum));
      playCompletion.complete();
      await tester.pump();
    } finally {
      if (!playCompletion.isCompleted) playCompletion.complete();
      await _dispose(tester, controller);
    }
  });

  testWidgets('唱片正常旋转速度跟随实际播放倍速', (tester) async {
    final engine = FakePlaybackEngine(
      PlaybackEngineKind.audio,
      initialState: const PlaybackViewState(
        engineKind: PlaybackEngineKind.audio,
        lifecycle: PlaybackLifecycle.ready,
        playing: true,
        rate: 1,
      ),
    );
    final controller = PlayerSessionController(engine: engine);
    try {
      await tester.pumpWidget(_app(controller));
      final rotation = tester.widget<RotationTransition>(
        find.byKey(const ValueKey<String>('audio-vinyl-rotation')),
      );
      await tester.pump(const Duration(seconds: 2));
      final oneXStart = rotation.turns.value;
      await tester.pump(const Duration(milliseconds: 400));
      final oneXDelta = rotation.turns.value - oneXStart;

      await controller.setRate(2);
      await tester.pump();
      final twoXStart = rotation.turns.value;
      await tester.pump(const Duration(milliseconds: 400));
      final twoXDelta = rotation.turns.value - twoXStart;

      expect(twoXDelta, closeTo(oneXDelta * 2, 0.01));
    } finally {
      await _dispose(tester, controller);
    }
  });

  testWidgets('旋拧 seek 会合并快速更新并限制在歌曲边界内', (tester) async {
    final engine = FakePlaybackEngine(
      PlaybackEngineKind.audio,
      seekDelay: const Duration(milliseconds: 80),
      initialState: const PlaybackViewState(
        engineKind: PlaybackEngineKind.audio,
        lifecycle: PlaybackLifecycle.ready,
        position: Duration(seconds: 59),
        duration: Duration(minutes: 1),
      ),
    );
    final controller = PlayerSessionController(engine: engine);
    try {
      await tester.pumpWidget(_app(controller));
      final record = find.byKey(const ValueKey<String>('audio-vinyl-record'));
      final center = tester.getCenter(record);
      final gesture = await tester.startGesture(center + const Offset(0, -120));
      await gesture.moveTo(center + const Offset(120, 0));
      await gesture.moveTo(center + const Offset(0, 120));
      await gesture.moveTo(center + const Offset(-120, 0));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 240));

      expect(engine.seekPositions, hasLength(1));
      expect(engine.seekPositions.single, const Duration(minutes: 1));
    } finally {
      await _dispose(tester, controller);
    }
  });

  testWidgets('暂停状态旋拧后保持暂停，加载或无时长时不发送唱片命令', (tester) async {
    final pausedEngine = FakePlaybackEngine(
      PlaybackEngineKind.audio,
      initialState: const PlaybackViewState(
        engineKind: PlaybackEngineKind.audio,
        lifecycle: PlaybackLifecycle.ready,
        position: Duration(seconds: 30),
        duration: Duration(minutes: 1),
      ),
    );
    final pausedController = PlayerSessionController(engine: pausedEngine);
    try {
      await tester.pumpWidget(_app(pausedController));
      final record = find.byKey(const ValueKey<String>('audio-vinyl-record'));
      final center = tester.getCenter(record);
      final gesture = await tester.startGesture(center + const Offset(0, -120));
      await gesture.moveTo(center + const Offset(120, 0));
      await gesture.up();
      await tester.pump();

      expect(pausedEngine.commands, contains('play'));
      expect(pausedEngine.commands, contains('pause'));
      expect(pausedEngine.commands, contains('seek'));
    } finally {
      await _dispose(tester, pausedController);
    }

    final loadingEngine = FakePlaybackEngine(
      PlaybackEngineKind.audio,
      initialState: const PlaybackViewState(
        engineKind: PlaybackEngineKind.audio,
        lifecycle: PlaybackLifecycle.opening,
      ),
    );
    final loadingController = PlayerSessionController(engine: loadingEngine);
    try {
      await tester.pumpWidget(_app(loadingController));
      final record = find.byKey(const ValueKey<String>('audio-vinyl-record'));
      await tester.tap(record);
      final center = tester.getCenter(record);
      final gesture = await tester.startGesture(center + const Offset(0, -120));
      await gesture.moveTo(center + const Offset(120, 0));
      await gesture.up();
      await tester.pump();

      expect(loadingEngine.commands, isEmpty);
    } finally {
      await _dispose(tester, loadingController);
    }

    final unknownDurationEngine = FakePlaybackEngine(
      PlaybackEngineKind.audio,
      initialState: const PlaybackViewState(
        engineKind: PlaybackEngineKind.audio,
        lifecycle: PlaybackLifecycle.ready,
      ),
    );
    final unknownDurationController = PlayerSessionController(
      engine: unknownDurationEngine,
    );
    try {
      await tester.pumpWidget(_app(unknownDurationController));
      final record = find.byKey(const ValueKey<String>('audio-vinyl-record'));
      await tester.tap(record);
      final center = tester.getCenter(record);
      final gesture = await tester.startGesture(center + const Offset(0, -120));
      await gesture.moveTo(center + const Offset(120, 0));
      await gesture.up();
      await tester.pump();

      expect(unknownDurationEngine.commands, isEmpty);
    } finally {
      await _dispose(tester, unknownDurationController);
    }
  });

  testWidgets('取消唱片手势不发送控制命令', (tester) async {
    final engine = FakePlaybackEngine(
      PlaybackEngineKind.audio,
      initialState: const PlaybackViewState(
        engineKind: PlaybackEngineKind.audio,
        lifecycle: PlaybackLifecycle.ready,
        duration: Duration(minutes: 1),
      ),
    );
    final controller = PlayerSessionController(engine: engine);
    try {
      await tester.pumpWidget(_app(controller));
      final record = find.byKey(const ValueKey<String>('audio-vinyl-record'));
      final center = tester.getCenter(record);
      final gesture = await tester.startGesture(center + const Offset(0, -120));
      await gesture.cancel();
      await tester.pump();

      expect(engine.commands, isEmpty);
    } finally {
      await _dispose(tester, controller);
    }
  });

  testWidgets('唱片提供 DJ 操作的无障碍语义', (tester) async {
    final engine = FakePlaybackEngine(
      PlaybackEngineKind.audio,
      initialState: const PlaybackViewState(
        engineKind: PlaybackEngineKind.audio,
        lifecycle: PlaybackLifecycle.ready,
        duration: Duration(minutes: 1),
      ),
    );
    final controller = PlayerSessionController(engine: engine);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_app(controller));
      final node = tester.getSemantics(
        find.byKey(const ValueKey<String>('audio-dj-record-semantics')),
      );

      expect(node.label, 'DJ 唱盘');
      expect(node.hint, '点按播放或暂停，旋拧唱片定位');
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    } finally {
      semantics.dispose();
      await _dispose(tester, controller);
    }
  });

  testWidgets('唱片尺寸固定，播放状态和倍速直接同步', (tester) async {
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
      await tester.pump(const Duration(milliseconds: 16));
      final start = rotation.turns.value;
      await tester.pump(const Duration(milliseconds: 400));
      expect(rotation.turns.value, greaterThan(start));
      expect(tester.getSize(record), recordSize);

      await controller.pause();
      await tester.pump();
      final paused = rotation.turns.value;
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump(const Duration(milliseconds: 16));
      expect(rotation.turns.value, closeTo(paused, 0.0001));
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

  testWidgets('歌词槽位状态切换不会移动唱片', (tester) async {
    final engine = FakePlaybackEngine(
      PlaybackEngineKind.audio,
      initialState: const PlaybackViewState(
        engineKind: PlaybackEngineKind.audio,
        lifecycle: PlaybackLifecycle.ready,
        duration: Duration(minutes: 2),
      ),
    );
    final controller = PlayerSessionController(engine: engine);
    try {
      await tester.pumpWidget(_app(controller));
      final record = find.byKey(const ValueKey<String>('audio-vinyl-record'));
      final withoutLyrics = tester.getCenter(record);

      await tester.pumpWidget(_app(controller, withLyrics: true));
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.getCenter(record), withoutLyrics);
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
  bool withLyrics = false,
}) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(
          size: const Size(800, 600),
          disableAnimations: disableAnimations,
        ),
        child: AudioNowPlayingView(
          controller: controller,
          artworkPath: artworkPath,
          lyrics: withLyrics
              ? const LrcDocument(
                  cues: [LrcCue(position: Duration.zero, text: '当前歌词')],
                )
              : null,
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
