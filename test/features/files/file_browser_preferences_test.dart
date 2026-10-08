import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/features/files/file_browser_preferences.dart';
import 'package:omm/features/files/file_entry_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('新用户和旧版偏好默认五类全选，保留原隐藏与排序设置', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = FileBrowserPreferencesRepository(prefs);
    expect(
      repository.load('server-one').selectedTypes,
      FileFilterType.values.toSet(),
    );
    await prefs.setString(
      'file_browser.preferences.v1.c2VydmVyLW9uZQ',
      '{"sort_field":"size","sort_ascending":false,"show_hidden_files":true}',
    );
    final old = repository.load('server-one');
    expect(old.selectedTypes, FileFilterType.values.toSet());
    expect(old.showHiddenFiles, isTrue);
    expect(old.sortField, FileBrowserSortField.size);
    expect(old.sortAscending, isFalse);
  });

  test('类型切换同步更新且按服务器保存，重建状态可恢复空集合', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    final one = fileBrowserPreferencesProvider('server-one');
    final two = fileBrowserPreferencesProvider('server-two');
    for (final type in FileFilterType.values) {
      container.read(one.notifier).toggleType(type);
    }
    container.read(two.notifier).toggleType(FileFilterType.subtitle);
    container.read(one.notifier).toggleHiddenFiles();
    container.read(one.notifier).setSort(FileBrowserSortField.date);
    expect(container.read(one).selectedTypes, isEmpty);
    expect(container.read(two).selectedTypes, hasLength(4));
    await container.read(fileBrowserPreferencesRepositoryProvider).flush();
    container.dispose();

    final restored = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(restored.dispose);
    expect(restored.read(one).selectedTypes, isEmpty);
    expect(restored.read(one).showHiddenFiles, isTrue);
    expect(restored.read(one).sortField, FileBrowserSortField.date);
    expect(
      restored.read(two).selectedTypes,
      isNot(contains(FileFilterType.subtitle)),
    );
    restored.read(one.notifier).toggleType(FileFilterType.video);
    expect(restored.read(one).selectedTypes, {FileFilterType.video});
    await restored.read(fileBrowserPreferencesRepositoryProvider).flush();
    expect(
      FileBrowserPreferencesRepository(prefs).load('server-one').selectedTypes,
      {FileFilterType.video},
    );
  });

  test('无效类型字段回退全选，混合未知值仅保留已知类型', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = FileBrowserPreferencesRepository(prefs);
    const key = 'file_browser.preferences.v1.c2VydmVyLW9uZQ';
    for (final value in ['null', 'true', '["unknown"]']) {
      await prefs.setString(key, '{"selected_types":$value}');
      expect(
        repository.load('server-one').selectedTypes,
        FileBrowserPreferences.allTypes,
      );
    }
    await prefs.setString(key, '{"selected_types":["music","unknown"]}');
    expect(repository.load('server-one').selectedTypes, {FileFilterType.music});
  });

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
