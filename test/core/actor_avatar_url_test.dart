import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/models/actor.dart';
import 'package:omm/shared/actor_avatar.dart';

void main() {
  test('演员头像地址保留反向代理前缀并使用公开接口', () {
    const config = ServerConfig(baseUrl: 'https://media.example/oh-my-media');

    expect(
      actorAvatarUrl(config, 42),
      'https://media.example/oh-my-media/api/actors/42/avatar',
    );
  });

  test('演员头像刷新参数会追加到地址而不丢失反向代理前缀', () {
    const config = ServerConfig(baseUrl: 'https://media.example/oh-my-media');

    expect(
      actorAvatarUrl(config, 42, cacheBust: '123'),
      'https://media.example/oh-my-media/api/actors/42/avatar?v=123',
    );
  });

  test('轮播索引会追加到头像地址,首页不携带 index 参数', () {
    const config = ServerConfig(baseUrl: 'https://media.example/oh-my-media');

    expect(
      actorAvatarUrl(config, 42, index: 2),
      'https://media.example/oh-my-media/api/actors/42/avatar?index=2',
    );
    expect(
      actorAvatarUrl(config, 42, index: 0),
      'https://media.example/oh-my-media/api/actors/42/avatar',
    );
    expect(
      actorAvatarUrl(config, 42, cacheBust: '9', index: 3),
      'https://media.example/oh-my-media/api/actors/42/avatar?index=3&v=9',
    );
  });

  test('演员模型读取后端返回的头像路径数组', () {
    final actor = ActorItem.fromJson(const {
      'id': 42,
      'name': '测试演员',
      'avatar_path': [
        'data/people/测试演员/avatar.jpg',
        'data/people/测试演员/avatar 2.jpg',
      ],
    });

    expect(actor.avatarPaths, [
      'data/people/测试演员/avatar.jpg',
      'data/people/测试演员/avatar 2.jpg',
    ]);
  });

  test('后端返回空数组或缺失时模型解析不崩溃', () {
    final empty = ActorItem.fromJson(const {
      'id': 1,
      'name': 'A',
      'avatar_path': <String>[],
    });
    expect(empty.avatarPaths, isEmpty);

    final missing = ActorItem.fromJson(const {'id': 2, 'name': 'B'});
    expect(missing.avatarPaths, isNull);
  });
}
