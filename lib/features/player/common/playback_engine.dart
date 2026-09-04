import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'player_queue.dart';

enum PlaybackEngineKind {
  libmpv('libmpv', 'libmpv'),
  ksPlayer('ksplayer', 'KSPlayer'),
  audio('audio', 'Audio');

  const PlaybackEngineKind(this.value, this.label);

  final String value;
  final String label;
}

/// 开发接口可手动指定的播放器组合。
///
/// KSPlayer 的两个内部播放器仍复用同一个 Dart 播放引擎，HLS 播放时通过
/// [preferFfmpegForHls] 选择 KSMEPlayer 或 AVPlayer。
enum PlaybackEngineSelection {
  libmpv('libmpv', PlaybackEngineKind.libmpv, false),
  ksmePlayer('ksplayer(ksmeplayer)', PlaybackEngineKind.ksPlayer, true),
  avPlayer('ksplayer(avplayer)', PlaybackEngineKind.ksPlayer, false);

  const PlaybackEngineSelection(
    this.label,
    this.engineKind,
    this.preferFfmpegForHls,
  );

  final String label;
  final PlaybackEngineKind engineKind;
  final bool preferFfmpegForHls;
}

abstract final class PlayerEnginePreference {
  static const storageKey = 'player.ios_engine';

  static PlaybackEngineKind fromValue(String? value) {
    return PlaybackEngineKind.values.firstWhere(
      (item) => item.value == value?.trim().toLowerCase(),
      orElse: () => PlaybackEngineKind.libmpv,
    );
  }
}

enum PlaybackLifecycle { idle, opening, ready, completed, stopped, failed }

enum PlaybackRepeatMode { off, one, all }

@immutable
class PlaybackEngineCapabilities {
  const PlaybackEngineCapabilities({
    required this.pictureInPicture,
    required this.framePreview,
    required this.audioTracks,
    required this.textSubtitles,
    required this.bitmapSubtitles,
    required this.customBuffering,
    this.playbackRate = true,
  });

  const PlaybackEngineCapabilities.libmpv()
    : pictureInPicture = false,
      framePreview = true,
      audioTracks = true,
      textSubtitles = true,
      bitmapSubtitles = true,
      customBuffering = true,
      playbackRate = true;

  const PlaybackEngineCapabilities.ksPlayer({this.framePreview = true})
    : pictureInPicture = true,
      audioTracks = true,
      textSubtitles = true,
      bitmapSubtitles = false,
      customBuffering = false,
      playbackRate = true;

  final bool pictureInPicture;
  final bool framePreview;
  final bool audioTracks;
  final bool textSubtitles;
  final bool bitmapSubtitles;
  final bool customBuffering;
  final bool playbackRate;
}

/// 播放中的媒体调试信息。
///
/// 字段可能来自后端探测、libmpv 实际轨道或 KSPlayer 原生轨道；缺失时
/// 保持为 null，Debug OSD 显示 `--`，不影响正常播放。
@immutable
class PlaybackMediaInfo {
  const PlaybackMediaInfo({
    this.container,
    this.videoCodec,
    this.videoBitrate,
    this.videoFps,
    this.videoDecoder,
    this.audioCodec,
    this.audioBitrate,
    this.internalPlayer,
  });

  final String? container;
  final String? videoCodec;
  final int? videoBitrate;
  final double? videoFps;
  final String? videoDecoder;
  final String? audioCodec;
  final int? audioBitrate;

  /// KSPlayer 内部实际使用的播放器，例如 `KSMEPlayer` 或 `AVPlayer`。
  final String? internalPlayer;

  PlaybackMediaInfo copyWith({
    String? container,
    String? videoCodec,
    int? videoBitrate,
    double? videoFps,
    String? videoDecoder,
    String? audioCodec,
    int? audioBitrate,
    String? internalPlayer,
  }) {
    return PlaybackMediaInfo(
      container: container ?? this.container,
      videoCodec: videoCodec ?? this.videoCodec,
      videoBitrate: videoBitrate ?? this.videoBitrate,
      videoFps: videoFps ?? this.videoFps,
      videoDecoder: videoDecoder ?? this.videoDecoder,
      audioCodec: audioCodec ?? this.audioCodec,
      audioBitrate: audioBitrate ?? this.audioBitrate,
      internalPlayer: internalPlayer ?? this.internalPlayer,
    );
  }

