import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/features/cache/image_cache_manager.dart';

import '../core/api/url_resolver.dart';
import '../core/config/server_config.dart';
import '../core/config/server_config_provider.dart';
import '../core/platform/app_theme.dart';

/// 构造演员头像地址。头像接口公开提供，不需要把 access token 放入 URL。
/// [index] 选择 avatar_path 数组中的第几张(默认第一张),供封面轮播使用。
String actorAvatarUrl(
  ServerConfig config,
  int actorId, {
  String? cacheBust,
  int index = 0,
}) {
  final url = resolveApiUrl(config, '/actors/$actorId/avatar');
  final uri = Uri.parse(url);
  final extra = <String, String>{
    if (index > 0) 'index': '$index',
    if ((cacheBust?.trim() ?? '').isNotEmpty) 'v': cacheBust!.trim(),
  };
  if (extra.isEmpty) return url;
  return uri
      .replace(queryParameters: {...uri.queryParameters, ...extra})
      .toString();
}

/// 演员头像(列表/卡片等小头像场景)。图片加载失败时自动回退为统一的
/// 渐变首字母占位。[avatarPaths] 为后端返回的 avatar_path 数组;
/// 小头像固定只显示第一张,轮播仅演员详情页的封面负责。
class ActorAvatar extends ConsumerWidget {
  const ActorAvatar({
    super.key,
    required this.actorId,
    required this.name,
    required this.hue,
    required this.size,
    this.avatarPaths,
    this.cacheBust,
  });

  final int actorId;
  final String name;
  final int hue;
  final double size;
  final List<String>? avatarPaths;
  final String? cacheBust;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(serverConfigProvider);
    final imageUrl = config == null
        ? null
        : actorAvatarUrl(config, actorId, cacheBust: cacheBust);
    // null = 字段缺失,仍尝试加载;空数组 = 明确无头像,跳过请求
    final shouldLoadImage = avatarPaths == null || avatarPaths!.isNotEmpty;
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _ActorAvatarPlaceholder(name: name, hue: hue),
            if (imageUrl != null && shouldLoadImage)
              CachedNetworkImage(
                cacheManager: AppImageCacheManager.instance,
                key: ValueKey(imageUrl),
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 180),
                placeholder: (_, __) => const SizedBox.shrink(),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActorAvatarPlaceholder extends StatelessWidget {
  const _ActorAvatarPlaceholder({required this.name, required this.hue});

  final String name;
  final int hue;

  @override
  Widget build(BuildContext context) {
    final value = name.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppHues.top(hue), AppHues.bottom(hue)],
        ),
      ),
      child: Center(
        child: Text(
          value.isEmpty ? '·' : value.characters.first,
          maxLines: 1,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}
