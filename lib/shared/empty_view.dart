import 'package:flutter/material.dart';

import '../core/ui/tokens.dart';

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, this.message = '暂无数据'});
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: c.textMuted),
            const SizedBox(height: AppSpacing.m),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: c.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
