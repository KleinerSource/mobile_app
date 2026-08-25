import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/update/update_models.dart';
import 'package:omm/core/update/update_repository.dart';
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

  test('开发版检测默认关闭并可以持久化', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = UpdateSettingsRepository(prefs);

    expect(repository.loadIncludeDevelopment(), isFalse);
    await repository.saveIncludeDevelopment(true);
    expect(repository.loadIncludeDevelopment(), isTrue);
    expect(
      prefs.getBool(UpdateSettingsRepository.includeDevelopmentKey),
      isTrue,
    );
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

  test('切换开发版检测会清除已忽略版本', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = UpdateSettingsRepository(prefs);
    final version = AppReleaseVersion.parse('0.39.0+409');
    const repositoryUrl = 'https://github.com/owner/repository';

    await repository.ignoreUpdate(
      repositoryUrl: repositoryUrl,
      platform: UpdatePlatform.android,
      version: version,
    );
    expect(
      repository.isUpdateIgnored(
        repositoryUrl: repositoryUrl,
        platform: UpdatePlatform.android,
        version: version,
      ),
      isTrue,
    );

    await repository.saveIncludeDevelopment(true);

    expect(
      repository.isUpdateIgnored(
        repositoryUrl: repositoryUrl,
        platform: UpdatePlatform.android,
        version: version,
      ),
      isFalse,
    );
  });
}
