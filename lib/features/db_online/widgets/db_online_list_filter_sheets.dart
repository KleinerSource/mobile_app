import 'package:flutter/material.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/filter_chip.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/sheet_controls.dart';

typedef DbOnlineFilterOption = ({String value, String label});

/// 筛选弹层中的一组选项，支持单选与多选。
///
/// 提供 [onToggleOrder] 的节按排序节渲染：字段 chip 行 + 行尾升降序切换。
class DbOnlineFilterSection {
  const DbOnlineFilterSection({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.multiSelect = false,
    this.ascending,
    this.onToggleOrder,
  });

  final String title;
  final List<DbOnlineFilterOption> options;

  /// 单选模式下是当前选中的值；多选模式下是逗号拼接的选中串（如
  /// "m,c"，空串表示未选）。
  final String selected;
  final ValueChanged<String> onSelected;

  /// 多选模式：点击已选中的选项将其移除；值为空的选项（全部）清空选择。
  final bool multiSelect;

  /// 排序节专用：当前升降序方向。
  final bool? ascending;

  /// 排序节专用：非空时行尾渲染升降序切换 chip。
  final VoidCallback? onToggleOrder;
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
                  if (section.onToggleOrder != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: SortOptionChipRow(
                        options: section.options,
                        selected: section.selected,
                        ascending: section.ascending ?? true,
                        onSelected: (value) {
                          section.onSelected(value);
                          setSheetState(() {});
                        },
                        onToggleOrder: () {
                          section.onToggleOrder?.call();
                          setSheetState(() {});
                        },
                        ascendingLabel: l.dbOnlineAscending,
                        descendingLabel: l.dbOnlineDescending,
                      ),
                    )
                  else
                    _FilterButtonRow(
                      options: section.options,
                      selectedValue: section.selected,
                      multiSelect: section.multiSelect,
                      onSelected: (value) {
                        if (section.multiSelect) {
                          final current = section.selected
                              .split(',')
                              .where((item) => item.isNotEmpty)
                              .toSet();
                          if (value.isEmpty) {
                            current.clear();
                          } else if (!current.remove(value)) {
                            current.add(value);
                          }
                          section.onSelected(
                            current.isEmpty ? '' : current.join(','),
                          );
                        } else {
                          section.onSelected(value);
                        }
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
    this.multiSelect = false,
  });

  final List<DbOnlineFilterOption> options;
  final String selectedValue;
  final ValueChanged<String> onSelected;
  final bool multiSelect;

  bool _isSelected(String value) => multiSelect
      ? selectedValue.split(',').contains(value)
      : value == selectedValue;

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
              active: _isSelected(options[index].value),
              onTap: () => onSelected(options[index].value),
            ),
          ],
        ],
      ),
    );
  }
}
