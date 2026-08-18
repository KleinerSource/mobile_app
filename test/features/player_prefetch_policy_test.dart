import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/features/player/player_prefetch_policy.dart';

void main() {
  test('预读上限为影片总时长的 15%', () {
    expect(
      playerPrefetchSecondsFor(const Duration(minutes: 100)),
      closeTo(900, 0.001),
    );
  });

  test('时长未知时使用安全的初始预读值', () {
    expect(
      playerPrefetchSecondsFor(Duration.zero),
      playerInitialPrefetchSeconds,
    );
  });
}
