# Movie Detail MVP (Sub 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 按 [Sub 1 spec](../specs/2026-05-22-movie-detail-mvp-design.md) 实现移动端影片详情页（10 个信息块全展示）+ 收藏切换 + 标记看完 + 列表关联导航。

**Architecture:** 新建 `lib/features/movies/detail/` 目录承载详情页页面、内容编排和 10 个 section 子 widget。`MovieDetail` model 扩字段，新增 `RelatedMovie`/`RelatedFile`/`MediaInfo` 三个 model。`MoviesApi` 修路径错误并加 3 端点（extra fanart / media info / favorite toggle）。MainShell 的 tab index 提到 riverpod provider，让详情页能驱动"切 tab + 注入 filter + popUntil"的列表跳转。

**Tech Stack:** Flutter 3.44 / Material 3 / flutter_riverpod 2.6 / freezed 2.5 / json_serializable / retrofit 4.5+ / cached_network_image / dio 5

---

## File Structure

```
lib/
  core/
    models/
      movie.dart                ← 扩 MovieDetail 字段
      related_movie.dart        ← 新
      related_file.dart         ← 新
      media_info.dart           ← 新
    api/services/
      movies_api.dart           ← 修 4 个旧路径 + 加 3 新端点
      favorites_api.dart        ← 新（独立 group 走 /favorites）
    api/
      api_client.dart           ← 暴露 favorites
  features/
    main/
      main_shell.dart           ← 改 ConsumerWidget + 读 mainShellTabIndexProvider
      main_shell_providers.dart ← 新（mainShellTabIndexProvider）
    movies/
      movies_page.dart          ← MovieCard.onTap + 监听 movieFilterProvider 变化 refresh
      movies_repository.dart    ← 加 extraFanarts/mediaInfo/toggleFavorite/markWatched
      movies_providers.dart     ← 加 movieDetailProvider / extraFanartsProvider / mediaInfoProvider
      detail/
        movie_detail_page.dart      ← AsyncValue 三态
        movie_detail_content.dart   ← 串 10 个 section
        movie_detail_actions.dart   ← 收藏 + 标记看完按钮（含 loading）
        sections/
          hero_section.dart
          info_section.dart
          plot_section.dart
          taxonomy_section.dart
          related_movies_section.dart
          extra_fanart_section.dart
          media_info_section.dart
          file_paths_section.dart
        widgets/
          taxonomy_pill.dart
          actor_chip.dart
          related_movie_card.dart
          info_item_row.dart
          fanart_gallery.dart       ← 全屏 InteractiveViewer
        navigation.dart             ← applyFilterAndPop + navigateToMovie helper

test/
  core/models/
    media_info_test.dart        ← 反序列化测试
    related_movie_test.dart
  features/movies/
    movies_page_test.dart       ← MovieCard.onTap 推 detail page
    detail/
      movie_detail_page_test.dart
      movie_detail_actions_test.dart
      sections/
        info_section_test.dart
        taxonomy_section_test.dart
      widgets/
        actor_chip_test.dart
        related_movie_card_test.dart
        info_item_row_test.dart
```

每个 section 是 Stateless，接 `MovieDetail`（或子字段）+ 必要回调。`movie_detail_content.dart` 串编排。`movie_detail_actions.dart` 是 ConsumerStateful 维护两个按钮的 loading 状态。Repository / API / Provider 分层与现有 movies 模块一致。

---

## Task 1: 修 MoviesApi 路径 & 新增 3 端点

**Files:**
- Modify: `lib/core/api/services/movies_api.dart`
- Create: `lib/core/api/services/favorites_api.dart`
- Modify: `lib/core/api/api_client.dart`

**Background:** Spec §5.3 已确认 backend 路径。当前 `movies_api.dart` 的所有 `/movies/{id}` 在 backend 上不存在（应为 `/movies/id/{id}`）；favorite 接口在独立 `/favorites/{id}/toggle` 上。

- [ ] **Step 1: Replace `lib/core/api/services/movies_api.dart` content**

```dart
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'movies_api.g.dart';

@RestApi()
abstract class MoviesApi {
  factory MoviesApi(Dio dio, {String baseUrl}) = _MoviesApi;

  @GET('/movies')
  Future<dynamic> getMovies(@Queries() Map<String, dynamic> q);

  @GET('/movies/id/{id}')
  Future<dynamic> getMovieDetail(@Path('id') int id);

  @PUT('/movies/id/{id}/watch-record')
  Future<dynamic> upsertWatchRecord(
    @Path('id') int id,
    @Body() Map<String, dynamic> body,
  );

  @GET('/movies/id/{id}/watch-record')
  Future<dynamic> getWatchRecord(@Path('id') int id);

  @GET('/movies/id/{id}/extrafanart')
  Future<dynamic> getExtraFanarts(@Path('id') int id);

  @GET('/movies/id/{id}/media-info')
  Future<dynamic> getMediaInfo(@Path('id') int id);
}
```

- [ ] **Step 2: Create `lib/core/api/services/favorites_api.dart`**

```dart
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'favorites_api.g.dart';

@RestApi()
abstract class FavoritesApi {
  factory FavoritesApi(Dio dio, {String baseUrl}) = _FavoritesApi;

  @PUT('/favorites/{movieId}/toggle')
  Future<dynamic> toggle(@Path('movieId') int movieId);
}
```

- [ ] **Step 3: Modify `lib/core/api/api_client.dart` to expose favorites**

Add to imports:
```dart
import 'services/favorites_api.dart';
```

Inside `ApiClient` class body, add field + initializer:

```dart
class ApiClient {
  ApiClient(this.dio)
      : system = SystemApi(dio),
        movies = MoviesApi(dio),
        favorites = FavoritesApi(dio),
        tags = TagsApi(dio),
        genres = GenresApi(dio),
        series = SeriesApi(dio),
        actors = ActorsApi(dio),
        directories = DirectoriesApi(dio);

  factory ApiClient.fromConfig(ServerConfig config) => ApiClient(buildDio(config));

  final Dio dio;
  final SystemApi system;
  final MoviesApi movies;
  final FavoritesApi favorites;
  final TagsApi tags;
  final GenresApi genres;
  final SeriesApi series;
  final ActorsApi actors;
  final DirectoriesApi directories;
}
```

- [ ] **Step 4: Update existing stub adapters in tests**

The test stubs that implement `MoviesApi` (in `test/features/movies_repository_test.dart`) need to add the 2 new methods so the analyzer doesn't complain. Open that file and add inside `_StubMoviesApi` (alphabetical ordering not required, just append before the closing `}`):

```dart
  @override
  Future<dynamic> getExtraFanarts(int id) async => <String>[];

  @override
  Future<dynamic> getMediaInfo(int id) async => <String, dynamic>{};
```

- [ ] **Step 5: Commit**

```bash
git add lib/core/api/services/movies_api.dart lib/core/api/services/favorites_api.dart lib/core/api/api_client.dart test/features/movies_repository_test.dart
git commit -m "feat(api): fix movie route paths and add favorites/extrafanart/media-info endpoints"
```

The `.g.dart` files are gitignored; CI runs `dart run build_runner build --delete-conflicting-outputs` and regenerates them.

---

## Task 2: 扩展 MovieDetail model

**Files:**
- Modify: `lib/core/models/movie.dart`

**Background:** Spec §5.1 列出 `MovieDetail` 缺的字段。`subtitles` 不建模（详情页不展示），`directory` 不建模（spec §5.1 已说明 backend 不导出）。

- [ ] **Step 1: Append fields to `MovieDetail` const factory**

Open `lib/core/models/movie.dart`. Locate the `MovieDetail` class. Replace the const factory parameter list with:

