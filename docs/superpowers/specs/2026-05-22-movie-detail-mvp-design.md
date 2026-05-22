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
| `extra_fanarts` | Extra Fanart 块 | 通过单独 `GET /api/movies/id/:id/extrafanart` 接口拿（返回 `["url1", ...]` 字符串数组），**不进 MovieDetail 模型** |
| `media_info` | MediaInfo 面板 | 通过单独 `GET /api/movies/id/:id/media-info` 接口拿 |
| `related_files` | 文件路径块 | `related_files` — backend 字段实际形态在 Plan Task 0 探查（service 内部用 `buildRelatedFiles`，结构未在 backend response 直接表达） |
| `movie_part` | 顶部 badge | `movie_part` (string) |

注：spec §4.2 提到的 "directory" 信息块在 backend 详情响应里**不直接存在**（`Movie.Directory` 是关联但响应未导出）—— 取消该子块，文件路径块改用 `file_path` 主路径 + `related_files`。

另外，**`has_external_subtitle` 在详情响应里不存在**（只有 `subtitles` 列表）。`MovieDetail` 模型保留 `hasExternalSubtitle` 字段（兼容现有反序列化），但详情响应解出来永远是 `false`（默认值），不影响功能。详情页不依赖该字段。

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

backend 返回的是**扁平结构**（不是按 video/audio/subtitle 分组）。UI 上按"容器 / 视频 / 音频"3 个 group 展示，每 group 由相关字段拼接。**没有 chapters 和 subtitle tracks**（subtitle 信息在 `MovieDetail.subtitles` 列表，但 Sub 1 不展示该列表 — 仅靠列表页 `hasExternalSubtitle` badge 提示已足够）。

### 5.3 API 扩展

**重要**：当前 [movies_api.dart](lib/core/api/services/movies_api.dart) 的所有 `{id}` 路径写的是 `/movies/{id}` —— 但 backend 实际是 `/movies/id/{id}`（带 `/id/` 段）。详情、watch-record 等都要修，包括已有但路径错的 4 个端点（getMovieDetail / upsertWatchRecord / getWatchRecord）。

`MoviesApi` 修正现有 + 增加 3 端点：

```dart
// 修正现有
@GET('/movies/id/{id}')
Future<dynamic> getMovieDetail(@Path('id') int id);

@PUT('/movies/id/{id}/watch-record')
Future<dynamic> upsertWatchRecord(@Path('id') int id, @Body() Map<String, dynamic> body);

@GET('/movies/id/{id}/watch-record')
Future<dynamic> getWatchRecord(@Path('id') int id);

// 新增 3 个
@GET('/movies/id/{id}/extrafanart')
Future<dynamic> getExtraFanarts(@Path('id') int id);

@GET('/movies/id/{id}/media-info')
Future<dynamic> getMediaInfo(@Path('id') int id);

@PUT('/favorites/{id}/toggle')
Future<dynamic> toggleFavorite(@Path('id') int id);
```

注意：
- `extrafanart`（无连字符），返回 `["url1", "url2", ...]` 字符串数组，url 是完整 path 例如 `/api/movies/id/123/extrafanart/foo.jpg` — 直接可拼 baseUrl 用
- `media-info`（带连字符），返回扁平 object（见 §5.2 重写）
- favorite endpoint 是 `PUT /api/favorites/{movie_id}/toggle`（独立 group，不在 movies 下），返回 `{is_favorited, message}`

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

## 11. Backend 已确认（在 brainstorming 阶段完成）

| Endpoint | 路径 | 返回 |
|---------|------|------|
| 详情 | `GET /api/movies/id/{id}` | 上述 `MovieDetail` 形态 |
| Extra Fanart | `GET /api/movies/id/{id}/extrafanart` | `["/api/movies/id/123/extrafanart/foo.jpg", ...]` 字符串数组（注意不是 uuid） |
| Media Info | `GET /api/movies/id/{id}/media-info` | 扁平 object，字段见 §5.2 `MediaInfo` |
| 收藏切换 | `PUT /api/favorites/{movie_id}/toggle` | `{movie_id, is_favorited, message}` |
| 观看记录 | `PUT /api/movies/id/{id}/watch-record` | 现有，body 含 `completed` / `progress_ratio` |

仅 `related_files` 形态需要在 Plan Task 0 探查 backend `buildRelatedFiles` 函数确认 — 该字段若结构复杂，简化为只展示主路径 `file_path` 单行，整个 `related_files` block 取消。

PWA 详情响应里 `subtitles` 字段存在但 mobile_app 详情页不展示（MediaInfo 已覆盖 subtitle 视觉提示）—— 不需要建模。
