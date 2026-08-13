import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/diagnostics/crash_log_service.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';
import 'settings_common.dart';

class CrashLogsPage extends ConsumerStatefulWidget {
  const CrashLogsPage({super.key});

  @override
  ConsumerState<CrashLogsPage> createState() => _CrashLogsPageState();
}

class _CrashLogsPageState extends ConsumerState<CrashLogsPage> {
  bool _exporting = false;
  bool _clearing = false;

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(crashLogEntriesProvider);
    final c = appColors(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            header: SettingsSubPageHeader(
                  eyebrow: '通用',
                  title: '崩溃日志',
                  subtitle: '日志已自动脱敏，仅保留最近记录。',
                  trailing: IconButton(
                    tooltip: '导出日志',
                    onPressed: _exporting ? null : () => _export(context),
                    icon: _exporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.ios_share_outlined),
                  ),
                ),
            body: RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                entries.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => _StatusPanel(
                    icon: Icons.error_outline,
                    message: '日志读取失败: $error',
                  ),
                  data: (items) => _buildContent(context, items),
                ),
                const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<CrashLogEntry> entries) {
    if (entries.isEmpty) {
      return const _StatusPanel(
        icon: Icons.check_circle_outline,
        message: '暂无崩溃或播放错误日志',
      );
    }
    return Column(
      children: [
        SettingsGroup(
          title: '日志管理',
          items: [
            SettingsTile(
              title: '最近记录',
              subtitle: '共 ${entries.length} 条，点击记录可查看详细堆栈',
              leadingIcon: Icons.history_outlined,
              trailing: TextButton.icon(
                onPressed: _clearing ? null : () => _clear(context),
                icon: const Icon(Icons.delete_sweep_outlined, size: 17),
                label: const Text('清空'),
              ),
            ),
          ],
        ),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
            child: _CrashLogCard(entry: entry),
          ),
      ],
    );
  }

  Future<void> _reload() async {
    ref.invalidate(crashLogEntriesProvider);
    await ref.read(crashLogEntriesProvider.future);
  }

  Future<void> _export(BuildContext context) async {
    setState(() => _exporting = true);
    try {
      final service = ref.read(crashLogServiceProvider);
      final file = service.logFile;
      await file.create(recursive: true);
      final nativeFiles = await service.nativeReportFiles();
      final exportFiles = <XFile>[
        XFile(file.path),
        if (await service.nativeLogFile.exists())
          XFile(service.nativeLogFile.path),
        ...nativeFiles.map((item) => XFile(item.path)),
      ];
      if (!context.mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final origin = box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size;
      await Share.shareXFiles(
        exportFiles,
        subject: 'MD Center 崩溃日志',
        sharePositionOrigin: origin,
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _clear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空崩溃日志？'),
        content: const Text('已保存的应用与播放错误记录将被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _clearing = true);
    try {
      await ref.read(crashLogServiceProvider).clear();
      ref.invalidate(crashLogEntriesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('崩溃日志已清空')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清空失败: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }
}

class _CrashLogCard extends StatelessWidget {
  const _CrashLogCard({required this.entry});

  final CrashLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDetails(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            border: Border.all(color: c.cardBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                entry.source == 'player'
                    ? Icons.play_circle_outline
                    : Icons.bug_report_outlined,
                color: entry.source == 'player' ? c.warning : c.danger,
                size: 21,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(context).copyWith(
                            color: c.text,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${entry.source} · ${_formatTimestamp(entry.timestamp)}',
                      style: AppText.meta(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: c.muted, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDetails(BuildContext context) {
    final c = appColors(context);
    final contextText = entry.context.isEmpty
        ? ''
        : const JsonEncoder.withIndent('  ').convert(entry.context);
    final details = [
      if (entry.stack.isNotEmpty) entry.stack,
      if (contextText.isNotEmpty) '上下文:\n$contextText',
    ].join('\n\n');
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(entry.source),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 460),
          child: SingleChildScrollView(
            child: SelectableText(
              details.isEmpty ? entry.message : details,
              style: AppText.mono(dialogContext, size: 12, color: c.text),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.cardBorder),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: c.muted, size: 30),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: AppText.body(context)),
          ],
        ),
      ),
    );
  }
}

String _formatTimestamp(DateTime timestamp) {
  final value = timestamp.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
}
