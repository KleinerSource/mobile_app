import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

const feiniuApiKey = 'NDzZTVxnRKP8Z0jXg1VAMonaG8akvh';
const feiniuApiSecret = '16CCEB3D-AB42-077D-36A1-F355324E4237';

typedef FeiniuNonceFactory = String Function();
typedef FeiniuTimestampFactory = int Function();

/// 飞牛影视 API 的 Authx 签名器。
///
/// 签名规则与飞牛影视 Web 客户端保持一致，基于最终发送的 body/query
/// 计算；nonce 和 timestamp 只放在 Authx 请求头中。
class FeiniuRequestSigner {
  FeiniuRequestSigner({
    this.apiKey = feiniuApiKey,
    this.apiSecret = feiniuApiSecret,
    FeiniuNonceFactory? nonceFactory,
    FeiniuTimestampFactory? timestampFactory,
  }) : _nonceFactory = nonceFactory ?? _defaultNonce,
       _timestampFactory = timestampFactory ?? _defaultTimestamp;

  final String apiKey;
  final String apiSecret;
  final FeiniuNonceFactory _nonceFactory;
  final FeiniuTimestampFactory _timestampFactory;

  FeiniuSignedRequest sign({
    required String method,
    required String pathname,
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) {
    final normalizedMethod = method.toUpperCase();
    final nonce = _nonceFactory();
    final timestamp = _timestampFactory();
    final finalBody = body;
    final payload = normalizedMethod == 'GET'
        ? _sortedQuery(query ?? const {})
        : finalBody == null
        ? ''
        : jsonEncode(finalBody);
    final digest = _md5(payload);
    final sign = _md5(
      '$apiKey'
      '_'
      '$pathname'
      '_'
      '$nonce'
      '_'
      '$timestamp'
      '_'
      '$digest'
      '_'
      '$apiSecret',
    );
    return FeiniuSignedRequest(
      nonce: nonce,
      timestamp: timestamp,
      authx: 'nonce=$nonce&timestamp=$timestamp&sign=$sign',
      body: finalBody,
    );
  }

  static String _sortedQuery(Map<String, dynamic> query) {
    final entries = <MapEntry<String, String>>[];
    for (final entry in query.entries) {
      final value = entry.value;
      if (value == null) continue;
      entries.add(MapEntry(entry.key, value.toString()));
    }
    entries.sort((a, b) => a.key.compareTo(b.key));
    return entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}='
              '${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
  }

  static String _md5(String value) =>
      md5.convert(utf8.encode(value)).toString().toLowerCase();
}

class FeiniuSignedRequest {
  const FeiniuSignedRequest({
    required this.nonce,
    required this.timestamp,
    required this.authx,
    required this.body,
  });

  final String nonce;
  final int timestamp;
  final String authx;
  final Map<String, dynamic>? body;
}

String _defaultNonce() {
  return (Random.secure().nextInt(900000) + 100000).toString();
}

int _defaultTimestamp() => DateTime.now().millisecondsSinceEpoch;
