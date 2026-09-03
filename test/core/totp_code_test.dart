import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/auth/totp_code.dart';

void main() {
  // RFC 6238 Appendix B 的 SHA-1 测试密钥 "12345678901234567890" 的
  // base32 编码；向量按 8 位截断后取末 6 位。
  const secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

  DateTime atSeconds(int seconds) =>
      DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

  test('RFC 6238 标准时间向量生成 6 位验证码', () {
    expect(
      tryGenerateTotpCode(secret, now: atSeconds(59)),
      '287082',
    );
    expect(
      tryGenerateTotpCode(secret, now: atSeconds(1111111109)),
      '081804',
    );
    expect(
      tryGenerateTotpCode(secret, now: atSeconds(1234567890)),
      '005924',
    );
    expect(
      tryGenerateTotpCode(secret, now: atSeconds(2000000000)),
      '279037',
    );
  });

  test('密钥中的空格、连字符、小写和 padding 被容忍', () {
    final spaced = 'gezd gnbv-gy3t qojq gezd gnbv gy3t qojq=';
    expect(
      tryGenerateTotpCode(spaced, now: atSeconds(59)),
      tryGenerateTotpCode(secret, now: atSeconds(59)),
    );
  });

  test('非法密钥返回 null', () {
    expect(tryGenerateTotpCode('', now: atSeconds(59)), isNull);
    expect(tryGenerateTotpCode('ABC!DEF', now: atSeconds(59)), isNull);
    expect(tryGenerateTotpCode('12345', now: atSeconds(59)), isNull);
  });

  test('normalizeTotpSecret 归一化并校验长度', () {
    expect(normalizeTotpSecret(' gezd gnbv gy3tqojq '), 'GEZDGNBVGY3TQOJQ');
    // 解码后不足 10 字节（80 位）的密钥不予接受；16 字符恰好 10 字节。
    expect(normalizeTotpSecret('GEZDGNBVGY3TQOJ'), isNull);
    expect(normalizeTotpSecret(''), isNull);
    expect(normalizeTotpSecret('GEZDGNBVGY3TQ0JQ!'), isNull);
  });
}
