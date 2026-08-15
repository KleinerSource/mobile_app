import 'dart:async';

import 'package:flutter/material.dart';

/// 保持现有 ScaffoldMessenger 调用方式不变，但把 SnackBar 显示在顶部。
///
/// ScaffoldMessengerState 没有悬浮顶部 SnackBar 布局选项，因此通知使用
/// MaterialBanner 外观并放入应用根 Overlay，避免参与 Scaffold 布局。
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

  @override
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(
    SnackBar snackBar, {
    AnimationStyle? snackBarAnimationStyle,
  }) {
    final sequence = ++_topNoticeSequence;

    // 清理承载兼容控制器的透明 SnackBar，避免连续通知累积到底部队列。
    super.clearSnackBars();
    final controller = super.showSnackBar(
      _hiddenSnackBar,
      snackBarAnimationStyle: snackBarAnimationStyle,
    );

    _overlayEntry?.remove();
    final overlay = widget.navigatorKey.currentState?.overlay ??
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
          child: _buildBanner(snackBar, sequence),
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
    unawaited(_dismissAfter(snackBar.duration, sequence));
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

  MaterialBanner _buildBanner(SnackBar snackBar, int sequence) {
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

    return MaterialBanner(
      content: Material(
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
      actions: const [SizedBox.shrink()],
      minActionBarHeight: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      dividerColor: Colors.transparent,
      elevation: 0,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      margin: EdgeInsets.zero,
    );
  }

  Future<void> _dismissAfter(Duration duration, int sequence) async {
    await Future<void>.delayed(duration);
    _dismissTopNotice(sequence);
  }

  void _dismissTopNotice(int sequence) {
    if (!mounted || sequence != _topNoticeSequence) return;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }
}
