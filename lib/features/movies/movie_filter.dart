import 'package:flutter/foundation.dart';

@immutable
class MovieFilter {
  const MovieFilter({
    this.search,
    this.tagIds = const [],
    this.genreIds = const [],
    this.seriesIds = const [],
    this.actorIds = const [],
    this.directoryId,
    this.libraryId,
    this.sortBy = 'created_at',
    this.sortOrder = 'desc',
  });

  final String? search;
  final List<int> tagIds;
  final List<int> genreIds;
  final List<int> seriesIds;
  final List<int> actorIds;
  final int? directoryId;
  final int? libraryId;
  final String sortBy;
  final String sortOrder;

  Map<String, dynamic> toQuery({required int limit, required int offset}) {
    final m = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      'sort_by': sortBy,
      'sort_order': sortOrder,
    };
    if (search != null && search!.trim().isNotEmpty) {
      m['search'] = search!.trim();
    }
    if (tagIds.isNotEmpty) m['tag_ids'] = tagIds.join(',');
    if (genreIds.isNotEmpty) m['genre_ids'] = genreIds.join(',');
    if (seriesIds.isNotEmpty) m['series_ids'] = seriesIds.join(',');
    if (actorIds.isNotEmpty) m['actor_ids'] = actorIds.join(',');
    if (directoryId != null) m['directory_id'] = directoryId;
    if (libraryId != null) m['library_id'] = libraryId;
    return m;
  }

  MovieFilter copyWith({
    String? search,
    List<int>? tagIds,
    List<int>? genreIds,
    List<int>? seriesIds,
    List<int>? actorIds,
    int? directoryId,
    int? libraryId,
    bool clearDirectory = false,
    bool clearLibrary = false,
    String? sortBy,
    String? sortOrder,
  }) {
    return MovieFilter(
      search: search ?? this.search,
      tagIds: tagIds ?? this.tagIds,
      genreIds: genreIds ?? this.genreIds,
      seriesIds: seriesIds ?? this.seriesIds,
      actorIds: actorIds ?? this.actorIds,
      directoryId: clearDirectory ? null : (directoryId ?? this.directoryId),
      libraryId: clearLibrary ? null : (libraryId ?? this.libraryId),
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MovieFilter &&
        other.search == search &&
        listEquals(other.tagIds, tagIds) &&
        listEquals(other.genreIds, genreIds) &&
        listEquals(other.seriesIds, seriesIds) &&
        listEquals(other.actorIds, actorIds) &&
        other.directoryId == directoryId &&
        other.libraryId == libraryId &&
        other.sortBy == sortBy &&
        other.sortOrder == sortOrder;
  }

  @override
  int get hashCode => Object.hash(
        search,
        Object.hashAll(tagIds),
        Object.hashAll(genreIds),
        Object.hashAll(seriesIds),
        Object.hashAll(actorIds),
        directoryId,
        libraryId,
        sortBy,
        sortOrder,
      );
}
