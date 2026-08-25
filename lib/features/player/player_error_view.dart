import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/platform/app_theme.dart';

String summarizePlayerError(String message, {int maxLength = 220}) {
  final normalized = message.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length <= maxLength) return normalized;
  return '${normalized.substring(0, maxLength).trimRight()}…';
}

class PlayerErrorView extends StatelessWidget {
  const PlayerErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onCopy,
    required this.onExport,
    required this.onExit,
  });

  final String message;
  final VoidCallback onRetry;
  final Future<void> Function() onCopy;
  final Future<void> Function() onExport;
  final VoidCallback onExit;

  Future<void> _showDetails(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        return AlertDialog(
          title: const Text('完整错误详情'),
          content: SizedBox(
            width: size.width > 720 ? 680 : size.width * 0.82,
            height: size.height * 0.58,
            child: Scrollbar(
              child: SingleChildScrollView(
                child: SelectableText(
                  message,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                unawaited(onCopy());
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('复制'),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                unawaited(onExport());
              },
              icon: const Icon(Icons.ios_share, size: 18),
              label: const Text('导出'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final summary = summarizePlayerError(message);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.danger.withValues(alpha: 0.55)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: colors.danger, size: 34),
                  const SizedBox(height: 8),
                  const Text(
                    '播放失败',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      summary,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('重试'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => unawaited(_showDetails(context)),
                        icon: const Icon(Icons.article_outlined, size: 16),
                        label: const Text('查看详情'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => unawaited(onCopy()),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('复制完整错误'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => unawaited(onExport()),
                        icon: const Icon(Icons.ios_share, size: 16),
                        label: const Text('导出错误'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: onExit,
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('退出播放'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
