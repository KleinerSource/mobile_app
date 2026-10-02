import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/filter_chip.dart';
import 'package:omm/shared/header_action_button.dart';
import 'package:omm/shared/media_view_mode.dart';
import 'package:omm/shared/page_header.dart';

// 使用 Flutter SDK 自带字体，避免依赖机器上的系统字体。
// 页面接入由 page_header_navigation_test 验证；此处固定共享控件的视觉契约。
// 基线更新：flutter test --no-pub --update-goldens test/shared/header_visual_test.dart
// CI 的 Flutter 3.44 与本机 3.47 圆角边缘绘制不同，仅影片库保留两套严格基线。
String _libraryGoldenSuffix = '';

Future<void> _loadFonts() async {
  final config = File('.dart_tool/package_config.json').absolute;
  final packages =
      (jsonDecode(await config.readAsString()) as Map)['packages'] as List;
  final flutter = packages.cast<Map>().singleWhere(
    (package) => package['name'] == 'flutter',
  );
  final flutterPackage = Directory.fromUri(
    config.uri.resolve(flutter['rootUri'] as String),
  ).uri;
  final sdkVersion =
      jsonDecode(
            await File.fromUri(
              flutterPackage.resolve('../../bin/cache/flutter.version.json'),
            ).readAsString(),
          )
          as Map;
  _libraryGoldenSuffix =
      (sdkVersion['frameworkVersion'] as String).startsWith('3.44.')
      ? '_flutter_3_44'
      : '';
  final fonts = flutterPackage.resolve(
    '../../bin/cache/artifacts/material_fonts/',
  );
  for (final entry in {
    'Inter': ['roboto-regular.ttf', 'roboto-bold.ttf'],
    'MaterialIcons': ['materialicons-regular.otf'],
  }.entries) {
    final loader = FontLoader(entry.key);
    for (final file in entry.value) {
      loader.addFont(
        File.fromUri(
          fonts.resolve(file),
        ).readAsBytes().then(ByteData.sublistView),
      );
    }
    await loader.load();
  }
}

Widget _header(BuildContext context, String variant) {
  final title = switch (variant) {
    'library' => '123 movies',
    'search' => 'Find content',
    'favorites' => '12 items',
    _ => 'Favorites',
  };
  final actions = switch (variant) {
    'library' => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CompactFilterButton(
          label: '',
          icon: Icons.tune_rounded,
          active: true,
          onTap: () {},
        ),
        const SizedBox(width: 8),
        MediaViewModeToggle(mode: MediaViewMode.landscape, onChanged: (_) {}),
      ],
    ),
    'search' => MediaViewModeToggle(
      mode: MediaViewMode.list,
      onChanged: (_) {},
    ),
    'favorites' => HeaderActionButton(
      icon: Icons.settings_outlined,
      tooltip: 'Settings',
      onPressed: () {},
    ),
    _ => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const HeaderActionButton(
          icon: Icons.cloud_download_outlined,
          tooltip: 'Scan resources',
          loading: true,
          onPressed: null,
        ),
        HeaderActionButton(
          icon: Icons.settings,
          tooltip: 'Settings',
          onPressed: () {},
        ),
      ],
    ),
  };
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      PageHeader(
        eyebrow: switch (variant) {
          'library' => 'Library',
          'search' => 'Search',
          'favorites' => 'Favorites',
          _ => 'You',
        },
        title: Text(title, style: AppText.pageTitle(context)),
        trailing: actions,
      ),
      if (variant == 'search')
        const Padding(
          padding: EdgeInsets.fromLTRB(22, 0, 22, 16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search movies',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  for (final viewport in [
    ('portrait', const Size(320, 720), 1.0),
    ('landscape', const Size(844, 390), 1.0),
    ('large_text', const Size(320, 720), 2.0),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets('Header 视觉回归 ${viewport.$1}/${brightness.name}', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(viewport.$2);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        for (final variant in ['library', 'search', 'favorites', 'loading']) {
          const captureKey = ValueKey('header-capture');
          await tester.pumpWidget(
            MaterialApp(
              theme: buildAppTheme(
                brightness,
              ).copyWith(platform: TargetPlatform.android),
              locale: const Locale('en'),
              localizationsDelegates: AppL10n.localizationsDelegates,
              supportedLocales: AppL10n.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(viewport.$3),
                  padding: const EdgeInsets.only(top: 24),
                  viewPadding: const EdgeInsets.only(top: 24),
                ),
                child: child!,
              ),
              home: Scaffold(
                body: SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: RepaintBoundary(
                      key: captureKey,
                      child: Builder(
                        builder: (context) => ColoredBox(
                          color: appColors(context).bg,
                          child: _header(context, variant),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          // 固定加载动画帧，避免 pumpAndSettle 等待无限动画。
          await tester.pump(const Duration(milliseconds: 200));
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(captureKey),
            matchesGoldenFile(
              'goldens/header_${variant}_${viewport.$1}_${brightness.name}'
              '${variant == 'library' ? _libraryGoldenSuffix : ''}.png',
            ),
          );
          await tester.pumpWidget(const SizedBox.shrink());
        }
      });
    }
  }
}
