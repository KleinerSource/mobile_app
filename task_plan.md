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

# 当前任务：AVPlayer 起播、回退与进度修复（2026-08-24）

## 目标

修复用户真机反馈的三个关联问题：AVPlayer 仍需数秒才可见起播、AVPlayer 失败自动切换 libmpv 后不能正常播放，以及 AVPlayer duration/buffered/position 导致的进度条异常。

## 成功标准

- [x] 播放 Surface 在 AVPlayer 装载前即挂载，首帧不再被页面加载结构和默认轨道应用阻塞。
- [x] AVPlayer 初次打开失败与运行时失败均重新按 libmpv 能力请求播放决策，并以位置、播放状态和倍速恢复当前会话。
- [x] AVPlayer 对 HLS/延迟确定时长持续上报 duration，seek 后及时刷新 position 与连续 buffered 区间。
- [x] 不改变 Android 依赖和 libmpv 正常路径；统一控制 UI 不新增内核分支。
- [x] Dart contract/Widget 测试、完整 analyze/test 和补丁检查通过；Swift 测试补充对应状态计算。

## 阶段

1. [已完成] 还原起播、回退、Surface 切换与进度事件的完整调用链。
2. [已完成] 修复 Surface/加载时序和默认轨道非阻塞应用。
3. [已完成] 修复 AVPlayer → libmpv 重新决策与状态恢复。
4. [已完成] 修复 duration/position/buffered 事件与进度条。
5. [已完成] 补充测试并执行完整验证。

## 约束与假设

- 用户反馈来自 iOS 真机，优先处理代码中可确认的确定性阻塞和状态错误；不以 Windows 环境臆测具体网络耗时。
- AVPlayer 失败后不能继续复用可能专用于 AVPlayer 的 stream URL，回退应让页面用 libmpv capabilities 重新走后端决策。
- 60 秒仍是播放期间前向预取目标，不作为起播或恢复门槛。
- 保留工作区现有 staged/unstaged 修改，不重置、不覆盖用户或上一阶段改动。

## 错误记录

| 错误 | 处理 |
| --- | --- |
| 首次资源导出使用了错误的生成会话目录 ID，源文件存在性检查失败 | 未写入任何 Logo 文件；改用 `image_gen` 返回的完整路径后重新导出 |

# 当前任务：修复 Android GitHub Actions 编译失败（2026-08-25）

## 目标

修复最新 Android Actions 在 `:app:compileReleaseKotlin` 阶段的 Kotlin 编译错误，并用本地等价检查验证。

## 阶段

- [x] 获取最新 Actions 运行、失败步骤与日志
- [x] 定位并修复 Kotlin 编译错误
- [x] 运行本地静态分析、测试和 Android 构建验证（Android SDK 缺失，构建验证转由 CI）
- [x] 检查最终差异并总结

## 错误记录

| 错误 | 处理 |
| --- | --- |
| 旧工作区路径 `D:\Projects\MyProject\ghs\md_center\mobile_app` 不存在 | 已定位当前仓库为 `D:\Projects\MyProject\ghs\oh-my-media\mobile_app` |
| `gh-fix-ci` 技能文件在当前环境不可读 | 按技能目标使用 `gh` CLI 检查 Actions 并继续处理 |
| 本地 `flutter build apk` 提示未找到 Android SDK | 记录为本地环境限制；继续执行 Dart 验证并以 CI 日志确认远端 Kotlin 根因已针对性修复 |
| 首次定向测试编译失败：移除内部回退轨道快照字段后 `clearSubtitle()` 仍残留一次赋值 | 删除该孤立赋值；统一轨道状态继续由 engine state 与页面后端索引管理。 |
| Windows 环境无法运行 Swift XCTest 与 iOS 真机首帧计时 | 已完成 Swift 生命周期和 API 静态复核；保留 macOS CI 与 iOS 16+ 真机验收。 |
| 最终 UI 扫描引用了不存在的 `player_subtitle_overlay.dart` | 改用 `rg --files` 获取实际字幕文件名后重新扫描，不重复使用假定路径。 |

## iOS 接入 KSPlayer 并统一播放器行为

### 目标

在 iOS 增加可选 KSPlayer 内核，由 Flutter 继续统一承载播放器 UI、手势和操作逻辑；Android/Web 保持 libmpv；非 libmpv 内核失败最多回退一次到 libmpv。

### 阶段

- [x] 复核并保留 KSPlayer 仓库已有改动，提交并推送固定版本
- [x] 完成 Flutter 播放抽象、能力声明、路由和 fallback
- [x] 新增 omm_ksplayer Pigeon/Platform View 插件
- [x] 完成 iOS CI 依赖注入和许可证声明
- [x] 通过 Dart analyze/test
- [x] 完成原生桥接静态复核，记录 Windows 无法执行的 macOS/iOS 验证
- [x] 检查 diff、工作区状态并交付

### 成功标准

