import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/resource.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/util/map_with_concurrency.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glass.dart';
import '../../shared/sheet_controls.dart';
import '../../shared/debouncer.dart';
import '../../shared/pagination_footer.dart';
import '../movie_detail/entity_picker_sheet.dart';
import '../resources/resources_providers.dart';
import '../resources/resources_repository.dart';
import 'movies_providers.dart';

/// 批量编辑 sheet · 快速标记 / 加减 tag / 加减 genre / 设置/移除 series
class BatchEditSheet extends ConsumerStatefulWidget {
  const BatchEditSheet({super.key, required this.movieIds});
  final List<int> movieIds;

  static Future<bool?> show(BuildContext context, List<int> ids) {
    return showGlassSheet<bool>(
      context: context,
      isScrollControlled: true,
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

  // 选中影片共有的 tag/genre id (供 "移除" picker 限制范围)
  Set<int>? _commonTagIds;
  Set<int>? _commonGenreIds;
  bool _loadingCommon = true;

  @override
  void initState() {
    super.initState();
    _loadCommonAssociations();
  }

  Future<void> _loadCommonAssociations() async {
    try {
      final repo = ref.read(moviesRepositoryProvider);
      // 有界并发拉取详情,避免选中大量条目时瞬间打满服务端。
      final details = await mapWithConcurrency(
        widget.movieIds,
        (id) => repo.detail(id),
      );
      if (!mounted) return;

      Set<int>? commonTags;
      Set<int>? commonGenres;
      for (final d in details) {
        final t = d.tags.map((r) => r.id).toSet();
        final g = d.genres.map((r) => r.id).toSet();
        commonTags = commonTags == null ? t : commonTags.intersection(t);
        commonGenres = commonGenres == null ? g : commonGenres.intersection(g);
      }
      setState(() {
        _commonTagIds = commonTags ?? <int>{};
        _commonGenreIds = commonGenres ?? <int>{};
        _loadingCommon = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _commonTagIds = <int>{};
        _commonGenreIds = <int>{};
        _loadingCommon = false;
      });
    }
  }

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
    final result = await repo.options(kind, search: name);
    for (final r in result.items) {
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

      final hasAdd =
          addTags.isNotEmpty || addGenres.isNotEmpty || _setSeriesId != null;
      final hasRemove = _removeTagIds.isNotEmpty || _removeGenreIds.isNotEmpty;
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
          messenger.showSnackBar(
            SnackBar(
              content: Text('海报裁剪：成功 ${r.successCount}，失败 ${r.failedCount}'),
            ),
          );
        }
      }
      if (!mounted) return;
      AppHaptics.medium();
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeader(
          icon: Icons.edit_note_outlined,
          title: '批量编辑 ${widget.movieIds.length} 部',
          subtitle: '集中调整标签、分类、系列和快速标记',
        ),
        Flexible(
          fit: FlexFit.loose,
          child: ListView(
            shrinkWrap: true,
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
                          child: _QuickFlagChip(
                            label: '字幕',
                            value: _quickSubtitle,
                            onChanged: (v) => _onQuickSubtitle(v),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _QuickFlagChip(
                            label: '外挂字幕',
                            value: _quickExsub,
                            onChanged: (v) => _onQuickExsub(v),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _QuickFlagChip(
                            label: '破解',
                            value: _quickCrack,
                            onChanged: (v) =>
                                setState(() => _quickCrack = v ?? false),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _QuickFlagChip(
                            label: 'UHD',
                            value: _quickUHD,
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
                      label: '移除标签 (仅共有)',
                      kind: ResourceKind.tag,
                      selected: _removeTagIds,
                      restrictToIds: _commonTagIds ?? const <int>{},
                      restrictLoading: _loadingCommon,
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
                      label: '移除分类 (仅共有)',
                      kind: ResourceKind.genre,
                      selected: _removeGenreIds,
                      restrictToIds: _commonGenreIds ?? const <int>{},
                      restrictLoading: _loadingCommon,
                      onChanged: (s) => setState(() => _removeGenreIds = s),
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
        SheetActionBar(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).pop(false),
                  style: sheetSecondaryButtonStyle(context),
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
                  style: sheetPrimaryButtonStyle(context),
                  label: Text(_saving ? '保存中...' : '保存'),
                ),
              ),
            ],
          ),
        ),
      ],
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.cardTitle(context)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: AppText.meta(context)),
          ],
          const SizedBox(height: 12),
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
    this.restrictToIds,
    this.restrictLoading = false,
  });
  final String label;
  final ResourceKind kind;
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;
  final Set<int>? restrictToIds;
  final bool restrictLoading;

  @override
  ConsumerState<_PickerField> createState() => _PickerFieldState();
}

