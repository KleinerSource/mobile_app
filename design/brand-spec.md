# md_center · Brand Spec

> 定稿日期: 2026-05-22
> 设计方向: **多彩集合派** (Playful · Apple Music / Spotify 同气质)
> 双版本: Light + Dark · 系统跟随
> 适配: iPhone 15 Pro (393 × 852) · Android 沿用 Material 等价

## 产品定位

私有影视媒体库的移动客户端,服务于自建片源 + 重元数据浏览的影迷收藏者。
**不是** 流媒体消费工具,而是「我的电影馆」—— 移动端是浏览 / 选片 / 管理入口,投屏到电视播放。

## 目标群体

- 自建 Plex / Jellyfin / Emby 用户,但嫌默认 UI 不够好看
- Letterboxd 重度影迷,在意演员 / 导演 / 类型 / 标签等元数据维度
- 包含成人内容观看场景 → 需要 R18 遮罩 + PIN 私密列表

## 核心理念

「像翻一本充满色彩的电影杂志」—— 多彩集合卡片 + 个人化问候 + 系统玻璃感。
活泼但不轻佻 · 信息密度高但不杂乱 · 包容成人场景但绝不低俗。

## 色板

### Light (奶油主题)

| Token | HEX | 用途 |
|---|---|---|
| `bg` | `#FAF6F0` | 主背景 · 奶油暖白 |
| `text` | `#1a1a22` | 主字 |
| `text-2` | `#3a3a45` | 次字 |
| `muted` | `#6e6e7a` | 弱字 / meta |
| `muted-2` | `#9a96a8` | 占位 / disabled |
| `accent` | `#7C4DFF` | 主品牌色 / 链接 / active |
| `card-bg` | `#fff` | 卡片底 |
| `card-border` | `rgba(0,0,0,0.05)` | 卡片描边 |
| `chip-bg` | `rgba(0,0,0,0.05)` | chip 默认 |
| `chip-bg-active` | `#1a1a22` | chip 选中 |
| `tab-active-bg` | `#1a1a22` | TabBar active |
| `glow-1` | `#7C4DFF` 55% opacity | 背景紫光晕 |
| `glow-2` | `#FF6B9D` 55% opacity | 背景粉光晕 |

### Dark (墨夜主题)

| Token | HEX | 用途 |
|---|---|---|
| `bg` | `#0F0E14` | 主背景 · 带紫粉光晕 |
| `text` | `#fff` | 主字 |
| `text-2` | `#d8d4e0` | 次字 |
| `muted` | `#9a96a8` | 弱字 / meta |
| `muted-2` | `#6e6a7a` | 占位 / disabled |
| `accent` | `#B888FF` | 主品牌色 (比 Light 亮一档) |
| `card-bg` | `rgba(255,255,255,0.04)` | 卡片底 (玻璃) |
| `card-border` | `rgba(255,255,255,0.06)` | 卡片描边 |
| `chip-bg` | `rgba(255,255,255,0.08)` | chip 默认 |
| `chip-bg-active` | `#fff` | chip 选中 |
| `tab-active-bg` | `#fff` | TabBar active |
| `glow-1` | `#7C4DFF` 18% opacity | 背景紫光晕 |
| `glow-2` | `#FF6B9D` 18% opacity | 背景粉光晕 |

### Collection Hues (集合卡片 4 色环)

每个 hue 都按 `hsl(H, 70%, 55%) → hsl(H+30, 75%, 35%)` 135° 渐变,叠加 `hsla(H, 90%, 70%, 0.4)` 高光圆球(top-right, blur 8px)。

| 名称 | Hue | 语义 |
|---|---|---|
| Lavender | 270 | Watchlist / 一般集合 |
| Coral | 0 | All-Time Best / 高优先级 |
| Mint | 145 | Weekend Picks / 轻松 |
| Sky | 220 | After Hours / 私密 (配 PIN 角标) |
| Solar | 50 | Comedy / 黄色 (genre chip 用) |
| Magenta | 320 | Animation (genre chip 用) |

## 字型

