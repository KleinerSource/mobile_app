import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/api_exception.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/features/db_online/settings/db_online_backend_settings_page.dart';
import 'package:omm/features/db_online/settings/db_online_downloader_config_widgets.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

void main() {
  test('下载器辅助接口使用当前配置、字符串 ID 和标准错误解析', () async {
    final backend = _CloudBackend();
    final api = backend.client().dbOnline;
    final directories = await api.pan115Directories({
      'cookie': '********',
      'cid': '12345678901234567890',
      'timeout': 30,
    });
    await api.thunderSelectOptions({
      'host': 'unsaved',
      'device_target': 'dev-b',
    });
    final tools = await api.openListToolPaths({
      'token': '********',
      'timeout': 50,
    });
    final account = await api.pan115Account();
    expect(directories['cid'], '12345678901234567890');
    expect(backend.to('/pan115/directories').single.data, {
      'cookie': '********',
      'cid': '12345678901234567890',
      'timeout': 30,
    });
    expect(backend.to('/thunder/select-options').single.data, {
      'host': 'unsaved',
      'device_target': 'dev-b',
    });
    expect((tools['tools'] as List).first['tool_key'], 'aria2');
    expect(account['user_name'], '115用户');
    expect(backend.to('/pan115/tasks').single.queryParameters, {
      'filter': 'downloading',
      'page': 1,
      'page_size': 1,
    });
    backend.respond = (request) => {'success': false, 'error': '目录认证失败'};
    await expectLater(api.pan115Directories({}), throwsA(isA<ApiException>()));
  });

  testWidgets('115 使用目录选择器浏览、刷新、上级、面包屑并保存选中目录', (tester) async {
    final backend = _CloudBackend();
    await _pump(tester, backend);
    await _openSection(tester, '115 网盘');
    expect(find.text('115用户'), findsOneWidget);
    expect(find.text('到期日期：永久有效'), findsOneWidget);
    expect(find.text('保留配额（GB）'), findsNothing);
    expect(find.byKey(const ValueKey('cid')), findsNothing);
    await _tap(tester, find.byType(DbOnlineDownloaderDirectoryField));
    expect(backend.to('/pan115/directories').last.data['cid'], '0');
    await _tap(tester, find.text('电影'));
    expect(backend.to('/pan115/directories').last.data['cid'], '100');
    await _tap(tester, find.byTooltip('刷新').last);
    await _tap(tester, find.byTooltip('上一级'));
    expect(backend.to('/pan115/directories').last.data['cid'], '0');
    await _tap(tester, find.text('电影'));
    await _tap(tester, find.text('收藏'));
    expect(
      backend.to('/pan115/directories').last.data['cid'],
      '12345678901234567890',
    );
    expect(find.text('当前目录下没有子目录'), findsOneWidget);
    await _tap(tester, find.text('电影'));
    expect(backend.to('/pan115/directories').last.data['cid'], '100');
    await _tap(tester, find.text('收藏'));
    await _tap(tester, find.text('选择当前目录'));
    expect(find.text('根目录 / 电影 / 收藏'), findsOneWidget);
    await _tap(tester, find.text('保存设置'));
    final saved =
        backend
                .to('/config')
                .singleWhere((request) => request.method == 'PUT')
                .data
            as Map;
    expect(saved.keys, ['downloader']);
    expect((saved['downloader'] as Map).keys, ['pan115']);
    expect(saved['downloader']['pan115']['cid'], '12345678901234567890');
    expect(saved['downloader']['pan115']['cookie'], '********');
    expect(saved['downloader']['pan115']['reserve_quota'], 50);
    expect(saved['downloader']['pan115']['future_option'], 'preserved');
    expect(tester.takeException(), isNull);
  });

  testWidgets('115 目录失败可重试，取消不会修改下载目录', (tester) async {
    final backend = _CloudBackend();
    var failed = true;
    backend.respond = (request) =>
        request.path == '/pan115/directories' && failed
        ? {'success': false, 'error': '目录读取失败'}
        : null;
    await _pump(tester, backend);
    await _openSection(tester, '115 网盘');
    await _tap(tester, find.byType(DbOnlineDownloaderDirectoryField));
    expect(find.text('目录读取失败'), findsOneWidget);
    failed = false;
    await _tap(tester, find.text('重试'));
    await _tap(tester, find.text('电影'));
    await _tap(tester, find.text('取消'));
    await _tap(tester, find.text('保存设置'));
    expect(backend.lastSaved('pan115')['cid'], '0');
  });

  testWidgets('迅雷只提供设备目录选择器，切换设备清空旧目录并保存真实选择', (tester) async {
    final backend = _CloudBackend();
    await _pump(tester, backend);
    await _openSection(tester, '迅雷');
    expect(find.byKey(const ValueKey('device_target')), findsNothing);
    expect(find.byKey(const ValueKey('parent_folder_id')), findsNothing);
    await _tap(tester, find.byType(DbOnlineDownloaderDirectoryField));
    final initial = backend.to('/thunder/select-options').first.data as Map;
    expect(initial.containsKey('device_target'), isFalse);
    expect(initial.containsKey('parent_folder_id'), isFalse);
    expect(
      backend.to('/thunder/select-options').last.data['device_target'],
      'dev-a',
    );
    await _tap(tester, find.text('设备B'));
    final request = backend.to('/thunder/select-options').last.data as Map;
    expect(request['device_target'], 'dev-b');
    expect(request.containsKey('parent_folder_id'), isFalse);
    await _tap(tester, find.text('取消'));
    await _tap(tester, find.text('保存设置'));
    expect(find.text('请选择下载目录'), findsOneWidget);
    expect(
      backend.to('/config').where((request) => request.method == 'PUT'),
      isEmpty,
    );
    await _tap(tester, find.byType(DbOnlineDownloaderDirectoryField));
    await _tap(tester, find.text('/data/dev-b'));
    await _tap(tester, find.text('保存设置'));
    expect(backend.lastSaved('thunder')['device_target'], 'dev-b');
    expect(backend.lastSaved('thunder')['parent_folder_id'], 'folder-dev-b');
  });

  testWidgets('迅雷快速切换设备丢弃旧目录响应', (tester) async {
    final backend = _CloudBackend();
    final old = Completer<Object?>();
    backend.config['downloader']['thunder']['device_target'] = '';
    backend.config['downloader']['thunder']['parent_folder_id'] = '';
    backend.respond = (request) =>
        request.path == '/thunder/select-options' &&
            request.data['device_target'] == 'dev-a'
        ? old.future
        : null;
    await _pump(tester, backend);
    await _openSection(tester, '迅雷');
    await _tap(tester, find.byType(DbOnlineDownloaderDirectoryField));
    await tester.tap(find.text('设备A'));
    await _frames(tester);
    await _tap(tester, find.text('设备B'));
    old.complete({
      'success': true,
      'data': {
        'devices': _CloudBackend.devices,
        'directories': [
          {'id': 'old', 'real_path': '旧设备目录'},
        ],
      },
    });
    await _frames(tester);
    expect(find.text('旧设备目录'), findsNothing);
    expect(find.text('/data/dev-b'), findsOneWidget);
    await _tap(tester, find.text('/data/dev-b'));
    await _tap(tester, find.text('保存设置'));
    expect(backend.lastSaved('thunder')['parent_folder_id'], 'folder-dev-b');
    expect(tester.takeException(), isNull);
  });

  testWidgets('OpenList 路径草稿取消不写回，刷新保留草稿并规范化后合并保存', (tester) async {
    final backend = _CloudBackend();
    await _pump(tester, backend);
    await _openSection(tester, 'OpenList');
    await _tap(tester, find.byType(DbOnlineOpenListToolPathsField));
    expect(find.text('/root'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('aria2')), '/discarded');
    await _tap(tester, find.text('取消'));
    expect(
      backend.to('/config').where((request) => request.method == 'PUT'),
      isEmpty,
    );
    await _tap(tester, find.byType(DbOnlineOpenListToolPathsField));
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('aria2')))
          .controller!
          .text,
      'saved',
    );
    await tester.enterText(
      find.byKey(const ValueKey('aria2')),
      r' \\movies//{actor_name}/ ',
    );
    await _tap(tester, find.byTooltip('刷新').last);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('aria2')))
          .controller!
          .text,
      r' \\movies//{actor_name}/ ',
    );
    await _tap(tester, find.text('保存'));
    await _tap(tester, find.text('保存设置'));
    final saved = backend.lastSaved('openlist');
    expect(saved['tool_path_suffixes'], {
      'aria2': 'movies/{actor_name}/',
      'hidden': 'retained',
      'thunder': 'web-default',
    });
    expect(saved['token'], '********');
    expect(saved['delete_policy'], 'delete_never');
    expect(backend.to('/openlist/tool-paths').last.data['token'], '********');
  });

  testWidgets('CloudDrive2 完整配置、ed2k、变量路径、测试版本及分区保存', (tester) async {
    final backend = _CloudBackend();
    await _pump(tester, backend);
    await _openSection(tester, 'CloudDrive2');
    await _reveal(tester, find.byKey(const ValueKey('host')));
    await tester.enterText(
      find.byKey(const ValueKey('host')),
      'new-cloud-host',
    );
    await _tap(tester, find.byKey(const ValueKey('ed2k_enabled')));
    await _reveal(tester, find.byKey(const ValueKey('save_path')));
    await tester.enterText(
      find.byKey(const ValueKey('save_path')),
      '/media/{actor_name}/{release_date}',
    );
    await _tap(tester, find.text('测试连接'));
    final request = backend.to('/clouddrive2/test').single.data as Map;
    expect(request['host'], 'new-cloud-host');
    expect(request['save_path'], '/media/{actor_name}/{release_date}');
    expect(request['ed2k_enabled'], isTrue);
    expect(request['token'], '********');
    expect(find.text('专用连接正常 · 1.2'), findsOneWidget);
    await _tap(tester, find.text('保存设置'));
    final saved = backend.lastSaved('clouddrive2');
    expect(saved, request);
  });

  testWidgets('未启用时禁用测试，启用后校验必填项和数值', (tester) async {
    final backend = _CloudBackend();
    backend.config['downloader']['openlist']['enabled'] = false;
    backend.config['downloader']['openlist']['token'] = '';
    await _pump(tester, backend);
    await _openSection(tester, 'OpenList');
    await _reveal(tester, find.text('测试连接'));
    final testButton = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('测试连接'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(testButton.onPressed, isNull);
    await _tap(tester, find.byKey(const ValueKey('enabled')));
    await _tap(tester, find.text('保存设置'));
    expect(
      backend.to('/config').where((request) => request.method == 'PUT'),
      isEmpty,
    );
    await tester.pump(const Duration(seconds: 5));
    await _reveal(tester, find.byKey(const ValueKey('token')));
    await tester.enterText(find.byKey(const ValueKey('token')), 'new-token');
    await _reveal(tester, find.byKey(const ValueKey('port')));
    await tester.enterText(find.byKey(const ValueKey('port')), '65536');
    await _tap(tester, find.text('测试连接'));
    expect(find.text('端口必须为 1–65535，超时时间必须为正整数'), findsOneWidget);
    expect(backend.to('/openlist/test'), isEmpty);
    expect(
      backend.to('/config').where((request) => request.method == 'PUT'),
      isEmpty,
    );
  });

  testWidgets('切换服务器关闭配置及选择面板并丢弃旧服务器响应', (tester) async {
    final backend = _CloudBackend();
    final pending = Completer<Object?>();
    backend.respond = (request) =>
        request.path == '/pan115/directories' ? pending.future : null;
    final container = await _pump(tester, backend);
    await _openSection(tester, '115 网盘');
    await _reveal(tester, find.byType(DbOnlineDownloaderDirectoryField));
    await tester.tap(find.byType(DbOnlineDownloaderDirectoryField));
    await _frames(tester);
    container.updateOverrides([
      requiredApiClientProvider.overrideWithValue(
        backend.client('https://second.test/api'),
      ),
    ]);
    await _frames(tester);
    expect(find.byType(DboBackendConfigDetailPage), findsNothing);
    pending.complete({
      'success': true,
      'data': {
        'cid': 'old',
        'path': [],
        'directories': [
          {'cid': 'old', 'name': '旧服务器目录'},
        ],
      },
    });
    await _frames(tester);
    expect(find.text('旧服务器目录'), findsNothing);
    expect(backend.to('/config').last.uri.host, 'second.test');
    expect(
      backend.to('/config').where((request) => request.method == 'PUT'),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  _CloudBackend backend,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        requiredApiClientProvider.overrideWithValue(backend.client()),
      ],
      child: const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: DboBackendSettingsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    final scrollable = find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pump();
  }
  for (var i = 0; i < 12 && finder.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -220));
    await tester.pump();
  }
  expect(finder, findsWidgets);
  await tester.ensureVisible(finder.first);
  await _frames(tester);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _reveal(tester, finder);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Future<void> _openSection(WidgetTester tester, String name) =>
    _tap(tester, find.text(name));

