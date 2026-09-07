import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/app_request_headers.dart';
import 'package:omm/core/platform/app_version.dart';
import 'package:package_info_plus/package_info_plus.dart';

void _setPackageInfo({required String version, String buildNumber = '745'}) {
  PackageInfo.setMockInitialValues(
    appName: 'Oh My Media',
    packageName: 'com.ohmymedia.omm',
    version: version,
    buildNumber: buildNumber,
    buildSignature: '',
  );
  resetAppVersionCache();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PackageInfo 不可用时回退到 omm/unknown', () async {
    resetAppVersionCache();
    expect(await appUserAgent(), 'omm/unknown');
  });

  test('默认 UA 使用版本号且不包含 build number', () async {
    _setPackageInfo(version: '0.92.10');

    expect(await appUserAgent(), 'omm/0.92.10');
    expect(formatAppUserAgent('  '), 'omm/unknown');
  });

  test('版本读取结果会被缓存', () async {
    _setPackageInfo(version: '0.92.10');
    expect(await appUserAgent(), 'omm/0.92.10');

    PackageInfo.setMockInitialValues(
      appName: 'Oh My Media',
      packageName: 'com.ohmymedia.omm',
      version: '9.9.9',
      buildNumber: '999',
      buildSignature: '',
    );
    expect(await appUserAgent(), 'omm/0.92.10');
  });

  test('媒体请求头无 UA 时自动补齐并保留其他鉴权头', () async {
    _setPackageInfo(version: '0.92.10');

    expect(await mergeAppRequestHeaders({'Authorization': 'Bearer token'}), {
      'Authorization': 'Bearer token',
      'User-Agent': 'omm/0.92.10',
    });
  });

  test('所有显式 UA 都被统一替换且大小写变体不会重复添加', () async {
    _setPackageInfo(version: '0.92.10');

    expect(
      await mergeAppRequestHeaders({
        'user-agent': 'custom-player/1.0',
        'Cookie': 'sid=session',
      }),
      {'Cookie': 'sid=session', 'User-Agent': 'omm/0.92.10'},
    );
    expect(await mergeAppRequestHeaders({'USER-AGENT': 'custom-player/2.0'}), {
      'User-Agent': 'omm/0.92.10',
    });
  });

  test('空的 UA 会被默认值替换且不影响其他头', () async {
    _setPackageInfo(version: '0.92.10');

    expect(
      await mergeAppRequestHeaders({
        'User-Agent': '  ',
        'Authorization': 'Bearer token',
      }),
      {'User-Agent': 'omm/0.92.10', 'Authorization': 'Bearer token'},
    );
  });

  test('Dio 拦截器幂等覆盖所有大小写 UA 并保留鉴权头', () async {
    _setPackageInfo(version: '0.92.10');

    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://example.test',
        headers: {'user-agent': 'legacy-client/1.0'},
      ),
    );
    installAppUserAgentInterceptor(dio);
    installAppUserAgentInterceptor(dio);

    RequestOptions? captured;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          handler.resolve(
            Response<void>(requestOptions: options, statusCode: 200),
          );
        },
      ),
    );

    await dio.get<void>(
      '/cover',
      options: Options(
        headers: {
          'USER-AGENT': 'legacy-request/2.0',
          'Authorization': 'Bearer token',
          'Cookie': 'sid=session',
        },
      ),
    );

    expect(captured, isNotNull);
    final headers = captured!.headers;
    expect(
      headers.entries
          .where((entry) => entry.key.toLowerCase() == 'user-agent')
          .toList(),
      hasLength(1),
    );
    expect(headers['User-Agent'], 'omm/0.92.10');
    expect(headers['Authorization'], 'Bearer token');
    expect(headers['Cookie'], 'sid=session');
  });
}
