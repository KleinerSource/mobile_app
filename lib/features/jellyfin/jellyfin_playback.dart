import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/media/media_models.dart';
import 'package:omm/core/sources/media/media_source_providers.dart';
import 'package:omm/features/jellyfin/models/jellyfin_models.dart';
import 'package:omm/features/jellyfin/providers/jellyfin_providers.dart';
import 'package:omm/features/player/common/playback_engine.dart';
import 'package:omm/features/player/common/player_settings.dart';
import 'package:omm/features/player/video/player_engine_picker.dart';
import 'package:omm/features/player/video/video_player_page.dart';

/// 打开 Jellyfin 条目播放。
///
/// 默认直连原始文件（static=true），[transcode] 为 true 时使用服务器
/// PlaybackInfo 返回的 HLS 转码地址。开播上报 Sessions/Playing，退出时
/// 通过播放页的进度回调上报 Stopped，让 Jellyfin 记住「继续观看」位置。
Future<void> openJellyfinPlayback(
  BuildContext context,
  WidgetRef ref, {
  required JellyfinItem item,
  bool transcode = false,
  PlaybackEngineKind? engineKind,
}) async {
  final source = ref.read(jellyfinMediaSourceProvider);
  if (source == null) return;
  final repo = ref.read(jellyfinMediaRepositoryProvider);
  final itemId = item.id.trim();
  if (itemId.isEmpty) return;
  try {
    final descriptor = await source.resolvePlayback(
      MediaRef(sourceId: const SourceId('jellyfin'), value: itemId),
      PlaybackRequest(forceVideoTranscode: transcode),
    );
    final payload = descriptor.payload;
    final playSessionId = payload is JellyfinPlaybackInfo
        ? payload.playSessionId
        : null;
    final resumeSec = descriptor.startAt.round();
    // 开播报告不阻塞播放；失败只影响服务端会话列表，不影响本地播放。
    unawaited(
      repo
          .reportPlaybackStart(
            itemId: itemId,
            positionTicks: secondsToJellyfinTicks(resumeSec),
            playSessionId: playSessionId,
          )
          .catchError((_) {}),
    );
    if (!context.mounted) return;
    await VideoPlayerPage.openDirect(
      context,
      title: _playbackTitle(item),
      directUrl: descriptor.uri.toString(),
      directFormatHint: descriptor.mimeType,
      startPositionSec: resumeSec,
      engineKind: engineKind,
      directProgressReporter: (positionSec, durationSec, completed) =>
          repo.reportPlaybackStopped(
            itemId: itemId,
            positionTicks: secondsToJellyfinTicks(
              completed ? durationSec : positionSec,
            ),
            playSessionId: playSessionId,
          ),
    );
    // 播放结束同步详情与首页的进度/已看状态。
    ref.invalidate(jellyfinItemDetailProvider);
    ref.invalidate(jellyfinResumeProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(toApiException(error).message)));
    }
  }
}

/// 长按「播放」先选内核再用所选内核播放。
///
/// 当前平台无可选内核（非 iOS）时是空操作，调用方应以
/// [playbackEnginePickerEnabled] 禁用长按。
Future<void> openJellyfinPlaybackWithEnginePicker(
  BuildContext context,
  WidgetRef ref, {
  required JellyfinItem item,
  bool transcode = false,
}) async {
  if (!playbackEnginePickerEnabled) return;
  final engineKind = await pickPlaybackEngine(
    context,
    ref.read(playerSettingsProvider).iosEngine,
  );
  if (engineKind == null || !context.mounted) return;
  await openJellyfinPlayback(
    context,
    ref,
    item: item,
    transcode: transcode,
    engineKind: engineKind,
  );
}

String _playbackTitle(JellyfinItem item) {
  if (!item.isEpisode) return item.name;
  final series = item.seriesName?.trim();
  final season = item.parentIndexNumber ?? 0;
  final episode = item.indexNumber ?? 0;
  final code = 'S${season.toString().padLeft(2, '0')}'
      'E${episode.toString().padLeft(2, '0')}';
  return series?.isNotEmpty == true ? '$series · $code' : code;
}
