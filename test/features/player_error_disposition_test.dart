import 'package:flutter_test/flutter_test.dart';

import 'package:omm/features/player/player_error_disposition.dart';

void main() {
  final now = DateTime(2026, 1, 1, 12);

  test('字幕加载窗口内且主媒体已装载时降级为字幕提示', () {
    final disposition = classifyPlayerError(
      subtitleGuardUntil: now.add(const Duration(seconds: 5)),
      now: now,
      mainMediaLoaded: true,
    );
    expect(disposition, PlayerErrorDisposition.subtitleWarning);
  });

  test('字幕窗口已过期时保持致命错误', () {
    final disposition = classifyPlayerError(
      subtitleGuardUntil: now.subtract(const Duration(seconds: 1)),
      now: now,
      mainMediaLoaded: true,
    );
    expect(disposition, PlayerErrorDisposition.fatal);
  });

  test('从未发起字幕加载时保持致命错误', () {
    final disposition = classifyPlayerError(
      subtitleGuardUntil: null,
      now: now,
      mainMediaLoaded: true,
    );
    expect(disposition, PlayerErrorDisposition.fatal);
  });

  test('主媒体未装载时报错仍然致命（字幕窗口内也可能是主媒体打开失败）', () {
    final disposition = classifyPlayerError(
      subtitleGuardUntil: now.add(const Duration(seconds: 5)),
      now: now,
      mainMediaLoaded: false,
    );
    expect(disposition, PlayerErrorDisposition.fatal);
  });

  test('窗口边界：恰好到期不再降级', () {
    final until = now.add(const Duration(seconds: 15));
    expect(
      classifyPlayerError(
        subtitleGuardUntil: until,
        now: until.subtract(const Duration(milliseconds: 1)),
        mainMediaLoaded: true,
      ),
      PlayerErrorDisposition.subtitleWarning,
    );
    expect(
      classifyPlayerError(
        subtitleGuardUntil: until,
        now: until,
        mainMediaLoaded: true,
      ),
      PlayerErrorDisposition.fatal,
    );
  });
}
