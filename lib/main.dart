import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/auth/auth_provider.dart';
import 'core/auth/auth_session.dart';
import 'core/config/server_config_provider.dart';
import 'core/platform/app_haptics.dart';
import 'core/platform/app_theme.dart';
import 'core/platform/performance_monitor_overlay.dart';
import 'features/i18n/locale_providers.dart';
import 'features/i18n/theme_provider.dart';
import 'features/home/server_switch_transition.dart';
import 'features/main/media_manager_shell.dart';
import 'features/privacy/privacy_shield.dart';
import 'features/security/security_gate.dart';
import 'features/security/security_providers.dart';
import 'features/files/file_manager_shell.dart';
import 'features/player/common/player_settings.dart';
import 'features/player/audio/file_audio_metadata_session.dart';
import 'features/files/file_navigation.dart';
import 'features/player/audio/audio_playback_service.dart';
import 'features/settings/app_update_startup_gate.dart';
import 'features/settings/server_selection_page.dart';
import 'l10n/generated/app_localizations.dart';
import 'shared/top_snack_bar.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  unawaited(FileAudioMetadataSession.cleanupStaleCache());
  await AudioPlaybackService.initialize();
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
    final playerSettings = ref.watch(playerSettingsProvider);
    final showPerformanceMonitor =
        playerSettings.debugMode && playerSettings.performanceMonitorEnabled;

    return MaterialApp(
      title: 'Oh My Media',
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
          child: PrivacyShield(
            child: Stack(
              children: [
                child ?? const SizedBox.shrink(),
                if (showPerformanceMonitor)
                  const Positioned.fill(child: PerformanceMonitorOverlay()),
              ],
            ),
          ),
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
/// 立即反向拖动。服务器切换层是透明的零时长页面，视觉转场只由头像动画负责。
/// 目录子页也使用相同的页面路由，因此不会再有两套手势逻辑。
class _AppNavigator extends ConsumerStatefulWidget {
  const _AppNavigator();

  static const _selectorKey = ValueKey<String>('server-selector');
  static const _mediaKey = ValueKey<String>('server-media');
  static const _fileKey = ValueKey<String>('server-files');
  static const _switchKey = ValueKey<String>('server-switch');

  @override
  ConsumerState<_AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends ConsumerState<_AppNavigator> {
  bool _contentWasVisible = false;
  bool _contentRemovalBelongsToServerSwitch = false;
  late final NavigatorObserver _routeObserver;
  final Set<Route<dynamic>> _observedContentRoutes = <Route<dynamic>>{};
  final Set<Route<dynamic>> _ignoredContentRoutes = <Route<dynamic>>{};
  Animation<double>? _pendingExitAnimation;
  AnimationStatusListener? _pendingExitListener;

  @override
  void initState() {
    super.initState();
    _routeObserver = _AppRouteObserver(_observeRouteExit);
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final config = ref.watch(serverConfigProvider);
    final auth = ref.watch(authControllerProvider);
    final serverSwitch = ref.watch(serverSwitchTransitionProvider);
    final selectionRequested = ref.watch(serverSelectionRequestedProvider);
    final isAuthenticated = auth.valueOrNull?.phase == AuthPhase.authenticated;
    final isFinishingServerSwitch =
        serverSwitch.phase == ServerSwitchPhase.finishing;
    final showContent =
        config != null &&
        (!selectionRequested || isFinishingServerSwitch) &&
        isAuthenticated &&
        (!serverSwitch.isActive || isFinishingServerSwitch);
    final isFileServer = config?.activeServer?.project?.isFileSource == true;

    // 切换服务器会先从声明式栈移除旧首页，再挂载切换遮罩。移除回调可能
    // 在异步切换完成后才到达，因此不能只在回调里读取 isActive 判断归属。
    if (_contentWasVisible && !showContent && serverSwitch.isActive) {
      _contentRemovalBelongsToServerSwitch = true;
    }
    _contentWasVisible = showContent;

    final pages = <Page<void>>[
      const MaterialPage<void>(
        key: _AppNavigator._selectorKey,
        child: ServerSelectionPage(),
      ),
      if (showContent && !isFileServer)
        const _ServerContentPage<void>(
          key: _AppNavigator._mediaKey,
          child: _AuthenticatedMediaHome(),
        ),
      if (showContent && isFileServer)
        const _ServerContentPage<void>(
          key: _AppNavigator._fileKey,
          name: fileManagerRootRouteName,
          child: _AuthenticatedFileHome(),
        ),
      if (serverSwitch.isActive)
        const _NoTransitionPage<void>(
          key: _AppNavigator._switchKey,
          child: _AuthenticatedHomeWithServerSwitch(),
        ),
    ];

    return ServerNavigationScope(
      child: Navigator(
        observers: [_routeObserver],
        pages: pages,
        // 页面栈必须接收 Navigator 的真实返回；资源释放由 route observer
        // 等待退出动画结束后执行，不能在 onDidRemovePage 的 pop 开始时执行。
        onDidRemovePage: (_) {},
      ),
    );
  }

  void _observeRouteExit(Route<dynamic> route, {required bool didPop}) {
    final settings = route.settings;
    if (settings is! Page<void> ||
        (settings.key != _AppNavigator._mediaKey &&
            settings.key != _AppNavigator._fileKey)) {
      return;
    }

    if (!didPop) {
      // didRemove 是 pop 动画完成后的第二个通知；正常 pop 已经在 didPop
      // 中登记，不能在这里再次释放。没有 didPop 的强制移除才直接处理。
      if (_ignoredContentRoutes.remove(route) ||
          _observedContentRoutes.remove(route)) {
        return;
      }
      _releaseServerResources();
      return;
    }

    if (!_observedContentRoutes.add(route)) return;

    final belongsToServerSwitch = _contentRemovalBelongsToServerSwitch;
    _contentRemovalBelongsToServerSwitch = false;
    if (belongsToServerSwitch) {
      _observedContentRoutes.remove(route);
      _ignoredContentRoutes.add(route);
      return;
    }

    final animation = route is TransitionRoute<dynamic>
        ? route.animation
        : null;
    if (animation == null || animation.status == AnimationStatus.dismissed) {
      _releaseServerResources();
      return;
    }

    void onStatusChanged(AnimationStatus status) {
      if (status != AnimationStatus.dismissed) return;
      animation.removeStatusListener(onStatusChanged);
      if (identical(_pendingExitAnimation, animation)) {
        _pendingExitAnimation = null;
        _pendingExitListener = null;
      }
      _releaseServerResources();
    }

    _pendingExitAnimation = animation;
    _pendingExitListener = onStatusChanged;
    animation.addStatusListener(onStatusChanged);
  }

  void _releaseServerResources() {
    if (!mounted) return;
    // 选择器已经在父路由中可见；此时再卸载运行态，下一次选择会重新创建
    // 媒体客户端或 SMB/WebDAV 连接，而不会与退出动画争用旧资源。
    ref.read(serverConfigProvider.notifier).showServerSelection();
  }

  @override
  void dispose() {
    final animation = _pendingExitAnimation;
    final listener = _pendingExitListener;
    if (animation != null && listener != null) {
      animation.removeStatusListener(listener);
    }
    _pendingExitAnimation = null;
    _pendingExitListener = null;
    _observedContentRoutes.clear();
    _ignoredContentRoutes.clear();
    super.dispose();
  }
}

class _AppRouteObserver extends NavigatorObserver {
  _AppRouteObserver(this.onRouteExit);

  final void Function(Route<dynamic> route, {required bool didPop}) onRouteExit;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onRouteExit(route, didPop: true);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onRouteExit(route, didPop: false);
  }
}

class _NoTransitionPage<T> extends Page<T> {
  const _NoTransitionPage({super.key, required this.child});

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) {
    return PageRouteBuilder<T>(
      settings: this,
      opaque: false,
      maintainState: true,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    );
  }
}

