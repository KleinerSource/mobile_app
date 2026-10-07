import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/resource.dart';
import 'package:omm/core/sources/media/media_source_providers.dart';
import 'package:omm/core/sources/media/omm_media_source_adapter.dart';
import 'package:omm/features/oh_my_media/actors/actor_management_page.dart';
import 'package:omm/features/oh_my_media/actor_associations/actor_associations_page.dart';
import 'package:omm/features/oh_my_media/audio/audio_management_page.dart';
import 'package:omm/features/oh_my_media/audio/audio_models.dart';
import 'package:omm/features/oh_my_media/audio/audio_providers.dart';
import 'package:omm/features/oh_my_media/audio/audio_repository.dart';
import 'package:omm/features/oh_my_media/mappings/mapping_rules_page.dart';
import 'package:omm/features/oh_my_media/mappings/mappings_repository.dart';
import 'package:omm/features/oh_my_media/movies/movies_page.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';
import 'package:omm/features/oh_my_media/resources/resource_list_page.dart';
import 'package:omm/features/oh_my_media/resources/resource_movies_page.dart';
import 'package:omm/features/oh_my_media/resources/resources_repository.dart';
import 'package:omm/features/oh_my_media/tasks/task_center_page.dart';
import 'package:omm/features/oh_my_media/tasks/task_center_provider.dart';
import 'package:omm/features/oh_my_media/tasks/task_model.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/features/translation/modal_transcription_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

class _Tasks extends TaskCenterNotifier {
  @override
  List<TaskItem> build() => [];
}

class _TaskMeta extends TaskCenterMetaNotifier {
  @override
  TaskCenterMeta build() => const TaskCenterMeta(total: 321);

  void setRunning(int running) {
    state = TaskCenterMeta(total: 321, stats: {'running': running});
  }
}

class _Audio extends Fake implements AudioRepository {
  _Audio(this.ready, this.total);
  final Future<bool> ready;
  final int total;

  @override
  Future<AudioAssetListResult> listAssets({
    int limit = 20,
    int offset = 0,
    String? search,
  }) async {
    if (await ready) throw StateError('测试加载失败');
    return AudioAssetListResult(items: const [], total: total);
  }
}

