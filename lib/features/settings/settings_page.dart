import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/server_config_provider.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';
import 'server_setup_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(serverConfigProvider);
    final c = appColors(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SETTINGS', style: AppText.eyebrow(context)),
                          const SizedBox(height: 3),
                          Text('Preferences', style: AppText.pageTitle(context)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _SettingsGroup(
                title: 'Server',
                items: [
                  _SettingsTile(
                    title: '服务器地址',
                    subtitle: cfg?.baseUrl ?? '未配置',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ServerSetupPage()),
                    ),
                  ),
                ],
              ),
              _SettingsGroup(
                title: 'Library',
                items: [
                  _SettingsTile(
                    title: '安全模式',
                    subtitle: '关闭后显示成人内容',
                    trailing: Switch(
                      value: true,
                      onChanged: (_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('安全模式开关尚未实现')),
                        );
                      },
                    ),
                  ),
                  _SettingsTile(
                    title: 'PIN 码',
                    subtitle: '未设置',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('PIN 码功能尚未实现')),
                      );
                    },
                  ),
                ],
              ),
              _SettingsGroup(
                title: 'About',
                items: [
                  const _SettingsTile(
                    title: '版本',
                    subtitle: '0.1.0',
                  ),
                  _SettingsTile(
                    title: '退出登录',
                    destructive: true,
                    onTap: () async {
                      await ref.read(serverConfigProvider.notifier).clear();
                      if (context.mounted) {
                        Navigator.of(context).popUntil((r) => r.isFirst);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.items});
  final String title;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 0, 10),
            child: Text(title.toUpperCase(), style: AppText.eyebrow(context)),
          ),
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.cardBorder),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  items[i],
                  if (i < items.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(height: 1, color: c.divider),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: destructive ? c.danger : c.text,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: AppText.meta(context)),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(Icons.chevron_right, size: 18, color: c.muted),
          ],
        ),
      ),
    );
  }
}
