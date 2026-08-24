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

# 当前任务：iOS 多播放器内核与 libmpv 升级（2026-08-24）

## 目标

在保持 Android 播放路径不变的前提下，将 iOS libmpv 升级到 v0.7.2，并建立统一播放会话接口；iOS 新增 AVPlayer 内核，设置只影响下一次打开媒体，AVPlayer 致命失败时当前会话最多自动回退一次 libmpv。

## 成功标准

- [x] iOS wrapper 统一为 1.1.5，固定 video-full v0.7.2 资产及指定 SHA-256；Android 依赖无差异。
- [x] 播放页、控制栏、字幕层和详情页预告片不再访问具体播放器类型。
- [x] AVPlayer 插件以 iOS 16 为目标，具备播放状态、音轨、PiP、预览帧与类型安全桥接。
- [x] iOS 设置页可选择默认内核，默认 libmpv，且只在新会话读取。
- [x] AVPlayer 按 direct-play → 后端适配 → 单次 libmpv 回退执行，并恢复会话状态。
- [x] Dart 静态分析与测试通过；iOS 原生构建由 macOS CI/真机继续验证。

## 阶段

1. [已完成] 恢复规划记录并核对播放器代码、依赖与测试基线。
2. [已完成] 升级 iOS libmpv wrapper 与固定二进制资产。
3. [已完成] 抽象 MediaKit 为统一 PlaybackEngine 并迁移所有 UI 调用点。
4. [已完成] 新建 AVPlayer 插件、原生实现及 Dart adapter。
5. [已完成] 接入内核偏好、后端播放决策、字幕/音轨与单次回退。
6. [已完成] 补充测试并执行 analyze/test/diff 验证。

## 约束与假设

- 现有用户修改与历史规划记录全部保留，只做本任务所需的外科式变更。
- iOS 默认保持 libmpv；播放中不提供手动热切换。
- 详情页预告片强制 libmpv，但复用统一接口。
- AVPlayer 不模拟 libmpv 的字节缓冲属性；能力差异由 capabilities 表达。
- Windows 环境无法完成 Swift 编译与 iOS 真机验收，原生代码仍需静态检查并交由 CI 验证。

## 错误记录

| 错误 | 处理 |
| --- | --- |
| `session-catchup.py` 只输出 PowerShell profile 警告 | 直接读取现有规划文件与 Git 状态继续恢复，不把该警告视为任务失败 |
| 首次追加规划补丁的上下文标题层级不匹配 | 读取文件尾部后以稳定末行追加，未覆盖历史内容 |
| 清理插件生成缓存的 `Remove-Item` 命令被执行策略拒绝 | 用补丁删除不应提交的插件级 `pubspec.lock`；`.dart_tool/` 已被根 `.gitignore` 排除，不进入交付差异 |
| 首次下沉 UI 内核判断的组合补丁因 `dart:io` import 精确文本不匹配而整体未应用 | 读取精确上下文后拆分为会话工厂、控制器和页面三个小补丁，避免部分写入 |
| 策略下沉后的首次 analyze 提示 `player_page.dart` 的 `foundation.dart` 已由 Material 导出 | 删除冗余 import 后重新验证 |
| 新增平台解析测试首次缺少 `TargetPlatform` import，测试和 analyze 均报 undefined identifier | 在测试文件显式导入 `flutter/foundation.dart` 后重新运行 |
| 音轨映射测试初次构造 `PlaybackAudioTrackState` 缺少必填 `isSelected`，导致全量测试加载失败 | 补齐 `isSelected: false` 并先重跑定向测试，再重跑全量 |

# 当前任务：AVPlayer 弱网缓冲与自动续播（2026-08-24）

## 目标

让 iOS AVPlayer 在点播流短时带宽不足时进入原生等待并自动续播，避免把缓冲误判为用户暂停；保持 Android、libmpv 和统一控制 UI 行为不变。

## 成功标准

- [x] AVPlayer 使用系统防卡顿等待与固定 60 秒前向缓冲，不再使用立即起播 API。
- [x] 播放意图与 `timeControlStatus` 分离，缓冲期间 UI 仍保持播放意图且可手动暂停。
- [x] 监听播放卡顿与播放到结尾失败，卡顿恢复有限且不会循环重试。
- [x] Dart 分析与测试通过；Swift 测试覆盖新增状态转换和资源清理。

