import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/models/playback.dart' as playback_models;
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/media/media_browser_media_source.dart';
import 'package:omm/core/sources/media/media_models.dart';
import 'package:omm/core/sources/media/media_source_providers.dart';
import 'package:omm/features/media_browser/api/media_browser_config.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/media_browser/repositories/media_browser_media_repository.dart';
import 'package:omm/features/player/common/playback_engine.dart';
import 'package:omm/features/player/common/player_queue.dart';
import 'package:omm/features/player/common/player_settings.dart';
import 'package:omm/features/player/video/player_engine_picker.dart';
import 'package:omm/features/player/video/video_player_page.dart';
import 'package:omm/shared/single_flight_gate.dart';

final _mediaBrowserVideoLaunchGate = SingleFlightGate();

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
  String? mediaSourceId,
  MediaBrowserVideoPart? part,
  bool playAllParts = false,
  PlaybackEngineKind? engineKind,
}) {
  return _mediaBrowserVideoLaunchGate.run(
    () => _openMediaBrowserPlayback(
      context,
      ref,
      item: item,
      transcode: transcode,
      mediaSourceId: mediaSourceId,
      part: part,
      playAllParts: playAllParts,
      engineKind: engineKind,
    ),
  );
}

Future<void> _openMediaBrowserPlayback(
  BuildContext context,
  WidgetRef ref, {
  required MediaBrowserItem item,
  bool transcode = false,
  String? mediaSourceId,
  MediaBrowserVideoPart? part,
  bool playAllParts = false,
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
    final allParts = item.videoParts;
    final firstPart = (part ?? allParts.first).copyWith(
      mediaSourceId: part == null ? mediaSourceId : part.mediaSourceId,
    );
    final queueParts = playAllParts && part == null && allParts.length > 1
        ? <MediaBrowserVideoPart>[firstPart, ...allParts.skip(1)]
        : <MediaBrowserVideoPart>[firstPart];
    final firstPlayback = await _resolveMediaBrowserPart(
      source: source,
      repo: repo,
      config: config,
      part: queueParts.first,
      transcode: transcode,
    );
    final queue = [
      for (var index = 0; index < queueParts.length; index++)
        _queueItemForPart(
          source: source,
          repo: repo,
          config: config,
          item: item,
          part: queueParts[index],
          partNumber: index + 1,
          transcode: transcode,
          resolved: index == 0 ? firstPlayback : null,
        ),
    ];
    if (!context.mounted) return;
    await VideoPlayerPage.openDirect(
      context,
      title: queue.first.title,
      directUrl: firstPlayback.url,
      directHeaders: firstPlayback.headers,
      directFormatHint: firstPlayback.formatHint,
      directAudioTracks: firstPlayback.audioTracks,
      directSubtitleTracks: firstPlayback.subtitleTracks,
      directProgressReporter: firstPlayback.progressReporter,
      startPositionSec: firstPlayback.startPositionSec,
      engineKind: engineKind,
      queue: queue,
      queueIndex: 0,
      autoAdvanceQueue: queue.length > 1,
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

PlayerQueueItem _queueItemForPart({
  required MediaBrowserMediaSource source,
  required MediaBrowserMediaRepository repo,
  required MediaBrowserConfig config,
  required MediaBrowserItem item,
  required MediaBrowserVideoPart part,
  required int partNumber,
  required bool transcode,
  required PlayerQueuePlayback? resolved,
}) {
  final title = _partPlaybackTitle(item, partNumber);
  return PlayerQueueItem(
    title: title,
    mediaId:
        '${config.sourceId}:${item.id}:${part.itemId}:${part.mediaSourceId ?? part.id}',
    directUrl: resolved?.url,
    directHeaders: resolved?.headers,
    directFormatHint: resolved?.formatHint,
    directAudioTracks: resolved?.audioTracks ?? const [],
    directSubtitleTracks: resolved?.subtitleTracks ?? const [],
    directProgressReporter: resolved?.progressReporter,
    startPositionSec: resolved?.startPositionSec ?? 0,
    directPlaybackResolver: () => _resolveMediaBrowserPart(
      source: source,
      repo: repo,
      config: config,
      part: part,
      transcode: transcode,
    ),
  );
}

Future<PlayerQueuePlayback> _resolveMediaBrowserPart({
  required MediaBrowserMediaSource source,
  required MediaBrowserMediaRepository repo,
  required MediaBrowserConfig config,
  required MediaBrowserVideoPart part,
  required bool transcode,
}) async {
  final itemId = part.itemId.trim();
  final descriptor = await source.resolvePlayback(
    MediaRef(sourceId: SourceId(config.sourceId), value: itemId),
    PlaybackRequest(
      forceVideoTranscode: transcode,
      mediaSourceId: part.mediaSourceId,
    ),
  );
  final payload = descriptor.payload;
  final playSessionId = payload is MediaBrowserPlaybackInfo
      ? payload.playSessionId
      : null;
  final resumeSec = descriptor.startAt.round();
  // 每个分集都使用自己的 ItemId 和播放会话，不能把第二分集的进度记到父条目。
  unawaited(
    repo
        .reportPlaybackStart(
          itemId: itemId,
          positionTicks: secondsToMediaBrowserTicks(resumeSec),
          playSessionId: playSessionId,
        )
        .catchError((_) {}),
  );
  return PlayerQueuePlayback(
    url: descriptor.uri.toString(),
    headers: descriptor.headers,
    formatHint: descriptor.mimeType,
    audioTracks: _audioTracks(descriptor.audioTracks),
    subtitleTracks: _subtitleTracks(descriptor.subtitleTracks),
    startPositionSec: resumeSec,
    progressReporter: (positionSec, durationSec, completed) =>
        repo.reportPlaybackStopped(
          itemId: itemId,
          positionTicks: secondsToMediaBrowserTicks(
            completed ? durationSec : positionSec,
          ),
          playSessionId: playSessionId,
        ),
  );
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
  String? mediaSourceId,
  MediaBrowserVideoPart? part,
  bool playAllParts = false,
}) async {
  await _mediaBrowserVideoLaunchGate.run(() async {
    if (!playbackEnginePickerEnabled) return;
    final engineKind = await pickPlaybackEngine(
      context,
      ref.read(playerSettingsProvider).iosEngine,
    );
    if (engineKind == null || !context.mounted) return;
    await _openMediaBrowserPlayback(
      context,
      ref,
      item: item,
      transcode: transcode,
      mediaSourceId: mediaSourceId,
      part: part,
      playAllParts: playAllParts,
      engineKind: engineKind,
    );
  });
}

String _partPlaybackTitle(MediaBrowserItem item, int partNumber) {
  final title = _playbackTitle(item);
  return partNumber <= 1 ? title : '$title · Part $partNumber';
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