  /// 使用播放请求中的后端提示和地址扩展名创建初始调试信息。
  factory PlaybackMediaInfo.fromSource({
    required String url,
    String? formatHint,
    String? internalPlayer,
  }) {
    final container = inferPlaybackContainer(url, formatHint);
    return PlaybackMediaInfo(
      container: container,
      internalPlayer: internalPlayer,
    );
  }

  static String? inferInternalPlayer(
    String url,
    String? formatHint, {
    String? videoCodec,
    bool preferFfmpegForHls = false,
  }) {
    // SMB 回环代理地址（含 m3u8）始终由 KSMEPlayer 处理，与原生
    // prefersFfmpegPlayer 的决策顺序保持一致。
    try {
      final host = Uri.parse(url).host.toLowerCase();
      if (host == '127.0.0.1' || host == 'localhost' || host == '::1') {
        return 'KSMEPlayer';
      }
    } catch (_) {}
    // 其余 HLS 默认 AVPlayer（OMM 转码/在线流），文件源显式要求 FFmpeg。
    if (_isHlsMedia(url, formatHint)) {
      return preferFfmpegForHls ? 'KSMEPlayer' : 'AVPlayer';
    }
    if (_isFfmpegVideoCodec(videoCodec)) return 'KSMEPlayer';
    final container = inferPlaybackContainer(url, formatHint);
    if (container == null) return null;
    return switch (container) {
      'mkv' || 'matroska' || 'webm' => 'KSMEPlayer',
      _ => 'AVPlayer',
    };
  }

  static bool _isHlsMedia(String url, String? formatHint) {
    final hint = formatHint?.trim().toLowerCase() ?? '';
    if (hint == 'm3u8' || hint == 'hls' || hint.contains('mpegurl')) {
      return true;
    }
    final path =
        Uri.tryParse(url.trim())?.path.toLowerCase() ??
        url.trim().toLowerCase();
    return path.endsWith('.m3u8');
  }

  static bool _isFfmpegVideoCodec(String? codec) {
    final normalized = (codec ?? '').toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    return normalized.contains('hevc') ||
        normalized.contains('h265') ||
        normalized.contains('hvc1') ||
        normalized.contains('hev1') ||
        normalized.contains('x265');
  }

  factory PlaybackMediaInfo.fromJson(Map<String, dynamic> json) {
    String? stringValue(Object? value) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? null : text;
    }

    int? positiveInt(Object? value) {
      final number = value is num ? value.toInt() : int.tryParse('$value');
      return number == null || number <= 0 ? null : number;
    }

    double? positiveDouble(Object? value) {
      final number = value is num
          ? value.toDouble()
          : double.tryParse('$value');
      return number == null || !number.isFinite || number <= 0 ? null : number;
    }

    return PlaybackMediaInfo(
      container: stringValue(json['container']),
      videoCodec: stringValue(json['video_codec']),
      videoBitrate: positiveInt(json['video_bitrate']),
      videoFps: positiveDouble(json['video_fps']),
      videoDecoder: stringValue(json['video_decoder']),
      audioCodec: stringValue(json['audio_codec']),
      audioBitrate: positiveInt(json['audio_bitrate']),
      internalPlayer: stringValue(json['internal_player']),
    );
  }

  static PlaybackMediaInfo? fromJsonString(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      return PlaybackMediaInfo.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }
}

String? inferPlaybackContainer(String url, String? formatHint) {
  final hint = formatHint?.trim().toLowerCase() ?? '';
  final hintTokens = hint.split(RegExp(r'[^a-z0-9]+'));
  const knownContainers = {
    'mp4',
    'mov',
    'm4v',
    'mkv',
    'matroska',
    'webm',
    'mpegts',
    'ts',
    'm3u8',
    'hls',
  };
  for (final token in hintTokens) {
    if (knownContainers.contains(token)) return token;
  }
  try {
    final path = Uri.parse(url).path;
    final fileName = path.split('/').last;
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == fileName.length - 1) return null;
    final extension = fileName.substring(dotIndex + 1).trim().toLowerCase();
    return extension.isEmpty ? null : extension;
  } catch (_) {
    return null;
  }
}

