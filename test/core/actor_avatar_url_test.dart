import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/config/server_config.dart';
import 'package:md_center/core/models/actor.dart';
import 'package:md_center/shared/actor_avatar.dart';

void main() {
  test('演员头像地址保留反向代理前缀并使用公开接口', () {
    const config = ServerConfig(baseUrl: 'https://media.example/md-center');

    expect(
      actorAvatarUrl(config, 42),
      'https://media.example/md-center/api/actors/42/avatar',
    );
  });

  test('演员头像刷新参数会追加到地址而不丢失反向代理前缀', () {
    const config = ServerConfig(baseUrl: 'https://media.example/md-center');

    expect(
      actorAvatarUrl(config, 42, cacheBust: '123'),
      'https://media.example/md-center/api/actors/42/avatar?v=123',
    );
  });

  test('演员模型读取后端返回的头像路径', () {
    final actor = ActorItem.fromJson(const {
      'id': 42,
      'name': '测试演员',
      'avatar_path': 'data/people/测试演员/avatar.jpg',
    });

    expect(actor.avatarPath, 'data/people/测试演员/avatar.jpg');
  });
}
