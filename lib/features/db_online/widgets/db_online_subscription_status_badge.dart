import 'package:flutter/material.dart';

import 'package:omm/l10n/generated/app_localizations.dart';

/// 订阅状态的文案/颜色/图标三件套：封面角标与详情操作按钮共用，
/// 保证两处视觉语义一致（订阅中黄、已完成绿、已跳过红、超期橙；
/// 未订阅无状态色，由调用方走中性样式）。
({String label, Color? color, IconData icon}) dbOnlineSubscriptionStatusStyle(
  AppL10n l, {
  required bool subscribed,
  required String status,
  required bool overdue,
}) {
  if (!subscribed) {
    return (
      label: l.dbOnlineSubscriptionAdd,
      color: null,
      icon: Icons.add_circle_outline,
    );
  }
  if (overdue) {
    return (
      label: l.dbOnlineSubscriptionOverdue,
      color: const Color(0xFFF97316),
      icon: Icons.schedule_rounded,
    );
  }
  return switch (status) {
    'completed' => (
      label: l.dbOnlineSubscriptionCompleted,
      color: const Color(0xFF22C55E),
      icon: Icons.check_circle_rounded,
    ),
    'skipped' => (
      label: l.dbOnlineSubscriptionSkipped,
      color: const Color(0xFFEF4444),
      icon: Icons.skip_next_rounded,
    ),
    _ => (
      label: l.dbOnlineSubscriptionPendingBadge,
      color: const Color(0xFFEAB308),
      icon: Icons.notifications_active_outlined,
    ),
  };
}

/// 订阅状态角标：与影片卡片上的字幕、破解角标保持一致的图标尺寸。
class DbOnlineSubscriptionStatusBadge extends StatelessWidget {
  const DbOnlineSubscriptionStatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: label,
      child: Tooltip(
        message: label,
        child: Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 13),
        ),
      ),
    );
  }
}
