import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/resource.dart';
import '../../core/platform/app_theme.dart';
import '../resources/resources_providers.dart';
import '../resources/resources_repository.dart';
import 'movies_providers.dart';

/// 批量编辑 sheet · 快速标记 / 加减 tag / 加减 genre / 设置/移除 series
class BatchEditSheet extends ConsumerStatefulWidget {
  const BatchEditSheet({super.key, required this.movieIds});
  final List<int> movieIds;

  static Future<bool?> show(BuildContext context, List<int> ids) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: appColors(context).bg,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BatchEditSheet(movieIds: ids),
    );
  }

  @override
  ConsumerState<BatchEditSheet> createState() => _BatchEditSheetState();
}

class _BatchEditSheetState extends ConsumerState<BatchEditSheet> {
  bool _quickSubtitle = false;
  bool _quickExsub = false;
  bool _quickCrack = false;
  bool _quickUHD = false;

  Set<int> _addTagIds = {};
  Set<int> _removeTagIds = {};
  Set<int> _addGenreIds = {};
  Set<int> _removeGenreIds = {};
  int? _setSeriesId;
  bool _saving = false;

  void _onQuickSubtitle(bool? v) {
    setState(() {
      _quickSubtitle = v ?? false;
      if (_quickSubtitle) _quickExsub = false;
    });
  }

  void _onQuickExsub(bool? v) {
    setState(() {
      _quickExsub = v ?? false;
      if (_quickExsub) _quickSubtitle = false;
    });
  }

  /// 名称解析 → 现有 id 或创建新条目
  Future<int?> _ensureResourceId(ResourceKind kind, String name) async {
    final repo = ref.read(resourcesRepositoryProvider);
    final lower = name.trim().toLowerCase();
    if (lower.isEmpty) return null;
    final page = await repo.list(kind, limit: 500);
    for (final r in page.items) {
      if (r.name.trim().toLowerCase() == lower) return r.id;
    }
    final created = await repo.create(kind, name: name);
    return created.id;
  }

