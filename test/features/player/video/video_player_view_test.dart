import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/player/common/playback_engine.dart';
import 'package:omm/features/player/video/video_player_view.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

void main() {
  test('仅在视频流缺失时显示 buffering 遮罩', () {
    expect(
      const PlaybackViewState(
        engineKind: PlaybackEngineKind.libmpv,
        buffering: true,
      ).shouldShowVideoBuffering,
      isTrue,
    );
    expect(
      const PlaybackViewState(
        engineKind: PlaybackEngineKind.libmpv,
        buffering: true,
        firstFrameRendered: true,
        position: Duration(seconds: 30),
        buffered: Duration(seconds: 60),
      ).shouldShowVideoBuffering,
      isFalse,
    );
    expect(
      const PlaybackViewState(
        engineKind: PlaybackEngineKind.libmpv,
        buffering: true,
        firstFrameRendered: true,
        position: Duration(seconds: 90),
        buffered: Duration(seconds: 60),
      ).shouldShowVideoBuffering,
      isTrue,
    );
    expect(
      const PlaybackViewState(
        engineKind: PlaybackEngineKind.libmpv,
        firstFrameRendered: true,
        position: Duration(seconds: 90),
        buffered: Duration(seconds: 60),
      ).shouldShowVideoBuffering,
      isFalse,
    );
  });

  test('KSPlayer 首帧后 buffering 交给 UI 防抖', () {
    expect(
      const PlaybackViewState(
        engineKind: PlaybackEngineKind.ksPlayer,
        playing: true,
        buffering: true,
        firstFrameRendered: true,
        position: Duration(seconds: 30),
      ).shouldShowVideoBuffering,
      isTrue,
    );
  });

  testWidgets('首帧前的零延迟 buffering 立即显示', (tester) async {
    final buffering = ValueNotifier(true);

    await tester.pumpWidget(
      _bufferingOverlayHarness(buffering, showDelay: Duration.zero),
    );

    expect(find.text('正在缓冲…'), findsOneWidget);
    buffering.dispose();
  });

  testWidgets('KSPlayer 首帧后的短 buffering 不显示', (tester) async {
    final buffering = ValueNotifier(false);

    await tester.pumpWidget(
      _bufferingOverlayHarness(
        buffering,
        showDelay: VideoPlayerView.ksPlayerBufferingDelay,
      ),
    );
    buffering.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 349));

    expect(find.text('正在缓冲…'), findsNothing);

    buffering.value = false;
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('正在缓冲…'), findsNothing);
    buffering.dispose();
  });

  testWidgets('KSPlayer 持续 buffering 延迟显示并在恢复时立即隐藏', (tester) async {
    final buffering = ValueNotifier(false);

    await tester.pumpWidget(
      _bufferingOverlayHarness(
        buffering,
        showDelay: VideoPlayerView.ksPlayerBufferingDelay,
      ),
    );
    buffering.value = true;
    await tester.pump();
    await tester.pump(VideoPlayerView.ksPlayerBufferingDelay);

    expect(find.text('正在缓冲…'), findsOneWidget);

    buffering.value = false;
    await tester.pump();

    expect(find.text('正在缓冲…'), findsNothing);
    buffering.dispose();
  });

  testWidgets('buffering 延迟到期前销毁不会触发异常', (tester) async {
    final buffering = ValueNotifier(true);

    await tester.pumpWidget(
      _bufferingOverlayHarness(
        buffering,
        showDelay: VideoPlayerView.ksPlayerBufferingDelay,
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(VideoPlayerView.ksPlayerBufferingDelay);

    expect(tester.takeException(), isNull);
    buffering.dispose();
  });

  testWidgets('视频缓冲时显示提示并且不拦截播放器手势', (tester) async {
    final buffering = ValueNotifier(true);
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: buffering,
            builder: (_, isBuffering, __) => Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => tapped = true,
                  child: const SizedBox.expand(),
                ),
                if (isBuffering)
                  const Positioned.fill(child: VideoPlayerBufferingView()),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('正在缓冲…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    expect(tapped, isTrue);

    buffering.value = false;
    await tester.pump();

    expect(find.text('正在缓冲…'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    buffering.dispose();
  });
}

Widget _bufferingOverlayHarness(
  ValueNotifier<bool> buffering, {
  required Duration showDelay,
}) {
  return MaterialApp(
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    locale: const Locale('zh'),
    home: Scaffold(
      body: ValueListenableBuilder<bool>(
        valueListenable: buffering,
        builder: (_, isBuffering, __) => VideoPlayerBufferingOverlay(
          isBuffering: isBuffering,
          showDelay: showDelay,
        ),
      ),
    ),
  );
}
