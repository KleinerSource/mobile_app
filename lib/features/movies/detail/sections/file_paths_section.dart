import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/movie.dart';
import '../../../../core/ui/tokens.dart';

class FilePathsSection extends StatelessWidget {
  const FilePathsSection({super.key, required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final items = <_Entry>[];
    if (movie.relatedFiles.isNotEmpty) {
      for (final rf in movie.relatedFiles) {
        items.add(_Entry(label: rf.label ?? rf.type ?? '文件', path: rf.path));
      }
    } else if (movie.filePath != null && movie.filePath!.isNotEmpty) {
      items.add(_Entry(label: '影片文件', path: movie.filePath!));
    }
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '文件',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: c.text),
          ),
          const SizedBox(height: AppSpacing.s),
          ...items.map((e) => _PathTile(entry: e, c: c)),
          const SizedBox(height: AppSpacing.l),
        ],
      ),
    );
  }
}

class _Entry {
  const _Entry({required this.label, required this.path});
  final String label;
  final String path;
}

class _PathTile extends StatelessWidget {
  const _PathTile({required this.entry, required this.c});
  final _Entry entry;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: () async {
        await Clipboard.setData(ClipboardData(text: entry.path));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已复制：${entry.path}')),
        );
      },
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: c.textMuted),
            ),
            const SizedBox(height: 2),
            Text(
              entry.path,
              style: TextStyle(
                fontSize: 12,
                color: c.text,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
