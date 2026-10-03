import 'package:flutter_test/flutter_test.dart';
import 'package:omm/shared/search_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('新增关键词置顶，重复关键词移动到最前', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SearchHistoryStore(await SharedPreferences.getInstance());

    await store.add('server-1', '演员');
    await store.add('server-1', '番号');
    await store.add('server-1', '演员');

    expect(store.load('server-1'), ['演员', '番号']);
  });

  test('历史按服务器独立保存，清空只影响当前服务器', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SearchHistoryStore(await SharedPreferences.getInstance());

    await store.add('server-1', '关键词A');
    await store.add('server-2', '关键词B');

    expect(store.load('server-1'), ['关键词A']);
    expect(store.load('server-2'), ['关键词B']);

    await store.clear('server-1');
    expect(store.load('server-1'), isEmpty);
    expect(store.load('server-2'), ['关键词B']);
  });

  test('历史最多保留 20 条，空白关键词被忽略', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SearchHistoryStore(await SharedPreferences.getInstance());

    for (var i = 1; i <= 25; i++) {
      await store.add('server-1', '关键词$i');
    }
    await store.add('server-1', '   ');

    final entries = store.load('server-1');
    expect(entries, hasLength(SearchHistoryStore.maxEntries));
    expect(entries.first, '关键词25');
    expect(entries.last, '关键词6');
  });

  test('损坏的历史数据回退为空列表', () async {
    SharedPreferences.setMockInitialValues({
      'search.history.v1.server-1': '{invalid json',
    });
    final store = SearchHistoryStore(await SharedPreferences.getInstance());

    expect(store.load('server-1'), isEmpty);
  });
}
