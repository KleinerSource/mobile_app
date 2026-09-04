import 'package:flutter/material.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/core/sources/media/media_metadata_normalizer.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

import 'filter_chip.dart';

/// 公共卡片的年份/时长元信息格式。
///
/// 评分以 [CatalogMovieCard] 的评分角标展示，不重复塞进文字行；调用方
/// 只需传入公共模型中的分钟数和年份即可得到一致的顺序与空值行为。
String? formatMediaYear(int? year) {
  final normalized = normalizeMediaYear(year);
  return normalized?.toString();
}

String? formatMediaDuration(AppL10n l, int? duration) {
  final normalized = normalizeMediaDurationMinutes(duration);
  return normalized == null ? null : l.mediaDurationMinutes(normalized);
}

String? formatMediaRating(double? rating) {
  final normalized = normalizeMediaRating(rating);
  return normalized?.toStringAsFixed(1);
}

String formatMediaCardMeta(
  AppL10n l, {
  int? year,
  int? duration,
  String? emptyText,
}) {
  final parts = <String>[];
  final yearText = formatMediaYear(year);
  if (yearText != null) parts.add(yearText);
  final durationText = formatMediaDuration(l, duration);
  if (durationText != null) parts.add(durationText);
  return parts.isEmpty ? (emptyText ?? '') : parts.join(' · ');
}

/// 统一的分类/标签 Chip 区块。
///
/// 组件只负责排版和可选点击回调，不知道任何来源的导航或筛选协议。
class MediaTaxonomySection extends StatelessWidget {
  const MediaTaxonomySection({
    super.key,
    required this.title,
    required this.items,
    this.prefix = '',
    this.hueOffset = 0,
    this.onTap,
    this.ids = const <String>[],
    this.onTapWithId,
    this.bottom = 22,
  });

  final String title;
  final List<String> items;
  final String prefix;
  final int hueOffset;
  final ValueChanged<String>? onTap;
  final List<String> ids;
  final void Function(String id, String label)? onTapWithId;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final values = <String>[];
    final valueIds = <String>[];
    final seen = <String>{};
    for (var i = 0; i < items.length; i++) {
      final value = normalizeMediaText(items[i]);
      if (value == null || !seen.add(value.toLowerCase())) continue;
      values.add(value);
      valueIds.add(i < ids.length ? ids[i] : '');
    }
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 0, 22, bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.sectionTitle(context)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < values.length; i++)
                HueChip(
                  label: '$prefix${values[i]}',
                  hue: AppHues.all[(i + hueOffset) % AppHues.all.length],
                  onTap: onTapWithId != null && valueIds[i].trim().isNotEmpty
                      ? () => onTapWithId!(valueIds[i].trim(), values[i])
                      : onTap == null
                      ? null
                      : () => onTap!(values[i]),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
