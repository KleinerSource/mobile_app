import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omm/features/player/playback_engine.dart';
import 'package:omm/features/player/player_debug_overlay.dart';

void main() {
  test('媒体调试信息可以从 KSPlayer 原生事件解析', () {
    const json =
        '{"internal_player":"KSMEPlayer","video_codec":"hevc",'
        '"video_bitrate":8240000,"video_fps":23.976,'
        '"audio_codec":"aac"}';

    final info = PlaybackMediaInfo.fromJsonString(json);

    expect(info?.internalPlayer, 'KSMEPlayer');
    expect(info?.videoCodec, 'hevc');
    expect(info?.videoBitrate, 8240000);
    expect(info?.videoFps, 23.976);
    expect(info?.audioCodec, 'aac');
  });

  test('播放请求可以从容器提示和地址识别 KSPlayer 内部播放器', () {
    expect(
      PlaybackMediaInfo.inferInternalPlayer(
        'https://example.com/video.mkv?token=1',
        null,
      ),
      'KSMEPlayer',
    );
    expect(
      PlaybackMediaInfo.inferInternalPlayer(
        'https://example.com/stream',
        'video/mp4',
      ),
      'AVPlayer',
    );
    expect(
      PlaybackMediaInfo.inferInternalPlayer(
        'https://example.com/video.mp4',
        'mp4',
        videoCodec: 'hevc',
      ),
      'KSMEPlayer',
    );
    expect(
      PlaybackMediaInfo.inferInternalPlayer(
        'http://127.0.0.1:56386/proxy.mp4',
        null,
      ),
      'KSMEPlayer',
    );
    expect(
      PlaybackMediaInfo.inferInternalPlayer(
        'https://example.com/stream.m3u8',
        'matroska',
      ),
      'AVPlayer',
      reason: '网络 HLS 默认交给 AVPlayer，容器提示不再干预',
    );
    expect(
      PlaybackMediaInfo.inferInternalPlayer(
        'https://example.com/live/index.m3u8?token=1',
        null,
        videoCodec: 'h264',
      ),
      'AVPlayer',
      reason: 'OMM/DBO 的网络 HLS 默认 AVPlayer',
    );
    expect(
      PlaybackMediaInfo.inferInternalPlayer(
        'https://example.com/v/play',
        'hls',
      ),
      'AVPlayer',
      reason: 'hls 容器提示按网络 HLS 处理',
    );
    expect(
      PlaybackMediaInfo.inferInternalPlayer(
        'https://example.com/live/index.m3u8?token=1',
        null,
        videoCodec: 'h264',
        preferFfmpegForHls: true,
      ),
      'KSMEPlayer',
      reason: '文件源显式要求 FFmpeg 播放 HLS',
    );
    expect(
      PlaybackMediaInfo.inferInternalPlayer(
        'http://127.0.0.1:56386/token.m3u8',
        null,
      ),
      'KSMEPlayer',
      reason: '回环代理上的 m3u8 始终是 KSMEPlayer',
    );
  });

  test('码率格式化为用户可读单位', () {
    expect(formatPlaybackBitrate(null), '--');
    expect(formatPlaybackBitrate(512000), '512 kbps');
    expect(formatPlaybackBitrate(8240000), '8.24 Mbps');
  });

  testWidgets('Debug OSD 只展示统一播放状态中的信息', (tester) async {
    final state = ValueNotifier(
      const PlaybackViewState(
        engineKind: PlaybackEngineKind.ksPlayer,
        videoSize: Size(1920, 1080),
        mediaInfo: PlaybackMediaInfo(
          container: 'matroska',
          videoCodec: 'hevc',
          videoBitrate: 8240000,
          videoFps: 23.976,
          internalPlayer: 'KSMEPlayer',
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlayerDebugOverlay(stateListenable: state)),
      ),
    );

    expect(find.text('内核 KSPlayer'), findsOneWidget);
    expect(find.text('内部 KSMEPlayer'), findsOneWidget);
    expect(find.text('视频 hevc'), findsOneWidget);
    expect(find.text('视频码率 8.24 Mbps'), findsOneWidget);
    expect(find.text('帧率 23.98 fps'), findsOneWidget);
    expect(find.text('分辨率 1920×1080'), findsOneWidget);
  });
}
