import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omm/features/player/common/player_orientation.dart';
import 'package:omm/features/player/common/player_settings.dart';

void main() {
  group('player orientation mapping', () {
    test('Android maps physical camera side to Flutter orientation', () {
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

    test('iOS reverses horizontal physical camera-side mapping', () {
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
    test('Android recognizes all four device orientations', () {
      expect(
        playerOrientationFromAccelerometer(
          9.7,
          0.2,
          platform: TargetPlatform.android,
        ),
        DeviceOrientation.landscapeLeft,
      );
      expect(
        playerOrientationFromAccelerometer(
          -9.7,
          0.2,
          platform: TargetPlatform.android,
        ),
        DeviceOrientation.landscapeRight,
      );
      expect(
        playerOrientationFromAccelerometer(
          0.2,
          9.7,
          platform: TargetPlatform.android,
        ),
        DeviceOrientation.portraitUp,
      );
      expect(
        playerOrientationFromAccelerometer(
          0.2,
          -9.7,
          platform: TargetPlatform.android,
        ),
        DeviceOrientation.portraitDown,
      );
    });

    test('iOS reverses only horizontal sensor targets', () {
      expect(
        playerOrientationFromAccelerometer(
          9.7,
          0.2,
          platform: TargetPlatform.iOS,
        ),
        DeviceOrientation.landscapeRight,
      );
      expect(
        playerOrientationFromAccelerometer(
          -9.7,
          0.2,
          platform: TargetPlatform.iOS,
        ),
        DeviceOrientation.landscapeLeft,
      );
      expect(
        playerOrientationFromAccelerometer(
          0.2,
          9.7,
          platform: TargetPlatform.iOS,
        ),
        DeviceOrientation.portraitUp,
      );
      expect(
        playerOrientationFromAccelerometer(
          0.2,
          -9.7,
          platform: TargetPlatform.iOS,
        ),
        DeviceOrientation.portraitDown,
      );
    });

    test('ignores flat, diagonal and invalid readings', () {
      expect(playerOrientationFromAccelerometer(1, 1), isNull);
      expect(playerOrientationFromAccelerometer(7, 7), isNull);
      expect(playerOrientationFromAccelerometer(0.2, 0.2), isNull);
      expect(playerOrientationFromAccelerometer(double.nan, 0), isNull);
    });
  });
}
