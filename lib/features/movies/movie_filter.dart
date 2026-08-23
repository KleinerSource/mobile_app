import 'package:flutter/foundation.dart';

enum MovieSearchType { title, num, actor, filename }

extension MovieSearchTypeQuery on MovieSearchType {
  String get queryValue => switch (this) {
    MovieSearchType.title => 'title',
    MovieSearchType.num => 'num',
    MovieSearchType.actor => 'actor',
    MovieSearchType.filename => 'filename',
  };
}

@immutable
class MovieFilter {
  const MovieFilter({
    this.search,
    this.searchType = MovieSearchType.title,
    this.tagIds = const [],
    this.excludeTagIds = const [],
    this.genreIds = const [],
    this.excludeGenreIds = const [],
    this.seriesIds = const [],
    this.actorIds = const [],
    this.directoryId,
    this.libraryId,
    this.yearFrom,
    this.yearTo,
    this.ratingFrom,
    this.ratingTo,
    this.hasExternalSubtitle,
    this.excludeHasExternalSubtitle,
    this.fileFilterMode,
    this.isUpdated,
    this.hasNewResources,
    this.duplicateNum = false,
    this.sortBy = 'created_at',
    this.sortOrder = 'desc',
  });

  final String? search;
  final MovieSearchType searchType;
  final List<int> tagIds;
  final List<int> excludeTagIds;
  final List<int> genreIds;
  final List<int> excludeGenreIds;
  final List<int> seriesIds;
  final List<int> actorIds;
  final int? directoryId;
  final int? libraryId;
  final int? yearFrom;
  final int? yearTo;

  /// 1-10 范围, web 用 string 但后端能接 number 也接 string
  final int? ratingFrom;
  final int? ratingTo;

  /// 仅包含含外挂字幕
  final bool? hasExternalSubtitle;

  /// 仅排除含外挂字幕
  final bool? excludeHasExternalSubtitle;

  /// standard / crack / subtitle / subtitle_crack
  final String? fileFilterMode;

  /// 已更新筛选: true=已更新 / false=未更新 / null=不限
  final bool? isUpdated;

  /// 仅显示最近资源扫描发现新资源的影片。
  final bool? hasNewResources;

  /// 仅显示重复番号 (true / false)
  final bool duplicateNum;

  final String sortBy;
  final String sortOrder;

  /// 用于 UI 显示 "几个筛选项激活"
  int get activeAdvancedCount {
    var n = 0;
    if (tagIds.isNotEmpty) n++;
    if (excludeTagIds.isNotEmpty) n++;
    if (genreIds.isNotEmpty) n++;
    if (excludeGenreIds.isNotEmpty) n++;
    if (seriesIds.isNotEmpty) n++;
    if (yearFrom != null || yearTo != null) n++;
    if (ratingFrom != null || ratingTo != null) n++;
    if (hasExternalSubtitle == true || excludeHasExternalSubtitle == true) n++;
    if (fileFilterMode != null && fileFilterMode!.isNotEmpty) n++;
    if (isUpdated != null) n++;
    if (hasNewResources == true) n++;
    if (duplicateNum) n++;
    return n;
  }

