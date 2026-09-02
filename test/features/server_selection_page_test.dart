import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/server_compatibility.dart';
import 'package:omm/core/auth/auth_provider.dart';
import 'package:omm/core/auth/auth_session.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/config/server_line_probe.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/home/server_switch_transition.dart';
import 'package:omm/features/settings/server_selection_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('无服务器时显示加号入口并打开创建页', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: _testApp(const ServerSelectionPage()),
      ),
    );

    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    final addCard = find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == '添加服务器',
    );
    expect(addCard, findsOneWidget);
    expect(tester.getSize(addCard), const Size(354, 124));
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.text('连接到媒体服务器'), findsOneWidget);
  });

  testWidgets('创建服务器保存后返回选择器且保留用户选择的类型', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          serverLineProbeCoordinatorProvider.overrideWithValue(
            ServerLineProbeCoordinator(
              probe: (line) async => ServerLineProbeResult.success(
                line,
                8,
                versionInfo: const ServerVersionInfo(
                  projectName: 'oh-my-media',
                  version: '2.0.0',
                ),
              ),
            ),
          ),
        ],
        child: _testApp(const ServerSelectionPage()),
      ),
    );

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await _enterHttpFields(tester, '媒体服务器', 'media.example', '443');
    await tester.tap(find.text('测试并保存'));
    await tester.pumpAndSettle();

    expect(find.byType(ServerSelectionPage), findsOneWidget);
    expect(prefs.getString('server.servers'), contains('oh-my-media'));
  });

  testWidgets('新增服务器拒绝重复的类型和连接地址', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          serverLineProbeCoordinatorProvider.overrideWithValue(
            ServerLineProbeCoordinator(
              probe: (line) async => ServerLineProbeResult.success(
                line,
                8,
                versionInfo: const ServerVersionInfo(
                  projectName: 'oh-my-media',
                  version: '2.0.0',
                ),
              ),
            ),
          ),
        ],
        child: _testApp(const ServerSelectionPage()),
      ),
    );

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await _enterHttpFields(tester, '第一台服务器', 'media.example', '8001');
    await tester.tap(find.text('测试并保存'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await _enterHttpFields(tester, '重复服务器', 'media.example', '8001');
    await tester.tap(find.text('测试并保存'));
    await tester.pumpAndSettle();

    expect(find.textContaining('已存在相同连接'), findsOneWidget);
    expect(find.text('连接到媒体服务器'), findsOneWidget);
    expect(
      (jsonDecode(prefs.getString('server.servers')!) as List),
      hasLength(1),
    );
  });

  testWidgets('初始化页连续添加两台服务器时保留第一台', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          serverLineProbeCoordinatorProvider.overrideWithValue(
            ServerLineProbeCoordinator(
              probe: (line) async => ServerLineProbeResult.success(
                line,
                8,
                versionInfo: const ServerVersionInfo(
                  projectName: 'oh-my-media',
                  version: '2.0.0',
                ),
              ),
            ),
          ),
        ],
        child: _testApp(const ServerSelectionPage()),
      ),
    );

    Future<void> addServer(String url) async {
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      final uri = Uri.parse(url);
      await _enterHttpFields(
        tester,
        '服务器 ${uri.host}',
        uri.host,
        uri.hasPort ? uri.port.toString() : '443',
        scheme: uri.scheme,
      );
      await tester.tap(find.text('测试并保存'));
      await tester.pumpAndSettle();
    }

    await addServer('https://first.example');
    expect(find.byType(ServerSelectionPage), findsOneWidget);
    expect(
      (jsonDecode(prefs.getString('server.servers')!) as List),
      hasLength(1),
    );

    await addServer('https://second.example');

    final stored = jsonDecode(prefs.getString('server.servers')!) as List;
    expect(stored, hasLength(2));
    expect(stored[0]['lines'][0]['base_url'], 'https://first.example');
    expect(stored[1]['lines'][0]['base_url'], 'https://second.example');
  });

  testWidgets('已有服务器列表末尾的加号打开新建页并保留已有服务器', (tester) async {
    SharedPreferences.setMockInitialValues({
      'server.servers': jsonEncode([
        {
          'id': 'saved',
          'name': 'DB Online',
          'lines': [
            {
              'id': 'saved-line',
              'name': '主线路',
              'base_url': 'https://db.example',
            },
          ],
          'active_line_id': 'saved-line',
          'project_name': 'db_online',
        },
      ]),
      'server.active_server_id': 'saved',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          serverLineProbeCoordinatorProvider.overrideWithValue(
            ServerLineProbeCoordinator(
              probe: (line) async => ServerLineProbeResult.success(
                line,
                8,
                versionInfo: const ServerVersionInfo(
                  projectName: 'oh-my-media',
                  version: '2.0.0',
                ),
              ),
            ),
          ),
        ],
        child: _testApp(const ServerSelectionPage()),
      ),
    );

    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.text('连接到媒体服务器'), findsOneWidget);
    expect(find.text('Oh My Media'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .elementAt(1)
          .controller
          ?.text,
      isEmpty,
    );

    await _enterHttpFields(tester, '媒体服务器', 'media.example', '443');
    await tester.tap(find.text('测试并保存'));
    await tester.pumpAndSettle();

    final stored = jsonDecode(prefs.getString('server.servers')!) as List;
    expect(stored, hasLength(2));
    expect(stored.first['id'], 'saved');
    expect(stored.last['project_name'], 'oh-my-media');
  });

  testWidgets('长按服务器头像显示编辑和删除操作', (tester) async {
    SharedPreferences.setMockInitialValues({
      'server.servers': jsonEncode([
        {
          'id': 'saved',
          'name': 'DB Online',
          'lines': [
            {
              'id': 'saved-line',
              'name': '主线路',
              'base_url': 'https://db.example',
            },
          ],
          'active_line_id': 'saved-line',
          'project_name': 'db_online',
        },
      ]),
      'server.active_server_id': 'saved',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: _testApp(const ServerSelectionPage()),
      ),
    );

    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('server-selection-search')),
      findsNothing,
    );

    await tester.longPress(find.bySemanticsLabel('选择DB Online'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('编辑服务器'), findsOneWidget);
    expect(find.bySemanticsLabel('删除服务器'), findsOneWidget);
    expect(find.text('服务器操作'), findsNothing);
    expect(find.text('编辑服务器地址'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('server-selection-edit-action')),
    );
    await tester.pumpAndSettle();
    expect(find.text('更换服务器'), findsOneWidget);
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields[0].controller?.text, 'DB Online');
    expect(fields[1].controller?.text, 'db.example');
    expect(fields[2].controller?.text, '9090');
  });

  testWidgets('编辑服务器名称后选择器显示新名称', (tester) async {
    SharedPreferences.setMockInitialValues({
      'server.servers': jsonEncode([
        {
          'id': 'saved',
          'name': '旧名称',
          'lines': [
            {
              'id': 'saved-line',
              'name': '主线路',
              'base_url': 'https://db.example',
            },
          ],
          'active_line_id': 'saved-line',
          'project_name': 'db_online',
        },
      ]),
      'server.active_server_id': 'saved',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          serverLineProbeCoordinatorProvider.overrideWithValue(
            ServerLineProbeCoordinator(
              probe: (line) async => ServerLineProbeResult.success(
                line,
                8,
                versionInfo: const ServerVersionInfo(
                  projectName: 'db_online',
                  version: '1.14.0',
                ),
              ),
            ),
          ),
        ],
        child: _testApp(const ServerSelectionPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('旧名称'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('server-selection-edit-action')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '新名称');
    await tester.tap(find.text('测试并保存'));
    await tester.pumpAndSettle();

    expect(find.text('新名称'), findsOneWidget);
    expect(find.text('旧名称'), findsNothing);
  });

  testWidgets('OMM 卡片显示真实名称，其他类型显示用户配置名称', (tester) async {
    SharedPreferences.setMockInitialValues({
      'server.servers': jsonEncode([
        {
          'id': 'omm-one',
          'name': 'OMM 用户配置名称',
          'lines': [
            {
              'id': 'omm-line',
              'name': 'OMM 公网线路',
              'base_url': 'http://127.0.0.1:1',
            },
          ],
          'active_line_id': 'omm-line',
          'project_name': 'oh-my-media',
        },
        {
          'id': 'smb-one',
          'name': 'SMB 用户配置名称',
          'lines': [
            {
              'id': 'smb-line',
              'name': 'SMB 线路名称',
              'base_url': 'smb://nas.example/share',
            },
          ],
          'active_line_id': 'smb-line',
          'project_name': 'smb',
        },
      ]),
      'server.active_server_id': 'omm-one',
      'server.profile_cache.v1': jsonEncode({
        'omm-one': {'name': 'OMM 真实服务器名称'},
        'smb-one': {'name': '不应显示的 SMB 服务端名称'},
      }),
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: _testApp(const ServerSelectionPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('OMM 真实服务器名称'), findsOneWidget);
    expect(find.text('OMM 用户配置名称'), findsNothing);
    expect(find.text('OMM 公网线路'), findsOneWidget);
    expect(find.text('SMB 用户配置名称'), findsOneWidget);
    expect(find.text('不应显示的 SMB 服务端名称'), findsNothing);
    expect(find.text('SMB 线路名称'), findsOneWidget);
  });

  testWidgets('Emby 和 Jellyfin 卡片优先显示服务端用户名并支持下拉刷新', (tester) async {
    SharedPreferences.setMockInitialValues({
      'server.servers': jsonEncode([
        {
          'id': 'emby-one',
          'name': 'Emby 用户配置名称',
          'lines': [
            {
              'id': 'emby-line',
              'name': '主线路',
              'base_url': 'https://emby.example',
            },
          ],
          'active_line_id': 'emby-line',
          'project_name': 'emby',
        },
        {
          'id': 'jellyfin-one',
          'name': 'Jellyfin 用户配置名称',
          'lines': [
            {
              'id': 'jellyfin-line',
              'name': '主线路',
              'base_url': 'https://jellyfin.example',
            },
          ],
          'active_line_id': 'jellyfin-line',
          'project_name': 'jellyfin',
        },
        {
          'id': 'emby-no-session',
          'name': '未鉴权的 Emby',
          'lines': [
            {
              'id': 'emby-no-session-line',
              'name': '主线路',
              'base_url': 'https://emby-no-session.example',
            },
          ],
          'active_line_id': 'emby-no-session-line',
          'project_name': 'emby',
        },
      ]),
      'server.active_server_id': 'emby-one',
      'server.profile_cache.v1': jsonEncode({
        'emby-one': {'name': 'Emby 服务端用户'},
        'jellyfin-one': {'name': 'Jellyfin 服务端用户'},
      }),
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          serverLineProbeCoordinatorProvider.overrideWithValue(
            ServerLineProbeCoordinator(
              probe: (line) async => ServerLineProbeResult.success(line, 8),
            ),
          ),
        ],
        child: _testApp(const ServerSelectionPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Emby 服务端用户'), findsOneWidget);
    expect(find.text('Emby 用户配置名称'), findsNothing);
    expect(find.text('Jellyfin 服务端用户'), findsOneWidget);
    expect(find.text('Jellyfin 用户配置名称'), findsNothing);
    expect(find.text('未鉴权的 Emby'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  testWidgets('服务器列表使用双列卡片网格', (tester) async {
    SharedPreferences.setMockInitialValues({
      'server.servers': jsonEncode([
        for (var i = 0; i < 6; i++)
          {
            'id': 'server-$i',
            'name': '服务器 $i',
            'lines': [
              {
                'id': 'line-$i',
                'name': '主线路',
                'base_url': 'https://server-$i.example',
                'latency_ms': 8,
              },
            ],
            'active_line_id': 'line-$i',
            'project_name': 'db_online',
          },
      ]),
      'server.active_server_id': 'server-0',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: _testApp(const ServerSelectionPage()),
      ),
    );
    await tester.pumpAndSettle();

    final grid = tester.widget<GridView>(find.byType(GridView));
    expect(grid, isNotNull);
    final delegate = grid.gridDelegate;
    expect(delegate, isA<SliverGridDelegateWithFixedCrossAxisCount>());
    expect(
      (delegate as SliverGridDelegateWithFixedCrossAxisCount).crossAxisCount,
      2,
    );
    expect(find.text('服务器 5'), findsOneWidget);
    expect(find.text('主线路'), findsNWidgets(6));
    expect(find.text('1条线路'), findsNWidgets(6));
    expect(find.text('延迟'), findsNWidgets(6));
    expect(find.text('8 ms'), findsNWidgets(6));
  });

  testWidgets('服务器卡片长按后可直接拖动排序', (tester) async {
    SharedPreferences.setMockInitialValues({
      'server.servers': jsonEncode([
        for (var i = 0; i < 3; i++)
          {
            'id': 'server-$i',
            'name': '服务器 $i',
            'lines': [
              {
                'id': 'line-$i',
                'name': '主线路',
                'base_url': 'https://server-$i.example',
              },
            ],
            'active_line_id': 'line-$i',
            'project_name': 'db_online',
          },
      ]),
      'server.active_server_id': 'server-0',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: _testApp(const ServerSelectionPage()),
      ),
    );
    await tester.pumpAndSettle();

    final first = tester.getCenter(find.bySemanticsLabel('选择服务器 0'));
    final second = tester.getCenter(find.bySemanticsLabel('选择服务器 1'));
    final gesture = await tester.startGesture(first);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveTo(second);
    await gesture.up();
    await tester.pumpAndSettle();

    final stored = jsonDecode(prefs.getString('server.servers')!) as List;
    expect(stored.map((server) => server['id']), [
      'server-1',
      'server-0',
      'server-2',
    ]);
    expect(find.bySemanticsLabel('编辑服务器'), findsNothing);
  });

  testWidgets('服务器卡片拖拽松手不会误选服务器', (tester) async {
    SharedPreferences.setMockInitialValues({
      'server.servers': jsonEncode([
        for (var i = 0; i < 3; i++)
          {
            'id': 'server-$i',
            'name': '服务器 $i',
            'lines': [
              {
                'id': 'line-$i',
                'name': '主线路',
                'base_url': 'smb://server-$i/share',
              },
            ],
            'active_line_id': 'line-$i',
            'project_name': 'smb',
          },
      ]),
      'server.active_server_id': 'server-2',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: _testApp(const ServerSelectionPage()),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ServerSelectionPage)),
      listen: false,
    );
    final first = tester.getCenter(find.bySemanticsLabel('选择服务器 0'));
    final second = tester.getCenter(find.bySemanticsLabel('选择服务器 1'));
    final gesture = await tester.startGesture(first);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveTo(second);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(container.read(serverConfigProvider)?.activeServerId, 'server-2');
    expect(
      container.read(serverSwitchTransitionProvider).phase,
      ServerSwitchPhase.idle,
    );
    final reordered = jsonDecode(prefs.getString('server.servers')!) as List;
    expect(reordered.map((server) => server['id']), [
      'server-1',
      'server-0',
      'server-2',
    ]);

    await tester.tap(find.bySemanticsLabel('选择服务器 0'));
    await tester.pumpAndSettle();
    expect(container.read(serverConfigProvider)?.activeServerId, 'server-0');
  });

  testWidgets('悬浮操作显示后继续长按拖动仍可排序', (tester) async {
    SharedPreferences.setMockInitialValues({
      'server.servers': jsonEncode([
        for (var i = 0; i < 3; i++)
          {
            'id': 'server-$i',
            'name': '服务器 $i',
            'lines': [
              {
                'id': 'line-$i',
                'name': '主线路',
                'base_url': 'https://server-$i.example',
              },
            ],
            'active_line_id': 'line-$i',
            'project_name': 'db_online',
          },
      ]),
      'server.active_server_id': 'server-0',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: _testApp(const ServerSelectionPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.bySemanticsLabel('选择服务器 0'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('编辑服务器'), findsOneWidget);

    final first = tester.getCenter(find.bySemanticsLabel('选择服务器 0'));
    final second = tester.getCenter(find.bySemanticsLabel('选择服务器 1'));
    final gesture = await tester.startGesture(first);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveTo(second);
    await gesture.up();
    await tester.pumpAndSettle();

    final stored = jsonDecode(prefs.getString('server.servers')!) as List;
    expect(stored.map((server) => server['id']), [
      'server-1',
      'server-0',
      'server-2',
    ]);
    expect(find.bySemanticsLabel('编辑服务器'), findsNothing);
  });

  testWidgets('搜索时长按仍可显示操作但不会排序', (tester) async {
    SharedPreferences.setMockInitialValues({
      'server.servers': jsonEncode([
        for (var i = 0; i < 21; i++)
          {
            'id': 'server-$i',
            'name': '服务器 $i',
            'lines': [
              {
                'id': 'line-$i',
                'name': '主线路',
                'base_url': 'https://server-$i.example',
              },
            ],
            'active_line_id': 'line-$i',
            'project_name': 'db_online',
          },
      ]),
      'server.active_server_id': 'server-0',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: _testApp(const ServerSelectionPage()),
      ),
    );
    await tester.pumpAndSettle();

    final search = find.byKey(
      const ValueKey<String>('server-selection-search'),
    );
    await tester.enterText(search, '服务器 0');
    await tester.pump();

    await tester.longPress(find.bySemanticsLabel('选择服务器 0'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('编辑服务器'), findsOneWidget);

    final card = tester.getCenter(find.bySemanticsLabel('选择服务器 0'));
    final gesture = await tester.startGesture(card);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(80, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    final stored = jsonDecode(prefs.getString('server.servers')!) as List;
    expect(stored, hasLength(21));
    expect(stored.map((server) => server['id']).take(2), [
      'server-0',
      'server-1',
    ]);
  });

  testWidgets('服务器选择器显示连接标题并支持搜索', (tester) async {
    SharedPreferences.setMockInitialValues({
      'server.servers': jsonEncode([
        {
          'id': 'smb-one',
          'name': 'SMB 一号',
          'lines': [
            {
              'id': 'smb-line',
              'name': '主线路',
              'base_url': 'smb://nas-one/share',
            },
          ],
          'active_line_id': 'smb-line',
          'project_name': 'smb',
        },
        for (var i = 1; i < 20; i++)
          {
            'id': 'smb-$i',
            'name': 'SMB 服务器 $i',
            'lines': [
              {
                'id': 'smb-line-$i',
                'name': '主线路',
                'base_url': 'smb://nas-$i/share',
              },
            ],
            'active_line_id': 'smb-line-$i',
            'project_name': 'smb',
          },
        {
          'id': 'webdav-two',
          'name': 'WebDAV 二号',
          'lines': [
            {
              'id': 'webdav-line',
              'name': '主线路',
              'base_url': 'https://nas-two/dav',
            },
          ],
          'active_line_id': 'webdav-line',
          'project_name': 'webdav',
        },
      ]),
      'server.active_server_id': 'smb-one',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: _testApp(const ServerSelectionPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('连接'), findsOneWidget);
    expect(find.text('Oh My Media'), findsNothing);
    final search = find.byKey(
      const ValueKey<String>('server-selection-search'),
    );
    expect(search, findsOneWidget);

    await tester.enterText(search, 'WebDAV');
    await tester.pump();

    expect(find.text('WebDAV 二号'), findsOneWidget);
    expect(find.text('SMB 一号'), findsNothing);
  });

  testWidgets('已登录页面打开服务器选择器使用普通页面转场', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: _testApp(const _SelectorLauncher()),
      ),
    );

    await tester.tap(find.text('打开服务器选择器'));
    await tester.pumpAndSettle();

    final selector = find.byType(ServerSelectionPage);
    expect(selector, findsOneWidget);
    expect(tester.getTopLeft(selector).dx, greaterThanOrEqualTo(0));
  });

  testWidgets('服务器选择器是顶层时继续返回不会回到服务器页面', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: _testApp(const _SelectorLauncher()),
      ),
    );

    await tester.tap(find.text('打开服务器选择器'));
    await tester.pumpAndSettle();
    expect(find.byType(ServerSelectionPage), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(ServerSelectionPage), findsOneWidget);
  });

  testWidgets('应用内服务器页通过真实页面栈返回并在转场后释放运行态', (tester) async {
    SharedPreferences.setMockInitialValues({
      'server.servers': jsonEncode([
        {
          'id': 'smb-one',
          'name': 'SMB 一号',
          'lines': [
            {
              'id': 'smb-line',
              'name': '主线路',
              'base_url': 'smb://nas-one/share',
            },
          ],
          'active_line_id': 'smb-line',
          'project_name': 'smb',
        },
      ]),
      'server.active_server_id': 'smb-one',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: _testApp(const _ServerStackFixture()),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ServerSelectionPage, skipOffstage: false)),
      listen: false,
    );

    await tester.tap(find.text('返回服务器选择'));
    await tester.pump(const Duration(milliseconds: 50));

    expect(container.read(serverConfigProvider), isNotNull);

    await tester.pumpAndSettle();

    expect(find.byType(ServerSelectionPage), findsOneWidget);
    expect(container.read(serverConfigProvider), isNull);
  });

  testWidgets('返回选择器释放运行态后仍可重新选择服务器', (tester) async {
    SharedPreferences.setMockInitialValues({
      'server.servers': jsonEncode([
        {
          'id': 'smb-one',
          'name': 'SMB 一号',
          'lines': [
            {
              'id': 'smb-line',
              'name': '主线路',
              'base_url': 'smb://nas-one/share',
            },
          ],
          'active_line_id': 'smb-line',
          'project_name': 'smb',
        },
        {
          'id': 'webdav-two',
          'name': 'WebDAV 二号',
          'lines': [
            {
              'id': 'webdav-line',
              'name': '主线路',
              'base_url': 'https://nas-two/dav',
            },
          ],
          'active_line_id': 'webdav-line',
          'project_name': 'webdav',
        },
      ]),
      'server.active_server_id': 'smb-one',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: _testApp(const _SelectorLauncher()),
      ),
    );

    await tester.tap(find.text('打开服务器选择器'));
    await tester.pumpAndSettle();
    expect(find.byType(ServerSelectionPage), findsOneWidget);

    await tester.tap(find.text('WebDAV 二号'));
    await tester.pumpAndSettle();

    expect(find.byType(ServerSelectionPage), findsNothing);
    final stored = jsonDecode(prefs.getString('server.servers')!) as List;
    expect(prefs.getString('server.active_server_id'), 'webdav-two');
    expect(stored, hasLength(2));
  });

  testWidgets('主选择器重新选择服务器后清除返回请求状态', (tester) async {
    SharedPreferences.setMockInitialValues({
      'server.servers': jsonEncode([
        {
          'id': 'smb-one',
          'name': 'SMB 一号',
          'lines': [
            {
              'id': 'smb-line',
              'name': '主线路',
              'base_url': 'smb://nas-one/share',
            },
          ],
          'active_line_id': 'smb-line',
          'project_name': 'smb',
        },
        {
          'id': 'webdav-two',
          'name': 'WebDAV 二号',
          'lines': [
            {
              'id': 'webdav-line',
              'name': '主线路',
              'base_url': 'https://nas-two/dav',
            },
          ],
          'active_line_id': 'webdav-line',
          'project_name': 'webdav',
        },
      ]),
      'server.active_server_id': 'smb-one',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: _testApp(const ServerSelectionPage()),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ServerSelectionPage)),
      listen: false,
    );
    container.read(serverConfigProvider.notifier).showServerSelection();
    await tester.pump();

    await tester.tap(find.text('WebDAV 二号'));
    await tester.pumpAndSettle();

    expect(container.read(serverSelectionRequestedProvider), isFalse);
    expect(container.read(serverConfigProvider)?.activeServerId, 'webdav-two');
  });

  testWidgets('需要密码的服务器登录完成后离开主选择状态', (tester) async {
    SharedPreferences.setMockInitialValues({
      'server.servers': jsonEncode([
        {
          'id': 'db-one',
          'name': 'DB Online 一号',
          'lines': [
            {
              'id': 'db-line-one',
              'name': '主线路',
              'base_url': 'https://db-one.example',
            },
          ],
          'active_line_id': 'db-line-one',
          'project_name': 'db_online',
        },
        {
          'id': 'db-two',
          'name': 'DB Online 二号',
          'lines': [
            {
              'id': 'db-line-two',
              'name': '主线路',
              'base_url': 'https://db-two.example',
            },
          ],
          'active_line_id': 'db-line-two',
          'project_name': 'db_online',
        },
      ]),
      'server.active_server_id': 'db-one',
    });
    final prefs = await SharedPreferences.getInstance();
    final loginCalls = <String>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          serverLineProbeCoordinatorProvider.overrideWithValue(
            ServerLineProbeCoordinator(
              probe: (line) async => ServerLineProbeResult.success(
                line,
                8,
                versionInfo: const ServerVersionInfo(
                  projectName: 'db_online',
                  version: '1.14.0',
                ),
              ),
            ),
          ),
          authControllerProvider.overrideWith(
            () => _LoginAuthController(loginCalls),
          ),
          dbOnlineRecommendProvider.overrideWith((ref) async => const []),
          dbOnlineLatestUpdatedProvider.overrideWith((ref) async => const []),
          dbOnlineLatestReleasedProvider.overrideWith((ref) async => const []),
        ],
        child: _testApp(const ServerSelectionPage()),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ServerSelectionPage)),
      listen: false,
    );
    container.read(serverConfigProvider.notifier).showServerSelection();
    await tester.pump();

    await tester.tap(find.text('DB Online 二号'));
    await tester.pump();
    expect(
      container.read(serverSwitchTransitionProvider).phase,
      ServerSwitchPhase.needsLogin,
    );

    await container
        .read(serverSwitchTransitionProvider.notifier)
        .login(password: 'password');
    await tester.pump();

    expect(loginCalls, ['password']);
    expect(container.read(serverSelectionRequestedProvider), isFalse);
    expect(
      container.read(serverSwitchTransitionProvider).phase,
      ServerSwitchPhase.finishing,
    );
    container.read(serverSwitchTransitionProvider.notifier).finishTransition();
    await tester.pump();
    expect(
      container.read(serverSwitchTransitionProvider).phase,
      ServerSwitchPhase.idle,
    );

    container.read(serverConfigProvider.notifier).showServerSelection();
    await tester.pump();
    await tester.tap(find.text('DB Online 一号'));
    await tester.pump();
    await container
        .read(serverSwitchTransitionProvider.notifier)
        .login(password: 'password-again');
    await tester.pump();

    expect(loginCalls, ['password', 'password-again']);
    expect(container.read(serverSelectionRequestedProvider), isFalse);
    expect(container.read(serverConfigProvider)?.activeServerId, 'db-one');
  });
}

Widget _testApp(Widget home) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child ?? const SizedBox.shrink(),
    ),
    home: home,
  );
}

