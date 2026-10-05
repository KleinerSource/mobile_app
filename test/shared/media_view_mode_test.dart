import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/shared/media_view_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('视图模式按服务器隔离并迁移旧版页面级键', () async {
    SharedPreferences.setMockInitialValues({
      'movies.view_mode.v1': 'list',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    final runtime = container.read(serverRuntimeProvider.notifier);

    // 服务器 A：首次读取迁移旧版页面级键 list 并固化到自己的键。
    runtime.commit(ServerRuntimeLane.media, 'srv-a');
    expect(container.read(mediaServerViewModeProvider), MediaViewMode.list);
    await pumpEventQueue();
    expect(
      prefs.getString(mediaServerViewModeStorageKey('srv-a')),
      'list',
    );

    // 服务器 B：无自有键，首次访问同样继承旧版键；切换只写入 B 的键。
    runtime.commit(ServerRuntimeLane.media, 'srv-b');
    expect(container.read(mediaServerViewModeProvider), MediaViewMode.list);
    container
        .read(mediaServerViewModeProvider.notifier)
        .set(MediaViewMode.landscape);
    expect(
      prefs.getString(mediaServerViewModeStorageKey('srv-b')),
      'landscape',
    );

    // 切回 A：仍保持迁移得到的列表模式，不被 B 的切换影响。
    runtime.commit(ServerRuntimeLane.media, 'srv-a');
    expect(container.read(mediaServerViewModeProvider), MediaViewMode.list);
    expect(
      prefs.getString(mediaServerViewModeStorageKey('srv-b')),
      'landscape',
    );
  });

  test('旧版 grid 值迁移为竖屏网格', () async {
    SharedPreferences.setMockInitialValues({
      'favorites.view_mode.v1': 'grid',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(mediaServerViewModeProvider), MediaViewMode.portrait);
    await pumpEventQueue();
    expect(
      prefs.getString(mediaServerViewModeStorageKey(null)),
      'portrait',
    );
  });
}
