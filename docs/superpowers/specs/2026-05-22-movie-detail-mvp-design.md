# Movie Detail MVP（Sub 1）设计稿

定稿日期：2026-05-22

## 1. 目标

mobile_app 当前点 MovieCard 没反应。本 spec 是详情页"看 + 个人态"层的实现：

- 把 PWA `MovieDetailContent.vue` 的 **10 个信息块全部展示**（不含编辑/同步/下载/外部播放等管理类动作 — 留给后续 Sub 3）
- 实现两个用户高频动作：**收藏切换** 和 **标记看完/未看**
- 详情页内的关联导航能力（pill 跳过滤列表 / 卡片跳别的详情页）全部接入

不在本轮：内置播放器（Sub 2）、所有 modal 类管理操作（Sub 3）、字幕编辑器（已明确排除）、Thunder 字幕下载、NFO 同步、Extra Fanart **下载**（仅展示）。

## 2. 决策表

| # | 决策 | 选项 |
|---|------|------|
| D1 | 路由 | `Navigator.push(MaterialPageRoute)`，不引入 router 库 |
| D2 | 关联导航 | 全做：pill 跳列表 + 卡片跳详情 |
| D3 | Extra Fanart | 横向 thumbnail + 点图全屏 `InteractiveViewer` |
| D4 | "标记看完" UX | 大动作按钮，与"收藏"并列 |
| D5 | 视觉规则 | 沿用之前定稿：no emoji / no gradient / 跟随系统 light/dark / brand Indigo `#4F6DF0` |
| D6 | 图标 | Material `Outlined` |

## 3. 路由与导航

### 3.1 详情页入口

`MovieCard` 已经暴露 `onTap`。修改 [movies_page.dart](lib/features/movies/movies_page.dart) 的 `itemBuilder`：

```dart
MovieCard(
  movie: item,
  posterUrlBuilder: urlBuilder,
  onTap: () => Navigator.of(ctx).push(
    MaterialPageRoute(builder: (_) => MovieDetailPage(movieId: item.id)),
  ),
)
```

### 3.2 详情页内的关联导航

| 来源 | 字段 | 行为 |
|------|------|------|
| 系列 pill | `movie.series` | pop 当前页 → 跳 `/movies` 并应用 `seriesId` filter |
| 标签 pill | `movie.tags[].id` | 同上，应用 `tagId` filter |
| 分类 pill | `movie.genres[].id` | 同上，应用 `genreId` filter |
| 演员 pill | `movie.actors[].id` | 同上，应用 `actorId` filter |
| 分片影片卡 | `part_movies[]` | `Navigator.push` 新 `MovieDetailPage` |
| 演员关联影片卡 | `actor_related_movies[]` | 同上 |

**"跳过滤列表"实现**：MainShell 是 IndexedStack，pop detail 后回到当前 tab。我们需要：
1. 切换到"影片" tab（index 1）
2. 把 filter 注入 `movieFilterProvider`
3. `MoviesPage` 的 `_currentFilter` 监听 provider 变化并 refresh

具体实现：在 detail 页里调用一个 `applyFilterAndPop` helper，它做：
- `ref.read(movieFilterProvider.notifier).state = newFilter`
- `Navigator.of(context).popUntil((r) => r.isFirst)`
- 通过一个 `mainShellIndexProvider` 把 tab index 设为 1

### 3.3 MovieFilter 字段扩展

[movie_filter.dart](lib/features/movies/movie_filter.dart) 增加 4 个可选字段：

```dart
@JsonKey(name: 'series_id') int? seriesId,
@JsonKey(name: 'tag_id') int? tagId,
@JsonKey(name: 'genre_id') int? genreId,
@JsonKey(name: 'actor_id') int? actorId,
```

`toQuery()` 把非空字段加进 query map。

### 3.4 MainShell 改造

把 `_index` 状态从 `_MainShellState` 提升为 riverpod provider：

```dart
final mainShellTabIndexProvider = StateProvider<int>((ref) => 0);
```

`MainShell` 改为 `ConsumerWidget` 监听该 provider，detail 页的关联导航就能直接写 `ref.read(mainShellTabIndexProvider.notifier).state = 1`。

