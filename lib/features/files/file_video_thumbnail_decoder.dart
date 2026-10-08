import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/sources/files/file_entry.dart';

Duration? fileVideoThumbnailPosition(Duration duration) =>
    duration > Duration.zero
    ? Duration(microseconds: (duration.inMicroseconds * 0.1).round())
    : null;

bool isVideoThumbnailFrameReady({
  required Duration target,
  required double? frameSeconds,
  required bool seeking,
}) =>
    !seeking &&
    frameSeconds != null &&
    frameSeconds.isFinite &&
    frameSeconds >= target.inMicroseconds / 1000000 - 0.001 &&
    frameSeconds <= target.inMicroseconds / 1000000 + 1;

/// 生命周期接口用于验证定位、取消与释放；生产实现始终使用独立 libmpv。
abstract interface class FileVideoFrameSession {
  Future<void> open(Uri uri);
  Future<Duration> duration();
  Future<bool> hasVideo();
  Future<void> seek(Duration position);
  Future<bool> frameReady(Duration position);
  Future<Uint8List?> screenshot();
  Future<void> dispose();
}

Future<Uint8List?> decodeFileVideoThumbnail(
  Uri uri,
  FileCancellationToken cancellation, {
  FileVideoFrameSession Function()? createSession,
}) async {
  if (cancellation.isCancelled) return null;
  final session = (createSession ?? _MediaKitFrameSession.new)();
  Future<T> cancellable<T>(Future<T> operation) => Future.any([
    operation,
    cancellation.whenCancelled.then<T>((_) => throw const _Cancelled()),
  ]);
  Future<void> poll() =>
      cancellable(Future<void>.delayed(const Duration(milliseconds: 40)));
  try {
    await cancellable(session.open(uri));
    Duration? target;
    while (target == null) {
      target = fileVideoThumbnailPosition(
        await cancellable(session.duration()),
      );
      if (target == null) await poll();
    }
    if (!await cancellable(session.hasVideo())) return null;
    await cancellable(session.seek(target));
    while (!await cancellable(session.frameReady(target))) {
      await poll();
    }
    final bytes = await cancellable(session.screenshot());
    if (bytes == null || bytes.isEmpty) return null;
    return await cancellable(compute(encodeFileVideoThumbnail, bytes));
  } on _Cancelled {
    return null;
  } finally {
    // 不对 dispose 做脱离队列的超时：上一解码器释放后才能启动下一任务。
    await session.dispose();
  }
}

Uint8List? encodeFileVideoThumbnail(Uint8List bytes) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    return null;
  }
  if (decoded == null) return null;
  final upright = img.bakeOrientation(decoded);
  final longest = upright.width > upright.height
      ? upright.width
      : upright.height;
  final image = longest <= 320
      ? upright
      : img.copyResize(
          upright,
          width: (upright.width * 320 / longest).round().clamp(1, 320),
          height: (upright.height * 320 / longest).round().clamp(1, 320),
          interpolation: img.Interpolation.average,
        );
  return img.encodeJpg(image, quality: 80);
}

class _Cancelled implements Exception {
  const _Cancelled();
}

class _MediaKitFrameSession implements FileVideoFrameSession {
  final _player = Player(
    configuration: const PlayerConfiguration(
      muted: true,
      bufferSize: 8 * 1024 * 1024,
    ),
  );
  NativePlayer get _native => _player.platform! as NativePlayer;

  @override
  Future<void> open(Uri uri) async {
    final controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        hwdec: 'no',
        enableHardwareAcceleration: false,
      ),
    );
    WidgetsBinding.instance.scheduleFrame();
    await controller.platform.future;
    for (final entry in const {
      'aid': 'no',
      'ao': 'null',
      'sid': 'no',
      'sub-auto': 'no',
      'audio-file-auto': 'no',
      'cache': 'no',
      'cache-on-disk': 'no',
      'demuxer-readahead-secs': '0',
      'demuxer-max-back-bytes': '0',
      // 播放列表分片可能绕过代理的流量上限；只探测独立视频容器。
      'demuxer-lavf-o':
          'format_whitelist=[mov,matroska,webm,avi,asf,flv,live_flv,mpeg,mpegts,ogg,rm,h264,hevc,m4v],protocol_whitelist=[http,tcp]',
    }.entries) {
      await _native.setProperty(entry.key, entry.value);
    }
    await _player.open(Media(uri.toString()), play: false);
  }

  @override
  Future<Duration> duration() async => _player.state.duration;

  @override
  Future<bool> hasVideo() async {
    // 元数据事件的到达次序不同，不能用可能还没更新的 Dart tracks 快照。
    final count =
        int.tryParse(await _native.getProperty('track-list/count')) ?? 0;
    for (var index = 0; index < count; index++) {
      if (await _native.getProperty('track-list/$index/type') == 'video' &&
          await _native.getProperty('track-list/$index/albumart') != 'yes') {
        return true;
      }
    }
    return false;
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<bool> frameReady(Duration position) async =>
      isVideoThumbnailFrameReady(
        target: position,
        // aid=no 且保持暂停，time-pos 在 seeking 结束后对应当前视频画面。
        frameSeconds: double.tryParse(await _native.getProperty('time-pos')),
        seeking: await _native.getProperty('seeking') == 'yes',
      );

  @override
  Future<Uint8List?> screenshot() => _player.screenshot(format: 'image/jpeg');

  @override
  Future<void> dispose() => _player.dispose();
}
