# 播放器统一改造发现记录

## 当前状态

- 工作目录：`D:\Projects\MyProject\ghs\md_center\mobile_app`
- 当前分支：`dev`，跟踪 `origin/dev`
- 初始工作区：`git status --short --branch` 未显示未提交文件改动
- 项目根目录未发现 `.codegraph`，不使用 CodeGraph

## 待确认

- Flutter/Dart 应用的播放器入口、控制器类型和状态管理方式
- `ksplayer` 具体版本及可用的原生手势/控制 API
- `media_kit` 当前封装层是否已有统一接口或仅有独立页面实现
- 进度拖拽与左右亮度/音量手势的冲突仲裁规则
- 测试、分析、构建命令及设备相关验证边界

## 初步文件地图

- `lib/features/player/player_page.dart`：统一播放器页面入口，按设置选择 `media_kit` 或 iOS `ksplayer`，目前已承载亮度/音量系统控制、手势层和覆盖提示。
- `lib/features/player/player_gesture_layer.dart`：现有 Flutter 手势层，注释显示已尝试区分点击、长按调速、左右亮度/音量和横向 seek。
- `lib/features/player/player_controller_host.dart`：`media_kit`/libmpv 控制器封装，`PlayerPage` 不直接接触后端类型。
- `lib/features/player/player_controls.dart`：`media_kit` 控制组件/控制条。
- `lib/features/player/ksplayer_page.dart`：iOS 原生 `KSPlayer` 页面，负责原生视图、配置、事件回调和生命周期。
- `lib/features/player/ksplayer_platform.dart`：Flutter `MethodChannel` 控制器及 PlatformView 注册。
- `ios/Runner/KSPlayerPlatformView.swift`：KSPlayer 原生视图实现，需与 Flutter 手势/能力层一起核对。
- `test/features/player_gesture_layer_test.dart`：手势层已有单测，应作为新行为回归入口。

## 初步风险

- 现在 `PlayerPage` 的 `PlayerGestureLayer` 仅包围 `media_kit` 分支还是同时包围 `ksplayer`，需要确认；如果只在 Flutter 层包裹，会与 KSPlayer 原生手势重复竞争。
- `ksplayer_page.dart` 可能已有原生手势开关或事件回调，不能在不了解原生实现前直接复制 Flutter 手势。
- 亮度是应用亮度，音量是系统音量；统一能力接口应区分“播放器能力”和“系统输出副作用”，避免重复初始化/恢复。

## 手势层现状（已确认）

- `PlayerGestureLayer` 已实现四类基础交互：点击显隐、双击、长按调速、水平 seek、垂直亮度/音量。
- 当前手势层通过单个 Flutter `GestureDetector` 依赖 gesture arena；长按默认起始 `2.0x`，可按垂直位移在 `0.5x~4.0x` 调节；seek 以全屏宽度映射 `90s`，拖动时预览、抬手提交。
- `PlayerGestureLayer` 只提供回调，不直接绑定后端；统一能力可以放在更上层控制器接口，避免为 `ksplayer` 复制同一套手势判定。
- `KsPlayerPlatformController` 目前只有 `play/pause/seek/setRate/stop/dispose`，未提供播放状态、位置/时长事件、音量/亮度或手势相关 API。
- `KsPlayerPlatformView` 原生事件通过 `onEvent` 转发到页面，但当前 controller 是一次性回调对象，后续能力需要扩展其 API 或增加通用适配接口。

## KSPlayer 现状（已确认）

- `KsPlayerPage` 当前只渲染 `KsPlayerPlatformView` 和队列按钮，不挂载 `PlayerGestureLayer`，因此 Flutter 侧已有的亮度、音量、长按调速、水平 seek 只覆盖 `media_kit`。
- KSPlayer 原生桥接 `KSPlayerFlutterView: IOSVideoPlayerView`，当前只桥接播放、暂停、seek、倍速、停止、释放，以及时间/状态/结束/错误/清晰度事件。
- 原生 `IOSVideoPlayerView` 已继承 KSPlayer 自带的 UI/手势基类能力，但项目层没有显式配置或验证其手势能力，且没有把亮度、音量、长按快进、横向进度的语义与 Flutter 手势层统一。
- `seekPlayer` 当前调用 `seek(time:autoPlay: true)`，这可能使拖动提交无条件恢复播放；需要与 `media_kit` 的暂停态/播放态语义对齐。
- Swift 桥接的 `setRate` 直接改 `playerLayer?.player.playbackRate`，但没有把播放速率变化回传给 Flutter。
- `KSPlayerPlatformView` 在 `dispose` 时调用 `disposePlayer`，页面 `_cleanupInternal` 又显式调用 `stop` + `dispose`；需要检查是否存在幂等性风险。

## `media_kit` 统一入口现状（已确认）

