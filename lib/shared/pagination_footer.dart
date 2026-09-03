import 'package:flutter/material.dart';

import '../core/platform/app_theme.dart';
import '../l10n/generated/app_localizations.dart';

/// 统一的分页列表末尾状态。
class NoMoreContent extends StatelessWidget {
  const NoMoreContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 30),
        child: Center(
          child: Text(
            AppL10n.of(context).paginationNoMore,
            style: AppText.meta(context),
          ),
        ),
      ),
    );
  }
}

/// 统一的分页加载失败重试入口。
class PaginationRetry extends StatelessWidget {
  const PaginationRetry({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: TextButton(
          onPressed: onRetry,
          child: Text(AppL10n.of(context).paginationLoadFailedRetry),
        ),
      ),
    );
  }
}
