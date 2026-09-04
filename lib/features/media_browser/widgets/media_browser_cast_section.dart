import 'package:flutter/material.dart';

import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/pages/media_browser_library_page.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/oh_my_media/movie_detail/cast_section.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

/// Emby/Jellyfin/Stash/fnos 演员区 · 直接复用 OMM 详情页的 [CastSection],
/// 仅负责把 MediaBrowserPerson 映射成 CastEntry(头像地址按服务器类型
/// 由 [MediaBrowserServerUrls.personImage] 解析)。
/// [onOpenPerson] 为 null 或人物没有 ID 时纯展示（fnos 列表接口不支持按人物过滤）。
class MediaBrowserCastSection extends StatelessWidget {
  const MediaBrowserCastSection({
    super.key,
    required this.people,
    required this.urls,
    this.title,
    this.onOpenPerson,
  });

  final List<MediaBrowserPerson> people;
  final MediaBrowserServerUrls? urls;

  /// 为 null 时使用默认文案「演员」。
  final String? title;
  final void Function(MediaBrowserPerson person)? onOpenPerson;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return const SizedBox.shrink();
    return CastSection(
      title: title ?? AppL10n.of(context).detailCast,
      entries: [
        for (final person in people)
          CastEntry(
            name: person.name,
            role: person.role,
            imageUrl: urls?.personImage(person),
            imageHeaders: urls?.imageHeaders,
            onTap: onOpenPerson == null || person.id.trim().isEmpty
                ? null
                : () => onOpenPerson!(person),
          ),
      ],
    );
  }
}

/// 打开演员作品列表（PersonIds 过滤的电影+剧集网格）。
///
/// 仅 Emby/Jellyfin 服务器可用；fnos 列表接口不支持按人物过滤，调用方
/// 应在 fnos 上不提供点击入口。
Future<void> openMediaBrowserPersonWorks(
  BuildContext context, {
  required String personId,
  required String personName,
}) {
  final id = personId.trim();
  if (id.isEmpty) return Future<void>.value();
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          MediaBrowserLibraryPage(personId: id, personName: personName.trim()),
    ),
  );
}

/// 打开标签作品列表（Stash SceneFilterType.tags 过滤）。
Future<void> openMediaBrowserTagWorks(
  BuildContext context, {
  required String tagId,
  required String tagName,
}) {
  final id = tagId.trim();
  if (id.isEmpty) return Future<void>.value();
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          MediaBrowserLibraryPage(tagId: id, tagName: tagName.trim()),
    ),
  );
}
