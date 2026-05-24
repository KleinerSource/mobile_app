import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/library.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';
import 'libraries_providers.dart';
import 'library_editor_page.dart';
import 'scan_progress_sheet.dart';
import 'scan_tasks_provider.dart';

/// 媒体库管理列表页
/// - 卡片列表 (名称 + 启用状态 + 文件数 + 目录数 + 多彩 hue)
/// - 顶右 + 添加按钮
/// - 卡片操作: 编辑 / 增量扫描 / more (全量 / 启用-停用 / 删除)
class LibrariesPage extends ConsumerWidget {
  const LibrariesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = appColors(context);
    final async = ref.watch(librariesAllProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: RefreshIndicator(
            color: c.accent,
            onRefresh: () => ref.refresh(librariesAllProvider.future),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LibraryEditorPage(),
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('添加',
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                          style: FilledButton.styleFrom(
                            backgroundColor: c.text,
                            foregroundColor: c.bg,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LIBRARIES', style: AppText.eyebrow(context)),
                        const SizedBox(height: 3),
                        Text('媒体库管理', style: AppText.pageTitle(context)),
                      ],
                    ),
                  ),
                ),
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
                        child: Text('加载失败: $e', style: AppText.body(context)),
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
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 80),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final hue =
                                AppHues.all[i % AppHues.all.length];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _LibraryCard(
                                library: libs[i],
                                hue: hue,
                              ),
                            );
                          },
                          childCount: libs.length,
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
    );
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
          Text('还没有媒体库',
              style: AppText.body(context).copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('点击右上 + 添加按钮创建第一个', style: AppText.meta(context)),
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
    final tracked = ref.watch(scanTasksProvider).where(
          (t) => t.libraryId == library.id,
        );
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(
            color: isScanning ? c.accent.withValues(alpha: 0.55) : c.cardBorder,
            width: isScanning ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
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
                    child: const Text('◆',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18)),
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
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: c.muted.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '已停用',
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
                        '${library.fileCount} 个文件 · ${library.directories.length} 个目录',
                        style: AppText.meta(context),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.more_horiz, color: c.muted),
                  onPressed: () => _showMore(context, ref, library),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: library.enabled
                        ? () => _triggerScan(context, ref, library, true)
                        : null,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text(
                      '增量扫描',
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.text,
                      side: BorderSide(color: c.cardBorder),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LibraryEditorPage(library: library),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text(
                      '编辑',
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.text,
                      side: BorderSide(color: c.cardBorder),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMore(
    BuildContext context,
    WidgetRef ref,
    LibraryItem lib,
  ) async {
    final c = appColors(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.bg,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.refresh, color: c.text),
                enabled: lib.enabled,
                title: const Text('全量扫描',
                    style: TextStyle(
                        fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                subtitle: const Text('重新扫描所有文件',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _triggerScan(context, ref, lib, false);
                },
              ),
              ListTile(
                leading: Icon(
                    lib.enabled ? Icons.toggle_off : Icons.toggle_on,
                    color: c.text),
                title: Text(
                  lib.enabled ? '停用媒体库' : '启用媒体库',
                  style: const TextStyle(
                      fontFamily: 'Inter', fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _toggleEnabled(context, ref, lib);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: c.danger),
                title: Text(
                  '删除媒体库',
                  style: TextStyle(
                      color: c.danger,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _confirmDelete(context, ref, lib);
                },
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
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
      ref.read(scanTasksProvider.notifier).register(
            libraryId: lib.id,
            libraryName: lib.name,
            taskId: taskId,
          );
      messenger.showSnackBar(SnackBar(
        content: Text('${incremental ? '增量' : '全量'}扫描已启动 · 进度见底部'),
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('扫描失败: ${toApiException(e).message}')),
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
      messenger.showSnackBar(SnackBar(
        content: Text(lib.enabled ? '已停用' : '已启用'),
        duration: const Duration(seconds: 1),
      ));
      // ignore: unused_result
      ref.refresh(librariesAllProvider);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('操作失败: ${toApiException(e).message}')),
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
        title: const Text('删除媒体库'),
        content: Text('删除「${lib.name}」?\n库内的影片元数据将一并移除 (硬盘上的文件不会被删除)。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(librariesRepositoryProvider).delete(lib.id);
      messenger.showSnackBar(const SnackBar(
        content: Text('媒体库已删除'),
        duration: Duration(seconds: 1),
      ));
      // ignore: unused_result
      ref.refresh(librariesAllProvider);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('删除失败: ${toApiException(e).message}')),
      );
    }
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
