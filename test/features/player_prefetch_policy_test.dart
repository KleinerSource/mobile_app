import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/features/player/player_prefetch_policy.dart';

void main() {
  test('预载上限为影片总时长的 15%', () {
    expect(
      playerPrefetchSecondsFor(const Duration(minutes: 100)),
      closeTo(900, 0.001),
    );
  });

  test('时长未知时使用安全的初始预载值', () {
    expect(
      playerPrefetchSecondsFor(Duration.zero),
      playerInitialPrefetchSeconds,
    );
  });

  test('起播缓存等待按预载目标设置且限制最长等待时间', () {
    expect(playerInitialCacheWaitSecondsFor(12), 12);
    expect(
      playerInitialCacheWaitSecondsFor(900),
      playerMaxInitialCacheWaitSeconds,
    );
    expect(playerInitialCacheWaitSecondsFor(0), playerInitialPrefetchSeconds);
  });
}
