import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/update/update_models.dart';
import 'package:md_center/core/update/update_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('更新仓库地址可以保存、读取和清空', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = UpdateSettingsRepository(prefs);

    expect(repository.loadRepository(), isNull);
    await repository.saveRepository(' https://github.com/owner/repository ');
    expect(repository.loadRepository(), 'https://github.com/owner/repository');

    await repository.saveRepository(null);
    expect(repository.loadRepository(), isNull);
  });

  test('忽略版本只匹配指定仓库、平台和版本', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = UpdateSettingsRepository(prefs);
    final version = AppReleaseVersion.parse('0.1.68+75');

    await repository.saveRepository('https://github.com/owner/repository');
    await repository.ignoreUpdate(
      repositoryUrl: 'https://github.com/owner/repository',
      platform: UpdatePlatform.ios,
      version: version,
    );

    expect(
      repository.isUpdateIgnored(
        repositoryUrl: 'https://github.com/owner/repository',
        platform: UpdatePlatform.ios,
        version: version,
      ),
      isTrue,
    );
    expect(
      repository.isUpdateIgnored(
        repositoryUrl: 'https://github.com/owner/repository',
        platform: UpdatePlatform.android,
        version: version,
      ),
      isFalse,
    );
    expect(
      repository.isUpdateIgnored(
        repositoryUrl: 'https://github.com/owner/repository',
        platform: UpdatePlatform.ios,
        version: AppReleaseVersion.parse('0.1.69+76'),
      ),
      isFalse,
    );
  });
}
