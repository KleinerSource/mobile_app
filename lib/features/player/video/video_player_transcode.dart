part of 'video_player_page.dart';

// 状态及资源所有权保留在页面；此扩展只组织同一职责的方法。
extension _VideoPlayerTranscode on _VideoPlayerPageState {
  Future<void> _stopTranscodeSession({bool waitForServer = true}) async {
    final shouldStopServerSession = _transcodeSessionActive;
    _transcodeSessionActive = false;
    // SSE 是长连接，cancel() 的 Future 可能要等到底层 HTTP stream 完整收尾。
    // 先让旧回调失效并异步取消，不能让它阻塞后续的清晰度切换队列。
    _cancelTranscodeMonitoring();
    if (_connectionLease?.isActive != true) return;
    final movieId = widget.movieId;
    final source = ref.read(ommMediaSourceProvider);
    final stopFuture =
        shouldStopServerSession && movieId != null && source != null
        ? source.stopTranscode(_ommRef(movieId))
        : null;
    if (!shouldStopServerSession) return;
    if (stopFuture == null) return;
    if (!waitForServer) {
      // 服务器会话停止属于网络清理，不应阻塞本地播放器退出。
      unawaited(stopFuture.catchError((_) {}));
      return;
    }
    try {
      // 后端 StopByMovie 会等待 FFmpeg 退出，但网络异常不能把 _loadQueue
      // 永久锁住。正常会话在此窗口内都会完成；超时后继续打开新源。
      await stopFuture.timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  void _cancelTranscodeMonitoring() {
    _transcodeMonitoringGeneration++;
    final eventsSub = _eventsSub;
    _eventsSub = null;
    _transcodePollTimer?.cancel();
    _transcodePollTimer = null;
    if (eventsSub != null) {
      unawaited(eventsSub.cancel().catchError((_) {}));
    }
  }

  void _startTranscodeMonitoring(
    String quality,
    playback_models.PlaybackDecision decision,
  ) {
    if (_connectionLease?.isActive != true) return;
    final movieId = widget.movieId;
    if (movieId == null) return;
    _cancelTranscodeMonitoring();
    _transcodePollTimer?.cancel();
    final monitoringGeneration = _transcodeMonitoringGeneration;
    final source = ref.read(ommMediaSourceProvider);
    if (source == null) return;
    final streamUri = Uri.tryParse(decision.streamUrl);
    final streamQuery = streamUri?.queryParameters ?? const <String, String>{};
    final sessionQuality = streamQuery['quality']?.trim().isNotEmpty == true
        ? streamQuery['quality']!.trim()
        : quality;
    final mode = streamQuery['mode'];
    final audioStreamIndex = int.tryParse(
      streamQuery['audio_stream_index'] ?? '',
    );
    final subtitleTrackId = streamQuery['subtitle_track_id'];
    _eventsSub = source
        .transcodeEvents(
          _ommRef(movieId),
          quality: sessionQuality,
          mode: mode,
          audioStreamIndex: audioStreamIndex,
          subtitleTrackId: subtitleTrackId,
        )
        .listen(
          (status) {
            if (_isCurrentTranscodeMonitoring(monitoringGeneration)) {
              _applyTranscodeStatus(status);
            }
          },
          onError: (_) {
            if (_isCurrentTranscodeMonitoring(monitoringGeneration)) {
              _startTranscodePolling(
                sessionQuality,
                monitoringGeneration: monitoringGeneration,
                mode: mode,
                audioStreamIndex: audioStreamIndex,
                subtitleTrackId: subtitleTrackId,
              );
            }
          },
          onDone: () {
            if (_isCurrentTranscodeMonitoring(monitoringGeneration)) {
              _startTranscodePolling(
                sessionQuality,
                monitoringGeneration: monitoringGeneration,
                mode: mode,
                audioStreamIndex: audioStreamIndex,
                subtitleTrackId: subtitleTrackId,
              );
            }
          },
        );
    _transcodePollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollTranscodeStatus(
        sessionQuality,
        monitoringGeneration: monitoringGeneration,
        mode: mode,
        audioStreamIndex: audioStreamIndex,
        subtitleTrackId: subtitleTrackId,
      ),
    );
  }

  void _startTranscodePolling(
    String quality, {
    required int monitoringGeneration,
    String? mode,
    int? audioStreamIndex,
    String? subtitleTrackId,
  }) {
    if (!_isCurrentTranscodeMonitoring(monitoringGeneration)) return;
    if (_transcodePollTimer != null) return;
    _transcodePollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollTranscodeStatus(
        quality,
        monitoringGeneration: monitoringGeneration,
        mode: mode,
        audioStreamIndex: audioStreamIndex,
        subtitleTrackId: subtitleTrackId,
      ),
    );
  }

  Future<void> _pollTranscodeStatus(
    String quality, {
    required int monitoringGeneration,
    String? mode,
    int? audioStreamIndex,
    String? subtitleTrackId,
  }) async {
    if (!_isCurrentTranscodeMonitoring(monitoringGeneration) ||
        !_transcodeSessionActive ||
        _connectionLease?.isActive != true) {
      return;
    }
    final movieId = widget.movieId;
    if (movieId == null) return;
    try {
      final source = ref.read(ommMediaSourceProvider);
      if (source == null) return;
      final status = await source.transcodeStatus(
        _ommRef(movieId),
        quality: quality,
        mode: mode,
        audioStreamIndex: audioStreamIndex,
        subtitleTrackId: subtitleTrackId,
      );
      if (_isCurrentTranscodeMonitoring(monitoringGeneration)) {
        _applyTranscodeStatus(status);
      }
    } catch (_) {}
  }

  bool _isCurrentTranscodeMonitoring(int generation) {
    return mounted &&
        !_isLeaving &&
        generation == _transcodeMonitoringGeneration;
  }

  void _applyTranscodeStatus(playback_models.TranscodeStatus status) {
    if (!mounted || _isLeaving) return;
    // 查询不到会话时后端返回 quality 为空的 inactive 状态。此时保留播放
    // 决策或上一帧给出的真实服务端状态，不能把 HLS 误显示成本地硬解。
    if (!status.active && status.quality.trim().isEmpty) return;
    _updateViewState(() {
      _serverDecodeStatus = PlayerDecodeStatus.server(
        engine: status.hwAccel,
        hardwareDecodeOk: status.hwDecodeOk,
        isFallback: status.hasHardwareFallback,
      );
    });
  }
}
