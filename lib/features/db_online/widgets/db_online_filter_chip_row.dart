import 'package:flutter/material.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

/// DBO 资源条件的共享选项：有磁链（下载）、字幕、单人。
///
/// 关注页/影片库与实体落地页使用单字母值（m/c/s），影片搜索的
/// `movie_filter_by` 使用全词值（magnets/subtitle/single）——同一组
/// 文案与固定顺序，仅按端点映射取值。
class DbOnlineResourceConditionOption {
  const DbOnlineResourceConditionOption(this.letter, this.word);

  /// 实体落地页与关注页的 filter 取值。
  final String letter;

  /// 搜索页 movie_filter_by 取值。
  final String word;
}

const dbOnlineResourceConditions = <DbOnlineResourceConditionOption>[
  DbOnlineResourceConditionOption('m', 'magnets'),
  DbOnlineResourceConditionOption('c', 'subtitle'),
  DbOnlineResourceConditionOption('s', 'single'),
];

String dbOnlineResourceConditionLabel(
  AppL10n l,
  DbOnlineResourceConditionOption option,
) => switch (option.letter) {
  'm' => l.dbOnlineLibraryDownload,
  'c' => l.dbOnlineLibrarySubtitle,
  _ => l.dbOnlineFollowingSingleActor,
};

/// 按固定顺序（m,c,s）整理选中的资源条件字母。
List<String> dbOnlineResourceConditionLetters(Set<String> selected) => [
  for (final option in dbOnlineResourceConditions)
    if (selected.contains(option.letter)) option.letter,
];

/// 搜索页 movie_filter_by 参数：选中字母映射为全词并按固定顺序拼接，
/// 空集返回 all。
String dbOnlineMovieFilterByLetters(Set<String> selected) {
  final words = [
    for (final option in dbOnlineResourceConditions)
      if (selected.contains(option.letter)) option.word,
  ];
  return words.isEmpty ? 'all' : words.join(',');
}

/// DBO 过滤器 chip 行：单行横向滚动，多组 chips 之间用细分隔线分开。
///
/// 与网页端 ConfigFilterPanel 的 inline-chips 行对应；组内单选还是多选
/// 由调用方在 chip 的 onTap 里自行处理。
class DbOnlineFilterChipRow extends StatelessWidget {
  const DbOnlineFilterChipRow({super.key, required this.groups});

  /// 每组是一段 chips；组间渲染竖向分隔线。
  final List<List<Widget>> groups;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final row = <Widget>[];
    for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
      if (groupIndex > 0) {
        row.addAll([
          const SizedBox(width: 7),
          Container(width: 1, height: 18, color: colors.cardBorder),
          const SizedBox(width: 7),
        ]);
      }
      row.addAll(groups[groupIndex]);
    }
    // 横向滚动 + Row 自然撑高，chips 文字随系统字体缩放时行高自适应。
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          for (var index = 0; index < row.length; index++) ...[
            if (index > 0) const SizedBox(width: 7),
            row[index],
          ],
        ],
      ),
    );
  }
}