@immutable
class PlaybackAudioTrackState {
  const PlaybackAudioTrackState({
    required this.id,
    required this.title,
    required this.language,
    required this.isSelected,
  });

  final String id;
  final String title;
  final String language;
  final bool isSelected;
}

@immutable
class PlaybackViewState {
  const PlaybackViewState({
    required this.engineKind,
    this.lifecycle = PlaybackLifecycle.idle,
    this.playing = false,
    this.buffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = Duration.zero,
    this.rate = 1,
    this.videoSize = Size.zero,
    this.mediaInfo,
    this.subtitleText = const <String>[],
    this.audioTracks = const <PlaybackAudioTrackState>[],
    this.selectedAudioTrackId,
    this.selectedSubtitleTrackId,
    this.firstFrameRendered = false,
    this.inPictureInPicture = false,
    this.currentTitle,
    this.artworkPath,
    this.queueIndex,
    this.shuffleEnabled = false,
    this.repeatMode = PlaybackRepeatMode.off,
    this.error,
  });

  final PlaybackEngineKind engineKind;
  final PlaybackLifecycle lifecycle;
  final bool playing;
  final bool buffering;
  final Duration position;
  final Duration duration;
  final Duration buffered;
  final double rate;
  final Size videoSize;
  final PlaybackMediaInfo? mediaInfo;
  final List<String> subtitleText;
  final List<PlaybackAudioTrackState> audioTracks;
  final String? selectedAudioTrackId;
  final String? selectedSubtitleTrackId;
  final bool firstFrameRendered;
  final bool inPictureInPicture;
  final String? currentTitle;
  final String? artworkPath;
  final int? queueIndex;
  final bool shuffleEnabled;
  final PlaybackRepeatMode repeatMode;
  final String? error;

  bool get mainMediaLoaded =>
      lifecycle == PlaybackLifecycle.ready ||
      duration > Duration.zero ||
      videoSize != Size.zero ||
      audioTracks.isNotEmpty;

  /// 首帧出现前等待首段视频流；首帧出现后，仅在当前时间点超出已缓冲
  /// 区间时显示。这样缓冲区内 seek 不会被短暂的 buffering 事件打断。
  bool get shouldShowVideoBuffering {
    if (!buffering) return false;
    if (!firstFrameRendered) return true;
    return position > buffered;
  }

  PlaybackViewState copyWith({
    PlaybackEngineKind? engineKind,
    PlaybackLifecycle? lifecycle,
    bool? playing,
    bool? buffering,
    Duration? position,
    Duration? duration,
    Duration? buffered,
    double? rate,
    Size? videoSize,
    PlaybackMediaInfo? mediaInfo,
    bool clearMediaInfo = false,
    List<String>? subtitleText,
    List<PlaybackAudioTrackState>? audioTracks,
    String? selectedAudioTrackId,
    bool clearSelectedAudioTrackId = false,
    String? selectedSubtitleTrackId,
    bool clearSelectedSubtitleTrackId = false,
    bool? firstFrameRendered,
    bool? inPictureInPicture,
    String? currentTitle,
    String? artworkPath,
    bool clearArtworkPath = false,
    int? queueIndex,
    bool? shuffleEnabled,
    PlaybackRepeatMode? repeatMode,
    String? error,
    bool clearError = false,
  }) {
    return PlaybackViewState(
      engineKind: engineKind ?? this.engineKind,
      lifecycle: lifecycle ?? this.lifecycle,
      playing: playing ?? this.playing,
      buffering: buffering ?? this.buffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      buffered: buffered ?? this.buffered,
      rate: rate ?? this.rate,
      videoSize: videoSize ?? this.videoSize,
      mediaInfo: clearMediaInfo ? mediaInfo : mediaInfo ?? this.mediaInfo,
      subtitleText: subtitleText ?? this.subtitleText,
      audioTracks: audioTracks ?? this.audioTracks,
      selectedAudioTrackId: clearSelectedAudioTrackId
          ? null
          : selectedAudioTrackId ?? this.selectedAudioTrackId,
      selectedSubtitleTrackId: clearSelectedSubtitleTrackId
          ? null
          : selectedSubtitleTrackId ?? this.selectedSubtitleTrackId,
      firstFrameRendered: firstFrameRendered ?? this.firstFrameRendered,
      inPictureInPicture: inPictureInPicture ?? this.inPictureInPicture,
      currentTitle: currentTitle ?? this.currentTitle,
      artworkPath: clearArtworkPath ? null : artworkPath ?? this.artworkPath,
      queueIndex: queueIndex ?? this.queueIndex,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      repeatMode: repeatMode ?? this.repeatMode,
      error: clearError ? null : error ?? this.error,
    );
  }
}