```css
--font-body: 'Inter', -apple-system, BlinkMacSystemFont, system-ui, sans-serif;
--font-mono: ui-monospace, 'SF Mono', 'JetBrains Mono', monospace;
```

- **Inter** 用于所有 display + body + UI 字 (300-900 全套)
- **ui-monospace** 用于数据 (评分 / 时长 / 计数) · 角标 (R18 / PIN) · 快捷键 (⌘K) · 服务器路径

**不使用衬线字体** —— v1 阶段探索过 Newsreader,用户明确反馈"太老派",已弃用。

### 字号节奏

| 用途 | size | weight | letter-spacing |
|---|---|---|---|
| Page Title | 28-30 | 800 | -0.03em |
| Section Title | 20 | 800 | -0.025em |
| Hero Title | 24-26 | 800 | -0.02em |
| Card Title | 13-15 | 700 | -0.01em |
| Body | 13-14 | 500-600 | 0 |
| Meta / Subtitle | 11-12 | 600 | 0.02em |
| Eyebrow / Label | 10-11 | 700 | 0.15-0.22em (uppercase) |
| Code / Mono | 9-11 | 600-700 | 0.05-0.1em |

## 设备框 + 导航

- iPhone 15 Pro logical: **393 × 852**
- 圆角 45px(屏) / 56px(外框)
- Status bar 高 54px (顶部内容必须从 top: 54 起算)
- Dynamic Island: 124 × 36,top: 12,居中
- Home indicator: 140 × 5,bottom: 10

底部 4 Tab (悬浮胶囊):
```
Home | Library | Search | You
```

胶囊样式: 60px 高 · 100px 圆角 · 背景 `tab-bg` (玻璃) · active 项内嵌反色 pill。

## 签名细节 (做到 120% 的地方)

1. **多彩 collection 卡片**: 4 张 2×2 网格,4 个 hue,每张右上角高光圆球 (blur 8px)
2. **AI 建议卡**: 紫粉渐变背景 + 真实可计算洞察 (例:"你 3 个月没看 Aftersun")
3. **悬浮 TabBar**: 始终离底 18px,带阴影,毛玻璃
4. **导演 / 演员头像**: 首字母 + hue 渐变圆 + 投光阴影,**不画 SVG 人脸**
5. **评分角标**: 黑色玻璃胶囊 + SVG 黄星 + 数字 (不用 emoji ★)

## 成人内容规则

| 项目 | 规则 |
|---|---|
| 海报遮罩 | 纯黑 `#0A0807` + 居中 mono 字符 `R18` · 字色 `rgba(255,255,255,0.4)` |
| 列表标题 | 显示 `Restricted` 斜体灰字,不显示原片名 |
| 角标 | 陈金底 `rgba(184,153,104,0.85)` + mono `R18` 大写白字 |
| 私密列表 | 集合卡片右上角 `PIN` mono 角标(陈金或黑半透底) |
| 解锁机制 | 设置页 "安全模式" 开关 + 4 位 PIN · 长按列表项可临时显示 5 秒 |
| 隐身模式 | 开启后 Library 计数不含成人内容,Search 不可搜 |

**绝不**使用 emoji / 卡通图标 / 红黄警告色 暗示内容性质。

## 反 slop 红线

| 类别 | 避免 | 采用 |
|---|---|---|
| 图标 | emoji 作图标 (R18/PIN/星等) | SVG 或 mono 字符 |
| 渐变 | 全屏紫渐变背景 | 紫只在 accent · 一个 collection · 局部光晕 |
| 卡片 | 圆角 + 左侧彩色 border accent | 完整 hue 渐变 + 高光圆球 |
| 字体 | 衬线作 display (v1 已弃) | Inter 800 大字号承担 display |
| 人像 | SVG 画人脸 / 物品 | 首字母 + hue 渐变圆 |
| 装饰 | 每处都配 icon | 装饰性 icon 一律去掉,文字 + 分隔点 |
| 数据 | 编造 stats 凑卡片 | 统计条只展示真实可计算字段 |

## 气质关键词

多彩 · 个性化 · 玻璃感 · 系统跟随 · 信息密度高 · 包容场景 · 不轻佻
