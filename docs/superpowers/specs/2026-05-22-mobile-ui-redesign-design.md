# mobile_app UI/UX 重构设计稿

定稿日期：2026-05-22

## 1. 目标

把当前依赖 Material 默认主题、Cupertino/Material 平台分叉的"工程占位 UI"重做成一个有品牌一致性的影音库 App。视觉对齐 `frontend_new` PWA 的功能信息密度（badge、进度条、番号 pill），但**不沿用赛博朋克的霓虹/渐变/玻璃磨砂**——换成标准 iOS/Android 风的克制配色，跟随系统浅/深主题。

## 2. 设计硬规则

| # | 规则 | 理由 |
|---|------|------|
| R1 | 不使用 emoji | 跨平台渲染不一致，与"标准"调性冲突 |
| R2 | 不使用渐变（含底部 badge 行的 transparent→black 渐变） | 用户硬性要求；改用纯色 |
| R3 | 影片网格 3 列 | 用户硬性要求（当前是 2 列） |
| R4 | 跟随系统浅/深色 | 标准设备体验 |
| R5 | 移除平台分叉（`isCupertino`），两端共用一套自绘 | 跨平台一致；代码简化 |

## 3. 视觉 Tokens

### 3.1 配色

| Token | Light | Dark | 用途 |
|-------|-------|------|------|
| `bg` | `#FFFFFF` | `#000000` | 页面底 |
| `surface` | `#F4F4F6` | `#1A1A1C` | 搜索框/chip/卡片背景 |
| `surfaceVariant` | `#ECECEF` | `#2A2A2E` | 番号 pill 底/普通 chip |
| `text` | `#0F0F14` | `#FFFFFF` | 主文字 |
| `textMuted` | `#6B6B75` | `#98989F` | 次要文字（meta、placeholder） |
| `divider` | `rgba(0,0,0,0.08)` | `rgba(255,255,255,0.10)` | 分隔线/边框 |
| `tabBarBg` | `#FFFFFF` | `#111113` | 底栏背景（不透明，无 blur） |
| `tabBarBorder` | `rgba(0,0,0,0.08)` | `rgba(255,255,255,0.10)` | 底栏顶部 1px |
| `tabIdle` | `#8A8A92` | `#7A7A82` | 未激活 tab |
| `posterBorder` | `rgba(0,0,0,0.06)` | `rgba(255,255,255,0.06)` | 海报 1px 边 |
| `progressTrack` | `rgba(0,0,0,0.12)` | `rgba(255,255,255,0.18)` | 进度条空槽 |
| `shade` | `rgba(0,0,0,0.72)` | `rgba(0,0,0,0.78)` | badge 自带底色 |

### 3.2 品牌色

唯一强调色 **Indigo `#4F6DF0`**（深浅色通用，前景 `#FFFFFF`）。
用途：激活 tab、激活 chip、主按钮、进度条填充、链接。

### 3.3 状态色（badge 专用）

| Token | 颜色 | 用途 |
|-------|------|------|
| `badgeUpdated` | `#F59E0B` (amber) | 已更新 |
| `badgeFavorited` | `#EF4444` (red) | 已收藏 |
| `badgeCompleted` | `#14B8A6` (teal) | 已看完 |
| `badgeSubtitle` | `#F59E0B` (amber) | 字幕 CC |
| `badgeMeta` | `shade` (深灰) | 评分 / 文件大小 |

### 3.4 几何 & 字体

- 圆角：海报 `10`、卡片/容器 `12`、chip/按钮 `999`、tab pill 无（纯文字+icon）
- 间距：8 / 12 / 16 / 24
- 字体：默认平台字体（iOS = SF Pro / Android = Roboto）
- 字号：title 30/800、headline 17/700、body 14/500、caption 12/500、badge 10/700
- 不引入自定义字体

## 4. 信息架构

### 4.1 底栏 5 tab（仿 PWA AppBottomNav，序号即左→右）

1. **仪表板** (icon: grid)
2. **影片** (icon: film)
3. **收藏** (icon: heart)
4. **更多** (icon: more / 三点)
5. **设置** (icon: gear)

