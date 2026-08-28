import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/sheet_controls.dart';
import 'lists_providers.dart';

/// 弹出底部 sheet 让用户把 movieId 加入/移出 多个 list
/// (复选模式 · 每个 list 独立 checkbox)
class AddToListSheet extends ConsumerStatefulWidget {
  const AddToListSheet({
    super.key,
    required this.movieId,
    required this.movieTitle,
  });

  final int movieId;
  final String movieTitle;

  static Future<void> show(
    BuildContext context, {
    required int movieId,
    required String movieTitle,
  }) {
    return showGlassSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddToListSheet(movieId: movieId, movieTitle: movieTitle),
    );
  }

  @override
  ConsumerState<AddToListSheet> createState() => _AddToListSheetState();
}

class _AddToListSheetState extends ConsumerState<AddToListSheet> {
  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final lists = ref.watch(listsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetHeader(
              icon: Icons.playlist_add_outlined,
              title: '加入集合',
              subtitle: widget.movieTitle,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 14),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: lists.length,
                itemBuilder: (ctx, i) {
                  final l = lists[i];
                  final inList = l.movieIds.contains(widget.movieId);
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      if (inList) {
                        await ref
                            .read(listsProvider.notifier)
                            .removeMovie(l.id, widget.movieId);
                      } else {
                        await ref
                            .read(listsProvider.notifier)
                            .addMovie(l.id, widget.movieId);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppHues.top(l.hue),
                                  AppHues.bottom(l.hue),
                                ],
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                '◇',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      l.name,
                                      style: TextStyle(
                                        color: c.text,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                    if (l.locked) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: c.warning.withValues(
                                            alpha: 0.18,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'PIN',
                                          style: TextStyle(
                                            color: c.warning,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.w800,
                                            fontSize: 8,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${l.movieIds.length} 部',
                                  style: AppText.meta(context),
                                ),
                              ],
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: inList ? c.accent : Colors.transparent,
                              border: Border.all(
                                color: inList ? c.accent : c.muted2,
                                width: 1.6,
                              ),
                            ),
                            child: inList
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: c.chipBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(Icons.add, color: c.accent),
                title: Text(
                  '新建集合',
                  style: TextStyle(
                    color: c.accent,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                onTap: () => _createDialog(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createDialog(BuildContext context) async {
    final controller = TextEditingController();
    int selectedHue = AppHues.lavender;

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('新建集合'),
          content: StatefulBuilder(
            builder: (sctx, setSt) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: sheetInputDecoration(
                    ctx,
                    hintText: '集合名称',
                    prefixIcon: const Icon(Icons.label_outline),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  children: AppHues.all.map((hue) {
                    final on = hue == selectedHue;
                    return GestureDetector(
                      onTap: () => setSt(() => selectedHue = hue),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [AppHues.top(hue), AppHues.bottom(hue)],
                          ),
                          border: Border.all(
                            color: on ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: on
                              ? [
                                  BoxShadow(
                                    color: AppHues.top(
                                      hue,
                                    ).withValues(alpha: 0.4),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('创建'),
            ),
          ],
        );
      },
    );

    if (name != null && name.isNotEmpty) {
      final created = await ref
          .read(listsProvider.notifier)
          .create(name: name, hue: selectedHue);
      if (created != null) {
        await ref
            .read(listsProvider.notifier)
            .addMovie(created.id, widget.movieId);
      }
    }
  }
}
