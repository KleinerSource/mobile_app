# md_center mobile_app · 设计对接 · 交付说明

> 完成日期: 2026-05-22
> 范围: 设计稿 → Flutter 全量对接 (4 Tab + 主题系统 + 二级页)

## 你需要做什么

由于本地未安装 Flutter SDK,以下步骤需要你在本机执行:

### 1. 生成代码 (freezed / json_serializable / retrofit)

```bash
cd D:\Projects\MyProject\ghs\md_center\mobile_app\.claude\worktrees\mystifying-euclid-302347
flutter pub get
dart run build_runner build
```

预期生成的新文件:
- `lib/core/models/library.freezed.dart` + `library.g.dart`
- `lib/core/api/services/favorites_api.g.dart`
- `lib/core/api/services/libraries_api.g.dart`

### 2. 静态分析

```bash
flutter analyze
```

应该 0 error 0 warning。若有问题大概率是:
- import 缺失 (复制贴漏)
- `WidgetsBinding.instance.addPostFrameCallback` 在 ConsumerWidget 用错 ref
  → 把 `MovieDetailPage` 里 `ref.read(favoriteStatusProvider.notifier).seed(...)` 改成
    单独的 `ConsumerStatefulWidget` 子组件,在 `initState` 调用

### 3. 字体 (可选)

设计稿用 Inter,目前 Flutter 默认 system font 已经接近。要 100% 精准:

```yaml
# pubspec.yaml 加入
flutter:
  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
        - asset: assets/fonts/Inter-Medium.ttf
          weight: 500
        - asset: assets/fonts/Inter-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Inter-Bold.ttf
          weight: 700
        - asset: assets/fonts/Inter-ExtraBold.ttf
          weight: 800
```

下载: https://fonts.google.com/specimen/Inter → 拷贝到 `assets/fonts/`

### 4. 运行

```bash
flutter run -d windows   # 或 -d chrome / iOS / Android
```

首次启动会要求填服务器地址(/api/health 测试)。

## 改动清单

### 新增文件

```
lib/
  core/
    platform/
      app_theme.dart                 ← 设计令牌 · Light/Dark/Hues/AppText
    api/services/
      favorites_api.dart             ← 收藏 API
      libraries_api.dart             ← 媒体库 API
    models/
      library.dart                   ← LibraryItem freezed
  features/
    home/
      home_page.dart                 ← 首页 (问候/Continue/Libraries/Recent)
      home_providers.dart
    libraries/
      libraries_repository.dart
      libraries_providers.dart
    movie_detail/
      movie_detail_page.dart         ← 影片详情二级页
      movie_detail_providers.dart
    person_detail/
      person_detail_page.dart        ← 演员/导演详情二级页
    search/
      search_page.dart               ← 全局搜索 (debounced)
    favorites/
      favorites_repository.dart      ← 收藏 repo
      favorites_providers.dart       ← 收藏全局状态
  shared/
    poster.dart                      ← 海报组件 (真图 + hue 渐变占位 + 评分角标)
    filter_chip.dart                 ← FilterChipPill / HueChip
    glow_background.dart             ← 紫粉光晕背景

design/                              ← 既有设计稿,无改动
```

### 重写文件

```
lib/
  main.dart                          ← 用 buildAppTheme()
  core/api/api_client.dart           ← 加入 favorites + libraries
  core/api/services/movies_api.dart  ← /movies/{id} → /movies/id/{id} (路径修正)
  core/platform/platform.dart        ← export app_theme
  features/main/main_shell.dart      ← 4-Tab 悬浮胶囊
  features/movies/movies_page.dart   ← Library 重构 (filter/Grid/List/搜索)
  features/favorites/favorites_page.dart  ← Favorites 重构 (stats/lists/watchlist)
  features/settings/settings_page.dart    ← 设计稿样式 + Server 入口 + 退出登录
  features/settings/server_setup_page.dart ← 设计稿样式 (大字号引导)
  shared/movie_card.dart             ← 紫色 accent + 评分角标 + R18 角标
```

## 已知 TODO (后端依赖)

| 功能 | 现状 | 解决路径 |
|---|---|---|
| Play 按钮 | SnackBar 占位 | 接 `/movies/id/{id}/transcode-status` + HLS 播放器 (better_player_plus 已装) |
| Unwatched filter | 复用 created_at | 后端加 `unwatched` 参数 |
| Lists 数量统计 | 显示 "—" | 客户端拼装: 用本地 SharedPreferences 存 "list_id → movie_ids[]" |
| After Hours PIN | 仅 UI 角标 | 设置页 PIN 输入 + SharedPreferences gate |
| R18 遮罩 | `restricted: false` 写死 | 后端加 `restricted` 字段或本地路径匹配规则 |
| AI 建议卡 | 未实现 | 客户端纯计算: 最近 N 天未观看的收藏 |
| Person Detail bio | 通过路由 props 传 | 加 ActorsApi.detail() endpoint |
| Genre/Tag 多彩 Browse 页 | 未做 | 后续迭代 (设计稿 03 还有更多模块) |

## 验证清单

启动后请确认:

- [ ] 首次启动进入 ServerSetupPage,大字号 "连接到 md_center"
- [ ] 填地址后进入主界面,底部悬浮 4-Tab 胶囊
- [ ] Home 显示问候 / Continue Watching (若有看过的) / Libraries / Recently Added
- [ ] Library Tab 显示 3 列网格 + Grid/List 切换 + filter chips
- [ ] 点击影片进入详情页 · Hero 海报 + 演员栏 + 收藏 ♡ 按钮可切换
- [ ] Search Tab 输入关键词 320ms 后出结果
- [ ] You Tab 显示统计条 + 4 张多彩 lists 卡片 + watchlist
- [ ] You → Settings 进入设置 · 改主题 / 退出登录可清空配置
- [ ] 系统切换深浅色,app 跟随

## 设计稿对照

| 设计稿 | 实现位置 |
|---|---|
| `design/01_library_favorites.html` Library | `features/movies/movies_page.dart` |
| `design/01_library_favorites.html` Favorites | `features/favorites/favorites_page.dart` |
| `design/02_detail.html` Movie Detail | `features/movie_detail/movie_detail_page.dart` |
| `design/02_detail.html` Person Detail | `features/person_detail/person_detail_page.dart` |
| `design/03_*` Browse/Search/Settings/Player | Search ✓ / Settings ✓ / Browse + Player TODO |
| `design/04_onboarding.html` | `features/settings/server_setup_page.dart` (单步版) |

第 2 个迭代可以扩展 Browse Hub + Player + 多步 Onboarding。
