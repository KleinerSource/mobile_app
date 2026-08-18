import 'dart:async';

import 'package:flutter/material.dart';

/// 保持现有 ScaffoldMessenger 调用方式不变，但把 SnackBar 显示在顶部。
///
/// ScaffoldMessengerState 没有悬浮顶部 SnackBar 布局选项，因此通知使用
/// 独立的顶部 Material 卡片并放入应用根 Overlay，避免参与 Scaffold 布局。
/// 底部仅放置一个透明的短生命周期 SnackBar，保证既有调用方拿到的
/// 控制器类型和关闭语义仍然有效。
class TopSnackBarMessenger extends ScaffoldMessenger {
  const TopSnackBarMessenger({
    super.key,
    required super.child,
    required this.navigatorKey,
  });

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  TopSnackBarMessengerState createState() => TopSnackBarMessengerState();
}

class TopSnackBarMessengerState extends ScaffoldMessengerState {
  int _topNoticeSequence = 0;
  OverlayEntry? _overlayEntry;
  Timer? _topNoticeDismissTimer;

  @override
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(
    SnackBar snackBar, {
    AnimationStyle? snackBarAnimationStyle,
  }) {
    final sequence = ++_topNoticeSequence;

    // 清理承载兼容控制器的透明 SnackBar，避免连续通知累积到底部队列。
    super.clearSnackBars();
    _topNoticeDismissTimer?.cancel();
    _topNoticeDismissTimer = null;
    final controller = super.showSnackBar(
      _hiddenSnackBar,
      snackBarAnimationStyle: snackBarAnimationStyle,
    );

    _overlayEntry?.remove();
    final messenger = widget as TopSnackBarMessenger;
    final overlay = messenger.navigatorKey.currentState?.overlay ??
        Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return controller;
    }
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: _TopNoticeDismissible(
                      onDismiss: () => _dismissTopNotice(sequence),
                      child: _buildBanner(snackBar, sequence),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _overlayEntry = entry;
    overlay.insert(entry);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && sequence == _topNoticeSequence) {
        snackBar.onVisible?.call();
      }
    });
    _topNoticeDismissTimer = Timer(
      snackBar.duration,
      () => _dismissTopNotice(sequence),
    );
    return controller;
  }

  static const SnackBar _hiddenSnackBar = SnackBar(
    content: SizedBox.shrink(),
    duration: Duration(milliseconds: 1),
    padding: EdgeInsets.zero,
    backgroundColor: Colors.transparent,
    elevation: 0,
    behavior: SnackBarBehavior.floating,
  );

  Widget _buildBanner(SnackBar snackBar, int sequence) {
    final theme = Theme.of(context);
    final snackBarTheme = SnackBarTheme.of(context);
    final action = snackBar.action;
    final backgroundColor = snackBar.backgroundColor ??
        snackBarTheme.backgroundColor ??
        theme.colorScheme.inverseSurface;
    final contentTextStyle =
        snackBarTheme.contentTextStyle ?? theme.textTheme.bodyMedium!;
    final actionColor = action?.textColor ??
        snackBarTheme.actionTextColor ??
        theme.colorScheme.primary;

    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        key: const ValueKey<String>('top-notice-card'),
        color: backgroundColor,
        elevation: snackBar.elevation ?? snackBarTheme.elevation ?? 6,
        shape: snackBar.shape ??
            snackBarTheme.shape ??
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: snackBar.padding ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: DefaultTextStyle(
                  style: contentTextStyle,
                  child: snackBar.content,
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    action.onPressed();
                    _dismissTopNotice(sequence);
                  },
                  style: TextButton.styleFrom(foregroundColor: actionColor),
                  child: Text(action.label),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _dismissTopNotice(int sequence) {
    if (!mounted || sequence != _topNoticeSequence) return;
    _topNoticeDismissTimer?.cancel();
    _topNoticeDismissTimer = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _topNoticeDismissTimer?.cancel();
    _topNoticeDismissTimer = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }
}

class _TopNoticeDismissible extends StatefulWidget {
  const _TopNoticeDismissible({required this.onDismiss, required this.child});

  final VoidCallback onDismiss;
  final Widget child;

  @override
  State<_TopNoticeDismissible> createState() => _TopNoticeDismissibleState();
}

class _TopNoticeDismissibleState extends State<_TopNoticeDismissible> {
  static const _swipeDistance = 24.0;
  static const _swipeVelocity = -150.0;

  double _upwardDragDistance = 0;

  void _resetDrag() {
    _upwardDragDistance = 0;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta;
    if (delta != null && delta < 0) {
      _upwardDragDistance += -delta;
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_upwardDragDistance >= _swipeDistance || velocity <= _swipeVelocity) {
      widget.onDismiss();
    }
    _resetDrag();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onDismiss,
      onVerticalDragStart: (_) => _resetDrag(),
      onVerticalDragUpdate: _handleDragUpdate,
      onVerticalDragEnd: _handleDragEnd,
      onVerticalDragCancel: _resetDrag,
      child: widget.child,
    );
  }
}
