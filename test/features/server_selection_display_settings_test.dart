import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_profile_runtime_loader.dart';
import 'package:omm/core/models/system.dart';
import 'package:omm/features/home/server_switcher.dart';

void main() {

  test('用户头像地址仅保留在运行时资料，不写入资料缓存 JSON', () {
    const profile = ServerProfileData(
      name: 'Alice',
      avatarUrl: 'https://server.example/logo.png',
      userAvatarUrl:
          'https://server.example/Users/alice/Images/Primary?ApiKey=secret',
    );

    expect(profile.toJson(), {
      'name': 'Alice',
      'avatar_url': 'https://server.example/logo.png',
    });
  });

  test('首页右上角仅在开启时使用 Emby/Jellyfin 用户头像', () {
    const line = ServerLine(
      id: 'jellyfin-line',
      name: '主线路',
      baseUrl: 'https://jellyfin.example',
    );
    const jellyfin = ServerProfile(
      id: 'jellyfin',
      name: '家庭影音',
      lines: [line],
      projectName: 'jellyfin',
      avatarUrl: 'https://jellyfin.example/logo.png',
    );
    const profile = ServerProfileData(
      name: 'Alice',
      avatarUrl: 'https://jellyfin.example/logo.png',
      userAvatarUrl: 'https://jellyfin.example/user.png',
    );

    expect(
      homeServerSwitcherAvatarUrl(
        server: jellyfin,
        profile: profile,
        showUserAvatar: true,
      ),
      'https://jellyfin.example/user.png',
    );
    expect(
      homeServerSwitcherAvatarUrl(
        server: jellyfin,
        profile: profile,
        showUserAvatar: false,
      ),
      'https://jellyfin.example/logo.png',
    );
    expect(
      homeServerSwitcherAvatarUrl(
        server: jellyfin,
        profile: const ServerProfileData(
          name: 'Alice',
          avatarUrl: 'https://jellyfin.example/logo.png',
        ),
        showUserAvatar: true,
      ),
      'https://jellyfin.example/logo.png',
    );

    const omm = ServerProfile(
      id: 'omm',
      name: 'OMM',
      lines: [line],
      projectName: 'oh-my-media',
      avatarUrl: 'https://omm.example/logo.png',
    );
    expect(
      homeServerSwitcherAvatarUrl(
        server: omm,
        profile: const ServerProfileData(
          name: 'OMM',
          avatarUrl: 'https://omm.example/logo.png',
          userAvatarUrl: 'https://omm.example/user.png',
        ),
        showUserAvatar: true,
      ),
      isNull,
    );
  });

  test('连接页切换动画与服务器选择页共用用户名显示开关', () {
    const line = ServerLine(
      id: 'jellyfin-line',
      name: '主线路',
      baseUrl: 'https://jellyfin.example',
    );
    const server = ServerProfile(
      id: 'jellyfin',
      name: '家庭影音',
      lines: [line],
      projectName: 'jellyfin',
    );
    const profile = ServerProfileData(name: 'Alice');

    expect(
      serverSelectionDisplayName(server, profile, showUsername: true),
      'Alice',
    );
    expect(
      serverSelectionDisplayName(server, profile, showUsername: false),
      '家庭影音',
    );
  });

}
