import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/server_config_provider.dart';
import 'core/ui/theme.dart';
import 'features/main/main_shell.dart';
import 'features/settings/server_setup_page.dart';

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
    return MaterialApp(
      title: 'md_center',
      debugShowCheckedModeBanner: false,
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: cfg == null ? const ServerSetupPage() : const MainShell(),
    );
  }
}
