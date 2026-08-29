// 合并自以下测试文件（测试内容保持不变，整合以减少每个文件的加载编译开销）。
//   - test/core/update_repository_test.dart
//   - test/core/update_service_test.dart

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/update/update_models.dart';
import 'package:omm/core/update/update_repository.dart';
import 'package:omm/core/update/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==================== 原 test/core/update_repository_test.dart ====================
void _main_0() {
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

// ==================== 原 test/core/update_service_test.dart ====================
void _main_1() {
  const currentVersion = AppReleaseVersion(
    major: 0,
    minor: 38,
    patch: 21,
    build: 408,
  );
  final repository = GitHubRepository.parse(
    'https://github.com/KleinerSource/mobile_app',
  );

  test('开启开发版检测会查询两个滚动标签并选择最高版本', () async {
    final stub = _ReleaseApiStub({
      repository.releaseTagApiUrl(UpdatePlatform.android): _release(
        tag: 'latest-android',
        asset: 'omm_0.38.22+409.apk',
      ),
      repository.releaseTagApiUrl(UpdatePlatform.android, development: true):
          _release(tag: 'latest-android-dev', asset: 'omm_dev_0.39.0+409.apk'),
    });
    final service = GitHubUpdateService(dio: stub.dio);

    final result = await service.check(
      repositoryUrl: repository.canonicalUrl,
      platform: UpdatePlatform.android,
      currentVersion: currentVersion,
      includeDevelopment: true,
    );

    expect(result.candidate.asset.name, 'omm_dev_0.39.0+409.apk');
    expect(
      stub.requests,
      containsAll([
        repository.releaseTagApiUrl(UpdatePlatform.android),
        repository.releaseTagApiUrl(UpdatePlatform.android, development: true),
      ]),
    );
    expect(stub.requests, isNot(contains(repository.releasesApiUrl)));
  });

  test('关闭开发版检测时列表回退不会选择开发资产', () async {
    final stub = _ReleaseApiStub({
      repository.releasesApiUrl: [
        _release(tag: 'latest-android-dev', asset: 'omm_dev_0.40.0+410.apk'),
        _release(tag: 'v0.38.22+409', asset: 'md_center_0.38.22+409.apk'),
      ],
    });
    final service = GitHubUpdateService(dio: stub.dio);

    final result = await service.check(
      repositoryUrl: repository.canonicalUrl,
      platform: UpdatePlatform.android,
      currentVersion: currentVersion,
    );

    expect(result.candidate.asset.name, 'md_center_0.38.22+409.apk');
    expect(
      stub.requests,
      isNot(
        contains(
          repository.releaseTagApiUrl(
            UpdatePlatform.android,
            development: true,
          ),
        ),
      ),
    );
    expect(stub.requests, contains(repository.releasesApiUrl));
  });

  test('开发标签不存在时回退已找到的标准滚动版本', () async {
    final stub = _ReleaseApiStub({
      repository.releaseTagApiUrl(UpdatePlatform.ios): _release(
        tag: 'latest',
        asset: 'omm_0.38.22+409.ipa',
      ),
    });
    final service = GitHubUpdateService(dio: stub.dio);

    final result = await service.check(
      repositoryUrl: repository.canonicalUrl,
      platform: UpdatePlatform.ios,
      currentVersion: currentVersion,
      includeDevelopment: true,
    );

    expect(result.candidate.asset.name, 'omm_0.38.22+409.ipa');
    expect(stub.requests, hasLength(2));
    expect(stub.requests, isNot(contains(repository.releasesApiUrl)));
  });

  test('列表回退不会重新加入滚动标签中的草稿 Release', () async {
    final draft = _release(tag: 'latest-android', asset: 'omm_0.40.0+410.apk')
      ..['draft'] = true;
    final stub = _ReleaseApiStub({
      repository.releaseTagApiUrl(UpdatePlatform.android): draft,
      repository.releasesApiUrl: [
        _release(tag: 'v0.38.22+409', asset: 'omm_0.38.22+409.apk'),
      ],
    });
    final service = GitHubUpdateService(dio: stub.dio);

    final result = await service.check(
      repositoryUrl: repository.canonicalUrl,
      platform: UpdatePlatform.android,
      currentVersion: currentVersion,
    );

    expect(result.candidate.asset.name, 'omm_0.38.22+409.apk');
  });
}

Map<String, Object> _release({required String tag, required String asset}) {
  return {
    'tag_name': tag,
    'assets': [
      {
        'name': asset,
        'browser_download_url': 'https://github.com/o/r/releases/$asset',
      },
    ],
  };
}

class _ReleaseApiStub extends Interceptor {
  _ReleaseApiStub(this.responses) : dio = Dio() {
    dio.interceptors.add(this);
  }

  final Map<String, Object?> responses;
  final Dio dio;
  final List<String> requests = [];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final url = options.uri.toString();
    requests.add(url);
    if (!responses.containsKey(url)) {
      handler.reject(
        DioException(
          requestOptions: options,
          response: Response<void>(requestOptions: options, statusCode: 404),
          type: DioExceptionType.badResponse,
        ),
      );
      return;
    }
    handler.resolve(
      Response<Object?>(
        requestOptions: options,
        statusCode: 200,
        data: responses[url],
      ),
    );
  }
}

void main() {
  group('update_repository', _main_0);
  group('update_service', _main_1);
}
