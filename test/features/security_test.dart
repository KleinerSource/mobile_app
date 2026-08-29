// 合并自以下测试文件（测试内容保持不变，整合以减少每个文件的加载编译开销）。
//   - test/features/security_policy_test.dart
//   - test/features/security_biometric_coordinator_test.dart
//   - test/features/security_pin_pad_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/security/security_biometric_coordinator.dart';
import 'package:omm/features/security/security_pin_pad.dart';
import 'package:omm/features/security/security_policy.dart';

// ==================== 原 test/features/security_policy_test.dart ====================
void _main_0() {
  test('数字密码固定为 6 位数字', () {
    expect(isValidSecurityPin('12345'), isFalse);
    expect(isValidSecurityPin('123456'), isTrue);
    expect(isValidSecurityPin('1234567'), isFalse);
    expect(isValidSecurityPin('12a4'), isFalse);
  });

  test('手势密码至少包含四个不同节点且节点范围正确', () {
    expect(isValidSecurityPattern([0, 1, 2]), isFalse);
    expect(isValidSecurityPattern([0, 1, 2, 3]), isTrue);
    expect(isValidSecurityPattern([0, 1, 1, 3]), isFalse);
    expect(isValidSecurityPattern([0, 1, 2, 9]), isFalse);
  });

  test('凭据摘要不暴露原始值并且对同一输入稳定', () {
    final first = securitySecretDigest('1234');
    expect(first, isNot('1234'));
    expect(first, securitySecretDigest('1234'));
    expect(first, isNot(securitySecretDigest('1235')));
  });
}

// ==================== 原 test/features/security_biometric_coordinator_test.dart ====================
void _main_1() {
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

// ==================== 原 test/features/security_pin_pad_test.dart ====================
void _main_2() {
  testWidgets('解锁模式填满六位自动提交并清空输入', (tester) async {
    final submitted = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SecurityPinPad(
            onCompleted: (pin) async {
              submitted.add(pin);
            },
          ),
        ),
      ),
    );

    for (final digit in '123456'.split('')) {
      await tester.tap(find.text(digit));
    }
    await tester.pump();

    expect(submitted, ['123456']);
    expect(find.text('确认'), findsNothing);

    for (final digit in '654321'.split('')) {
      await tester.tap(find.text(digit));
    }
    await tester.pump();

    expect(submitted, ['123456', '654321']);
  });
}

void main() {
  group('security_policy', _main_0);
  group('security_biometric_coordinator', _main_1);
  group('security_pin_pad', _main_2);
}
