import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/shared/filter_chip.dart';
import 'package:omm/shared/glow_background.dart';

/// 关注相关页面沿用订阅管理的固定页头和共享页面布局。
class DbOnlineFollowingLayout extends StatelessWidget {
  const DbOnlineFollowingLayout({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.filters,
    this.scrollController,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? filters;
  final ScrollController? scrollController;

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
              SettingsSubPageHeader(
                eyebrow: 'DB ONLINE',
                title: title,
                trailing: actions.isEmpty
                    ? null
                    : Row(mainAxisSize: MainAxisSize.min, children: actions),
              ),
              if (filters != null) filters!,
            ],
          ),
          body: body,
        ),
      ),
    ),
  );
}

class DbOnlineFollowingActionIcon extends StatelessWidget {
  const DbOnlineFollowingActionIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.busy = false,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: busy ? null : onPressed,
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.surface,
          border: Border.all(color: colors.cardBorder),
        ),
        child: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: 18, color: colors.text),
      ),
    );
  }
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

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
    child: Row(
      children: [
        for (final option in options)
          Padding(
            padding: const EdgeInsets.only(right: 7),
            child: CompactFilterButton(
              label: option.label,
              active: isSelected(option.value),
              onTap: () => onSelected(option.value),
            ),
          ),
      ],
    ),
  );
}

String formatDbOnlineFollowingDate(String value) {
  final date = DateTime.tryParse(value.replaceAll('/', '-'));
  return date == null
      ? ''
      : DateFormat('yyyy-MM-dd HH:mm').format(date.toLocal());
}
