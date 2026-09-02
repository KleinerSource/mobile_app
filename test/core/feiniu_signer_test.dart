import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/feiniu_signer.dart';

void main() {
  test('POST 签名与飞牛影视 Web 客户端一致且不修改请求体', () {
    final signer = FeiniuRequestSigner(
      apiKey: 'key',
      apiSecret: 'secret',
      nonceFactory: () => 'nonce-1',
      timestampFactory: () => 1700000000000,
    );

    final signed = signer.sign(
      method: 'post',
      pathname: '/v/api/v1/login',
      body: {'username': 'alice'},
    );
    final body = {'username': 'alice'};
    final digest = _md5(jsonEncode(body));
    final expectedSign = _md5(
      'key_/v/api/v1/login_nonce-1_1700000000000_${digest}_secret',
    );

    expect(signed.body, body);
    expect(
      signed.authx,
      'nonce=nonce-1&timestamp=1700000000000&sign=$expectedSign',
    );
  });

  test('GET 签名按 key 排序并进行 URL 编码', () {
    final signer = FeiniuRequestSigner(
      apiKey: 'key',
      apiSecret: 'secret',
      nonceFactory: () => 'nonce-2',
      timestampFactory: () => 1700000000001,
    );
    final signed = signer.sign(
      method: 'GET',
      pathname: '/v/api/v1/item/1',
      query: {'z': 'a b', 'skip': null, 'a': 'x/y'},
    );
    final query =
        'a=${Uri.encodeQueryComponent('x/y')}'
        '&z=${Uri.encodeQueryComponent('a b')}';
    final digest = _md5(query);
    final expectedSign = _md5(
      'key_/v/api/v1/item/1_nonce-2_1700000000001_${digest}_secret',
    );

    expect(signed.body, isNull);
    expect(
      signed.authx,
      'nonce=nonce-2&timestamp=1700000000001&sign=$expectedSign',
    );
  });
}

String _md5(String value) => md5.convert(utf8.encode(value)).toString();