class _ServerContentPage<T> extends Page<T> {
  const _ServerContentPage({required this.child, super.key, super.name});

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) {
    return _ServerContentPageRoute<T>(page: this);
  }
}

class _ServerContentPageRoute<T> extends PageRoute<T>
    with MaterialRouteTransitionMixin<T> {
  _ServerContentPageRoute({required this.page}) : super(settings: page);

  final _ServerContentPage<T> page;

  @override
  Widget buildContent(BuildContext context) => page.child;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration =>
      _disableTransitions ? Duration.zero : super.transitionDuration;

  @override
  Duration get reverseTransitionDuration =>
      _disableTransitions ? Duration.zero : super.reverseTransitionDuration;

  bool get _disableTransitions {
    final navigatorContext = navigator?.context;
    if (navigatorContext == null) return false;
    return ProviderScope.containerOf(
      navigatorContext,
      listen: false,
    ).read(serverSwitchTransitionProvider).isActive;
  }
}

class _AuthenticatedHomeWithServerSwitch extends StatelessWidget {
  const _AuthenticatedHomeWithServerSwitch();

  @override
  Widget build(BuildContext context) {
    // 切换期间不能挂载媒体管理器 Shell：目标服务器尚未完成鉴权时，DBO 首页
    // 会立即请求 recommend/latest 等受保护接口并产生 401。切换层保持透明，
    // 由下方选择页作为头像飞行阶段的底图，进入 finishing 后再揭示已挂载的首页。
    return const Stack(
      fit: StackFit.expand,
      children: [ServerSwitchTransitionOverlay()],
    );
  }
}

class _AuthenticatedMediaHome extends ConsumerWidget {
  const _AuthenticatedMediaHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StartupUpdateGate(
      enabled: ref.watch(securityGateReadyProvider),
      child: const MediaManagerShell(),
    );
  }
}

class _AuthenticatedFileHome extends ConsumerWidget {
  const _AuthenticatedFileHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StartupUpdateGate(
      enabled: ref.watch(securityGateReadyProvider),
      child: const FileManagerShell(),
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