class _LoginAuthController extends AuthController {
  _LoginAuthController(this.loginCalls);

  final List<String> loginCalls;

  @override
  Future<AuthState> build() async =>
      const AuthState(phase: AuthPhase.needsLogin);

  @override
  Future<AuthState> refreshCurrentServer() async =>
      const AuthState(phase: AuthPhase.needsLogin);

  @override
  Future<bool> login({
    String? username,
    required String password,
    String? totpCode,
  }) async {
    loginCalls.add(password);
    return true;
  }
}

class _SelectorLauncher extends StatelessWidget {
  const _SelectorLauncher();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => ServerSelectionPage.openForReturn(context),
          child: const Text('打开服务器选择器'),
        ),
      ),
    );
  }
}

class _ServerStackFixture extends StatefulWidget {
  const _ServerStackFixture();

  @override
  State<_ServerStackFixture> createState() => _ServerStackFixtureState();
}

class _ServerStackFixtureState extends State<_ServerStackFixture> {
  bool _showContent = true;
  late final NavigatorObserver _observer = _FixtureRouteObserver(
    _handleContentExit,
  );

  @override
  Widget build(BuildContext context) {
    return ServerNavigationScope(
      child: Navigator(
        observers: [_observer],
        pages: [
          const MaterialPage<void>(
            key: ValueKey('fixture-selector'),
            child: ServerSelectionPage(),
          ),
          if (_showContent)
            const MaterialPage<void>(
              key: ValueKey('fixture-content'),
              child: _ServerStackContent(),
            ),
        ],
        onDidRemovePage: (_) {},
      ),
    );
  }