```dart
  const factory MovieDetail({
    required int id,
    required String title,
    String? num,
    @JsonKey(name: 'original_title') String? originalTitle,
    int? year,
    double? rating,
    int? runtime,
    String? plot,
    String? outline,
    String? country,
    String? trailer,
    @JsonKey(name: 'file_path') String? filePath,
    @JsonKey(name: 'file_size') int? fileSize,
    @JsonKey(name: 'last_downloaded_at') String? lastDownloadedAt,
    @JsonKey(name: 'movie_part') String? moviePart,
    @JsonKey(name: 'poster_uuid') String? posterUuid,
    @JsonKey(name: 'fanart_uuid') String? fanartUuid,
    @JsonKey(name: 'has_external_subtitle') @Default(false) bool hasExternalSubtitle,
    @JsonKey(name: 'is_favorited') @Default(false) bool isFavorited,
    @Default(<ResourceItem>[]) List<ResourceItem> tags,
    @Default(<ResourceItem>[]) List<ResourceItem> genres,
    @Default(<ActorItem>[]) List<ActorItem> actors,
    ResourceItem? series,
    @JsonKey(name: 'watch_record') WatchRecordSummary? watchRecord,
    @JsonKey(name: 'part_movies') @Default(<RelatedMovie>[]) List<RelatedMovie> partMovies,
    @JsonKey(name: 'actor_related_movies') @Default(<RelatedMovie>[]) List<RelatedMovie> actorRelatedMovies,
    @JsonKey(name: 'related_files') @Default(<RelatedFile>[]) List<RelatedFile> relatedFiles,
  }) = _MovieDetail;
```

Add import at top of file (after existing imports):

```dart
import 'related_movie.dart';
import 'related_file.dart';
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/models/movie.dart
git commit -m "feat(model): extend MovieDetail with file_size, related files, part/actor related movies"
```

---

## Task 3: 新模型 RelatedMovie + RelatedFile + MediaInfo

**Files:**
- Create: `lib/core/models/related_movie.dart`
- Create: `lib/core/models/related_file.dart`
- Create: `lib/core/models/media_info.dart`
- Test: `test/core/models/related_movie_test.dart`
- Test: `test/core/models/media_info_test.dart`

- [ ] **Step 1: Create `lib/core/models/related_movie.dart`**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

import 'actor.dart';

part 'related_movie.freezed.dart';
part 'related_movie.g.dart';

@freezed
class RelatedMovie with _$RelatedMovie {
  const factory RelatedMovie({
    required int id,
    required String title,
    String? num,
    @JsonKey(name: 'movie_part') String? moviePart,
    int? year,
    double? rating,
    int? runtime,
    @JsonKey(name: 'poster_uuid') String? posterUuid,
    @JsonKey(name: 'thumb_uuid') String? thumbUuid,
    @JsonKey(name: 'fanart_uuid') String? fanartUuid,
    @JsonKey(name: 'matching_actors')
    @Default(<ActorRef>[]) List<ActorRef> matchingActors,
  }) = _RelatedMovie;

  factory RelatedMovie.fromJson(Map<String, dynamic> json) =>
      _$RelatedMovieFromJson(json);
}
```

- [ ] **Step 2: Create `lib/core/models/related_file.dart`**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'related_file.freezed.dart';
part 'related_file.g.dart';

@freezed
class RelatedFile with _$RelatedFile {
  const factory RelatedFile({
    String? type,
    String? label,
    required String path,
  }) = _RelatedFile;

  factory RelatedFile.fromJson(Map<String, dynamic> json) =>
      _$RelatedFileFromJson(json);
}
```

- [ ] **Step 3: Create `lib/core/models/media_info.dart`**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'media_info.freezed.dart';
part 'media_info.g.dart';

@freezed
class MediaInfo with _$MediaInfo {
  const factory MediaInfo({
    String? container,
    @JsonKey(name: 'video_codec') String? videoCodec,
    @JsonKey(name: 'video_profile') String? videoProfile,
    @JsonKey(name: 'video_width') int? videoWidth,
    @JsonKey(name: 'video_height') int? videoHeight,
    @JsonKey(name: 'video_pix_fmt') String? videoPixFmt,
    @JsonKey(name: 'video_bit_rate') int? videoBitRate,
    @JsonKey(name: 'video_frame_rate') double? videoFrameRate,
    @JsonKey(name: 'audio_codec') String? audioCodec,
    @JsonKey(name: 'audio_channels') int? audioChannels,
    @JsonKey(name: 'audio_bit_rate') int? audioBitRate,
    @JsonKey(name: 'duration_sec') double? durationSec,
    @JsonKey(name: 'bit_rate') int? bitRate,
    @JsonKey(name: 'file_size') int? fileSize,
  }) = _MediaInfo;

  factory MediaInfo.fromJson(Map<String, dynamic> json) =>
      _$MediaInfoFromJson(json);
}
```

- [ ] **Step 4: Create `test/core/models/related_movie_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/models/related_movie.dart';

void main() {
  test('RelatedMovie.fromJson decodes all fields including snake_case keys', () {
    final json = {
      'id': 7,
      'title': '示例',
      'num': 'ABC-001',
      'movie_part': 'A',
      'year': 2023,
      'rating': 8.4,
      'runtime': 120,
      'poster_uuid': 'p-uuid',
      'thumb_uuid': 't-uuid',
      'fanart_uuid': 'f-uuid',
      'matching_actors': [
        {'id': 1, 'name': 'Actor 1'},
      ],
    };
    final m = RelatedMovie.fromJson(json);
    expect(m.id, 7);
    expect(m.moviePart, 'A');
    expect(m.posterUuid, 'p-uuid');
    expect(m.matchingActors.first.name, 'Actor 1');
  });

  test('RelatedMovie.fromJson handles missing optional fields', () {
    final m = RelatedMovie.fromJson({'id': 1, 'title': 't'});
    expect(m.year, isNull);
    expect(m.matchingActors, isEmpty);
  });
}
```

- [ ] **Step 5: Create `test/core/models/media_info_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/models/media_info.dart';

void main() {
  test('MediaInfo.fromJson decodes flat fields', () {
    final mi = MediaInfo.fromJson({
      'container': 'mkv',
      'video_codec': 'hevc',
      'video_width': 1920,
      'video_height': 1080,
      'audio_codec': 'aac',
      'audio_channels': 2,
      'duration_sec': 5430.0,
      'bit_rate': 8000000,
      'file_size': 4500000000,
    });
    expect(mi.videoCodec, 'hevc');
    expect(mi.videoWidth, 1920);
    expect(mi.audioChannels, 2);
    expect(mi.fileSize, 4500000000);
  });

  test('MediaInfo.fromJson with empty map yields all-null fields', () {
    final mi = MediaInfo.fromJson(const {});
    expect(mi.container, isNull);
    expect(mi.videoCodec, isNull);
  });
}
```

- [ ] **Step 6: Commit**

```bash
git add lib/core/models/related_movie.dart lib/core/models/related_file.dart lib/core/models/media_info.dart test/core/models/
git commit -m "feat(model): add RelatedMovie/RelatedFile/MediaInfo models"
```

---

## Task 4: Repository 新方法

**Files:**
- Modify: `lib/features/movies/movies_repository.dart`

**Background:** [movies_repository.dart](lib/features/movies/movies_repository.dart) 已有 `list()` 和 `detail()`. 现需新增 4 个方法包装 API + envelope。`MoviesRepository` 持有 `MoviesApi`，需要顺带持有 `FavoritesApi`（构造里加进来）。

- [ ] **Step 1: Replace `lib/features/movies/movies_repository.dart` content**

```dart
import '../../core/api/api_exception.dart';
import '../../core/api/envelope.dart';
import '../../core/api/services/favorites_api.dart';
import '../../core/api/services/movies_api.dart';
import '../../core/models/media_info.dart';
import '../../core/models/movie.dart';
import '../../core/models/paged_result.dart';
import 'movie_filter.dart';

class MoviesRepository {
  MoviesRepository(this._api, this._favorites);
  final MoviesApi _api;
  final FavoritesApi _favorites;

  Future<PagedResult<MovieListItem>> list(
    MovieFilter filter, {
    required int limit,
    required int offset,
  }) async {
    final raw = await _api.getMovies(filter.toQuery(limit: limit, offset: offset));
    return unwrapMovieList<MovieListItem>(raw, MovieListItem.fromJson);
  }

