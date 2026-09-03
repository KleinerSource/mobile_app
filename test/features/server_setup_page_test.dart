import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/api_exception.dart';
import 'package:omm/core/api/server_compatibility.dart';
import 'package:omm/core/auth/auth_provider.dart';
import 'package:omm/core/auth/auth_session.dart';
import 'package:omm/core/auth/auth_session_provider.dart';
import 'package:omm/core/auth/auth_session_repository.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/config/server_line_probe.dart';
import 'package:omm/features/settings/server_list_page.dart';
import 'package:omm/features/settings/server_setup_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('服务器名称为空时显示报错', (tester) async {
    final prefs = await _prefs();
    await _pumpSetup(tester, prefs);

    await tester.tap(find.text('测试并保存'));
    await tester.pump();

    expect(find.text('请输入服务器名称'), findsOneWidget);
  });

  testWidgets('创建服务器默认选择 Oh My Media 并显示 HTTP 字段', (tester) async {
    final prefs = await _prefs();
    await _pumpSetup(tester, prefs);

    expect(find.text('Oh My Media'), findsOneWidget);
    expect(find.text('协议'), findsOneWidget);
    expect(find.text('主机'), findsOneWidget);
    expect(find.text('端口'), findsOneWidget);
    expect(find.text('路径'), findsNothing);
    // OMM 密码鉴权没有用户名概念，只有密码 + TOTP 密钥。
    expect(find.text('用户名'), findsNothing);
    expect(find.text('密码'), findsOneWidget);
    expect(find.text('TOTP 密钥（可选）'), findsOneWidget);
    expect(find.text('登录凭据（可选）'), findsOneWidget);
  });

  testWidgets('切换服务器类型显示对应字段', (tester) async {
    final prefs = await _prefs();
    await _pumpSetup(tester, prefs);

    await _selectProject(tester, 'SMB');
    expect(find.text('协议'), findsNothing);
    expect(find.text('主机'), findsOneWidget);
    expect(find.text('端口'), findsOneWidget);
    expect(find.text('路径'), findsOneWidget);
    expect(find.text('用户名'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .elementAt(2)
          .decoration
          ?.hintText,
      '445',
    );

    await _selectProject(tester, 'WebDAV');
    expect(find.text('协议'), findsOneWidget);
    expect(find.text('主机'), findsOneWidget);
    expect(find.text('端口'), findsOneWidget);
    expect(find.text('路径'), findsOneWidget);
    expect(find.text('用户名'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .elementAt(2)
          .decoration
          ?.hintText,
      '80',
    );

    await _selectProject(tester, 'OpenList');
    expect(find.text('协议'), findsOneWidget);
    expect(find.text('主机'), findsOneWidget);
    expect(find.text('端口'), findsOneWidget);
    expect(find.text('根路径'), findsOneWidget);
    expect(find.text('用户名（留空匿名访问）'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .elementAt(2)
          .decoration
          ?.hintText,
      '5244',
    );
    // 根路径自动预填 /，dav 前缀内置在端点里，用户无需输入。
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .elementAt(3)
          .controller
          ?.text,
      '/',
    );
  });

  testWidgets('DB Online 显示 HTTP 字段而不显示文件服务器字段', (tester) async {
    final prefs = await _prefs();
    await _pumpSetup(tester, prefs);
    await _selectProject(tester, 'DB Online');

    expect(find.text('协议'), findsOneWidget);
    expect(find.text('主机'), findsOneWidget);
    expect(find.text('端口'), findsOneWidget);
    expect(find.text('路径'), findsNothing);
    expect(find.text('用户名'), findsNothing);
    expect(find.text('密码'), findsOneWidget);
    expect(find.text('TOTP 密钥（可选）'), findsOneWidget);
  });

  testWidgets('Emby 显示用户名密码而不显示 TOTP 密钥', (tester) async {
    final prefs = await _prefs();
    await _pumpSetup(tester, prefs);
    await _selectProject(tester, 'Emby');

    expect(find.text('用户名'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(find.text('TOTP 密钥（可选）'), findsNothing);
  });

  testWidgets('飞牛与 Jellyfin 登录需要用户名', (tester) async {
    final prefs = await _prefs();
    await _pumpSetup(tester, prefs);
    await _selectProject(tester, 'Jellyfin');

    expect(find.text('用户名'), findsOneWidget);
    expect(find.text('TOTP 密钥（可选）'), findsNothing);
  });

  testWidgets('Emby 填写密码但缺少用户名时报错', (tester) async {
    final prefs = await _prefs();
    await _pumpSetup(tester, prefs);
    await _selectProject(tester, 'Emby');

    // Emby 字段顺序：名称、主机、端口、用户名、密码。
    await tester.enterText(find.byType(TextField).at(0), '我的 Emby');
    await tester.enterText(find.byType(TextField).at(1), 'example.com');
    await tester.enterText(find.byType(TextField).at(4), 'secret-pw');
    await tester.tap(find.text('测试并保存'));
    await tester.pumpAndSettle();

    expect(find.text('已填写密码，请输入用户名'), findsOneWidget);
  });

  testWidgets('TOTP 密钥格式非法时报错', (tester) async {
    final prefs = await _prefs();
    await _pumpSetup(tester, prefs);

    await tester.enterText(find.byType(TextField).at(0), '我的 OMM');
    await tester.enterText(find.byType(TextField).at(1), 'example.com');
    await tester.enterText(find.byType(TextField).at(4), 'not-base32!!');
    await tester.tap(find.text('测试并保存'));
    await tester.pumpAndSettle();

    expect(
      find.text('TOTP 密钥格式无效（应为 base32 字符串）'),
      findsOneWidget,
    );
  });

  testWidgets('HTTP 类型之间切换服务器类型时清空已输入的凭据', (tester) async {
    final prefs = await _prefs();
    await _pumpSetup(tester, prefs);

    // OMM 字段顺序：名称、主机、端口、密码、TOTP 密钥。
    await tester.enterText(find.byType(TextField).at(3), 'old-password');
    await _selectProject(tester, 'Emby');

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields[3].controller?.text, isEmpty);
    expect(fields[4].controller?.text, isEmpty);
  });

  testWidgets('填写凭据时保存前先登录并持久化 TOTP 密钥', (tester) async {
    final prefs = await _prefs();
    final store = _MemoryTokenStore();
    final sessions = AuthSessionRepository(store: store);
    final controller = _RecordingAuthController(null);
    await _pumpSetupWithAuth(
      tester,
      prefs,
      sessions: sessions,
      controller: controller,
    );

    await tester.enterText(find.byType(TextField).at(0), '我的 OMM');
    await tester.enterText(find.byType(TextField).at(1), '192.168.1.10');
    await tester.enterText(find.byType(TextField).at(3), 'secret-pw');
    await tester.enterText(
      find.byType(TextField).at(4),
      'gezd gnbv gy3tqojq gezd gnbv gy3tqojq',
    );
    await tester.tap(find.text('测试并保存'));
    await tester.pumpAndSettle();

    expect(controller.log.single['username'], isNull);
    expect(controller.log.single['password'], 'secret-pw');
    expect(
      controller.log.single['totpSecret'],
      'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
    );
    // 服务器与 TOTP 密钥均已保存。
    expect(prefs.getString('server.servers'), isNotNull);
    expect(
      store.values.values,
      contains('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'),
    );
  });

  testWidgets('登录失败时显示错误且不保存服务器', (tester) async {
    final prefs = await _prefs();
    final store = _MemoryTokenStore();
    final sessions = AuthSessionRepository(store: store);
    final controller = _RecordingAuthController(
      ApiException('用户名或密码错误'),
    );
    await _pumpSetupWithAuth(
      tester,
      prefs,
      sessions: sessions,
      controller: controller,
    );

    await tester.enterText(find.byType(TextField).at(0), '我的 OMM');
    await tester.enterText(find.byType(TextField).at(1), '192.168.1.10');
    await tester.enterText(find.byType(TextField).at(3), 'wrong-pw');
    await tester.tap(find.text('测试并保存'));
    await tester.pumpAndSettle();

    expect(find.text('用户名或密码错误'), findsOneWidget);
    expect(prefs.getString('server.servers'), isNull);
    expect(store.values, isEmpty);
  });

  testWidgets('编辑服务器时拆分回填名称、协议、主机和端口', (tester) async {
    SharedPreferences.setMockInitialValues({
      'server.servers': jsonEncode([
        {
          'id': 'saved',
          'name': '已保存服务器',
          'lines': [
            {
              'id': 'saved-line',
              'name': '主线路',
              'base_url': 'https://saved.example:8001/',
            },
          ],
          'active_line_id': 'saved-line',
          'project_name': 'oh-my-media',
        },
      ]),
      'server.active_server_id': 'saved',
    });
    final prefs = await SharedPreferences.getInstance();

    await _pumpSetup(tester, prefs, editing: true);

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields[0].controller?.text, '已保存服务器');
    expect(fields[1].controller?.text, 'saved.example');
    expect(fields[2].controller?.text, '8001');
    expect(find.text('HTTPS'), findsOneWidget);
    expect(find.text('已回填上次保存的服务器地址，可直接修改后重新测试。'), findsNothing);
  });

  testWidgets('编辑服务器时拒绝改成其他服务器的重复连接', (tester) async {
    SharedPreferences.setMockInitialValues({
      'server.servers': jsonEncode([
        {
          'id': 'first',
          'name': '第一台服务器',
          'lines': [
            {
              'id': 'first-line',
              'name': '主线路',
              'base_url': 'http://first.example:8001',
            },
          ],
          'active_line_id': 'first-line',
          'project_name': 'oh-my-media',
        },
        {
          'id': 'second',
          'name': '第二台服务器',
          'lines': [
            {
              'id': 'second-line',
              'name': '主线路',
              'base_url': 'http://second.example:8001',
            },
          ],
          'active_line_id': 'second-line',
          'project_name': 'oh-my-media',
        },
      ]),
      'server.active_server_id': 'first',
    });
    final prefs = await SharedPreferences.getInstance();

    await _enlargeSurface(tester);
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
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: ServerSetupPage(editing: true, serverId: 'first'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), 'second.example');
    await tester.tap(find.text('测试并保存'));
    await tester.pumpAndSettle();

    expect(find.textContaining('已存在相同连接'), findsOneWidget);
    expect(find.text('更换服务器'), findsOneWidget);
  });

  testWidgets('服务器列表添加入口打开统一服务器页面', (tester) async {
    final prefs = await _prefs();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: ServerListPage(),
        ),
      ),
    );

    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    expect(find.text('添加服务器'), findsOneWidget);
    expect(find.byType(ServerSetupPage), findsOneWidget);
    expect(find.byType(DropdownButton<ServerProject>), findsOneWidget);
  });
}

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