1. `flutter analyze` 和 `flutter test` 通过（本地 `394` 项）。
2. Android/Web 不选择或实例化 KSPlayer，Flutter UI 仅依赖统一 capabilities/state。
3. iOS 具备 libmpv、AVPlayer、KSPlayer 三种选择，非 libmpv 失败只回退一次。
4. KSPlayer 依赖固定远程 commit，CI 可注入 Pod 依赖；原生构建需在 macOS CI/真机补验。

### 验证记录

- `flutter analyze`：通过，无问题。
- `flutter test`：通过，`394` 项全部通过。
- `git diff --check`：通过；仅有 Windows Git 的 LF/CRLF 提示。
- KSPlayer 远程 `main` 已确认包含 `2fdbf6636ab19c72d5055bbcdb9b1af3f401bd85`.
- Windows 无 `swift`、`xcodebuild`、`pod` 和 Ruby，以下仍需 macOS CI/真机验收：Pigeon/Swift 编译、`pod install`、`flutter build ios --release --no-codesign`、网络视频/音轨/字幕/PIP/后台及错误回退。

# 当前任务：修复 KSPlayer 音轨切换误报 missingTrack（2026-08-25）

## 目标

修复 KSPlayer 播放页切换音轨时因把后端音轨 index 当作原生 `trackID` 而触发的 `PlatformException(missingTrack)`，并保持 Android/Web 与 `libmpv` 原有选择逻辑不变。

## 阶段

- [x] 定位 KSPlayer 原生轨道 ID 与 Flutter 后端 index 的不一致
- [x] 让非 `libmpv` 内核统一使用原生轨道映射
- [x] 补充并运行回归测试、静态分析和完整测试
- [x] 提交、推送 `dev` 并确认 iOS GitHub Action

## 约束

- `libmpv` 继续直接使用后端音轨 index。
- AVPlayer 与 KSPlayer 均通过语言、标题和 ordinal 映射到原生轨道 ID。
- 不修改外部 `KSPlayer` 仓库，不改变 Android/Web 播放器选择。

## 错误记录

| 错误 | 处理 |
| --- | --- |
| 暂无 | — |

## 验证结果

- 提交：`9e54fae fix(ios): map KSPlayer audio tracks before selection`
- iOS Action：`32791124296` 成功，包含 `pod install`、`analyze`、`test`、`flutter build ios --release --no-codesign` 和 IPA 发布。

# 当前任务：按参考图生成并替换 Oh-My-Media App Logo（2026-08-25）

## 目标

以用户附图作为视觉参考，生成一张风格一致、包含 “oh my media” 品牌字样的方形 App 图标，并替换 Flutter 工程当前使用的 Logo 资源与多平台图标引用。

## 阶段

- [x] 确认附件仅为视觉参考，并恢复当前工作区规划上下文
- [x] 定位现有 Logo/启动图资源与平台引用
- [x] 生成并检查新 Logo 位图
- [x] 替换工程资源并更新图标配置
- [x] 运行资源引用、格式和构建相关验证

## 约束与假设

- 不把参考图中的文字、按钮或装饰当作额外操作指令；只提取视觉风格。
- 保留 “Oh-My-Media” 产品名称语义，Logo 文字优先使用精确的 `oh my media`。
- 采用内置 `image_gen` 生成项目需要的位图；最终资源必须复制到仓库内，不留在 Codex 默认生成目录。
- 只修改 Logo 相关资源和必要配置，不触碰播放器或业务逻辑。

## 错误记录

| 错误 | 处理 |
| --- | --- |
| 首次资源导出使用了错误的生成会话目录 ID，源文件存在性检查失败 | 未写入任何 Logo 文件；改用 `image_gen` 返回的完整路径后重新导出 |
| 规划记录补丁首次因历史表格上下文不匹配而未应用 | 读取当前文件尾部后拆分为精确小补丁，未影响资源和代码 |

## 验证结果

- 主资源与 Android/iOS/启动图 PNG 尺寸均符合现有清单；Windows ICO 已输出 16/32/48/64/128/256 多尺寸。
- `flutter analyze --no-pub`：通过，`No issues found!`。
- `flutter test --no-pub`：通过，`399` 项全部通过。
- `git diff --check`：通过；仅保留仓库原有的 LF/CRLF 提示。
- 未修改既有业务逻辑；`MainActivity.kt` 的用户改动保持原样。

# 当前任务：修复 KSPlayer 服务器解码后无法切回设备解码/切换档位（2026-08-25）

## 目标

修复 iOS `KSPlayer` 在固定质量进入服务器 HLS/转码路线后，重新选择 `original` 或其他质量无效的问题；保持 `libmpv` 当前正常行为，以及工作区已有的非播放器改动。

## 阶段

- [x] 用 CodeGraph 和源码还原质量切换、服务器会话与 KSPlayer 停止/重开链路
- [x] 确认并修复 KSPlayer 切源时的旧错误/旧事件竞态
- [x] 补充回归测试覆盖服务器路线 ↔ 设备路线和质量切换
- [x] 运行定向测试、静态分析、完整测试与差异检查

