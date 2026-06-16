import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'platform_utils.dart';

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
  if (isCupertino(context)) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(title),
        actions: actions
            .map((a) => CupertinoActionSheetAction(
                  onPressed: () => Navigator.of(ctx).pop(a.value),
                  isDestructiveAction: a.destructive,
                  child: Text(a.label),
                ))
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
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
    ),
  );
}
