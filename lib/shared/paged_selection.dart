import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:omm/shared/drag_selection.dart';
import 'package:omm/shared/entity_batch_toolbar.dart';
import 'package:omm/shared/selection_controller.dart';

/// 长按拖选分页列表 · 通用装配（媒体源无关）。
///
/// OMM 影片库/收藏夹与 Emby/Jellyfin 的库/搜索/收藏夹共用同一套拖选交互；
/// 新接入媒体源或新增列表页时按固定三件套装配，避免两类历史问题复发：
///
/// 1. **长按水波纹**：长按手势由本作用域内条目的手势竞技接管（胜出后
///    InkWell 的 tap 手势被拒，高亮/水波纹不出现，长按松手不误触）。
///    拖选页面的卡片自身 `InkWell.onLongPress` 必须保持 null——两个长按
///    手势会竞争导致拖选失效。
/// 2. **拖选勾选不刷新**：拖选过程勾选集合只经 `selectedListenable`
///    通知（不触发页面 setState），勾选态必须在 [PagedSelectionItem]
///    内局部重建，不能在页面 build 时取值后传给卡片。
///
/// 页面装配步骤：
/// 1. 持有 [PagedSelectionController]，`addModeListener` 里 setState；
/// 2. [PagedSelectionPopScope] 包页面根（返回键先退出选择）；
/// 3. [PagedSelectionScope] 包滚动视图（grid/list 两种扫选布局）；
/// 4. 每个条目用 [PagedSelectionItem]，cardBuilder 返回带勾选态的卡片；
/// 5. 页面根 Stack 内叠一个 [PagedSelectionToolbar]（选择模式才出现）。
class PagedSelectionController<I> {
  PagedSelectionController({Object Function(I item)? idOf})
    : idOf = idOf ?? ((item) => item as Object);

  /// 条目 → 选择键（String/int id 均可）；默认把条目本身当键。
  final Object Function(I item) idOf;

  final SelectionController<Object> _selection = SelectionController<Object>();

  ValueListenable<Set<Object>> get selectedListenable =>
      _selection.selectedListenable;

  ValueListenable<bool> get activeListenable => _selection.activeListenable;

  bool get isActive => _selection.isActive;

  Set<Object> get selectedIds => _selection.selected;

  bool contains(Object id) => _selection.contains(id);

  /// 进入/退出选择模式时通知（页面在此 setState）。
  void addModeListener(VoidCallback listener) =>
      _selection.activeListenable.addListener(listener);

  void removeModeListener(VoidCallback listener) =>
      _selection.activeListenable.removeListener(listener);

  /// 拖选起点：进入选择模式并按下首个条目的目标值
  /// （长按未选项 = 选中扫选；长按已选项 = 取消扫选）。
  void startSweep(Object id, bool selected) {
    _selection.enter();
    _selection.setSelected(id, selected);
  }

  /// 拖选过程：设置单项值；扫空时不会提前退出选择模式。
  void applySweep(Object id, bool selected) =>
      _selection.setSelected(id, selected);

  /// 拖选结束：一个不剩时退出选择模式。
  void finishSweep() {
    if (isActive && _selection.isEmpty) exit();
  }

  /// 选择模式下点按条目切换勾选；取消到空集合默认退出选择模式。
  void toggle(Object id) => _selection.toggle(id);

  void clear() => _selection.clear();

  void exit() => _selection.exit();

  void selectAll(Iterable<I> items) => _selection.selectAll(items.map(idOf));

  void retainWhere(bool Function(Object id) test) =>
      _selection.retainWhere(test);

  void dispose() => _selection.dispose();
}

/// 选择作用域 · 包住滚动视图。
///
/// 长按手势在这里的条目（[PagedSelectionItem]）上接管，压掉卡片
/// InkWell 的长按水波纹；布局决定选择模式下的直接拖选方向
/// （网格横向扫选 / 列表左缘纵向扫选）。
class PagedSelectionScope<I> extends StatelessWidget {
  const PagedSelectionScope({
    super.key,
    required this.selection,
    required this.scrollController,
    required this.layout,
    required this.child,
  });

  final PagedSelectionController<I> selection;
  final ScrollController scrollController;
  final DragSelectionLayout layout;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DragSelectionScope<Object>(
      scrollController: scrollController,
      selectionLayout: layout,
      isSelected: selection.contains,
      onSelectionStart: selection.startSweep,
      onSelectionChanged: selection.applySweep,
      onSelectionEnd: selection.finishSweep,
      selectionMode: selection.isActive,
      child: child,
    );
  }
}

/// 单个条目的选择目标。
///
/// cardBuilder 在勾选集合变化时局部重建，selected 为该条目当前勾选态；
/// 选择模式经 `selection.isActive` 读取。切勿在页面 build 时取勾选值
/// 再传给卡片——拖选过程没有页面级重建，勾选会停在旧值。
class PagedSelectionItem<I> extends StatelessWidget {
  const PagedSelectionItem({
    super.key,
    required this.selection,
    required this.item,
    required this.cardBuilder,
    this.selectionIndex,
    this.selectionHandleAlignment = Alignment.topLeft,
  });

  final PagedSelectionController<I> selection;
  final I item;

  /// 网格内传行序号（范围扫选）；列表传 null（沿拖动路径扫选）。
  final int? selectionIndex;

  /// 列表模式下左缘直接拖选热区的对齐位置。
  final Alignment selectionHandleAlignment;

  final Widget Function(BuildContext context, I item, bool selected)
  cardBuilder;

  @override
  Widget build(BuildContext context) {
    final id = selection.idOf(item);
    return DragSelectionTarget<Object>(
      key: ValueKey(id),
      id: id,
      selectionIndex: selectionIndex,
      selectionHandleAlignment: selectionHandleAlignment,
      child: ValueListenableBuilder<Set<Object>>(
        valueListenable: selection.selectedListenable,
        builder: (context, selected, _) =>
            cardBuilder(context, item, selected.contains(id)),
      ),
    );
  }
}

/// 选择模式的返回键拦截 · 包在页面根。
class PagedSelectionPopScope<I> extends StatelessWidget {
  const PagedSelectionPopScope({
    super.key,
    required this.selection,
    required this.child,
  });

  final PagedSelectionController<I> selection;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !selection.isActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && selection.isActive) selection.exit();
      },
      child: child,
    );
  }
}

/// 底部批量工具栏浮层 · 作为页面根 Stack 的直接 child。
///
/// 非选择模式下渲染为零尺寸占位；actionsBuilder 按当前已选集合构建
/// 批量操作（空集合或页面忙碌时返回 null 的 onTap 以禁用按钮）。
class PagedSelectionToolbar<I> extends StatelessWidget {
  const PagedSelectionToolbar({
    super.key,
    required this.selection,
    required this.onSelectAll,
    required this.actionsBuilder,
  });

  final PagedSelectionController<I> selection;

  /// 全选回调；页面一般传已加载条目：
  /// `() => selection.selectAll(_controller.itemList ?? [])`。
  final VoidCallback onSelectAll;

  final List<EntityBatchAction> Function(Set<Object> selected) actionsBuilder;

  @override
  Widget build(BuildContext context) {
    if (!selection.isActive) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ValueListenableBuilder<Set<Object>>(
        valueListenable: selection.selectedListenable,
        builder: (context, selected, _) => EntityBatchToolbar(
          selectedCount: selected.length,
          onSelectAll: onSelectAll,
          onClear: selection.clear,
          onClose: selection.exit,
          actions: actionsBuilder(selected),
        ),
      ),
    );
  }
}
