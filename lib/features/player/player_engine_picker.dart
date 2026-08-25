import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import 'playback_engine.dart';

Future<PlaybackEngineKind?> showPlaybackEnginePicker(
  BuildContext context, {
  required List<PlaybackEngineKind> engineKinds,
}) {
  return showModalBottomSheet<PlaybackEngineKind>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final l = AppL10n.of(sheetContext);
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.playerEnginePickerTitle,
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              l.playerEnginePickerSubtitle,
              style: Theme.of(sheetContext).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            for (final engineKind in engineKinds)
              ListTile(
                key: ValueKey('player-engine-${engineKind.value}'),
                leading: Icon(switch (engineKind) {
                  PlaybackEngineKind.libmpv => Icons.video_library_outlined,
                  PlaybackEngineKind.ksPlayer => Icons.movie_outlined,
                }),
                title: Text(engineKind.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(sheetContext).pop(engineKind),
              ),
          ],
        ),
      );
    },
  );
}