  void _handleContentExit(Route<dynamic> route) {
    final settings = route.settings;
    if (settings is! Page ||
        settings.key != const ValueKey('fixture-content')) {
      return;
    }
    final animation = route is TransitionRoute<dynamic>
        ? route.animation
        : null;
    if (animation == null || animation.status == AnimationStatus.dismissed) {
      _finishContentExit();
      return;
    }
    void onStatusChanged(AnimationStatus status) {
      if (status != AnimationStatus.dismissed) return;
      animation.removeStatusListener(onStatusChanged);
      _finishContentExit();
    }

    animation.addStatusListener(onStatusChanged);
  }

  void _finishContentExit() {
    if (!mounted || !_showContent) return;
    setState(() => _showContent = false);
    ProviderScope.containerOf(
      context,
      listen: false,
    ).read(serverConfigProvider.notifier).showServerSelection();
  }
}

class _FixtureRouteObserver extends NavigatorObserver {
  _FixtureRouteObserver(this.onExit);

  final void Function(Route<dynamic> route) onExit;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onExit(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onExit(route);
  }
}

class _ServerStackContent extends StatelessWidget {
  const _ServerStackContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => ServerSelectionPage.requestReturn(context),
          child: const Text('返回服务器选择'),
        ),
      ),
    );
  }
}

Future<void> _enterHttpFields(
  WidgetTester tester,
  String name,
  String host,
  String port, {
  String scheme = 'http',
}) async {
  if (scheme != 'http') {
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(scheme.toUpperCase()).last);
    await tester.pumpAndSettle();
  }
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), name);
  await tester.enterText(fields.at(1), host);
  await tester.enterText(fields.at(2), port);
}