- `PlayerPage.open` 在 iOS + `PlayerKernel.ksPlayer` 时直接切换到独立的 `KsPlayerPage`；否则进入 `PlayerPage`。
- `PlayerPage` 的 Flutter 手势层位于 `Video` 之上，回调直接调用 `_host.seek`、系统亮度和系统音量、`_onRateBoost`，所以这些交互当前天然只对 `media_kit` 生效。
- `PlayerControllerHost` 已经提供可供抽象层复用的 `open/seek/setRate/playOrPause/stop/dispose` 和 position/duration 流，但类型上仍直接绑定 `media_kit` 的 `Player`/`VideoController`。
- `PlayerControllerHost.seek` 不强制起播，符合保留播放态的预期；这与 KSPlayer 桥接当前 `autoPlay: true` 不一致，是统一能力层必须修正的关键点。
- 亮度/音量初始化和离场恢复全部在 `PlayerPage`，`KsPlayerPage` 没有对应生命周期处理。

## 测试现状（已确认）

- `test/features/player_gesture_layer_test.dart` 目前只覆盖“单击显隐不触发震动”，没有覆盖长按、垂直分区、水平 seek、边界钳制、取消和播放态保持。
- 目前没有发现 KSPlayer PlatformView/MethodChannel 的 Dart 或 Swift 单元测试；新增统一适配后需要优先给纯 Dart 的能力/手势仲裁补测试，原生桥接至少做静态/编译验证。

## 依赖版本

- iOS Swift Package 锁定 `KSPlayer` `2.3.4`，revision `bdfa2da39bb18865b317c4ffd08cdef5f8efc043`。
- Dart 侧锁定 `media_kit ^1.2.6` 与 `media_kit_video ^2.0.1`，本地还包含 Android/iOS `media_kit` 原生库包。
- KSPlayer 源码不在当前仓库，原生 API 能力需要以已锁定版本的源码/构建结果为准，不能假设最新版本接口。

## 外部源码获取

- 已创建临时只读 clone 目录：`C:\Users\KleinerSource\AppData\Local\Temp\md-center-ksplayer-2.3.4`。
- 首次 clone 命令在拉取/检出阶段超时，当前临时仓库尚未有可解析的 `HEAD`；不把未确认的外部源码结论写入实现。
- 后续 fetch 已拿到目标 revision，但 checkout 受到首次 clone 遗留的 `.git/index.lock` 阻塞；临时仓库当前显示 `main` 的不完整工作树，正在等待后台 git 进程结束，暂不操作锁文件。

## KSPlayer 2.3.4 原生手势结论

- `IOSVideoPlayerView` 已原生继承 `VideoPlayerView` 的 `UIPanGestureRecognizer`、单击/双击和长按手势。
- 原生垂直手势：左半屏修改 `UIScreen.main.brightness`，右半屏通过 `MPVolumeView` 的 slider 修改系统音量；`KSOptions.enableBrightnessGestures` 和 `enableVolumeGestures` 默认均为 `true`。
- 原生水平手势：通过 `tmpPanValue + panValue(...)` 实时预览，抬手调用 slider 提交；`KSOptions.enablePlaytimeGestures` 默认 `true`。
- 原生长按手势：按下设置 `playbackRate = 2.0`，结束/取消恢复原始倍速；默认长按时长 `0.5s`。
- `IOSVideoPlayerView.judgePanGesture()` 会在播放中、未结束且未锁屏时启用 pan；横屏或 iPad 始终可用，竖屏要求播放按钮为播放态。
- 因此本次实现不应在 KSPlayer PlatformView 上再叠加 Flutter `PlayerGestureLayer`，否则会出现两个手势识别器竞争、原生控制条触摸被拦截和重复 seek/音量变化。
- 需要在项目桥接层显式设置 `KSOptions` 开关，并补齐 KSPlayer 页面自身的亮度生命周期、系统音量 HUD 控制和基础状态语义；核心四类手势应直接复用 KSPlayer 原生实现。

## 设置映射风险

- Flutter `PlayerSettings` 目前只有 Flutter 手势的震动/双击开关，没有 KSPlayer 原生手势开关；原生四类手势应默认开启，避免用户选择 KSPlayer 后能力缺失。
- `PlayerSettings` 的控制条显示项、设备状态覆盖层、应用内 Haptic 与 KSPlayer 自带控制条并不一一对应；若要完全统一，需要额外桥接原生 UI 配置，当前先聚焦执行逻辑和核心手势。
- KSPlayer 原生长按固定 `2.0x`，与 Flutter `0.5x~4.0x` 的长按调速扩展不同；“对标 media_kit”不能假设两边调速细节完全相同，应该保持 KSPlayer 原生语义并统一生命周期/恢复倍速。

## 原生与页面生命周期差异

