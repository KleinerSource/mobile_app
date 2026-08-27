import 'package:flutter/material.dart';

import '../../shared/glass.dart';
import '../../shared/sheet_controls.dart';

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
  IconData icon = Icons.tune_rounded,
}) {
  return showGlassSheet<T>(
    context: context,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeader(
          icon: icon,
          title: title,
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
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
