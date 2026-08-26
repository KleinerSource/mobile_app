import 'package:flutter/material.dart';

import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import 'playback_engine.dart';

/// 屏幕中间的选择播放器弹窗。
///
/// [engineKinds] 会按默认播放器优先排序：设置里选中的内核排在最前，
/// 其余按传入顺序靠后展示，并带「默认」角标。
Future<PlaybackEngineKind?> showPlaybackEnginePicker(
  BuildContext context, {
  required List<PlaybackEngineKind> engineKinds,
  PlaybackEngineKind? defaultEngineKind,
}) {
  final orderedKinds = <PlaybackEngineKind>[
    if (defaultEngineKind != null && engineKinds.contains(defaultEngineKind))
      defaultEngineKind,
    ...engineKinds.where((kind) => kind != defaultEngineKind),
  ];

  return showDialog<PlaybackEngineKind>(
    context: context,
    builder: (dialogContext) {
      final l = AppL10n.of(dialogContext);
      final c = appColors(dialogContext);
      return AlertDialog(
        title: Text(l.playerEnginePickerTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.playerEnginePickerSubtitle,
              style: Theme.of(dialogContext).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            for (final engineKind in orderedKinds)
              ListTile(
                key: ValueKey('player-engine-${engineKind.value}'),
                leading: Icon(switch (engineKind) {
                  PlaybackEngineKind.libmpv => Icons.video_library_outlined,
                  PlaybackEngineKind.ksPlayer => Icons.movie_outlined,
                }),
                title: Text(engineKind.label),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (engineKind == defaultEngineKind)
                      _DefaultBadge(label: l.playerEnginePickerDefaultBadge),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => Navigator.of(dialogContext).pop(engineKind),
              ),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              MaterialLocalizations.of(
                dialogContext,
              ).cancelButtonLabel.toUpperCase(),
              style: TextStyle(color: c.text2),
            ),
          ),
        ],
      );
    },
  );
}

class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: c.accent,
          fontFamily: 'Inter',
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
