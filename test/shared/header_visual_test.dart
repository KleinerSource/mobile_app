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

// 所有平台均验证布局；像素基线只在固定 Windows 环境中显式启用。
// CI: header-visual-tests.yml，Windows 2025 / Flutter 3.47.0。
// 本地截图验证：flutter test --no-pub --dart-define=HEADER_GOLDENS=true test/shared/header_visual_test.dart
// Windows 更新基线：在上述命令中增加 --update-goldens，并人工检查差异。
const _compareGoldens = bool.fromEnvironment('HEADER_GOLDENS');

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

void _expectHeaderLayout(WidgetTester tester, String variant, double width) {
  final header = find.byType(PageHeader);
  final config = tester.widget<PageHeader>(header);
  final eyebrow = tester.getRect(find.text(config.eyebrow));
  final title = tester.getRect(find.byWidget(config.title));
  final headerRect = tester.getRect(header);
  expect(headerRect.width, width);
  expect(headerRect.top, 24);
  expect(eyebrow.left, 22);
  expect(eyebrow.top, 40);
  expect(title.left, 22);
  expect(title.top, greaterThanOrEqualTo(eyebrow.bottom + 3));
  expect(headerRect.bottom - title.bottom, greaterThanOrEqualTo(22));

  final toggle = find.byType(MediaViewModeToggle);
  if (variant == 'library' || variant == 'search') {
    expect(tester.getSize(toggle), const Size(99, 31));
    expect(tester.getCenter(toggle).dy, closeTo(title.center.dy, 0.01));
  }
  if (variant == 'library') {
    final filter = find.byType(CompactFilterButton);
    expect(tester.getSize(filter), const Size(37, 29));
    expect(tester.getCenter(filter).dy, closeTo(title.center.dy, 0.01));
    expect(
      tester.getCenter(find.byIcon(Icons.tune_rounded)),
      tester.getCenter(filter),
    );
  }
  for (final element in find.byType(HeaderActionButton).evaluate()) {
    final button = find.byWidget(element.widget);
    final circle = find.descendant(
      of: button,
      matching: find.byType(HeaderActionIcon),
    );
    expect(tester.getSize(button), const Size.square(44));
    expect(tester.getSize(circle), const Size.square(36));
    expect(tester.getCenter(circle), tester.getCenter(button));
    expect(tester.getCenter(button).dy, closeTo(title.center.dy, 0.01));
    final content = find.descendant(
      of: circle,
      matching: find.byWidgetPredicate(
        (widget) => widget is Icon || widget is CircularProgressIndicator,
      ),
    );
    expect(tester.getCenter(content), tester.getCenter(circle));
  }
  if (variant == 'loading') {
    expect(
      tester.getSize(find.byType(CircularProgressIndicator)),
      const Size.square(18),
    );
    final scanButton = tester.widget<HeaderActionButton>(
      find.byWidgetPredicate(
        (widget) =>
            widget is HeaderActionButton && widget.tooltip == 'Scan resources',
      ),
    );
    expect(scanButton.onPressed, isNull);
  }
  final capture = tester.getRect(find.byKey(const ValueKey('header-capture')));
  if (variant == 'search') {
    final search = tester.getRect(find.byType(TextField));
    expect(search.left, 22);
    expect(search.top, headerRect.bottom);
    expect(capture.bottom - search.bottom, 16);
  } else {
    expect(capture, headerRect);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (_compareGoldens) {
      if (!Platform.isWindows) {
        throw StateError(
          'Header 截图基线需要 Windows；其他平台请不传 HEADER_GOLDENS，执行布局回归。',
        );
      }
      await _loadFonts();
    }
  });

  for (final viewport in [
    ('portrait', const Size(320, 720), 1.0),
    ('landscape', const Size(844, 390), 1.0),
    ('large_text', const Size(320, 720), 2.0),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets('Header 布局与视觉回归 ${viewport.$1}/${brightness.name}', (
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
          _expectHeaderLayout(tester, variant, viewport.$2.width);
          if (_compareGoldens) {
            await expectLater(
              find.byKey(captureKey),
              matchesGoldenFile(
                'goldens/header_${variant}_${viewport.$1}_${brightness.name}.png',
              ),
            );
          }
          await tester.pumpWidget(const SizedBox.shrink());
        }
      });
    }
  }
}
