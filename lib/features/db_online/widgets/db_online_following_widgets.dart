import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/shared/filter_chip.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/shared/page_header.dart';

/// 关注相关页面沿用订阅管理的固定页头和共享页面布局。
class DbOnlineFollowingLayout extends StatelessWidget {
  const DbOnlineFollowingLayout({
    super.key,
    required this.title,
    required this.body,
    this.eyebrow = 'DB ONLINE',
    this.actions = const [],
    this.alignTrailingToPadding = false,
    this.filters,
    this.scrollController,
  });

  final String title;
  final String eyebrow;
  final Widget body;
  final List<Widget> actions;

  /// actions 末尾是圆形操作按钮时传 true，可见圆右缘对齐水平边距
  /// （透传给 [PageHeader.alignTrailingToPadding]）。
  final bool alignTrailingToPadding;

  final Widget? filters;
  final ScrollController? scrollController;

  /// 窄屏上标题至少保留的宽度。
  static const _minTitleWidth = 64.0;

  /// 操作区保持自然尺寸；只有在窄屏放不下时整体缩小，避免页头溢出。
  Widget _trailing(double headerWidth) {
    final maxWidth =
        headerWidth -
        PageHeader.horizontalPadding * 2 -
        PageHeader.leadingWidth -
        PageHeader.trailingGap -
        _minTitleWidth;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: math.max(0, maxWidth)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(mainAxisSize: MainAxisSize.min, children: actions),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: appColors(context).bg,
    body: GlowBackground(
      child: SafeArea(
        bottom: false,
        child: SettingsFixedHeaderLayout(
          scrollController: scrollController,
          header: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) => SettingsSubPageHeader(
                  eyebrow: eyebrow,
                  title: title,
                  trailing: actions.isEmpty
                      ? null
                      : _trailing(constraints.maxWidth),
                  alignTrailingToPadding: alignTrailingToPadding,
                  // 下一块是工具栏用块间距，列表直接跟随时用列表间距，
                  // 组件增减不改变主列表与上一块的间距。
                  bottomPadding: filters == null
                      ? PageHeader.aboveListGap
                      : PageHeader.toolbarTopGap,
                ),
              ),
              // 工具栏的水平和底部间距由布局统一施加，页面无需自带 padding。
              if (filters != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    PageHeader.horizontalPadding,
                    0,
                    PageHeader.horizontalPadding,
                    PageHeader.aboveListGap,
                  ),
                  child: filters,
                ),
            ],
          ),
          body: body,
        ),
      ),
    ),
  );
}

class DbOnlineFollowingButtonRow extends StatelessWidget {
  const DbOnlineFollowingButtonRow({
    super.key,
    required this.options,
    required this.isSelected,
    required this.onSelected,
  });
  final List<({String value, String label})> options;
  final bool Function(String) isSelected;
  final ValueChanged<String> onSelected;

  String? get _scrollTargetValue {
    for (final option in options) {
      if (isSelected(option.value)) return option.value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scrollTargetValue = _scrollTargetValue;
    return SelectedHorizontalScrollView(
      selectedValue: scrollTargetValue,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
      childBuilder: (context, selectedItemKey) => Row(
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: CompactFilterButton(
                key: option.value == scrollTargetValue ? selectedItemKey : null,
                label: option.label,
                active: isSelected(option.value),
                onTap: () => onSelected(option.value),
              ),
            ),
        ],
      ),
    );
  }
}

String formatDbOnlineFollowingDate(String value) {
  final date = DateTime.tryParse(value.replaceAll('/', '-'));
  return date == null
      ? ''
      : DateFormat('yyyy-MM-dd HH:mm').format(date.toLocal());
}
