import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/auth/auth_provider.dart';
import 'package:omm/core/auth/auth_session.dart';
import 'package:omm/core/api/server_connection.dart';
import 'package:omm/core/api/server_compatibility.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/config/server_line_probe.dart';
import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/core/sources/common/source_descriptor.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/files/file_source_providers.dart';
import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/files/file_manager_shell.dart';
import 'package:omm/features/home/server_switch_transition.dart';
import 'package:omm/features/main/media_manager_shell.dart';
import 'package:omm/features/settings/server_selection_page.dart';
import 'package:omm/features/security/security_providers.dart';
import 'package:omm/features/security/security_repository.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/main.dart';
import 'package:omm/shared/floating_tab_bar.dart';
import 'package:omm/shared/glass_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ServerConfigState extends ServerConfigNotifier {
  _ServerConfigState(this.config);

  final ServerConfig config;

  @override
  ServerConfig build() => config;
}

class _AuthenticatedAuthState extends AuthController {
  @override
  Future<AuthState> build() async =>
      const AuthState(phase: AuthPhase.authenticated);
}

class _UnlockedSecurityState extends SecurityController {
  @override
  Future<SecuritySettings> build() async => const SecuritySettings.empty();
}

ServerConfig _mainNavigationConfig() {
  const mediaLine = ServerLine(
    id: 'media-line',
    name: '媒体线路',
    baseUrl: 'https://media.example',
  );
  const fileLine = ServerLine(
    id: 'file-line',
    name: '文件线路',
    baseUrl: 'smb://file.example/share',
  );
  final mediaServer = ServerProfile(
    id: 'media-server',
    name: '媒体服务器',
    lines: const [mediaLine],
    activeLineId: mediaLine.id,
    projectName: 'db_online',
  );
  final fileServer = ServerProfile(
    id: 'file-server',
    name: '文件服务器',
    lines: const [fileLine],
    activeLineId: fileLine.id,
    projectName: 'smb',
  );
  return ServerConfig(
    baseUrl: mediaLine.baseUrl,
    lines: const [mediaLine],
    servers: [mediaServer, fileServer],
    activeServerId: mediaServer.id,
  );
}

Future<void> _pumpMainNavigationApp(
  WidgetTester tester,
  SharedPreferences prefs,
  ServerConfig config, {
  bool activateMedia = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        serverConfigProvider.overrideWith(() => _ServerConfigState(config)),
        serverLineProbeCoordinatorProvider.overrideWithValue(
          ServerLineProbeCoordinator(
            probe: (line) async => ServerLineProbeResult.success(
              line,
              1,
              versionInfo: const ServerVersionInfo(
                projectName: 'db_online',
                version: 'test',
              ),
            ),
          ),
        ),
        authControllerProvider.overrideWith(_AuthenticatedAuthState.new),
        securityControllerProvider.overrideWith(_UnlockedSecurityState.new),
        dbOnlineRecommendProvider.overrideWith(
          (ref) async => const <DbOnlineMovie>[],
        ),
        dbOnlineLatestUpdatedProvider.overrideWith(
          (ref) async => const <DbOnlineMovie>[],
        ),
        dbOnlineLatestReleasedProvider.overrideWith(
          (ref) async => const <DbOnlineMovie>[],
        ),
        fileSourceDescriptorsProvider('file-server').overrideWith(
          (ref) async => [
            const SourceDescriptor(
              id: SourceId('file-source'),
              kind: SourceKind.smb,
              name: '测试文件来源',
              serverId: 'file-server',
              endpoint: 'smb://file.example/share',
            ),
          ],
        ),
      ],
      child: const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: OmmApp(),
      ),
    ),
  );
  if (activateMedia) {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OmmApp)),
      listen: false,
    );
    container
        .read(serverRuntimeProvider.notifier)
        .beginSwitch(ServerRuntimeLane.media, 'media-server');
    container
        .read(mediaServerConnectionProvider.notifier)
        .activate('media-server');
    container
        .read(serverRuntimeProvider.notifier)
        .commit(ServerRuntimeLane.media, 'media-server');
  }
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (condition()) return;
  }
  fail('等待界面状态超时');
}

