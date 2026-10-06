import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/core/sources/media/dbo/db_online_following.dart';
import 'package:omm/features/db_online/providers/db_online_subscription_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/error_view.dart';
import 'package:omm/shared/filter_chip.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'package:omm/shared/sheet_controls.dart';

/// 演员订阅类别过滤的多选弹窗（包含/排除类别共用），选项来自该演员的
/// 标签列表 `GET /options/categories/{actorId}`，保存值为类别 external_id。
class DbOnlineActorCategoriesSheet extends ConsumerStatefulWidget {
  const DbOnlineActorCategoriesSheet({
    super.key,
    required this.actorId,
    required this.title,
    required this.selected,
    required this.maxSelections,
  });

  final String actorId;
  final String title;
  final List<String> selected;
  final int maxSelections;

  @override
  ConsumerState<DbOnlineActorCategoriesSheet> createState() =>
      _DbOnlineActorCategoriesSheetState();
}

class _DbOnlineActorCategoriesSheetState
    extends ConsumerState<DbOnlineActorCategoriesSheet> {
  late final Set<String> _selected = widget.selected.toSet();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final categories = ref.watch(
      dbOnlineActorCategoriesProvider(widget.actorId),
    );
    final selectedTarget = _selected.isEmpty ? null : _selected.last;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: sheetMaxHeight(context) * .8,
        child: Column(
          children: [
            SheetHeader(
              icon: Icons.category_outlined,
              title: widget.title,
              subtitle: l.dbOnlineSubscriptionCategoryCount(
                _selected.length,
                widget.maxSelections,
              ),
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
                  hintText: l.dbOnlineSubscriptionSearchCategories,
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
                    l.dbOnlineSubscriptionCategoryCount(
                      _selected.length,
                      widget.maxSelections,
                    ),
                    style: AppText.meta(context),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => setState(_selected.clear),
                    child: Text(l.dbOnlineSubscriptionClearSelection),
                  ),
                ],
              ),
            ),
            if (_selected.isNotEmpty)
              SelectedHorizontalScrollView(
                selectedValue: selectedTarget,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                childBuilder: (context, selectedItemKey) => Row(
                  children: [
                    for (final id in _selected)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: CompactFilterButton(
                          key: id == selectedTarget ? selectedItemKey : null,
                          label: _categoryName(categories.asData?.value, id),
                          active: true,
                          trailingIcon: Icons.close_rounded,
                          onTap: () => setState(() => _selected.remove(id)),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: categories.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ErrorView(
                  message: localizedErrorMessage(l, error),
                  onRetry: () => ref.invalidate(
                    dbOnlineActorCategoriesProvider(widget.actorId),
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
                                _selected.length >= widget.maxSelections
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

  /// 已选值存储的是类别 external_id；列表尚未加载或值不在该演员的标签
  /// 中（如历史手输内容）时回退显示原始值。
  String _categoryName(List<DbOnlineFollowingStyle>? items, String id) {
    for (final item in items ?? const <DbOnlineFollowingStyle>[]) {
      if (item.id == id) return item.name;
    }
    return id;
  }
}
