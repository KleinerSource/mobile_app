import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/models/playback.dart';
import 'package:omm/features/player/common/engine_playback_route.dart';
import 'package:omm/features/player/common/playback_engine.dart';
import 'package:omm/features/player/common/player_session_controller.dart';
import 'package:omm/core/platform/app_version.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'fake_playback_engine.dart';

PlaybackDecision resolvedStrm({bool hls = false}) => PlaybackDecision.fromJson({
  'mode': 'direct_play',
  'direct_url': 'https://cdn.example/video.${hls ? 'm3u8' : 'mp4'}?sign=abc',
  'stream_url': 'https://cdn.example/video.${hls ? 'm3u8' : 'mp4'}?sign=abc',
  'strm_user_agent': 'omm/android',
  'quality_options': const [
    {'id': 'auto', 'label': '自动', 'kind': 'auto'},
    {'id': 'original', 'label': '原画', 'kind': 'original'},
  ],
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PackageInfo.setMockInitialValues(
    appName: 'Oh My Media',
    packageName: 'com.ohmymedia.omm',
    version: '0.92.10',
    buildNumber: '745',
    buildSignature: '',
  );
  resetAppVersionCache();

  for (final quality in ['auto', 'original']) {
    for (final hls in [false, true]) {
      test('$quality 档 STRM（HLS=$hls）使用客户端直连，不创建服务器会话', () {
        final decision = resolvedStrm(hls: hls);
        final route = playbackRouteForQuality(
          quality: quality,
          decision: decision,
          forceServerRoute: true,
        );
        expect(route.useBackendStream, isFalse);
        expect(route.useServerRoute, isFalse);
        expect(route.usesManagedTranscode, isFalse);
        expect(
          serverFallbackPlanFor(
            quality: quality,
            alreadyAttempted: false,
            usingHls: false,
            decision: decision,
          ),
          isNull,
        );
      });
    }
  }

  for (final kind in [PlaybackEngineKind.libmpv, PlaybackEngineKind.ksPlayer]) {
    test('$kind 无显式覆盖时使用统一版本 UA', () async {
      final engine = FakePlaybackEngine(kind);
      final session = PlayerSessionController(engine: engine);
      try {
        await session.open('https://cdn.example/video.mp4');
        expect(engine.lastOpenRequest?.headers, {'User-Agent': 'omm/0.92.10'});
        await session.captureFrame(
          const Duration(seconds: 5),
          sourceUrl: 'https://cdn.example/preview.mp4',
        );
        expect(engine.lastCaptureHeaders, {'User-Agent': 'omm/0.92.10'});
      } finally {
        await session.dispose();
      }
    });

    test('$kind 打开、定位和重开均保留 STRM URL 和 UA', () async {
      final engine = FakePlaybackEngine(kind);
      final session = PlayerSessionController(engine: engine);
      final decision = resolvedStrm();
      try {
        await session.open(decision.directUrl, headers: decision.strmHeaders);
        expect(engine.lastOpenRequest?.url, decision.directUrl);
        expect(engine.lastOpenRequest?.headers, {'User-Agent': 'omm/0.92.10'});
        await session.seek(const Duration(seconds: 42));
        expect(engine.lastOpenRequest?.headers, {'User-Agent': 'omm/0.92.10'});
        await session.stop();
        await session.configure(hardwareAcceleration: false);
        await session.open(
          decision.directUrl,
          headers: decision.strmHeaders,
          startAt: const Duration(seconds: 42),
        );
        expect(engine.openCount, 2);
        expect(engine.lastOpenRequest?.url, decision.directUrl);
        expect(engine.lastOpenRequest?.headers, {'User-Agent': 'omm/0.92.10'});
        expect(engine.lastOpenRequest?.startAt, const Duration(seconds: 42));
      } finally {
        await session.dispose();
      }
    });
  }
}
