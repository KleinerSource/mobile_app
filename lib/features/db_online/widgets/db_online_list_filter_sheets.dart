import 'package:flutter/material.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/filter_chip.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/sheet_controls.dart';

typedef DbOnlineFilterOption = ({String value, String label});

/// 筛选弹层中的一组选项，支持单选与多选。
///
/// 提供 [onSortSelected] 的节按排序节渲染：点击字段选中，点击已选
/// 字段切换升降序，无独立的升降序切换按钮。
class DbOnlineFilterSection {
  const DbOnlineFilterSection({
    required this.title,
    required this.options,
    required this.selected,
    this.onSelected,
    this.multiSelect = false,
    this.ascending,
    this.onSortSelected,
  });

  final String title;
  final List<DbOnlineFilterOption> options;

  /// 单选模式下是当前选中的值；多选模式下是逗号拼接的选中串（如
  /// "m,c"，空串表示未选）。
  final String selected;

  /// 普通筛选节的选择回调；排序节改用 [onSortSelected]，可省略。
  final ValueChanged<String>? onSelected;

  /// 多选模式：点击已选中的选项将其移除；值为空的选项（全部）清空选择。
  final bool multiSelect;

  /// 排序节专用：当前升降序方向（展示用）。
  final bool? ascending;

  /// 排序节专用：非空时本节按排序节渲染，回调带切换后的方向。
  final void Function(String value, bool ascending)? onSortSelected;
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
                  if (section.onSortSelected != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: SortOptionChipRow(
                        options: section.options,
                        selected: section.selected,
                        ascending: section.ascending ?? false,
                        onSelected: (value, ascending) {
                          section.onSortSelected?.call(value, ascending);
                          setSheetState(() {});
                        },
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
                          section.onSelected?.call(
                            current.isEmpty ? '' : current.join(','),
                          );
                        } else {
                          section.onSelected?.call(value);
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

class _FilterButtonRow extends StatefulWidget {
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

  @override
  State<_FilterButtonRow> createState() => _FilterButtonRowState();
}

class _FilterButtonRowState extends State<_FilterButtonRow> {
  final _scrollController = ScrollController();
  final _selectedOptionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollToSelectedOption();
  }

  @override
  void didUpdateWidget(covariant _FilterButtonRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedValue != widget.selectedValue) {
      _scrollToSelectedOption();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _isSelected(String value) => widget.multiSelect
      ? widget.selectedValue.split(',').contains(value)
      : value == widget.selectedValue;

  String? get _scrollTargetValue {
    for (final option in widget.options) {
      if (_isSelected(option.value)) return option.value;
    }
    return null;
  }

  void _scrollToSelectedOption() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _selectedOptionKey.currentContext?.findRenderObject();
      if (target == null) return;
      _scrollController.position.ensureVisible(
        target,
        alignment: 0.5,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scrollTargetValue = _scrollTargetValue;
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          for (var index = 0; index < widget.options.length; index++) ...[
            if (index > 0) const SizedBox(width: 7),
            CompactFilterButton(
              key: widget.options[index].value == scrollTargetValue
                  ? _selectedOptionKey
                  : null,
              label: widget.options[index].label,
              active: _isSelected(widget.options[index].value),
              onTap: () => widget.onSelected(widget.options[index].value),
            ),
          ],
        ],
      ),
    );
  }
}
