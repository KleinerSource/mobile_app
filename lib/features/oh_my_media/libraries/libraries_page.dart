import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/models/library.dart';
import 'package:omm/core/platform/app_action_sheet.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/shared/swipe_actions.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/features/oh_my_media/tasks/task_model.dart';
import 'libraries_providers.dart';
import 'library_editor_page.dart';
import 'scan_progress_sheet.dart';
import 'scan_tasks_provider.dart';

/// 媒体库管理列表页
/// - 分组列表 (名称 + 启用状态 + 文件数 + 目录数 + 多彩 hue)
/// - 顶右批量扫描菜单 + 添加按钮
/// - 单库操作左滑展开: 扫描 (增量/全量) / 停用-启用 / 删除；点行进入编辑
class LibrariesPage extends ConsumerStatefulWidget {
  const LibrariesPage({super.key});

  @override
  ConsumerState<LibrariesPage> createState() => _LibrariesPageState();
}

enum _BatchScanAction { incremental, full }

class _LibrariesPageState extends ConsumerState<LibrariesPage> {
  bool _batchScanStarting = false;
  final SwipeActionGroup _openSwipe = SwipeActionGroup(null);

  @override
  void dispose() {
    _openSwipe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final async = ref.watch(librariesAllProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            header: SettingsSubPageHeader(
              eyebrow: l.settingsGroupLibrary,
              title: l.libraryManageTitle,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: _batchScanStarting
                        ? null
                        : _showBatchScanActions,
                    icon: _batchScanStarting
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.text,
                            ),
                          )
                        : const Icon(Icons.sync_rounded, size: 18),
                    label: Text(
                      _batchScanStarting ? l.librarySubmitting : l.libraryScan,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.text,
                      side: BorderSide(color: c.cardBorder),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SettingsAddButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LibraryEditorPage(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            body: RefreshIndicator(
              color: c.accent,
              onRefresh: () => ref.refresh(librariesAllProvider.future),
              child: NotificationListener<ScrollUpdateNotification>(
                // 滚动时收起已展开的左滑操作
                onNotification: (_) {
                  if (_openSwipe.value != null) _openSwipe.value = null;
                  return false;
                },
                child: CustomScrollView(
                  primary: true,
                  slivers: [
                    async.when(
                      loading: () => const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              '${AppL10n.of(context).loadFailed}: $e',
                              style: AppText.body(context),
                            ),
                          ),
                        ),
                      ),
                      data: (libs) {
                        if (libs.isEmpty) {
                          return SliverFillRemaining(
                            hasScrollBody: false,
                            child: _Empty(),
                          );
                        }
                        // 媒体库数量少且有界：合并为设置页式分组卡，行间细分隔线。
                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(22, 0, 22, 80),
                          sliver: SliverToBoxAdapter(
                            child: Container(
                              decoration: settingsCardDecoration(context),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Column(
                                  children: [
                                    for (var i = 0; i < libs.length; i++) ...[
                                      if (i > 0)
                                        Divider(height: 1, color: c.divider),
                                      SwipeActionCell(
                                        group: _openSwipe,
                                        cellKey: libs[i].id,
                                        actions: _librarySwipeActions(libs[i]),
                                        enabled: true,
                                        child: _LibraryCard(
                                          library: libs[i],
                                          hue: AppHues
                                              .all[i % AppHues.all.length],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 单个媒体库的左滑操作：停用的库不提供扫描入口。
  List<SwipeActionData> _librarySwipeActions(LibraryItem lib) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    return [
      if (lib.enabled)
        SwipeActionData(
          icon: Icons.refresh,
          label: l.libraryScan,
          color: AppHues.top(AppHues.mint),
          onPressed: () => _showScanActions(lib),
        ),
      SwipeActionData(
        icon: lib.enabled
            ? Icons.toggle_off_outlined
            : Icons.toggle_on_outlined,
        label: lib.enabled ? l.libraryDisable : l.libraryEnable,
        color: c.warning,
        onPressed: () => _toggleEnabled(context, ref, lib),
      ),
      SwipeActionData(
        icon: Icons.delete_outline_rounded,
        label: l.delete,
        color: c.danger,
        onPressed: () => _confirmDelete(context, ref, lib),
      ),
    ];
  }

  /// 左滑「扫描」后的方式选择：增量 / 全量。
  Future<void> _showScanActions(LibraryItem lib) async {
    final l = AppL10n.of(context);
    final incremental = await showAppActionSheet<bool>(
      context: context,
      title: l.libraryScanSheetTitle(lib.name),
      actions: [
        AppActionSheetAction(label: l.libraryScanIncremental, value: true),
        AppActionSheetAction(label: l.libraryScanFull, value: false),
      ],
    );
    if (!mounted || incremental == null) return;
    await _triggerScan(context, ref, lib, incremental);
  }

  Future<void> _triggerScan(
    BuildContext context,
    WidgetRef ref,
    LibraryItem lib,
    bool incremental,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final taskId = await ref
          .read(librariesRepositoryProvider)
          .scan(lib.id, incremental: incremental);
      if (!context.mounted) return;
      // 注册到常驻 dock, 不再弹模态 sheet
      ref
          .read(scanTasksProvider.notifier)
          .register(libraryId: lib.id, libraryName: lib.name, taskId: taskId);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            incremental
                ? AppL10n.of(context).libraryScanIncrementalStarted
                : AppL10n.of(context).libraryScanFullStarted,
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppL10n.of(
              context,
            ).libraryScanFailed(toApiException(e).message),
          ),
        ),
      );
    }
  }

  Future<void> _toggleEnabled(
    BuildContext context,
    WidgetRef ref,
    LibraryItem lib,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(librariesRepositoryProvider)
          .update(lib.id, enabled: !lib.enabled);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            lib.enabled
                ? AppL10n.of(context).libraryDisabledToast
                : AppL10n.of(context).libraryEnabledToast,
          ),
          duration: const Duration(seconds: 1),
        ),
      );
      // ignore: unused_result
      ref.refresh(librariesAllProvider);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppL10n.of(context).operationFailed(toApiException(e).message),
          ),
        ),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    LibraryItem lib,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppL10n.of(ctx).libraryDeleteTitle),
        content: Text(AppL10n.of(ctx).libraryDeleteConfirm(lib.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppL10n.of(ctx).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppL10n.of(ctx).delete),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(librariesRepositoryProvider).delete(lib.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppL10n.of(context).libraryDeletedToast),
          duration: const Duration(seconds: 1),
        ),
      );
      // ignore: unused_result
      ref.refresh(librariesAllProvider);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppL10n.of(
              context,
            ).libraryDeleteFailed(toApiException(e).message),
          ),
        ),
      );
    }
  }

  Future<void> _showBatchScanActions() async {
    final l = AppL10n.of(context);
    final action = await showAppActionSheet<_BatchScanAction>(
      context: context,
      title: l.libraryBatchScanTitle,
      actions: [
        AppActionSheetAction(
          label: l.libraryBatchScanIncremental,
          value: _BatchScanAction.incremental,
        ),
        AppActionSheetAction(
          label: l.libraryBatchScanFull,
          value: _BatchScanAction.full,
        ),
      ],
    );
    if (!mounted || action == null) return;
    await _triggerBatchScan(action == _BatchScanAction.incremental);
  }

  Future<void> _triggerBatchScan(bool incremental) async {
    if (_batchScanStarting) return;
    setState(() => _batchScanStarting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref
          .read(librariesRepositoryProvider)
          .batchScan(incremental: incremental);
      if (!mounted) return;

      final taskNotifier = ref.read(scanTasksProvider.notifier);
      for (final task in result.tasks) {
        final queueMessage = task.queuePosition > 0
            ? '$kTaskMsgScanQueuedAtPrefix${task.queuePosition}'
            : kTaskMsgScanQueued;
        taskNotifier.register(
          libraryId: task.libraryId,
          libraryName: task.libraryName,
          taskId: task.taskId,
          task: ScanTask(
            taskId: task.taskId,
            libraryId: task.libraryId,
            status: task.status,
            incremental: incremental,
            currentFile:
                task.status == 'queued' ? queueMessage : kTaskMsgScanPreparing,
          ),
        );
      }

      final l = AppL10n.of(context);
      String message;
      if (result.acceptedCount == 0) {
        if (result.enabledCount == 0) {
          message = result.message.isNotEmpty
              ? result.message
              : l.libraryBatchNoEnabled;
        } else {
          message = result.message.isNotEmpty
              ? result.message
              : l.libraryBatchNoTasks(result.scanType);
          if (result.failedCount > 0) {
            message += '，${l.libraryBatchSubmitFailedCount(result.failedCount)}';
          }
        }
      } else {
        message = l.libraryBatchAccepted(result.acceptedCount, result.scanType);
        if (result.reusedCount > 0) {
          message += ' · ${l.libraryBatchReused(result.reusedCount)}';
        }
        if (result.failedCount > 0) {
          message += ' · ${l.libraryBatchFailedShort(result.failedCount)}';
        }
      }
      if (result.skippedDisabledCount > 0) {
        message += ' · ${l.libraryBatchSkippedDisabled(result.skippedDisabledCount)}';
      }
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              AppL10n.of(
                context,
              ).libraryBatchScanFailed(toApiException(e).message),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _batchScanStarting = false);
    }
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_outlined, size: 40, color: c.muted),
          const SizedBox(height: 14),
          Text(
            AppL10n.of(context).libraryEmptyTitle,
            style: AppText.body(context).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            AppL10n.of(context).libraryEmptyHint,
            style: AppText.meta(context),
          ),
        ],
      ),
    );
  }
}

