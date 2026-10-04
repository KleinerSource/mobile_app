import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/features/visited/visited_movies_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('记录已浏览影片：去重、持久化、幂等通知', () async {
    final prefs = await SharedPreferences.getInstance();
    final state = VisitedMoviesState(prefs, 'server-a');

    expect(state.isVisited(5), isFalse);
    await state.markVisited(5);
    await state.markVisited(5);

    expect(state.isVisited(5), isTrue);
    // OMM 整数 id 与外部源字符串 id 统一按 toString 归一化。
    expect(state.isVisited('5'), isTrue);
    expect(state.isVisited(' 5 '), isTrue);
    expect(state.isVisited(null), isFalse);
    expect(
      prefs.getStringList('visited.movies.v1.server-a'),
      equals(['5']),
    );
  });

  test('按服务器隔离：不同服务器的集合互不可见', () async {
    final prefs = await SharedPreferences.getInstance();
    final stateA = VisitedMoviesState(prefs, 'server-a');
    await stateA.markVisited('v_1');

    final stateB = VisitedMoviesState(prefs, 'server-b');
    expect(stateB.isVisited('v_1'), isFalse);

    // 同服务器重新加载可见（重启场景）。
    final reloadedA = VisitedMoviesState(prefs, 'server-a');
    expect(reloadedA.isVisited('v_1'), isTrue);
  });

  test('超出上限时按进入顺序淘汰最旧的记录', () async {
    final prefs = await SharedPreferences.getInstance();
    final initial = [
      for (var i = 0; i < maxVisitedMovies + 1; i++) 'm$i',
    ];
    await prefs.setStringList('visited.movies.v1.server-a', initial);

    final state = VisitedMoviesState(prefs, 'server-a');
    expect(state.isVisited('m0'), isFalse, reason: '最旧的记录被淘汰');
    expect(state.isVisited('m1'), isTrue);
    expect(state.isVisited('m$maxVisitedMovies'), isTrue);
  });

  test('provider 随 media lane 服务器切换重建集合', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('visited.movies.v1.server-b', ['scene-9']);
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    // server-a：无记录。
    container
        .read(serverRuntimeProvider.notifier)
        .commit(ServerRuntimeLane.media, 'server-a');
    expect(container.read(visitedMoviesProvider).isVisited('scene-9'), isFalse);

    // 切到 server-b：加载该服务器的记录。
    await container
        .read(visitedMoviesProvider)
        .markVisited('scene-1');
    container
        .read(serverRuntimeProvider.notifier)
        .commit(ServerRuntimeLane.media, 'server-b');
    expect(container.read(visitedMoviesProvider).isVisited('scene-9'), isTrue);
    expect(container.read(visitedMoviesProvider).isVisited('scene-1'), isFalse);
  });
}
