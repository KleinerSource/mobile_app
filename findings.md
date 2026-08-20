# 首页封面切换调查记录

## 参考图要点

- 顶部主封面占据固定区域，切换时以垂直边缘直接切换到下一项。
- 影片标题、评分/年份/标签、简介等信息位于封面下方的固定信息层。
- 信息层在当前影片变化时更新，不应与封面一起产生横向拖动位移。

## 当前实现

- `lib/features/home/recommend_carousel.dart` 使用 `PageView.builder` 负责整块轮播内容。
- `lib/features/home/home_page.dart` 通过 `RecommendCarousel` 将轮播放入可纵向滚动的首页 Sliver 中。
- `lib/features/home/hero_backdrop.dart` 监听轮播位置，仅用于氛围背景，不应被本次修改破坏。

## 实现方向

- 将封面容器与影片信息层从整页 `PageView` 中拆出。
- 封面使用固定 `Stack`/裁剪槽位，通过当前索引切换内容，不让封面容器横向移动。
- 信息层使用当前索引对应的影片数据，采用无位移的直切/短淡入切换。
- 保留横向手势，但让手势只改变索引，不让用户看到整张封面被拖走。

## 已实施

- `RecommendCarousel` 的 `PageView` 现在只渲染透明的信息层。
- 固定封面层根据 `PageController.page` 的小数进度，以右侧垂直裁切区域展示下一张封面。
- 封面图片关闭淡入，避免边缘直切时出现额外交叉淡化。
