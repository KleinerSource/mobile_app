import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/models/system.dart';

void main() {
  test('服务器资料模型保留名称和头像地址', () {
    const profile = ServerProfileData(
      name: '客厅服务器',
      avatarUrl: 'http://192.168.1.10:8001/api/public/avatar',
    );

    expect(profile.name, '客厅服务器');
    expect(profile.avatarUrl, contains('/public/avatar'));
  });
}
