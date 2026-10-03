import 'package:flutter/material.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/filter_chip.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/library_sort_buttons.dart';
import 'package:omm/shared/sheet_controls.dart';

typedef DbOnlineFilterOption = ({String value, String label});

/// 筛选弹层中的一组单选按钮。
class DbOnlineFilterSection {
  const DbOnlineFilterSection({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final List<DbOnlineFilterOption> options;
  final String selected;
  final ValueChanged<String> onSelected;
}

/// DBO 影片列表通用的筛选弹层：选择后立即生效，弹层保持打开。
///
/// [sections] 在每次选择后重新调用，以读取页面最新的选中值。
Future<void> showDbOnlineFilterSheet(
  BuildContext context, {
  required List<DbOnlineFilterSection> Function(AppL10n l) sections,
}) {
  return showGlassSheet<void>(
    context: context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final l = AppL10n.of(sheetContext);
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SheetHeader(
                  icon: Icons.tune_rounded,
                  title: l.dbOnlineLibraryFilters,
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
                ),
                for (final section in sections(l)) ...[
                  _FilterSectionTitle(title: section.title),
                  _FilterButtonRow(
                    options: section.options,
                    selectedValue: section.selected,
                    onSelected: (value) {
                      section.onSelected(value);
                      setSheetState(() {});
                    },
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// DBO 影片列表通用的排序弹层：选择字段或切换方向后关闭。
Future<void> showDbOnlineSortSheet(
  BuildContext context, {
  required List<DbOnlineFilterOption> options,
  required String selected,
  required bool ascending,
  required ValueChanged<String> onSelected,
  required VoidCallback onToggleOrder,
}) {
  final colors = appColors(context);
  final l = AppL10n.of(context);
  return showGlassSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              icon: Icons.sort_rounded,
              title: l.dbOnlineSort,
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
              trailing: LibraryOrderButton(
                label: ascending ? l.dbOnlineAscending : l.dbOnlineDescending,
                ascending: ascending,
                onTap: () {
                  Navigator.pop(sheetContext);
                  onToggleOrder();
                },
              ),
            ),
            for (final option in options)
              ListTile(
                dense: true,
                title: Text(option.label),
                trailing: option.value == selected
                    ? Icon(Icons.check_rounded, color: colors.accent, size: 18)
                    : null,
                onTap: () {
                  Navigator.pop(sheetContext);
                  onSelected(option.value);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

/// 页头的排序与筛选入口，与 DBO 影片库保持一致。
class DbOnlineSortFilterButtons extends StatelessWidget {
  const DbOnlineSortFilterButtons({
    super.key,
    required this.ascending,
    required this.filterActive,
    required this.onSort,
    required this.onFilter,
  });

  final bool ascending;
  final bool filterActive;
  final VoidCallback onSort;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: l.dbOnlineSort,
          child: LibrarySortButton(ascending: ascending, onTap: onSort),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: l.dbOnlineLibraryFilters,
          child: CompactFilterButton(
            label: '',
            icon: Icons.tune_rounded,
            active: filterActive,
            onTap: onFilter,
          ),
        ),
      ],
    );
  }
}

class _FilterSectionTitle extends StatelessWidget {
  const _FilterSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: AppText.eyebrow(context)),
      ),
    );
  }
}

class _FilterButtonRow extends StatelessWidget {
  const _FilterButtonRow({
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  final List<DbOnlineFilterOption> options;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          for (var index = 0; index < options.length; index++) ...[
            if (index > 0) const SizedBox(width: 7),
            CompactFilterButton(
              label: options[index].label,
              active: options[index].value == selectedValue,
              onTap: () => onSelected(options[index].value),
            ),
          ],
        ],
      ),
    );
  }
}
