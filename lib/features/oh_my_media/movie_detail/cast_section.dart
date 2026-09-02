import 'package:flutter/material.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/shared/actor_avatar.dart';

import 'movie_detail_scaffold.dart';

/// 详情页演员区条目:头像地址由调用方解析(OMM 按演员 id、
/// Emby/Jellyfin/fnos 按服务器 URL 规则),为空时显示渐变首字占位。
class CastEntry {
  const CastEntry({
    required this.name,
    this.role,
    this.imageUrl,
    this.imageHeaders,
    this.onTap,
  });

  final String name;

  /// 角色/职务,如「饰 XXX」;空则不渲染角色行。
  final String? role;
  final String? imageUrl;
  final Map<String, String>? imageHeaders;
  final VoidCallback? onTap;
}

/// 详情页「演员」横滑区 · OMM / Emby / Jellyfin / fnos 共用同一实现:
/// 横向滚动的大圆头像(色相发光 + 名字首字渐变兜底)+ 名字与角色。
/// 有任一条目带角色时预留角色行高度。
class CastSection extends StatelessWidget {
  const CastSection({
    super.key,
    required this.entries,
    this.title = '演员',
  });

  final List<CastEntry> entries;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final hasRole = entries.any(
      (entry) => (entry.role ?? '').trim().isNotEmpty,
    );
    return MovieDetailSection(
      title: title,
      child: SizedBox(
        height: hasRole ? 150 : 132,
        // 不用 ListView：虚拟化会回收滚动出缓存区的头像，回滚重建时
        // 重放图片淡入，表现为靠边缘的头像突然消失。详情页演员行只有
        // 几十个轻量头像，整行常驻（Row + SingleChildScrollView）没有
        // 回收，滚动不再闪变。
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          // 顶部预留泛光渐隐空间,避免 BoxShadow 上溢被视口硬切
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                SizedBox(
                  width: 80,
                  child: _CastTile(
                    entry: entries[i],
                    hue: AppHues.all[i % AppHues.all.length],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CastTile extends StatelessWidget {
  const _CastTile({required this.entry, required this.hue});

  final CastEntry entry;
  final int hue;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final name = entry.name.trim();
    final role = entry.role?.trim() ?? '';
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
          child: CircularInitialsAvatar(
            name: entry.name,
            hue: hue,
            size: 76,
            imageUrl: entry.imageUrl,
            httpHeaders: entry.imageHeaders,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name.isEmpty ? '—' : name,
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
    if (entry.onTap == null) return tile;
    return InkWell(
      onTap: entry.onTap,
      borderRadius: BorderRadius.circular(12),
      child: tile,
    );
  }
}
