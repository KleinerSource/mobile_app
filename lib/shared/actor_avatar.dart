import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/url_resolver.dart';
import '../core/config/server_config.dart';
import '../core/config/server_config_provider.dart';
import '../core/platform/app_theme.dart';

/// 构造演员头像地址。头像接口公开提供，不需要把 access token 放入 URL。
String actorAvatarUrl(ServerConfig config, int actorId, {String? cacheBust}) {
  final url = resolveApiUrl(config, '/actors/$actorId/avatar');
  final version = cacheBust?.trim() ?? '';
  if (version.isEmpty) return url;
  final uri = Uri.parse(url);
  return uri
      .replace(queryParameters: {...uri.queryParameters, 'v': version})
      .toString();
}

/// 演员头像。图片加载失败时自动回退为统一的渐变首字母占位。
class ActorAvatar extends ConsumerWidget {
  const ActorAvatar({
    super.key,
    required this.actorId,
    required this.name,
    required this.hue,
    required this.size,
    this.avatarPath,
    this.cacheBust,
  });

  final int actorId;
  final String name;
  final int hue;
  final double size;
  final String? avatarPath;
  final String? cacheBust;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(serverConfigProvider);
    final imageUrl = config == null
        ? null
        : actorAvatarUrl(config, actorId, cacheBust: cacheBust);
    final shouldLoadImage =
        avatarPath == null ||
        avatarPath!.trim().isNotEmpty ||
        cacheBust?.trim().isNotEmpty == true;
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