class _CloudBackend implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  FutureOr<Object?> Function(RequestOptions request)? respond;
  final config = <String, dynamic>{
    'downloader': {
      'openlist': {
        'enabled': true,
        'host': 'openlist-host',
        'port': 5244,
        'use_https': true,
        'timeout': 30,
        'token': '********',
        'delete_policy': 'delete_never',
        'tool_path_suffixes': {'aria2': 'saved', 'hidden': 'retained'},
      },
      'pan115': {
        'enabled': true,
        'cookie': '********',
        'timeout': 30,
        'cid': '0',
        'reserve_quota': 50,
        'future_option': 'preserved',
      },
      'thunder': {
        'enabled': true,
        'host': 'thunder-host',
        'port': 6984,
        'timeout': 30,
        'use_https': false,
        'device_target': 'dev-a',
        'parent_folder_id': 'folder-dev-a',
      },
      'clouddrive2': {
        'enabled': true,
        'host': 'cloud-host',
        'port': 19798,
        'timeout': 30,
        'token': '********',
        'save_path': '/downloads/{actor_name}',
        'ed2k_enabled': false,
      },
    },
  };
  static const devices = [
    {'target': 'dev-a', 'name': '设备A'},
    {'target': 'dev-b', 'name': '设备B'},
  ];

  ApiClient client([String url = 'https://first.test/api']) =>
      ApiClient(Dio(BaseOptions(baseUrl: url))..httpClientAdapter = this);

  List<RequestOptions> to(String path) =>
      requests.where((request) => request.path == path).toList();
  Map lastSaved(String name) =>
      (to('/config').lastWhere((request) => request.method == 'PUT').data
              as Map)['downloader'][name]
          as Map;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final request = options.copyWith(
      data: options.data == null ? null : jsonDecode(jsonEncode(options.data)),
    );
    requests.add(request);
    final custom = respond == null ? null : await respond!(request);
    return ResponseBody.fromString(
      jsonEncode(custom ?? _response(request)),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  Object _response(RequestOptions request) {
    final body = request.data is Map ? request.data as Map : const {};
    Object? data;
    switch (request.path) {
      case '/config':
        if (request.method == 'PUT') {
          (config['downloader'] as Map).addAll(body['downloader'] as Map);
        }
        data = config;
      case '/pan115/tasks':
        data = {
          'account': {
            'user_name': '115用户',
            'display_uid': '98765',
            'vip_level': 'VIP',
            'is_forever': true,
          },
        };
      case '/pan115/directories':
        final cid = body['cid']?.toString() ?? '0';
        data = {
          'cid': cid,
          'path': [
            {'cid': '0', 'name': '根目录'},
            if (cid != '0') {'cid': '100', 'name': '电影'},
            if (cid != '0' && cid != '100') {'cid': cid, 'name': '收藏'},
          ],
          'directories': [
            if (cid == '0') {'cid': '100', 'name': '电影'},
            if (cid == '100') {'cid': '12345678901234567890', 'name': '收藏'},
          ],
          'total': 1,
        };
      case '/thunder/select-options':
        final device = body['device_target']?.toString() ?? '';
        data = {
          'devices': devices,
          if (device.isNotEmpty)
            'directories': [
              {
                'id': 'folder-$device',
                'real_path': '/data/$device',
                'is_default': true,
              },
            ],
        };
      case '/openlist/tool-paths':
        data = {
          'tools': [
            {
              'tool': 'Aria2',
              'tool_key': 'aria2',
              'prefix': '/root//',
              'suffix': 'default',
            },
            {
              'tool': 'Thunder',
              'tool_key': 'thunder',
              'prefix': '/',
              'suffix': 'web-default',
            },
          ],
        };
      default:
        data = {'message': '专用连接正常', 'version': '1.2'};
    }
    return {'success': true, 'data': data};
  }
}