class _LibraryCard extends ConsumerWidget {
  const _LibraryCard({required this.library, required this.hue});

  final LibraryItem library;
  final int hue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = appColors(context);
    // 当前库是否在扫描中
    final tracked = ref
        .watch(scanTasksProvider)
        .where((t) => t.libraryId == library.id);
    final scan = tracked.isEmpty ? null : tracked.first;
    final isScanning = scan != null;

    return InkWell(
      onTap: isScanning
          ? () => ScanProgressSheet.show(
              context,
              libraryId: library.id,
              libraryName: library.name,
              taskId: scan.taskId,
            )
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LibraryEditorPage(library: library),
              ),
            ),
      child: Container(
        padding: const EdgeInsets.all(16),
        // 分组连排行：透明背景，由外层分组容器提供表面；
        // 扫描中的库以浅强调底色提示。
        color: isScanning ? c.accent.withValues(alpha: 0.06) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 扫描中显示圆形进度 / 否则 hue 图标
                if (isScanning)
                  _ScanProgressIcon(scan: scan)
                else
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppHues.top(hue), AppHues.bottom(hue)],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '◆',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              library.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: library.enabled ? c.text : c.muted,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          if (!library.enabled) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: c.muted.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                AppL10n.of(context).libraryDisabledBadge,
                                style: TextStyle(
                                  color: c.muted,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 9.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppL10n.of(context).libraryCardMeta(
                          library.fileCount,
                          library.directories.length,
                        ),
                        style: AppText.meta(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 扫描中的库卡片左侧图标 · 圆形进度 + 百分比
class _ScanProgressIcon extends StatelessWidget {
  const _ScanProgressIcon({required this.scan});
  final TrackedScan scan;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final t = scan.task;
    final ratio = (t?.progressRatio ?? 0).clamp(0.0, 1.0).toDouble();
    final total = t?.totalFiles ?? 0;
    final percent = total > 0 ? (ratio * 100).round() : null;
    final indeterminate = total <= 0;

    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              value: indeterminate ? null : ratio,
              strokeWidth: 3,
              backgroundColor: c.chipBg,
              valueColor: AlwaysStoppedAnimation(c.accent),
            ),
          ),
          if (indeterminate)
            Icon(Icons.sync_rounded, size: 16, color: c.accent)
          else
            Text(
              '$percent%',
              style: TextStyle(
                color: c.accent,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: -0.2,
                height: 1,
              ),
            ),
        ],
      ),
    );
  }
}
