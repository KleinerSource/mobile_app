const playerPrefetchRatio = 0.15;
const playerInitialPrefetchSeconds = 1.0;

double playerPrefetchSecondsFor(Duration duration) {
  final totalSeconds = duration.inMilliseconds / Duration.millisecondsPerSecond;
  if (totalSeconds <= 0) return playerInitialPrefetchSeconds;
  return totalSeconds * playerPrefetchRatio;
}
