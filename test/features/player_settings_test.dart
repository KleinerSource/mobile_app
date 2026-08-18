import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:md_center/features/player/player_settings.dart';

void main() {
  test('播放器设置默认值保持现有播放行为', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = PlayerSettingsRepository(prefs).load();

    expect(settings.resumeFromLastPosition, isTrue);
    expect(settings.landscapeSide, PlayerLandscapeSide.cameraRight);
    expect(settings.entryOrientation, PlayerEntryOrientation.forceLandscape);
    expect(settings.preloadSize, PlayerPreloadSize.mb250);
    expect(settings.doubleTapCenter, isTrue);
    expect(settings.doubleTapEdges, isTrue);
    expect(settings.hapticLongPress, isTrue);
    expect(settings.hapticSeek, isTrue);
    expect(settings.hapticRate, isTrue);
    expect(settings.hapticProgressBar, isTrue);
    expect(settings.showSystemTime, isTrue);
    expect(settings.showNetworkSpeed, isTrue);
    expect(settings.showCpuUsage, isTrue);
    expect(settings.showBattery, isTrue);
    expect(settings.showPlayPauseButton, isTrue);
    expect(settings.showSeekButtons, isTrue);
    expect(settings.showSpeedButton, isTrue);
    expect(settings.showPipButton, isTrue);
    expect(settings.showOrientationButton, isTrue);
    expect(settings.showMediaSwitchButton, isTrue);
  });

  test('设备横屏方向未知值回退为摄像头在右侧', () async {
    expect(
      const PlayerSettings().landscapeSide,
      PlayerLandscapeSide.cameraRight,
    );
    expect(
      PlayerLandscapeSide.fromValue(null),
      PlayerLandscapeSide.cameraRight,
    );
    SharedPreferences.setMockInitialValues({
      'player.landscape_side': 'unsupported',
    });
    final prefs = await SharedPreferences.getInstance();

    expect(
      PlayerSettingsRepository(prefs).load().landscapeSide,
      PlayerLandscapeSide.cameraRight,
    );
  });

  test('预载档位提供四个内存选项且未知值回退默认', () {
    expect(PlayerPreloadSize.values, hasLength(4));
    expect(PlayerPreloadSize.mb250.bytes, 250 * 1024 * 1024);
    expect(PlayerPreloadSize.mb500.bytes, 500 * 1024 * 1024);
    expect(PlayerPreloadSize.mb750.bytes, 750 * 1024 * 1024);
    expect(PlayerPreloadSize.gb1.bytes, 1024 * 1024 * 1024);
    expect(PlayerPreloadSize.gb1.label, '1GB');
    expect(PlayerPreloadSize.fromValue('500mb'), PlayerPreloadSize.mb500);
    expect(PlayerPreloadSize.fromValue(null), PlayerPreloadSize.mb250);
    expect(PlayerPreloadSize.fromValue('unsupported'), PlayerPreloadSize.mb250);
  });

  test('预载档位可以持久化并恢复', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = PlayerSettingsRepository(prefs);

    await repository.save(
      const PlayerSettings(preloadSize: PlayerPreloadSize.gb1),
    );
    expect(repository.load().preloadSize, PlayerPreloadSize.gb1);

    SharedPreferences.setMockInitialValues({'player.preload_size': '750mb'});
    final restored = await SharedPreferences.getInstance();
    expect(
      PlayerSettingsRepository(restored).load().preloadSize,
      PlayerPreloadSize.mb750,
    );
  });

  test('播放器设置可以持久化并恢复', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = PlayerSettingsRepository(prefs);
    const expected = PlayerSettings(
      resumeFromLastPosition: false,
      landscapeSide: PlayerLandscapeSide.cameraRight,
      entryOrientation: PlayerEntryOrientation.forcePortrait,
      preloadSize: PlayerPreloadSize.mb500,
      doubleTapCenter: false,
      doubleTapEdges: true,
      hapticLongPress: false,
      hapticSeek: false,
      hapticRate: true,
      hapticProgressBar: false,
      showSystemTime: false,
      showNetworkSpeed: false,
      showCpuUsage: true,
      showBattery: false,
      showPlayPauseButton: false,
      showSeekButtons: false,
      showSpeedButton: true,
      showPipButton: false,
      showOrientationButton: false,
      showMediaSwitchButton: true,
    );

    await repository.save(expected);
    final actual = repository.load();

    expect(actual.resumeFromLastPosition, isFalse);
    expect(actual.landscapeSide, PlayerLandscapeSide.cameraRight);
    expect(actual.entryOrientation, PlayerEntryOrientation.forcePortrait);
    expect(actual.preloadSize, PlayerPreloadSize.mb500);
    expect(actual.doubleTapCenter, isFalse);
    expect(actual.doubleTapEdges, isTrue);
    expect(actual.hapticLongPress, isFalse);
    expect(actual.hapticSeek, isFalse);
    expect(actual.hapticRate, isTrue);
    expect(actual.hapticProgressBar, isFalse);
    expect(actual.showSystemTime, isFalse);
    expect(actual.showNetworkSpeed, isFalse);
    expect(actual.showCpuUsage, isTrue);
    expect(actual.showBattery, isFalse);
    expect(actual.showPlayPauseButton, isFalse);
    expect(actual.showSeekButtons, isFalse);
    expect(actual.showSpeedButton, isTrue);
    expect(actual.showPipButton, isFalse);
    expect(actual.showOrientationButton, isFalse);
    expect(actual.showMediaSwitchButton, isTrue);
  });
}
