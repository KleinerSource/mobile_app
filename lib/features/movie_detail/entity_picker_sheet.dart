import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/api/envelope.dart';
import '../../core/api/providers.dart';
import '../../core/models/paged_result.dart';
import '../../core/models/resource.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/pinyin_search.dart';
import '../../shared/pagination_footer.dart';
import '../../shared/debouncer.dart';
import '../../shared/taxonomy_search_policy.dart';
import '../resources/resources_providers.dart';
import '../resources/resources_repository.dart';

/// 资源选择器类型 · 比 ResourceKind 多个 actor
enum EntityPickerKind { genre, tag, series, actor }

extension on EntityPickerKind {
  String get label {
    switch (this) {
      case EntityPickerKind.genre:
        return '分类';
      case EntityPickerKind.tag:
        return '标签';
      case EntityPickerKind.series:
        return '系列';
      case EntityPickerKind.actor:
        return '演员';
    }
  }

  bool get multi => this != EntityPickerKind.series;
}

typedef EntityPickerSelection = ({List<int> ids, Map<int, String> names});

/// 实体选择 sheet · multi-select (series 单选)
///
/// 接收当前选中 ids,返回新的 ids 和名称 (multi / series)。
class EntityPickerSheet extends ConsumerStatefulWidget {
  const EntityPickerSheet({
    super.key,
    required this.kind,
    required this.initialSelectedIds,
    this.selectedNames = const {},
    this.allowMultiple = false,
    this.allowedIds,
  });

  final EntityPickerKind kind;

  /// 初始选中 · multi 用 list,series 用 [singleId] 形式
  final List<int> initialSelectedIds;

  /// 当前选中项的名称。远程查询只返回有限候选时，用于继续显示已选项。
  final Map<int, String> selectedNames;

  /// 某些筛选器需要对系列进行多选；影片编辑仍由 pickSingle 保持单选。
  final bool allowMultiple;

  /// 可选范围；高级筛选的“移除共有项”使用它限制结果。
  final Set<int>? allowedIds;

  /// 弹出多选 · 返回选中 ID 和名称 (取消则 null)
  static Future<EntityPickerSelection?> pickMulti({
    required BuildContext context,
    required EntityPickerKind kind,
    required List<int> selected,
    Map<int, String> selectedNames = const {},
    Set<int>? allowedIds,
  }) async {
    return showModalBottomSheet<EntityPickerSelection>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => EntityPickerSheet(
        kind: kind,
        initialSelectedIds: selected,
        selectedNames: selectedNames,
        allowMultiple: true,
        allowedIds: allowedIds,
      ),
    );
  }

  /// 弹出单选 (series 专用) · 返回选中 ID 和名称 (取消则 null)
  static Future<EntityPickerSelection?> pickSingle({
    required BuildContext context,
    required EntityPickerKind kind,
    required int? selected,
    Map<int, String> selectedNames = const {},
  }) async {
    assert(!kind.multi, 'multi 用 pickMulti');
    final result = await showModalBottomSheet<EntityPickerSelection>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => EntityPickerSheet(
        kind: kind,
        initialSelectedIds: selected != null ? [selected] : const [],
        selectedNames: selectedNames,
        allowMultiple: false,
      ),
    );
    return result;
  }

  @override
  ConsumerState<EntityPickerSheet> createState() => _EntityPickerSheetState();
}

class _EntityPickerSheetState extends ConsumerState<EntityPickerSheet> {
  final _searchCtrl = TextEditingController();
  final _debounce = Debouncer();
  String? _search;
  late final Set<int> _selected = widget.initialSelectedIds.toSet();
  final Map<int, String> _selectedNames = {};

  bool get _isMulti => widget.allowMultiple || widget.kind.multi;

  @override
  void initState() {
    super.initState();
    _selectedNames.addAll(widget.selectedNames);
  }

  @override
  void dispose() {
    _debounce.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce.run(() {
      if (mounted) {
        setState(() => _search = v.trim().isEmpty ? null : v.trim());
      }
    });
  }

  void _toggle(({int id, String name}) selection) {
    final id = selection.id;
    final name = selection.name;
    setState(() {
      if (_isMulti) {
        if (_selected.contains(id)) {
          _selected.remove(id);
          _selectedNames.remove(id);
        } else {
          _selected.add(id);
          _selectedNames[id] = name;
        }
      } else {
        // 单选: 替换
        _selected.clear();
        _selected.add(id);
        _selectedNames
          ..clear()
          ..[id] = name;
      }
    });
  }

