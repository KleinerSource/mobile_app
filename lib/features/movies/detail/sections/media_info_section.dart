import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/media_info.dart';
import '../../../../core/ui/tokens.dart';
import '../../movies_providers.dart';

class MediaInfoSection extends ConsumerWidget {
  const MediaInfoSection({super.key, required this.movieId});
  final int movieId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<AppColors>()!;
    final asyncMi = ref.watch(mediaInfoProvider(movieId));
    return asyncMi.maybeWhen(
      data: (mi) {
        if (mi == null) return const SizedBox.shrink();
        final rows = _buildRows(mi);
        if (rows.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '媒体信息',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: c.text),
              ),
              const SizedBox(height: AppSpacing.s),
              ...rows,
              const SizedBox(height: AppSpacing.l),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  List<Widget> _buildRows(MediaInfo mi) {
    String? video;
    if (mi.videoCodec != null) {
      final parts = <String>[mi.videoCodec!];
      if (mi.videoWidth != null && mi.videoHeight != null) {
        parts.add('${mi.videoWidth}×${mi.videoHeight}');
      }
      if (mi.videoProfile != null) parts.add(mi.videoProfile!);
      if (mi.videoFrameRate != null) {
        parts.add('${mi.videoFrameRate!.toStringAsFixed(2)} fps');
      }
      if (mi.videoBitRate != null && mi.videoBitRate! > 0) {
        parts.add(_formatBitrate(mi.videoBitRate!));
      }
      video = parts.join(' · ');
    }

    String? audio;
    if (mi.audioCodec != null) {
      final parts = <String>[mi.audioCodec!];
      if (mi.audioChannels != null) parts.add('${mi.audioChannels} 声道');
      if (mi.audioBitRate != null && mi.audioBitRate! > 0) {
        parts.add(_formatBitrate(mi.audioBitRate!));
      }
      audio = parts.join(' · ');
    }

    String? container;
    if (mi.container != null && mi.container!.isNotEmpty) {
      final parts = <String>[mi.container!];
      if (mi.durationSec != null && mi.durationSec! > 0) {
        parts.add(_formatDuration(mi.durationSec!));
      }
      if (mi.bitRate != null && mi.bitRate! > 0) {
        parts.add('总码率 ${_formatBitrate(mi.bitRate!)}');
      }
      container = parts.join(' · ');
    }

    return [
      if (container != null) _row('容器', container),
      if (video != null) _row('视频', video),
      if (audio != null) _row('音频', audio),
    ];
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Builder(builder: (context) {
        final c = Theme.of(context).extension<AppColors>()!;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              child: Text(
                label,
                style: TextStyle(fontSize: 13, color: c.textMuted),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: c.text,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  String _formatBitrate(int bps) {
    if (bps >= 1000000) return '${(bps / 1000000).toStringAsFixed(1)} Mbps';
    if (bps >= 1000) return '${(bps / 1000).round()} kbps';
    return '$bps bps';
  }

  String _formatDuration(double seconds) {
    final total = seconds.round();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
