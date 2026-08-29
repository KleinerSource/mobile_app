import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/api/server_compatibility.dart';
import '../core/platform/app_theme.dart';

/// 服务器名首字母(最多 2 个 rune),无名字时退化为 'S'。
String serverInitials(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'S';
  final runes = trimmed.runes.toList();
  if (runes.length == 1) return String.fromCharCode(runes.first);
  return String.fromCharCodes(runes.take(2));
}

/// 服务器头像: 渐变圆底 + 远程头像(首字母兜底) + 白色描边。
///
/// 小尺寸(菜单行 ≤40)用细描边与大号首字母;大尺寸(>60)自动加投影、
/// 更粗的描边并缩小首字母占比。[busy] 时轻微缩放;大尺寸把白色进度环
/// 描在边框上(头像保持清晰),小尺寸叠加半透明遮罩加中心加载指示,
/// 用于切换/登录进行中的服务器选择页。
class ServerAvatar extends StatelessWidget {
  const ServerAvatar({
    super.key,
    required this.displayName,
    required this.avatarUrl,
    required this.size,
    required this.colors,
    this.busy = false,
    this.project,
  });

  final String displayName;
  final String? avatarUrl;
  final double size;
  final AppColors colors;
  final bool busy;
  final ServerProject? project;

  @override
  Widget build(BuildContext context) {
    final isHeroSize = size > 60;
    final sizeProgress = ((size - 104) / 24).clamp(0.0, 1.0).toDouble();
    final borderWidth = isHeroSize
        ? 4 + sizeProgress
        : (size >= 36 ? 2.2 : 2.0);
    final fallbackForeground = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : colors.surface;
    final fallback = Center(
      child: Text(
        serverInitials(displayName),
        style: TextStyle(
          color: fallbackForeground,
          fontSize: size * (isHeroSize ? 0.30 : 0.38),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final face = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.accent.withValues(alpha: 0.95),
            colors.accent.withValues(alpha: 0.52),
          ],
        ),
        boxShadow: isHeroSize
            ? [
                BoxShadow(
                  color: colors.accent.withValues(alpha: 0.2),
                  blurRadius: 20 + (6 * sizeProgress),
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(borderWidth),
        child: ClipOval(
          child: avatarUrl == null || avatarUrl!.isEmpty
              ? fallback
              : CachedNetworkImage(
                  imageUrl: avatarUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => fallback,
                  errorWidget: (_, __, ___) => fallback,
                ),
        ),
      ),
    );
    return AnimatedScale(
      scale: busy ? 0.94 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            face,
            if (busy && !isHeroSize)
              Padding(
                padding: EdgeInsets.all(borderWidth),
                child: ClipOval(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: colors.surface,
                        strokeWidth: 2.5 + (0.3 * sizeProgress),
                      ),
                    ),
                  ),
                ),
              ),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.94),
                    width: borderWidth,
                  ),
                ),
              ),
            ),
            if (project != null)
              Positioned(
                right: 0,
                bottom: 0,
                child: _ServerProjectBadge(project: project!, size: size),
              ),
            if (busy && isHeroSize)
              // 大尺寸时进度环叠在白色边框上，头像保持清晰不变暗。
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  strokeWidth: borderWidth,
                  color: colors.accent,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ServerProjectBadge extends StatelessWidget {
  const _ServerProjectBadge({required this.project, required this.size});

  final ServerProject project;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (label, color, name) = switch (project) {
      ServerProject.ohMyMedia => (
        'OMM',
        const Color(0xFF7C4DFF),
        'Oh-My-Media',
      ),
      ServerProject.dbOnline => ('DBO', const Color(0xFF0E7490), 'dbonline'),
      ServerProject.smb => ('SMB', const Color(0xFF2E7D32), 'SMB'),
      ServerProject.webDav => ('DAV', const Color(0xFF6A1B9A), 'WebDAV'),
      ServerProject.openList => ('OL', const Color(0xFFBF360C), 'OpenList'),
    };
    final height = (size * 0.34).clamp(11.0, 16.0).toDouble();

    return Tooltip(
      message: name,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: size > 60 ? 5 : 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.9),
            width: size > 60 ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: height * 0.58,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.25,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
