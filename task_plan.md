# 首页封面切换优化计划

## 目标

参考用户提供的首页截图，将首页轮播调整为：封面区域在横向切换时保持固定，通过边缘直切展示下一张封面；只有影片信息区域随当前项切换，不让整张封面跟随滚动位移。

## 阶段

- [x] 定位首页轮播入口与当前动画实现
- [x] 调整轮播布局与切换动画
- [x] 更新/补充必要测试
- [x] 运行静态分析、测试与差异检查

## 约束与假设

- 保留现有首页数据源、点击进入详情、自动播放、指示器和纵向滚动行为。
- “封面保持不移动”指横向切换时封面不跟随 PageView 滑动，改为固定槽位的直切；信息层按当前索引同步切换。
- 不修改用户此前已经完成的其他首页样式调整。

## 错误记录

| 错误 | 处理 |
| --- | --- |
| Product Design 用户上下文脚本路径不存在 | 使用当前用户附图与仓库现有设计系统继续实施，未声称已加载持久化上下文 |
| 回归测试按 `ClipRect` 类型计数得到 2 个匹配 | `CachedNetworkImage` 内部也使用 `ClipRect`，为新增边缘裁切节点增加稳定 key 并改测该 key |

## 当前任务：修复 GitHub Actions 编译失败

### 目标

定位最近一次 GitHub Actions 编译失败的真实原因，进行最小范围修复，并用本地等价检查验证。

### 阶段

- [x] 获取失败的 GitHub Actions 运行与日志
- [x] 定位根因并实施最小代码/配置修复
- [x] 运行本地静态分析、测试或构建验证
- [x] 检查差异并总结结果

### 当前错误记录

| 错误 | 处理 |
| --- | --- |
| `gh-fix-ci` 技能文件路径在当前环境不存在 | 按该技能的目标流程使用 `gh` CLI 继续排查 |
| 当前仓库没有 `.codegraph/` | 跳过 CodeGraph，使用仓库工具和文件检查 |
| 测试假 API 仍匹配旧的 `/favorites/batch-delete` | 同步为实际客户端使用的 `/favorites/delete` |
| 预期 workflow 文件名不存在 | 先列出 `.github/workflows`，改读实际的 `android-build.yml` 与 `ios-build.yml` |

## 当前任务：iOS 16+ 列表滑动菜单重构

### 目标

重构共享 `SwipeActionCell`，让 iOS 与 Android 统一采用 iOS 16+ 的列表行滑动语义：直接跟手、速度投影、可中断吸附、松手提交、第一个动作位于尾缘并承担全滑。

### 阶段

- [x] 恢复会话并确认工作区状态
- [x] 用 CodeGraph 核对当前实现、调用方与影响范围
- [x] 重写滑动状态机和多动作布局
- [x] 扩充共享组件测试
- [x] 运行页面回归、格式化、静态分析和完整测试
- [x] 检查最终差异并总结

### 约束与决策

- 仅修改列表行左滑交互，不修改 `GlassMenuAnchor`。
- 两个平台共享同一套行为，不增加平台分支或第三方依赖。
- 全滑默认开启且只执行 `actions.first`；动作按声明顺序从尾缘向内排列。
- 手指按住期间不执行动作，越过临界点后允许回滑撤销。
- 保留现有业务回调、颜色、动作宽度和圆角。

### 当前错误记录

