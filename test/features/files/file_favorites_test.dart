import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/files/file_entry.dart';
import 'package:omm/features/files/file_favorites.dart';
import 'package:shared_preferences/shared_preferences.dart';

FileEntry _entry(String path, {bool directory = false}) {
  return FileEntry(
    path: FilePath(sourceId: const SourceId('src-one'), value: path),
    name: path.split('/').where((part) => part.isNotEmpty).last,
    type: directory ? FileEntryType.directory : FileEntryType.file,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('收藏按服务器分别保存，互不可见', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = FileFavoritesRepository(prefs);

    await repository.save('server-one', [
      FileFavorite.fromEntry(_entry('/media/movies', directory: true)),
    ]);
    await repository.save('server-two', [
      FileFavorite.fromEntry(_entry('/docs', directory: true)),
    ]);

    final one = repository.load('server-one');
    final two = repository.load('server-two');
    expect(one, hasLength(1));
    expect(one.single.path, '/media/movies');
    expect(two, hasLength(1));
    expect(two.single.path, '/docs');
  });

  test('收藏记录可完整序列化往返', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = FileFavoritesRepository(prefs);

    await repository.save('server-one', [
      FileFavorite.fromEntry(_entry('/a/视频.mp4')),
      FileFavorite.fromEntry(_entry('/a/b', directory: true)),
    ]);

    final saved = repository.load('server-one');
    expect(saved, hasLength(2));
    expect(saved[0].name, '视频.mp4');
    expect(saved[0].isDirectory, isFalse);
    expect(saved[0].stableKey, 'src-one:/a/视频.mp4');
    expect(saved[1].isDirectory, isTrue);
    expect(saved[1].addedAtMilliseconds, greaterThan(0));
  });

  test('损坏或非法数据会安全回退为空收藏', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = FileFavoritesRepository(prefs);

    await prefs.setString(
      'file_browser.favorites.v1.c2VydmVyLW9uZQ',
      '{invalid json',
    );
    expect(repository.load('server-one'), isEmpty);

    await prefs.setString(
      'file_browser.favorites.v1.c2VydmVyLW9uZQ',
      '[{"path":"/only-path"}]',
    );
    expect(repository.load('server-one'), isEmpty);
  });

  test('按服务器分组的状态支持切换收藏并写入本地', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final serverOne = fileFavoritesProvider('server-one');
    final serverTwo = fileFavoritesProvider('server-two');
    expect(container.read(serverOne), isEmpty);
    expect(container.read(serverTwo), isEmpty);

    final movie = _entry('/media/movie.mkv');
    expect(container.read(serverOne.notifier).toggle(movie), isTrue);
    expect(
      container.read(serverOne.notifier).toggle(_entry('/media', directory: true)),
      isTrue,
    );
    expect(
      container.read(serverOne.notifier).isFavorite(movie.stableKey),
      isTrue,
    );
    expect(container.read(serverTwo.notifier).isFavorite(movie.stableKey), isFalse);

    // 再次切换同一文件即取消收藏。
    expect(container.read(serverOne.notifier).toggle(movie), isFalse);
    expect(container.read(serverOne), hasLength(1));
    expect(container.read(serverOne).single.isDirectory, isTrue);

    await container.read(fileFavoritesRepositoryProvider).flush();
    final saved = FileFavoritesRepository(prefs).load('server-one');
    expect(saved, hasLength(1));
    expect(saved.single.path, '/media');
    expect(FileFavoritesRepository(prefs).load('server-two'), isEmpty);
  });

  test('remove 按 stableKey 移除收藏', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(fileFavoritesProvider('server-one').notifier);
    final dir = _entry('/shows', directory: true);
    notifier.toggle(dir);
    notifier.toggle(_entry('/shows/s01.mkv'));

    notifier.remove('src-one:/shows/s01.mkv');
    expect(container.read(fileFavoritesProvider('server-one')), hasLength(1));
    expect(container.read(fileFavoritesProvider('server-one')).single.path, '/shows');

    // 不存在的键不会改动状态。
    notifier.remove('src-one:/missing');
    expect(container.read(fileFavoritesProvider('server-one')), hasLength(1));
  });

  test('toEntry 还原目录/文件类型与路径键一致', () {
    const sourceId = SourceId('src-one');
    final favorite = FileFavorite.fromEntry(_entry('/a/b', directory: true));
    final entry = favorite.toEntry(sourceId);
    expect(entry.isDirectory, isTrue);
    expect(entry.name, 'b');
    expect(entry.stableKey, favorite.stableKey);
  });
}