## 4. 详情页布局

### 4.1 顶层结构

```
MovieDetailPage (ConsumerStatefulWidget)
  ├ Scaffold(AppBar 标题 = movie.title)
  └ AsyncValue<MovieDetail> 切换
      ├ loading: CircularProgressIndicator
      ├ error:   ErrorView(retry)
      └ data:    _MovieDetailContent
```

### 4.2 _MovieDetailContent 顺序（10 块，按从上到下）

1. **Hero 区** — fanart 横图作为背景（aspect 16/9），底部覆盖海报 + 标题 + 番号 pill + 年份
2. **动作行** — 两个 FilledButton 并列：`收藏 ⟷ 已收藏 / 取消收藏`、`标记看完 ⟷ 标记未看`
3. **信息卡片** — Wrap 形式的元信息条目：番号 / 年份 / 评分 / 时长 / 国家 / 文件大小 / 最近下载（每条 icon + label + value，缺字段直接跳过）
4. **剧情简介** — `plot`（fallback `outline`），可折叠（默认 4 行，"展开"切换 max lines）
5. **分类区** — 4 个子块（系列 / 标签 / 分类 / 演员），每块横滑 `Wrap` of pill；演员 pill 用 ActorChip（圆头像 + 名字）；空块整块不显示
6. **分片影片** — 横向 ListView，每张卡 = 海报 + 标题，点跳详情
7. **Extra Fanart 墙** — 横向 ListView 缩略图（aspect 16/9，高 110），点图全屏 `_FanartGallery`
8. **演员关联影片** — 横向 ListView，每张卡显示海报 + 标题 + 匹配演员小字
9. **MediaInfo 面板** — 4 个子块（视频 / 音频 / 字幕 / 章节），列表显示 codec/bitrate/lang 等
10. **文件路径** — 列表，每条 `file_path` 文本（可长按复制）

### 4.3 全屏 Fanart Viewer (`_FanartGallery`)

- 路由：`Navigator.push(PageRouteBuilder(opaque: false, ...))`
- 内部：`PageView` 翻页 + `InteractiveViewer(minScale: 1, maxScale: 4)` 缩放拖拽
- 顶部 close icon，底部 "X / N" 计数
- 背景纯黑（独立 Scaffold，不套 AppPage）

### 4.4 ActorChip

横向 ListView 一行，每个 chip：
- 圆头像 56×56（actor 有 `profile_uuid` 时显示，否则灰底首字母）
- 名字 12/600 居中
- 点击跳影片列表过滤

## 5. 数据层

### 5.1 当前 `MovieDetail` 模型缺的字段

| 缺的字段 | 用途 | json key |
|---------|------|---------|
| `last_downloaded_at` | 信息卡 | `last_downloaded_at` (ISO string) |
| `file_size` | 信息卡 | `file_size` (int64) |
| `subtitles` | 没用，MediaInfo 已覆盖。`hasExternalSubtitle` bool 够了 | — |
| `part_movies` | 分片影片块 | `part_movies` (List of RelatedMovie) |
| `actor_related_movies` | 演员关联影片块 | `actor_related_movies` (List of RelatedMovie + `matching_actors`) |
| `extra_fanarts` | Extra Fanart 块 | 通过单独 `/api/movies/:id/extra-fanarts` 接口拿，**不进 MovieDetail 模型** |
| `media_info` | MediaInfo 面板 | 通过单独 `/api/movies/:id/mediainfo` 接口拿 |
| `related_files` | 文件路径块 | `related_files` (List of `{type, label, path}`) |
| `directory` | 可选展示 | `directory` (`{id, name}`) |
| `movie_part` | 顶部 badge | `movie_part` (string) |

加到 `MovieDetail` freezed 类里。

### 5.2 新模型

