import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import 'disk_cache.dart';

class PrecacheMovieDialog extends ConsumerStatefulWidget {
  const PrecacheMovieDialog({
    super.key,
    required this.movieId,
    required this.movieTitle,
  });

  final int movieId;
  final String movieTitle;

  static Future<void> show(
    BuildContext context, {
    required int movieId,
    required String movieTitle,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PrecacheMovieDialog(
        movieId: movieId,
        movieTitle: movieTitle,
      ),
    );
  }

  @override
  ConsumerState<PrecacheMovieDialog> createState() =>
      _PrecacheMovieDialogState();
}

class _PrecacheMovieDialogState extends ConsumerState<PrecacheMovieDialog> {
  late final CancelToken _cancelToken;
  int _received = 0;
  int _total = 0;
  bool _running = true;
  String? _error;
  VideoCacheResult? _result;

  @override
  void initState() {
    super.initState();
    _cancelToken = CancelToken();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_start());
    });
  }

  Future<void> _start() async {
    try {
      final result = await ref.read(videoPrecacheServiceProvider).precacheMovie(
            movieId: widget.movieId,
            settings: ref.read(diskPrecacheSettingsProvider),
            cancelToken: _cancelToken,
            onProgress: (received, total) {
              if (!mounted) return;
              setState(() {
                _received = received;
                _total = total;
              });
            },
          );
      if (!mounted) return;
      ref.invalidate(cacheUsageProvider);
      setState(() {
        _running = false;
        _result = result;
      });
      AppHaptics.medium();
    } catch (error) {
      if (!mounted) return;
      if (error is DioException && CancelToken.isCancel(error)) return;
      setState(() {
        _running = false;
        _error = _message(error);
      });
    }
  }

  String _message(Object error) {
    if (error is CacheDisabledException ||
        error is CacheLimitExceededException ||
        error is CacheNetworkUnavailableException) {
      return error.toString();
    }
    return '预缓存失败: ${toApiException(error).message}';
  }

  void _close() {
    if (_running) {
      _cancelToken.cancel('user cancelled');
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final progress = _total > 0
        ? (_received / _total).clamp(0.0, 1.0).toDouble()
        : null;
    final completed = _result != null;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.download_for_offline_outlined, color: c.accent),
          const SizedBox(width: 10),
          const Expanded(child: Text('磁盘预缓存')),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.movieTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.sectionTitle(context),
            ),
            const SizedBox(height: 18),
            if (_running) ...[
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 10),
              Text(
                progress == null
                    ? '正在准备下载…'
                    : '${formatCacheBytes(_received)} / ${formatCacheBytes(_total)}',
                style: AppText.meta(context),
              ),
            ] else if (completed) ...[
              Text(
                _result!.fromCache ? '影片已在缓存中' : '预缓存完成',
                style: TextStyle(color: c.accent, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '已占用 ${formatCacheBytes(_result!.bytes)}',
                style: AppText.meta(context),
              ),
            ] else
              Text(
                _error ?? '预缓存失败',
                style: TextStyle(color: c.danger, height: 1.4),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _close,
          child: Text(_running ? '取消' : '关闭'),
        ),
      ],
    );
  }
}
