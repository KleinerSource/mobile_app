import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api/server_compatibility.dart';
import 'core/auth/auth_provider.dart';
import 'core/auth/auth_session.dart';
import 'core/auth/auth_session_provider.dart';
import 'core/config/server_config_provider.dart';
import 'core/diagnostics/crash_log_service.dart';
import 'core/platform/app_haptics.dart';
import 'core/platform/app_theme.dart';
import 'features/i18n/locale_providers.dart';
import 'features/i18n/theme_provider.dart';
import 'features/main/main_shell.dart';
import 'features/privacy/privacy_shield.dart';
import 'features/security/security_gate.dart';
import 'features/settings/app_update_startup_gate.dart';
import 'features/settings/server_setup_page.dart';
import 'features/settings/login_page.dart';
import 'l10n/generated/app_localizations.dart';
import 'shared/glass.dart';
import 'shared/glow_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final crashLogs = await CrashLogService.create();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _recordCrashSafely(
      crashLogs,
      details.exception,
      details.stack ?? StackTrace.empty,
      source: 'flutter',
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    _recordCrashSafely(crashLogs, error, stack, source: 'platform');
    return true;
  };

  await runZonedGuarded(() async {
    MediaKit.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    AppHaptics.configureFromPreferences(prefs);
    await crashLogs.recordMessage('应用启动', source: 'app');
    runApp(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        crashLogServiceProvider.overrideWithValue(crashLogs),
      ],
      child: const MdCenterApp(),
    ));
  }, (error, stack) {
    _recordCrashSafely(crashLogs, error, stack, source: 'zone');
  });
}

void _recordCrashSafely(
  CrashLogService service,
  Object error,
  StackTrace stack, {
  required String source,
}) {
  try {
    service.recordErrorSync(error, stack, source: source);
  } catch (_) {
    // 崩溃处理器不能因为日志写入失败再次抛错。
  }
}

class MdCenterApp extends ConsumerWidget {
  const MdCenterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(serverConfigProvider);
    final auth = ref.watch(authControllerProvider);
    final appLocale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    Future<void> changeServer() async {
      await ref.read(authSessionRepositoryProvider).clear();
      ref.read(serverConfigProvider.notifier).beginEdit();
    }

    return MaterialApp(
      title: 'MD Center',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: themeMode.toMaterial(),
      locale: appLocale.toLocale(),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      builder: (context, child) {
        return PrivacyShield(child: child ?? const SizedBox.shrink());
      },
      home: cfg == null
          ? const ServerSetupPage()
          : auth.when(
              loading: () => const _StartupLoading(),
              error: (error, _) => _StartupError(
                    message: error.toString(),
                    serverUrl: cfg.baseUrl,
                    incompatible: error is ServerCompatibilityException,
                    onRetry: () => ref.invalidate(authControllerProvider),
                    onChangeServer: changeServer,
                  ),
              data: (state) => switch (state.phase) {
                AuthPhase.needsLogin || AuthPhase.totpRequired =>
                  const LoginPage(),
                AuthPhase.incompatible || AuthPhase.unavailable =>
                  _StartupError(
                    message: state.message ?? '服务器不可用',
                    serverUrl: cfg.baseUrl,
                    incompatible: state.phase == AuthPhase.incompatible,
                    onRetry: () => ref.invalidate(authControllerProvider),
                    onChangeServer: changeServer,
                  ),
                _ => const _AuthenticatedHome(),
              },
            ),
    );
  }
}

class _AuthenticatedHome extends StatefulWidget {
  const _AuthenticatedHome();

  @override
  State<_AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<_AuthenticatedHome> {
  bool _securityReady = false;

  @override
  Widget build(BuildContext context) {
    return SecurityGate(
      onReady: () {
        if (!mounted || _securityReady) return;
        setState(() => _securityReady = true);
      },
      child: StartupUpdateGate(
        enabled: _securityReady,
        child: const MainShell(),
      ),
    );
  }
}

class _StartupLoading extends StatelessWidget {
  const _StartupLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({
    required this.message,
    required this.serverUrl,
    required this.incompatible,
    required this.onRetry,
    required this.onChangeServer,
  });

  final String message;
  final String? serverUrl;
  final bool incompatible;
  final VoidCallback onRetry;
  final Future<void> Function() onChangeServer;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: GlassPanel(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildIcon(c),
                        const SizedBox(height: 18),
                        Text(
                          incompatible ? '服务器需要更新' : '暂时无法连接服务器',
                          textAlign: TextAlign.center,
                          style: AppText.pageTitle(context).copyWith(fontSize: 25),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          incompatible
                              ? '当前 App 已更新，但连接的 MD Center 服务端版本较旧。请先更新服务端，或切换到已兼容的服务器。'
                              : '请检查服务器地址和网络连接，然后重试。',
                          textAlign: TextAlign.center,
                          style: AppText.body(context),
                        ),
                        const SizedBox(height: 22),
                        _buildDetails(context, c),
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh),
                          label: Text(incompatible ? '重新检查服务器' : '重试'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => onChangeServer(),
                          icon: const Icon(Icons.dns_outlined),
                          label: const Text('更换服务器'),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(AppColors c) {
    final color = incompatible ? c.warning : c.danger;
    return Center(
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(
          incompatible ? Icons.system_update_alt_outlined : Icons.cloud_off_outlined,
          color: color,
          size: 30,
        ),
      ),
    );
  }

  Widget _buildDetails(BuildContext context, AppColors c) {
    final compatibilityMessage = message.trim().isNotEmpty
        ? message.trim()
        : serverCompatibilityRequirementMessage;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (serverUrl?.isNotEmpty == true) ...[
              Text('当前服务器', style: AppText.meta(context)),
              const SizedBox(height: 4),
              Text(
                serverUrl!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.mono(context, size: 12, color: c.text),
              ),
              if (incompatible) const SizedBox(height: 12),
            ],
            if (incompatible) ...[
              Text('兼容性要求', style: AppText.meta(context)),
              const SizedBox(height: 4),
              Text(
                compatibilityMessage,
                style: AppText.body(context).copyWith(color: c.warning),
              ),
            ] else
              Text(message, style: AppText.body(context)),
          ],
        ),
      ),
    );
  }
}