- KSPlayer 原生双击语义是切换播放/暂停并显示控制层，与 Flutter `media_kit` 的双击中间区域语义一致；原生没有左右边缘双击 seek。
- KSPlayer 原生单击只切换自己的控制层，原生水平/垂直 pan 只在播放态和允许条件下启用；因此不应由 Dart 额外驱动 `_toggleControls` 或 seek。
- `KsPlayerPage` 当前缺少 `FlutterVolumeController.updateShowSystemUI(false/true)`、应用亮度退出恢复以及 inactive/paused 时的暂停/恢复，和 `PlayerPage` 生命周期不一致。
- 最小统一方案：保留 KSPlayer 自带控制层和四类手势；在 Swift 桥接显式打开原生手势、修正 seek 播放态保持；在 Dart 页面补齐系统资源生命周期、后台暂停恢复和进度上报；不复制 `PlayerGestureLayer`。

## 已实现的第一版

- 新增 `PlayerSystemLevels` 作为两种播放器共用的系统亮度/音量作用域：初始化读取当前值、亮度更新串行化、离场恢复初始亮度、切换系统音量提示。
- `KsPlayerPage` 已接入该作用域，并处理 `inactive/hidden/paused/resumed` 的暂停/恢复和进度上报。
- `PlayerPage` 同步改为使用共享作用域，并增加生命周期去重，避免 `hidden` 与 `paused` 连续回调重复暂停或覆盖恢复标记。
- Swift 桥接已显式打开 KSPlayer 原生三类开关（亮度、音量、进度），控制层隐藏时间与 `media_kit` 对齐到 3 秒，seek 改为保持原播放态，释放和事件发送增加幂等保护。
- 额外覆盖 KSPlayer 默认 pan 启用条件：在播放媒体且未锁屏/结束时，暂停态也保留原生 pan，避免与 `media_kit` 的暂停态 seek/亮度/音量能力不一致。

## 代码复核

- 共享系统作用域的亮度写入通过 Future chain 串行执行，退出恢复会排在初始化/最后一次亮度写入之后，覆盖初始化竞态。
- `KsPlayerPage` 没有引入 Flutter `PlayerGestureLayer`，原生控制层和原生四类手势仍是唯一输入路径。
- `flutter analyze` 通过后，补充的四项手势测试（单击、左右垂直、水平边界、长按）已全部通过。

## 验证记录

- `dart format` 已完成。
- 首次 `flutter analyze` 未发现类型/语法错误，仅发现共享层对 `updateShowSystemUI` 缺少显式 `unawaited`，待修复后重跑。
- 首次新增手势测试使用固定屏幕坐标，拖动未命中实际 widget；这是测试定位问题，不是实现回调失败，已改为按 widget 实际矩形计算起点。
- 第二次手势测试已能命中回调；剩余失败来自测试布局实际高度与假设不一致，以及 `DoubleTapGestureRecognizer` 的 40ms 定时器未等待，测试将改为相对尺寸断言并补 pump。
- 第三次测试确认实际差异来自 Flutter gesture arena 的触摸 slop（约 20px 不进入业务增量），不是手势分区错误；测试改为验证方向和左右幅度对称。

## 收尾复核状态

- 上一轮已完成 `flutter analyze`、`flutter test test/features/player_gesture_layer_test.dart` 和完整 `flutter test`；完整测试结果为 265 项通过。
- 上一轮已完成 `dart format` 和 `git diff --check`；本轮仅复核最终差异，不重新引入无关格式化。
- iOS 原生桥接尚未在当前 Windows 环境编译；交付时需明确该验证边界，并建议在 macOS/Xcode 或 CI 运行 `flutter build ios --no-codesign`。

## 最终源码复核重点

- `KsPlayerPage` 没有重复包裹 `PlayerGestureLayer`；KSPlayer 原生手势仍是唯一输入路径，避免 Flutter PlatformView 与 UIKit 手势竞争。
- `PlayerSystemLevels` 的亮度和音量操作均通过 Future 链串行化，恢复操作会排在初始化和最后一次亮度写入之后；页面只在 media_kit 手势层显示 Flutter 指示器，KSPlayer 继续使用原生反馈。
- `KsPlayerPage` 与 `PlayerPage` 的后台状态都采用去重标记，连续 `inactive -> paused -> hidden` 不会重复暂停，恢复只在进入后台前处于播放态时起播。
- 原生 `seekPlayer` 使用当前 `state.isPlaying` 决定 `autoPlay`，因此暂停态 seek 不会被强制起播；`disposePlayer` 和事件发送均有幂等保护。
- `flutter_volume_controller` 的 `setVolume` 返回异步平台调用；共享层已补充音量写入 Future 队列，连续滑动时按最新的逻辑顺序依次落地，避免异步回写乱序。
