import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/platform/app_log_store.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glow_background.dart';
import 'settings_common.dart';

/// 应用内播放排障日志页，适用于无法连接 Xcode 的真机环境。
class AppLogPage extends StatelessWidget {
  const AppLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final l = AppL10n.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            header: SettingsSubPageHeader(
              eyebrow: l.settingsAppUpdate,
              title: l.appLogTitle,
              subtitle: l.appLogSubtitle,
            ),
            body: ValueListenableBuilder<List<String>>(
              valueListenable: AppLogStore.instance.listenable,
              builder: (context, entries, _) {
                return ListView(
                  primary: true,
                  padding: const EdgeInsets.only(bottom: 80),
                  children: [
                    SettingsGroup(
                      title: l.commonActions,
                      items: [
                        SettingsTile(
                          title: l.appLogCopyAll,
                          subtitle: entries.isEmpty
                              ? l.appLogEmpty
                              : l.appLogCount(entries.length),
                          leadingIcon: Icons.copy_all_outlined,
                          onTap: entries.isEmpty
                              ? null
                              : () => _copyLogs(context),
                        ),
                        SettingsTile(
                          title: l.appLogClear,
                          subtitle: l.appLogClearSub,
                          leadingIcon: Icons.delete_outline,
                          onTap: entries.isEmpty
                              ? null
                              : () => _clearLogs(context),
                        ),
                      ],
                    ),
                    SettingsGroup(
                      title: l.appLogContent,
                      items: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Container(
                            height: 420,
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colors.bg.withValues(alpha: 0.62),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colors.cardBorder),
                            ),
                            child: entries.isEmpty
                                ? Center(
                                    child: Text(
                                      l.appLogEmptyHint,
                                      textAlign: TextAlign.center,
                                      style: AppText.meta(context),
                                    ),
                                  )
                                : SelectionArea(
                                    child: ListView.builder(
                                      primary: false,
                                      itemCount: entries.length,
                                      itemBuilder: (context, index) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        child: Text(
                                          entries[index],
                                          style: TextStyle(
                                            color: colors.text,
                                            fontFamily: 'monospace',
                                            fontSize: 11,
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copyLogs(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: AppLogStore.instance.text));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppL10n.of(context).appLogCopied)));
    }
  }

  Future<void> _clearLogs(BuildContext context) async {
    AppLogStore.instance.clear();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppL10n.of(context).appLogCleared)));
  }
}
