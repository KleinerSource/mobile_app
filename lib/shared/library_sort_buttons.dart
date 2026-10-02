import 'package:flutter/material.dart';

import '../core/platform/app_theme.dart';

class LibrarySortButton extends StatelessWidget {
  const LibrarySortButton({
    super.key,
    required this.ascending,
    required this.onTap,
  });

  final bool ascending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colors.chipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort_rounded, size: 15, color: colors.muted),
            const SizedBox(width: 5),
            Icon(
              ascending
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 12,
              color: colors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class LibraryOrderButton extends StatelessWidget {
  const LibraryOrderButton({
    super.key,
    required this.label,
    required this.ascending,
    required this.onTap,
  });

  final String label;
  final bool ascending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colors.chipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ascending
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 14,
              color: colors.accent,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: colors.accent,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
