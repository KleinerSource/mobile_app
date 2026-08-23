import 'package:flutter/widgets.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../core/models/paged_result.dart';

/// 分页列表刷新后恢复刷新前的纵向滚动位置。
///
/// [PagingController.refresh] 会先清空已加载页面，列表内容在请求期间可能
/// 缩短并把滚动位置夹回顶部。因此在数据变更后刷新时先记录偏移，首屏及后续
/// 分页加载完成后再恢复，直到目标位置对应的内容已经加载出来。
class PagedScrollPositionRestorer<T> {
  PagedScrollPositionRestorer(this.pagingController);

  final PagingController<int, T> pagingController;
  double? _pendingOffset;

  double? capture(ScrollController controller) {
    return controller.hasClients ? controller.offset : null;
  }

  void prepare(ScrollController controller, {bool preserve = false}) {
    _pendingOffset = preserve ? capture(controller) : null;
  }

  void restoreAfterPage(ScrollController controller) {
    final target = _pendingOffset;
    if (target == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!controller.hasClients || _pendingOffset != target) return;

      final position = controller.position;
      final restored = target
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if ((position.pixels - restored).abs() > 0.5) {
        controller.jumpTo(restored);
      }

      // 目标位置还在未加载的后续分页时保留 pending，触发后续分页后继续恢复。
      if (target <= position.maxScrollExtent ||
          pagingController.nextPageKey == null) {
        _pendingOffset = null;
      }
    });
  }
}

typedef PagedListPageLoader<T> = Future<PagedResult<T>> Function(int limit);

/// 在保留当前列表的前提下，后台刷新已加载的数据。
///
/// [PagingController.refresh] 会先清空 [itemList] 并显示首屏加载状态，适合
/// 用户主动下拉刷新，但不适合从详情页返回这种需要保持内容连续的场景。
/// 这里按当前已加载数量请求第一页，成功后原地替换列表并更新分页游标。
Future<bool> refreshPagedListInBackground<T>({
  required PagingController<int, T> controller,
  required PagedListPageLoader<T> loadFirstPage,
}) async {
  final currentItems = controller.itemList;
  if (currentItems == null || currentItems.isEmpty) return false;

  try {
    final page = await loadFirstPage(currentItems.length);

    // 用户可能在请求期间主动刷新或切换筛选条件，避免旧结果覆盖新列表。
    if (!identical(controller.itemList, currentItems)) return false;

    controller.itemList = page.items;
    controller.nextPageKey = page.hasMore ? page.items.length : null;
    controller.error = null;
    return true;
  } catch (_) {
    // 静默刷新失败时保留已有内容，由下一次主动刷新或重试处理。
    return false;
  }
}