  Future<MovieDetail> detail(int id) async {
    final raw = await _api.getMovieDetail(id);
    return unwrapStd<MovieDetail>(
      raw,
      (d) => MovieDetail.fromJson(Map<String, dynamic>.from(d as Map)),
    );
  }

  Future<List<String>> extraFanarts(int id) async {
    final raw = await _api.getExtraFanarts(id);
    return unwrapStd<List<String>>(raw, (d) {
      if (d is List) {
        return d.whereType<String>().toList();
      }
      return const <String>[];
    });
  }

  Future<MediaInfo?> mediaInfo(int id) async {
    try {
      final raw = await _api.getMediaInfo(id);
      return unwrapStd<MediaInfo?>(raw, (d) {
        if (d is Map) {
          return MediaInfo.fromJson(Map<String, dynamic>.from(d));
        }
        return null;
      });
    } on ApiException {
      // backend returns 404 when no media info; surface as null instead of error
      return null;
    }
  }

  Future<bool> toggleFavorite(int id) async {
    final raw = await _favorites.toggle(id);
    return unwrapStd<bool>(raw, (d) {
      if (d is Map) {
        final v = d['is_favorited'];
        return v == true;
      }
      return false;
    });
  }

  Future<void> markWatched(int id, bool completed) async {
    await _api.upsertWatchRecord(id, {'completed': completed});
  }
}
```

- [ ] **Step 2: Update repository provider to inject FavoritesApi**

Edit `lib/features/movies/movies_providers.dart` `moviesRepositoryProvider`:

```dart
final moviesRepositoryProvider = Provider<MoviesRepository>((ref) {
  final client = ref.watch(requiredApiClientProvider);
  return MoviesRepository(client.movies, client.favorites);
});
```

- [ ] **Step 3: Update `_StubMoviesApi` consumers in tests**

`test/features/movies_repository_test.dart` constructs `MoviesRepository(api)` with single arg. Update to accept a stub favorites:

Add stub class at bottom of the test file:

```dart
class _StubFavoritesApi implements FavoritesApi {
  bool nextIsFavorited = true;

  @override
  Future<dynamic> toggle(int movieId) async => {
        'success': true,
        'message': 'ok',
        'data': {'movie_id': movieId, 'is_favorited': nextIsFavorited},
      };
}
```

Add import at top:
```dart
import 'package:md_center/core/api/services/favorites_api.dart';
```

Update both `MoviesRepository(api)` constructions to `MoviesRepository(api, _StubFavoritesApi())`.

- [ ] **Step 4: Commit**

```bash
git add lib/features/movies/movies_repository.dart lib/features/movies/movies_providers.dart test/features/movies_repository_test.dart
git commit -m "feat(repo): add extraFanarts/mediaInfo/toggleFavorite/markWatched"
```

---

## Task 5: Detail / ExtraFanart / MediaInfo providers

**Files:**
- Modify: `lib/features/movies/movies_providers.dart`

- [ ] **Step 1: Append providers**

Open `lib/features/movies/movies_providers.dart` and add at the bottom (keep existing 3 providers untouched):

```dart
import '../../core/models/media_info.dart';
import '../../core/models/movie.dart';

final movieDetailProvider = FutureProvider.autoDispose
    .family<MovieDetail, int>((ref, id) async {
  return ref.read(moviesRepositoryProvider).detail(id);
});

final extraFanartsProvider = FutureProvider.autoDispose
    .family<List<String>, int>((ref, id) async {
  return ref.read(moviesRepositoryProvider).extraFanarts(id);
});

final mediaInfoProvider = FutureProvider.autoDispose
    .family<MediaInfo?, int>((ref, id) async {
  return ref.read(moviesRepositoryProvider).mediaInfo(id);
});
```

If the existing file lacks `import` for `flutter_riverpod`, keep using the one at the top.

- [ ] **Step 2: Commit**

```bash
git add lib/features/movies/movies_providers.dart
git commit -m "feat(providers): add movieDetail/extraFanarts/mediaInfo family providers"
```

---

## Task 6: MainShell tab index → riverpod provider

**Files:**
- Create: `lib/features/main/main_shell_providers.dart`
- Modify: `lib/features/main/main_shell.dart`

**Background:** Spec §3.4 — 详情页关联导航需要远程切 tab。把 `_index` 从局部 state 提升到 `StateProvider`。

- [ ] **Step 1: Create `lib/features/main/main_shell_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// MainShell 底栏 tab 索引（0..4）。
/// 3 是"更多"，永远不会写入这里；写 3 的人请改成调用 onMoreTap。
final mainShellTabIndexProvider = StateProvider<int>((_) => 0);
```

- [ ] **Step 2: Replace `lib/features/main/main_shell.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/app_bottom_nav.dart';
import '../../core/ui/app_more_sheet.dart';
import '../dashboard/dashboard_page.dart';
import '../favorites/favorites_page.dart';
import '../movies/movies_page.dart';
import '../settings/settings_page.dart';
import 'main_shell_providers.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const _pageIndexMap = <int, int>{
    0: 0, // dashboard
    1: 1, // movies
    2: 2, // favorites
    4: 3, // settings (skip 3 = more)
  };

  static const _pages = <Widget>[
    DashboardPage(),
    MoviesPage(),
    FavoritesPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabIndex = ref.watch(mainShellTabIndexProvider);
    final pageIdx = _pageIndexMap[tabIndex] ?? 0;
    return Scaffold(
      body: IndexedStack(index: pageIdx, children: _pages),
      bottomNavigationBar: AppBottomNav(
        currentIndex: tabIndex,
        onTap: (i) => ref.read(mainShellTabIndexProvider.notifier).state = i,
        onMoreTap: () => showAppMoreSheet(context),
      ),
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/main/main_shell_providers.dart lib/features/main/main_shell.dart
git commit -m "refactor(shell): lift tab index into mainShellTabIndexProvider"
```

---

## Task 7: navigation.dart helper（applyFilterAndPop + navigateToMovie）

**Files:**
- Create: `lib/features/movies/detail/navigation.dart`

**Background:** Spec §3.2 — pill 跳列表过滤 = popUntil 根 + 切 movies tab + 注入 filter。`MovieFilter` 现有 `seriesIds/tagIds/genreIds/actorIds` list 字段直接复用（每次推一个单 ID list）。

- [ ] **Step 1: Create `lib/features/movies/detail/navigation.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main/main_shell_providers.dart';
import '../movie_filter.dart';
import '../movies_providers.dart';
import 'movie_detail_page.dart';

void applyFilterAndPop(
  BuildContext context,
  WidgetRef ref, {
  required MovieFilter filter,
}) {
  ref.read(movieFilterProvider.notifier).state = filter;
  ref.read(mainShellTabIndexProvider.notifier).state = 1;
  Navigator.of(context).popUntil((route) => route.isFirst);
}

void filterBySeries(BuildContext context, WidgetRef ref, int seriesId) {
  applyFilterAndPop(context, ref,
      filter: MovieFilter(seriesIds: [seriesId]));
}

void filterByTag(BuildContext context, WidgetRef ref, int tagId) {
  applyFilterAndPop(context, ref,
      filter: MovieFilter(tagIds: [tagId]));
}

void filterByGenre(BuildContext context, WidgetRef ref, int genreId) {
  applyFilterAndPop(context, ref,
      filter: MovieFilter(genreIds: [genreId]));
}

void filterByActor(BuildContext context, WidgetRef ref, int actorId) {
  applyFilterAndPop(context, ref,
      filter: MovieFilter(actorIds: [actorId]));
}

void navigateToMovie(BuildContext context, int movieId) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => MovieDetailPage(movieId: movieId)),
  );
}
```

- [ ] **Step 2: Commit**

(Will commit after Task 8 — `MovieDetailPage` doesn't exist yet, so the import will not resolve until Task 8. To commit cleanly, we sequence: create page skeleton first.)

Actually, **skip commit here**; let Task 8 commit them together.

---

## Task 8: MovieDetailPage skeleton (loading/error/data 三态)

**Files:**
- Create: `lib/features/movies/detail/movie_detail_page.dart`
- Create: `lib/features/movies/detail/movie_detail_content.dart`
- Test: `test/features/movies/detail/movie_detail_page_test.dart`

- [ ] **Step 1: Create `lib/features/movies/detail/movie_detail_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/tokens.dart';
import '../../../shared/error_view.dart';
import '../movies_providers.dart';
import 'movie_detail_content.dart';

