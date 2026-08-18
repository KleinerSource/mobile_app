import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';
import '../movie_detail/cover_badges.dart';
import '../i18n/poster_badge_visibility_provider.dart';
import 'settings_common.dart';

/// 影片详情页海报技术角标显示设置。
class PosterBadgeDisplayPage extends ConsumerWidget {
  const PosterBadgeDisplayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibility = ref.watch(posterBadgeVisibilityProvider);

    return Scaffold(
      backgroundColor: appColors(context).bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            header: const SettingsSubPageHeader(
              eyebrow: '应用设置',
              title: '海报角标显示',
              subtitle: '控制影片详情海报上显示的技术信息',
            ),
            body: ListView(
              primary: true,
              padding: EdgeInsets.zero,
              children: [
                _PosterBadgePreview(visibility: visibility),
                SettingsGroup(
                  title: '影片详情海报',
                  items: [
                    for (final kind in PosterBadgeKind.values)
                      _PosterBadgeVisibilityTile(
                        kind: kind,
                        enabled: visibility.isEnabled(kind),
                        onChanged: (value) => ref
                            .read(posterBadgeVisibilityProvider.notifier)
                            .setEnabled(kind, value),
                      ),
                  ],
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PosterBadgePreview extends StatelessWidget {
  const _PosterBadgePreview({required this.visibility});

  static const _previewBadges = [
    CoverBadgeSpec(
      PosterBadgeKind.codec,
      'HEVC',
      Color(0xFF059669),
      '视频编码: HEVC',
    ),
    CoverBadgeSpec(
      PosterBadgeKind.hdr,
      'HDR10',
      Color(0xFFEA580C),
      '动态范围: HDR10 (PQ)',
    ),
    CoverBadgeSpec(
      PosterBadgeKind.strm,
      'STRM',
      Color(0xFF475569),
      'STRM 视频文件',
    ),
    CoverBadgeSpec(
      PosterBadgeKind.subtitle,
      '字幕',
      Color(0xFFCA8A04),
      '内嵌字幕',
    ),
    CoverBadgeSpec(
      PosterBadgeKind.crack,
      '破解',
      Color(0xFFDB2777),
      '破解/无码',
    ),
    CoverBadgeSpec(
      PosterBadgeKind.resolution,
      'HD',
      Color(0xFF0891B2),
      '720p 及以上',
    ),
  ];

  final PosterBadgeVisibility visibility;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final badges = _previewBadges
        .where((badge) => visibility.isEnabled(badge.kind))
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.cardBorder),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('预览', style: AppText.eyebrow(context)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            c.surfaceAlt,
                            c.accent.withValues(alpha: 0.28),
                            c.bg,
                          ],
                        ),
                      ),
                    ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black12,
                              Colors.black87,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ABC-123  示例影片',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (badges.isEmpty)
                            Text(
                              '已隐藏所有技术角标',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 11,
                              ),
                            )
                          else
                            CoverBadgeRow(badges: badges),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '开关会实时更新预览和影片详情页海报。',
              style: AppText.meta(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _PosterBadgeVisibilityTile extends StatelessWidget {
  const _PosterBadgeVisibilityTile({
    required this.kind,
    required this.enabled,
    required this.onChanged,
  });

  final PosterBadgeKind kind;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  IconData get _icon {
    return switch (kind) {
      PosterBadgeKind.codec => Icons.memory_outlined,
      PosterBadgeKind.hdr => Icons.hdr_on,
      PosterBadgeKind.strm => Icons.link_outlined,
      PosterBadgeKind.subtitle => Icons.closed_caption_outlined,
      PosterBadgeKind.crack => Icons.lock_open_outlined,
      PosterBadgeKind.resolution => Icons.high_quality_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      key: ValueKey('poster-badge-${kind.name}'),
      title: kind.label,
      subtitle: enabled ? '显示' : '已隐藏',
      leadingIcon: _icon,
      trailing: SettingsSwitch(value: enabled, onChanged: onChanged),
    );
  }
}
