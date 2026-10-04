import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/update/update_repository.dart';
import 'package:omm/features/settings/app_changelog_startup_gate.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpGate(
    WidgetTester tester, {
    required SharedPreferences prefs,
    String version = '0.113.5+893',
    String notes = 'fix(floating_tab_bar): 增大激活项圆角\n - 视觉更饱满',
    bool enabled = true,
    void Function()? onFinished,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: const Locale('zh'),
          home: StartupChangelogGate(
            enabled: enabled,
            startDelay: Duration.zero,
            version: version,
            notes: notes,
            onFinished: onFinished ?? () {},
            child: const Scaffold(body: Text('home')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('旧版本与当前版本不同时弹窗展示并记录新版本', (tester) async {
    SharedPreferences.setMockInitialValues({
      UpdateSettingsRepository.lastChangelogVersionKey: '0.113.4+892',
    });
    final prefs = await SharedPreferences.getInstance();
    var finishedCount = 0;

    await pumpGate(
      tester,
      prefs: prefs,
      onFinished: () => finishedCount++,
    );

    expect(find.byType(BuildChangelogDialog), findsOneWidget);
    expect(find.text('更新内容'), findsOneWidget);
    expect(find.text('版本: 0.113.5+893'), findsOneWidget);
    expect(find.text('fix(floating_tab_bar): 增大激活项圆角'), findsOneWidget);
    expect(find.text('- 视觉更饱满'), findsOneWidget);
    // 弹窗未关闭前不允许放行后续启动检查。
    expect(finishedCount, 0);

    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();

    expect(find.byType(BuildChangelogDialog), findsNothing);
    expect(
      prefs.getString(UpdateSettingsRepository.lastChangelogVersionKey),
      '0.113.5+893',
    );
    expect(finishedCount, 1);
  });

  testWidgets('已记录版本与当前一致时不弹窗且立即完成', (tester) async {
    SharedPreferences.setMockInitialValues({
      UpdateSettingsRepository.lastChangelogVersionKey: '0.113.5+893',
    });
    final prefs = await SharedPreferences.getInstance();
    var finishedCount = 0;

    await pumpGate(
      tester,
      prefs: prefs,
      onFinished: () => finishedCount++,
    );

    expect(find.byType(BuildChangelogDialog), findsNothing);
    expect(finishedCount, 1);
  });

  testWidgets('全新安装无记录时不弹窗，静默记录当前版本', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    var finishedCount = 0;

    await pumpGate(
      tester,
      prefs: prefs,
      onFinished: () => finishedCount++,
    );

    expect(find.byType(BuildChangelogDialog), findsNothing);
    expect(finishedCount, 1);
    expect(
      prefs.getString(UpdateSettingsRepository.lastChangelogVersionKey),
      '0.113.5+893',
    );
  });

  testWidgets('无内嵌日志（本地构建）时不弹窗也不写记录', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    var finishedCount = 0;

    await pumpGate(
      tester,
      prefs: prefs,
      version: '',
      notes: '',
      onFinished: () => finishedCount++,
    );

    expect(find.byType(BuildChangelogDialog), findsNothing);
    expect(finishedCount, 1);
    expect(
      prefs.getString(UpdateSettingsRepository.lastChangelogVersionKey),
      isNull,
    );
  });

  testWidgets('enabled 为 false 时不触发，置 true 后才检查', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    Widget app(bool enabled) => ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('zh'),
        home: StartupChangelogGate(
          enabled: enabled,
          startDelay: Duration.zero,
          version: '0.113.5+893',
          notes: 'fix: 修复',
          onFinished: () {},
          child: const Scaffold(body: Text('home')),
        ),
      ),
    );

    await tester.pumpWidget(app(false));
    await tester.pumpAndSettle();
    expect(find.byType(BuildChangelogDialog), findsNothing);
    expect(
      prefs.getString(UpdateSettingsRepository.lastChangelogVersionKey),
      isNull,
    );

    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    // 无记录（全新安装语义）→ 静默记录。
    expect(
      prefs.getString(UpdateSettingsRepository.lastChangelogVersionKey),
      '0.113.5+893',
    );
  });
}
