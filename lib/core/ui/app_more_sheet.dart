import 'package:flutter/material.dart';
import 'tokens.dart';

class _MoreEntry {
  const _MoreEntry(this.icon, this.label);
  final IconData icon;
  final String label;
}

const _entries = <_MoreEntry>[
  _MoreEntry(Icons.collections_bookmark_outlined, '媒体库'),
  _MoreEntry(Icons.label_outline, '标签管理'),
  _MoreEntry(Icons.category_outlined, '分类管理'),
  _MoreEntry(Icons.video_library_outlined, '系列管理'),
  _MoreEntry(Icons.people_outline, '演员管理'),
  _MoreEntry(Icons.link, '演员关联'),
];

Future<void> showAppMoreSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final c = Theme.of(ctx).extension<AppColors>()!;
      return Container(
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(top: BorderSide(color: c.divider, width: 1)),
        ),
        padding: EdgeInsets.only(
          top: AppSpacing.l,
          left: AppSpacing.l,
          right: AppSpacing.l,
          bottom: MediaQuery.of(ctx).viewPadding.bottom + AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '更多页面',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: AppSpacing.s,
              crossAxisSpacing: AppSpacing.s,
              childAspectRatio: 1.0,
              children: _entries
                  .map((e) => _MoreCell(entry: e, c: c))
                  .toList(),
            ),
          ],
        ),
      );
    },
  );
}

class _MoreCell extends StatelessWidget {
  const _MoreCell({required this.entry, required this.c});
  final _MoreEntry entry;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${entry.label} 待实现')),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(entry.icon, size: 22, color: c.text),
            const SizedBox(height: 8),
            Text(
              entry.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
