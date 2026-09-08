typedef MovieQuickEntity = ({int id, String name});
typedef MovieQuickSelections = ({
  List<MovieQuickEntity> tags,
  List<MovieQuickEntity> genres,
});

enum MovieQuickFlag { subtitle, exsub, crack, fourK, twoK }

class MovieQuickFlagConfig {
  const MovieQuickFlagConfig({
    required this.canonicalName,
    required this.keywords,
  });

  final String canonicalName;
  final List<String> keywords;
}

const _subtitleConfig = MovieQuickFlagConfig(
  canonicalName: '中文字幕',
  keywords: ['中文字幕', '中字'],
);
const _crackConfig = MovieQuickFlagConfig(
  canonicalName: '无码破解',
  keywords: ['无码破解', '破解'],
);
const _fourKConfig = MovieQuickFlagConfig(
  canonicalName: '4K',
  keywords: ['4K', '2160P'],
);
const _twoKConfig = MovieQuickFlagConfig(
  canonicalName: '2K',
  keywords: ['2K', 'QHD', '1440P'],
);

/// 快捷清晰度下拉框只提供 4K / 2K；这些别名用于切换时清理互斥的旧清晰度标签。
const movieResolutionCleanupKeywords = <String>[
  '4K',
  '2160P',
  '2K',
  'QHD',
  '1440P',
  'FHD',
  '1080P',
];

MovieQuickFlagConfig movieQuickFlagConfig(MovieQuickFlag flag) {
  return switch (flag) {
    MovieQuickFlag.subtitle || MovieQuickFlag.exsub => _subtitleConfig,
    MovieQuickFlag.crack => _crackConfig,
    MovieQuickFlag.fourK => _fourKConfig,
    MovieQuickFlag.twoK => _twoKConfig,
  };
}

String _normalizeQuickFlagName(String value) => value.trim().toLowerCase();

bool hasMovieQuickFlag({
  required MovieQuickFlag flag,
  required Iterable<MovieQuickEntity> tags,
  required Iterable<MovieQuickEntity> genres,
}) {
  final keywords = movieQuickFlagConfig(
    flag,
  ).keywords.map(_normalizeQuickFlagName).toSet();
  return tags
      .followedBy(genres)
      .any((item) => keywords.contains(_normalizeQuickFlagName(item.name)));
}

MovieQuickSelections addMovieQuickFlagSelections({
  required List<MovieQuickEntity> tags,
  required List<MovieQuickEntity> genres,
  required MovieQuickEntity tag,
  required MovieQuickEntity genre,
}) {
  return (tags: _appendEntity(tags, tag), genres: _appendEntity(genres, genre));
}

MovieQuickSelections removeMovieQuickFlagSelections({
  required MovieQuickFlag flag,
  required List<MovieQuickEntity> tags,
  required List<MovieQuickEntity> genres,
}) {
  final keywords = movieQuickFlagConfig(
    flag,
  ).keywords.map(_normalizeQuickFlagName).toSet();
  bool keep(MovieQuickEntity item) =>
      !keywords.contains(_normalizeQuickFlagName(item.name));
  return (
    tags: tags.where(keep).toList(growable: false),
    genres: genres.where(keep).toList(growable: false),
  );
}

List<MovieQuickEntity> _appendEntity(
  List<MovieQuickEntity> items,
  MovieQuickEntity item,
) {
  if (items.any((current) => current.id == item.id)) {
    return List<MovieQuickEntity>.of(items);
  }
  return [...items, item];
}