Future<void> _pumpPage(
  WidgetTester tester,
  Widget page,
  Completer<bool> ready,
  int total, {
  double scale = 1,
  double? bottomInset,
}) async {
  SharedPreferences.setMockInitialValues({
    'privacy.app_switcher_shield': false,
  });
  final prefs = await SharedPreferences.getInstance();
  final dio = Dio(BaseOptions(baseUrl: 'https://headers.test/api'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (await ready.future) {
          handler.reject(
            DioException(requestOptions: options, error: '测试加载失败'),
          );
        } else {
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {
                'success': true,
                'data':
                    options.path.endsWith('/movies') ||
                        options.queryParameters['scope'] == 'association'
                    ? {
                        'items': [],
                        'total_count': total,
                        'limit': 50,
                        'offset': 0,
                      }
                    : [],
                'total_count': total,
                'limit': 50,
                'offset': 0,
              },
            ),
          );
        }
      },
    ),
  );
  final client = ApiClient(dio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        requiredApiClientProvider.overrideWithValue(client),
        ommMediaSourceProvider.overrideWithValue(OmmMediaSourceAdapter(client)),
        imageUrlBuilderProvider.overrideWithValue((_) => ''),
        audioRepositoryProvider.overrideWithValue(_Audio(ready.future, total)),
        taskCenterProvider.overrideWith(_Tasks.new),
        taskCenterMetaProvider.overrideWith(_TaskMeta.new),
        modalTranscriptionConfigProvider.overrideWith(
          (ref) => throw StateError('未配置'),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            padding: bottomInset == null
                ? MediaQuery.paddingOf(context)
                : MediaQuery.paddingOf(context).copyWith(bottom: bottomInset),
          ),
          child: child!,
        ),
        locale: const Locale('zh'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: page,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void _expectHeader(WidgetTester tester, String section, String countText) {
  final header = find.byType(SettingsSubPageHeader);
  final label = find.descendant(of: header, matching: find.text(section));
  final count = find.descendant(of: header, matching: find.text(countText));
  expect(label, findsOneWidget);
  expect(count, findsOneWidget);
  expect(
    tester.widget<Text>(label).style!.fontSize,
    lessThan(tester.widget<Text>(count).style!.fontSize!),
  );
  expect(tester.getTopLeft(label).dx, tester.getTopLeft(count).dx);
  expect(
    tester.getBottomRight(label).dy,
    lessThan(tester.getTopLeft(count).dy),
  );
  expect(
    tester.getRect(find.byTooltip('返回')).right,
    lessThanOrEqualTo(tester.getRect(count).left),
  );
  expect(tester.takeException(), isNull);
}

void main() {
  for (final total in [0, 321]) {
    testWidgets('影片库加载后显示真实统计，包括零数量：$total', (tester) async {
      final ready = Completer<bool>();
      await _pumpPage(tester, const Scaffold(body: MoviesPage()), ready, total);
      final count = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.textSpan?.toPlainText().contains('部影片') ?? false),
      );
      expect(
        tester.widget<Text>(count).textSpan!.toPlainText(),
        startsWith('—'),
      );
      ready.complete(false);
      await tester.pumpAndSettle();
      final number = tester.widget<Text>(count);
      expect(number.textSpan!.toPlainText(), startsWith('$total'));
      expect(
        tester.widget<Text>(find.text('影片库')).style!.fontSize,
        lessThan(number.style!.fontSize!),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('资源管理页滚动布局穿透底部安全区', (tester) async {
    final ready = Completer<bool>();
    await _pumpPage(
      tester,
      const ResourceListPage(kind: ResourceKind.genre),
      ready,
      321,
      bottomInset: 34,
    );

    final scaffold = find.byType(Scaffold).first;
    final safeArea = find
        .descendant(of: scaffold, matching: find.byType(SafeArea))
        .first;
    expect(tester.widget<SafeArea>(safeArea).bottom, isFalse);
    expect(tester.getRect(safeArea).bottom, tester.getRect(scaffold).bottom);
    expect(
      MediaQuery.paddingOf(
        tester.element(find.byType(SettingsFixedHeaderLayout)),
      ),
      isA<EdgeInsets>().having((padding) => padding.bottom, 'bottom', 34),
    );
    final listPadding = tester.widget<SliverPadding>(
      find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(SliverPadding),
      ).first,
    );
    expect(listPadding.padding.resolve(TextDirection.ltr).bottom, 80);
    ready.complete(false);
    await tester.pumpAndSettle();
  });

  final pages = <(Widget, String, String)>[
    (const ResourceListPage(kind: ResourceKind.genre), '类型管理', '个类型'),
    (const ResourceListPage(kind: ResourceKind.tag), '标签管理', '个标签'),
    (const ResourceListPage(kind: ResourceKind.series), '系列管理', '个系列'),
    (const ActorManagementPage(), '演员管理', '位演员'),
    (const AudioManagementPage(), '音频管理', '个资产'),
    (const ActorAssociationsPage(), '演员关联', '个关联'),
    (const MappingRulesPage(type: MappingType.tag), '标签映射', '条映射'),
  ];
  for (final (page, section, suffix) in pages) {
    for (final total in [0, 321]) {
      testWidgets('$section 加载前后使用小字名称和大字统计：$total', (tester) async {
        final ready = Completer<bool>();
        await _pumpPage(tester, page, ready, total);
        _expectHeader(tester, section, '— $suffix');
        ready.complete(false);
        await tester.pumpAndSettle();
        _expectHeader(tester, section, '$total $suffix');
      });
    }
  }

  testWidgets('请求失败时统计保持未知，不显示虚假的零数量', (tester) async {
    final ready = Completer<bool>();
    await _pumpPage(
      tester,
      const ResourceListPage(kind: ResourceKind.genre),
      ready,
      321,
    );
    ready.complete(true);
    await tester.pumpAndSettle();
    _expectHeader(tester, '类型管理', '— 个类型');
  });

  testWidgets('演员关联请求失败时统计保持未知', (tester) async {
    final ready = Completer<bool>();
    await _pumpPage(tester, const ActorAssociationsPage(), ready, 321);
    ready.complete(true);
    await tester.pumpAndSettle();
    _expectHeader(tester, '演员关联', '— 个关联');
  });

  for (final kind in ResourceKind.values) {
    for (final total in [0, 321]) {
      testWidgets('${kind.value} 作品横幅只有分类和大字数量，窄屏双倍字体仍保留固定名称：$total', (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final ready = Completer<bool>();
        await _pumpPage(
          tester,
          ResourceMoviesPage(
            kind: kind,
            resource: const ResourceItem(id: 1, name: '资源名称', movieCount: 5),
          ),
          ready,
          total,
          scale: 2,
        );
        final hero = find.byType(FlexibleSpaceBar);
        expect(
          find.descendant(of: hero, matching: find.text('5 部影片')),
          findsOneWidget,
        );
        ready.complete(false);
        await tester.pumpAndSettle();
        final label = find.descendant(of: hero, matching: find.text(kind.icon));
        final count = find.descendant(
          of: hero,
          matching: find.text('$total 部影片'),
        );
        expect(
          find.descendant(of: hero, matching: find.byType(Text)),
          findsNWidgets(2),
        );
        expect(
          tester.widget<Text>(count).style!.fontSize,
          greaterThan(tester.widget<Text>(label).style!.fontSize!),
        );
        expect(find.text('资源名称'), findsOneWidget);
        expect(
          tester.widget<SliverAppBar>(find.byType(SliverAppBar)).pinned,
          isTrue,
        );
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(find.byTooltip('返回').hitTestable(), findsOneWidget);
        expect(find.text('资源名称').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('任务中心使用服务端总数而非已加载任务条数', (tester) async {
    final ready = Completer<bool>();
    await _pumpPage(tester, const TaskCenterPage(), ready, 0);
    await tester.pumpAndSettle();
    _expectHeader(tester, '任务中心', '321 项任务');
    expect(
      tester
          .widget<SettingsSubPageHeader>(find.byType(SettingsSubPageHeader))
          .subtitle,
      '共 321 条记录',
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TaskCenterPage)),
    );
    (container.read(taskCenterMetaProvider.notifier) as _TaskMeta).setRunning(
      2,
    );
    await tester.pump();
    expect(
      tester
          .widget<SettingsSubPageHeader>(find.byType(SettingsSubPageHeader))
          .subtitle,
      '2 条任务正在执行 · 共 321 条记录',
    );
    ready.complete(false);
  });

  testWidgets('音频管理仅在搜索时显示第三行关键词，清空后隐藏', (tester) async {
    final ready = Completer<bool>();
    await _pumpPage(tester, const AudioManagementPage(), ready, 321);
    ready.complete(false);
    await tester.pumpAndSettle();
    final header = find.byType(SettingsSubPageHeader);
    expect(tester.widget<SettingsSubPageHeader>(header).subtitle, isNull);
    await tester.enterText(find.byType(TextField), '  关键词  ');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    _expectHeader(tester, '音频管理', '321 个资产');
    expect(tester.widget<SettingsSubPageHeader>(header).subtitle, '搜索：关键词');
    await tester.enterText(find.byType(TextField), '');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(tester.widget<SettingsSubPageHeader>(header).subtitle, isNull);
  });
}
