import 'package:flutter/material.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

import 'actor_avatar.dart';
import 'movie_detail_scaffold.dart';

/// 详情页演员条目。头像地址、角色和点击行为由来源页面提供。
class CastEntry {
  const CastEntry({
    required this.name,
    this.role,
    this.imageUrl,
    this.imageHeaders,
    this.onTap,
  });

  final String name;
  final String? role;
  final String? imageUrl;
  final Map<String, String>? imageHeaders;
  final VoidCallback? onTap;
}

/// 详情页演员横滑区，OMM、DBO、Emby/Jellyfin、FNOS 和 Stash 共用。
class CastSection extends StatelessWidget {
  const CastSection({super.key, required this.entries, this.title});

  final List<CastEntry> entries;
  final String? title;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final hasRole = entries.any(
      (entry) => (entry.role ?? '').trim().isNotEmpty,
    );
    return MovieDetailFullBleedSection(
      header: Text(
        title ?? AppL10n.of(context).detailCast,
        style: AppText.sectionTitle(context),
      ),
      child: SizedBox(
        height: hasRole ? 150 : 132,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
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
          name.isEmpty ? AppL10n.of(context).commonUnknown : name,
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
