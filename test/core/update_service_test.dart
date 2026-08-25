import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/update/update_models.dart';
import 'package:omm/core/update/update_service.dart';

void main() {
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
