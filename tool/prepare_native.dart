import 'dart:convert';
import 'dart:io';

/// 与 CI 共用的原生工程准备入口，不下载播放器或安装 Pods。
Future<void> main(List<String> args) async {
  if (args.length != 2 ||
      !['bootstrap', 'configure'].contains(args[0]) ||
      !['android', 'ios'].contains(args[1])) {
    stderr.writeln(
      '用法: dart tool/prepare_native.dart <bootstrap|configure> <android|ios>',
    );
    exitCode = 64;
    return;
  }
  final root = Directory.current;
  if (!File('${root.path}/pubspec.yaml').existsSync()) {
    throw StateError('请在 mobile_app 根目录运行');
  }
  final platform = args[1];
  if (args[0] == 'bootstrap') {
    final exists = platform == 'android'
        ? [
            'android/settings.gradle.kts',
            'android/settings.gradle',
          ].any((path) => File(path).existsSync())
        : File('ios/Runner.xcodeproj/project.pbxproj').existsSync();
    if (!exists) {
      final templateTest = File('test/widget_test.dart');
      final hadTest = templateTest.existsSync();
      final process = await Process.start(
        Platform.isWindows ? 'flutter.bat' : 'flutter',
        [
          'create',
          '.',
          '--no-pub',
          '--platforms=$platform',
          '--org',
          'com.ohmymedia',
          '--project-name',
          'omm',
          '--description',
          'omm 移动端',
        ],
        mode: ProcessStartMode.inheritStdio,
        runInShell: Platform.isWindows,
      );
      final result = await process.exitCode;
      if (result != 0) {
        throw ProcessException('flutter create', [], '工程生成失败', result);
      }
      if (!hadTest && templateTest.existsSync()) templateTest.deleteSync();
    }
    if (platform == 'android') {
      prepareAndroidProject(root);
    } else {
      prepareIosProject(root);
    }
  } else if (platform == 'android') {
    prepareAndroidProject(root);
    prepareVolumePlugin(root);
  } else {
    prepareIosProject(root);
    updateFile(
      File('ios/Podfile'),
      (text) => preparePodfile(text, Platform.environment),
    );
  }
}

void updateFile(File file, String Function(String) transform) {
  final before = file.readAsStringSync(encoding: utf8);
  final after = transform(before);
  if (before != after) {
    file.writeAsStringSync(after, encoding: utf8);
    stdout.writeln('已更新 ${file.path}');
  }
}

String prepareAndroidGradle(String text) => text
    .replaceAll('minSdk = flutter.minSdkVersion', 'minSdk = 24')
    .replaceAll('targetSdk = flutter.targetSdkVersion', 'targetSdk = 35')
    .replaceAll('compileSdk = flutter.compileSdkVersion', 'compileSdk = 36');

void prepareAndroidProject(Directory root) {
  for (final name in ['build.gradle.kts', 'build.gradle']) {
    final file = File('${root.path}/android/app/$name');
    if (file.existsSync()) updateFile(file, prepareAndroidGradle);
  }
  updateFile(
    File('${root.path}/android/gradle/wrapper/gradle-wrapper.properties'),
    (text) => text.replaceAll('services.gradle.org', 'downloads.gradle.org'),
  );
}

void prepareVolumePlugin(Directory root) {
  final config = File('${root.path}/.dart_tool/package_config.json');
  final packages =
      (jsonDecode(config.readAsStringSync()) as Map)['packages'] as List;
  final package = packages.cast<Map>().singleWhere(
    (package) => package['name'] == 'flutter_volume_controller',
  );
  final uri = config.absolute.uri.resolve(package['rootUri'] as String);
  final android = Directory.fromUri(uri.resolve('android/'));
  final file = ['build.gradle', 'build.gradle.kts']
      .map((name) => File('${android.path}/$name'))
      .firstWhere((file) => file.existsSync());
  updateFile(
    file,
    (text) => text.replaceAllMapped(
      RegExp(r'(compileSdk(?:Version)?\s*(?:=\s*)?)\d+'),
      (match) => '${match[1]}36',
    ),
  );
}

void prepareIosProject(Directory root) {
  updateFile(
    File('${root.path}/ios/Runner.xcodeproj/project.pbxproj'),
    (text) => text.replaceAll(
      RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = (12|13)\.0;'),
      'IPHONEOS_DEPLOYMENT_TARGET = 16.0;',
    ),
  );
  final target = File(
    '${root.path}/ios/Runner/Base.lproj/LaunchScreen.storyboard',
  );
  target.parent.createSync(recursive: true);
  final source = File('${root.path}/ios/Runner/LaunchScreen.storyboard');
  final content = source.readAsStringSync(encoding: utf8);
  if (!target.existsSync() ||
      target.readAsStringSync(encoding: utf8) != content) {
    target.writeAsStringSync(content, encoding: utf8);
  }
}

String preparePodfile(String text, Map<String, String> environment) {
  text = text.replaceAll('\r\n', '\n');
  String setting(String key) {
    final value = environment[key];
    if (value == null || value.isEmpty || value.contains(RegExp('[\r\n]'))) {
      throw StateError('缺少有效的 $key；请使用工作流中固定的播放器依赖版本');
    }
    // Ruby 单引号字符串，避免环境值被解释为代码。
    return "'${value.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";
  }

  final platform = RegExp(
    r"^\s*#?\s*platform :ios, '[0-9.]+'[^\r\n]*",
    multiLine: true,
  );
  text = platform.hasMatch(text)
      ? text.replaceAll(platform, "platform :ios, '16.0'")
      : "platform :ios, '16.0'\n$text";
  text = text.replaceAll(
    RegExp(r'^([ \t]*)use_frameworks![ \t]*$', multiLine: true),
    '  use_frameworks! :linkage => :static',
  );
  const marker = "target 'Runner' do";
  if (!text.contains(marker) ||
      !text.contains('use_frameworks! :linkage => :static')) {
    throw StateError('Podfile 必须包含 Runner target 和静态 use_frameworks!');
  }
  final pods = [
    ('KSPlayer', 'KSPLAYER', 'commit', 'COMMIT'),
    ('DisplayCriteria', 'DISPLAYCRITERIA', 'commit', 'COMMIT'),
    ('FFmpegKit', 'FFMPEGKIT', 'tag', 'VERSION'),
    ('Libass', 'LIBASS', 'tag', 'VERSION'),
  ];
  // 移除旧声明后统一插入，固定版本改变时同样可重复执行。
  for (final (name, _, _, _) in pods) {
    text = text.replaceAll(
      RegExp(
        "^[ \\t]*pod ['\"]$name['\"][^\\r\\n]*(?:\\r?\\n|\$)",
        multiLine: true,
      ),
      '',
    );
  }
  final declarations = pods
      .map(
        (pod) =>
            "  pod '${pod.$1}', :git => ${setting('${pod.$2}_REPOSITORY')}, "
            ":${pod.$3} => ${setting('${pod.$2}_${pod.$4}')}",
      )
      .join('\n');
  return text.replaceFirst(marker, '$marker\n$declarations');
}
