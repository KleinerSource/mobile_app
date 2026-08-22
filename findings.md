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

## 当前任务：GitHub Actions 编译失败

- 工作区：`D:\Projects\MyProject\ghs\md_center\mobile_app`。
- 当前分支：`master`，相对 `origin/master` 落后 1 个提交；工作区初始无未提交代码改动。
- 仓库未包含 `.codegraph/`，本任务不使用 CodeGraph。
- 项目是 Flutter/Dart 工程，存在 `pubspec.yaml`、`android/build.gradle.kts`、`android/app/build.gradle.kts`。
- 需要先通过 `gh` 获取具体失败运行和日志，不能仅凭项目结构猜测修复原因。

### Actions 失败证据

- Android 运行：`32575915349`，提交 `affc4bb298624864bc5253fe9e5716e5a0de9c74`，失败于 `test`，`311 tests passed, 1 failed`。
- iOS 运行：`32575915343`，同一提交，失败于 `test`，`311 tests passed, 1 failed`。
- 两个平台的唯一失败用例均为 `test/features/drag_selection_pages_test.dart: 收藏夹列表仍保留左滑移除`。
- 断言为 `Expected: no matching candidates`，实际发现 1 个带 key `1` 的 widget；因此更像是测试/实现行为回归，而非平台编译差异。
- 根因确认：`lib/core/api/services/favorites_api.dart` 与生成文件已使用 `POST /favorites/delete`；`test/features/drag_selection_pages_test.dart` 的 `_fakeResponse` 仍只处理 `POST /favorites/batch-delete`，导致删除请求被 fake Dio 拒绝，`_removeOne` 捕获异常后保留列表项。
- 修复策略：只更新测试 fake endpoint，不改变已经与后端统一接口的生产 API。
