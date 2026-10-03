import 'package:flutter/foundation.dart';

/// DBO 资源条件的共享词表：有磁链（下载）、字幕、单人、可播放。
///
/// 关注页 filter_by 的 basic 段与实体落地页的 filter 参数使用单字母值
/// （m/c/s/p），影片搜索的 `movie_filter_by` 使用全词值
/// （magnets/subtitle/single）——同一组文案与固定顺序，仅按端点映射取值。
/// 本地影片库 `/videos` 的 filter 字母集（m/c/n/l）语义不同，不复用此词表。
@immutable
class DbOnlineResourceConditionOption {
  const DbOnlineResourceConditionOption(this.letter, this.word);

  /// 实体落地页与关注页的 filter 取值。
  final String letter;

  /// 搜索页 movie_filter_by 取值；空串表示该端点不支持此条件
  /// （如 p=可播放，上游搜索仅支持 magnets/subtitle/single）。
  final String word;
}

const dbOnlineResourceConditions = <DbOnlineResourceConditionOption>[
  DbOnlineResourceConditionOption('m', 'magnets'),
  DbOnlineResourceConditionOption('c', 'subtitle'),
  DbOnlineResourceConditionOption('s', 'single'),
  DbOnlineResourceConditionOption('p', ''),
];

/// 按固定顺序（m,c,s,p）整理选中的资源条件字母。
List<String> dbOnlineResourceConditionLetters(Set<String> selected) => [
  for (final option in dbOnlineResourceConditions)
    if (selected.contains(option.letter)) option.letter,
];

/// 搜索页 movie_filter_by 参数：选中字母映射为全词并按固定顺序拼接，
/// 空集返回 all。无全词的条件（如 p）不参与该端点。
String dbOnlineMovieFilterByLetters(Set<String> selected) {
  final words = [
    for (final option in dbOnlineResourceConditions)
      if (selected.contains(option.letter) && option.word.isNotEmpty)
        option.word,
  ];
  return words.isEmpty ? 'all' : words.join(',');
}

/// 解析来源（预设 JSON、服务端回传）的资源条件字母白名单过滤，
/// 按固定顺序去重输出，未知字母丢弃。
List<String> dbOnlineSanitizeResourceConditions(Iterable<String> raw) {
  final allowed = {
    for (final option in dbOnlineResourceConditions) option.letter,
  };
  return dbOnlineResourceConditionLetters(raw.where(allowed.contains).toSet());
}
