# dbo 播放选源改造发现

## 当前已知

- dbo 详情入口是 `lib/features/db_online/db_online_movie_detail_page.dart` 中的 `_openDbOnlinePlayback`。
- 点击“在线播放”时，多个播放源已通过 `showAppActionSheet` 从底部弹出选择；单源直接继续。
- 选择后会导航到同文件内的 `DbOnlinePlaybackPage`，该独立页面负责按源请求剧集，并在顶部再次提供“切换播放源”。
- 用户意图应是移除这个独立的选源/播放承载页面层，将选源与剧集内容收进详情页的底部弹出 bar；仍需结合现有测试确认期望行为和播放器入口。
- 目前工作区存在用户已有修改：`lib/features/db_online/db_online_latest_movies_page.dart`；本任务不触碰该文件。

## 进一步确认

- `57e1e35` 已将详情页多源选择改为 `showAppActionSheet`，但仍保留 `DbOnlinePlaybackPage` 作为剧集承载页，并在其 AppBar 提供二次切源。
- 当前测试 `db_online_playback_entry_test.dart` 只覆盖直连播放器构造，不覆盖详情页选源交互。
- 目标实现应保留“选源后加载剧集并播放”的能力，同时去掉播放页里的独立选源入口/承载职责，避免点击链路再次出现独立选源页。

## 本轮 DBO 搜索改造

- `lib/features/db_online/db_online_search_page.dart` 当前只有影片搜索，输入通过 `Debouncer` 更新 `_query` 并立即创建分页结果；搜索图标是静态 `Icon`。
- `lib/features/search/search_page.dart` 的 `_SearchTypeMenu` 是 OMM 现有自定义 Overlay 切换器，可作为 DBO 搜索模式交互的复用基准。
- `DbOnlineApi.searchPage` 当前固定请求 `/search`、`type=movie`，并携带 `movie_filter_by=can_play`。
- 当前本地化只有 OMM 的影片/番号/演员/文件名文案，尚无 DBO“列表/系列”专用文案。
- DBO 后端文档确认：影片列表使用 `/api/search?q=...`，演员使用 `/api/search/actors?q=...`，两者响应分别为 `data.movies` 与 `data.actors`；文档当前没有列出系列独立搜索接口。
- DBO 前端搜索模式契约是 `list`、`actor`、`series`；`series` 通过 `/search?q=...&type=series` 进入通用搜索路由，需继续确认其实际响应形态后再接入移动端。
- 移动端当前只有 `DbOnlineMovie`、`DbOnlineMoviePage` 和详情中的 `DbOnlinePerson` 模型，没有演员/系列搜索模型或结果 Provider；需要增加轻量实体模型与分页/非分页请求解析。
- DBO 前端 `Search.vue` 的非影片实体统一读取 `response.data.data.items`，并按 `id/name` 渲染实体卡片；路由仅把 `actor` 分流到独立演员搜索，`series` 仍走 `/api/search` 的通用搜索。
- DBO 后端 `handleSearch` 对 `type=series` 调用 `SearchEntities`，将 `SearchEntityItem` 列表包装为 `data.items`；实体项字段为 `id`、`name`、可选 `image_url`、`movies_count`。
- 演员响应字段确认是 `data.actors[]`，包含 `id`、`name`、`name_zht`、`other_name`、`gender`、`videos_count`、`avatar_url` 等；演员搜索无分页参数，移动端可使用一次性结果列表。
- OMM 切换器的交互包含点击打开、点击外部关闭、长按滑动选择、触觉反馈和悬停高亮；适合抽为泛型共享组件，让 OMM 与 DBO 使用同一实现。
- DBO 系列实体结果使用与 OMM 网页一致的 `data.items`，可按 `id/name/movies_count` 渲染统一实体卡片；演员结果单次返回 `data.actors`，无需为演员伪造分页接口。
- 实施方案：增加 `SearchTypeMenu<T>` 共享组件并让 OMM 现有页面改用它；DBO 页面保留影片分页卡片，新增演员一次性实体结果与系列实体分页结果。

## 本轮隐私模式排查

- OMM 的隐私模式由 `privacyShieldProvider` 控制，影片卡片通过 `PrivacyMask`、`PrivacyText` 和 `PrivacyAwareInkWell` 实现遮罩、标题隐藏及首次点击揭示。
- `lib/features/db_online/db_online_movie_card.dart` 当前复用共享 `CatalogMovieCard`，但 `CatalogMovieCard` 只渲染普通 `Poster`/`Text`，没有接入隐私组件；因此 DBO 首页、最新和影片搜索卡片不会响应隐私模式。
- DBO 影片标识是字符串（可能是 `movie-1`、番号或 `video_id`），现有 `RevealedIdsNotifier` 只接受 `Set<int>`，不能直接把 DBO 标识传给现有影片隐私域。
- 需要在共享隐私能力中增加字符串键支持，并让 DBO 卡片复用同一套隐私开关/揭示行为；不能用字符串 `hashCode` 充当 ID，以免碰撞且语义不稳定。

## 本轮实现结果

