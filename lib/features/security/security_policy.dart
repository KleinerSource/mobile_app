import 'dart:convert';

import 'package:crypto/crypto.dart';

const securityPinMinLength = 6;
const securityPinMaxLength = 6;

/// 本地数字密码固定为 6 位 ASCII 数字。
bool isValidSecurityPin(String value) {
  return RegExp(r'^\d{6}$').hasMatch(value);
}

/// 手势图案使用 0–8 表示 3×3 网格，至少连接四个不同节点。
bool isValidSecurityPattern(Iterable<int> pattern) {
  final values = pattern.toList(growable: false);
  return values.length >= 4 &&
      values.every((value) => value >= 0 && value <= 8) &&
      values.toSet().length == values.length;
}

String encodeSecurityPattern(Iterable<int> pattern) => pattern.join(',');

/// 凭据摘要用于比对，不将 PIN 或完整手势写入持久化存储。
String securitySecretDigest(String value) {
  return sha256.convert(utf8.encode(value)).toString();
}