## 阶段

1. [已完成] 核对 Pigeon API、Swift 会话实现与测试接缝。
2. [已完成] 实施 AVPlayer 缓冲策略、状态转换和有限恢复。
3. [已完成] 补充原生测试并确认现有 Dart 契约无需变更。
4. [已完成] 运行格式、静态分析、测试和差异检查。

## 约束与假设

- 本轮只处理点播；不为直播流引入相同的 60 秒策略。
- 不把 libmpv 的字节档位映射为 AVPlayer 缓冲时长，也不新增设置项。
- 持续平均带宽低于媒体码率时仍应由后端 HLS/降码率解决，本轮只吸收短时网络抖动。
- Windows 无法运行 Xcode/Swift XCTest，原生代码在本地做静态复核并由 macOS CI/真机最终验证。

## 错误记录

| 错误 | 处理 |
| --- | --- |
| 当前 Windows 环境未安装 Swift/Xcode 工具链，无法执行 Swift XCTest | 已完成 Swift API/生命周期静态复核；保留 macOS CI 与 iOS 真机验证要求 |

# 当前任务：AVPlayer 起播优化与详情页内核测试入口（2026-08-24）

## 目标

将内网 AVPlayer 的可见起播耗时从当前大于 5 秒压缩到接近 libmpv，同时保留 60 秒前向缓冲和卡顿自动续播；在影片详情页长按播放按钮时提供一次性播放器内核选择，普通点击继续使用设置中的默认内核。

## 成功标准

- [x] AVPlayer 初始播放不再被系统保守等待与单音轨枚举无意义阻塞；播放期间持续维持 60 秒前向预取目标，断流恢复不把 60 秒作为门槛。
- [x] 详情页播放按钮普通点击行为不变；长按在 iOS 提供“libmpv / 原生”选择并仅覆盖本次会话。
- [x] Android 仍固定 libmpv，不产生不可用的 AVPlayer 入口。
- [x] 新增文案进入 ARB 多国语言资源，不在 Widget 中硬编码。
- [x] 定向测试、完整 `flutter analyze`、`flutter test` 和差异检查通过。

## 阶段

1. [已完成] 定位详情页播放入口、AVPlayer 初始播放和现有测试接缝。
2. [已完成] 实施 AVPlayer 快速起播且保留播放期间前向预取策略。
3. [已完成] 实施详情页长按选择内核与多语言文案。
4. [已完成] 补充测试并执行完整验证。

## 约束与假设

- 长按选择仅覆盖当前新建播放会话，不修改 `player.ios_engine` 持久化偏好。
- 选择器只展示当前平台真正可用的内核；Android 普通点击路径和二进制依赖不变。
- 60 秒是播放期间持续向前预取的目标，不是首帧或断流恢复门槛；首次播放和有限恢复均尽快启动，AVPlayer 在后台继续填充前向窗口。
- 不引入新的播放器设置或第三方依赖。

## 错误记录

| 错误 | 处理 |
| --- | --- |
| 用 `Get-ChildItem -Filter` 传入多个文件名导致 PowerShell 参数转换失败 | 改为直接读取已确认存在的三个规划文件；未重复错误命令。 |
| 首次追加本任务规划时使用了错误的历史标题层级，补丁未应用 | 读取文件尾部后改用稳定末行追加，未覆盖历史内容。 |
| Windows 下 `rg` 参数中的 `app_localizations*.dart` 通配符未被 shell 展开 | 后续改用目录级 `rg -g` 过滤或读取明确文件，不重复该参数形式。 |
| 最终本地化扫描再次把 `app_*.arb` 作为 Windows 路径参数传给 `rg` | 改用目录参数配合 `-g 'app_*.arb'`；生成文件扫描结果已正常返回。 |
| Windows 环境无法执行 Swift/XCTest 和 iOS 真机起播计时 | 已完成 Swift 静态复核与 XCTest 用例补充；真实起播耗时交由 macOS CI/iOS 真机验证。 |
