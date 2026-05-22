import 'package:flutter/material.dart';
import 'tokens.dart';

class AppChipRow extends StatelessWidget {
  const AppChipRow({
    super.key,
    required this.labels,
    required this.activeIndex,
    required this.onTap,
  });

  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s),
        itemBuilder: (_, i) {
          final active = i == activeIndex;
          return InkWell(
            onTap: () => onTap(i),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: active ? c.brand : c.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active ? c.brandOn : c.text,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
