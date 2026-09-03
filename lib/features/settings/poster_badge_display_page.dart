import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glow_background.dart';
import 'package:omm/features/oh_my_media/movie_detail/cover_badges.dart';
import '../i18n/poster_badge_visibility_provider.dart';
import 'settings_common.dart';

/// 影片详情页海报技术角标显示设置。
class PosterBadgeDisplayPage extends ConsumerWidget {
  const PosterBadgeDisplayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibility = ref.watch(posterBadgeVisibilityProvider);
    final l = AppL10n.of(context);

    return Scaffold(
      backgroundColor: appColors(context).bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            header: SettingsSubPageHeader(
              eyebrow: l.settingsAppSettings,
              title: l.settingsPosterBadges,
              subtitle: l.posterBadgePageSubtitle,
            ),
            body: ListView(
              primary: true,
              padding: EdgeInsets.zero,
              children: [
                _PosterBadgePreview(visibility: visibility),
                SettingsGroup(
                  title: l.posterBadgeDetailPoster,
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

String _badgeKindLabel(PosterBadgeKind kind, AppL10n l) {
  return kind.label(l);
}

class _PosterBadgePreview extends StatelessWidget {
  const _PosterBadgePreview({required this.visibility});

  static List<CoverBadgeSpec> _previewBadges(AppL10n l) => [
    CoverBadgeSpec(
      PosterBadgeKind.codec,
      'HEVC',
      const Color(0xFF059669),
      l.posterBadgePreviewCodec,
    ),
    CoverBadgeSpec(
      PosterBadgeKind.hdr,
      'HDR10',
      const Color(0xFFEA580C),
      l.posterBadgePreviewHdr,
    ),
    CoverBadgeSpec(
      PosterBadgeKind.strm,
      'STRM',
      const Color(0xFF475569),
      l.posterBadgePreviewStrm,
    ),
    CoverBadgeSpec(
      PosterBadgeKind.subtitle,
      l.badgeSubtitle,
      const Color(0xFFFF9F1C),
      l.movieCardSubExternal,
    ),
    CoverBadgeSpec(
      PosterBadgeKind.subtitle,
      l.badgeSubtitle,
      const Color(0xFF16A34A),
      l.movieCardSubMuxedTrack,
    ),
    CoverBadgeSpec(
      PosterBadgeKind.subtitle,
      l.badgeSubtitle,
      const Color(0xFFCA8A04),
      l.movieCardSubFilename,
    ),
    CoverBadgeSpec(
      PosterBadgeKind.crack,
      l.badgeCrack,
      const Color(0xFFDB2777),
      l.movieCardCrack,
    ),
    CoverBadgeSpec(
      PosterBadgeKind.resolution,
      'HD',
      const Color(0xFF0891B2),
      l.posterBadgePreviewHd,
    ),
  ];

  final PosterBadgeVisibility visibility;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final badges = _previewBadges(l)
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
            Text(l.previewTitle, style: AppText.eyebrow(context)),
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
                          Text(
                            l.posterBadgePreviewTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (badges.isEmpty)
                            Text(
                              l.posterBadgeAllHidden,
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
            Text(l.posterBadgePreviewHint, style: AppText.meta(context)),
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
    final l = AppL10n.of(context);
    return SettingsTile(
      key: ValueKey('poster-badge-${kind.name}'),
      title: _badgeKindLabel(kind, l),
      subtitle: enabled ? l.posterBadgeVisible : l.badgeHidden,
      leadingIcon: _icon,
      trailing: SettingsSwitch(value: enabled, onChanged: onChanged),
    );
  }
}
