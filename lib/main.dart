import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/server_config_provider.dart';
import 'core/platform/app_theme.dart';
import 'features/i18n/locale_providers.dart';
import 'features/main/main_shell.dart';
import 'features/privacy/privacy_shield.dart';
import 'features/settings/server_setup_page.dart';
import 'l10n/generated/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    final appLocale = ref.watch(localeProvider);
    return MaterialApp(
      title: 'md_center',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      locale: appLocale.toLocale(),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      builder: (context, child) {
        return PrivacyShield(child: child ?? const SizedBox.shrink());
      },
      home: cfg == null ? const ServerSetupPage() : const MainShell(),
    );
  }
}
