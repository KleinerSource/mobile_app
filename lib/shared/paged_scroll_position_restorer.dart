import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../core/models/paged_result.dart';
import 'paged_request_coordinator.dart';

/// 4.x 在首屏仍加载时 refresh 可能不通知列表重新请求；帧末补发该请求。
/// 正常列表监听也在帧末请求，同页请求由 requests 去重。
void refreshPagedController<T>({
  required PagingController<int, T> controller,
  required PagedRequestCoordinator requests,
  required Future<void> Function(int) loadPage,
}) {
  if (requests.isDisposed) return;
  controller.refresh();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (requests.isDisposed) return;
    if (controller.value.status == PagingStatus.loadingFirstPage) {
      unawaited(loadPage(controller.firstPageKey));
    }
  });
  WidgetsBinding.instance.ensureVisualUpdate();
}

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

/// 将一页分页数据落地到 [controller] 并触发滚动位置恢复。
///
/// 各列表页共同的收尾逻辑: 还有后续数据时 `appendPage`,
/// 否则(含空页) `appendLastPage`。返回是否有后续页,
/// 供 `_lastPageComplete` 这类"末页样式"标记使用。
bool applyPagedListPage<T>({
  required PagingController<int, T> controller,
  required int offset,
  required List<T> items,
  required int totalCount,
  PagedScrollPositionRestorer<T>? restorer,
  ScrollController? scrollController,
}) {
  final hasMore = items.isNotEmpty && offset + items.length < totalCount;
  if (hasMore) {
    controller.appendPage(items, offset + items.length);
  } else {
    controller.appendLastPage(items);
  }
  if (restorer != null && scrollController != null) {
    restorer.restoreAfterPage(scrollController);
  }
  return hasMore;
}

typedef PagedListPageLoader<T> =
    Future<PagedResult<T>> Function(int limit, int offset);

/// 在保留当前列表的前提下，后台刷新已加载的数据。
///
/// [PagingController.refresh] 会先清空 [itemList] 并显示首屏加载状态，适合
/// 用户主动下拉刷新，但不适合从详情页返回这种需要保持内容连续的场景。
/// 服务端可能限制单次返回数量，因此按实际返回条数补齐已加载范围，
/// 全部成功后一次性替换列表和分页游标，避免中间的短列表改变滚动位置。
Future<bool> refreshPagedListInBackground<T>({
  required PagingController<int, T> controller,
  required PagedListPageLoader<T> loadPage,
  PagedRequestCoordinator? requests,
  void Function(PagedResult<T> page)? onApplied,
}) async {
  final currentItems = controller.itemList;
  if (currentItems == null || currentItems.isEmpty) return false;

  requests?.invalidate();
  final request = requests?.begin(#backgroundRefresh);
  if (requests != null && request == null) return false;

  try {
    final items = <T>[];
    late PagedResult<T> page;
    do {
      page = await loadPage(currentItems.length - items.length, items.length);
      if (request != null && !request.isCurrent) return false;

      // 主动刷新、筛选和翻页可能改变当前列表；每页完成后都检查，
      // 过期请求既不能提交，也不应继续补页。
      if (!identical(controller.itemList, currentItems)) return false;
      items.addAll(page.items);
    } while (items.length < currentItems.length &&
        page.hasMore &&
        page.items.isNotEmpty);

    controller.value = PagingState(
      itemList: items,
      nextPageKey: page.hasMore && page.items.isNotEmpty ? items.length : null,
    );
    onApplied?.call(
      PagedResult(
        items: items,
        totalCount: page.totalCount,
        limit: currentItems.length,
        offset: 0,
      ),
    );
    // 已提交的新快照也使同代次、使用旧偏移量启动的翻页失效。
    requests?.invalidate();
    return true;
  } catch (_) {
    // 静默刷新失败时保留已有内容，由下一次主动刷新或重试处理。
    return false;
  } finally {
    request?.finish();
  }
}
