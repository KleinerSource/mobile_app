import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/server_config_provider.dart';
import '../../core/platform/platform.dart';
import 'server_setup_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(serverConfigProvider);
    return AppScaffold(
      body: ListView(
        children: [
          const SizedBox(height: 24),
          ListTile(
            title: const Text('服务器地址'),
            subtitle: Text(cfg?.baseUrl ?? '未配置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ServerSetupPage()),
            ),
          ),
        ],
      ),
    );
  }
}
