import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/movie.dart';
import '../../core/platform/app_theme.dart';
import 'movies_providers.dart';

/// 批量合并重复番号 sheet
class BatchMergeSheet extends ConsumerStatefulWidget {
  const BatchMergeSheet({super.key, required this.movieIds});
  final List<int> movieIds;

  static Future<bool?> show(BuildContext context, List<int> ids) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: appColors(context).bg,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BatchMergeSheet(movieIds: ids),
    );
  }

  @override
  ConsumerState<BatchMergeSheet> createState() => _BatchMergeSheetState();
}

class _BatchMergeSheetState extends ConsumerState<BatchMergeSheet> {
  bool _loading = true;
  String? _error;
  List<MovieDetail> _movies = const [];
  int? _targetId;
  bool _merging = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(moviesRepositoryProvider);
    try {
      final results = await Future.wait(
        widget.movieIds.map((id) => repo.detail(id)),
      );
      if (!mounted) return;
      setState(() {
        _movies = results;
        _loading = false;
        // 默认选第一个 (web 行为)
        _targetId = results.isNotEmpty ? results.first.id : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = toApiException(e).message;
        _loading = false;
      });
    }
  }

  bool get _allInSameFolder {
    if (_movies.length < 2) return false;
    final folder = _folderOf(_movies.first.filePath);
    if (folder.isEmpty) return false;
    return _movies.every((m) => _folderOf(m.filePath) == folder);
  }

  String _folderOf(String? path) {
    if (path == null || path.isEmpty) return '';
    final norm = path.replaceAll('\\', '/');
    final i = norm.lastIndexOf('/');
    return i <= 0 ? '' : norm.substring(0, i);
  }

  Future<void> _confirm() async {
    if (_targetId == null || _merging || _allInSameFolder) return;
    setState(() => _merging = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(moviesRepositoryProvider).mergeDuplicateFiles(
            movieIds: widget.movieIds,
            targetMovieId: _targetId!,
          );
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('已启动合并任务')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('合并失败: ${toApiException(e).message}'),
      ));
      setState(() => _merging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final mq = MediaQuery.of(context);
    return SizedBox(
      height: mq.size.height * 0.82,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('合并 ${widget.movieIds.length} 部重复影片',
                      style: AppText.sectionTitle(context)),
                  const SizedBox(height: 2),
                  Text('选择主导影片, 其他相关文件会移到该影片所在目录',
                      style: AppText.meta(context)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: Text(_error!,
                                style: TextStyle(color: c.danger)),
                          ),
                        )
                      : ListView(
                          padding:
                              const EdgeInsets.fromLTRB(22, 14, 22, 14),
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: c.warning.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: c.warning.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      color: c.warning, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '同名视频文件会被覆盖, 文件名冲突时非主导记录将被删除',
                                      style: TextStyle(
                                        color: c.warning,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_allInSameFolder) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: c.danger.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: c.danger.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  '所有选中影片已在同一目录, 无需合并',
                                  style: TextStyle(
                                      color: c.danger,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            for (final m in _movies)
                              _MovieOption(
                                movie: m,
                                selected: _targetId == m.id,
                                disabled: _allInSameFolder,
                                onTap: () => setState(() => _targetId = m.id),
                              ),
                            const SizedBox(height: 20),
                          ],
                        ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 10),
              decoration: BoxDecoration(
                color: c.bg,
                border: Border(top: BorderSide(color: c.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _merging
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: (_merging ||
                              _targetId == null ||
                              _allInSameFolder ||
                              _loading)
                          ? null
                          : _confirm,
                      icon: _merging
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.merge_rounded, size: 18),
                      label: Text(_merging ? '合并中...' : '确认合并'),
                      style: FilledButton.styleFrom(
                        backgroundColor: c.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovieOption extends StatelessWidget {
  const _MovieOption({
    required this.movie,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });
  final MovieDetail movie;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? c.accent.withValues(alpha: 0.15) : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected
                ? c.accent.withValues(alpha: 0.55)
                : c.cardBorder,
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? c.accent : c.muted,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title.isEmpty ? '未命名' : movie.title,
                    style: TextStyle(
                      color: c.text,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    movie.num ?? '无番号',
                    style: TextStyle(
                      color: c.muted,
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    movie.filePath ?? '路径不可用',
                    style: TextStyle(
                      color: c.muted,
                      fontFamily: 'monospace',
                      fontSize: 10.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
