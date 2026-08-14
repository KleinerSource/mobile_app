import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/api/envelope.dart';
import '../../core/api/providers.dart';
import '../../core/models/actor.dart';
import '../../core/models/mapping_rule.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glow_background.dart';
import '../../shared/actor_avatar.dart';
import '../../shared/filter_chip.dart';
import '../actor_associations/actor_associations_providers.dart';
import '../actor_associations/actor_associations_repository.dart';
import '../person_detail/person_detail_page.dart';
import '../settings/settings_common.dart';

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
  final _scrollController = ScrollController();
  Timer? _searchDebounce;
  String? _search;
  String _sortBy = 'movie_count';
  String _sortOrder = 'desc';
  List<ActorItem> _items = const [];
  int _totalCount = 0;
  int _nextOffset = 0;
  bool _hasMore = false;
  bool _loading = false;
  bool _hasLoaded = false;
  Object? _error;
  int _requestSerial = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_fetch(reset: true));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 280 ||
        _error != null) {
      return;
    }
    unawaited(_fetch(reset: false));
  }

  Future<void> _fetch({required bool reset}) async {
    if (!reset && (_loading || !_hasMore)) return;

    final requestSerial = reset ? ++_requestSerial : _requestSerial;
    final offset = reset ? 0 : _nextOffset;
    final query = <String, dynamic>{
      'limit': _pageSize,
      'offset': offset,
      'sort_by': _sortBy,
      'sort_order': _sortOrder,
      if (_search != null) 'search': _search,
    };
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items = const [];
        _totalCount = 0;
        _nextOffset = 0;
        _hasMore = false;
        _hasLoaded = false;
      }
    });

    try {
      final raw = await ref.read(requiredApiClientProvider).actors.list(query);
      final page = unwrapTopLevelList<ActorItem>(raw, ActorItem.fromJson);
      if (!mounted || requestSerial != _requestSerial) return;

      final existingIds = _items.map((item) => item.id).toSet();
      final newItems = page.items
          .where((item) => existingIds.add(item.id))
          .toList();
      setState(() {
        _items = [..._items, ...newItems];
        _totalCount = page.totalCount;
        _nextOffset = offset + page.items.length;
        _hasMore = page.hasMore && newItems.isNotEmpty;
        _loading = false;
        _hasLoaded = true;
      });
    } catch (error) {
      if (!mounted || requestSerial != _requestSerial) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      setState(() {
        _search = value.trim().isEmpty ? null : value.trim();
      });
      unawaited(_fetch(reset: true));
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
    unawaited(_fetch(reset: true));
    AppHaptics.selection();
  }

  Future<void> _refresh() async {
    await _fetch(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final items = _items;

    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
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
              child: CustomScrollView(
                primary: true,
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
                  if (_loading && !_hasLoaded)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null && items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '加载失败: ${toApiException(_error!).message}',
                                style: AppText.body(context),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: () => unawaited(_fetch(reset: true)),
                                child: const Text('点击重试'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (items.isEmpty && _hasLoaded)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyActors(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 80),
                      sliver: SliverList.builder(
                        itemCount: items.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= items.length) {
                            if (_error != null) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Center(
                                  child: TextButton(
                                    onPressed: () =>
                                        unawaited(_fetch(reset: false)),
                                    child: const Text('加载更多失败，点击重试'),
                                  ),
                                ),
                              );
                            }
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          }
                          final actor = items[index];
                          return _ActorTile(
                            actor: actor,
                            hue: AppHues.all[index % AppHues.all.length],
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PersonDetailPage(
                                  actorId: actor.id,
                                  name: actor.name,
                                  actorType: actor.actorType,
                                  biography: actor.biography,
                                  avatarPath: actor.avatarPath,
                                  onUpdated: _refresh,
                                ),
                              ),
                            ),
                            onEdit: () => _showEditor(
                              context,
                              actor: actor,
                            ),
                            onDelete: () => _confirmDelete(
                              context,
                              actor,
                            ),
                          );
                        },
                      ),
                    ),
                  if (_loading && _hasLoaded)
                    const SliverToBoxAdapter(
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditor(
    BuildContext context, {
    ActorItem? actor,
  }) async {
    final associationData = actor == null
        ? const _ActorAssociationData.empty()
        : await _loadActorAssociation(actor.name);
    if (!context.mounted) return;

    final c = appColors(context);
    final nameController = TextEditingController(text: actor?.name ?? '');
    final biographyController =
        TextEditingController(text: actor?.biography ?? '');
    final associationController =
        TextEditingController(text: associationData.aliases.join('\n'));
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
      await _refresh();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('操作失败: ${toApiException(error).message}')),
      );
    }
  }

  Future<_ActorAssociationData> _loadActorAssociation(String actorName) async {
    try {
      final rules = (await ref.read(actorAssociationsRepositoryProvider).list(
            limit: 100,
            search: actorName,
          ))
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

  Future<void> _confirmDelete(BuildContext context, ActorItem actor) async {
    final hasMovies = actor.movieCount > 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除演员'),
        content: Text(
          hasMovies
              ? '「${actor.name}」关联了 ${actor.movieCount} 部影片。强制删除将解除关联,影片本身不会被删除。'
              : '确定删除「${actor.name}」?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(hasMovies ? '强制删除' : '删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final raw = await ref.read(requiredApiClientProvider).catalog.deleteActors(
        {
          'ids': [actor.id],
          'force': hasMovies,
        },
      );
      unwrapStd<void>(raw, (_) {});
      AppHaptics.medium();
      messenger.showSnackBar(const SnackBar(content: Text('演员已删除')));
      await _refresh();
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
    this.loaded = true,
  });

  const _ActorAssociationData.empty() : this();

  const _ActorAssociationData.loaded()
      : this(loaded: true);

  const _ActorAssociationData.unavailable()
      : this(loaded: false);

  final MappingRule? rule;
  final bool isCanonical;
  final List<String> aliases;
  final bool loaded;
}

enum _ActorMenuAction { edit, delete }

class _ActorTile extends StatelessWidget {
  const _ActorTile({
    required this.actor,
    required this.hue,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final ActorItem actor;
  final int hue;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final hasBiography = actor.biography?.trim().isNotEmpty == true;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.cardBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  ActorAvatar(
                    actorId: actor.id,
                    name: actor.name,
                    hue: hue,
                    size: 42,
                    avatarPath: actor.avatarPath,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          actor.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.text,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
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
