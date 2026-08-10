import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/features/security/security_biometric_coordinator.dart';

void main() {
  test('启用生物识别的系统页返回不会再次触发应用锁', () {
    final coordinator = SecurityBiometricCoordinator();

    expect(coordinator.isAuthenticationInFlight, isFalse);
    coordinator.beginAuthentication();
    expect(coordinator.isAuthenticationInFlight, isTrue);
    coordinator.didEnterInactive();
    expect(coordinator.consumeResume(), isTrue);
    coordinator.endAuthentication();
    expect(coordinator.isAuthenticationInFlight, isFalse);
    expect(coordinator.consumeResume(), isFalse);
  });

  test('验证完成后才收到 resumed 也只消费一次', () {
    final coordinator = SecurityBiometricCoordinator();

    coordinator.beginAuthentication();
    coordinator.didEnterInactive();
    coordinator.endAuthentication();
    expect(coordinator.consumeResume(), isTrue);
    expect(coordinator.consumeResume(), isFalse);
  });

  test('没有生命周期切换时不会吞掉下一次真实回前台', () {
    final coordinator = SecurityBiometricCoordinator();

    coordinator.beginAuthentication();
    coordinator.endAuthentication();
    expect(coordinator.consumeResume(), isFalse);
  });

  test('设备锁屏解锁只消费设备锁周期，不触发应用锁', () {
    final coordinator = SecurityBiometricCoordinator();

    coordinator.didLockDevice();
    expect(coordinator.isDeviceLocked, isTrue);
    expect(coordinator.hasDeviceLockCycle, isTrue);
    coordinator.didUnlockDevice();
    expect(coordinator.isDeviceLocked, isFalse);
    expect(coordinator.consumeDeviceLockResume(), isTrue);
    expect(coordinator.consumeDeviceLockResume(), isFalse);
  });

  test('进程内完成验证后，生命周期切换不会清除会话验证状态', () {
    final coordinator = SecurityBiometricCoordinator();

    expect(coordinator.isSessionAuthenticated, isFalse);
    coordinator.markSessionAuthenticated();
    coordinator.didEnterInactive();

    expect(coordinator.isSessionAuthenticated, isTrue);
  });
}
