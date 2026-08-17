const playerPrefetchRatio = 0.15;
const playerInitialPrefetchSeconds = 1.0;
const playerMaxInitialCacheWaitSeconds = 30.0;

double playerPrefetchSecondsFor(Duration duration) {
  final totalSeconds = duration.inMilliseconds / Duration.millisecondsPerSecond;
  if (totalSeconds <= 0) return playerInitialPrefetchSeconds;
  return totalSeconds * playerPrefetchRatio;
}

/// 初始缓存等待不能无限随影片时长增长，否则长视频会让打开页面阻塞数分钟。
/// 预载上限仍然由 [playerPrefetchSecondsFor] 控制，这里只限制起播前等待时间。
double playerInitialCacheWaitSecondsFor(double prefetchSeconds) {
  if (!prefetchSeconds.isFinite || prefetchSeconds <= 0) {
    return playerInitialPrefetchSeconds;
  }
  return prefetchSeconds > playerMaxInitialCacheWaitSeconds
      ? playerMaxInitialCacheWaitSeconds
      : prefetchSeconds;
}
