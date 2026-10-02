import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/api_exception.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/features/db_online/settings/db_online_backend_config.dart';
import 'package:omm/features/db_online/settings/db_online_backend_settings_page.dart';
import 'package:omm/features/db_online/settings/db_online_media_library_config_widgets.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

void main() {
  test('媒体库辅助接口发送草稿，字幕管理兼容 code 响应并传递扫描模式', () async {
    final backend = _MediaBackend();
    final api = backend.client().dbOnline;
    final libraries = await api.mediaServerLibraries('fnmedia', {
      'host': 'draft',
      'password': '********',
    });
    expect(libraries.first['id'], '12345678901234567890');
    expect(backend.request('/fnmedia/libraries').data, {
      'host': 'draft',
      'password': '********',
    });
    expect(
      await api.libraryTaskStats(subtitles: true),
      containsPair('total_count', 12),
    );
    await api.startLibraryTask(subtitles: true, mode: 'full');
    expect(backend.request('/subtitle/scan').queryParameters, {'mode': 'full'});
    await api.libraryTaskProgress(subtitles: true);
    backend.subtitleError = true;
    await expectLater(
      api.libraryTaskStats(subtitles: true),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          '字幕统计失败',
        ),
      ),
    );
  });

  testWidgets('实验性开关依赖与网页一致，缺少条件时禁用并在保存时关闭', (tester) async {
    final backend = _MediaBackend();
    backend.config['javdb_api'] = {'authorization': ''};
    backend.config['telegram'] = {'enabled': false};
    backend.config['external_magnet'] = {'builtin_magnets': []};
    await _open(tester, backend, 'experimental');
    expect(
      tester
          .widget<SettingsSwitch>(
            find.byKey(const ValueKey('auto_sync_watched_online')),
          )
          .onChanged,
      isNull,
    );
    expect(find.text('需要先配置 JavDB Authorization'), findsWidgets);
    await _reach(
      tester,
      find.byKey(const ValueKey('webhook_auto_blacklist_on_delete')),
    );
    expect(
      tester
          .widget<SettingsSwitch>(
            find.byKey(const ValueKey('webhook_auto_blacklist_on_delete')),
          )
          .onChanged,
      isNull,
    );
    await _reach(
      tester,
      find.byKey(const ValueKey('builtin_magnets_in_subscription')),
    );
    expect(
      tester
          .widget<SettingsSwitch>(
            find.byKey(const ValueKey('builtin_magnets_in_subscription')),
          )
          .onChanged,
      isNull,
    );
    await _reach(tester, find.byKey(const ValueKey('fetch_video_overview')));
    expect(
      tester
          .widget<SettingsSwitch>(
            find.byKey(const ValueKey('fetch_video_overview')),
          )
          .onChanged,
      isNotNull,
    );
    await _save(tester);
    final saved = backend.lastSaved!['experimental'] as Map;
    expect(saved['fetch_video_overview'], isTrue);
    expect(
      saved.entries
          .where((entry) => entry.key != 'fetch_video_overview')
          .every((entry) => entry.value == false),
      isTrue,
    );
    expect(backend.lastSaved!.keys, ['experimental']);
  });

  testWidgets('配置前置条件后实验性同步开关可以修改并按分区保存', (tester) async {
    final backend = _MediaBackend();
    await _open(tester, backend, 'experimental');
    final field = find.byKey(const ValueKey('auto_sync_watched_online'));
    expect(tester.widget<SettingsSwitch>(field).onChanged, isNotNull);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await _save(tester);
    expect(
      (backend.lastSaved!['experimental'] as Map)['auto_sync_watched_online'],
      isFalse,
    );
  });

  for (final name in ['emby', 'jellyfin', 'fnmedia']) {
    testWidgets('$name 从当前草稿获取媒体库、多选并保留掩码与字符串 ID', (tester) async {
      final backend = _MediaBackend();
      await _open(tester, backend, 'mediaserver.$name');
      await tester.enterText(find.byKey(const ValueKey('host')), 'draft-$name');
      await _reach(tester, find.byType(DbOnlineMediaLibrariesField));
      await tester.tap(find.widgetWithText(OutlinedButton, '全部媒体库'));
      await tester.pumpAndSettle();
      final request = backend.request('/$name/libraries');
      expect((request.data as Map)['host'], 'draft-$name');
      expect(
        (request.data as Map)[name == 'fnmedia' ? 'password' : 'api_key'],
        '********',
      );
      await tester.tap(find.text('电影'));
      await tester.tap(find.text('收藏'));
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      expect(find.text('已选 2 个媒体库'), findsOneWidget);
      await _save(tester);
      final saved = (backend.lastSaved!['mediaserver'] as Map)[name] as Map;
      expect(saved['library_ids'], ['12345678901234567890', 'collection']);
      expect(saved['host'], 'draft-$name');
      expect((backend.lastSaved!['mediaserver'] as Map).keys, [name]);
    });
  }

  testWidgets('媒体库选择支持失败重试、取消草稿和清空选择以搜索全部', (tester) async {
    final backend = _MediaBackend()..failLibraries = true;
    ((backend.config['mediaserver'] as Map)['emby'] as Map)['library_ids'] = [
      'saved',
    ];
    await _open(tester, backend, 'mediaserver.emby');
    await _reach(tester, find.byType(DbOnlineMediaLibrariesField));
    await tester.tap(find.widgetWithText(OutlinedButton, '已选 1 个媒体库'));
    await tester.pumpAndSettle();
    expect(find.text('媒体库请求失败'), findsOneWidget);
    backend.failLibraries = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('电影'));
    await tester.tap(find.widgetWithText(OutlinedButton, '取消'));
    await tester.pumpAndSettle();
    expect(find.text('已选 1 个媒体库'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, '已选 1 个媒体库'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '全部媒体库'));
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, '全部媒体库'), findsOneWidget);
    await _save(tester);
    expect(
      ((backend.lastSaved!['mediaserver'] as Map)['emby']
          as Map)['library_ids'],
      isEmpty,
    );
  });

  testWidgets('媒体库连接测试使用草稿并显示版本，未启用时禁用测试', (tester) async {
    final backend = _MediaBackend();
    await _open(tester, backend, 'mediaserver.fnmedia');
    await _reach(tester, find.widgetWithText(OutlinedButton, '测试连接'));
    await tester.tap(find.widgetWithText(OutlinedButton, '测试连接'));
    await tester.pumpAndSettle();
    expect(find.text('连接正常 · 1.2.3'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('enabled')));
    await tester.pumpAndSettle();
    await _reach(tester, find.widgetWithText(OutlinedButton, '测试连接'));
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '测试连接'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('播放器自定义控制与速度按钮保留至少一项，默认速度随移除调整', (tester) async {
    final backend = _MediaBackend();
    final player = (backend.config['mediaserver'] as Map)['player'] as Map;
    player['controls'] = ['play'];
    player['speed_options'] = [1, 2];
    player['default_speed'] = 1;
    await _open(tester, backend, 'mediaserver.player');
    await _reach(tester, find.byKey(const ValueKey('controls.play')));
    await tester.tap(find.byKey(const ValueKey('controls.play')));
    await tester.pumpAndSettle();
    await _reach(tester, find.byKey(const ValueKey('speed_options.1')));
    await tester.tap(find.byKey(const ValueKey('speed_options.1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('speed_options.2')));
    await tester.pumpAndSettle();
    await _save(tester);
    final saved = (backend.lastSaved!['mediaserver'] as Map)['player'] as Map;
    expect(saved['controls'], ['play']);
    expect(saved['speed_options'], [2]);
    expect(saved['default_speed'], 2);
  });

  testWidgets('缓存计划快捷按钮只保存计划，刷新展示进度并更新统计', (tester) async {
    final backend = _MediaBackend();
    await _open(tester, backend, 'mediaserver');
    await tester.tap(find.text('每 6 小时'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('library_cache_schedule')),
          )
          .controller!
          .text,
      '0 */6 * * *',
    );
    await _reach(tester, find.widgetWithText(OutlinedButton, '刷新入库缓存'));
    await tester.tap(find.widgetWithText(OutlinedButton, '刷新入库缓存'));
    await _frames(tester);
    expect(
      backend.requests
          .where(
            (request) => request.uri.path.endsWith('/library/cache/refresh'),
          )
          .length,
      1,
    );
    await tester.pump(const Duration(milliseconds: 520));
    await _frames(tester);
    expect(find.text('已完成 2 / 4 项'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 520));
    await _frames(tester);
    expect(find.text('缓存 / 实际总数：4 / 4'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await _save(tester);
    expect(backend.lastSaved, {
      'mediaserver': {'library_cache_schedule': '0 */6 * * *'},
    });
  });

  testWidgets('媒体库能力缺失时禁止刷新且不请求统计', (tester) async {
    final backend = _MediaBackend()..mediaLibrary = false;
    await _open(tester, backend, 'mediaserver');
    await _reach(tester, find.widgetWithText(OutlinedButton, '刷新入库缓存'));
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '刷新入库缓存'))
          .onPressed,
      isNull,
    );
    expect(
      backend.requests.where(
        (request) => request.uri.path.endsWith('/library/cache/stats'),
      ),
      isEmpty,
    );
  });

  testWidgets('字幕目录、扩展名和分钟间隔按数组保存，支持完整扫描与忙碌任务', (tester) async {
    final backend = _MediaBackend()..subtitleConflict = true;
    await _open(tester, backend, 'subtitle');
    await tester.enterText(
      find.byKey(const ValueKey('directories')),
      '/new/subtitles\nD:/subtitles',
    );
    await tester.enterText(find.byKey(const ValueKey('scan_interval')), '15');
    await _reach(tester, find.byKey(const ValueKey('extensions')));
    await tester.enterText(
      find.byKey(const ValueKey('extensions')),
      '.srt, .ass',
    );
    await _reach(tester, find.widgetWithText(OutlinedButton, '完整扫描'));
    await tester.tap(find.widgetWithText(OutlinedButton, '完整扫描'));
    await _frames(tester);
    expect(backend.request('/subtitle/scan').queryParameters['mode'], 'full');
    expect(find.text('字幕扫描任务正在进行中'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 520));
    await _frames(tester);
    expect(find.text('文件 2 / 4 · 目录 1 / 2'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 520));
    await _frames(tester);
    await tester.pump(const Duration(seconds: 5));
    await _save(tester);
    expect(backend.lastSaved, {
      'subtitle': {
        'enabled': true,
        'directories': ['/new/subtitles', 'D:/subtitles'],
        'extensions': ['.srt', '.ass'],
        'scan_interval': 15,
        'cache_file': 'cache.json',
      },
    });
  });

  testWidgets('切换服务器关闭媒体库弹层并丢弃旧请求，退出缓存页停止轮询', (tester) async {
    final backend = _MediaBackend();
    final pending = Completer<List<Map<String, dynamic>>>();
    backend.pendingLibraries = pending.future;
    final container = await _open(tester, backend, 'mediaserver.emby');
    await _reach(tester, find.byType(DbOnlineMediaLibrariesField));
    await tester.tap(find.widgetWithText(OutlinedButton, '全部媒体库'));
    await _frames(tester);
    container.updateOverrides([
      requiredApiClientProvider.overrideWithValue(_MediaBackend().client()),
    ]);
    await _frames(tester);
    pending.complete([
      {'id': 'old', 'name': '旧服务器媒体库'},
    ]);
    await tester.pumpAndSettle();
    expect(find.text('配置入口'), findsOneWidget);
    expect(find.text('旧服务器媒体库'), findsNothing);
    await _open(tester, backend, 'mediaserver');
    await _reach(tester, find.widgetWithText(OutlinedButton, '刷新入库缓存'));
    await tester.tap(find.widgetWithText(OutlinedButton, '刷新入库缓存'));
    await _frames(tester);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    final count = backend.requests.length;
    await tester.pump(const Duration(seconds: 3));
    expect(backend.requests.length, count);
    expect(tester.takeException(), isNull);
  });
  testWidgets('播放器默认速度完整读取服务端已有速度列表', (tester) async {
    final backend = _MediaBackend();
    final player = (backend.config['mediaserver'] as Map)['player'] as Map;
    player['speed_options'] = [3];
    player['default_speed'] = 3;
    await _open(tester, backend, 'mediaserver.player');
    await _reach(tester, find.text('3x'));
    await _save(tester);
    expect(
      ((backend.lastSaved!['mediaserver'] as Map)['player']
          as Map)['default_speed'],
      3,
    );
  });

  testWidgets('新增设置和媒体库选择器在窄屏双倍字体下保持可滚动且无溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final backend = _MediaBackend();
    for (final path in [
      'experimental',
      'mediaserver',
      'subtitle',
      'mediaserver.emby',
    ]) {
      await _open(tester, backend, path, textScale: 2);
      if (path == 'mediaserver.emby') {
        await _reach(tester, find.byType(DbOnlineMediaLibrariesField));
        await tester.tap(find.widgetWithText(OutlinedButton, '全部媒体库'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(OutlinedButton, '取消'));
        await tester.pumpAndSettle();
      }
      await _reach(tester, find.text('保存设置'));
      expect(tester.takeException(), isNull, reason: path);
    }
  });
}

Future<ProviderContainer> _open(
  WidgetTester tester,
  _MediaBackend backend,
  String path, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  final section = dboBackendConfigGroups
      .expand((group) => group.sections)
      .firstWhere((section) => section.basePath == path);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        requiredApiClientProvider.overrideWithValue(backend.client()),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        locale: const Locale('zh'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Navigator(
          onGenerateInitialRoutes: (_, _) => [
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('配置入口')),
            ),
            MaterialPageRoute<void>(
              builder: (_) => DboBackendConfigDetailPage(
                section: section,
                config: backend.config,
              ),
            ),
          ],
          onGenerateRoute: (_) => null,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

Future<void> _reach(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 12 && finder.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -280));
    await tester.pumpAndSettle();
  }
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await _reach(tester, find.text('保存设置'));
  await tester.tap(find.text('保存设置'));
  await tester.pumpAndSettle();
  expect(find.text('配置入口'), findsOneWidget);
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

class _MediaBackend implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Map<String, dynamic>? lastSaved;
  Future<List<Map<String, dynamic>>>? pendingLibraries;
  bool failLibraries = false;
  bool mediaLibrary = true;
  bool subtitleLibrary = true;
  bool subtitleError = false;
  bool subtitleConflict = false;
  int cacheTicks = 0;
  int scanTicks = 0;
  bool cacheDone = false;
  final config = <String, dynamic>{
    'javdb_api': {'authorization': '********'},
    'telegram': {'enabled': true},
    'external_magnet': {
      'builtin_magnets': ['nyaa'],
    },
    'experimental': {
      for (final key in [
        'auto_sync_watched_online',
        'auto_sync_want_watch_online',
        'auto_sync_cancel_want_watch_online',
        'webhook_cancel_subscription_on_delete',
        'webhook_auto_blacklist_on_delete',
        'builtin_magnets_in_subscription',
        'fetch_video_overview',
      ])
        key: true,
    },
    'mediaserver': {
      for (final name in ['emby', 'jellyfin', 'fnmedia'])
        name: {
          'enabled': true,
          'host': 'saved',
          'port': name == 'fnmedia' ? 5666 : 8096,
          'timeout': 30,
          'use_https': false,
          'library_ids': <String>[],
          if (name == 'fnmedia') ...{
            'username': 'user',
            'password': '********',
          } else
            'api_key': '********',
        },
      'webhook': {'enabled': true},
      'library_cache_schedule': '30 0 * * *',
      'player': <String, dynamic>{'enabled': true},
    },
    'subtitle': {
      'enabled': true,
      'directories': ['/subtitles'],
      'extensions': ['.srt'],
      'scan_interval': 0,
      'cache_file': 'cache.json',
    },
  };

  ApiClient client() => ApiClient(
    Dio(BaseOptions(baseUrl: 'http://test/api'))..httpClientAdapter = this,
  );
  RequestOptions request(String path) =>
      requests.lastWhere((request) => request.uri.path.endsWith(path));
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final path = options.uri.path.replaceFirst('/api', '');
    Object? data;
    var status = 200;
    Object? response;
    if (path == '/config') {
      if (options.method == 'PUT') {
        lastSaved = Map<String, dynamic>.from(
          jsonDecode(jsonEncode(options.data)) as Map,
        );
      }
      data = config;
    } else if (path == '/health') {
      return _response({
        'capabilities': {
          'media_library': mediaLibrary,
          'subtitle_library': subtitleLibrary,
        },
      }, status);
    } else if (path.endsWith('/libraries')) {
      if (failLibraries) {
        response = {'success': false, 'error': '媒体库请求失败'};
      } else {
        data =
            await pendingLibraries ??
            [
              {
                'id': '12345678901234567890',
                'name': '电影',
                'collection_type': 'movies',
              },
              {'id': 'collection', 'name': '收藏', 'collection_type': 'movies'},
            ];
      }
    } else if (path.endsWith('/test')) {
      data = {'message': '连接正常', 'version': '1.2.3'};
    } else if (path == '/library/cache/stats') {
      data = {
        'cache_total': cacheDone ? 4 : 2,
        'actual_total': 4,
        'libraries': [
          {
            'source': 'emby',
            'cache_count': cacheDone ? 4 : 2,
            'actual_count': 4,
            'ready': true,
          },
        ],
      };
    } else if (path == '/library/cache/refresh') {
      cacheTicks = 2;
      data = {'triggered': true, 'message': '缓存刷新已启动'};
    } else if (path == '/library/cache/refresh/progress') {
      if (cacheTicks > 0) {
        cacheTicks--;
        if (cacheTicks == 0) cacheDone = true;
      }
      data = {
        'refreshing': cacheTicks > 0,
        'total': 4,
        'completed': cacheTicks > 0 ? 2 : 4,
        'percent': cacheTicks > 0 ? 50 : 100,
      };
    } else if (path == '/subtitle/stats') {
      data = {
        'total_count': 12,
        'unique_codes': 4,
        'last_scan': '2026-10-03T12:34:00+08:00',
      };
      if (subtitleError) response = {'code': -1, 'msg': '字幕统计失败'};
    } else if (path == '/subtitle/scan') {
      scanTicks = 2;
      data = {'message': '字幕扫描已启动'};
      if (subtitleConflict) {
        status = 409;
        response = {'code': -1, 'msg': '扫描任务正在进行中'};
      }
    } else if (path == '/subtitle/progress') {
      if (scanTicks > 0) scanTicks--;
      data = {
        'scanning': scanTicks > 0,
        'phase': 'scanning',
        'total_files': scanTicks > 0 ? 2 : 4,
        'estimated_total': 4,
        'completed_dirs': scanTicks > 0 ? 1 : 2,
        'total_dirs': 2,
        'current_dir': '/subtitles',
      };
    }
    response ??= path.startsWith('/subtitle/')
        ? {'code': 0, 'msg': 'success', 'data': data}
        : {'success': true, 'data': data};
    return _response(response, status);
  }

  ResponseBody _response(Object? response, int status) =>
      ResponseBody.fromString(
        jsonEncode(response),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
}
