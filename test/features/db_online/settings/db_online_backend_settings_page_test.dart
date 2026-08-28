import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/features/db_online/settings/db_online_backend_settings_page.dart';
import 'package:omm/features/settings/server_settings_page.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('当前 DBO 服务器在服务器设置中显示后台配置入口', (tester) async {
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: _localizedApp(const ServerSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DBO 后台配置'), findsOneWidget);
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
    final data = _config();
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': data}),
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