/// 凭据区块让表单变高，默认 600px 视口放不下保存按钮（懒加载不构建）。
Future<void> _enlargeSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _pumpSetup(
  WidgetTester tester,
  SharedPreferences prefs, {
  bool editing = false,
}) async {
  await _enlargeSurface(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('zh'),
        home: ServerSetupPage(editing: editing),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 挂上会话仓库与 AuthController 桩、探测直接成功的添加服务器页面。
Future<void> _pumpSetupWithAuth(
  WidgetTester tester,
  SharedPreferences prefs, {
  required AuthSessionRepository sessions,
  required _RecordingAuthController controller,
}) async {
  await _enlargeSurface(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        authSessionRepositoryProvider.overrideWithValue(sessions),
        authControllerProvider.overrideWith(() => controller),
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
      child: const MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: Locale('zh'),
        home: ServerSetupPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _selectProject(WidgetTester tester, String project) async {
  await tester.tap(find.byType(DropdownButton<ServerProject>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(project).last);
  await tester.pumpAndSettle();
}

/// 记录 loginForServer 调用参数的 AuthController 桩。
class _RecordingAuthController extends AuthController {
  _RecordingAuthController(this.error);

  final Object? error;
  final log = <Map<String, Object?>>[];

  @override
  Future<AuthState> build() async =>
      const AuthState(phase: AuthPhase.unconfigured);

  @override
  Future<void> loginForServer({
    required ServerProfile server,
    String? username,
    required String password,
    String? totpSecret,
  }) async {
    log.add({
      'serverId': server.id,
      'username': username,
      'password': password,
      'totpSecret': totpSecret,
    });
    if (error != null) throw error!;
  }
}

class _MemoryTokenStore implements AuthTokenStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
