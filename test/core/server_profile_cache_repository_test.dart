import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/config/server_profile_cache_repository.dart';
import 'package:md_center/core/models/system.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('服务器资料可以持久化并按服务器隔离', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ServerProfileCacheRepository(prefs);
    const home = ServerProfileData(
      name: '家庭服务器',
      avatarUrl: 'https://home.example/api/public/avatar',
    );
    const remote = ServerProfileData(name: '公网服务器');

    await repository.save('home', home);
    await repository.save('remote', remote);

    expect(repository.load('home')?.name, '家庭服务器');
    expect(repository.load('home')?.avatarUrl, home.avatarUrl);
    expect(repository.load('remote')?.name, remote.name);
    expect(repository.load('remote')?.avatarUrl, remote.avatarUrl);
    expect(repository.load('missing'), isNull);
  });

  test('可以删除单台服务器资料并清空全部缓存', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ServerProfileCacheRepository(prefs);
    const profile = ServerProfileData(name: '服务器');

    await repository.save('home', profile);
    await repository.save('remote', profile);
    await repository.remove('home');

    expect(repository.load('home'), isNull);
    expect(repository.load('remote')?.name, profile.name);

    await repository.clear();
    expect(repository.load('remote'), isNull);
  });
}