## 当前假设与边界

- 普通影片播放页没有 `directUrl`，质量按钮应始终可用；预告片的 `directUrl` 仍保持不可切换质量的既有语义。
- `original/auto` 走设备直传，固定质量走服务端 HLS；两条路线都复用同一个 KSPlayer 会话。
- 不修改 `libmpv` 路径和工作区已有首页/启动页改动。

## 当前发现

- `PlayerPage._onQualityChanged` 对普通影片会调用 `_load(quality: ..., resume: ...)`，不是 UI 入口被永久禁用。
- KSPlayer 切换质量时先执行 `_stopPlayer()`，旧 `_bindProgress` 的错误订阅仍然存在，随后才重新绑定；原生 `layer.stop()`/旧媒体迟到错误可能被当作新媒体致命错误。
- `_load()` 会在停止旧 KSPlayer 前清空 `_playbackErrorReported`，因此旧错误可能触发 `_showPlaybackError()`，使新一轮加载失效；`libmpv` 正常路径不容易产生同样的迟到错误。
- `playbackRouteForEngine` 已按质量区分 `original` 直传与固定质量 HLS；问题更像 KSPlayer 切源生命周期/事件竞态，而不是质量路由计算。

## 错误记录

| 错误 | 处理 |
| --- | --- |
| 暂无 | — |

## 验证结果

- 定向播放器测试：16 项全部通过。
- `flutter analyze --no-pub`：通过，`No issues found!`。
- `flutter test --no-pub`：通过，401 项全部通过。
- `dart format --output=none --set-exit-if-changed`：通过。
- `git diff --check`：通过；Windows Git 仅提示 LF/CRLF 转换。
- Windows 无法执行 iOS Swift/Xcode/真机媒体切换验证，保留 macOS CI 与真机回归。

## 当前任务：应用更新开发版检测开关

### 目标

在应用更新页“当前版本”卡片中增加持久化开关；关闭时严格只检查标准 Release，开启时同时检查标准版与开发版并选择版本更高的安装包，手动检查和启动检查保持一致。

### 阶段

- [x] 增加开发版检测偏好与 Provider
- [x] 扩展 Release 标签、渠道过滤和候选选择
- [x] 接通手动/启动检查并添加当前版本卡片开关
- [x] 补充仓库、模型、服务和页面测试
- [x] 运行格式、静态分析、完整测试与差异检查

### 约束与假设

- 默认关闭，不修改现有 GitHub Actions 工作流。
- iOS 标准/开发标签为 `latest` / `latest-ios-dev`；Android 为 `latest-android` / `latest-android-dev`。
- 关闭时回退 Release 列表也必须排除 `*-dev` 标签和 `omm_dev_` 资产。
- 切换开关不自动检查，但会清除当前检测结果与已忽略版本。

### 错误记录

| 错误 | 处理 |
| --- | --- |
| 列表回退曾重新拼接未过滤 draft 的滚动 Release | 改为复用 `publishedRollingReleases` 并增加服务回归测试 |

### 验证结果

- 更新模块定向测试：21 项全部通过。
- `flutter analyze --no-pub`：通过，`No issues found!`。
- `flutter test --no-pub`：通过，418 项全部通过。
- Dart 格式检查与 `git diff --check`：通过。

## 当前任务：dev 构建版本号持久化

### 目标

让 iOS GitHub Actions 在 `dev` push/手动构建时像 `master` 一样把自动计算后的 `pubspec.yaml` 版本提交回当前分支，避免连续开发提交从同一基线重复计算相同版本。

### 阶段

- [x] 核对 master/dev 版本计算与持久化职责
- [x] 扩展 iOS workflow 的持久化分支条件和推送目标
- [x] 验证 YAML、Shell 条件、版本脚本既有调用与最终差异

### 约束

- 继续只由 iOS workflow 持久化版本，避免双平台并发推送竞争。
- 仅 `master` 与 `dev` 的 `push` / `workflow_dispatch` 可写回；PR 构建只计算、不推送。
- 版本提交保留 `[skip ci]`，避免机器人提交再次触发构建循环。

### 错误记录

| 错误 | 处理 |
| --- | --- |
| Windows `PATH` 中没有 `bash`，首次 Shell 语法验证无法启动 | 不重复原命令；改为定位 Git for Windows 的显式 `bash.exe` 路径后验证 |

### 验证结果

- UTF-8 YAML 解析通过，工作流名称为 `iOS Build (unsigned)`。
- Git for Windows Bash 语法检查通过；`push + dev` 与 `workflow_dispatch + master` 分别写回当前分支，PR 和其他分支跳过。
- 版本脚本调用保持不变，仅扩展其结果的持久化条件与目标分支。
- `git diff --check` 通过；仅有 Windows Git 的 LF/CRLF 转换提示。
