import 'package:flutter/material.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/db_online/repositories/dbo_media_repository.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'package:omm/shared/sheet_controls.dart';

typedef DbOnlineDownloader = ({
  String name,
  String displayName,
  bool? ed2kEnabled,
});

/// 详情与关注资源共用下载器选择、协议限制和下载记录写入。
Future<bool> pushDbOnlineResource({
  required BuildContext context,
  required DboMediaRepository repository,
  required List<DbOnlineDownloader> downloaders,
  required Map<String, dynamic> videoInfo,
  required String url,
  required String protocol,
  required String name,
  required List<String> tags,
  required bool Function() isCurrent,
  required ValueChanged<bool> onPushing,
  String? site,
  String? date,
  Map<String, dynamic>? recordResource,
  Map<String, int> downloaderQuotas = const {},
  String Function(String downloader)? successMessage,
  VoidCallback? onSubmitted,
}) async {
  if (url.trim().isEmpty || !isCurrent()) return false;
  final l = AppL10n.of(context);
  final available = downloaders
      .where(
        (downloader) => protocol != 'ed2k' || downloader.ed2kEnabled == true,
      )
      .toList();
  if (available.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l.resourceNoDownloaders)));
    return false;
  }
  onPushing(true);
  try {
    final selected = available.length == 1
        ? available.single.name
        : await showGlassSheet<String>(
            context: context,
            builder: (context) => SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SheetHeader(
                    icon: Icons.download_outlined,
                    title: l.resourceSelectDownloader,
                  ),
                  for (final downloader in available)
                    ListTile(
                      leading: const Icon(Icons.download_outlined, size: 20),
                      title: Text(downloader.displayName),
                      trailing: downloaderQuotas[downloader.name] == null
                          ? null
                          : Tooltip(
                              message: l.dbOnlineDownloadRecordsQuota,
                              child: Text(
                                downloaderQuotas[downloader.name].toString(),
                                style: AppText.mono(
                                  context,
                                  color:
                                      downloaderQuotas[downloader.name]! <= 49
                                      ? const Color(0xFFEF4444)
                                      : appColors(context).accent,
                                ),
                              ),
                            ),
                      onTap: () => Navigator.pop(context, downloader.name),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
    if (selected == null || !context.mounted || !isCurrent()) return false;
    onSubmitted?.call();
    final result = await repository.pushDownload(
      urls: [url],
      downloader: selected,
      videoInfo: videoInfo,
      recordResources: [
        recordResource ??
            {
              'url': url,
              'name': name,
              'resource_protocol': protocol,
              'resource_site': site ?? '',
              'resource_flags': _resourceFlags(tags),
              'resource_date': date ?? '',
              'video_code': videoInfo['code'] ?? '',
              'video_title': videoInfo['title'] ?? '',
            },
      ],
    );
    if (!context.mounted || !isCurrent()) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          successMessage?.call(result.downloader) ??
              (result.message.isEmpty
                  ? l.resourcePushDownload
                  : result.message),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    return true;
  } catch (error) {
    if (context.mounted && isCurrent()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.resourcePushFailed(localizedErrorMessage(l, error))),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    return false;
  } finally {
    if (isCurrent()) onPushing(false);
  }
}

int _resourceFlags(List<String> tags) {
  final lowered = tags.map((tag) => tag.toLowerCase()).toList();
  var flags = lowered.any((tag) => tag == 'uhd' || tag.contains('4k'))
      ? 4
      : lowered.any(
          (tag) =>
              (tag.contains('hd') && !tag.contains('uhd')) ||
              tag.contains('高清'),
        )
      ? 2
      : 1;
  if (lowered.any((tag) => tag.contains('字幕') || tag.contains('sub'))) {
    flags |= 8;
  }
  if (lowered.any((tag) => tag.contains('破解') || tag.contains('无码'))) {
    flags |= 16;
  }
  return flags;
}
