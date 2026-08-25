import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/security/security_policy.dart';

void main() {
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
