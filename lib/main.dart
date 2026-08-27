import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/auth/auth_provider.dart';
import 'core/auth/auth_session.dart';
import 'core/config/server_config.dart';
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
    final cfg = ref.watch(serverConfigProvider);
    final auth = ref.watch(authControllerProvider);
    final serverSwitch = ref.watch(serverSwitchTransitionProvider);
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
        // 鉴权阶段切换（选择页 → 首页）用统一的淡入浮出过渡，
        // 避免登录成功瞬间整页硬切。
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey(_rootStageKey(cfg, serverSwitch, auth)),
            child: serverSwitch.isActive
                ? const _AuthenticatedHomeWithServerSwitch()
                : cfg == null
                ? const ServerSelectionPage()
                : auth.when(
                    skipLoadingOnReload: true,
                    loading: () => const ServerSelectionPage(),
                    error: (_, __) => const ServerSelectionPage(),
                    data: (state) => switch (state.phase) {
                      AuthPhase.needsLogin ||
                      AuthPhase.totpRequired ||
                      AuthPhase.serverSelection ||
                      AuthPhase.unconfigured => const ServerSelectionPage(),
                      AuthPhase.incompatible ||
                      AuthPhase.unavailable => const ServerSelectionPage(),
                      _ => const _AuthenticatedHome(),
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

/// 根路由当前阶段的稳定键：阶段变化时触发 AnimatedSwitcher 过渡，
/// 阶段内的重建（如登录中状态翻转）保持同一键，不触发换页动画。
String _rootStageKey(
  ServerConfig? cfg,
  ServerSwitchState serverSwitch,
  AsyncValue<AuthState> auth,
) {
  if (cfg == null) return 'selector';
  if (serverSwitch.isActive) return 'server-switch';
  final state = auth.valueOrNull;
  if (auth.hasError) return 'selector';
  return switch (state?.phase) {
    AuthPhase.needsLogin ||
    AuthPhase.totpRequired ||
    AuthPhase.serverSelection ||
    AuthPhase.unconfigured => 'selector',
    AuthPhase.incompatible || AuthPhase.unavailable => 'selector',
    _ => 'home',
  };
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
