import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/auth/auth_provider.dart';
import 'core/auth/auth_session.dart';
import 'core/config/server_config_provider.dart';
import 'core/platform/app_haptics.dart';
import 'core/platform/app_theme.dart';
import 'features/i18n/locale_providers.dart';
import 'features/i18n/theme_provider.dart';
import 'features/home/server_switch_transition.dart';
import 'features/main/main_shell.dart';
import 'features/privacy/privacy_shield.dart';
import 'features/security/security_gate.dart';
import 'features/security/security_providers.dart';
import 'features/settings/app_update_startup_gate.dart';
import 'features/settings/server_selection_page.dart';
import 'l10n/generated/app_localizations.dart';
import 'shared/top_snack_bar.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const _AppBootstrap());
}

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  late final Future<SharedPreferences> _preferencesFuture;

  @override
  void initState() {
    super.initState();
    _preferencesFuture = SharedPreferences.getInstance();
    _preferencesFuture.then(AppHaptics.configureFromPreferences);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: _preferencesFuture,
      builder: (context, snapshot) {
        final prefs = snapshot.data;
        if (prefs == null) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(Brightness.dark),
            home: const _BootSplash(),
          );
        }
        return ProviderScope(
          overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
          child: const OmmApp(),
        );
      },
    );
  }
}

class OmmApp extends ConsumerWidget {
  const OmmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Oh-My-Media',
      debugShowCheckedModeBanner: false,
      navigatorKey: _rootNavigatorKey,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: themeMode.toMaterial(),
      locale: appLocale.toLocale(),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      builder: (context, child) {
        return TopSnackBarMessenger(
          navigatorKey: _rootNavigatorKey,
          child: PrivacyShield(child: child ?? const SizedBox.shrink()),
        );
      },
      home: SecurityGate(
        onReady: () {
          ref.read(securityGateReadyProvider.notifier).state = true;
        },
        child: const _AppNavigator(),
      ),
    );
  }
}

/// 应用内服务器导航栈：选择器始终是父页，服务器内容是可交互返回的子页。
///
/// 服务器内容使用 [MaterialPage]，复用 OMM 普通详情页的自适应页面返回手势：
/// 拖动时上一页会持续绘制在下层，释放时可根据速度完成或取消，取消后还能
/// 立即反向拖动。目录子页也使用相同的页面路由，因此不会再有两套手势逻辑。
class _AppNavigator extends ConsumerStatefulWidget {
  const _AppNavigator();

  static const _selectorKey = ValueKey<String>('server-selector');
  static const _homeKey = ValueKey<String>('server-home');
  static const _switchKey = ValueKey<String>('server-switch');

  @override
  ConsumerState<_AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends ConsumerState<_AppNavigator> {
  bool _homeWasVisible = false;
  bool _homeRemovalBelongsToServerSwitch = false;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final config = ref.watch(serverConfigProvider);
    final auth = ref.watch(authControllerProvider);
    final serverSwitch = ref.watch(serverSwitchTransitionProvider);
    final selectionRequested = ref.watch(serverSelectionRequestedProvider);
    final isAuthenticated = auth.valueOrNull?.phase == AuthPhase.authenticated;
    final showHome =
        config != null &&
        !selectionRequested &&
        isAuthenticated &&
        !serverSwitch.isActive;

    // 切换服务器会先从声明式栈移除旧首页，再挂载切换遮罩。移除回调可能
    // 在异步切换完成后才到达，因此不能只在回调里读取 isActive 判断归属。
    if (_homeWasVisible && !showHome && serverSwitch.isActive) {
      _homeRemovalBelongsToServerSwitch = true;
    }
    _homeWasVisible = showHome;

    final pages = <Page<void>>[
      const MaterialPage<void>(
        key: _AppNavigator._selectorKey,
        allowSnapshotting: false,
        child: ServerSelectionPage(),
      ),
      if (showHome)
        const MaterialPage<void>(
          key: _AppNavigator._homeKey,
          allowSnapshotting: false,
          child: _AuthenticatedHome(),
        ),
      if (serverSwitch.isActive)
        const MaterialPage<void>(
          key: _AppNavigator._switchKey,
          allowSnapshotting: false,
          child: _AuthenticatedHomeWithServerSwitch(),
        ),
    ];

    return ServerNavigationScope(
      child: Navigator(
        pages: pages,
        onDidRemovePage: (page) {
          if (page.key != _AppNavigator._homeKey) {
            return;
          }
          if (_homeRemovalBelongsToServerSwitch) {
            _homeRemovalBelongsToServerSwitch = false;
            return;
          }
          // 真实页面返回（包括边缘手势完成）后才释放运行态资源；选择器
          // 已经在下层可见，重新选择服务器时会从持久化配置重新连接。
          ref.read(serverConfigProvider.notifier).showServerSelection();
        },
      ),
    );
  }
}

class _AuthenticatedHomeWithServerSwitch extends StatelessWidget {
  const _AuthenticatedHomeWithServerSwitch();

  @override
  Widget build(BuildContext context) {
    // 切换期间不能挂载 MainShell：目标服务器尚未完成鉴权时，DBO 首页
    // 会立即请求 recommend/latest 等受保护接口并产生 401。
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
        const ServerSwitchTransitionOverlay(),
      ],
    );
  }
}

class _AuthenticatedHome extends ConsumerWidget {
  const _AuthenticatedHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StartupUpdateGate(
      enabled: ref.watch(securityGateReadyProvider),
      child: const MainShell(),
    );
  }
}

/// SharedPreferences 就绪前的冷启动闪屏，无法读取服务器配置，仅显示背景与
/// 轻量加载指示。
class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}
