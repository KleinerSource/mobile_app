import 'package:flutter/material.dart';
import 'tokens.dart';

class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.icon,
    required this.background,
    this.label,
    this.foreground = Colors.white,
  });

  final IconData icon;
  final String? label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: label == null ? 4 : 5,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.badge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: foreground),
          if (label != null) ...[
            const SizedBox(width: 2),
            Text(
              label!,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: foreground,
                letterSpacing: 0.2,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
