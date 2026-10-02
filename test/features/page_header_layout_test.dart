import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/movie_detail_scaffold.dart';
import 'package:omm/features/home/hero_backdrop.dart';
import 'package:omm/shared/filter_chip.dart';
import 'package:omm/shared/header_action_button.dart';
import 'package:omm/shared/page_header.dart';

Widget _app(Widget page, {double scale = 1}) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: page),
);

void main() {
  for (final size in [const Size(320, 720), const Size(844, 390)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('圆形操作在 ${size.width}/$scale 下点击与加载区域不跳动', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final loading = ValueNotifier(false);
        addTearDown(loading.dispose);
        var taps = 0;
        await tester.pumpWidget(
          _app(
            ValueListenableBuilder<bool>(
              valueListenable: loading,
              builder: (context, busy, _) => PageHeader(
                eyebrow: '我的',
                title: Text(
                  '收藏',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                trailing: HeaderActionButton(
                  icon: Icons.cloud_download_outlined,
                  tooltip: '扫描资源',
                  loading: busy,
                  onPressed: busy ? null : () => taps++,
                ),
              ),
            ),
            scale: scale,
          ),
        );
        final button = find.byType(HeaderActionButton);
        final before = tester.getRect(button);
        expect(before.size, const Size.square(48));
        final circle = find.byType(HeaderActionIcon);
        expect(tester.getSize(circle), const Size.square(36));
        expect(tester.getCenter(circle), before.center);
        expect(
          tester.getCenter(find.byIcon(Icons.cloud_download_outlined)),
          before.center,
        );
        // 圆形以外的点击留白同样有效。
        await tester.tapAt(before.topLeft + const Offset(2, 2));
        expect(taps, 1);
        loading.value = true;
        await tester.pump();
        expect(tester.getRect(button), before);
        expect(
          tester.getCenter(find.byType(CircularProgressIndicator)),
          before.center,
        );
        await tester.tap(button);
        expect(taps, 1);
        expect(
          tester.widget<IconButton>(find.byType(IconButton)).onPressed,
          isNull,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('共享筛选按钮在 ${size.width}/$scale 的拉伸工具栏中仍保持内容居中', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _app(
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  Expanded(
                    child: CompactFilterButton(
                      label: '筛选',
                      icon: Icons.tune_rounded,
                      active: false,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ),
            scale: scale,
          ),
        );
        final button = tester.getRect(find.byType(CompactFilterButton));
        final icon = tester.getRect(find.byIcon(Icons.tune_rounded));
        final label = tester.getRect(find.text('筛选'));
        expect((icon.left + label.right) / 2, closeTo(button.center.dx, 0.01));
        expect(icon.center.dy, closeTo(button.center.dy, 0.01));
        expect(label.center.dy, closeTo(button.center.dy, 0.01));
        expect(tester.takeException(), isNull);
      });

      testWidgets('长标题与操作在 ${size.width}/$scale 下不溢出', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        const title = '这是一个用于验证窄屏和放大字体的长页面标题';
        await tester.pumpWidget(
          _app(
            SettingsSubPageHeader(
              eyebrow: '设置',
              title: title,
              subtitle: '页面说明',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.more_horiz),
                  ),
                ],
              ),
            ),
            scale: scale,
          ),
        );
        final back = tester.getRect(find.byTooltip('返回'));
        final text = tester.getRect(find.text(title));
        expect(back.right, lessThanOrEqualTo(text.left));
        expect(back.center.dy, closeTo(text.center.dy, 1));
        expect(tester.getTopLeft(find.text('设置')).dx, closeTo(text.left, 1));
        expect(tester.getTopLeft(find.text('页面说明')).dx, closeTo(text.left, 1));
        expect(tester.takeException(), isNull);
      });

      for (final count in [null, 0, 123456]) {
        testWidgets('统计抬头 $count 在 ${size.width}/$scale 下保持层级和返回位置', (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          const section = '这是需要显示统计数量的长板块名称';
          final countText = '${count ?? '—'} 个类型';
          await tester.pumpWidget(
            _app(
              SettingsSubPageHeader(
                eyebrow: '媒体库',
                title: section,
                count: count,
                countSuffix: '个类型',
                subtitle: '页面说明',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.more_horiz),
                    ),
                  ],
                ),
              ),
              scale: scale,
            ),
          );
          final label = find.text(section);
          final countLabel = find.text(countText);
          final back = tester.getRect(find.byTooltip('返回'));
          final number = tester.getRect(countLabel);
          expect(
            tester.widget<Text>(label).style!.fontSize,
            lessThan(tester.widget<Text>(countLabel).style!.fontSize!),
          );
          expect(tester.getTopLeft(label).dx, number.left);
          expect(tester.getTopLeft(find.text('页面说明')).dx, number.left);
          expect(back.right, lessThanOrEqualTo(number.left));
          expect(back.center.dy, closeTo(number.center.dy, 1));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('隐藏返回时取消占位，标题恢复左侧留白', (tester) async {
    await tester.pumpWidget(
      _app(
        const SettingsSubPageHeader(
          eyebrow: '设置',
          title: '偏好设置',
          showBackButton: false,
        ),
      ),
    );
    expect(find.byTooltip('返回'), findsNothing);
    expect(tester.getTopLeft(find.text('偏好设置')).dx, 22);
    expect(
      tester.widget<Text>(find.text('偏好设置')).style!.fontSize,
      greaterThan(tester.widget<Text>(find.text('设置')).style!.fontSize!),
    );
  });

  testWidgets('详情滚动后导航标题和返回固定，返回只弹出一层', (tester) async {
    final arts = ValueNotifier<List<HeroArt>>(const []);
    final position = ValueNotifier(0.0);
    addTearDown(arts.dispose);
    addTearDown(position.dispose);
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: MovieDetailScaffold(
                    title: '详情导航标题',
                    heroArts: arts,
                    heroPosition: position,
                    hero: const SizedBox(height: 320),
                    slivers: const [
                      SliverToBoxAdapter(child: SizedBox(height: 1600)),
                    ],
                    actions: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.more_horiz),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            child: const Text('上一页'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('上一页'));
    await tester.pumpAndSettle();
    final title = find.text('详情导航标题');
    final back = find.byTooltip('返回');
    final before = tester.getRect(title);
    expect(tester.getRect(back).right, lessThanOrEqualTo(before.left));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(tester.getRect(title), before);
    expect(back.hitTestable(), findsOneWidget);
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.text('上一页'), findsOneWidget);
    expect(find.byType(MovieDetailScaffold), findsNothing);
  });
}
