import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/preview.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';
import 'package:omm/features/oh_my_media/tasks/task_center_provider.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/status_pill.dart';
import 'package:omm/features/settings/settings_common.dart';

/// 影片详情页的预览资产状态与单片生成入口。
class PreviewStatusCard extends ConsumerStatefulWidget {
  const PreviewStatusCard({
    super.key,
    required this.movieId,
    required this.movieTitle,
    this.filePath,
  });

  final int movieId;
  final String movieTitle;
  final String? filePath;

  @override
  ConsumerState<PreviewStatusCard> createState() => _PreviewStatusCardState();
}

class _PreviewStatusCardState extends ConsumerState<PreviewStatusCard> {
  PreviewStatus? _status;
  PreviewTask? _task;
  String? _taskId;
  String? _error;
  Timer? _pollTimer;
  bool _loading = true;
  bool _starting = false;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadInitial());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    if (ref.read(serverConfigProvider)?.isOmm != true) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final status = await ref
          .read(mediaRepositoryProvider)
          .previewStatus(widget.movieId);
      if (!mounted) return;
      setState(() {
        _status = status;
        _task = status.task;
        _taskId = status.task?.taskId;
        _loading = false;
        _error = null;
      });
      if (status.task?.isActive == true && _taskId?.isNotEmpty == true) {
        _startPolling();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = toApiException(error).message;
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_pollTask()),
    );
    unawaited(_pollTask());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollTask() async {
    final taskId = _taskId;
    if (_polling || taskId == null || taskId.isEmpty) return;
    _polling = true;
    try {
      final task = await ref.read(mediaRepositoryProvider).previewTask(taskId);
      if (!mounted) return;
      setState(() {
        _task = task;
        _error = null;
      });
      if (task.isActive) return;
      _stopPolling();
      final status = await ref
          .read(mediaRepositoryProvider)
          .previewStatus(widget.movieId, taskId: taskId);
      if (!mounted) return;
      setState(() {
        _status = status;
        _task = task;
      });
    } catch (error) {
      if (mounted) setState(() => _error = toApiException(error).message);
    } finally {
      _polling = false;
    }
  }

  Future<void> _generate() async {
    if (!_canGenerate || _starting) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(mediaRepositoryProvider)
          .generatePreview(
            widget.movieId,
            overwrite: _status?.hasReadyAsset == true,
          );
      if (!mounted) return;
      _taskId = result.taskId;
      _task = result.task;
      ref
          .read(taskCenterProvider.notifier)
          .registerPreview(
            result.task,
            movieId: widget.movieId,
            movieTitle: widget.movieTitle,
          );
      setState(() {});
      if (result.task.isActive) {
        _startPolling();
      } else {
        // 缓存复用可能直接返回终态任务；仍需刷新资产状态，否则按钮和
        // 视频/Sprite/VTT 就绪标记会停留在提交前的快照。
        final status = await ref
            .read(mediaRepositoryProvider)
            .previewStatus(widget.movieId, taskId: result.taskId);
        if (!mounted) return;
        setState(() {
          _status = status;
          _task = status.task ?? result.task;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = toApiException(error).message);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  bool get _canGenerate {
    if (_status == null || _sourceUnavailable) return false;
    final path = widget.filePath?.trim().toLowerCase() ?? '';
    return path.isNotEmpty && !path.endsWith('.strm');
  }

  bool get _sourceUnavailable => const {
    'unsupported',
    'missing',
    'invalid',
  }.contains(_status?.sourceState);

  PreviewAssetStatus _asset(String key) {
    final assets = _status?.assets;
    if (assets == null) return const PreviewAssetStatus();
    // 兼容旧服务端曾使用的 sprite_vtt 键名；当前协议使用 vtt。
    return assets[key] ??
        (key == 'vtt' ? assets['sprite_vtt'] : null) ??
        const PreviewAssetStatus();
  }

  String _taskMessage(AppL10n l) {
    final task = _task;
    if (task == null) return '';
    if (task.status == 'queued') return l.previewQueued;
    if (task.status == 'completed') return l.previewCompleted;
    if (task.status == 'failed') return l.previewFailed;
    if (task.isCanceled) return l.previewCancelled;
    return l.previewGenerating;
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(serverConfigProvider)?.isOmm != true) {
      return const SizedBox.shrink();
    }
    final colors = appColors(context);
    final l = AppL10n.of(context);
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: settingsCardDecoration(context),
        child: const LinearProgressIndicator(minHeight: 4),
      );
    }
    final task = _task;
    final active = task?.isActive == true;
    final progress = task?.overallProgress ?? 0;
    final buttonLabel = _status?.hasReadyAsset == true
        ? l.previewRegenerate
        : l.previewGenerate;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: settingsCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.video_settings_outlined, color: colors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.previewStatusTitle,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (active) StatusPill(status: task!.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _sourceUnavailable
                ? l.previewSourceUnsupported
                : l.previewSourceReady,
            style: TextStyle(
              color: _canGenerate ? colors.muted : colors.warning,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _assetRow(colors, l.previewVideoAsset, _asset('video')),
          const SizedBox(height: 7),
          _assetRow(colors, l.previewSpriteAsset, _asset('sprite')),
          const SizedBox(height: 7),
          _assetRow(colors, l.previewVttAsset, _asset('vtt')),
          if (active) ...[
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: (progress / 100).clamp(0.0, 1.0),
              minHeight: 5,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: colors.divider,
              color: colors.accent,
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _taskMessage(l),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.muted, fontSize: 11),
                  ),
                ),
                Text(
                  '${progress.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _canGenerate && !_starting ? _generate : null,
                icon: _starting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _status?.hasReadyAsset == true
                            ? Icons.refresh_rounded
                            : Icons.play_arrow_rounded,
                      ),
                label: Text(buttonLabel),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: colors.danger, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _assetRow(AppColors colors, String label, PreviewAssetStatus asset) {
    return Row(
      children: [
        Icon(
          asset.ready
              ? Icons.check_circle_outline
              : Icons.radio_button_unchecked,
          size: 18,
          color: asset.ready ? colors.accent : colors.muted,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: colors.text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          asset.ready
              ? AppL10n.of(context).previewReady
              : AppL10n.of(context).previewNotReady,
          style: TextStyle(
            color: asset.ready ? colors.accent : colors.muted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