class MovieDetailPage extends ConsumerWidget {
  const MovieDetailPage({super.key, required this.movieId});
  final int movieId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<AppColors>()!;
    final asyncMovie = ref.watch(movieDetailProvider(movieId));
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        foregroundColor: c.text,
        elevation: 0,
        title: asyncMovie.maybeWhen(
          data: (m) => Text(
            m.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text),
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
      body: asyncMovie.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(movieDetailProvider(movieId)),
        ),
        data: (movie) => MovieDetailContent(movie: movie),
      ),
    );
  }
}
```

- [ ] **Step 2: Create `lib/features/movies/detail/movie_detail_content.dart` (stub)**

```dart
import 'package:flutter/material.dart';

import '../../../core/models/movie.dart';

class MovieDetailContent extends StatelessWidget {
  const MovieDetailContent({super.key, required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(movie.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (movie.plot != null) Text(movie.plot!),
      ],
    );
  }
}
```

We'll flesh out the 10 sections in later tasks.

- [ ] **Step 3: Create `test/features/movies/detail/movie_detail_page_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/models/movie.dart';
import 'package:md_center/core/ui/theme.dart';
import 'package:md_center/features/movies/detail/movie_detail_page.dart';
import 'package:md_center/features/movies/movies_providers.dart';
import 'package:md_center/features/movies/movies_repository.dart';

class _FakeRepo implements MoviesRepository {
  _FakeRepo(this._detail);
  final MovieDetail _detail;

