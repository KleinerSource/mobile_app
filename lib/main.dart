import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/server_config_provider.dart';
import 'core/auth/auth_provider.dart';
import 'core/auth/auth_session.dart';
import 'core/auth/auth_session_provider.dart';
import 'core/platform/app_theme.dart';
import 'features/i18n/locale_providers.dart';
import 'features/i18n/theme_provider.dart';
import 'features/main/main_shell.dart';
import 'features/privacy/privacy_shield.dart';
import 'features/settings/server_setup_page.dart';
import 'features/settings/login_page.dart';
import 'l10n/generated/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    child: const MdCenterApp(),
  ));
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
      await ref.read(serverConfigProvider.notifier).clear();
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
                    onRetry: () => ref.invalidate(authControllerProvider),
                    onChangeServer: changeServer,
                  ),
              data: (state) => switch (state.phase) {
                AuthPhase.needsLogin || AuthPhase.totpRequired =>
                  const LoginPage(),
                AuthPhase.incompatible || AuthPhase.unavailable =>
                  _StartupError(
                    message: state.message ?? '服务器不可用',
                    onRetry: () => ref.invalidate(authControllerProvider),
                    onChangeServer: changeServer,
                  ),
                _ => const MainShell(),
              },
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
    required this.onRetry,
    required this.onChangeServer,
  });

  final String message;
  final VoidCallback onRetry;
  final Future<void> Function() onChangeServer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => onChangeServer(),
                icon: const Icon(Icons.dns_outlined),
                label: const Text('更换服务器'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
