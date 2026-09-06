import 'package:flutter/material.dart';

import '../core/platform/app_theme.dart';
import '../l10n/generated/app_localizations.dart';

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, this.message, this.verticalOffset = -48});

  final String? message;
  final double verticalOffset;

  @override
  Widget build(BuildContext context) {
    return CenteredEmptyState(
      verticalOffset: verticalOffset,
      child: Text(
        message ?? AppL10n.of(context).commonNoData,
        textAlign: TextAlign.center,
        style: AppText.body(context).copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// 分页列表的空态容器。
///
/// 列表页通常有固定页头和悬浮底部导航，直接在剩余区域使用 [Center]
/// 会让空态视觉上偏下；统一向内容区上方补偿少量空间。
class CenteredEmptyState extends StatelessWidget {
  const CenteredEmptyState({
    super.key,
    required this.child,
    this.verticalOffset = -48,
  });

  final Widget child;
  final double verticalOffset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: Offset(0, verticalOffset),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: child,
        ),
      ),
    );
  }
}