- `RevealedIdsNotifier` 和三个揭示 Provider 现在使用 `Set<Object>`；OMM 的 `int` 与 DBO 的 `String` 键按 Dart 原始相等性保存，仍按影片/演员/演员关联 Provider 隔离。
- `CatalogMovieCard` 新增可选 `privacyId`，复用 OMM 的海报 `PrivacyMask` 和文本 `PrivacyText`；未提供时保持原目录卡片行为。
- `DbOnlineMovieCard` 读取共享隐私开关，首次点击字符串 `movie.id` 只写入共享揭示集合，第二次点击才执行原 DBO 详情回调，因此首页、最新、搜索和详情相关推荐统一生效。

## 2026-08-28 底部毛玻璃面板内部控件审计

- 范围限定为通过 `showGlassSheet` / `showAppActionSheet` 进入、带统一拖拽把手的底部面板；排除灯箱、对话框和播放器内部控制手势；未启动浏览器，未修改业务源码。
- 共盘点 36 个业务文件、47 处相关调用（包含公共 `showAppActionSheet` 转发和嵌套选择器）。
- 公共基准为 `lib/shared/glass.dart:158` 的 `showGlassSheet` / `GlassSheetHandle`、`lib/core/platform/app_theme.dart:7` 的 `AppColors`、`lib/features/settings/settings_common.dart:67` 的 `SettingsTile`、`SettingsSwitch`、`settingsInputDecoration`、`settingsCardDecoration`。
- 高优先级：`advanced_filter_sheet.dart:374`、`batch_download_sheet.dart:214`、`batch_duplicate_nfo_sheet.dart:245`、`batch_edit_sheet.dart:351`、`batch_merge_sheet.dart:213` 使用不透明 `c.bg` 作为底部操作栏背景，会在毛玻璃面板内形成实色横带。
- 高优先级：`batch_download_sheet.dart:185`、`:193`、`:201` 使用 `SwitchListTile.adaptive`，其余偏好开关主要使用公共 `SettingsSwitch`，平台自适应尺寸、轨道/拇指配色及行布局不一致。
- 中优先级：输入控件混用公共 `settingsInputDecoration` 与局部 `TextField + BoxDecoration`、裸 `InputDecoration`；典型为 `advanced_filter_sheet.dart:527`（8px 圆角）、`batch_download_sheet.dart:274`（默认 `OutlineInputBorder`）、`batch_edit_sheet.dart:727`（默认边框）、`translation_settings_page.dart:442`、`mapping_rules_page.dart:555`、`movie_editor_sheet.dart:810`、`resource_list_page.dart:716`（未复用 helper，焦点态也不同）。
- 中优先级：按钮组件、颜色、圆角和提交结构混用；`SettingsSaveButton` 是 `c.text/c.bg + 12px + 48px`，而批量面板多为默认 `FilledButton` / `OutlinedButton`，进度面板还使用 `ElevatedButton`，危险/警告/成功色分别使用 `c.danger`、`c.warning`、`c.accent`、`c.text`。
- 中优先级：危险操作语义没有完全沿用公共 action-sheet 规则；`app_action_sheet.dart:5-13` 支持 `destructive` 红色动作，但 `server_selection_page.dart:118-126` 的“删除服务器”直接使用默认 `ListTile`，与“编辑服务器”同色同层级。
- 中优先级：选择列表混用默认 `ListTile`、`SettingsTile`、自定义 `InkWell` 行、`ChoiceChip` 和自定义胶囊；标题字号、左右内边距、dense 行高、选中标记尺寸及点击反馈没有单一来源。代表：`app_action_sheet.dart:26`、`db_online_library_page.dart:171`、`movies_page.dart:988`、`settings/*.dart` 选择器、`entity_picker_sheet.dart:820`、`db_online_movie_detail_page.dart:709`。
- 中优先级：公共 `showGlassSheet` 已统一 SafeArea，但多个业务 builder 再次包裹默认 `SafeArea`，另有 `top: false`、`useSafeArea: true` 混用；代表 `add_to_list_sheet.dart:42`、`translation_settings_page.dart:114`、`db_online_library_page.dart:150`、`movies_page.dart:933`、`resources_sheet.dart:355`。
- 中优先级：选择和切换的触觉/状态反馈路径不一致；`SettingsSwitch`、`SettingsTile` 显式接入 `AppHaptics`，而 `advanced_filter_sheet.dart:472`、`batch_edit_sheet.dart:921`、`movie_editor_sheet.dart:879`、DBO 播放源 `db_online_movie_detail_page.dart:709` 等自定义 `GestureDetector` / `ChoiceChip` 没有共享反馈入口。
- 低优先级：状态提示 alpha 混用 `0.08/0.10/0.12`，边框 alpha 混用 `0.20/0.28/0.35/0.40/0.55/0.60`；错误、警告、信息语义不应抹平，但应抽取统一状态容器 token。
- 低优先级：`resources_sheet.dart:799`、`:872-896` 与 `dbo_diff_sheet.dart:850-854` 使用硬编码绿色、蓝色、橙色、紫色、粉色及性别色；属于内容/语义色例外，但未纳入 `AppColors`。
- 有意差异不建议直接统一：播放源切换的横向 `ChoiceChip`、字幕颜色圆形色样、头像选择网格、DBO 元数据增删/替换语义色，均由交互对象决定。
