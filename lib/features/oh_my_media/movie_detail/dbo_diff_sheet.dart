import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/envelope.dart';
import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/models/resource.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/sheet_controls.dart';
import 'package:omm/core/sources/media/media_source_providers.dart';
import 'package:omm/core/sources/media/omm_metadata_operations_source.dart';
import 'package:omm/features/oh_my_media/resources/resources_providers.dart';
import 'package:omm/features/oh_my_media/resources/resources_repository.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';
import 'dbo_metadata_diff.dart';

/// 从 DBO 接口拉元数据 · 弹出 diff sheet 让用户挑选要应用的字段
///
/// 流程:
/// 1. 显示 loading 调 getDbonlineMetadata
/// 2. 把 DBO 数据 vs 当前影片对比,生成可选 diff 项
/// 3. 用户勾选要应用的字段 → updateMovie(local) → refresh detail
class DboDiffSheet extends ConsumerStatefulWidget {
  const DboDiffSheet({super.key, required this.movie});
  final MovieDetail movie;

  static Future<void> show(BuildContext context, MovieDetail movie) {
    return showGlassSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DboDiffSheet(movie: movie),
    );
  }

  @override
  ConsumerState<DboDiffSheet> createState() => _DboDiffSheetState();
}

class _DboDiffSheetState extends ConsumerState<DboDiffSheet> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<DboMetadataDiffItem> _items = const [];
  Map<String, dynamic>? _meta;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref
          .read(mediaRepositoryProvider)
          .getDbonlineMetadata(widget.movie.id);
      if (!mounted) return;
      _meta = data;
      _items = buildDboMetadataDiff(widget.movie, data).items;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = toApiException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _anySelected => _items.any((i) => i.selected);

  Future<void> _apply() async {
    final selected = _items.where((i) => i.selected).toList();
    if (selected.isEmpty) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final movies = ref.read(mediaRepositoryProvider);
      final payload = <String, dynamic>{};
      for (final item in selected) {
        if (item.section != DboMetadataDiffSection.info || item.field == null) {
          continue;
        }
        payload[item.field!] = item.value;
      }

      final selectedSeries = selected
          .where((item) => item.section == DboMetadataDiffSection.series)
          .toList();
      var seriesRemoved = false;
      for (final item in selectedSeries) {
        if (item.action == DboMetadataDiffAction.remove &&
            item.localId != null) {
          await movies.batchRemoveAssociations(
            movieIds: [widget.movie.id],
            seriesId: item.localId,
          );
          seriesRemoved = true;
        } else if (item.action != DboMetadataDiffAction.remove &&
            item.remoteName?.trim().isNotEmpty == true) {
          payload['series_id'] = await _ensureOptionId(
            type: 'series',
            name: item.remoteName!,
          );
        }
      }

      final selectedGenres = selected
          .where((item) => item.section == DboMetadataDiffSection.genres)
          .toList();
      if (selectedGenres.isNotEmpty) {
        payload['genre_ids'] = await _nextAssociationIds(
          currentIds: widget.movie.genres.map((item) => item.id),
          changes: selectedGenres,
          type: 'genre',
        );
      }

      final selectedActors = selected
          .where((item) => item.section == DboMetadataDiffSection.actors)
          .toList();
      if (selectedActors.isNotEmpty) {
        payload['actor_ids'] = await _nextAssociationIds(
          currentIds: widget.movie.actors.map((item) => item.id),
          changes: selectedActors,
          type: 'actor',
        );
      }

      if (payload.isNotEmpty) {
        await movies.updateMovie(widget.movie.id, payload);
      } else if (!seriesRemoved) {
        return;
      }
      if (!mounted) return;
      // ignore: unused_result
      ref.refresh(movieDetailProvider(widget.movie.id));
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppL10n.of(context).dboAppliedFields(selected.length)),
          duration: const Duration(seconds: 1),
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppL10n.of(context).dboApplyFailed(toApiException(e).message),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<List<int>> _nextAssociationIds({
    required Iterable<int> currentIds,
    required List<DboMetadataDiffItem> changes,
    required String type,
  }) async {
    final ids = currentIds.toSet();
    for (final item in changes) {
      if (item.action == DboMetadataDiffAction.remove) {
        if (item.localId != null) ids.remove(item.localId);
        continue;
      }
      final name = item.remoteName?.trim() ?? '';
      if (name.isEmpty) continue;
      ids.add(await _ensureOptionId(type: type, name: name));
    }
    return ids.toList();
  }

  Future<int> _ensureOptionId({
    required String type,
    required String name,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw StateError('DB Online 返回的名称为空');
    }

    final source = ref.read(ommMediaSourceProvider);
    if (source == null) throw StateError('当前服务器不是 OMM');
    final candidates = switch (type) {
      'genre' =>
        (await ref
                .read(resourcesRepositoryProvider)
                .options(ResourceKind.genre, search: normalizedName))
            .items,
      'series' =>
        (await ref
                .read(resourcesRepositoryProvider)
                .options(ResourceKind.series, search: normalizedName))
            .items,
      'actor' => await _actorOptions(source.metadataOperations, normalizedName),
      _ => const <ResourceItem>[],
    };
    final key = normalizedName.toLowerCase();
    for (final item in candidates) {
      if (item.name.trim().toLowerCase() == key) return item.id;
    }

    final raw = switch (type) {
      'genre' =>
        await ref
            .read(resourcesRepositoryProvider)
            .create(ResourceKind.genre, name: normalizedName),
      'series' =>
        await ref
            .read(resourcesRepositoryProvider)
            .create(ResourceKind.series, name: normalizedName),
      'actor' => await source.metadataOperations.createActor({
        'name': normalizedName,
      }),
      _ => throw StateError('未知 DBO 关联类型: $type'),
    };
    final created = unwrapStd<ResourceItem>(raw, (data) {
      if (data is! Map) throw const FormatException('实体响应格式异常');
      return ResourceItem.fromJson(Map<String, dynamic>.from(data));
    });
    return created.id;
  }

  Future<List<ResourceItem>> _actorOptions(
    OmmMetadataOperationsSource source,
    String search,
  ) async {
    try {
      final raw = await source.actorOptions({'search': search});
      return unwrapOptions<ResourceItem>(raw, ResourceItem.fromJson).items;
    } catch (error) {
      final status = toApiException(error).status;
      if (status != 404 && status != 400) rethrow;
      final raw = await source.listActors({
        'limit': 500,
        'offset': 0,
        'sort_by': 'movie_count',
        'sort_order': 'desc',
        'search': search,
      });
      return unwrapTopLevelList<ResourceItem>(raw, ResourceItem.fromJson).items;
    }
  }

  void _selectAll(bool v) {
    setState(() {
      for (final it in _items) {
        it.selected = v;
      }
    });
  }

  void _setSectionSelection(List<DboMetadataDiffItem> items, bool selected) {
    setState(() {
      for (final item in items) {
        item.selected = selected;
      }
    });
  }

  String _sectionLabel(AppL10n l, DboMetadataDiffSection section) {
    return switch (section) {
      DboMetadataDiffSection.info => l.dboSectionInfo,
      DboMetadataDiffSection.series => l.dboSectionSeries,
      DboMetadataDiffSection.genres => l.dboSectionGenres,
      DboMetadataDiffSection.actors => l.dboSectionActors,
    };
  }

  Widget _buildDiffSections(BuildContext context, AppColors c) {
    const order = <DboMetadataDiffSection>[
      DboMetadataDiffSection.info,
      DboMetadataDiffSection.series,
      DboMetadataDiffSection.genres,
      DboMetadataDiffSection.actors,
    ];
    final grouped = <DboMetadataDiffSection, List<DboMetadataDiffItem>>{
      for (final section in order)
        section: _items.where((item) => item.section == section).toList(),
    };
    final visible = order
        .where((section) => grouped[section]!.isNotEmpty)
        .toList(growable: false);

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
      children: [
        for (var index = 0; index < visible.length; index++) ...[
          if (index > 0) Divider(height: 24, color: c.divider),
          _DboDiffSection(
            label: _sectionLabel(AppL10n.of(context), visible[index]),
            section: visible[index],
            items: grouped[visible[index]]!,
            saving: _saving,
            onToggle: (item) => setState(() {
              item.selected = !item.selected;
            }),
            onSelectAll: () =>
                _setSectionSelection(grouped[visible[index]]!, true),
            onClear: () =>
                _setSectionSelection(grouped[visible[index]]!, false),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final dboTitle = _meta?['title']?.toString() ?? '';
    final dboCode =
        _meta?['code']?.toString() ?? _meta?['num']?.toString() ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeader(
          icon: Icons.sync_alt_outlined,
          title: l.dboTitle,
          subtitle: (dboTitle.isNotEmpty || dboCode.isNotEmpty)
              ? [
                  if (dboCode.isNotEmpty) dboCode,
                  if (dboTitle.isNotEmpty) dboTitle,
                ].join(' · ')
              : null,
          trailing: IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: _loading ? null : _load,
          ),
        ),
        // ===== 主体 =====
        Flexible(
          fit: FlexFit.loose,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: c.danger,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              : _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 36,
                          color: c.muted,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l.dboUpToDate,
                          style: AppText.body(
                            context,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l.dboNoOverridableFields,
                          style: AppText.meta(context),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildDiffSections(context, c),
        ),
        // ===== 底部 actions =====
        if (!_loading && _items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
            child: Row(
              children: [
                TextButton(
                  onPressed: _saving ? null : () => _selectAll(!_anySelected),
                  child: Text(
                    _anySelected ? l.dboClear : l.dboSelectAll,
                    style: TextStyle(
                      color: c.muted,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: (_anySelected && !_saving) ? _apply : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _anySelected
                              ? l.dboApplyCount(
                                  _items.where((i) => i.selected).length,
                                )
                              : l.dboSelectFields,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DboDiffSection extends StatelessWidget {
  const _DboDiffSection({
    required this.label,
    required this.section,
    required this.items,
    required this.saving,
    required this.onToggle,
    required this.onSelectAll,
    required this.onClear,
  });

  final String label;
  final DboMetadataDiffSection section;
  final List<DboMetadataDiffItem> items;
  final bool saving;
  final ValueChanged<DboMetadataDiffItem> onToggle;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;

  bool get _isCollection =>
      section == DboMetadataDiffSection.genres ||
      section == DboMetadataDiffSection.actors;

  bool _isLongText(DboMetadataDiffItem item) {
    return section == DboMetadataDiffSection.info &&
        (item.field == 'title' || item.field == 'plot');
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final durationRatingItems = section == DboMetadataDiffSection.info
        ? <DboMetadataDiffItem>[
            ...items.where((item) => item.field == 'runtime'),
            ...items.where((item) => item.field == 'rating'),
          ]
        : const <DboMetadataDiffItem>[];
    final badgeItems = items
        .where(
          (item) => !_isLongText(item) && !durationRatingItems.contains(item),
        )
        .toList();
    final longTextItems = items.where(_isLongText).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: c.text,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: saving ? null : onSelectAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(l.dboSelectAll),
            ),
            TextButton(
              onPressed: saving ? null : onClear,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(l.dboClear),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isCollection || section == DboMetadataDiffSection.series)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in badgeItems)
                _DboDiffBadge(
                  item: item,
                  section: section,
                  saving: saving,
                  onTap: () => onToggle(item),
                ),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < longTextItems.length; i++) ...[
                _DboDiffRow(
                  item: longTextItems[i],
                  saving: saving,
                  onTap: () => onToggle(longTextItems[i]),
                ),
                if (i < longTextItems.length - 1) const SizedBox(height: 8),
              ],
              if (longTextItems.isNotEmpty && durationRatingItems.isNotEmpty)
                const SizedBox(height: 10),
              if (durationRatingItems.isNotEmpty)
                Row(
                  children: [
                    for (var i = 0; i < durationRatingItems.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Flexible(
                        child: _DboDiffBadge(
                          item: durationRatingItems[i],
                          section: section,
                          saving: saving,
                          onTap: () => onToggle(durationRatingItems[i]),
                        ),
                      ),
                    ],
                  ],
                ),
              if (durationRatingItems.isNotEmpty && badgeItems.isNotEmpty)
                const SizedBox(height: 10),
              if (badgeItems.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in badgeItems)
                      _DboDiffBadge(
                        item: item,
                        section: section,
                        saving: saving,
                        onTap: () => onToggle(item),
                      ),
                  ],
                ),
            ],
          ),
      ],
    );
  }
}

class _DboDiffRow extends StatelessWidget {
  const _DboDiffRow({
    required this.item,
    required this.saving,
    required this.onTap,
  });

  final DboMetadataDiffItem item;
  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: saving ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: item.selected ? c.accent.withValues(alpha: 0.1) : c.chipBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: item.selected
                    ? c.accent.withValues(alpha: 0.55)
                    : c.cardBorder,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _dboFieldLabel(l, item.field, item.label),
                        style: TextStyle(
                          color: c.text,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (item.currentText != null)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.dboCurrent, style: AppText.meta(context)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item.currentText!,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: c.muted,
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 5),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.arrow_forward, size: 12, color: c.accent),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.remoteText,
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.accent,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
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

class _DboDiffBadge extends StatelessWidget {
  const _DboDiffBadge({
    required this.item,
    required this.section,
    required this.saving,
    required this.onTap,
  });

  final DboMetadataDiffItem item;
  final DboMetadataDiffSection section;
  final bool saving;
  final VoidCallback onTap;

  bool get _isRemove => item.action == DboMetadataDiffAction.remove;

  bool get _isReplace =>
      item.action == DboMetadataDiffAction.replace &&
      item.currentText?.trim().isNotEmpty == true;

  String _displayName() {
    final value = _isRemove
        ? item.currentText
        : item.remoteName ?? item.remoteText;
    return value?.trim().isNotEmpty == true ? value!.trim() : item.remoteText;
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final accent = _isRemove ? c.danger : c.accent;
    final selected = item.selected;
    final showLabel = section == DboMetadataDiffSection.info;
    final textStyle = TextStyle(
      color: selected ? accent : c.text,
      fontFamily: 'Inter',
      fontWeight: FontWeight.w700,
      fontSize: 12.5,
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(100),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: saving ? null : onTap,
        borderRadius: BorderRadius.circular(100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.14) : c.chipBg,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: selected ? accent.withValues(alpha: 0.6) : c.cardBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showLabel) ...[
                Text(
                  '${_dboFieldLabel(l, item.field, item.label)}:',
                  style: AppText.meta(context).copyWith(
                    color: selected ? accent : c.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              if (!_isReplace)
                Icon(
                  _isRemove
                      ? Icons.remove_circle_outline
                      : Icons.add_circle_outline,
                  size: 15,
                  color: selected ? accent : c.muted,
                ),
              if (!_isReplace) const SizedBox(width: 5),
              if (_isReplace) ...[
                Flexible(
                  child: Text(
                    item.currentText!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle.copyWith(
                      color: selected ? c.muted : c.muted2,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Icon(Icons.arrow_forward, size: 13, color: accent),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  _displayName(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle,
                ),
              ),
              if (section == DboMetadataDiffSection.actors &&
                  item.gender?.trim().isNotEmpty == true) ...[
                const SizedBox(width: 6),
                _DboGenderBadge(gender: item.gender!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DboGenderBadge extends StatelessWidget {
  const _DboGenderBadge({required this.gender});

  final String gender;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final l = AppL10n.of(context);
    final normalized = gender.trim().toLowerCase();
    final isFemale =
        normalized == '♀' || normalized == '女' || normalized == 'female';
    final isMale =
        normalized == '♂' || normalized == '男' || normalized == 'male';
    final color = isFemale
        ? const Color(0xFFE875A8)
        : isMale
        ? const Color(0xFF69A7F8)
        : colors.muted;
    final label = isFemale
        ? l.dboFemale
        : isMale
        ? l.dboMale
        : gender.trim();
    final icon = isFemale
        ? Icons.female
        : isMale
        ? Icons.male
        : Icons.person_outline;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ],
    );
  }
}

String _dboFieldLabel(AppL10n l, String? field, String fallback) =>
    switch (field) {
      'title' => l.dboFieldTitle,
      'rating' => l.dboFieldRating,
      'year' => l.dboFieldYear,
      'runtime' => l.dboFieldRuntime,
      'plot' => l.dboFieldPlot,
      'series' => l.dboSectionSeries,
      'genres' => l.dboSectionGenres,
      'actors' => l.dboSectionActors,
      'remove' => l.dboRemove,
      _ => fallback,
    };
