# omm · 移动端设计定稿

> 完成日期: 2026-05-22
> 设计方向: **多彩集合派** (Playful · Apple Music / Spotify 同气质)
> 双版本: Light + Dark · 系统跟随
> 入口: 打开 `INDEX.html`

## 产品定位

私有影视媒体库的 iOS / Android 客户端,服务于:
- **自建 Plex / Jellyfin / Emby 用户**,但嫌默认 UI 不够好看
- **Letterboxd 重度影迷**,在意演员 / 导演 / 类型 / 标签等元数据维度
- **混合内容场景**(含成人内容),需要 R18 遮罩 + PIN 私密列表

## 文件清单

仅保留定稿,部署时不会有歧义:

| 文件 | 模块 | 屏数 | 双版本 |
|------|------|------|--------|
| `INDEX.html` | 设计系统入口 (聚合所有屏) | - | - |
| `01_library_favorites.html` | Library + Favorites | 4 | Light/Dark |
| `02_detail.html` | Movie Detail + Person Detail | 2 | Light/Dark |
| `03_browse_search_settings_player.html` | Browse + Search + Settings + Player | 4 | Light/Dark |
| `04_onboarding.html` | 首次启动 + 服务器配置 | 3 | Light/Dark |
| `brand-spec.md` | 品牌规范 (色板 / 字型 / 反 slop 红线) | - | - |
| `README.md` | 本文件 | - | - |

**总计 13 屏 · 4 模块 · 全部带 Light + Dark 双版本**

## 信息架构

底部 4 Tab (悬浮胶囊):
- **Home** — 个性化首页 (Continue watching / Collections / Fresh / Genres / Directors)
- **Library** — 影片库全量浏览 + 强筛选 + Grid/List 切换
- **Search** — 全局搜索 (片名 / 演员 / 导演 / 标签)
- **You** — 收藏夹 / Watchlist / 自定义列表 / 设置入口

**注:** 应用户决策,产品中**不包含 Series (系列) 概念**作为独立浏览维度。系列信息保留在影片详情页内,不进入顶层导航。

## 设计语言

### 色板速查
- **Light**: 底 `#FAF6F0` · 字 `#1a1a22` · accent `#7C4DFF`
- **Dark**: 底 `#0F0E14` · 字 `#fff` · accent `#B888FF`
- **Collection hue**: 紫 270 · 红 0 · 绿 145 · 蓝 220 · 黄 50 · 粉 320

### 字型
- Display + Body: **Inter** (300-900)
- 数据 / 角标 / 快捷键: **ui-monospace** (SF Mono)
- **不使用衬线** (v1 探索过 Newsreader,用户反馈"太老派",已弃用)

### 关键签名细节
1. 多彩 collection 卡片,每张主调 hue 不同,带高光圆球装饰
2. R18 遮罩用纯黑底 + mono 字符 `R18`,不用 emoji
3. After Hours 私密列表用 `PIN` mono 角标
4. AI 建议卡用紫粉渐变 + 真实可计算的洞察 (例:"你 3 个月没看 X")
5. 导演 / 演员头像用首字母 + hue 渐变圆,不画 SVG 人脸

## 反 slop 红线 (已严格执行)

- 无 emoji 图标 (R18 / PIN / 评分都用 SVG 或 mono)
- 无紫色渐变填充背景 (紫只在 accent 和一个 collection)
- 无圆角左 border accent 卡片
- 无 SVG 画人物 / 物品
- 无每处都配的装饰图标
- 无编造的装饰 stats (统计条只展示真实可计算字段)

## 与现有代码的对应

设计参考了 `lib/` 中已有的产品架构:

| 后端 / 数据层 | 对应设计屏 |
|---|---|
| `core/api/services/movies_api.dart` | `01_library_favorites.html` (Library) |
| `core/api/services/actors_api.dart` + `directors_api.dart` | `02_detail.html` (Person Detail) |
| `core/api/services/genres_api.dart` + `tags_api.dart` | `03_browse_search_settings_player.html` (Browse) |
| `features/favorites/` | `01_library_favorites.html` (Favorites) + Watchlist |
| `core/config/server_config_*` | `04_onboarding.html` (Server Setup) |
| `core/platform/` 平台抽象 | 设计稿仅给 iOS,Android 沿用 Material 等价 |

## 实施建议

1. **优先实施 04 (Onboarding) + 01 Library** —— 这是冷启动到能用的最短路径
2. **字体引入** Inter (Google Fonts) + 系统等宽备用
3. **颜色 token** 写进 `core/platform/theme.dart` (新建),亮暗双套,见 `brand-spec.md`
4. **R18 遮罩**走 `Movie` model 的 `restricted` flag,在 `movie_card.dart` 层统一处理
5. **PIN 私密列表**走 SharedPreferences + 启动门控