  EntityPickerSelection _selection() {
    return (
      ids: _selected.toList(),
      names: {
        for (final id in _selected)
          if (_selectedNames[id]?.trim().isNotEmpty == true)
            id: _selectedNames[id]!.trim(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayBg = isDark
        ? const Color(0xFF1B1A24)
        : const Color(0xFFFAFAFA);

    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height * 0.85;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: overlayBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.muted2.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            // 头部
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '选择${widget.kind.label}',
                          style: AppText.sectionTitle(context),
                        ),
                        if (_isMulti) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${_selected.length} 已选',
                            style: AppText.meta(context),
                          ),
                        ],
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_selection()),
                    child: Text(
                      _isMulti ? '完成' : '使用',
                      style: TextStyle(
                        color: c.accent,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 搜索栏
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: c.chipBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(Icons.search, size: 18, color: c.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText:
                              widget.kind == EntityPickerKind.genre ||
                                  widget.kind == EntityPickerKind.tag
                              ? '搜索名称'
                              : widget.kind == EntityPickerKind.actor
                              ? '搜索名称 / 别名'
                              : '搜索名称',
                          border: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 列表
            Expanded(
              child: widget.kind == EntityPickerKind.actor
                  ? _ActorList(
                      search: _search,
                      selected: _selected,
                      selectedNames: widget.selectedNames,
                      onToggle: _toggle,
                    )
                  : _ResourceList(
                      kind: _resourceKindOf(widget.kind),
                      search: _search,
                      selected: _selected,
                      selectedNames: widget.selectedNames,
                      allowedIds: widget.allowedIds,
                      onToggle: _toggle,
                      singleSelect: !_isMulti,
                    ),
            ),
            // 底部清空按钮
            if (_selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
                child: TextButton(
                  onPressed: () => setState(() {
                    _selected.clear();
                    _selectedNames.clear();
                  }),
                  child: Text(
                    '清空',
                    style: TextStyle(
                      color: c.danger,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

ResourceKind _resourceKindOf(EntityPickerKind k) {
  switch (k) {
    case EntityPickerKind.genre:
      return ResourceKind.genre;
    case EntityPickerKind.tag:
      return ResourceKind.tag;
    case EntityPickerKind.series:
      return ResourceKind.series;
    case EntityPickerKind.actor:
      throw StateError('actor uses _ActorList');
  }
}

class _ResourceList extends ConsumerStatefulWidget {
  const _ResourceList({
    required this.kind,
    required this.search,
    required this.selected,
    required this.selectedNames,
    this.allowedIds,
    required this.onToggle,
    required this.singleSelect,
  });

  final ResourceKind kind;
  final String? search;
  final Set<int> selected;
  final Map<int, String> selectedNames;
  final Set<int>? allowedIds;
  final ValueChanged<({int id, String name})> onToggle;
  final bool singleSelect;

  @override
  ConsumerState<_ResourceList> createState() => _ResourceListState();
}

class _ResourceListState extends ConsumerState<_ResourceList> {
  final _scrollController = ScrollController();
  List<ResourceItem> _items = const [];
  List<ResourceItem> _localItems = const [];
  Map<int, PinyinSearchTokens> _pinyinIndex = {};
  final _knownNames = <int, String>{};
  bool _loading = false;
  Object? _error;
  int _requestSerial = 0;
  int _nextOffset = 0;
  bool _hasMore = false;
  bool? _localPinyinMode;

  bool get _supportsLocalPinyin =>
      widget.kind == ResourceKind.genre || widget.kind == ResourceKind.tag;

  @override
  void initState() {
    super.initState();
    _knownNames.addAll(widget.selectedNames);
    _scrollController.addListener(_onScroll);
    _loadPage(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ResourceList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _knownNames.addAll(widget.selectedNames);
    if (oldWidget.kind != widget.kind) {
      _localPinyinMode = null;
      _localItems = const [];
      _pinyinIndex = {};
      _loadPage(reset: true);
    } else if (oldWidget.search != widget.search && _localPinyinMode == true) {
      setState(() {});
    } else if (oldWidget.search != widget.search) {
      if (_supportsLocalPinyin &&
          (widget.search == null || widget.search!.isEmpty)) {
        _localPinyinMode = null;
        _localItems = const [];
        _pinyinIndex = {};
      }
      _loadPage(reset: true);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 240 ||
        _error != null) {
      return;
    }
    _loadPage(reset: false);
  }

  Future<void> _loadPage({required bool reset}) async {
    if (_localPinyinMode == true) {
      if (mounted) setState(() {});
      return;
    }
    if (!reset && (_loading || !_hasMore)) return;

    final requestSerial = reset ? ++_requestSerial : _requestSerial;
    final search = widget.search;
    final offset = reset ? 0 : _nextOffset;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items = const [];
        _nextOffset = 0;
        _hasMore = false;
      }
    });
    try {
      final repository = ref.read(resourcesRepositoryProvider);
      OptionsResult<ResourceItem>? probe;
      if (reset &&
          _localPinyinMode == null &&
          _supportsLocalPinyin &&
          (search == null || search.isEmpty)) {
        // 选项接口只读取 id/name，不触发资源管理页的影片计数聚合。
        probe = await repository.options(widget.kind, offset: 0);
        if (!mounted || requestSerial != _requestSerial) return;
        if (shouldUseLocalTaxonomySearch(
          hasMore: probe.hasMore,
          itemCount: probe.items.length,
        )) {
          _localPinyinMode = true;
          _localItems = probe.items;
          _pinyinIndex = {
            for (final item in _localItems)
              item.id: pinyinSearchTokens(item.name),
          };
          for (final item in _localItems) {
            _knownNames[item.id] = item.name;
          }
          setState(() {
            _loading = false;
            _hasMore = false;
          });
          return;
        }
        _localPinyinMode = false;
      } else {
        _localPinyinMode ??= false;
      }

      final result = probe != null && (search == null || search.isEmpty)
          ? probe
          : await repository.options(
              widget.kind,
              search: search,
              offset: offset,
            );
      if (!mounted || requestSerial != _requestSerial) return;
      for (final item in result.items) {
        _knownNames[item.id] = item.name;
      }
      final ids = _items.map((item) => item.id).toSet();
      final newItems = result.items.where((item) => ids.add(item.id)).toList();
      setState(() {
        _items = [..._items, ...newItems];
        _nextOffset = offset + result.items.length;
        _hasMore = result.hasMore && newItems.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || requestSerial != _requestSerial) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  List<ResourceItem> _visibleItems() {
    final source = _localPinyinMode == true
        ? _localItems.where(
            (item) => matchesPinyinSearch(
              item.name,
              widget.search ?? '',
              tokens: _pinyinIndex[item.id],
            ),
          )
        : _items;
    final byId = <int, ResourceItem>{
      for (final item in source)
        if (widget.allowedIds == null || widget.allowedIds!.contains(item.id))
          item.id: item,
    };
    for (final id in widget.selected) {
      if (widget.allowedIds != null && !widget.allowedIds!.contains(id)) {
        continue;
      }
      if (byId.containsKey(id)) continue;
      final name = _knownNames[id];
      if (name != null && name.isNotEmpty) {
        byId[id] = ResourceItem(id: id, name: name);
      }
    }
    if (!_supportsLocalPinyin) return byId.values.toList();
    return prioritizeSelectedWhenSearchEmpty(
      items: byId.values,
      searchIsEmpty: widget.search == null || widget.search!.trim().isEmpty,
      isSelected: (item) => widget.selected.contains(item.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _visibleItems().isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _visibleItems().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            '加载失败: ${toApiException(_error!).message}',
            style: AppText.meta(context),
          ),
        ),
      );
    }
    final items = _visibleItems();
    if (items.isEmpty && !_loading) {
      return Center(child: Text('没有匹配的资源', style: AppText.meta(context)));
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
            itemCount:
                items.length + (_localPinyinMode != true && _hasMore ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i >= items.length) {
                if (_error != null) {
                  return PaginationRetry(
                    onRetry: () => _loadPage(reset: false),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _loadPage(reset: false);
                });
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              final r = items[i];
              final isSel = widget.selected.contains(r.id);
              return _PickerTile(
                id: r.id,
                label: r.name,
                sub: r.movieCount > 0 ? '${r.movieCount} 部' : null,
                hue: AppHues.all[i % AppHues.all.length],
                selected: isSel,
                multiCheckbox: !widget.singleSelect,
                onTap: () => widget.onToggle((id: r.id, name: r.name)),
              );
            },
          ),
        ),
        if (!_loading && !_hasMore && items.isNotEmpty) const NoMoreContent(),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
      ],
    );
  }
}

class _ActorList extends ConsumerStatefulWidget {
  const _ActorList({
    required this.search,
    required this.selected,
    required this.selectedNames,
    required this.onToggle,
  });

  final String? search;
  final Set<int> selected;
  final Map<int, String> selectedNames;
  final ValueChanged<({int id, String name})> onToggle;

  @override
  ConsumerState<_ActorList> createState() => _ActorListState();
}

class _ActorListState extends ConsumerState<_ActorList> {
  static const _pageSize = 100;

  final _scrollController = ScrollController();
  List<ResourceItem> _items = const [];
  Object? _error;
  bool _loading = false;
  int _requestSerial = 0;
  int _nextOffset = 0;
  bool _hasMore = false;
  final _knownNames = <int, String>{};

  @override
  void initState() {
    super.initState();
    _knownNames.addAll(widget.selectedNames);
    _scrollController.addListener(_onScroll);
    _fetch(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ActorList old) {
    super.didUpdateWidget(old);
    _knownNames.addAll(widget.selectedNames);
    if (old.search != widget.search) _fetch(reset: true);
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 240 ||
        _error != null) {
      return;
    }
    _fetch(reset: false);
  }

  Future<void> _fetch({required bool reset}) async {
    if (!reset && (_loading || !_hasMore)) return;

    final requestSerial = reset ? ++_requestSerial : _requestSerial;
    final search = widget.search;
    final offset = reset ? 0 : _nextOffset;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items = const [];
        _nextOffset = 0;
        _hasMore = false;
      }
    });
    try {
      final api = ref.read(requiredApiClientProvider).actors;
      final q = <String, dynamic>{
        'limit': _pageSize,
        'offset': offset,
        if (search != null && search.isNotEmpty) 'search': search,
      };
      OptionsResult<ResourceItem> result;
      try {
        final raw = await api.options(q);
        result = unwrapOptions<ResourceItem>(raw, ResourceItem.fromJson);
      } catch (error) {
        final status = toApiException(error).status;
        // 老服务没有 /options 路由时，/options 可能会命中 /:id 并返回 400。
        if (status != 404 && status != 400) rethrow;
        final raw = await api.list({
          'limit': _pageSize,
          'offset': offset,
          'sort_by': 'movie_count',
          'sort_order': 'desc',
          if (search != null && search.isNotEmpty) 'search': search,
        });
        final page = unwrapTopLevelList<ResourceItem>(
          raw,
          ResourceItem.fromJson,
        );
        result = OptionsResult<ResourceItem>(
          items: page.items,
          hasMore: page.hasMore,
          limit: page.limit,
          offset: offset,
        );
      }
      if (!mounted || requestSerial != _requestSerial) return;
      for (final item in result.items) {
        _knownNames[item.id] = item.name;
      }
      final ids = _items.map((item) => item.id).toSet();
      final newItems = result.items.where((item) => ids.add(item.id)).toList();
      setState(() {
        _items = [..._items, ...newItems];
        _nextOffset = offset + result.items.length;
        _hasMore = result.hasMore && newItems.isNotEmpty;
      });
    } catch (e) {
      if (!mounted || requestSerial != _requestSerial) return;
      setState(() => _error = e);
    } finally {
      if (mounted && requestSerial == _requestSerial) {
        setState(() => _loading = false);
      }
    }
  }

  List<ResourceItem> _visibleItems() {
    final byId = <int, ResourceItem>{for (final item in _items) item.id: item};
    for (final id in widget.selected) {
      if (byId.containsKey(id)) continue;
      final name = _knownNames[id];
      if (name != null && name.isNotEmpty) {
        byId[id] = ResourceItem(id: id, name: name);
      }
    }
    return byId.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _visibleItems().isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _visibleItems().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            '加载失败: ${toApiException(_error!).message}',
            style: AppText.meta(context),
          ),
        ),
      );
    }
    final items = _visibleItems();
    if (items.isEmpty && !_loading) {
      return Center(child: Text('没有匹配的演员', style: AppText.meta(context)));
    }
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
            itemCount: items.length + (_hasMore ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i >= items.length) {
                if (_error != null) {
                  return PaginationRetry(onRetry: () => _fetch(reset: false));
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _fetch(reset: false);
                });
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              final r = items[i];
              final isSel = widget.selected.contains(r.id);
              return _PickerTile(
                id: r.id,
                label: r.name,
                sub: r.movieCount > 0 ? '${r.movieCount} 部' : null,
                hue: AppHues.all[i % AppHues.all.length],
                selected: isSel,
                multiCheckbox: true,
                onTap: () => widget.onToggle((id: r.id, name: r.name)),
              );
            },
          ),
        ),
        if (!_loading && !_hasMore && items.isNotEmpty) const NoMoreContent(),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
      ],
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.id,
    required this.label,
    required this.sub,
    required this.hue,
    required this.selected,
    required this.multiCheckbox,
    required this.onTap,
  });

  final int id;
  final String label;
  final String? sub;
  final int hue;
  final bool selected;
  final bool multiCheckbox;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppHues.top(hue), AppHues.bottom(hue)],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  label.isNotEmpty ? label.characters.first : '·',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.text,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (sub != null) ...[
                      const SizedBox(height: 2),
                      Text(sub!, style: AppText.meta(context)),
                    ],
                  ],
                ),
              ),
              // 复选或单选指示器
              if (multiCheckbox)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? c.accent : Colors.transparent,
                    border: Border.all(
                      color: selected ? c.accent : c.muted2,
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                )
              else
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? c.accent : c.muted2,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