| 错误 | 处理 |
| --- | --- |
| 工作区存在未跟踪 `.codegraph/` | 视为用户/环境数据，仅只读使用，不纳入本次差异 |
| `$env:FLUTTER_ROOT` 未设置，无法按该路径检索 Flutter SDK 源码 | 采用项目编译器验证公开 API，不重复依赖该环境变量 |
| 首次编译提示 `CustomSemanticsAction` 与 `DragStartBehavior` 未导入，且预备状态字段未读取 | 增加 `flutter/semantics.dart`、`flutter/gestures.dart` 导入，并将预备状态纳入松手决策 |
| 首次 `apply_patch` 同时删除并新增同一路径被拒绝 | 拆成先删除、再新增的两个补丁后成功写入 |
| 旧版“按钮贴尾缘”测试发现部分展开时按钮固定在屏幕尾缘、与内容尾缘重叠 18px | 动作层在部分展开阶段改为锚定内容当前尾缘，仍由行边界裁剪 |
| 辅助功能测试首次将 `customAction` 直接调用在 `WidgetTester` | 按当前 Flutter API 改为 `tester.semantics.customAction` |
| `SemanticsController.customAction` 不接收普通 widget Finder | 改用 `find.semantics.byLabel` 定位合并后的语义节点 |
| 多动作布局测试首次拖动速度使投影直接选择整行，布局已在断言前收起 | 延长普通展开拖动时间，使该阶段明确落在动作区落点 |
| 语义句柄用 `addTearDown` 释放晚于框架句柄校验 | 在测试末尾显式调用 `SemanticsHandle.dispose()` |
| 反向速度测试受测试手势最后采样速度和竞技场时序影响，可能落在普通展开落点 | 断言核心契约为不提交，同时允许普通展开落点保留 |
| 用户反馈短距离快速滑动容易误触默认动作 | 仅当位移达到动作区+一个动作宽度（窄行取全滑临界点）时加入整行落点，短快甩保持普通展开 |
# 当前任务：Flutter iOS 播放器内核与项目播放器模块分析（2026-08-23）

## 目标

基于项目源码、依赖锁定信息和权威文档，说明 Flutter 在 iOS 可用的主要播放器内核，并还原当前 App 已使用的播放器模块、底层内核、调用链和能力边界。

## 成功标准

- [x] 区分 Flutter 播放器封装与 iOS 真正解码/渲染内核。
- [x] 盘点主流 iOS 内核、Flutter 接入方式、协议/格式、硬解、DRM 与维护风险。
- [x] 从项目依赖和源码确认实际播放器组件、封装层、页面入口与原生配置。
- [x] 给出与当前项目直接相关的选型建议，并标注证据与不确定项。

## 阶段

1. [已完成] 项目发现 → 验证：依赖、源码调用链、iOS 配置证据互相印证。
2. [已完成] 权威资料核验 → 验证：优先官方文档、插件源码/发布页与 Context7。
3. [已完成] 对比与结论 → 验证：形成内核矩阵、项目现状图和建议。
4. [已完成] 交付检查 → 验证：所有结论可追溯，不修改业务代码。

## 假设与边界

- “播放器内核”按 iOS 侧实际媒体引擎理解，包括 AVFoundation/AVPlayer、FFmpeg、libmpv、VLC/libVLC、IJKPlayer 等；Flutter package 视为接入/控制层。
- 分析本地当前工作树，而非仅以仓库默认分支为准。
- 只做读取、分析和验证；计划记录文件除外，不修改业务代码。

## 当前错误记录

| 错误 | 尝试 | 处理 |
| --- | --- | --- |
| 首次通过 JavaScript 包装调用 CodeGraph 出现 `SyntaxError: Invalid or unexpected token` | 1 | 简化为无额外转义的单行调用，不重复原调用格式。 |
| 读取 `ios/Podfile` 失败：文件不存在 | 1 | 不假定 CocoaPods 文件已提交；改为枚举 `ios/` 构建配置，并以插件依赖清单、podspec 和 Xcode 工程为证据。 |
| Context7 三个库解析请求均返回月度配额已耗尽 | 1 | 停止重复 Context7 请求，改为直接读取 Apple、Flutter、media_kit、mpv/VLC 等官方文档和仓库。 |
| 浏览器读取 Apple AVPlayer 文档 JSON 被客户端阻止（`ERR_BLOCKED_BY_CLIENT`） | 1 | 不重复同一路径的浏览器导航；改用只读 HTTP CLI 获取 Apple 官方 JSON。 |
| 查询 pub.dev 包状态的 PowerShell `foreach` 后直接管道导致 `ParserError` | 1 | 用变量接收 foreach 输出后再 `Format-Table`，不重复原管道结构。 |
| GStreamer 官方 iOS 文档页返回 503 backend timeout | 1 | 不重复刷新页面；改读 GStreamer 官方 GitLab 文档源文件。 |