  @override
  Future<MovieDetail> detail(int id) async => _detail;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ErrRepo implements MoviesRepository {
  @override
  Future<MovieDetail> detail(int id) async => throw Exception('boom');
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget wrap(Widget child, MoviesRepository repo) => ProviderScope(
        overrides: [
          moviesRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(theme: appTheme(Brightness.light), home: child),
      );

  testWidgets('loading state shows CircularProgressIndicator', (tester) async {
    final repo = _FakeRepo(const MovieDetail(id: 1, title: 't'));
    await tester.pumpWidget(wrap(const MovieDetailPage(movieId: 1), repo));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('data state shows title in body', (tester) async {
    final repo = _FakeRepo(const MovieDetail(id: 1, title: '示例片名'));
    await tester.pumpWidget(wrap(const MovieDetailPage(movieId: 1), repo));
    await tester.pumpAndSettle();
    expect(find.text('示例片名'), findsWidgets);
  });

  testWidgets('error state shows ErrorView with retry', (tester) async {
    await tester.pumpWidget(wrap(const MovieDetailPage(movieId: 1), _ErrRepo()));
    await tester.pumpAndSettle();
    expect(find.text('重试'), findsOneWidget);
  });
}
```

`noSuchMethod` is intentional: tests only exercise `detail()` on the fake; any other call would (correctly) throw a NoSuchMethodError, signaling test scope violation.

- [ ] **Step 4: Commit (with navigation.dart from Task 7)**

```bash
git add lib/features/movies/detail/movie_detail_page.dart lib/features/movies/detail/movie_detail_content.dart lib/features/movies/detail/navigation.dart test/features/movies/detail/movie_detail_page_test.dart
git commit -m "feat(detail): add MovieDetailPage scaffolding and navigation helpers"
```

---

## Task 9: Wire MovieCard.onTap in MoviesPage + filter refresh listener

**Files:**
- Modify: `lib/features/movies/movies_page.dart`

**Background:** Spec §3.1 — MovieCard 点击跳详情。Spec §3.2 — `MoviesPage` 监听 `movieFilterProvider` 变化（来自详情页的 popOnFilter 调用）并 refresh `_controller`。

- [ ] **Step 1: Modify `lib/features/movies/movies_page.dart`**

Replace the entire file with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/movie.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_search_field.dart';
import '../../core/ui/tokens.dart';
import '../../shared/empty_view.dart';
import '../../shared/error_view.dart';
import '../../shared/movie_card.dart';
import 'detail/movie_detail_page.dart';
import 'movie_filter.dart';
import 'movies_providers.dart';

class MoviesPage extends ConsumerStatefulWidget {
  const MoviesPage({super.key});

  @override
  ConsumerState<MoviesPage> createState() => _MoviesPageState();
}

class _MoviesPageState extends ConsumerState<MoviesPage> {
  static const _pageSize = 50;
  final _controller = PagingController<int, MovieListItem>(firstPageKey: 0);
  final _searchController = TextEditingController();
  MovieFilter _currentFilter = const MovieFilter();

  @override
  void initState() {
    super.initState();
    _controller.addPageRequestListener(_fetch);
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetch(int offset) async {
    try {
      final repo = ref.read(moviesRepositoryProvider);
      final page = await repo.list(_currentFilter,
          limit: _pageSize, offset: offset);
      final nextOffset = offset + page.items.length;
      if (nextOffset >= page.totalCount || page.items.isEmpty) {
        _controller.appendLastPage(page.items);
      } else {
        _controller.appendPage(page.items, nextOffset);
      }
    } catch (e) {
      _controller.error = toApiException(e).message;
    }
  }

  void _applyFilter(MovieFilter next) {
    if (next == _currentFilter) return;
    setState(() => _currentFilter = next);
    _searchController.text = next.search ?? '';
    _controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final urlBuilder = ref.watch(imageUrlBuilderProvider);
    final c = Theme.of(context).extension<AppColors>()!;

    ref.listen<MovieFilter>(movieFilterProvider, (prev, next) {
      _applyFilter(next);
    });

    return AppScaffold(
      body: AppPage(
        title: '影片库',
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l, 0, AppSpacing.l, AppSpacing.m,
              ),
              child: AppSearchField(
                controller: _searchController,
                placeholder: '搜索片名 / 演员 / 标签',
                onSubmitted: (v) {
                  ref.read(movieFilterProvider.notifier).state =
                      _currentFilter.copyWith(search: v);
                },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
            sliver: PagedSliverGrid<int, MovieListItem>(
              pagingController: _controller,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.55,
                mainAxisSpacing: AppSpacing.s,
                crossAxisSpacing: AppSpacing.s,
              ),
              builderDelegate: PagedChildBuilderDelegate<MovieListItem>(
                itemBuilder: (ctx, item, idx) => MovieCard(
                  movie: item,
                  posterUrlBuilder: urlBuilder,
                  onTap: () => Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (_) => MovieDetailPage(movieId: item.id),
                    ),
                  ),
                ),
                firstPageErrorIndicatorBuilder: (_) => ErrorView(
                  message: _controller.error?.toString() ?? '加载失败',
                  onRetry: () => _controller.refresh(),
                ),
                newPageErrorIndicatorBuilder: (_) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  child: TextButton(
                    onPressed: () => _controller.retryLastFailedRequest(),
                    child: Text(
                      '加载失败，点击重试：${_controller.error}',
                      style: TextStyle(color: c.brand),
                    ),
                  ),
                ),
                noItemsFoundIndicatorBuilder: (_) =>
                    const EmptyView(message: '没有找到符合条件的影片'),
                firstPageProgressIndicatorBuilder: (_) => Center(
                  child: CircularProgressIndicator(color: c.brand),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/movies/movies_page.dart
git commit -m "feat(movies): tap card opens detail; listen filter provider"
```

---

## Task 10: Hero section

**Files:**
- Create: `lib/features/movies/detail/sections/hero_section.dart`

**Background:** Spec §4.2 块 1 — fanart 横图作为背景（aspect 16/9），底部覆盖海报 + 标题 + 番号 pill + 年份。

- [ ] **Step 1: Create `lib/features/movies/detail/sections/hero_section.dart`**

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/movie.dart';
import '../../../../core/ui/tokens.dart';
import '../../movies_providers.dart';

class HeroSection extends ConsumerWidget {
  const HeroSection({super.key, required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<AppColors>()!;
    final urlBuilder = ref.watch(imageUrlBuilderProvider);
    final fanart = movie.fanartUuid;
    final poster = movie.posterUuid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (fanart != null)
                CachedNetworkImage(
                  imageUrl: urlBuilder(fanart),
                  fit: BoxFit.cover,
                  placeholder: (_, __) => ColoredBox(color: c.surface),
                  errorWidget: (_, __, ___) => ColoredBox(color: c.surface),
                )
              else
                ColoredBox(color: c.surface),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 80,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.bg.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l, AppSpacing.m, AppSpacing.l, AppSpacing.s,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.poster),
                    child: poster != null
                        ? CachedNetworkImage(
                            imageUrl: urlBuilder(poster),
                            fit: BoxFit.cover,
                            placeholder: (_, __) => ColoredBox(color: c.surface),
                            errorWidget: (_, __, ___) =>
                                ColoredBox(color: c.surface),
                          )
                        : ColoredBox(color: c.surface),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (movie.num != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.surfaceVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              movie.num!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                color: c.text,
                              ),
                            ),
                          ),
                        if (movie.year != null)
                          Text(
                            '${movie.year}',
                            style: TextStyle(
                                fontSize: 13, color: c.textMuted),
                          ),
                        if (movie.runtime != null)
                          Text(
                            '${movie.runtime} 分钟',
                            style: TextStyle(
                                fontSize: 13, color: c.textMuted),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/movies/detail/sections/hero_section.dart
git commit -m "feat(detail): add hero section with fanart, poster, title"
```

---

## Task 11: Actions section (收藏 + 标记看完)

**Files:**
- Create: `lib/features/movies/detail/movie_detail_actions.dart`
- Test: `test/features/movies/detail/movie_detail_actions_test.dart`

**Background:** Spec §4.2 块 2 — 两个 FilledButton 并列。Spec D4 — "标记看完" 大动作按钮。点击调 repository，成功后 invalidate `movieDetailProvider(id)` 让页面 rebuild。Loading 时按钮 disabled + 小 spinner。

- [ ] **Step 1: Create `lib/features/movies/detail/movie_detail_actions.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/movie.dart';
import '../../../core/ui/tokens.dart';
import '../movies_providers.dart';

class MovieDetailActions extends ConsumerStatefulWidget {
  const MovieDetailActions({super.key, required this.movie});
  final MovieDetail movie;

  @override
  ConsumerState<MovieDetailActions> createState() => _MovieDetailActionsState();
}

class _MovieDetailActionsState extends ConsumerState<MovieDetailActions> {
  bool _favoriteLoading = false;
  bool _watchedLoading = false;

  Future<void> _toggleFavorite() async {
    setState(() => _favoriteLoading = true);
    try {
      await ref.read(moviesRepositoryProvider).toggleFavorite(widget.movie.id);
      ref.invalidate(movieDetailProvider(widget.movie.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('收藏操作失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _favoriteLoading = false);
    }
  }

  Future<void> _toggleWatched() async {
    final current = widget.movie.watchRecord?.completed ?? false;
    setState(() => _watchedLoading = true);
    try {
      await ref.read(moviesRepositoryProvider).markWatched(widget.movie.id, !current);
      ref.invalidate(movieDetailProvider(widget.movie.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('观看状态更新失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _watchedLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final favorited = widget.movie.isFavorited;
    final completed = widget.movie.watchRecord?.completed ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.l, AppSpacing.s, AppSpacing.l, AppSpacing.l),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _favoriteLoading ? null : _toggleFavorite,
              style: FilledButton.styleFrom(
                backgroundColor: favorited ? c.surface : c.brand,
                foregroundColor: favorited ? c.text : c.brandOn,
              ),
              icon: _favoriteLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(favorited ? Icons.favorite : Icons.favorite_outline),
              label: Text(favorited ? '已收藏' : '收藏'),
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: FilledButton.icon(
              onPressed: _watchedLoading ? null : _toggleWatched,
              style: FilledButton.styleFrom(
                backgroundColor: completed ? c.surface : c.brand,
                foregroundColor: completed ? c.text : c.brandOn,
              ),
              icon: _watchedLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(completed
                      ? Icons.check_circle
                      : Icons.check_circle_outline),
              label: Text(completed ? '已看完' : '标记看完'),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Create `test/features/movies/detail/movie_detail_actions_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/models/movie.dart';
import 'package:md_center/core/ui/theme.dart';
import 'package:md_center/features/movies/detail/movie_detail_actions.dart';
import 'package:md_center/features/movies/movies_providers.dart';
import 'package:md_center/features/movies/movies_repository.dart';

class _RecordingRepo implements MoviesRepository {
  bool? toggledFavorite;
  bool? markedCompleted;

  @override
  Future<bool> toggleFavorite(int id) async {
    toggledFavorite = true;
    return true;
  }

  @override
  Future<void> markWatched(int id, bool completed) async {
    markedCompleted = completed;
  }

  @override
  Future<MovieDetail> detail(int id) async =>
      const MovieDetail(id: 1, title: 't');

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget wrap(Widget child, MoviesRepository repo) => ProviderScope(
        overrides: [moviesRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(theme: appTheme(Brightness.light), home: Scaffold(body: child)),
      );

  testWidgets('shows "收藏" when not favorited', (tester) async {
    await tester.pumpWidget(wrap(
      const MovieDetailActions(movie: MovieDetail(id: 1, title: 't')),
      _RecordingRepo(),
    ));
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('已收藏'), findsNothing);
  });

  testWidgets('shows "已收藏" when isFavorited=true', (tester) async {
    await tester.pumpWidget(wrap(
      const MovieDetailActions(
          movie: MovieDetail(id: 1, title: 't', isFavorited: true)),
      _RecordingRepo(),
    ));
    expect(find.text('已收藏'), findsOneWidget);
  });

  testWidgets('shows "标记看完" when not completed', (tester) async {
    await tester.pumpWidget(wrap(
      const MovieDetailActions(movie: MovieDetail(id: 1, title: 't')),
      _RecordingRepo(),
    ));
    expect(find.text('标记看完'), findsOneWidget);
  });

  testWidgets('shows "已看完" when watchRecord.completed=true', (tester) async {
    await tester.pumpWidget(wrap(
      const MovieDetailActions(
        movie: MovieDetail(
          id: 1,
          title: 't',
          watchRecord: WatchRecordSummary(progressRatio: 1, completed: true),
        ),
      ),
      _RecordingRepo(),
    ));
    expect(find.text('已看完'), findsOneWidget);
  });

  testWidgets('tap on favorite button calls repository.toggleFavorite', (tester) async {
    final repo = _RecordingRepo();
    await tester.pumpWidget(wrap(
      const MovieDetailActions(movie: MovieDetail(id: 1, title: 't')),
      repo,
    ));
    await tester.tap(find.text('收藏'));
    await tester.pump();
    expect(repo.toggledFavorite, true);
  });

  testWidgets('tap on watched button calls repository.markWatched(true)', (tester) async {
    final repo = _RecordingRepo();
    await tester.pumpWidget(wrap(
      const MovieDetailActions(movie: MovieDetail(id: 1, title: 't')),
      repo,
    ));
    await tester.tap(find.text('标记看完'));
    await tester.pump();
    expect(repo.markedCompleted, true);
  });
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/movies/detail/movie_detail_actions.dart test/features/movies/detail/movie_detail_actions_test.dart
git commit -m "feat(detail): add actions row (favorite + mark watched)"
```

---

## Task 12: Info section + InfoItemRow widget

**Files:**
- Create: `lib/features/movies/detail/widgets/info_item_row.dart`
- Create: `lib/features/movies/detail/sections/info_section.dart`
- Test: `test/features/movies/detail/sections/info_section_test.dart`

**Background:** Spec §4.2 块 3 — 元信息条目（番号/年份/评分/时长/国家/文件大小/最近下载）。缺字段跳过。

- [ ] **Step 1: Create `lib/features/movies/detail/widgets/info_item_row.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../../core/ui/tokens.dart';

class InfoItemRow extends StatelessWidget {
  const InfoItemRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: c.textMuted),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: c.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: c.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Create `lib/features/movies/detail/sections/info_section.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../../core/models/movie.dart';
import '../../../../core/ui/tokens.dart';
import '../widgets/info_item_row.dart';

class InfoSection extends StatelessWidget {
  const InfoSection({super.key, required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    if (movie.num != null && movie.num!.isNotEmpty) {
      rows.add(InfoItemRow(icon: Icons.qr_code, label: '番号', value: movie.num!));
    }
    if (movie.year != null) {
      rows.add(InfoItemRow(icon: Icons.calendar_today, label: '年份', value: '${movie.year}'));
    }
    if (movie.rating != null && movie.rating! > 0) {
      rows.add(InfoItemRow(
          icon: Icons.star, label: '评分', value: movie.rating!.toStringAsFixed(1)));
    }
    if (movie.runtime != null && movie.runtime! > 0) {
      rows.add(InfoItemRow(
          icon: Icons.schedule, label: '时长', value: _formatRuntime(movie.runtime!)));
    }
    if (movie.country != null && movie.country!.isNotEmpty) {
      rows.add(InfoItemRow(icon: Icons.public, label: '国家', value: movie.country!));
    }
    final size = movie.fileSize;
    if (size != null && size > 0) {
      rows.add(InfoItemRow(icon: Icons.storage, label: '大小', value: _formatFileSize(size)));
    }
    if (movie.lastDownloadedAt != null && movie.lastDownloadedAt!.isNotEmpty) {
      rows.add(InfoItemRow(
          icon: Icons.cloud_download,
          label: '最近下载',
          value: _formatDate(movie.lastDownloadedAt!)));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
    );
  }

  String _formatRuntime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) return '$h 小时 $m 分钟';
    return '$m 分钟';
  }

  String _formatFileSize(int size) {
    if (size >= 1073741824) return '${(size / 1073741824).toStringAsFixed(1)} GB';
    if (size >= 1048576) return '${(size / 1048576).round()} MB';
    if (size >= 1024) return '${(size / 1024).round()} KB';
    return '$size B';
  }

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
```

- [ ] **Step 3: Create `test/features/movies/detail/sections/info_section_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/models/movie.dart';
import 'package:md_center/core/ui/theme.dart';
import 'package:md_center/features/movies/detail/sections/info_section.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: appTheme(Brightness.light),
        home: Scaffold(body: child),
      );

  testWidgets('renders only fields that are present', (tester) async {
    await tester.pumpWidget(wrap(const InfoSection(
      movie: MovieDetail(id: 1, title: 't', num: 'ABC-001', year: 2020),
    )));
    expect(find.text('ABC-001'), findsOneWidget);
    expect(find.text('2020'), findsOneWidget);
    expect(find.text('国家'), findsNothing);
    expect(find.text('评分'), findsNothing);
  });

  testWidgets('formats file size 4500000000 as 4.2 GB', (tester) async {
    await tester.pumpWidget(wrap(const InfoSection(
      movie: MovieDetail(id: 1, title: 't', fileSize: 4500000000),
    )));
    expect(find.text('4.2 GB'), findsOneWidget);
  });

  testWidgets('formats runtime 125 minutes as 2 小时 5 分钟', (tester) async {
    await tester.pumpWidget(wrap(const InfoSection(
      movie: MovieDetail(id: 1, title: 't', runtime: 125),
    )));
    expect(find.text('2 小时 5 分钟'), findsOneWidget);
  });

  testWidgets('empty data renders nothing visible', (tester) async {
    await tester.pumpWidget(wrap(const InfoSection(
      movie: MovieDetail(id: 1, title: 't'),
    )));
    expect(find.byType(InfoSection), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
  });
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/movies/detail/widgets/info_item_row.dart lib/features/movies/detail/sections/info_section.dart test/features/movies/detail/sections/info_section_test.dart
git commit -m "feat(detail): add info section with formatted rows"
```

---

## Task 13: Plot section

**Files:**
- Create: `lib/features/movies/detail/sections/plot_section.dart`

**Background:** Spec §4.2 块 4 — `plot` fallback `outline`，默认 4 行，"展开" 切换。

- [ ] **Step 1: Create `lib/features/movies/detail/sections/plot_section.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../../core/models/movie.dart';
import '../../../../core/ui/tokens.dart';

class PlotSection extends StatefulWidget {
  const PlotSection({super.key, required this.movie});
  final MovieDetail movie;

  @override
  State<PlotSection> createState() => _PlotSectionState();
}

class _PlotSectionState extends State<PlotSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = (widget.movie.plot != null && widget.movie.plot!.isNotEmpty)
        ? widget.movie.plot!
        : widget.movie.outline;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    final c = Theme.of(context).extension<AppColors>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.l, AppSpacing.s, AppSpacing.l, AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Heading('剧情简介', c),
          const SizedBox(height: AppSpacing.s),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topLeft,
            child: Text(
              text,
              maxLines: _expanded ? null : 4,
              overflow:
                  _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: c.text, height: 1.55),
            ),
          ),
          if (_shouldShowToggle(text))
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _expanded ? '收起' : '展开',
                style: TextStyle(color: c.brand, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  bool _shouldShowToggle(String text) {
    // Approximate: any text long enough to plausibly exceed 4 lines.
    // 50 chars/line × 4 lines is a rough threshold.
    return text.length > 200;
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, this.c);
  final String text;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w700, color: c.text),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/movies/detail/sections/plot_section.dart
git commit -m "feat(detail): add plot section with expand toggle"
```

---

## Task 14: Taxonomy section + TaxonomyPill + ActorChip

**Files:**
- Create: `lib/features/movies/detail/widgets/taxonomy_pill.dart`
- Create: `lib/features/movies/detail/widgets/actor_chip.dart`
- Create: `lib/features/movies/detail/sections/taxonomy_section.dart`
- Test: `test/features/movies/detail/sections/taxonomy_section_test.dart`

**Background:** Spec §4.2 块 5 — 4 个子块（系列/标签/分类/演员）。空块整块不显示。点击 → 跳列表过滤。

- [ ] **Step 1: Create `lib/features/movies/detail/widgets/taxonomy_pill.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../../core/ui/tokens.dart';

class TaxonomyPill extends StatelessWidget {
  const TaxonomyPill({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: c.text),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Create `lib/features/movies/detail/widgets/actor_chip.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../../core/ui/tokens.dart';

class ActorChip extends StatelessWidget {
  const ActorChip({
    super.key,
    required this.name,
    required this.onTap,
  });

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final initial = name.isNotEmpty ? name.substring(0, 1) : '?';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: c.surface,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: c.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: c.text),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Create `lib/features/movies/detail/sections/taxonomy_section.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/movie.dart';
import '../../../../core/ui/tokens.dart';
import '../navigation.dart';
import '../widgets/actor_chip.dart';
import '../widgets/taxonomy_pill.dart';

class TaxonomySection extends ConsumerWidget {
  const TaxonomySection({super.key, required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<AppColors>()!;
    final blocks = <Widget>[];

    if (movie.series != null) {
      blocks.add(_block(
        c: c,
        title: '系列',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TaxonomyPill(
              label: movie.series!.name,
              onTap: () => filterBySeries(context, ref, movie.series!.id),
            ),
          ],
        ),
      ));
    }
    if (movie.tags.isNotEmpty) {
      blocks.add(_block(
        c: c,
        title: '标签',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: movie.tags
              .map((t) => TaxonomyPill(
                    label: t.name,
                    onTap: () => filterByTag(context, ref, t.id),
                  ))
              .toList(),
        ),
      ));
    }
    if (movie.genres.isNotEmpty) {
      blocks.add(_block(
        c: c,
        title: '分类',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: movie.genres
              .map((g) => TaxonomyPill(
                    label: g.name,
                    onTap: () => filterByGenre(context, ref, g.id),
                  ))
              .toList(),
        ),
      ));
    }
    if (movie.actors.isNotEmpty) {
      blocks.add(_block(
        c: c,
        title: '演员',
        child: SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: movie.actors.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final a = movie.actors[i];
              return ActorChip(
                name: a.name,
                onTap: () => filterByActor(context, ref, a.id),
              );
            },
          ),
        ),
      ));
    }

    if (blocks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: blocks,
      ),
    );
  }

  Widget _block({required AppColors c, required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: c.text),
          ),
          const SizedBox(height: AppSpacing.s),
          child,
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Create `test/features/movies/detail/sections/taxonomy_section_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/models/actor.dart';
import 'package:md_center/core/models/movie.dart';
import 'package:md_center/core/models/resource.dart';
import 'package:md_center/core/ui/theme.dart';
import 'package:md_center/features/movies/detail/sections/taxonomy_section.dart';

void main() {
  Widget wrap(Widget child) => ProviderScope(
        child: MaterialApp(
          theme: appTheme(Brightness.light),
          home: Scaffold(body: child),
        ),
      );

  testWidgets('empty movie renders nothing', (tester) async {
    await tester.pumpWidget(wrap(const TaxonomySection(
      movie: MovieDetail(id: 1, title: 't'),
    )));
    expect(find.text('系列'), findsNothing);
    expect(find.text('标签'), findsNothing);
    expect(find.text('分类'), findsNothing);
    expect(find.text('演员'), findsNothing);
  });

  testWidgets('renders only sections with content', (tester) async {
    await tester.pumpWidget(wrap(const TaxonomySection(
      movie: MovieDetail(
        id: 1,
        title: 't',
        tags: [ResourceItem(id: 1, name: '标签 A')],
        actors: [ActorItem(id: 2, name: '演员 X')],
      ),
    )));
    expect(find.text('标签'), findsOneWidget);
    expect(find.text('标签 A'), findsOneWidget);
    expect(find.text('演员'), findsOneWidget);
    expect(find.text('演员 X'), findsOneWidget);
    expect(find.text('系列'), findsNothing);
    expect(find.text('分类'), findsNothing);
  });
}
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/movies/detail/widgets/taxonomy_pill.dart lib/features/movies/detail/widgets/actor_chip.dart lib/features/movies/detail/sections/taxonomy_section.dart test/features/movies/detail/sections/taxonomy_section_test.dart
git commit -m "feat(detail): add taxonomy section (series/tags/genres/actors)"
```

---

## Task 15: RelatedMovies section + RelatedMovieCard

**Files:**
- Create: `lib/features/movies/detail/widgets/related_movie_card.dart`
- Create: `lib/features/movies/detail/sections/related_movies_section.dart`

**Background:** Spec §4.2 块 6/8 — 分片影片 + 演员关联影片，共用同一个 section（不同 title）。横向 ListView。

- [ ] **Step 1: Create `lib/features/movies/detail/widgets/related_movie_card.dart`**

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/related_movie.dart';
import '../../../../core/ui/tokens.dart';
import '../../movies_providers.dart';

class RelatedMovieCard extends ConsumerWidget {
  const RelatedMovieCard({
    super.key,
    required this.movie,
    required this.onTap,
  });

  final RelatedMovie movie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<AppColors>()!;
    final urlBuilder = ref.watch(imageUrlBuilderProvider);
    final uuid = movie.posterUuid ?? movie.thumbUuid ?? movie.fanartUuid;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.poster),
      child: SizedBox(
        width: 96,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.poster),
                child: uuid != null
                    ? CachedNetworkImage(
                        imageUrl: urlBuilder(uuid),
                        fit: BoxFit.cover,
                        placeholder: (_, __) => ColoredBox(color: c.surface),
                        errorWidget: (_, __, ___) =>
                            ColoredBox(color: c.surface),
                      )
                    : ColoredBox(color: c.surface),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              movie.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: c.text),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Create `lib/features/movies/detail/sections/related_movies_section.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../../core/models/related_movie.dart';
import '../../../../core/ui/tokens.dart';
import '../navigation.dart';
import '../widgets/related_movie_card.dart';

class RelatedMoviesSection extends StatelessWidget {
  const RelatedMoviesSection({
    super.key,
    required this.title,
    required this.movies,
  });

  final String title;
  final List<RelatedMovie> movies;

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SizedBox.shrink();
    final c = Theme.of(context).extension<AppColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: c.text),
          ),
          const SizedBox(height: AppSpacing.s),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: movies.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final m = movies[i];
                return RelatedMovieCard(
                  movie: m,
                  onTap: () => navigateToMovie(context, m.id),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.l),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/movies/detail/widgets/related_movie_card.dart lib/features/movies/detail/sections/related_movies_section.dart
git commit -m "feat(detail): add related movies section and card"
```

---

## Task 16: ExtraFanart section + FanartGallery

**Files:**
- Create: `lib/features/movies/detail/widgets/fanart_gallery.dart`
- Create: `lib/features/movies/detail/sections/extra_fanart_section.dart`

**Background:** Spec §4.2 块 7 + §4.3 — 横向缩略图 + 点击进全屏。Backend 返回字符串 URL list（path 形式），需要拼 server baseUrl。

- [ ] **Step 1: Create `lib/features/movies/detail/widgets/fanart_gallery.dart`**

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class FanartGallery extends StatefulWidget {
  const FanartGallery({super.key, required this.urls, this.initialIndex = 0});
  final List<String> urls;
  final int initialIndex;

  @override
  State<FanartGallery> createState() => _FanartGalleryState();
}

class _FanartGalleryState extends State<FanartGallery> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.urls[i],
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '${_index + 1} / ${widget.urls.length}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Create `lib/features/movies/detail/sections/extra_fanart_section.dart`**

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/server_config_provider.dart';
import '../../../../core/ui/tokens.dart';
import '../../movies_providers.dart';
import '../widgets/fanart_gallery.dart';

class ExtraFanartSection extends ConsumerWidget {
  const ExtraFanartSection({super.key, required this.movieId});
  final int movieId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<AppColors>()!;
    final cfg = ref.watch(serverConfigProvider);
    final baseUrl = cfg?.baseUrl ?? '';
    final asyncList = ref.watch(extraFanartsProvider(movieId));
    return asyncList.maybeWhen(
      data: (paths) {
        if (paths.isEmpty) return const SizedBox.shrink();
        final urls = paths.map((p) => '$baseUrl$p').toList();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '预览图',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: c.text),
              ),
              const SizedBox(height: AppSpacing.s),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: urls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => FanartGallery(
                              urls: urls, initialIndex: i),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        child: CachedNetworkImage(
                          imageUrl: urls[i],
                          fit: BoxFit.cover,
                          placeholder: (_, __) => ColoredBox(color: c.surface),
                          errorWidget: (_, __, ___) =>
                              ColoredBox(color: c.surface),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.l),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/movies/detail/widgets/fanart_gallery.dart lib/features/movies/detail/sections/extra_fanart_section.dart
git commit -m "feat(detail): add extra fanart section with full-screen InteractiveViewer"
```

---

## Task 17: MediaInfo section

**Files:**
- Create: `lib/features/movies/detail/sections/media_info_section.dart`

**Background:** Spec §4.2 块 9 — backend 扁平 model 拆 3 个子块（容器/视频/音频）。

- [ ] **Step 1: Create `lib/features/movies/detail/sections/media_info_section.dart`**

```dart
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/movies/detail/sections/media_info_section.dart
git commit -m "feat(detail): add media info section (container/video/audio)"
```

---

## Task 18: FilePaths section

**Files:**
- Create: `lib/features/movies/detail/sections/file_paths_section.dart`

**Background:** Spec §4.2 块 10 — 文件路径列表。`MovieDetail.relatedFiles` 是 `RelatedFile[]`，每条 `{type, label, path}`。如果为空，只显示 `filePath`。

- [ ] **Step 1: Create `lib/features/movies/detail/sections/file_paths_section.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/movie.dart';
import '../../../../core/ui/tokens.dart';

class FilePathsSection extends StatelessWidget {
  const FilePathsSection({super.key, required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final items = <_Entry>[];
    if (movie.relatedFiles.isNotEmpty) {
      for (final rf in movie.relatedFiles) {
        items.add(_Entry(label: rf.label ?? rf.type ?? '文件', path: rf.path));
      }
    } else if (movie.filePath != null && movie.filePath!.isNotEmpty) {
      items.add(_Entry(label: '影片文件', path: movie.filePath!));
    }
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '文件',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: c.text),
          ),
          const SizedBox(height: AppSpacing.s),
          ...items.map((e) => _PathTile(entry: e, c: c)),
          const SizedBox(height: AppSpacing.l),
        ],
      ),
    );
  }
}

class _Entry {
  const _Entry({required this.label, required this.path});
  final String label;
  final String path;
}

class _PathTile extends StatelessWidget {
  const _PathTile({required this.entry, required this.c});
  final _Entry entry;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: () async {
        await Clipboard.setData(ClipboardData(text: entry.path));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已复制：${entry.path}')),
        );
      },
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: c.textMuted),
            ),
            const SizedBox(height: 2),
            Text(
              entry.path,
              style: TextStyle(
                fontSize: 12,
                color: c.text,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/movies/detail/sections/file_paths_section.dart
git commit -m "feat(detail): add file paths section with long-press copy"
```

---

## Task 19: 串起 MovieDetailContent

**Files:**
- Modify: `lib/features/movies/detail/movie_detail_content.dart`

**Background:** 把 10 个 section 按 spec §4.2 顺序拼起来。

- [ ] **Step 1: Replace `lib/features/movies/detail/movie_detail_content.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../core/models/movie.dart';
import 'movie_detail_actions.dart';
import 'sections/extra_fanart_section.dart';
import 'sections/file_paths_section.dart';
import 'sections/hero_section.dart';
import 'sections/info_section.dart';
import 'sections/media_info_section.dart';
import 'sections/plot_section.dart';
import 'sections/related_movies_section.dart';
import 'sections/taxonomy_section.dart';

class MovieDetailContent extends StatelessWidget {
  const MovieDetailContent({super.key, required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        HeroSection(movie: movie),
        MovieDetailActions(movie: movie),
        InfoSection(movie: movie),
        PlotSection(movie: movie),
        TaxonomySection(movie: movie),
        RelatedMoviesSection(title: '分片', movies: movie.partMovies),
        ExtraFanartSection(movieId: movie.id),
        RelatedMoviesSection(title: '同演员其他影片', movies: movie.actorRelatedMovies),
        MediaInfoSection(movieId: movie.id),
        FilePathsSection(movie: movie),
        const SizedBox(height: 24),
      ],
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/movies/detail/movie_detail_content.dart
git commit -m "feat(detail): compose 10 sections into MovieDetailContent"
```

---

## Task 20: Final analyze + smoke checklist

This task is a manual review hook — no code changes, just a verification checklist for the controller.

- [ ] **Step 1: Verify file structure matches the plan**

Run from project root (PowerShell / Bash):
```
ls lib/features/movies/detail/
ls lib/features/movies/detail/sections/
ls lib/features/movies/detail/widgets/
```

Expect exactly the files listed in "File Structure" section at the top of this plan.

- [ ] **Step 2: Verify imports resolve and no `core/platform/` ghosts**

`grep -rn "core/platform/" lib/ test/` — expect zero matches.
`grep -rn "movies/{id}\"" lib/` — expect zero matches (must be `movies/id/{id}` now).

- [ ] **Step 3: Verify all 10 sections present**

`grep -rn "class.*Section\b" lib/features/movies/detail/sections/` should list:
- HeroSection
- InfoSection
- PlotSection
- TaxonomySection
- RelatedMoviesSection (used twice in content)
- ExtraFanartSection
- MediaInfoSection
- FilePathsSection

8 unique section classes (Hero + Actions + Info + Plot + Taxonomy + Related[×2] + ExtraFanart + MediaInfo + FilePaths = 10 visual blocks but 9 classes since Related is shared, and Actions is in `movie_detail_actions.dart` not `sections/`).

- [ ] **Step 4: Backend route audit**

Confirm `lib/core/api/services/movies_api.dart` and `favorites_api.dart` paths all match Backend (spec §11). No `extra-fanarts`, no `mediainfo`. All movie item endpoints have `/id/{id}/...`.

- [ ] **Step 5: Manual smoke (when device available)**

When user tests on a device:
- Tap a MovieCard → detail loads
- Title in AppBar matches movie title
- 10 sections render top→down: Hero / Actions / Info / Plot / Taxonomy / Parts / Extra Fanart / Actor Related / Media Info / Files
- Toggle 收藏 → button switches state, no error
- Toggle 标记看完 → button switches state
- Tap a taxonomy pill (series/tag/genre/actor) → pops to movies tab with the right filter
- Tap a related movie card → opens that movie's detail
- Tap a fanart thumbnail → full-screen viewer, pinch to zoom, swipe to page, close button works
- Long-press a file path → SnackBar "已复制"

- [ ] **Step 6: Commit any documentation fixes uncovered**

If smoke surfaces issues not in plan scope (e.g., spacing tweaks, label typos), file follow-ups but don't block.

---

## Self-Review

**Spec coverage:**
- §3.1 路由（MovieCard.onTap → push detail） → Task 9 ✓
- §3.2 关联导航 6 类（series/tag/genre/actor pill + part/actor-related card） → Task 7 + 14 + 15 ✓
- §3.3 MovieFilter — 不需要扩字段（既有 list 入参满足），spec §5.1 提到的 "加 4 个字段" overruled ✓
- §3.4 MainShell tab index → provider → Task 6 ✓
- §4.1 page 三态 → Task 8 ✓
- §4.2 10 个 section → Tasks 10–18 ✓
- §4.3 FanartGallery 全屏 → Task 16 ✓
- §4.4 ActorChip → Task 14 ✓
- §5.1 MovieDetail 字段扩 → Task 2 ✓
- §5.2 3 个新 model → Task 3 ✓
- §5.3 API 修路径 + 新 endpoints → Task 1 ✓
- §5.4 Repository 4 新方法 → Task 4 ✓
- §5.5 Provider → Task 5 ✓
- §6 文件结构 → 全部 Task 文件创建顺序符合 ✓
- §7 复用 vs 新建 → ActorChip / TaxonomyPill / RelatedMovieCard / InfoItemRow / FanartGallery 都建了 ✓
- §8 错误 & 边界 → ExtraFanart/MediaInfo `maybeWhen` orElse 不显示；`relatedFiles` 空 fallback `filePath`；invalid date `tryParse` safe；favorite/markWatched try/catch + SnackBar ✓
- §9 测试 — 5 个测试文件覆盖：movie_detail_page / movie_detail_actions / info_section / taxonomy_section / related_movie + media_info model ✓（plan 中的 movie_filter_test 不需要因为没扩字段；fanart_gallery_test 因为价值低省略 — 见 spec §9 self-review）
- §10 YAGNI — 没碰，全在 Sub 3 ✓
- §11 backend 已确认 ✓

**Placeholder scan:** ✓ 无 TBD / TODO 残留。Task 14 用 ResourceItem / ActorItem 的具体字段名（id/name）已确认（[lib/core/models/resource.dart](lib/core/models/resource.dart) 和 [actor.dart](lib/core/models/actor.dart) 现有）。

**Type consistency:**
- `MoviesRepository(api)` → `MoviesRepository(api, favorites)` 两 arg — Task 4 改 + Task 4 同时更新所有调用方 ✓
- `RelatedMovie.posterUuid` / `thumbUuid` / `fanartUuid` → Task 3 定义；Task 15 RelatedMovieCard 使用 ✓
- `MovieDetail.partMovies` / `actorRelatedMovies` / `relatedFiles` → Task 2 定义；Task 19 使用 ✓
- `mainShellTabIndexProvider` → Task 6 定义；Task 7 navigation.dart 使用 ✓
- `movieDetailProvider(id)` `extraFanartsProvider(id)` `mediaInfoProvider(id)` → Task 5 定义；Tasks 8/11/16/17 使用 ✓
