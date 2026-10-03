import 'package:omm/core/sources/media/dbo/db_online_resource_filter.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

/// DBO 各页面共享的筛选选项定义：资源条件、影片分类、排序。
///
/// 取值与顺序和网页端保持一致；仅聚合 l10n 文案，词表与参数转换在
/// core 层的 db_online_resource_filter.dart。

/// 资源条件字母 → 文案；m/c 复用影片库的下载/字幕文案。
String dbOnlineResourceConditionLabel(
  AppL10n l,
  DbOnlineResourceConditionOption option,
) => switch (option.letter) {
  'm' => l.dbOnlineLibraryDownload,
  'c' => l.dbOnlineLibrarySubtitle,
  'p' => l.dbOnlineResourcePlayable,
  _ => l.dbOnlineFollowingSingleActor,
};

/// 资源条件在筛选弹层中的选项（含“全部”）：单选场景传 `selected: ''`，
/// 多选场景 [DbOnlineFilterSection.multiSelect] 为 true。
///
/// 搜索端点的 `movie_filter_by` 不支持 p（可播放），默认不含；
/// 实体/关注端点在服务端 can_play 开启时传 [includePlayable] 追加。
List<({String value, String label})> dbOnlineResourceConditionOptions(
  AppL10n l, {
  bool includePlayable = false,
}) => [
  (value: '', label: l.filterAll),
  for (final option in dbOnlineResourceConditions)
    if (includePlayable || option.word.isNotEmpty)
      (value: option.letter, label: dbOnlineResourceConditionLabel(l, option)),
];

/// DBO 影片分类值 → 文案：0 有码 / 1 无码 / 2 欧美 / 3 FC2 / 4 动漫；
/// 未知值（如 Top250 的年份）原样返回。
String dbOnlineCategoryLabel(AppL10n l, String value) => switch (value) {
  '0' => l.dbOnlineCategoryCensored,
  '1' => l.dbOnlineCategoryUncensored,
  '2' => l.dbOnlineCategoryWestern,
  '3' => 'FC2',
  '4' => l.dbOnlineCategoryAnime,
  _ => value,
};

/// 分类选项列表；[count] 截取前 N 个值（5=含动漫、4=到 FC2、3=到欧美），
/// [includeAll] 时首位附加「全部」（值 `all`）。
List<({String value, String label})> dbOnlineCategoryOptions(
  AppL10n l, {
  int count = 5,
  bool includeAll = false,
}) => [
  if (includeAll) (value: 'all', label: l.filterAll),
  for (final value in const ['0', '1', '2', '3', '4'].take(count))
    (value: value, label: dbOnlineCategoryLabel(l, value)),
];

/// 搜索页排序选项：relevance/release/update/score。
List<({String value, String label})> dbOnlineMovieSortOptions(AppL10n l) => [
  (value: 'relevance', label: l.dbOnlineSortRelevance),
  (value: 'release', label: l.dbOnlineLibrarySortDate),
  (value: 'update', label: l.dbOnlineRecentUpdated),
  (value: 'score', label: l.dbOnlineLibraryCommunityRating),
];

/// 实体落地页排序选项：release/update/score。
List<({String value, String label})> dbOnlineEntityMovieSortOptions(
  AppL10n l,
) => [
  (value: 'release', label: l.dbOnlineLibrarySortDate),
  (value: 'update', label: l.dbOnlineRecentUpdated),
  (value: 'score', label: l.dbOnlineLibraryCommunityRating),
];

/// 本地影片库 `/videos` 的资源筛选（单选）：m/c 复用共享资源条件，
/// n/l 为该端点专属（无资源/已入库），不含 p。
List<({String value, String label})> dbOnlineLibraryResourceOptions(
  AppL10n l,
) => [
  (value: '', label: l.filterAll),
  for (final option in dbOnlineResourceConditions)
    if (option.letter == 'm' || option.letter == 'c')
      (value: option.letter, label: dbOnlineResourceConditionLabel(l, option)),
  (value: 'n', label: l.dbOnlineLibraryNoResources),
  (value: 'l', label: l.dbOnlineLibraryInLibrary),
];
