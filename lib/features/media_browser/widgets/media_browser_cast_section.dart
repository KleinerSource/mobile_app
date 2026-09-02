import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/cache/image_cache_manager.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/pages/media_browser_library_page.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_detail_scaffold.dart';

/// Emby/Jellyfin/fnos 演员区 · OMM 详情页同款头像风格：
/// 横向滚动的大圆头像（色相发光 + 名字首字渐变兜底）+ 名字与角色。
/// [onOpenPerson] 为 null 时纯展示（fnos 列表接口不支持按人物过滤）。
class MediaBrowserCastSection extends StatelessWidget {
  const MediaBrowserCastSection({
    super.key,
    required this.people,
    required this.urls,
    this.title = '演员',
    this.onOpenPerson,
  });

  final List<MediaBrowserPerson> people;
  final MediaBrowserServerUrls? urls;
  final String title;
  final void Function(MediaBrowserPerson person)? onOpenPerson;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return const SizedBox.shrink();
    return MovieDetailSection(
      title: title,
      child: SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 0),
          separatorBuilder: (_, __) => const SizedBox(width: 16),
          itemCount: people.length,
          itemBuilder: (context, index) {
            final person = people[index];
            final hue = AppHues.all[index % AppHues.all.length];
            return SizedBox(
              width: 80,
              child: _CastTile(
                person: person,
                imageUrl: urls?.personImage(person),
                hue: hue,
                onTap: onOpenPerson == null ? null : () => onOpenPerson!(person),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CastTile extends StatelessWidget {
  const _CastTile({
    required this.person,
    required this.imageUrl,
    required this.hue,
    this.onTap,
  });

  final MediaBrowserPerson person;
  final String? imageUrl;
  final int hue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final role = person.role?.trim() ?? '';
    final tile = Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppHues.top(hue).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _CastAvatar(
            name: person.name,
            imageUrl: imageUrl,
            hue: hue,
            size: 76,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          person.name.trim().isEmpty ? '—' : person.name.trim(),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.text,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
            height: 1.2,
          ),
        ),
        if (role.isNotEmpty)
          Text(
            role,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.muted,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 10,
              height: 1.2,
            ),
          ),
      ],
    );
    if (onTap == null) return tile;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: tile,
    );
  }
}

/// 圆形头像 · OMM ActorAvatar 同款视觉：名字首字渐变兜底 + 网络头像覆盖。
class _CastAvatar extends StatelessWidget {
  const _CastAvatar({
    required this.name,
    required this.imageUrl,
    required this.hue,
    required this.size,
  });

  final String name;
  final String? imageUrl;
  final int hue;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '·' : name.trim().characters.first;
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppHues.top(hue), AppHues.bottom(hue)],
                ),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            if (imageUrl != null && imageUrl!.isNotEmpty)
              CachedNetworkImage(
                cacheManager: AppImageCacheManager.instance,
                key: ValueKey(imageUrl),
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 180),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
          ],
        ),
      ),
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
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MediaBrowserLibraryPage(
        personId: personId,
        personName: personName,
      ),
    ),
  );
}
