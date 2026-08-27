import 'package:flutter/material.dart';

import '../../shared/glass.dart';

class AppActionSheetAction<T> {
  const AppActionSheetAction({
    required this.label,
    required this.value,
    this.destructive = false,
  });
  final String label;
  final T value;
  final bool destructive;
}

Future<T?> showAppActionSheet<T>({
  required BuildContext context,
  required String title,
  required List<AppActionSheetAction<T>> actions,
}) {
  return showGlassSheet<T>(
    context: context,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
        ),
        for (final a in actions)
          ListTile(
            title: Text(
              a.label,
              style: TextStyle(
                color: a.destructive ? Theme.of(ctx).colorScheme.error : null,
              ),
            ),
            onTap: () => Navigator.of(ctx).pop(a.value),
          ),
      ],
    ),
  );
}
