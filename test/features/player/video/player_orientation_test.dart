import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omm/features/player/common/player_orientation.dart';
import 'package:omm/features/player/common/player_settings.dart';

void main() {
  group('player orientation mapping', () {
    test('Android keeps physical camera-side mapping', () {
      expect(
        playerLandscapeOrientationForPlatform(
          PlayerLandscapeSide.cameraLeft,
          platform: TargetPlatform.android,
        ),
        DeviceOrientation.landscapeLeft,
      );
      expect(
        playerLandscapeOrientationForPlatform(
          PlayerLandscapeSide.cameraRight,
          platform: TargetPlatform.android,
        ),
        DeviceOrientation.landscapeRight,
      );
    });

    test('iOS reverses the platform orientation enum', () {
      expect(
        playerLandscapeOrientationForPlatform(
          PlayerLandscapeSide.cameraLeft,
          platform: TargetPlatform.iOS,
        ),
        DeviceOrientation.landscapeRight,
      );
      expect(
        playerLandscapeOrientationForPlatform(
          PlayerLandscapeSide.cameraRight,
          platform: TargetPlatform.iOS,
        ),
        DeviceOrientation.landscapeLeft,
      );
    });
  });

  group('playerOrientationFromAccelerometer', () {
    test('recognizes both landscape sides and ignores portrait', () {
      expect(
        playerOrientationFromAccelerometer(
          0.2,
          -9.7,
          platform: TargetPlatform.android,
        ),
        isNull,
      );
      expect(
        playerOrientationFromAccelerometer(
          -9.7,
          0.2,
          platform: TargetPlatform.android,
        ),
        DeviceOrientation.landscapeLeft,
      );
      expect(
        playerOrientationFromAccelerometer(
          9.7,
          0.2,
          platform: TargetPlatform.android,
        ),
        DeviceOrientation.landscapeRight,
      );
    });

    test('ignores flat, diagonal, inverted and invalid readings', () {
      expect(
        playerOrientationFromAccelerometer(
          1,
          1,
          platform: TargetPlatform.android,
        ),
        isNull,
      );
      expect(
        playerOrientationFromAccelerometer(
          7,
          7,
          platform: TargetPlatform.android,
        ),
        isNull,
      );
      expect(
        playerOrientationFromAccelerometer(
          0,
          9.8,
          platform: TargetPlatform.android,
        ),
        isNull,
      );
      expect(
        playerOrientationFromAccelerometer(
          double.nan,
          0,
          platform: TargetPlatform.android,
        ),
        isNull,
      );
    });
  });
}
