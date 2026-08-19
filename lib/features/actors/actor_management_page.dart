import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../core/api/dio_factory.dart';
import '../../core/api/envelope.dart';
import '../../core/api/providers.dart';
import '../../core/models/actor.dart';
import '../../core/models/mapping_rule.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/drag_selection.dart';
import '../../shared/entity_batch_toolbar.dart';
import '../../shared/glow_background.dart';
import '../../shared/actor_avatar.dart';
import '../../shared/error_view.dart';
import '../../shared/filter_chip.dart';
import '../../shared/pagination_footer.dart';
import '../../shared/paged_scroll_position_restorer.dart';
import '../actor_associations/actor_associations_providers.dart';
import '../actor_associations/actor_associations_repository.dart';
import '../person_detail/person_detail_page.dart';
import '../privacy/privacy_mask.dart';
import '../settings/settings_common.dart';
import 'actor_row.dart';

/// 演员管理 · 演员信息 CRUD、搜索、排序和作品查看。
class ActorManagementPage extends ConsumerStatefulWidget {
  const ActorManagementPage({super.key});

  @override
  ConsumerState<ActorManagementPage> createState() =>
      _ActorManagementPageState();
}

class _ActorManagementPageState extends ConsumerState<ActorManagementPage> {
  static const _pageSize = 100;

  final _searchController = TextEditingController();
  final _controller = PagingController<int, ActorRow>(firstPageKey: 0);
  final _scrollController = ScrollController();
  late final _scrollRestorer = PagedScrollPositionRestorer<ActorRow>(
    _controller,
  );
  Timer? _searchDebounce;
  String? _search;
  String _sortBy = 'movie_count';
  String _sortOrder = 'desc';
  // 折叠关联演员：已展开的主行 id，各行的展开状态相互独立。
  final Set<int> _expandedIds = <int>{};
  int _totalCount = 0;
  bool _hasLoaded = false;
  int _requestSerial = 0;
  bool _selectionMode = false;
  final Set<int> _selectedIds = <int>{};
  Completer<void>? _refreshCompleter;

  @override
  void initState() {
    super.initState();
    _controller.addPageRequestListener(_fetch);
  }

