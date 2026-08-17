import 'package:flutter/widgets.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

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
