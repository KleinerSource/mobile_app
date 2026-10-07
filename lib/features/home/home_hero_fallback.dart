import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/localized_error_message.dart';

class HomeHeroFallback<T> extends StatelessWidget {
  const HomeHeroFallback({
    super.key,
    required this.value,
    required this.height,
    required this.onRetry,
    required this.retryLabel,
    required this.emptyMessage,
  });

  final AsyncValue<List<T>> value;
  final double height;
  final VoidCallback onRetry;
  final String retryLabel;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return SizedBox(
      height: height,
      child: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    localizedErrorMessage(AppL10n.of(context), error),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.muted),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: onRetry, child: Text(retryLabel)),
              ],
            ),
          ),
        ),
        data: (items) => items.isEmpty
            ? Center(
                child: Text(
                  emptyMessage,
                  style: TextStyle(color: colors.muted),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
