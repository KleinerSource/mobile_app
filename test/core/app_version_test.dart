import 'package:flutter_test/flutter_test.dart';
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

    expect(await mergeMediaRequestHeaders({'Authorization': 'Bearer token'}), {
      'Authorization': 'Bearer token',
      'User-Agent': 'omm/0.92.10',
    });
  });

  test('显式 UA 优先且大小写变体不会重复添加', () async {
    _setPackageInfo(version: '0.92.10');

    expect(
      await mergeMediaRequestHeaders({
        'user-agent': 'custom-player/1.0',
        'Cookie': 'sid=session',
      }),
      {'user-agent': 'custom-player/1.0', 'Cookie': 'sid=session'},
    );
    expect(
      await mergeMediaRequestHeaders({'USER-AGENT': 'custom-player/2.0'}),
      {'USER-AGENT': 'custom-player/2.0'},
    );
  });

  test('空的 UA 会被默认值替换且不影响其他头', () async {
    _setPackageInfo(version: '0.92.10');

    expect(
      await mergeMediaRequestHeaders({
        'User-Agent': '  ',
        'Authorization': 'Bearer token',
      }),
      {'User-Agent': 'omm/0.92.10', 'Authorization': 'Bearer token'},
    );
  });
}
