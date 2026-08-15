import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:md_center/features/player/player_settings.dart';

void main() {
  test('播放器设置默认值保持现有播放行为', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = PlayerSettingsRepository(prefs).load();

    expect(settings.kernel, PlayerKernel.mediaKit);
    expect(settings.resumeFromLastPosition, isTrue);
    expect(settings.landscapeSide, PlayerLandscapeSide.cameraRight);
    expect(settings.entryOrientation, PlayerEntryOrientation.forceLandscape);
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

  test('播放器内核未知值回退为 media_kit', () async {
    SharedPreferences.setMockInitialValues({
      'player.kernel': 'unsupported',
    });
    final prefs = await SharedPreferences.getInstance();

    expect(
      PlayerSettingsRepository(prefs).load().kernel,
      PlayerKernel.mediaKit,
    );
    expect(PlayerKernel.fromValue('ksplayer'), PlayerKernel.ksPlayer);
  });

  test('播放器设置可以持久化并恢复', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = PlayerSettingsRepository(prefs);
    const expected = PlayerSettings(
      kernel: PlayerKernel.ksPlayer,
      resumeFromLastPosition: false,
      landscapeSide: PlayerLandscapeSide.cameraRight,
      entryOrientation: PlayerEntryOrientation.forcePortrait,
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

    expect(actual.kernel, PlayerKernel.ksPlayer);
    expect(actual.resumeFromLastPosition, isFalse);
    expect(actual.landscapeSide, PlayerLandscapeSide.cameraRight);
    expect(actual.entryOrientation, PlayerEntryOrientation.forcePortrait);
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
