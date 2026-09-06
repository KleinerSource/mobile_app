import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../core/platform/app_theme.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry})
    : _list = false,
      retryLabel = null;
  const ErrorView.list({
    super.key,
    required this.message,
    required this.onRetry,
    this.retryLabel,
  }) : _list = true;
  final bool _list;
  final String? retryLabel;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (_list) {
      final colors = appColors(context);
      return Padding(
        padding: const EdgeInsets.fromLTRB(22, 56, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: colors.muted, size: 38),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.muted),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: Text(retryLabel ?? AppL10n.of(context).commonRetry),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: Text(AppL10n.of(context).commonRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
