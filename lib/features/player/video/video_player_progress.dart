part of 'video_player_page.dart';

// 状态及资源所有权保留在页面；此扩展只组织同一职责的方法。
extension _VideoPlayerProgress on _VideoPlayerPageState {
  Future<void> _reportProgress() {
    if (_isDirectPlayback) return _reportFileProgress();
    final movieId = widget.movieId;
    if (movieId == null) return Future<void>.value();
    final next = _progressReportChain.then<void>((_) async {
      final position = _host.position.inSeconds;
      final duration = _host.duration.inSeconds;
      final positionSec = position > 0 ? position : _lastPositionSec;
      final durationSec = duration > 0 ? duration : _lastDurationSec;
      _lastPositionSec = positionSec;
      _lastDurationSec = durationSec;
      if (durationSec <= 0 || positionSec <= 0) return;

      try {
        await ref
            .read(mediaRepositoryProvider)
            .upsertWatchRecord(
              movieId,
              positionSec: positionSec,
              durationSec: durationSec,
              completed: positionSec >= (durationSec * 0.95),
            );
      } catch (_) {
        // 播放器退出时网络可能已经断开，不能影响退出流程。
      }
    });
    _progressReportChain = next;
    return next;
  }

  Future<void> _reportFileProgress() {
    final fileName = _activeDirectPlaybackFileName?.trim();
    final serverReporter = _activeDirectProgressReporter;
    if ((fileName == null || fileName.isEmpty) && serverReporter == null) {
      return Future<void>.value();
    }
    final next = _progressReportChain.then<void>((_) async {
      final positionSec = _host.position.inSeconds > 0
          ? _host.position.inSeconds
          : _lastPositionSec;
      final durationSec = _host.duration.inSeconds > 0
          ? _host.duration.inSeconds
          : _lastDurationSec;
      _lastPositionSec = positionSec;
      _lastDurationSec = durationSec;
      if (fileName != null && fileName.isNotEmpty) {
        final settings = ref.read(playerSettingsProvider);
        if (settings.resumeFromLastPosition && durationSec > 0) {
          await _filePlaybackProgress.savePosition(
            fileName: fileName,
            positionSec: positionSec,
            durationSec: durationSec,
          );
        }
      }
      if (serverReporter != null && positionSec > 0 && durationSec > 0) {
        // 服务器侧进度（如 Emby 的 Stopped 报告）不受本地续播偏好影响；
        // 与 OMM 观看记录相同，播放超过 95% 视为看完。
        try {
          await serverReporter(
            positionSec,
            durationSec,
            positionSec >= (durationSec * 0.95),
          );
        } catch (_) {
          // 播放器退出时网络可能已经断开，不能影响退出流程。
        }
      }
    });
    _progressReportChain = next;
    return next;
  }

  void _bindProgress() {
    _unbindProgress();
    _completionHandled = false;
    _lastPositionSec = _host.position.inSeconds;
    _lastDurationSec = _host.duration.inSeconds;
    _posSub = _host.positionStream.listen((position) {
      _lastPositionSec = position.inSeconds;
    });
    _durSub = _host.durationStream.listen((duration) {
      _lastDurationSec = duration.inSeconds;
    });
    _completedSub = _host.completedStream.listen((completed) {
      if (!_isLeaving && completed && !_completionHandled) {
        _completionHandled = true;
        unawaited(_handlePlaybackCompleted());
      }
    });
    _errorSub = _host.errorStream.listen(_onPlayerError);
    _progressReportTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_isLeaving) unawaited(_reportProgress());
    });
  }

  Future<void> _handlePlaybackCompleted() async {
    final duration = _host.duration.inSeconds;
    if (duration > 0) _lastDurationSec = duration;
    if (_lastDurationSec > 0) _lastPositionSec = _lastDurationSec;
    await _reportProgress();
    await _stopTranscodeSession();
    if (!mounted ||
        _isLeaving ||
        !widget.autoAdvanceQueue ||
        widget.queueIndex >= widget.queue.length - 1) {
      return;
    }
    await _switchMedia(widget.queueIndex + 1);
  }

  void _unbindProgress() {
    _posSub?.cancel();
    _durSub?.cancel();
    _completedSub?.cancel();
    _errorSub?.cancel();
    _posSub = null;
    _durSub = null;
    _completedSub = null;
    _errorSub = null;
    _progressReportTimer?.cancel();
    _progressReportTimer = null;
  }
}
