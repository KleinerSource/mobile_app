import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// TOTP 验证码长度（标准 6 位）与周期（RFC 6238 默认 30 秒）。
const totpDigits = 6;
const totpPeriodSeconds = 30;
const _totpModulo = 1000000; // 10^totpDigits

/// 归一化 TOTP 密钥：去空格/连字符、转大写，并校验是可解码的 base32。
///
/// 返回归一化后的密钥；不是合法 base32 或解码后不足 10 字节（80 位，
/// 常见部署最小长度）时返回 null。
String? normalizeTotpSecret(String raw) {
  final normalized = raw.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
  if (normalized.isEmpty) return null;
  final decoded = _base32Decode(normalized);
  if (decoded == null || decoded.length < 10) return null;
  return normalized;
}

/// 按当前时间（或指定 [now]）从 base32 密钥生成 RFC 6238 验证码。
///
/// 密钥非法或解码失败时返回 null，由调用方决定报错或忽略。
String? tryGenerateTotpCode(String base32Secret, {DateTime? now}) {
  final normalized = base32Secret.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
  final keyBytes = _base32Decode(normalized);
  if (keyBytes == null || keyBytes.isEmpty) return null;

  final timestamp = ((now ?? DateTime.now()).millisecondsSinceEpoch / 1000)
      .floor();
  final counter = timestamp ~/ totpPeriodSeconds;
  final counterBytes = ByteData(8)..setUint64(0, counter);
  final digest = Hmac(sha1, keyBytes).convert(counterBytes.buffer.asUint8List());

  // RFC 4226 动态截断：取最后一个字节的低 4 位作偏移，再取 4 字节并去掉
  // 最高位，对 10^digits 取模后补零。
  final bytes = digest.bytes;
  final offset = bytes[bytes.length - 1] & 0x0f;
  final binary =
      ((bytes[offset] & 0x7f) << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
  final code = binary % _totpModulo;
  return code.toString().padLeft(totpDigits, '0');
}

const _base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

/// RFC 4648 base32 解码（输入须已去空白字符；padding 可有可无）。
///
/// 不足 8 字符的分组按比特数截断解码，与多数验证器行为一致。
Uint8List? _base32Decode(String input) {
  final text = input.replaceAll('=', '');
  if (text.isEmpty || text.length % 8 == 1) return null;
  var buffer = 0;
  var bits = 0;
  final data = <int>[];
  for (final char in text.split('')) {
    final value = _base32Alphabet.indexOf(char);
    if (value < 0) return null;
    buffer = (buffer << 5) | value;
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      data.add((buffer >> bits) & 0xff);
    }
  }
  return Uint8List.fromList(data);
}