```dart
@freezed
class RelatedMovie with _$RelatedMovie {
  const factory RelatedMovie({
    required int id,
    required String title,
    String? num,
    @JsonKey(name: 'movie_part') String? moviePart,
    int? year,
    @JsonKey(name: 'poster_uuid') String? posterUuid,
    @JsonKey(name: 'thumb_uuid') String? thumbUuid,
    @JsonKey(name: 'fanart_uuid') String? fanartUuid,
    @JsonKey(name: 'matching_actors') @Default(<ActorRef>[]) List<ActorRef> matchingActors,
  }) = _RelatedMovie;

  factory RelatedMovie.fromJson(Map<String, dynamic> json) =>
      _$RelatedMovieFromJson(json);
}

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

@freezed
class MediaInfo with _$MediaInfo {
  const factory MediaInfo({
    @Default(<MediaInfoTrack>[]) List<MediaInfoTrack> video,
    @Default(<MediaInfoTrack>[]) List<MediaInfoTrack> audio,
    @Default(<MediaInfoTrack>[]) List<MediaInfoTrack> subtitle,
    @Default(<MediaInfoChapter>[]) List<MediaInfoChapter> chapters,
  }) = _MediaInfo;

  factory MediaInfo.fromJson(Map<String, dynamic> json) =>
      _$MediaInfoFromJson(json);
}

// MediaInfoTrack / MediaInfoChapter 字段以 backend 返回为准（read 后端 model 时确认）
```

### 5.3 API 扩展

`MoviesApi` 增加 3 个端点：

```dart
@GET('/movies/{id}/extra-fanarts')
Future<dynamic> getExtraFanarts(@Path('id') int id);

@GET('/movies/{id}/mediainfo')
Future<dynamic> getMediaInfo(@Path('id') int id);

@POST('/movies/{id}/favorite')
Future<dynamic> toggleFavorite(@Path('id') int id);
```

PWA 上 `toggleFavorite` 是 POST `/api/movies/:id/favorite`，需要后端确认（看 [backend/internal/handlers/movies.go](backend/internal/handlers/movies.go) 路由）。`upsertWatchRecord` 已有。

### 5.4 Repository 层

`MoviesRepository` 增加：

```dart
Future<MovieDetail> detail(int id);  // 已有
Future<List<String>> extraFanarts(int id);  // 返回 fanart uuid list
Future<MediaInfo?> mediaInfo(int id);
Future<bool> toggleFavorite(int id);  // 返回新的 is_favorited
Future<void> markWatched(int id, bool completed);
```

`toggleFavorite` 和 `markWatched` 返回后 detail 状态需要更新，统一通过 riverpod 重新触发 detail provider 实现。

### 5.5 Provider

```dart
final movieDetailProvider = FutureProvider.autoDispose
    .family<MovieDetail, int>((ref, id) => ref.read(moviesRepositoryProvider).detail(id));

final extraFanartsProvider = FutureProvider.autoDispose
    .family<List<String>, int>((ref, id) => ref.read(moviesRepositoryProvider).extraFanarts(id));

final mediaInfoProvider = FutureProvider.autoDispose
    .family<MediaInfo?, int>((ref, id) => ref.read(moviesRepositoryProvider).mediaInfo(id));
```

收藏/标记看完写完后 `ref.invalidate(movieDetailProvider(id))` 让页面 rebuild。

## 6. 文件结构

```
lib/
  core/
    models/
      movie.dart                ← 扩展 MovieDetail 字段
      related_movie.dart        ← 新（RelatedMovie）
      related_file.dart         ← 新（RelatedFile）
      media_info.dart           ← 新（MediaInfo + Track + Chapter）
    api/services/
      movies_api.dart           ← 新增 3 端点
  features/
    main/
      main_shell.dart           ← 改 ConsumerWidget + mainShellTabIndexProvider
      main_shell_providers.dart ← 新（mainShellTabIndexProvider）
    movies/
      movie_filter.dart         ← 加 series/tag/genre/actor 字段
      movies_page.dart          ← MovieCard.onTap → push detail；filter 监听更新
      movies_repository.dart    ← 加 detail/extraFanarts/mediaInfo/toggleFavorite/markWatched
      movies_providers.dart     ← 加 movieDetailProvider 等
      detail/
        movie_detail_page.dart  ← 顶层 page
        movie_detail_content.dart ← 主体内容
        sections/
          hero_section.dart
          actions_section.dart
          info_section.dart
          plot_section.dart
          taxonomy_section.dart
          related_movies_section.dart  ← 分片 + 演员关联共用
          extra_fanart_section.dart
          media_info_section.dart
          file_paths_section.dart
        widgets/
          actor_chip.dart
          related_movie_card.dart
          fanart_gallery.dart       ← 全屏 InteractiveViewer
          info_item_row.dart
          taxonomy_pill.dart
  shared/
    (已有)
```

