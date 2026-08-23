import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'platform_utils.dart';

Future<bool?> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = '确定',
  String cancelLabel = '取消',
  bool destructive = false,
}) {
  if (isCupertino(context)) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(true),
            isDestructiveAction: destructive,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}
