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

## 当前任务：iOS 16+ 列表滑动菜单重构

- 目标组件是 `lib/shared/swipe_actions.dart` 中的 `SwipeActionCell`，被影片、收藏、演员、资源、音频、映射、媒体库和服务器列表共享。
- Apple 公开契约：全滑默认开启并执行动作列表的第一个动作；动作按声明顺序从滑动起始边缘排列，因此 `actions.first` 必须最靠近尾缘。
- 当前实现存在结构性问题：越过 55% 在手指未松开时即提交；快速全滑阶段视觉冻结；多动作时第一个动作不在尾缘；普通吸附动画和手势取消缺少完整的可中断状态管理。
- 实现采用单一像素位移、`0.998` 速度投影和三个落点（收起/展开/整行），避免继续叠加离散速度阈值。
- CodeGraph 确认 `SwipeActionCell` 有 15 个生产调用点；共享测试是主要直接覆盖，页面级 `drag_selection_pages_test.dart` 提供业务回归。
- 所有调用方都未显式传入 `fullSwipeIndex`，因此将接口收敛为 `allowsFullSwipe` 不需要迁移业务页面参数。
- 多动作普通展开应按 `actions.reversed` 排列，使 `actions.first` 位于行尾缘；全滑阶段按进度压缩其余动作宽度，并让首动作接管剩余宽度，直至整行。
- `DragStartBehavior.down` 配合 `globalPosition` 起点可把手势竞技场判定前的初始位移计入累计拖动；动画中途开始手势时从控制器当前像素值接续。
- 减少动态效果时使用短促无回弹 `animateTo`；常规吸附使用 `mass: 1, stiffness: 440, damping: 42` 的近临界阻尼弹簧。
- 当前 Flutter SDK 的 `CustomSemanticsAction` 定义在 `package:flutter/semantics.dart`，`DragStartBehavior` 定义在 `package:flutter/gestures.dart`；`material.dart` 不转出这两个符号。
- 全仓库未发现显式 `fullSwipeIndex` 调用，生产调用点无需业务迁移；新增接口只需共享组件测试覆盖 `allowsFullSwipe`。