class _PickerFieldState extends ConsumerState<_PickerField> {
  final Map<int, String> _names = {};

  @override
  void initState() {
    super.initState();
    _loadSelectedNames();
  }

  @override
  void didUpdateWidget(covariant _PickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind ||
        oldWidget.selected != widget.selected) {
      _loadSelectedNames();
    }
  }

  Future<void> _loadSelectedNames() async {
    if (widget.selected.isEmpty) return;
    final repository = ref.read(resourcesRepositoryProvider);
    try {
      final items = await Future.wait(
        widget.selected.take(100).map((id) => repository.get(widget.kind, id)),
      );
      if (!mounted) return;
      setState(() {
        for (final item in items) {
          _names[item.id] = item.name;
        }
      });
    } catch (_) {
      // 选项查询失败不阻断批量编辑；已选 ID 仍可提交。
    }
  }

  Future<void> _open() async {
    final kind = switch (widget.kind) {
      ResourceKind.genre => EntityPickerKind.genre,
      ResourceKind.tag => EntityPickerKind.tag,
      ResourceKind.series => EntityPickerKind.series,
    };
    final result = await EntityPickerSheet.pickMulti(
      context: context,
      kind: kind,
      selected: widget.selected.toList(),
      selectedNames: _names,
      allowedIds: widget.restrictToIds,
    );
    if (result == null) return;
    _names.addAll(result.names);
    widget.onChanged(result.ids.toSet());
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final restrict = widget.restrictToIds;
    final restricted = restrict != null;
    final restrictEmpty = restricted && restrict.isEmpty;
    final disabled = widget.restrictLoading || restrictEmpty;
    final selectedItems = widget.selected
        .map((id) => ResourceItem(id: id, name: _names[id] ?? '#$id'))
        .toList();
    final placeholder = widget.restrictLoading
        ? '加载中...'
        : restrictEmpty
        ? '无共有${widget.kind.label}'
        : '选择${widget.kind.label}...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppText.meta(context)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: disabled ? null : _open,
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
                  child: selectedItems.isEmpty
                      ? Text(placeholder, style: TextStyle(color: c.muted))
                      : Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final item in selectedItems.take(3))
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: c.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  item.name,
                                  style: TextStyle(
                                    color: c.accent,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            if (selectedItems.length > 3)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: c.chipBg,
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(color: c.cardBorder),
                                ),
                                child: Text(
                                  '+${selectedItems.length - 3}',
                                  style: TextStyle(
                                    color: c.muted,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
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
  static const _pageSize = 100;

  bool _loading = true;
  List<ResourceItem> _all = const [];
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await ref
          .read(resourcesRepositoryProvider)
          .options(ResourceKind.series, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _all = result.items;
        _hasMore = result.hasMore;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _open() async {
    final c = appColors(context);
    var q = '';
    var items = List<ResourceItem>.of(_all);
    var hasMore = _hasMore;
    var loadingMore = false;
    var nextOffset = items.length;
    var searching = false;
    String? searchError;
    final debounce = Debouncer();
    var requestSerial = 0;
    var active = true;

    Future<void> searchSeries(String value, StateSetter setS) async {
      final serial = ++requestSerial;
      items = [];
      hasMore = false;
      nextOffset = 0;
      setS(() {
        searching = true;
        searchError = null;
      });
      try {
        final result = await ref
            .read(resourcesRepositoryProvider)
            .options(ResourceKind.series, search: value, limit: _pageSize);
        if (!active || serial != requestSerial) return;
        items = result.items;
        hasMore = result.hasMore;
        nextOffset = result.offset + result.items.length;
      } catch (_) {
        if (!active || serial != requestSerial) return;
        searchError = '搜索系列失败，请稍后重试';
      } finally {
        if (active && serial == requestSerial) {
          setS(() => searching = false);
        }
      }
    }

    Future<void> loadMoreSeries(StateSetter setS) async {
      if (loadingMore || !hasMore || searching) return;
      final serial = requestSerial;
      loadingMore = true;
      setS(() {});
      try {
        final result = await ref
            .read(resourcesRepositoryProvider)
            .options(
              ResourceKind.series,
              search: q.isEmpty ? null : q,
              offset: nextOffset,
              limit: _pageSize,
            );
        if (!active || serial != requestSerial) return;
        final ids = items.map((item) => item.id).toSet();
        final newItems = result.items
            .where((item) => ids.add(item.id))
            .toList();
        items = [...items, ...newItems];
        nextOffset = result.offset + result.items.length;
        hasMore = result.hasMore && newItems.isNotEmpty;
        searchError = null;
      } catch (_) {
        if (active && serial == requestSerial) {
          searchError = '加载更多系列失败，请稍后重试';
        }
      } finally {
        loadingMore = false;
        if (active) setS(() {});
      }
    }

    final picked = await showGlassSheet<({int? id, bool clear})>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SheetHeader(
                  icon: Icons.collections_bookmark_outlined,
                  title: '选择系列',
                  padding: EdgeInsets.fromLTRB(22, 0, 22, 10),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
                  child: TextField(
                    textAlignVertical: TextAlignVertical.center,
                    onChanged: (v) {
                      q = v.trim();
                      debounce.run(() {
                        searchSeries(q, setS);
                      });
                      setS(() {});
                    },
                    decoration: sheetInputDecoration(
                      ctx,
                      hintText: '搜索系列...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                    ),
                  ),
                ),
                if (searchError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        searchError!,
                        style: TextStyle(color: c.danger, fontSize: 12),
                      ),
                    ),
                  ),
                Flexible(
                  fit: FlexFit.loose,
                  child: searching
                      ? const Center(child: CircularProgressIndicator())
                      : items.isEmpty
                      ? Center(
                          child: Text(
                            q.isEmpty ? '暂无系列' : '未找到匹配的系列',
                            style: AppText.body(ctx),
                          ),
                        )
                      : NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification.metrics.extentAfter < 240 &&
                                searchError == null) {
                              loadMoreSeries(setS);
                            }
                            return false;
                          },
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: items.length + (hasMore ? 1 : 0),
                            itemBuilder: (ctx, i) {
                              if (i >= items.length) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Center(
                                    child: searchError != null && !loadingMore
                                        ? TextButton(
                                            onPressed: () {
                                              searchError = null;
                                              loadMoreSeries(setS);
                                            },
                                            child: const Text('加载更多失败，点击重试'),
                                          )
                                        : loadingMore
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                );
                              }
                              final r = items[i];
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
                                onTap: () => Navigator.of(
                                  ctx,
                                ).pop((id: r.id, clear: false)),
                              );
                            },
                          ),
                        ),
                ),
                if (!searching && !loadingMore && !hasMore && items.isNotEmpty)
                  const NoMoreContent(),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 10),
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(ctx).pop((id: null, clear: true)),
                      child: const Text('清空选择'),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    active = false;
    debounce.cancel();
    if (picked != null) {
      if (!picked.clear && picked.id != null) {
        ResourceItem? selectedItem;
        for (final item in items) {
          if (item.id == picked.id) {
            selectedItem = item;
            break;
          }
        }
        final item = selectedItem;
        if (item != null && mounted) {
          setState(() {
            _all = [item, ..._all.where((existing) => existing.id != item.id)];
          });
        }
      }
      widget.onChanged(picked.clear ? null : picked.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final name = _all
        .firstWhere(
          (r) => r.id == widget.selected,
          orElse: () => const ResourceItem(id: -1, name: ''),
        )
        .name;
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

class _QuickFlagChip extends StatelessWidget {
  const _QuickFlagChip({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: value ? c.accent.withValues(alpha: 0.15) : c.chipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value ? c.accent.withValues(alpha: 0.55) : c.cardBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              value ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 14,
              color: value ? c.accent : c.muted,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: value ? c.accent : c.text,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