  Map<String, dynamic> toQuery({required int limit, required int offset}) {
    final m = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      'sort_by': sortBy,
      'sort_order': sortOrder,
    };
    if (search != null && search!.trim().isNotEmpty) {
      m['search'] = search!.trim();
      m['search_type'] = searchType.queryValue;
    }
    if (tagIds.isNotEmpty) m['tag_ids'] = tagIds.join(',');
    if (excludeTagIds.isNotEmpty) {
      m['exclude_tag_ids'] = excludeTagIds.join(',');
    }
    if (genreIds.isNotEmpty) m['genre_ids'] = genreIds.join(',');
    if (excludeGenreIds.isNotEmpty) {
      m['exclude_genre_ids'] = excludeGenreIds.join(',');
    }
    if (seriesIds.isNotEmpty) m['series_ids'] = seriesIds.join(',');
    if (actorIds.isNotEmpty) m['actor_ids'] = actorIds.join(',');
    if (directoryId != null) m['directory_id'] = directoryId;
    if (libraryId != null) m['library_id'] = libraryId;
    if (yearFrom != null) m['year_from'] = yearFrom;
    if (yearTo != null) m['year_to'] = yearTo;
    if (ratingFrom != null) m['rating_from'] = ratingFrom;
    if (ratingTo != null) m['rating_to'] = ratingTo;
    if (hasExternalSubtitle == true) m['has_external_subtitle'] = true;
    if (excludeHasExternalSubtitle == true) {
      m['exclude_has_external_subtitle'] = true;
    }
    if (fileFilterMode != null && fileFilterMode!.isNotEmpty) {
      m['file_filter_mode'] = fileFilterMode;
    }
    if (isUpdated != null) m['is_updated'] = isUpdated;
    if (hasNewResources == true) m['has_new_resources'] = true;
    if (duplicateNum) m['duplicate_num'] = true;
    return m;
  }

  /// 构造资源扫描接口所需的 JSON 筛选体。
  ///
  /// 资源扫描接口接收数组和数字，不复用列表查询中的逗号分隔参数，
  /// 同时省略分页、排序等只对列表请求有意义的字段。
  Map<String, dynamic> toResourceScanBody() {
    final m = <String, dynamic>{};
    void addList(String key, List<int> values) {
      if (values.isNotEmpty) m[key] = List<int>.from(values);
    }

    if (search != null && search!.trim().isNotEmpty) {
      m['search'] = search!.trim();
      m['search_type'] = searchType.queryValue;
    }
    addList('tag_ids', tagIds);
    addList('exclude_tag_ids', excludeTagIds);
    addList('genre_ids', genreIds);
    addList('exclude_genre_ids', excludeGenreIds);
    addList('series_ids', seriesIds);
    addList('actor_ids', actorIds);
    if (directoryId != null) m['directory_id'] = directoryId;
    if (libraryId != null) m['library_id'] = libraryId;
    if (yearFrom != null) m['year_from'] = yearFrom;
    if (yearTo != null) m['year_to'] = yearTo;
    if (ratingFrom != null) m['rating_from'] = ratingFrom;
    if (ratingTo != null) m['rating_to'] = ratingTo;
    if (isUpdated != null) m['is_updated'] = isUpdated;
    if (hasNewResources == true) m['has_new_resources'] = true;
    if (hasExternalSubtitle == true) m['has_external_subtitle'] = true;
    if (excludeHasExternalSubtitle == true) {
      m['exclude_has_external_subtitle'] = true;
    }
    if (fileFilterMode != null && fileFilterMode!.isNotEmpty) {
      m['file_filter_mode'] = fileFilterMode;
    }
    if (duplicateNum) m['duplicate_num'] = true;
    return m;
  }

  MovieFilter copyWith({
    String? search,
    MovieSearchType? searchType,
    List<int>? tagIds,
    List<int>? excludeTagIds,
    List<int>? genreIds,
    List<int>? excludeGenreIds,
    List<int>? seriesIds,
    List<int>? actorIds,
    int? directoryId,
    int? libraryId,
    int? yearFrom,
    int? yearTo,
    int? ratingFrom,
    int? ratingTo,
    bool? hasExternalSubtitle,
    bool? excludeHasExternalSubtitle,
    String? fileFilterMode,
    bool? isUpdated,
    bool? hasNewResources,
    bool? duplicateNum,
    bool clearDirectory = false,
    bool clearLibrary = false,
    bool clearYearFrom = false,
    bool clearYearTo = false,
    bool clearRatingFrom = false,
    bool clearRatingTo = false,
    bool clearHasExternalSubtitle = false,
    bool clearExcludeHasExternalSubtitle = false,
    bool clearFileFilterMode = false,
    bool clearIsUpdated = false,
    bool clearHasNewResources = false,
    String? sortBy,
    String? sortOrder,
  }) {
    return MovieFilter(
      search: search ?? this.search,
      searchType: searchType ?? this.searchType,
      tagIds: tagIds ?? this.tagIds,
      excludeTagIds: excludeTagIds ?? this.excludeTagIds,
      genreIds: genreIds ?? this.genreIds,
      excludeGenreIds: excludeGenreIds ?? this.excludeGenreIds,
      seriesIds: seriesIds ?? this.seriesIds,
      actorIds: actorIds ?? this.actorIds,
      directoryId: clearDirectory ? null : (directoryId ?? this.directoryId),
      libraryId: clearLibrary ? null : (libraryId ?? this.libraryId),
      yearFrom: clearYearFrom ? null : (yearFrom ?? this.yearFrom),
      yearTo: clearYearTo ? null : (yearTo ?? this.yearTo),
      ratingFrom: clearRatingFrom ? null : (ratingFrom ?? this.ratingFrom),
      ratingTo: clearRatingTo ? null : (ratingTo ?? this.ratingTo),
      hasExternalSubtitle: clearHasExternalSubtitle
          ? null
          : (hasExternalSubtitle ?? this.hasExternalSubtitle),
      excludeHasExternalSubtitle: clearExcludeHasExternalSubtitle
          ? null
          : (excludeHasExternalSubtitle ?? this.excludeHasExternalSubtitle),
      fileFilterMode: clearFileFilterMode
          ? null
          : (fileFilterMode ?? this.fileFilterMode),
      isUpdated: clearIsUpdated ? null : (isUpdated ?? this.isUpdated),
      hasNewResources: clearHasNewResources
          ? null
          : (hasNewResources ?? this.hasNewResources),
      duplicateNum: duplicateNum ?? this.duplicateNum,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MovieFilter &&
        other.search == search &&
        other.searchType == searchType &&
        listEquals(other.tagIds, tagIds) &&
        listEquals(other.excludeTagIds, excludeTagIds) &&
        listEquals(other.genreIds, genreIds) &&
        listEquals(other.excludeGenreIds, excludeGenreIds) &&
        listEquals(other.seriesIds, seriesIds) &&
        listEquals(other.actorIds, actorIds) &&
        other.directoryId == directoryId &&
        other.libraryId == libraryId &&
        other.yearFrom == yearFrom &&
        other.yearTo == yearTo &&
        other.ratingFrom == ratingFrom &&
        other.ratingTo == ratingTo &&
        other.hasExternalSubtitle == hasExternalSubtitle &&
        other.excludeHasExternalSubtitle == excludeHasExternalSubtitle &&
        other.fileFilterMode == fileFilterMode &&
        other.isUpdated == isUpdated &&
        other.hasNewResources == hasNewResources &&
        other.duplicateNum == duplicateNum &&
        other.sortBy == sortBy &&
        other.sortOrder == sortOrder;
  }

  @override
  int get hashCode => Object.hashAll([
    search,
    searchType,
    Object.hashAll(tagIds),
    Object.hashAll(excludeTagIds),
    Object.hashAll(genreIds),
    Object.hashAll(excludeGenreIds),
    Object.hashAll(seriesIds),
    Object.hashAll(actorIds),
    directoryId,
    libraryId,
    yearFrom,
    yearTo,
    ratingFrom,
    ratingTo,
    hasExternalSubtitle,
    excludeHasExternalSubtitle,
    fileFilterMode,
    isUpdated,
    hasNewResources,
    duplicateNum,
    sortBy,
    sortOrder,
  ]);
}
