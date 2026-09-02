import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/models/playback.dart' as playback_models;
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/media/media_browser_media_source.dart';
import 'package:omm/core/sources/media/media_models.dart';
import 'package:omm/core/sources/media/media_source_providers.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/player/common/playback_engine.dart';
import 'package:omm/features/player/common/player_settings.dart';
import 'package:omm/features/player/video/player_engine_picker.dart';
import 'package:omm/features/player/video/video_player_page.dart';

/// 打开 Emby/Jellyfin 条目播放。
///
/// 默认直连原始文件（static=true），[transcode] 为 true 时使用服务器
/// PlaybackInfo 返回的 HLS 转码地址。开播上报 Sessions/Playing，退出时
/// 通过播放页的进度回调上报 Stopped，让服务器记住「继续观看」位置。
Future<void> openMediaBrowserPlayback(
  BuildContext context,
  WidgetRef ref, {
  required MediaBrowserItem item,
  bool transcode = false,
  PlaybackEngineKind? engineKind,
}) async {
  final config = ref.read(mediaBrowserConfigProvider);
  if (config == null) return;
  final source = ref
      .read(mediaSourceRegistryProvider)
      .find(SourceId(config.sourceId));
  if (source is! MediaBrowserMediaSource) return;
  final repo = ref.read(mediaBrowserMediaRepositoryProvider);
  final itemId = item.id.trim();
  if (itemId.isEmpty) return;
  try {
    final descriptor = await source.resolvePlayback(
      MediaRef(sourceId: SourceId(config.sourceId), value: itemId),
      PlaybackRequest(forceVideoTranscode: transcode),
    );
    final payload = descriptor.payload;
    final playSessionId = payload is MediaBrowserPlaybackInfo
        ? payload.playSessionId
        : null;
    final resumeSec = descriptor.startAt.round();
    // 开播报告不阻塞播放；失败只影响服务端会话列表，不影响本地播放。
    unawaited(
      repo
          .reportPlaybackStart(
            itemId: itemId,
            positionTicks: secondsToMediaBrowserTicks(resumeSec),
            playSessionId: playSessionId,
          )
          .catchError((_) {}),
    );
    if (!context.mounted) return;
    await VideoPlayerPage.openDirect(
      context,
      title: _playbackTitle(item),
      directUrl: descriptor.uri.toString(),
      directHeaders: descriptor.headers,
      directFormatHint: descriptor.mimeType,
      directAudioTracks: _audioTracks(descriptor.audioTracks),
      directSubtitleTracks: _subtitleTracks(descriptor.subtitleTracks),
      startPositionSec: resumeSec,
      engineKind: engineKind,
      directProgressReporter: (positionSec, durationSec, completed) =>
          repo.reportPlaybackStopped(
            itemId: itemId,
            positionTicks: secondsToMediaBrowserTicks(
              completed ? durationSec : positionSec,
            ),
            playSessionId: playSessionId,
          ),
    );
    // 播放结束同步详情与首页的进度/已看状态。
    ref.invalidate(mediaBrowserItemDetailProvider);
    ref.invalidate(mediaBrowserResumeProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(toApiException(error).message)));
    }
  }
}

List<playback_models.AudioTrack> _audioTracks(List<PlaybackTrack> tracks) =>
    tracks
        .asMap()
        .entries
        .map((entry) => _audioTrack(entry.value, entry.key))
        .toList(growable: false);

List<playback_models.SubtitleTrack> _subtitleTracks(
  List<PlaybackTrack> tracks,
) => tracks
    .asMap()
    .entries
    .map((entry) => _subtitleTrack(entry.value, entry.key))
    .toList(growable: false);

playback_models.AudioTrack _audioTrack(
  PlaybackTrack track,
  int fallbackIndex,
) => playback_models.AudioTrack(
  index: track.index >= 0 ? track.index : fallbackIndex,
  codec: track.codec ?? '',
  language: track.language ?? '',
  title: track.label,
  channels: track.channels ?? 0,
  isDefault: track.isDefault,
);

playback_models.SubtitleTrack _subtitleTrack(
  PlaybackTrack track,
  int fallbackIndex,
) => playback_models.SubtitleTrack(
  id: track.id,
  index: track.index >= 0 ? track.index : fallbackIndex,
  source: track.source ?? (track.isExternal ? 'external' : 'embedded'),
  language: track.language ?? '',
  title: track.label,
  codec: track.codec ?? '',
  url: track.url ?? '',
  isDefault: track.isDefault,
  playable: track.playable,
  forced: track.isForced,
);

/// 长按「播放」先选内核再用所选内核播放。
///
/// 当前平台无可选内核（非 iOS）时是空操作，调用方应以
/// [playbackEnginePickerEnabled] 禁用长按。
Future<void> openMediaBrowserPlaybackWithEnginePicker(
  BuildContext context,
  WidgetRef ref, {
  required MediaBrowserItem item,
  bool transcode = false,
}) async {
  if (!playbackEnginePickerEnabled) return;
  final engineKind = await pickPlaybackEngine(
    context,
    ref.read(playerSettingsProvider).iosEngine,
  );
  if (engineKind == null || !context.mounted) return;
  await openMediaBrowserPlayback(
    context,
    ref,
    item: item,
    transcode: transcode,
    engineKind: engineKind,
  );
}

String _playbackTitle(MediaBrowserItem item) {
  if (!item.isEpisode) return item.name;
  final series = item.seriesName?.trim();
  final season = item.parentIndexNumber ?? 0;
  final episode = item.indexNumber ?? 0;
  final code =
      'S${season.toString().padLeft(2, '0')}'
      'E${episode.toString().padLeft(2, '0')}';
  return series?.isNotEmpty == true ? '$series · $code' : code;
}
