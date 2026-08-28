import 'dart:convert';

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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: ServerSelectionPage()),
      ),
    );

    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
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
        child: const MaterialApp(home: ServerSelectionPage()),
      ),
    );

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await _enterHttpFields(tester, '媒体服务器', 'media.example', '443');
    await tester.tap(find.text('测试并保存'));
    await tester.pumpAndSettle();

    expect(find.text('选择服务器'), findsOneWidget);
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
        child: const MaterialApp(home: ServerSelectionPage()),
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
        child: const MaterialApp(home: ServerSelectionPage()),
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
    expect(find.text('选择服务器'), findsOneWidget);
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
        child: const MaterialApp(home: ServerSelectionPage()),
      ),
    );

    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.text('连接到媒体服务器'), findsOneWidget);
    expect(find.text('Oh-My-Media'), findsOneWidget);
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
        child: const MaterialApp(home: ServerSelectionPage()),
      ),
    );

    await tester.longPress(find.text('DB Online'));
    await tester.pumpAndSettle();

    expect(find.text('编辑服务器'), findsOneWidget);
    expect(find.text('删除服务器'), findsOneWidget);
    expect(find.text('编辑服务器地址'), findsNothing);

    await tester.tap(find.text('编辑服务器'));
    await tester.pumpAndSettle();
    expect(find.text('更换服务器'), findsOneWidget);
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields[0].controller?.text, 'DB Online');
    expect(fields[1].controller?.text, 'db.example');
    expect(fields[2].controller?.text, '9090');
  });

  testWidgets('头像横向滚动区域延伸到屏幕边缘', (tester) async {
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
        child: const MaterialApp(home: ServerSelectionPage()),
      ),
    );
    await tester.pumpAndSettle();

    final horizontalScrollView = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    expect(horizontalScrollView, findsOneWidget);
    expect(
      tester.getSize(horizontalScrollView).width,
      tester.getSize(find.byType(Scaffold)).width,
    );
  });

  testWidgets('已登录页面打开服务器选择器使用普通页面转场', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: _SelectorLauncher()),
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
        child: const MaterialApp(home: _SelectorLauncher()),
      ),
    );

    await tester.tap(find.text('打开服务器选择器'));
    await tester.pumpAndSettle();
    expect(find.byType(ServerSelectionPage), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(ServerSelectionPage), findsOneWidget);
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
        child: const MaterialApp(home: _SelectorLauncher()),
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
        child: const MaterialApp(home: ServerSelectionPage()),
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
        child: const MaterialApp(home: ServerSelectionPage()),
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
  Future<bool> login({required String password, String? totpCode}) async {
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
