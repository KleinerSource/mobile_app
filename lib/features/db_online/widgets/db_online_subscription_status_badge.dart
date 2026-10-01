import 'package:flutter/material.dart';

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