@immutable
class PlaybackOpenRequest {
  const PlaybackOpenRequest({
    required this.url,
    this.startAt,
    this.headers,
    this.play = true,
    this.formatHint,
    this.mediaInfo,
    this.preferFfmpegForHls = false,
    this.queue = const <PlayerQueueItem>[],
    this.queueIndex = 0,
    this.onQueueDispose,
  });

  final String url;
  final Duration? startAt;
  final Map<String, String>? headers;
  final bool play;

  /// 后端探测到的容器提示，例如 `matroska` 或 `mkv`。
  /// 仅供需要按容器选择原生播放实现的内核使用。
  final String? formatHint;
  final PlaybackMediaInfo? mediaInfo;

  /// HLS 是否优先使用 KSPlayer 的 FFmpeg 内核（KSMEPlayer）。
  /// 仅文件源（WebDAV 直连、SMB 回环代理）设为 true；OMM 转码流与
  /// DBO 在线流保持 false，由 AVPlayer 处理串流与 seek。
  final bool preferFfmpegForHls;
  final List<PlayerQueueItem> queue;
  final int queueIndex;
  final Future<void> Function()? onQueueDispose;
}

@immutable
class PlaybackPictureInPictureRequest {
  const PlaybackPictureInPictureRequest({
    required this.url,
    required this.position,
    required this.autoplay,
    this.headers,
    this.onStopped,
  });

  final String url;
  final Map<String, String>? headers;
  final Duration position;
  final bool autoplay;
  final Future<void> Function(Duration position)? onStopped;
}

abstract interface class PlaybackEngine {
  PlaybackEngineKind get kind;
  PlaybackEngineCapabilities get capabilities;
  ValueListenable<PlaybackViewState> get state;

  Future<void> open(PlaybackOpenRequest request);
  Future<void> play();
  Future<void> pause();
  Future<void> playOrPause();
  Future<void> skipToPrevious();
  Future<void> skipToNext();
  Future<void> setShuffleMode(bool enabled);
  Future<void> setRepeatMode(PlaybackRepeatMode mode);
  Future<void> seek(Duration position);
  Future<void> setRate(double rate);
  Future<void> configure({bool? hardwareAcceleration, int? preloadBytes});
  Future<void> setAudioTrackById(String id);
  Future<void> setSubtitleTrackById(
    String id, {
    int? fallbackIndex,
    bool nativeRendering = false,
  });
  Future<void> setSubtitleData(
    String content, {
    String? title,
    String? language,
  });
  Future<void> clearSubtitle();
  Future<void> setSubtitleDelay(Duration delay);
  Future<Uint8List?> captureFrame(
    Duration position, {
    String? sourceUrl,
    Map<String, String>? headers,
  });
  Future<void> clearFramePreview();
  Future<bool> enterPictureInPicture(PlaybackPictureInPictureRequest request);
  Future<void> stopPictureInPicture();
  Future<void> stop();
  Future<void> dispose();

  Widget buildSurface({BoxFit fit = BoxFit.contain});
}

/// 可选的实时 PCM 搓碟能力。
///
/// 普通播放引擎无需实现；支持该接口的音频引擎必须让正负速率作用于同一条
/// 当前音轨，并在结束时返回 native 音频游标的真实位置。
abstract interface class ScratchPlaybackEngine {
  Future<bool> startScratch(Duration position, {required bool resumePlayback});
  Future<void> setScratchRate(double rate);

  /// 取消尚未完成的 native 准备，不影响已经开始的 Scratch。
  Future<void> cancelScratchStart();
  Future<Duration?> finishScratch({required bool resumePlayback});
}
