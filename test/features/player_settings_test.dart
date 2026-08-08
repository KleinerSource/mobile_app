import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:md_center/features/player/player_settings.dart';

void main() {
  test('播放器设置默认值保持现有播放行为', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = PlayerSettingsRepository(prefs).load();

    expect(settings.resumeFromLastPosition, isTrue);
    expect(settings.entryOrientation, PlayerEntryOrientation.forceLandscape);
    expect(settings.doubleTapCenter, isTrue);
    expect(settings.doubleTapEdges, isTrue);
    expect(settings.hapticLongPress, isTrue);
    expect(settings.hapticSeek, isTrue);
    expect(settings.hapticRate, isTrue);
    expect(settings.hapticProgressBar, isTrue);
  });

  test('播放器设置可以持久化并恢复', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = PlayerSettingsRepository(prefs);
    const expected = PlayerSettings(
      resumeFromLastPosition: false,
      landscapeSide: PlayerLandscapeSide.cameraRight,
      entryOrientation: PlayerEntryOrientation.forcePortrait,
      doubleTapCenter: false,
      doubleTapEdges: true,
      hapticLongPress: false,
      hapticSeek: false,
      hapticRate: true,
      hapticProgressBar: false,
    );

    await repository.save(expected);
    final actual = repository.load();

    expect(actual.resumeFromLastPosition, isFalse);
    expect(actual.landscapeSide, PlayerLandscapeSide.cameraRight);
    expect(actual.entryOrientation, PlayerEntryOrientation.forcePortrait);
    expect(actual.doubleTapCenter, isFalse);
    expect(actual.doubleTapEdges, isTrue);
    expect(actual.hapticLongPress, isFalse);
    expect(actual.hapticSeek, isFalse);
    expect(actual.hapticRate, isTrue);
    expect(actual.hapticProgressBar, isFalse);
  });
}