void main() {
  testWidgets('冷启动保留服务器配置但不恢复运行实例', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await _pumpMainNavigationApp(
      tester,
      prefs,
      _mainNavigationConfig(),
      activateMedia: false,
    );

    expect(find.byType(MediaManagerShell), findsNothing);
    expect(find.byType(FileManagerShell), findsNothing);
    expect(find.byType(ServerSelectionPage), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OmmApp)),
      listen: false,
    );
    expect(container.read(serverRuntimeProvider).hasAnyServer, isFalse);
    expect(container.read(mediaServerConnectionProvider).suspended, isTrue);
    expect(container.read(fileServerConnectionProvider).suspended, isTrue);
  });

  testWidgets('媒体内容页返回服务器选择器而不是直接退出应用', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await _pumpMainNavigationApp(tester, prefs, _mainNavigationConfig());

    expect(find.byType(MediaManagerShell), findsOneWidget);

    // `handlePopRoute` 模拟的是传统平台返回，不会触发
    // `NavigatorPopHandler` 的 predictive-back 回调。直接驱动同一个嵌套
    // Navigator，验证回调最终委托的真实页面栈行为。
    final popped = await Navigator.of(
      tester.element(find.byType(MediaManagerShell)),
    ).maybePop();
    expect(popped, isTrue);
    await _pumpUi(tester);

    expect(find.byType(ServerSelectionPage), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OmmApp)),
      listen: false,
    );
    expect(container.read(serverRuntimeProvider).hasAnyServer, isFalse);
    expect(container.read(mediaServerConnectionProvider).suspended, isTrue);
    expect(container.read(fileServerConnectionProvider).suspended, isTrue);
  });

  testWidgets('媒体首页长按滑动选择文件服务器不会回到服务器选择器', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await _pumpMainNavigationApp(tester, prefs, _mainNavigationConfig());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OmmApp)),
      listen: false,
    );

    expect(find.byType(MediaManagerShell), findsOneWidget);

    final homeIcon = find.descendant(
      of: find.byType(FloatingTabBar<Object?>),
      matching: find.byIcon(Icons.home_rounded),
    );
    final homeAnchor = find.ancestor(
      of: homeIcon,
      matching: find.byType(GlassMenuAnchor<Object?>),
    );
    expect(homeAnchor, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(homeAnchor));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    final fileServerEntry = find.text('文件服务器').last;
    expect(fileServerEntry, findsOneWidget);
    await gesture.moveTo(tester.getCenter(fileServerEntry));
    await tester.pump();
    await gesture.up();
    await _pumpUntil(
      tester,
      () =>
          container.read(serverRuntimeProvider).visibleLane ==
              ServerRuntimeLane.files &&
          !container.read(serverSwitchTransitionProvider).isActive,
    );

    expect(find.byType(FileManagerShell), findsOneWidget);
    expect(find.byType(MediaManagerShell), findsNothing);
    expect(find.byType(MediaManagerShell, skipOffstage: false), findsOneWidget);
    expect(find.byType(ServerSelectionPage), findsNothing);
    final runtime = container.read(serverRuntimeProvider);
    expect(runtime.media.serverId, 'media-server');
    expect(runtime.files.serverId, 'file-server');
    expect(runtime.visibleLane, ServerRuntimeLane.files);
    expect(
      find.byType(ServerSelectionPage, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('媒体与文件 Shell 往返切换保留各自 Tab 状态', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await _pumpMainNavigationApp(tester, prefs, _mainNavigationConfig());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OmmApp)),
      listen: false,
    );

    await tester.tap(find.byIcon(Icons.video_library_rounded));
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      tester
          .widget<FloatingTabBar<Object?>>(find.byType(FloatingTabBar<Object?>))
          .active,
      1,
    );

    await container
        .read(serverSwitchTransitionProvider.notifier)
        .switchTo('file-server');
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(MediaManagerShell, skipOffstage: false), findsOneWidget);
    expect(find.byType(FileManagerShell, skipOffstage: false), findsOneWidget);
    await tester.tap(find.byIcon(Icons.star_rounded).last);
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      tester
          .widget<FloatingTabBar<String>>(find.byType(FloatingTabBar<String>))
          .active,
      1,
    );

    await container.read(authControllerProvider.future);
    await container
        .read(serverSwitchTransitionProvider.notifier)
        .switchTo('media-server');
    await _pumpUntil(
      tester,
      () =>
          container.read(serverRuntimeProvider).visibleLane ==
              ServerRuntimeLane.media &&
          !container.read(serverSwitchTransitionProvider).isActive,
    );
    expect(
      tester
          .widget<FloatingTabBar<Object?>>(find.byType(FloatingTabBar<Object?>))
          .active,
      1,
    );

    await container
        .read(serverSwitchTransitionProvider.notifier)
        .switchTo('file-server');
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      tester
          .widget<FloatingTabBar<String>>(find.byType(FloatingTabBar<String>))
          .active,
      1,
    );
  });
}