每个 section 是独立 `StatelessWidget`，输入 `MovieDetail`（或派生数据）+ 必要回调，输出一段 `Widget`。`movie_detail_content.dart` 串起所有 section + 处理 loading 状态。

## 7. 复用 vs 新建

- **复用** `AppBadge`（继续用于 hero 区番号 pill / 分片角标）、`MovieCard` 风格（related_movie_card 是简化版 — 海报 + 标题 + 角标）、`ErrorView`、`EmptyView`、`AppRadius/AppSpacing/AppColors`
- **新建** `_TaxonomyPill`（pill 形式 chip，用于系列/标签/分类，区别于演员的圆头像 chip）、`ActorChip`、`RelatedMovieCard`、`InfoItemRow`、`FanartGallery`

不复用 `AppChipRow` — chip row 是水平滚 + 状态选中，taxonomy pill 是包裹 + 点击跳列表，行为不同。

## 8. 错误 & 边界

- `MovieDetail` 加载失败 → ErrorView + retry
- Extra Fanart / MediaInfo **独立**加载，失败不影响主内容（section 内 `AsyncValue.when` 错误态 → "加载失败" 小文本，留空）
- 关联导航 pill 点击时如果 series/tag/... id 为 null，按钮不可点（disabled 透明）
- 番号 pill 长按复制（用 `Clipboard.setData`，提示 SnackBar "已复制 ABC-001"）

## 9. 测试

新增的测试（保持现有测试不动）：

- `test/features/movies/detail/movie_detail_page_test.dart`：loading / error / data 三态 widget 测试
- `test/features/movies/detail/sections/info_section_test.dart`：空字段过滤、格式化（文件大小/时长）
- `test/features/movies/detail/sections/taxonomy_section_test.dart`：空 section 不渲染；pill 可点击
- `test/features/movies/detail/sections/actions_section_test.dart`：收藏切换调 repository、标记看完调 repository、loading 态禁用按钮
- `test/features/movies/movie_filter_test.dart`：新 4 字段 `toQuery()` 正确转 snake_case
- `test/features/movies/detail/widgets/fanart_gallery_test.dart`：左右翻页、close 按钮 pop

ApiClient / Repository 的新方法用 stub repository 注入测试（沿用现有 `_StubMoviesApi` 模式）。

## 10. 非目标 (YAGNI)

- 编辑、删除、NFO 同步、DBO 同步、Extra Fanart **下载**、外部下载 → Sub 3
- 内置/外部播放器 → Sub 2
- 字幕编辑器 → 永不做（明确排除）
- 离线缓存 / 详情数据 hive 持久化
- pull-to-refresh on detail page（拉新数据通过收藏/看完按钮自动 invalidate provider 实现）
- 番号 pill 复制的多平台兼容（fallback execCommand）
- 标记看完时同步上传 `progress_ratio = 1.0`（看完 = `completed: true`，进度保持当前值不变；取消看完 = `completed: false`）

## 11. Backend 依赖确认

实施前需要验证（spec 写完后由实施 agent 在 Task 0 完成）：

- `GET /api/movies/:id/extra-fanarts` 返回结构
- `GET /api/movies/:id/mediainfo` 返回结构
- `POST /api/movies/:id/favorite` 返回结构（PWA 调用 `api.toggleFavorite`）
- `MovieDetail` JSON 实际返回的 `part_movies`、`actor_related_movies`、`related_files`、`directory`、`movie_part`、`subtitles` 字段名

如果某个端点不存在 / 字段名不匹配，**对应 section 降级**（hide 整块或显示"暂不支持"），写在实施 plan 的 Task 0 探查 → 调整 spec 章节里。