"更多" 点击展开 bottom sheet（参考 [AppBottomNav.vue:81-88](../../../../frontend_new/src/components/layout/AppBottomNav.vue#L81-L88)），列出：媒体库 / 标签管理 / 分类管理 / 系列管理 / 演员管理 / 演员关联（占位项，本轮只先建占位 sheet 和入口）。

### 4.2 屏幕清单（本轮实现 vs 占位）

| 屏幕 | 状态 | 备注 |
|------|------|------|
| 仪表板 | **占位** | 一个 "建设中" 屏，给个 tab 入口即可 |
| 影片 | **完整重做** | 标题区 + 搜索 + chip 筛选 + 3 列 grid + 完整 badge |
| 收藏 | **占位** | 沿用现有"建设中"文案，套新主题 |
| 更多（sheet） | **新建** | bottom sheet，列占位条目（点了 toast 提示"待实现"） |
| 设置 | **新主题** | 列表样式重做，内容（服务器地址）不动 |
| 服务器配置页 | **新主题** | 内容/校验逻辑不动，仅样式 |

不在本轮范围：影片详情、收藏列表实数据、媒体库等管理类页面。

## 5. 组件库（`lib/core/ui/`）

新建一个 `ui` 子目录，所有平台无关的视觉组件归在这里。旧 `lib/core/platform/` 整体废弃（见 §7）。

### 5.1 主题

`lib/core/ui/theme.dart`
- `AppColors` — 上述 token 表（暴露 light/dark 两套，按 `Brightness` 取）
- `appTheme(Brightness)` — 一个返回 `ThemeData` 的工厂；`MaterialApp.theme/darkTheme` 各调一次
- `themeMode: ThemeMode.system`

### 5.2 Scaffold + 大标题

`lib/core/ui/app_scaffold.dart`
- 替换现有 `AppScaffold` + `AppLargeNavBar`
- 单一 Material `Scaffold`，无 Cupertino 分叉
- 提供 `AppPage({title, subtitle?, children: List<Widget>, sliverChildren?: ...})`，内部用 `CustomScrollView` + 自绘大标题 sliver（不用 SliverAppBar.large，避免 Material 滚动折叠动画跟设计稿不一致）
- 大标题：30/800、字间距 -0.6、与 sub `12/500/textMuted` 间距 3px

### 5.3 5-tab 底栏

`lib/core/ui/app_bottom_nav.dart`
- 自绘 `Container` + 5 个 `InkWell` 列
- 高度 58 + safe-area bottom
- 顶部 1px `tabBarBorder`，背景 `tabBarBg`
- 每个 tab：竖排 icon(22px, stroke 1.7) + label(10/500)，激活态 brand + label 600
- 第 4 个 tab 是 "更多"，点击不切换页面而是 `showModalBottomSheet`
- API：`AppBottomNav({currentIndex, onTap, onMoreTap})`

### 5.4 影片卡片（核心）

`lib/shared/movie_card.dart`（重写现有文件）

布局：
```
┌──────────┐
│ [L][R]   │  ← 左/右上 badge 浮层
│ poster   │
│          │
│ [bot row]│  ← 左下 badge 行（无背景）
│──────────│  ← 底边 2px progress
└──────────┘
  Title         ← 10/600 max 2 行
  meta · num    ← 9/500 textMuted + 番号 pill
```

Badge 规则（与 PWA 对齐）：

| 位置 | 触发字段 | 优先级 | 视觉 |
|------|---------|--------|------|
| 左上 | `is_updated == true` | 高 | 黄底 + refresh icon + "已更新" |
| 左上 | `is_favorited == true` | 低 | 红底 + heart-fill + "已收藏" |
| 右上 | `watch_record.completed == true` | — | 青绿底 + check + "已看完" |
| 左下行 | `has_external_subtitle == true` | — | 橙底 + CC icon（无文字） |
| 左下行 | `rating` 可解析 | — | 深灰底 + star icon + 数字（保留一位小数） |
| 左下行 | `file_size > 0` | — | 深灰底 + hdd icon + "X.XG"/"XM" |
| 底边 | `progress_ratio > 0` | — | 2px brand 横条，宽度按 ratio |
| 标题下 meta 行 | `num` 非空 | — | surfaceVariant 底 pill |

Badge 公共样式：`8/700/uppercase`、`padding 2x5`、`radius 4`、`gap 2`、icon `9x9 stroke 2.2`。

左上互斥规则：`is_updated` 优先于 `is_favorited`（与 PWA 一致）。

### 5.5 搜索框 / Chip 行 / 空态&错误态

- `app_search_field.dart` — surface 底 + search icon（line），textMuted placeholder，38 高
- `app_chip_row.dart` — 横滑 chip 列，激活时 brand 底白字
- `empty_view.dart` / `error_view.dart` — 套新色 token，移除 `Icons.error_outline` 大图标，改用线条 SVG 风（用 `CustomPainter` 或简单 `Icon` + 线条 Material icon `Icons.search_off_outlined` 之类）

### 5.6 图标策略

避免 emoji。Flutter 内置 `Material Icons` / `CupertinoIcons` 是字体图标，渲染稳定。**全部用 `Material Icons` 的 outlined 变体**（线条风，与设计稿同步）：

| 用途 | 图标 |
|------|------|
| 搜索 | `Icons.search` |
| 仪表板 | `Icons.dashboard_outlined` / `Icons.dashboard`（激活） |
| 影片 | `Icons.movie_outlined` / `Icons.movie` |
| 收藏 | `Icons.favorite_outline` / `Icons.favorite` |
| 更多 | `Icons.more_horiz` |
| 设置 | `Icons.settings_outlined` / `Icons.settings` |
| Badge: 已更新 | `Icons.refresh` |
| Badge: 已收藏 | `Icons.favorite` |
| Badge: 已看完 | `Icons.check_circle_outline` |
| Badge: 字幕 | `Icons.closed_caption_outlined` |
| Badge: 评分 | `Icons.star` |
| Badge: 大小 | `Icons.storage` |

## 6. 屏幕规范

### 6.1 影片页

```
SafeArea
  CustomScrollView
    ├─ Sliver: 大标题区（"影片库" + "N 部 · 已看 M 部"）
    ├─ Sliver: 搜索框
    ├─ Sliver: chip 行（全部/未看/收藏/在看 — 本轮先静态展示，wired 到 filter 留下一轮）
    └─ Sliver: PagedSliverGrid（3 列，aspectRatio 0.55 还需调整）
```

`crossAxisCount` 固定 3（移除 `MediaQuery.of(context).size.width > 600 ? 4 : 2` 逻辑）。
统计数字 (`N 部 · 已看 M 部`)：本轮**写死占位文案**（"影片库" 单行，无 sub），实数据接入留下一轮——避免引入新 API。

### 6.2 设置页

`ListView` + 自绘 list tile（surface 底、圆角 12、左 padding 16、右侧线条 chevron）。
单条目：`服务器地址 / [当前值或"未配置"] / chevron` → 跳转服务器配置页。

### 6.3 服务器配置页

保持现有校验逻辑（empty / 协议前缀 / `dio.get('/health')` 探活），只换：
- 标题大字风
- 输入框统一用 `Material` `TextField` + 自绘 surface 底（移除 `CupertinoTextField` 分支）
- 按钮：`FilledButton` brand 色（移除 `CupertinoButton.filled` 分支）
- 错误文字 `#EF4444`

## 7. 迁移与删除

| 文件 | 操作 |
|------|------|
| `lib/core/platform/platform.dart` | 删除（`isCupertino` 不再用） |
| `lib/core/platform/app_scaffold.dart` | 删除 → `lib/core/ui/app_scaffold.dart` 重写 |
| `lib/core/platform/app_tab_bar.dart` | 删除 → `lib/core/ui/app_bottom_nav.dart` 重写 |
| `lib/core/platform/app_nav_bar.dart` | 删除（大标题逻辑挪进 `AppPage`） |
| `lib/core/platform/app_search_field.dart` | 删除 → `lib/core/ui/app_search_field.dart` 重写 |
| `lib/core/platform/app_action_sheet.dart` | 保留但不再用平台分叉（本轮没用到，可留可删；先**保留**避免无关改动） |
| `lib/core/platform/app_dialog.dart` | 同上 |
| `lib/shared/movie_card.dart` | 重写 |
| `lib/shared/empty_view.dart` / `error_view.dart` | 应用新 token |
| `lib/features/main/main_shell.dart` | 改用新 `AppBottomNav`，移除 `isCupertino` |
| `lib/features/movies/movies_page.dart` | 改 3 列 grid、套新 chip 行 |
| `lib/features/settings/*.dart` | 套新主题，移除 Cupertino 分支 |
| `lib/features/favorites/favorites_page.dart` | 套新主题（仍占位） |
| `lib/main.dart` | `MaterialApp` 用新 `appTheme(light)` / `appTheme(dark)` |
| `test/core/platform_test.dart` | 用例围绕"iOS 渲染 Cupertino" 假设，**重写**为只验证 Material |

## 8. 测试

- **平台测试重写** (`test/core/platform_test.dart`)：删掉 iOS Cupertino 用例，改为：
  - `AppScaffold` 在任意平台都渲染 Material `Scaffold`
  - `AppBottomNav` 渲染 5 个 tab
  - 点击第 4 个 tab 触发 `onMoreTap`（不切换页）
- **MovieCard 测试增量** (`test/shared/movie_card_test.dart`)：保留现有 3 个用例（已修复 wrap 宽度），新增：
  - `is_updated=true` 显示"已更新"角标
  - `is_favorited=true && is_updated=false` 显示"已收藏"
  - 同时为 true 时只显示"已更新"（互斥优先）
  - `rating=8.5` 显示星标 badge
  - `file_size=4500000000` 显示 "4.2G"
- 旧测试不动：envelope / error_mapper / dio_factory / movies_repository / server_setup_page。

## 9. 非目标 (YAGNI)

明确不做：
- 自定义 SVG 图标包（用 Material outlined 够）
- 图片占位骨架屏动画（保留现有 `ColoredBox` 灰块即可）
- 主题切换开关（强制跟随系统）
- 任何尚未在 PWA 实现的功能
- 浮动操作按钮、Fab 菜单
- 仪表板/媒体库等占位页的真实内容
- 国际化 / 字体加载策略 / 字号缩放适配
