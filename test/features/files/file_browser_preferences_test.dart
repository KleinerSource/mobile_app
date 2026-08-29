import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/features/files/file_browser_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('按服务器分别保存排序和隐藏文件偏好', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = FileBrowserPreferencesRepository(prefs);

    await repository.save(
      'server-one',
      const FileBrowserPreferences(
        sortField: FileBrowserSortField.date,
        sortAscending: false,
        showHiddenFiles: true,
      ),
    );

    final saved = repository.load('server-one');
    expect(saved.sortField, FileBrowserSortField.date);
    expect(saved.sortAscending, isFalse);
    expect(saved.showHiddenFiles, isTrue);

    const defaults = FileBrowserPreferences();
    expect(repository.load('server-two').sortField, defaults.sortField);
    expect(repository.load('server-two').sortAscending, defaults.sortAscending);
    expect(
      repository.load('server-two').showHiddenFiles,
      defaults.showHiddenFiles,
    );
  });

  test('损坏或未知偏好会安全回退到默认值', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = FileBrowserPreferencesRepository(prefs);

    await prefs.setString(
      'file_browser.preferences.v1.c2VydmVyLW9uZQ',
      '{invalid json',
    );
    expect(repository.load('server-one').sortField, FileBrowserSortField.name);

    await repository.save(
      'server-two',
      const FileBrowserPreferences(sortField: FileBrowserSortField.category),
    );
    expect(
      repository.load('server-two').sortField,
      FileBrowserSortField.category,
    );
  });

  test('按服务器分组的状态会同步更新并写入本地偏好', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final serverOne = fileBrowserPreferencesProvider('server-one');
    final serverTwo = fileBrowserPreferencesProvider('server-two');
    expect(container.read(serverOne).sortField, FileBrowserSortField.name);
    expect(container.read(serverTwo).sortField, FileBrowserSortField.name);

    container.read(serverOne.notifier).setSort(FileBrowserSortField.size);
    container.read(serverOne.notifier).toggleHiddenFiles();

    expect(container.read(serverOne).sortField, FileBrowserSortField.size);
    expect(container.read(serverOne).showHiddenFiles, isTrue);
    expect(container.read(serverTwo).sortField, FileBrowserSortField.name);
    expect(container.read(serverTwo).showHiddenFiles, isFalse);

    await container.read(fileBrowserPreferencesRepositoryProvider).flush();
    final saved = FileBrowserPreferencesRepository(prefs).load('server-one');
    expect(saved.sortField, FileBrowserSortField.size);
    expect(saved.showHiddenFiles, isTrue);
  });
}
