import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/home/home_layout.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('编辑面板可以切换模块显示状态并保存', (tester) async {
    HomeLayoutPreferences? saved;
    final modules = [
      HomeLayoutModule(
        id: 'first',
        title: '第一模块',
        builder: (_) => const SizedBox(),
      ),
      HomeLayoutModule(
        id: 'second',
        title: '第二模块',
        builder: (_) => const SizedBox(),
      ),
    ];
    final config = HomeLayoutEditorConfig(
      modules: modules,
      preferences: reconcileHomeLayoutPreferences(
        modules,
        const HomeLayoutPreferences(),
      ),
      onSave: (preferences) async => saved = preferences,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('zh'),
        theme: buildAppTheme(Brightness.dark),
        home: Builder(
          builder: (context) => Scaffold(
            body: HomeLayoutEditButton(
              onPressed: () =>
                  showHomeLayoutEditor(context: context, config: config),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('编辑布局'));
    await tester.pumpAndSettle();
    expect(find.text('第一模块'), findsOneWidget);
    expect(find.text('第二模块'), findsOneWidget);

    final button = find.byType(OutlinedButton);
    final scaffoldWidth = tester.getSize(find.byType(Scaffold)).width;
    expect(tester.getSize(button).width, lessThan(scaffoldWidth * 0.75));
    expect(tester.getRect(button).center.dx, closeTo(scaffoldWidth / 2, 1));

    final moduleRow = find
        .ancestor(of: find.text('第一模块'), matching: find.byType(Container))
        .first;
    final decoration =
        tester.widget<Container>(moduleRow).decoration! as BoxDecoration;
    expect(
      decoration.color,
      Color.alphaBlend(AppColors.dark.surfaceAlt, AppColors.dark.bg),
    );

    await tester.tap(find.byType(Switch).first);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(saved?.hidden, contains('first'));
    expect(saved?.order, ['first', 'second']);
  });

  test('布局偏好按服务器持久化并能恢复', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = HomeLayoutPreferencesRepository(prefs);
    const preferences = HomeLayoutPreferences(
      order: ['library_stats', 'latest_added'],
      hidden: {'latest_added'},
    );

    await repository.save('server/1', preferences);

    expect(repository.load('server/1').order, preferences.order);
    expect(repository.load('server/1').hidden, preferences.hidden);
    expect(repository.load('server/2').order, isEmpty);
  });

  test('新增模块追加到保存顺序末尾，未知模块和隐藏项会被清理', () {
    final modules = [
      HomeLayoutModule(
        id: 'first',
        title: '第一',
        builder: (_) => const SizedBox(),
      ),
      HomeLayoutModule(
        id: 'second',
        title: '第二',
        builder: (_) => const SizedBox(),
      ),
      HomeLayoutModule(
        id: 'new',
        title: '新增',
        builder: (_) => const SizedBox(),
      ),
    ];
    const saved = HomeLayoutPreferences(
      order: ['second', 'missing', 'second'],
      hidden: {'first', 'missing'},
    );

    final result = reconcileHomeLayoutPreferences(modules, saved);

    expect(result.order, ['second', 'first', 'new']);
    expect(result.hidden, {'first'});
  });
}