  Future<void> _onSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    final repo = ref.read(moviesRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final addTags = Set<int>.of(_addTagIds);
      final addGenres = Set<int>.of(_addGenreIds);

      Future<void> applyQuick(String canonical) async {
        final tid = await _ensureResourceId(ResourceKind.tag, canonical);
        final gid = await _ensureResourceId(ResourceKind.genre, canonical);
        if (tid != null) addTags.add(tid);
        if (gid != null) addGenres.add(gid);
      }

      if (_quickSubtitle || _quickExsub) await applyQuick('中文字幕');
      if (_quickCrack) await applyQuick('无码破解');
      if (_quickUHD) await applyQuick('UHD');

      final hasAdd = addTags.isNotEmpty ||
          addGenres.isNotEmpty ||
          _setSeriesId != null;
      final hasRemove = _removeTagIds.isNotEmpty ||
          _removeGenreIds.isNotEmpty;
      final hasWatermark =
          _quickSubtitle || _quickExsub || _quickCrack || _quickUHD;

      if (!hasAdd && !hasRemove && !hasWatermark) {
        messenger.showSnackBar(
          const SnackBar(content: Text('请至少选择一项要添加、移除或裁剪的内容')),
        );
        setState(() => _saving = false);
        return;
      }

      if (hasAdd) {
        await repo.batchAddAssociations(
          movieIds: widget.movieIds,
          tagIds: addTags.toList(),
          genreIds: addGenres.toList(),
          seriesId: _setSeriesId,
        );
      }
      if (hasRemove) {
        await repo.batchRemoveAssociations(
          movieIds: widget.movieIds,
          tagIds: _removeTagIds.toList(),
          genreIds: _removeGenreIds.toList(),
        );
      }
      if (hasWatermark) {
        final r = await repo.batchWatermark(
          movieIds: widget.movieIds,
          subtitle: _quickSubtitle,
          exsub: _quickExsub,
          crack: _quickCrack,
          uhd: _quickUHD,
        );
        if (r.failedCount > 0) {
          messenger.showSnackBar(SnackBar(
            content:
                Text('海报裁剪：成功 ${r.successCount}，失败 ${r.failedCount}'),
          ));
        }
      }
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('批量编辑成功')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('批量编辑失败: ${toApiException(e).message}')),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final mq = MediaQuery.of(context);
    return SizedBox(
      height: mq.size.height * 0.9,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('批量编辑 ${widget.movieIds.length} 部',
                            style: AppText.sectionTitle(context)),
                        const SizedBox(height: 2),
                        Text('集中调整标签、分类、系列和快速标记',
                            style: AppText.meta(context)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
                children: [
                  _Card(
                    title: '快速标记',
                    subtitle: '保存时会同步裁剪海报水印',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: CheckboxListTile(
                                value: _quickSubtitle,
                                dense: true,
                                title: const Text('字幕'),
                                onChanged: _onQuickSubtitle,
                              ),
                            ),
                            Expanded(
                              child: CheckboxListTile(
                                value: _quickExsub,
                                dense: true,
                                title: const Text('外挂字幕'),
                                onChanged: _onQuickExsub,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: CheckboxListTile(
                                value: _quickCrack,
                                dense: true,
                                title: const Text('破解'),
                                onChanged: (v) =>
                                    setState(() => _quickCrack = v ?? false),
                              ),
                            ),
                            Expanded(
                              child: CheckboxListTile(
                                value: _quickUHD,
                                dense: true,
                                title: const Text('UHD'),
                                onChanged: (v) =>
                                    setState(() => _quickUHD = v ?? false),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '字幕与外挂字幕互斥',
                            style: TextStyle(
                              color: c.muted,
                              fontFamily: 'Inter',
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    title: '标签',
                    subtitle: '分别指定要追加和移除的标签集合',
                    child: Column(
                      children: [
                        _PickerField(
                          label: '添加标签',
                          kind: ResourceKind.tag,
                          selected: _addTagIds,
                          onChanged: (s) => setState(() => _addTagIds = s),
                        ),
                        const SizedBox(height: 8),
                        _PickerField(
                          label: '移除标签',
                          kind: ResourceKind.tag,
                          selected: _removeTagIds,
                          onChanged: (s) => setState(() => _removeTagIds = s),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    title: '分类',
                    child: Column(
                      children: [
                        _PickerField(
                          label: '添加分类',
                          kind: ResourceKind.genre,
                          selected: _addGenreIds,
                          onChanged: (s) => setState(() => _addGenreIds = s),
                        ),
                        const SizedBox(height: 8),
                        _PickerField(
                          label: '移除分类',
                          kind: ResourceKind.genre,
                          selected: _removeGenreIds,
                          onChanged: (s) =>
                              setState(() => _removeGenreIds = s),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    title: '系列',
                    subtitle: '可统一设置系列',
                    child: _SingleSeriesPicker(
                      selected: _setSeriesId,
                      onChanged: (id) => setState(() => _setSeriesId = id),
                    ),
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
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _onSave,
                      icon: _saving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: Text(_saving ? '保存中...' : '保存'),
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

class _Card extends StatelessWidget {
  const _Card({required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                color: c.text,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 14,
              )),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: AppText.meta(context)),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _PickerField extends ConsumerStatefulWidget {
  const _PickerField({
    required this.label,
    required this.kind,
    required this.selected,
    required this.onChanged,
  });
  final String label;
  final ResourceKind kind;
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  ConsumerState<_PickerField> createState() => _PickerFieldState();
}

class _PickerFieldState extends ConsumerState<_PickerField> {
  bool _loading = true;
  List<ResourceItem> _all = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final page = await ref
          .read(resourcesRepositoryProvider)
          .list(widget.kind, limit: 500);
      if (!mounted) return;
      setState(() {
        _all = page.items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _open() async {
    final c = appColors(context);
    final mq = MediaQuery.of(context);
    var q = '';
    final picked = await showModalBottomSheet<Set<int>>(
      context: context,
      backgroundColor: c.bg,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final selected = Set.of(widget.selected);
        return StatefulBuilder(builder: (ctx, setS) {
          final filtered = q.isEmpty
              ? _all
              : _all
                  .where((r) => r.name.toLowerCase().contains(q.toLowerCase()))
                  .toList();
          return SizedBox(
            height: mq.size.height * 0.75,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
                  child: Text('选择${widget.kind.label}',
                      style: AppText.sectionTitle(ctx)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
                  child: TextField(
                    onChanged: (v) => setS(() => q = v.trim()),
                    decoration: InputDecoration(
                      hintText: '搜索${widget.kind.label}...',
                      prefixIcon:
                          Icon(Icons.search, size: 18, color: c.muted),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final r = filtered[i];
                      return CheckboxListTile(
                        dense: true,
                        value: selected.contains(r.id),
                        title: Text(r.name),
                        onChanged: (v) {
                          setS(() {
                            if (v == true) {
                              selected.add(r.id);
                            } else {
                              selected.remove(r.id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setS(() => selected.clear()),
                            child: const Text('清空'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(selected),
                            child: const Text('确定'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
    if (picked != null) widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final selectedItems =
        _all.where((r) => widget.selected.contains(r.id)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppText.meta(context)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _loading ? null : _open,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: c.chipBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.cardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: selectedItems.isEmpty
                      ? Text(_loading ? '加载中...' : '选择${widget.kind.label}...',
                          style: TextStyle(color: c.muted))
                      : Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final r in selectedItems.take(3))
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: c.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(r.name,
                                    style: TextStyle(
                                      color: c.accent,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    )),
                              ),
                            if (selectedItems.length > 3)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: c.chipBg,
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(color: c.cardBorder),
                                ),
                                child: Text('+${selectedItems.length - 3}',
                                    style: TextStyle(
                                      color: c.muted,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    )),
                              ),
                          ],
                        ),
                ),
                Icon(Icons.expand_more, color: c.muted, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SingleSeriesPicker extends ConsumerStatefulWidget {
  const _SingleSeriesPicker({required this.selected, required this.onChanged});
  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  ConsumerState<_SingleSeriesPicker> createState() =>
      _SingleSeriesPickerState();
}

class _SingleSeriesPickerState extends ConsumerState<_SingleSeriesPicker> {
  bool _loading = true;
  List<ResourceItem> _all = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final page = await ref
          .read(resourcesRepositoryProvider)
          .list(ResourceKind.series, limit: 500);
      if (!mounted) return;
      setState(() {
        _all = page.items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _open() async {
    final c = appColors(context);
    final mq = MediaQuery.of(context);
    var q = '';
    final picked = await showModalBottomSheet<({int? id, bool clear})>(
      context: context,
      backgroundColor: c.bg,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setS) {
          final filtered = q.isEmpty
              ? _all
              : _all
                  .where((r) => r.name.toLowerCase().contains(q.toLowerCase()))
                  .toList();
          return SizedBox(
            height: mq.size.height * 0.75,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
                  child: Text('选择系列', style: AppText.sectionTitle(ctx)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
                  child: TextField(
                    onChanged: (v) => setS(() => q = v.trim()),
                    decoration: InputDecoration(
                      hintText: '搜索系列...',
                      prefixIcon:
                          Icon(Icons.search, size: 18, color: c.muted),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final r = filtered[i];
                      final isSel = widget.selected == r.id;
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          isSel
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color: isSel ? c.accent : c.muted,
                        ),
                        title: Text(r.name),
                        onTap: () =>
                            Navigator.of(ctx).pop((id: r.id, clear: false)),
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 10),
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx)
                          .pop((id: null, clear: true)),
                      child: const Text('清空选择'),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
    if (picked != null) {
      widget.onChanged(picked.clear ? null : picked.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final name =
        _all.firstWhere((r) => r.id == widget.selected, orElse: () => const ResourceItem(id: -1, name: '')).name;
    return GestureDetector(
      onTap: _loading ? null : _open,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.chipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.cardBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.selected == null
                    ? (_loading ? '加载中...' : '选择系列...')
                    : name,
                style: TextStyle(
                  color: widget.selected == null ? c.muted : c.text,
                ),
              ),
            ),
            Icon(Icons.expand_more, color: c.muted, size: 18),
          ],
        ),
      ),
    );
  }
}
