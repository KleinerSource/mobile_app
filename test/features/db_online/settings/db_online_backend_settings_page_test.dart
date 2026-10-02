import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/features/db_online/settings/db_online_backend_config.dart';
import 'package:omm/features/db_online/settings/db_online_backend_settings_page.dart';
import 'package:omm/features/settings/server_settings_page.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('当前 DBO 服务器在服务器设置中直接显示后台配置分区', (tester) async {
    SharedPreferences.setMockInitialValues({
      'server.servers': jsonEncode([
        {
          'id': 'dbo',
          'name': 'DB Online',
          'lines': [
            {
              'id': 'dbo-line',
              'name': '主线路',
              'base_url': 'https://dbo.example',
            },
          ],
          'active_line_id': 'dbo-line',
          'project_name': 'db_online',
        },
      ]),
      'server.active_server_id': 'dbo',
    });
    final prefs = await SharedPreferences.getInstance();
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api'))
      ..httpClientAdapter = _BackendConfigAdapter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          requiredApiClientProvider.overrideWithValue(ApiClient(dio)),
        ],
        child: _localizedApp(const ServerSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('JavDB API'), findsOneWidget);
    expect(find.text('DBO 后台配置'), findsNothing);
    expect(find.text('服务器列表'), findsNothing);
    expect(find.text('DB Online 数据源'), findsNothing);
  });

  testWidgets('DBO 后台配置读取分区并按分区提交 PUT', (tester) async {
    final adapter = _BackendConfigAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api'))
      ..httpClientAdapter = adapter;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          requiredApiClientProvider.overrideWithValue(ApiClient(dio)),
        ],
        child: _localizedApp(const DboBackendSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DB ONLINE'), findsOneWidget);
    expect(find.text('DB Online 后端'), findsOneWidget);
    expect(find.text('配置 DB Online 后端'), findsNothing);
    expect(find.text('JavDB API'), findsOneWidget);
    await tester.tap(find.text('JavDB API'));
    await tester.pumpAndSettle();

    expect(find.text('API 地址'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).first,
      'https://changed.example',
    );
    for (var i = 0; i < 6 && find.text('保存设置').evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    expect(find.text('保存设置'), findsOneWidget);
    await tester.tap(find.text('保存设置'));
    await tester.pumpAndSettle();

    expect(adapter.lastMethod, 'PUT');
    expect(adapter.lastPath, '/api/config');
    expect(adapter.lastBody, {
      'javdb_api': {
        'host': 'https://changed.example',
        'authorization': '********',
        'timeout': 30,
        'image_mode': 'decrypt',
        'url_replace_new': '',
      },
    });
  });

  testWidgets('DBO 后端加载、失败和重试成功始终显示双抬头', (tester) async {
    final pending = Completer<Object?>();
    final adapter = _BackendConfigAdapter()..response = pending.future;
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api'))
      ..httpClientAdapter = adapter;
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          requiredApiClientProvider.overrideWithValue(ApiClient(dio)),
        ],
        child: _localizedApp(const DboBackendSettingsPage()),
      ),
    );
    await tester.pump();
    final header = find.byType(SettingsSubPageHeader);
    final before = tester.getRect(header);
    expect(find.text('DB ONLINE'), findsOneWidget);
    expect(find.text('DB Online 后端'), findsOneWidget);
    expect(find.byTooltip('返回'), findsOneWidget);
    expect(tester.widget<SettingsSubPageHeader>(header).subtitle, isNull);

    pending.complete({'success': false, 'error': '测试配置请求失败'});
    await tester.pumpAndSettle();
    expect(find.text('测试配置请求失败'), findsOneWidget);
    expect(tester.getRect(header), before);
    adapter.response = null;
    await tester.tap(find.text('重试'));
    await tester.pump();
    expect(tester.getRect(header), before);
    await tester.pumpAndSettle();
    expect(find.text('JavDB API'), findsOneWidget);
    expect(find.text('测试配置请求失败'), findsNothing);
    expect(find.text('配置 DB Online 后端'), findsNothing);
    expect(tester.getRect(header), before);
    expect(tester.takeException(), isNull);
  });

  for (final section in dboBackendConfigGroups.expand(
    (group) => group.sections,
  )) {
    testWidgets('${section.basePath} 分区只显示两层抬头，滚动后仍可返回', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            requiredApiClientProvider.overrideWithValue(
              ApiClient(
                Dio(BaseOptions(baseUrl: 'http://test/api'))
                  ..httpClientAdapter = _BackendConfigAdapter(),
              ),
            ),
          ],
          child: _localizedApp(
            Navigator(
              onGenerateInitialRoutes: (_, _) => [
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('后端配置入口')),
                ),
                MaterialPageRoute<void>(
                  builder: (_) => DboBackendConfigDetailPage(
                    section: section,
                    config: const {},
                  ),
                ),
              ],
              onGenerateRoute: (_) => null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final header = find.byType(SettingsSubPageHeader);
      final l = AppL10n.of(tester.element(header));
      final title = find.descendant(
        of: header,
        matching: find.text(section.title(l)),
      );
      final back = find.byTooltip('返回');
      expect(find.text('DB ONLINE'), findsOneWidget);
      expect(title, findsOneWidget);
      expect(find.text(l.dbOnlineSectionScopeHint), findsNothing);
      expect(
        find.text('DB ONLINE · ${l.dbOnlineBackendConfigTitle}'),
        findsNothing,
      );
      expect(tester.widget<SettingsSubPageHeader>(header).subtitle, isNull);
      expect(
        tester.getRect(back).right,
        lessThanOrEqualTo(tester.getRect(title).left),
      );
      expect(
        tester.getRect(back).center.dy,
        closeTo(tester.getRect(title).center.dy, 1),
      );
      final before = tester.getRect(header);
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.getRect(header), before);
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.text('后端配置入口'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Widget _localizedApp(Widget home) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: home,
  );
}

class _BackendConfigAdapter implements HttpClientAdapter {
  Future<Object?>? response;
  String? lastMethod;
  String? lastPath;
  Map<String, dynamic>? lastBody;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastMethod = options.method;
    lastPath = options.uri.path;
    if (options.data is Map) {
      lastBody = Map<String, dynamic>.from(options.data as Map);
    }
    return ResponseBody.fromString(
      jsonEncode(await response ?? {'success': true, 'data': _config()}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  Map<String, dynamic> _config() {
    return {
      'javdb_api': {
        'host': 'https://javdb.example',
        'authorization': '********',
        'timeout': 30,
        'image_mode': 'decrypt',
        'url_replace_new': '',
      },
      'subscription': {'enabled': false},
      'proxy': {
        'main': {'enabled': false, 'protocol': 'http'},
      },
      'downloader': {
        'aria2': {'enabled': false},
        'qbittorrent': {'enabled': false},
        'pan115': {'enabled': false},
        'thunder': {'enabled': false},
      },
      'mediaserver': {
        'player': {
          'enabled': true,
          'autoplay': true,
          'captions': true,
          'pip': true,
          'fullscreen': true,
          'keyboard': true,
        },
      },
    };
  }
}
