import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/platform/app_log_store.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';
import 'settings_common.dart';

/// 应用内播放排障日志页，适用于无法连接 Xcode 的真机环境。
class AppLogPage extends StatelessWidget {
  const AppLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            header: const SettingsSubPageHeader(
              eyebrow: '应用更新',
              title: '播放日志',
              subtitle: '复现问题后返回此页，复制日志发给开发者分析',
            ),
            body: ValueListenableBuilder<List<String>>(
              valueListenable: AppLogStore.instance.listenable,
              builder: (context, entries, _) {
                return ListView(
                  primary: true,
                  padding: const EdgeInsets.only(bottom: 80),
                  children: [
                    SettingsGroup(
                      title: '操作',
                      items: [
                        SettingsTile(
                          title: '复制全部日志',
                          subtitle: entries.isEmpty
                              ? '当前没有可复制的日志'
                              : '共 ${entries.length} 条，仅保留本次运行期间的最近记录',
                          leadingIcon: Icons.copy_all_outlined,
                          onTap: entries.isEmpty
                              ? null
                              : () => _copyLogs(context),
                        ),
                        SettingsTile(
                          title: '清空日志',
                          subtitle: '清空后重新复现，可减少无关信息',
                          leadingIcon: Icons.delete_outline,
                          onTap: entries.isEmpty
                              ? null
                              : () => _clearLogs(context),
                        ),
                      ],
                    ),
                    SettingsGroup(
                      title: '日志内容',
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
                                      '暂无日志\n先播放一次 SMB / WebDAV 视频',
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
      ).showSnackBar(const SnackBar(content: Text('日志已复制，可粘贴发送给开发者')));
    }
  }

  Future<void> _clearLogs(BuildContext context) async {
    AppLogStore.instance.clear();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('日志已清空')));
  }
}