  @override
  void dispose() {
    _completeRefresh();
    _searchDebounce?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetch(int offset) async {
    final requestSerial = _requestSerial;
    final query = <String, dynamic>{
      'limit': _pageSize,
      'offset': offset,
      'sort_by': _sortBy,
      'sort_order': _sortOrder,
      // 折叠关联演员：列表只保留关联组的标准演员行，成员折叠为子行。
      'collapse_associations': true,
      if (_search != null) 'search': _search,
    };

    try {
      final raw = await ref.read(requiredApiClientProvider).actors.list(query);
      final page = unwrapTopLevelList<ActorItem>(raw, ActorItem.fromJson);
      if (!mounted || requestSerial != _requestSerial) return;

      final rows = ActorRow.parseRows(raw, page.items);
      setState(() {
        _totalCount = page.totalCount;
        _hasLoaded = true;
      });
      final nextOffset = offset + page.items.length;
      if (nextOffset >= page.totalCount || page.items.isEmpty) {
        _controller.appendLastPage(rows);
      } else {
        _controller.appendPage(rows, nextOffset);
      }
      _scrollRestorer.restoreAfterPage(_scrollController);
      _completeRefresh();
    } catch (error) {
      if (!mounted || requestSerial != _requestSerial) return;
      _controller.error = toApiException(error).message;
      _completeRefresh();
    }
  }

  void _reload({bool preserveScroll = false}) {
    _requestSerial++;
    _scrollRestorer.prepare(_scrollController, preserve: preserveScroll);
    if (mounted) {
      setState(() {
        _hasLoaded = false;
        _totalCount = 0;
      });
    }
    _controller.refresh();
  }

  Future<void> _refresh({bool preserveScroll = false}) {
    final pending = _refreshCompleter;
    if (pending != null) return pending.future;

    final completer = Completer<void>();
    _refreshCompleter = completer;
    _reload(preserveScroll: preserveScroll);
    return completer.future;
  }

  void _completeRefresh() {
    final completer = _refreshCompleter;
    _refreshCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      setState(() {
        _search = value.trim().isEmpty ? null : value.trim();
      });
      _reload();
    });
  }

  void _setSort(String field) {
    setState(() {
      if (_sortBy == field) {
        _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc';
      } else {
        _sortBy = field;
        _sortOrder = field == 'movie_count' ? 'desc' : 'asc';
      }
    });
    _reload();
    AppHaptics.selection();
  }

  void _startSelectionSweep(int id, bool selected) {
    setState(() {
      _selectionMode = true;
      _setSelectionValue(id, selected);
    });
  }

  void _applySelectionSweep(int id, bool selected) {
    if (_selectedIds.contains(id) == selected) return;
    setState(() => _setSelectionValue(id, selected));
  }

  void _finishSelectionSweep() {
    if (_selectionMode && _selectedIds.isEmpty) _exitSelection();
  }

  void _setSelectionValue(int id, bool selected) {
    if (selected) {
      _selectedIds.add(id);
    } else {
      _selectedIds.remove(id);
    }
  }

  void _toggleSelect(int id) {
    setState(() {
      if (_selectedIds.remove(id)) {
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAllLoaded() {
    final loaded = _controller.itemList ?? const <ActorRow>[];
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(loaded.map((row) => row.id));
    });
  }

  List<ActorItem> _selectedActors() {
    final loaded = _controller.itemList ?? const <ActorRow>[];
    return loaded
        .where((row) => _selectedIds.contains(row.id))
        .map((row) => row.actor)
        .toList();
  }

  Future<void> _onBatchDelete() async {
    final actors = _selectedActors();
    if (actors.isEmpty) return;
    final force = actors.any((actor) => actor.movieCount > 0);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量删除演员'),
        content: Text(
          force
              ? '已选择 ${actors.length} 位演员，其中包含影片关联。强制删除会解除关联，影片本身不会被删除。'
              : '确定删除已选择的 ${actors.length} 位演员吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(force ? '强制删除' : '删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final raw = await ref
          .read(requiredApiClientProvider)
          .catalog
          .deleteActors({
            'ids': actors.map((actor) => actor.id).toList(),
            'force': force,
          });
      unwrapStd<void>(raw, (_) {});
      if (!mounted) return;
      AppHaptics.medium();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已删除 ${actors.length} 位演员')));
      _exitSelection();
      _reload(preserveScroll: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('批量删除失败: ${toApiException(error).message}')),
      );
    }
  }

  void _removeDeletedActor(int actorId) {
    var changed = false;
    var removedMainRow = false;
    final nextItems = <ActorRow>[];

    for (final row in _controller.itemList ?? const <ActorRow>[]) {
      if (row.id == actorId) {
        changed = true;
        removedMainRow = true;
        continue;
      }

      final remainingMembers = row.members
          .where((member) => member.id != actorId)
          .toList(growable: false);
      if (remainingMembers.length != row.members.length) {
        changed = true;
        nextItems.add(ActorRow(actor: row.actor, members: remainingMembers));
      } else {
        nextItems.add(row);
      }
    }

    if (!changed || !mounted) return;
    _controller.itemList = nextItems;
    setState(() {
      if (removedMainRow && _totalCount > 0) _totalCount -= 1;
      _expandedIds.remove(actorId);
    });
  }

  void _toggleExpand(int actorId) {
    setState(() {
      if (!_expandedIds.remove(actorId)) {
        _expandedIds.add(actorId);
      }
    });
    AppHaptics.selection();
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      bottomNavigationBar: _selectionMode
          ? EntityBatchToolbar(
              selectedCount: _selectedIds.length,
              onSelectAll: _selectAllLoaded,
              onClear: () => setState(() => _selectedIds.clear()),
              onClose: _exitSelection,
              actions: [
                EntityBatchAction(
                  icon: Icons.delete_outline,
                  label: '删除',
                  color: c.danger,
                  onTap: _selectedIds.isEmpty ? null : _onBatchDelete,
                ),
              ],
            )
          : null,
      body: PopScope(
        canPop: !_selectionMode,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _selectionMode) _exitSelection();
        },
        child: GlowBackground(
          child: SafeArea(
            child: SettingsFixedHeaderLayout(
              scrollController: _scrollController,
              header: SettingsSubPageHeader(
                eyebrow: l.settingsGroupLibrary,
                title: l.settingsActors,
                trailing: SettingsAddButton(
                  onPressed: () => _showEditor(context),
                ),
              ),
              body: RefreshIndicator(
                color: c.accent,
                onRefresh: _refresh,
                child: DragSelectionScope<int>(
                  scrollController: _scrollController,
                  selectionLayout: DragSelectionLayout.list,
                  isSelected: _selectedIds.contains,
                  onSelectionStart: _startSelectionSweep,
                  onSelectionChanged: _applySelectionSweep,
                  onSelectionEnd: _finishSelectionSweep,
                  selectionMode: _selectionMode,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                _hasLoaded ? '$_totalCount' : '—',
                                style: AppText.pageTitle(context),
                              ),
                              const SizedBox(width: 8),
                              Text('位演员', style: AppText.meta(context)),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                          child: Container(
                            decoration: BoxDecoration(
                              color: c.surface,
                              border: Border.all(color: c.cardBorder),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 14),
                                Icon(Icons.search, size: 18, color: c.muted),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: _onSearchChanged,
                                    decoration: const InputDecoration(
                                      hintText: '搜索演员名称',
                                      isCollapsed: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      border: InputBorder.none,
                                    ),
                                    style: TextStyle(
                                      color: c.text,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (_searchController.text.isNotEmpty)
                                  IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: c.muted,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 36,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            children: [
                              CompactSortButton(
                                label: '影片数',
                                active: _sortBy == 'movie_count',
                                ascending: _sortOrder == 'asc',
                                onTap: () => _setSort('movie_count'),
                              ),
                              const SizedBox(width: 7),
                              CompactSortButton(
                                label: '名称',
                                active: _sortBy == 'name',
                                ascending: _sortOrder == 'asc',
                                onTap: () => _setSort('name'),
                              ),
                              const SizedBox(width: 7),
                              CompactSortButton(
                                label: '创建时间',
                                active: _sortBy == 'created_at',
                                ascending: _sortOrder == 'asc',
                                onTap: () => _setSort('created_at'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 10)),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          22,
                          0,
                          22,
                          _selectionMode ? 136 : 80,
                        ),
                        sliver: PagedSliverList<int, ActorRow>(
                          pagingController: _controller,
                          builderDelegate: PagedChildBuilderDelegate<ActorRow>(
                            itemBuilder: (context, row, index) {
                              final actor = row.actor;
                              return DragSelectionTarget<int>(
                                key: ValueKey(row.id),
                                id: row.id,
                                child: _ActorTile(
                                  row: row,
                                  hue: AppHues.all[index % AppHues.all.length],
                                  isExpanded: _expandedIds.contains(row.id),
                                  selectionMode: _selectionMode,
                                  selected: _selectedIds.contains(row.id),
                                  onSelectionTap: () => _toggleSelect(row.id),
                                  onToggleExpand: () => _toggleExpand(row.id),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PersonDetailPage(
                                        actorId: actor.id,
                                        name: actor.name,
                                        actorType: actor.actorType,
                                        biography: actor.biography,
                                        avatarPath: actor.avatarPath,
                                        onUpdated: () =>
                                            _refresh(preserveScroll: true),
                                      ),
                                    ),
                                  ),
                                  onEdit: () =>
                                      _showEditor(context, actor: actor),
                                  onDelete: () =>
                                      _confirmDelete(context, actor),
                                  onEditMember: (member) => _showEditor(
                                    context,
                                    actor: member.asActorItem,
                                  ),
                                  onDeleteMember: (member) => _confirmDelete(
                                    context,
                                    member.asActorItem,
                                    force: true,
                                  ),
                                ),
                              );
                            },
                            firstPageProgressIndicatorBuilder: (_) =>
                                const Center(
                                  child: CircularProgressIndicator(),
                                ),
                            firstPageErrorIndicatorBuilder: (_) => ErrorView(
                              message: _controller.error?.toString() ?? '加载失败',
                              onRetry: _controller.refresh,
                            ),
                            newPageErrorIndicatorBuilder: (_) =>
                                PaginationRetry(
                                  onRetry: _controller.retryLastFailedRequest,
                                ),
                            noItemsFoundIndicatorBuilder: (_) =>
                                const _EmptyActors(),
                            noMoreItemsIndicatorBuilder: (_) =>
                                const NoMoreContent(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditor(BuildContext context, {ActorItem? actor}) async {
    final associationData = actor == null
        ? const _ActorAssociationData.empty()
        : await _loadActorAssociation(actor.name);
    if (!context.mounted) return;

    final c = appColors(context);
    final nameController = TextEditingController(text: actor?.name ?? '');
    final biographyController = TextEditingController(
      text: actor?.biography ?? '',
    );
    final associationController = TextEditingController(
      text: associationData.aliases.join('\n'),
    );
    final isEdit = actor != null;

    final draft = await showModalBottomSheet<_ActorDraft>(
      context: context,
      backgroundColor: c.bg,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            4,
            22,
            MediaQuery.of(sheetContext).viewInsets.bottom + 22,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? '编辑演员' : '新建演员',
                  style: AppText.sectionTitle(sheetContext),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  autofocus: !isEdit,
                  decoration: settingsInputDecoration(
                    sheetContext,
                    labelText: '演员名称',
                    hintText: '演员名称',
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: biographyController,
                  maxLines: 4,
                  minLines: 2,
                  decoration: settingsInputDecoration(
                    sheetContext,
                    labelText: '演员简介',
                    hintText: '填写演员简介（可选）',
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: associationController,
                  maxLines: 4,
                  minLines: 2,
                  decoration: settingsInputDecoration(
                    sheetContext,
                    labelText: '关联名称',
                    hintText: '每行一个，可选',
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final name = nameController.text.trim();
                      if (name.isEmpty) return;
                      Navigator.of(sheetContext).pop(
                        _ActorDraft(
                          name: name,
                          biography: biographyController.text.trim(),
                          associationText: associationController.text,
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: c.text,
                      foregroundColor: c.bg,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(isEdit ? '保存' : '创建'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    nameController.dispose();
    biographyController.dispose();
    associationController.dispose();

    if (draft == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final api = ref.read(requiredApiClientProvider);
      final body = <String, dynamic>{'name': draft.name};
      if (isEdit) {
        body['biography'] = draft.biography;
      } else {
        if (draft.biography.isNotEmpty) body['biography'] = draft.biography;
      }
      final raw = isEdit
          ? await api.catalog.updateActor(actor.id, body)
          : await api.catalog.createActor(body);
      final savedActor = unwrapStd<ActorItem>(
        raw,
        (data) => ActorItem.fromJson(Map<String, dynamic>.from(data as Map)),
      );

      if (associationData.loaded &&
          (isEdit || draft.associationText.trim().isNotEmpty)) {
        await _saveActorAssociation(
          actorName: savedActor.name,
          associationText: draft.associationText,
          existing: associationData.rule,
          isCanonical: associationData.isCanonical,
        );
      }
      AppHaptics.medium();
      messenger.showSnackBar(
        SnackBar(content: Text(isEdit ? '演员已保存' : '演员已创建')),
      );
      await _refresh(preserveScroll: isEdit);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('操作失败: ${toApiException(error).message}')),
      );
    }
  }

  Future<_ActorAssociationData> _loadActorAssociation(String actorName) async {
    try {
      final rules =
          (await ref
                  .read(actorAssociationsRepositoryProvider)
                  .list(limit: 100, search: actorName))
              .items;
      final normalizedName = _normalizeActorName(actorName);
      MappingRule? rule;
      for (final item in rules) {
        final matchesCanonical =
            _normalizeActorName(item.mappedValue) == normalizedName;
        final matchesAlias = item.originalValues.any(
          (value) => _normalizeActorName(value) == normalizedName,
        );
        if (matchesCanonical || matchesAlias) {
          rule = item;
          break;
        }
      }
      if (rule == null) return const _ActorAssociationData.loaded();

      final isCanonical =
          _normalizeActorName(rule.mappedValue) == normalizedName;
      return _ActorAssociationData(
        rule: rule,
        isCanonical: isCanonical,
        aliases: List<String>.from(rule.originalValues),
        loaded: true,
      );
    } catch (_) {
      // 演员资料仍可编辑；关联接口不可用时不覆盖已有规则。
      return const _ActorAssociationData.unavailable();
    }
  }

  Future<void> _saveActorAssociation({
    required String actorName,
    required String associationText,
    required MappingRule? existing,
    required bool isCanonical,
  }) async {
    final repo = ref.read(actorAssociationsRepositoryProvider);
    final mappedValue = isCanonical
        ? actorName
        : (existing?.mappedValue?.trim() ?? actorName);
    final aliases = ActorAssociationsRepository.parseAliases(
      associationText,
      mappedValue,
    );

    if (aliases.isEmpty) {
      if (existing != null) await repo.deleteById(existing.id);
      return;
    }
    if (existing == null) {
      await repo.create(mappedValue: mappedValue, originalValues: aliases);
    } else {
      await repo.update(
        id: existing.id,
        mappedValue: mappedValue,
        originalValues: aliases,
      );
    }
  }

  String _normalizeActorName(String? value) =>
      (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  Future<void> _confirmDelete(
    BuildContext context,
    ActorItem actor, {
    bool force = false,
  }) async {
    final hasMovies = actor.movieCount > 0;
    final willForce = force || hasMovies;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除演员'),
        content: Text(
          hasMovies
              ? '「${actor.name}」关联了 ${actor.movieCount} 部影片。强制删除将解除关联,影片本身不会被删除。'
              : force
              ? '「${actor.name}」是关联名称,删除将解除其影片关联,影片本身不会被删除。'
              : '确定删除「${actor.name}」?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(willForce ? '强制删除' : '删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final raw = await ref
          .read(requiredApiClientProvider)
          .catalog
          .deleteActors({
            'ids': [actor.id],
            'force': willForce,
          });
      unwrapStd<void>(raw, (_) {});
      _removeDeletedActor(actor.id);
      AppHaptics.medium();
      messenger.showSnackBar(const SnackBar(content: Text('演员已删除')));
      await _refresh(preserveScroll: true);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('删除失败: ${toApiException(error).message}')),
      );
    }
  }
}

class _ActorDraft {
  const _ActorDraft({
    required this.name,
    required this.biography,
    required this.associationText,
  });

  final String name;
  final String biography;
  final String associationText;
}

class _ActorAssociationData {
  const _ActorAssociationData({
    this.rule,
    this.isCanonical = true,
    this.aliases = const <String>[],
    required this.loaded,
  });

  const _ActorAssociationData.empty() : this(loaded: true);

  const _ActorAssociationData.loaded() : this(loaded: true);

  const _ActorAssociationData.unavailable() : this(loaded: false);

  final MappingRule? rule;
  final bool isCanonical;
  final List<String> aliases;
  final bool loaded;
}

enum _ActorMenuAction { edit, delete }

class _ActorTile extends StatelessWidget {
  const _ActorTile({
    required this.row,
    required this.hue,
    required this.isExpanded,
    required this.selectionMode,
    required this.selected,
    required this.onSelectionTap,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onEditMember,
    required this.onDeleteMember,
    this.onToggleExpand,
  });

  final ActorRow row;
  final int hue;
  final bool isExpanded;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onSelectionTap;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(ActorAssociationMember member) onEditMember;
  final void Function(ActorAssociationMember member) onDeleteMember;
  final VoidCallback? onToggleExpand;

  ActorItem get actor => row.actor;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final hasBiography = actor.biography?.trim().isNotEmpty == true;
    final avatar = ActorAvatar(
      actorId: actor.id,
      name: actor.name,
      hue: hue,
      size: 42,
      avatarPath: actor.avatarPath,
    );
    // 有关联成员的主行：头像边框提示可展开，点击头像单独展开/收起子行。
    final expandableAvatar =
        !selectionMode && row.hasMembers && onToggleExpand != null
        ? _ExpandableAvatar(
            expanded: isExpanded,
            color: c.accent,
            onTap: onToggleExpand!,
            child: avatar,
          )
        : avatar;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? c.accent : c.cardBorder,
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: PrivacyAwareInkWell(
          movieId: actor.id,
          scope: PrivacyScope.actor,
          onTap: selectionMode ? onSelectionTap : onTap,
          borderRadius: 14,
          child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      if (selectionMode) ...[
                        Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: selected ? c.accent : c.muted,
                        ),
                        const SizedBox(width: 10),
                      ],
                      PrivacyMask(
                        movieId: actor.id,
                        scope: PrivacyScope.actor,
                        radius: 21,
                        icon: false,
                        child: expandableAvatar,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PrivacyText(
                              movieId: actor.id,
                              scope: PrivacyScope.actor,
                              text: actor.name,
                              style: TextStyle(
                                color: c.text,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${actor.movieCount} 部影片',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.meta(context),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<_ActorMenuAction>(
                        tooltip: '更多操作',
                        icon: Icon(Icons.more_horiz, color: c.muted),
                        onSelected: (action) {
                          switch (action) {
                            case _ActorMenuAction.edit:
                              onEdit();
                              return;
                            case _ActorMenuAction.delete:
                              onDelete();
                              return;
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _ActorMenuAction.edit,
                            child: Text('编辑'),
                          ),
                          PopupMenuItem(
                            value: _ActorMenuAction.delete,
                            child: Text('删除'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (row.hasMembers && isExpanded)
                  _ActorMemberList(
                    members: row.members,
                    onEdit: onEditMember,
                    onDelete: onDeleteMember,
                  ),
              ],
            ),
            if (hasBiography)
              Positioned(
                top: 0,
                right: 0,
                child: ClipPath(
                  clipper: _TopRightCornerTriangleClipper(),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: ColoredBox(color: c.accent),
                  ),
                ),
              ),
          ],
          ),
        ),
      ),
    );
  }
}

/// 有关联成员的主行头像：强调色边框提示可展开，点击切换子行展开状态。
class _ExpandableAvatar extends StatelessWidget {
  const _ExpandableAvatar({
    required this.child,
    required this.color,
    required this.onTap,
    required this.expanded,
  });

  final Widget child;
  final Color color;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(alpha: expanded ? 1 : 0.62),
            width: 2,
          ),
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// 展开后的关联成员列表：仅名称 + 关联徽章 + 编辑/删除，不显示头像与影片数。
class _ActorMemberList extends StatelessWidget {
  const _ActorMemberList({
    required this.members,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ActorAssociationMember> members;
  final void Function(ActorAssociationMember member) onEdit;
  final void Function(ActorAssociationMember member) onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 0, 14, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final member in members)
            _ActorMemberRow(
              member: member,
              onEdit: () => onEdit(member),
              onDelete: () => onDelete(member),
            ),
        ],
      ),
    );
  }
}

class _ActorMemberRow extends StatelessWidget {
  const _ActorMemberRow({
    required this.member,
    required this.onEdit,
    required this.onDelete,
  });

  final ActorAssociationMember member;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c.accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PrivacyText(
              movieId: member.id,
              scope: PrivacyScope.actor,
              text: member.name,
              style: TextStyle(
                color: c.text,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '关联',
              style: TextStyle(
                color: c.accent,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          PopupMenuButton<_ActorMenuAction>(
            tooltip: '关联演员操作',
            icon: Icon(Icons.more_horiz, size: 18, color: c.muted),
            onSelected: (action) {
              switch (action) {
                case _ActorMenuAction.edit:
                  onEdit();
                  return;
                case _ActorMenuAction.delete:
                  onDelete();
                  return;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: _ActorMenuAction.edit, child: Text('编辑')),
              PopupMenuItem(value: _ActorMenuAction.delete, child: Text('删除')),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopRightCornerTriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _EmptyActors extends StatelessWidget {
  const _EmptyActors();

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 42, color: c.muted),
          const SizedBox(height: 14),
          Text(
            '还没有演员',
            style: AppText.body(context).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text('点击右上角添加演员', style: AppText.meta(context)),
        ],
      ),
    );
  }
}
