import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/core/sources/media/dbo/db_online_following.dart';
import 'package:omm/features/db_online/providers/db_online_following_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/error_view.dart';
import 'package:omm/shared/filter_chip.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'package:omm/shared/sheet_controls.dart';

import 'db_online_filter_chip_row.dart';
import 'db_online_following_widgets.dart';

class DbOnlineFollowingFilterSheet extends ConsumerStatefulWidget {
  const DbOnlineFollowingFilterSheet({
    super.key,
    required this.serverId,
    required this.filter,
    required this.database,
    required this.onChanged,
  });
  final String serverId;
  final DbOnlineFollowingFilter filter;
  final bool database;
  final ValueChanged<DbOnlineFollowingFilter> onChanged;

  @override
  ConsumerState<DbOnlineFollowingFilterSheet> createState() =>
      _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<DbOnlineFollowingFilterSheet> {
  late DbOnlineFollowingFilter _filter = widget.filter;

  void _change(DbOnlineFollowingFilter value) {
    if (!isDbOnlineFollowingServer(ref, widget.serverId)) return;
    setState(() => _filter = value);
    widget.onChanged(_filter);
  }

  Future<void> _styles() async {
    final selected = await showGlassSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      minHeight: sheetMinHeight(context),
      builder: (_) => _FollowingStylesSheet(
        serverId: widget.serverId,
        selected: _filter.styles,
      ),
    );
    if (selected != null && mounted) {
      _change(_filter.copyWith(styles: selected));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final dateMenuMaxHeight = (sheetMaxHeight(context) * 0.4)
        .clamp(0.0, 280.0)
        .toDouble();
    Widget label(String value) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 3),
      child: Text(value, style: AppText.eyebrow(context)),
    );
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetHeader(
              icon: Icons.tune_rounded,
              title: l.dbOnlineFollowingFilters,
            ),
            label(l.dbOnlineCategorySection),
            DbOnlineFollowingButtonRow(
              options: [
                (value: '0', label: l.dbOnlineCategoryCensored),
                (value: '1', label: l.dbOnlineCategoryUncensored),
                (value: '2', label: l.dbOnlineCategoryWestern),
                (value: '3', label: 'FC2'),
                (value: '4', label: l.dbOnlineCategoryAnime),
              ],
              isSelected: (value) => value == _filter.category,
              onSelected: (value) => _change(_filter.copyWith(category: value)),
            ),
            label(l.dbOnlineFollowingConditions),
            DbOnlineFollowingButtonRow(
              options: [
                for (final option in dbOnlineResourceConditions)
                  (
                    value: option.letter,
                    label: dbOnlineResourceConditionLabel(l, option),
                  ),
              ],
              isSelected: _filter.basic.contains,
              onSelected: (value) {
                final selected = _filter.basic.toSet();
                selected.contains(value)
                    ? selected.remove(value)
                    : selected.add(value);
                _change(
                  _filter.copyWith(
                    basic: dbOnlineResourceConditionLetters(selected),
                  ),
                );
              },
            ),
            label(l.dbOnlineSort),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
              child: Row(
                children: [
                  CompactSortButton(
                    label: l.dbOnlineRecentUpdated,
                    active: _filter.sortBy == 'update',
                    ascending: false,
                    onTap: () => _change(
                      _filter.copyWith(sortBy: 'update', orderBy: 'desc'),
                    ),
                  ),
                  const SizedBox(width: 7),
                  CompactSortButton(
                    label: l.dbOnlineDetailDate,
                    active: _filter.sortBy == 'release',
                    ascending: _filter.orderBy == 'asc',
                    onTap: () => _change(
                      _filter.copyWith(
                        sortBy: 'release',
                        orderBy:
                            _filter.sortBy == 'release' &&
                                _filter.orderBy == 'desc'
                            ? 'asc'
                            : 'desc',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.database) ...[
              label(l.dbOnlineFollowingStyles),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 4,
                ),
                child: CompactFilterButton(
                  label: l.dbOnlineFollowingStyleCount(_filter.styles.length),
                  icon: Icons.category_outlined,
                  active: _filter.styles.isNotEmpty,
                  onTap: _styles,
                ),
              ),
            ],
            label(l.dbOnlineFollowingTime),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _filter.year,
                      menuMaxHeight: dateMenuMaxHeight,
                      decoration: sheetInputDecoration(
                        context,
                        labelText: l.dbOnlineFollowingYear,
                      ),
                      items: [
                        DropdownMenuItem(value: '', child: Text(l.filterAll)),
                        for (
                          var year = DateTime.now().year;
                          year >= 2011;
                          year--
                        )
                          DropdownMenuItem(
                            value: '$year',
                            child: Text('$year'),
                          ),
                      ],
                      onChanged: (value) =>
                          _change(_filter.copyWith(year: value)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _filter.month,
                      menuMaxHeight: dateMenuMaxHeight,
                      decoration: sheetInputDecoration(
                        context,
                        labelText: l.dbOnlineFollowingMonth,
                      ),
                      items: [
                        DropdownMenuItem(value: '', child: Text(l.filterAll)),
                        for (var month = 1; month <= 12; month++)
                          DropdownMenuItem(
                            value: '$month'.padLeft(2, '0'),
                            child: Text('$month'),
                          ),
                      ],
                      onChanged: (value) =>
                          _change(_filter.copyWith(month: value)),
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

class _FollowingStylesSheet extends ConsumerStatefulWidget {
  const _FollowingStylesSheet({required this.serverId, required this.selected});
  final String serverId;
  final List<String> selected;

  @override
  ConsumerState<_FollowingStylesSheet> createState() => _StylesState();
}

class _StylesState extends ConsumerState<_FollowingStylesSheet> {
  late final _selected = widget.selected.toSet();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final styles = ref.watch(dbOnlineFollowingStylesProvider(widget.serverId));
    return SafeArea(
      top: false,
      child: SizedBox(
        height: sheetMaxHeight(context) * .8,
        child: Column(
          children: [
            SheetHeader(
              icon: Icons.category_outlined,
              title: l.dbOnlineFollowingStyles,
              subtitle: l.dbOnlineFollowingStyleLimit,
              trailing: TextButton(
                onPressed: () => Navigator.pop(context, _selected.toList()),
                child: Text(l.dbOnlineSubscriptionSave),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: TextField(
                decoration: sheetInputDecoration(
                  context,
                  hintText: l.dbOnlineFollowingSearchStyles,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
              child: Row(
                children: [
                  Text(
                    l.dbOnlineFollowingStyleCount(_selected.length),
                    style: AppText.meta(context),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(_selected.clear),
                    child: Text(l.filterAll),
                  ),
                ],
              ),
            ),
            if (_selected.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  children: [
                    for (final id in _selected)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: CompactFilterButton(
                          label:
                              styles.asData?.value
                                  .where((item) => item.id == id)
                                  .firstOrNull
                                  ?.name ??
                              id,
                          active: true,
                          trailingIcon: Icons.close_rounded,
                          onTap: () => setState(() => _selected.remove(id)),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: styles.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ErrorView(
                  message: localizedErrorMessage(l, error),
                  onRetry: () => ref.invalidate(
                    dbOnlineFollowingStylesProvider(widget.serverId),
                  ),
                ),
                data: (items) => ListView(
                  children: [
                    for (final item in items.where(
                      (item) => '${item.name} ${item.id}'
                          .toLowerCase()
                          .contains(_query),
                    ))
                      CheckboxListTile(
                        value: _selected.contains(item.id),
                        title: Text(item.name),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged:
                            !_selected.contains(item.id) &&
                                _selected.length >= 5
                            ? null
                            : (value) => setState(() {
                                value == true
                                    ? _selected.add(item.id)
                                    : _selected.remove(item.id);
                              }),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
