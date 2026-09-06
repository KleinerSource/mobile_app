import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../../tool/prepare_native.dart';

void main() {
  test('Android 只替换 Flutter 模板变量，保留显式平台目标', () {
    const source =
        'minSdk = 23\ncompileSdk = flutter.compileSdkVersion\n'
        'targetSdk = flutter.targetSdkVersion';
    final result = prepareAndroidGradle(source);
    expect(result, 'minSdk = 23\ncompileSdk = 36\ntargetSdk = 35');
    expect(prepareAndroidGradle(result), result);
    expect(
      prepareAndroidGradle('minSdk = flutter.minSdkVersion'),
      'minSdk = 24',
    );
  });

  test('Podfile 固定四个依赖，重复准备不产生重复声明', () {
    const source =
        "# platform :ios, '13.0'\ntarget 'Runner' do\n"
        '  use_frameworks!\n  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))\nend\n';
    final env = <String, String>{
      for (final prefix in [
        'KSPLAYER',
        'DISPLAYCRITERIA',
        'FFMPEGKIT',
        'LIBASS',
      ])
        '${prefix}_REPOSITORY': 'https://example.test/$prefix.git',
      'KSPLAYER_COMMIT': 'abc',
      'DISPLAYCRITERIA_COMMIT': 'abc',
      'FFMPEGKIT_VERSION': '6.1.4',
      'LIBASS_VERSION': '6.1.4',
    };
    final result = preparePodfile(source, env);
    expect(result, contains("platform :ios, '16.0'"));
    expect(result, contains('use_frameworks! :linkage => :static'));
    expect(RegExp('  pod ').allMatches(result), hasLength(4));
    expect(preparePodfile(result, env), result);
    expect(preparePodfile(source.replaceAll('\n', '\r\n'), env), result);
    env['KSPLAYER_COMMIT'] = 'def';
    final updated = preparePodfile(result, env);
    expect(updated, contains(":commit => 'def'"));
    expect(RegExp('  pod ').allMatches(updated), hasLength(4));
    expect(() => preparePodfile(source, {}), throwsStateError);
  });

  test('音量插件路径支持 package_config 中含空格的相对 URI', () {
    final root = Directory.systemTemp.createTempSync('native_prepare_');
    addTearDown(() => root.deleteSync(recursive: true));
    final config = File('${root.path}/.dart_tool/package_config.json');
    config.parent.createSync();
    config.writeAsStringSync(
      jsonEncode({
        'packages': [
          {
            'name': 'flutter_volume_controller',
            'rootUri': '../cache%20space/volume/',
          },
        ],
      }),
    );
    final gradle = File('${root.path}/cache space/volume/android/build.gradle');
    gradle.parent.createSync(recursive: true);
    gradle.writeAsStringSync('compileSdkVersion 33\n// 中文');
    prepareVolumePlugin(root);
    expect(gradle.readAsStringSync(), 'compileSdkVersion 36\n// 中文');
    prepareVolumePlugin(root);
    expect(gradle.readAsStringSync(), 'compileSdkVersion 36\n// 中文');
  });
}
