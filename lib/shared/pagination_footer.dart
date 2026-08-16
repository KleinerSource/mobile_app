import 'package:flutter/material.dart';

import '../core/platform/app_theme.dart';

/// 统一的分页列表末尾状态。
class NoMoreContent extends StatelessWidget {
  const NoMoreContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
      child: Center(child: Text('没有更多内容', style: AppText.meta(context))),
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
        child: TextButton(onPressed: onRetry, child: const Text('加载更多失败，点击重试')),
      ),
    );
  }
}
