part of 'video_player_page.dart';

// 状态及资源所有权保留在页面；此扩展只组织同一职责的方法。
extension _VideoPlayerDevice on _VideoPlayerPageState {
  Future<void> _applyEntryOrientation(PlayerSettings settings) async {
    final orientations = switch (settings.entryOrientation) {
      PlayerEntryOrientation.unchanged => null,
      PlayerEntryOrientation.forceLandscape => [
        _landscapeOrientation(settings.landscapeSide),
      ],
      PlayerEntryOrientation.forcePortrait =>
        _VideoPlayerPageState._portraitOrientations,
    };
    if (orientations == null) return;
    await SystemChrome.setPreferredOrientations(orientations);
  }

  void _startOrientationSensor() {
    if (_orientationSensorSubscription != null ||
        kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS) ||
        !_orientationSensorUnlocked ||
        _isLeaving) {
      return;
    }
    _orientationSensorCandidate = null;
    _orientationSensorCandidateSamples = 0;
    _orientationSensorSubscription =
        accelerometerEventStream(
          samplingPeriod: const Duration(milliseconds: 100),
        ).listen(
          _onOrientationSensorEvent,
          onError: (_) {
            _orientationSensorSubscription = null;
          },
        );
  }

  void _stopOrientationSensor() {
    _orientationSensorRequestGeneration++;
    final subscription = _orientationSensorSubscription;
    _orientationSensorSubscription = null;
    _orientationSensorCandidate = null;
    _orientationSensorCandidateSamples = 0;
    _orientationSensorApplied = null;
    _pendingOrientationSensorTarget = null;
    _orientationSensorLastAppliedAt = null;
    if (subscription != null) unawaited(subscription.cancel());
  }

  void _onOrientationSensorEvent(AccelerometerEvent event) {
    if (_isLeaving || !mounted || !_orientationSensorUnlocked) {
      _orientationSensorCandidate = null;
      _orientationSensorCandidateSamples = 0;
      return;
    }
    final target = playerOrientationFromAccelerometer(event.x, event.y);
    if (target == null) {
      _orientationSensorCandidate = null;
      _orientationSensorCandidateSamples = 0;
      return;
    }
    if (_orientationSensorCandidate != target) {
      _orientationSensorCandidate = target;
      _orientationSensorCandidateSamples = 1;
      return;
    }
    _orientationSensorCandidateSamples++;
    if (_orientationSensorCandidateSamples <
        _VideoPlayerPageState._orientationSensorSampleCount) {
      return;
    }
    _orientationSensorCandidate = null;
    _orientationSensorCandidateSamples = 0;
    if (_orientationSensorApplied == target) return;
    final now = DateTime.now();
    final lastAppliedAt = _orientationSensorLastAppliedAt;
    if (lastAppliedAt != null &&
        now.difference(lastAppliedAt) <
            _VideoPlayerPageState._orientationSensorCooldown) {
      return;
    }
    _orientationSensorLastAppliedAt = now;
    _pendingOrientationSensorTarget = target;
    _orientationSensorRequestGeneration++;
    if (_orientationSensorRequestInFlight) return;
    _orientationSensorRequestInFlight = true;
    unawaited(_drainOrientationSensorRequests());
  }

  Future<void> _drainOrientationSensorRequests() async {
    while (!_isLeaving) {
      final target = _pendingOrientationSensorTarget;
      _pendingOrientationSensorTarget = null;
      if (target == null) break;
      final requestGeneration = _orientationSensorRequestGeneration;
      try {
        await SystemChrome.setPreferredOrientations([target]);
        if (!mounted || _isLeaving || !_orientationSensorUnlocked) {
          _pendingOrientationSensorTarget = null;
          break;
        }
        if (requestGeneration != _orientationSensorRequestGeneration) {
          continue;
        }
        _orientationSensorApplied = target;
        _updateViewState(() {
          _isLandscape =
              target == DeviceOrientation.landscapeLeft ||
              target == DeviceOrientation.landscapeRight;
        });
      } catch (_) {}
    }
    _orientationSensorRequestInFlight = false;
  }

  Future<void> _initLevels() async {
    // 只读一次当前亮度作为手势增量基线，不保存、不恢复：
    // 退出播放器或 app 时亮度保持最后状态，任何阶段都不回写其他值。
    await _queueBrightnessOperation(() async {
      final currentBrightness = await ScreenBrightnessChannel.read();
      if (currentBrightness != null && !_isLeaving) {
        _brightness = currentBrightness;
      }
      _brightnessReady = true;
    });
    try {
      _volume = await FlutterVolumeController.getVolume() ?? 0.5;
    } catch (_) {}
  }

  Future<void> _queueBrightnessOperation(Future<void> Function() operation) {
    final next = _brightnessOperations.then<void>((_) async {
      try {
        await operation();
      } catch (_) {}
    });
    _brightnessOperations = next;
    return next;
  }

  void _startDeviceStatsPolling() {
    unawaited(_refreshDeviceStats());
    _deviceStatsTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_refreshDeviceStats()),
    );
  }

  Future<void> _refreshDeviceStats() async {
    if (_isLeaving) return;
    final settings = ref.read(playerSettingsProvider);
    if (!settings.showNetworkSpeed &&
        !settings.showCpuUsage &&
        !settings.showBattery) {
      return;
    }
    final stats = await _deviceStatsReader.read();
    if (!mounted || _isLeaving) return;
    _updateViewState(() => _deviceStats = stats);
  }
}
