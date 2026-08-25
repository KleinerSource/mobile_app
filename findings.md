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

- 工作区：`D:\Projects\MyProject\ghs\omm\mobile_app`。
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
- 用户反馈“稍微快一点就触发默认逻辑”后，整行落点增加距离意图门槛：实际位移未达到 `min(动作区+一个动作宽度, 全滑临界点)` 时，不把整行加入松手落点集合；速度仍用于投影和弹簧速度继承。
# Flutter iOS 播放器分析记录（2026-08-23）

## 用户需求

- 分析 Flutter 在 iOS 平台可用的播放器内核。
- 了解当前 App 项目已经使用的播放器模块。
- 输出需区分 Flutter 上层 package 与 iOS 底层媒体引擎，并给出项目相关建议。

## 初始发现

- 项目根目录存在 `.codegraph/`，后续代码定位优先使用 CodeGraph。
- 根目录已有计划文件，内容属于此前已完成任务；本次以新增章节记录，避免覆盖历史。

## 待核验

- `pubspec.yaml` / `pubspec.lock` 中播放器及关联依赖。
- `lib/` 中播放器控制器、页面、状态管理与调用链。
- `ios/` 中 CocoaPods、Info.plist、网络/后台音频/画中画配置。
- 各候选内核的 iOS 支持边界、许可证、维护状态与 Flutter 生态封装。

## 调查问题

| 问题 | 处理 |
| --- | --- |
| CodeGraph 首次调用的包装脚本语法错误，尚未执行查询 | 改用更简单的 JavaScript 调用格式。 |
| Context7 月度配额耗尽，未返回 media_kit / video_player / flutter_vlc_player 文档 | 按 AGENTS.md 的权威性要求，改查上游官方文档与仓库；最终不把 Context7 调用当作证据。 |

## 项目播放器证据（第一轮）

- 顶层依赖只有 `media_kit ^1.2.6`、`media_kit_video ^2.0.1`，以及项目内路径依赖 `packages/media_kit_libs_ios_video` / `packages/media_kit_libs_android_video`；没有发现 `video_player`、Chewie、Better Player、VLC、IJK 或 FVP 依赖。
- `PlayerControllerHost` 是业务层与内核之间的封装：创建 `Player` + `VideoController`，硬件加速由 `VideoControllerConfiguration.enableHardwareAcceleration` 控制。
- 项目直接访问 `NativePlayer` 的 mpv 属性，配置 `cache`、`cache-on-disk`、`cache-secs`、`demuxer-max-bytes`、`demuxer-max-back-bytes`，可确认主内核不是 AVPlayer，而是 libmpv。
- 项目注释明确当前 iOS 解码链：libmpv 内置 FFmpeg 软解，系统 VideoToolbox 硬解。
- 自定义 iOS 路径包的 Makefile 下载 `media-kit/libmpv-darwin-build` 的 `libmpv-xcframeworks v0.6.0`，文件名为 `ios-universal-video-full`，说明项目不是使用 pub.dev 默认轻量二进制，而是自维护 full 构建。
- `AppDelegate.swift` 另有 `AVPictureInPictureController` 桥接：主播放仍由 media_kit/libmpv 通过 Flutter texture 渲染；进入系统 PiP 时以同一地址临时创建原生 `AVPlayer`，退出后把进度同步回主播放器。
- `Info.plist` 存在 ATS 和 `UIBackgroundModes` 配置，具体键值待下一轮读取。
- 播放器相关业务不仅在 `PlayerPage`：`MovieDetailPage` 也直接依赖 media_kit，可能用于预览/背景播放，需进一步区分。

## 当前初步架构判断

`PlayerPage / MovieDetailPage` → `PlayerControllerHost` 或直接 `media_kit` → `media_kit_video` texture 渲染 → iOS `libmpv` → FFmpeg 解封装/软解 + VideoToolbox 硬解；系统画中画单独旁路到 `AVPlayer`。

## 版本与 iOS 配置证据

- 锁定版本：`media_kit 1.2.6`、`media_kit_video 2.0.1`、本地 `media_kit_libs_ios_video 1.1.4`。
- 本地 iOS 库包描述为“full PGS subtitle decoding”；podspec 将 `Frameworks/*.xcframework` 作为 vendored frameworks，最低 iOS 声明仍为 9.0。
- Makefile 固定下载 `libmpv-darwin-build v0.6.0` 的 `ios-universal-video-full` 包，并校验 SHA-256；仓库当前没有已展开的 Frameworks 内容，预计在 iOS 依赖安装阶段下载生成。
- `Info.plist` 对媒体允许 `NSAllowsArbitraryLoadsInMedia=true`，同时允许本地网络；后台模式仅声明 `audio`，与后台/画中画播放需要的音频会话相符。
- `ios/Podfile` 当前不存在；这不是播放器实现不存在的证据，项目的 `.flutter-plugins-dependencies` 已明确 iOS 原生插件为 `media_kit_libs_ios_video` 和 `media_kit_video`，仍需继续检查 Xcode/生成式集成方式。
- 播放页对直传和 HLS 均先尝试硬解，打开失败时重建播放器并关闭硬件加速后重试；成功后保存 PiP 使用的 URL/headers。
- `PlayerPage` 可从首页和详情页进入；它接受后端协商源或显式 `directUrl`，负责直传/HLS 回退、续播、队列、字幕/音轨、错误处理与设备方向。

## 官方资料核验（第一轮）

- Flutter 官方 `video_player` 页面明确：iOS/macOS 的 backing player 是 `AVPlayer`；可播格式随 iOS 版本变化，可通过 `AVURLAsset.audiovisualTypes` 查询。HTTP 源需要适当 ATS 配置。
- `media_kit` 官方包页确认 iOS 9+、宽格式/编解码支持、默认硬件/GPU 加速、多音视频/字幕轨；原生平台使用 libmpv（Web 例外，Web 使用 HTML `<video>`）。
- `media_kit` 项目主体为 MIT，但应用实际分发时还必须单独审视捆绑的 libmpv/FFmpeg 及具体编译选项的许可证；不能只看 Dart 包的 MIT 标签。
- 官方资料地址：
  - https://pub.dev/packages/video_player
  - https://pub.dev/packages/media_kit

## 内核分类原则

- `video_player` 是 Flutter 插件/API，iOS 内核为 AVPlayer。
- `media_kit` / `media_kit_video` 是 Flutter API 与渲染层，项目 iOS 内核为 libmpv。
- “默认硬件加速”不等于所有编码都能硬解；在 iOS 上最终受 VideoToolbox、设备芯片、编码 profile/level、像素格式等约束，不支持时需软解或服务端转码。

## 官方资料核验（第二轮）

- `flutter_vlc_player 7.4.4`（页面显示约 11 个月前发布）自述为 VLC-powered 的 `video_player` 替代方案，支持 iOS/Android，多实例、录制、投屏等；iOS 依赖底层 VLCKit/libVLC。许可证为 BSD-3-Clause，但仍需审查 VLCKit/libVLC 及编解码组件的许可证。
- `fvp` 是官方 `video_player` 平台接口的可替换后端，底层为 `libmdk`；iOS 使用 Metal 渲染，默认硬解，不支持的格式通过 FFmpeg demuxer/软解回退。它也暴露独立 backend Player API。
- `fvp` 的关键取舍是 MDK SDK 二进制依赖与许可/分发模式，不应仅按 Dart 包页的 BSD-3-Clause 判断整个产品合规性；采用前必须核查 MDK 当前商业许可条款。
- 官方/上游资料地址：
  - https://pub.dev/packages/flutter_vlc_player
  - https://pub.dev/packages/fvp

## 非内核型 Flutter 组件

- `Chewie` 官方页面明确：它仅在 `video_player` 之上提供 Material/Cupertino UI，播放问题归属底层 `video_player`；因此 iOS 实际仍是 AVPlayer，不是新内核。
- `better_player_plus` 是当前活跃的 Better Player 衍生方案，仍基于 `video_player`，增加 HLS/DASH、字幕、缓存、控制 UI 及 FairPlay/EZDRM 等集成；iOS 底层仍以 AVPlayer 路线为主。
- 选型比较时应把 Chewie/Better Player 放在“功能封装层”而不是与 AVPlayer/libmpv/libVLC/libmdk 并列。
- 资料地址：
  - https://pub.dev/packages/chewie
  - https://pub.dev/packages/better_player_plus

## Apple 原生能力核验

- Apple FairPlay Streaming 官方页明确：FPS 用于通过 HLS 安全分发流媒体，支持内容加密、密钥安全交换和 Apple 平台受保护播放；生产凭据需要 Apple Developer Program 及审批。
- 因而“商业 DRM/FairPlay、系统 HLS、系统 PiP/AirPlay 深度集成”是 AVPlayer 路线的核心优势；libmpv/libVLC 路线不能假定自动拥有等价的 FairPlay 能力。
- AVPlayer 官方文档页本轮只返回动态页面壳，尚未取得描述正文；不以空页面推断能力，下一步改读 Apple 文档 JSON 数据源。
- Apple 文档 JSON 的浏览器直达请求被客户端阻止；将用只读 HTTP CLI 获取相同官方数据源。
- 资料地址：
  - https://developer.apple.com/documentation/avfoundation/avplayer
  - https://developer.apple.com/streaming/fps/

## 项目原生桥接与辅助模块

- Dart 侧 `PlayerPlatformCapabilities` 通过 `omm/player_capabilities` MethodChannel 请求进入/停止 PiP，并在 `pictureInPictureStopped` 回调中接收 AVPlayer 的最终进度。
- iOS `AppDelegate.swift` 创建临时 `AVPlayerItem`、`AVPlayer`、`AVPlayerLayer` 与 `AVPictureInPictureController`；等待 item ready 和 PiP possible 后按主播放器位置 seek，再启动 PiP。PiP 停止后把当前位置毫秒值回传 Dart，并完整释放 AVPlayer 相关对象。
- 这是一种“双内核接力”：全屏/内嵌主播放是 libmpv，系统 PiP 阶段是 AVPlayer。其边界是 PiP URL 必须为 AVPlayer 能识别的资源；项目代码因此对常见 MKV 直传源改用 HLS 作为 PiP 源。
- `PlayerDeviceStatsReader` 通过 `omm/player_stats` 读取 iOS/Android 的 CPU、电量、上下行速率与网络类型，为播放器状态面板提供信息，不参与解码。

## Apple 与 IJK 状态补充

- Apple AVPlayer 官方 JSON 将其定义为控制播放器 transport 行为的对象，主题覆盖创建、player item 管理、ready 状态、播放控制与时间观察；结合 Flutter 官方 `video_player` 说明，可确认 AVPlayer 是该插件的 iOS backing player。
- GitHub API（2026-08-23 查询）显示 `bilibili/ijkplayer` 未标记 archived，许可证字段为 GPL-2.0，仓库最近 push 为 2024-08-13。不能再使用“官方仓库已归档”这一过时说法；仍需从 release/提交频率判断其是否适合新项目。
- 资料地址：
  - https://developer.apple.com/tutorials/data/documentation/avfoundation/avplayer.json
  - https://api.github.com/repos/bilibili/ijkplayer

## Flutter IJKPlayer 生态现状

- `flutter_ijkplayer 0.3.5+1` 页面明确标记 `DISCONTINUED`、Dart 3 incompatible，且约 6 年未发布；不能用于当前 Dart 3.8 项目。
- `fijkplayer 0.11.0` 基于 ijkplayer，支持 iOS/Android 和常见协议/编码，但页面显示约 3 年未发布，且 iOS 模拟器不可用。它比已停更的 `flutter_ijkplayer` 可用性略好，但对新项目仍属于高维护风险的遗留路线。
- IJK 本身仍可自建/原生桥接，并支持 VideoToolbox，但 Flutter 现成封装老化、FFmpeg 构建与 GPL/编解码许可成本高；只适合已有 IJK 资产的维护项目，不建议本项目迁移过去。
- 资料地址：
  - https://pub.dev/packages/fijkplayer
  - https://pub.dev/packages/flutter_ijkplayer

## 项目播放器模块清单

- 核心播放：`player_page.dart`（全屏播放编排）、`player_controller_host.dart`（media_kit/libmpv 隔离层）、`player_controls.dart`（控制 UI）。
- 源与状态：`playback_decision.dart`（直传/HLS 决策）、`player_decode_status.dart`（客户端/服务端解码状态）、`player_status_overlay.dart`、`player_device_stats.dart`、`player_error_disposition.dart`。
- 交互：`player_gesture_layer.dart`、`player_haptics.dart`、`player_overlay_indicators.dart`、`player_platform.dart`（PiP 原生桥接）。
- 播放会话：`player_queue.dart`、`player_resume.dart`、`player_settings.dart`。
- 字幕：`player_subtitle_track_resolver.dart`、`subtitle_content_fetcher.dart`、`subtitle_rendering.dart`、`subtitle_settings.dart`、`subtitle_adjustment_sheet.dart`。
- 共发现 13 个对应单元测试文件，覆盖播放决策、续播、手势、错误分类、设备状态、解码状态、设置与字幕逻辑；未发现对 `PlayerPage`/`PlayerControllerHost` 真正起播链或 iOS PiP 的集成测试。

## 播放策略

- 页面通过 `/movies/id/{id}/playback-decision` 与后端协商；API 还提供 stream URL、转码状态、停止转码会话和 SSE 转码事件。
- 移动端 H.264/AVC 与 HEVC/H.265 优先直传给 media_kit/libmpv + 系统硬解；播放器打开失败时关闭硬解再试一次。
- 其他编码若为 10-bit/4:2:2/4:4:4，或容器不在 MP4/MOV/M4V/MP4A 白名单，或后端标记不兼容，则选择 HLS 服务端转码；这说明内核能力与服务端转码共同构成当前播放兼容性。
- 控制层支持画质、字幕/字幕样式、音轨、解码状态、震动进度条、快进快退、倍速、PiP、横竖屏、上下集/队列切换与帧预览。

## 初始化与 iOS 工程生成

- `main()` 在 `runApp` 前调用 `WidgetsFlutterBinding.ensureInitialized()` 与 `MediaKit.ensureInitialized()`，因此 libmpv 运行时在应用启动阶段统一初始化。
- 仓库有意不提交完整 iOS 工程：`.gitignore` 仅放行 `Runner/Info.plist`、`AppDelegate.swift`、启动图与图标；`Runner.xcodeproj`、Podfile 等均被忽略。
- `.github/workflows/ios-build.yml` 在 CI 检测不到 `ios/Runner.xcodeproj/project.pbxproj` 时执行 `flutter create . --platforms=ios`，再把部署目标统一调整到 iOS 16.0，并显式 `pod install` 兜底集成只支持 CocoaPods 的 `media_kit_libs_ios_video`。
- 因此当前工作树缺少 Podfile/Xcode 工程是仓库设计，不是配置遗漏；评估实际 iOS 构建集成必须同时看 CI bootstrap。插件自带 podspec 的 iOS 9.0 只是库最低声明，App 实际 deployment target 是 16.0。

## 详情页第二播放场景

- `MovieDetailPage` 的预告片有两条入口：缩略图可直接打开完整 `PlayerPage`；图片灯箱中的 `_TrailerViewer` 则独立创建 `Player` + `VideoController`，直接 `open(Media(widget.url))`。
- 灯箱内预告片使用 `Video(... controls: NoVideoControls)`，自行处理点击播放/暂停；切到其他页时暂停，widget 销毁时释放 Player。
- 该内嵌预告片没有复用 `PlayerControllerHost`，因此不会获得主播放器的 mpv 缓冲属性、自定义鉴权 headers、硬解失败后关闭硬解重试、字幕与音轨逻辑；它是同一 media_kit/libmpv 内核上的轻量第二封装。
- 代码未设置静音，内嵌预告片按播放器默认音量播放。

## 本地 libmpv 二进制与许可风险

- 本地 `media_kit_libs_ios_video/LICENSE` 只覆盖该 Flutter 包装层（MIT），不能自动覆盖下载进来的 mpv/FFmpeg/第三方 codec。
- 上游 `media-kit/libmpv-darwin-build` README 表述为“commercial use for playback, GPL use for encoding”，同时提供 default / encodersgpl / full 多种构建。当前项目选用 `video-full`，在发布前仍应以该 release 的实际依赖清单和编译选项做 SBOM/许可证审计。
- 项目固定的 native release `v0.6.0` 发布于 2023-09-24；这比当前 Dart 包新鲜度明显低，属于安全更新、codec bug 与新设备兼容性方面的维护点。
- 本地 package 版本为 1.1.4，而 podspec 仍写 1.0.4；这通常不影响 path pod 集成，但说明本地 fork 的版本元数据并未完全同步。
- 资料地址：https://github.com/media-kit/libmpv-darwin-build/releases/tag/v0.6.0

## 当前 media_kit 上游差异（查询日期 2026-08-23）

- 项目锁定的 `media_kit 1.2.6` 与 `media_kit_video 2.0.1` 正是 pub.dev 当前最新版本。
- 官方当前安装说明推荐视频项目使用跨平台 `media_kit_libs_video ^1.0.7`；项目仍使用 2023 年发布的、平台专用且本地 fork 的 `media_kit_libs_ios_video 1.1.4`，原因是 full PGS 字幕构建。
- `libmpv-darwin-build` 最新 release 为 `v0.7.2`（2026-06-27），项目固定 `v0.6.0`（2023-09-24）。因此主风险不在 Dart API 版本，而在自定义 iOS native 二进制落后。
- 是否迁移到官方 `media_kit_libs_video` 不能只看版本：必须先验证 PGS 字幕、ASS/libass、现有 mpv 属性、自定义 codec/协议和 iOS PiP HLS 接力是否全部保留。
- 资料地址：
  - https://pub.dev/api/packages/media_kit
  - https://pub.dev/api/packages/media_kit_video
  - https://pub.dev/api/packages/media_kit_libs_video
  - https://github.com/media-kit/libmpv-darwin-build/releases/tag/v0.7.2

## 商业 SDK 路线

- `bitmovin_player 0.26.0` 是 Bitmovin 官方 Flutter bindings，底层接入其 mobile Player SDK；页面显示约 3 个月前发布，支持 iOS/iPadOS 14+、Android 与 Web。
- 这类商业 SDK（同类还包括 THEOplayer/JW Player 等）适用于 FairPlay/多 DRM、广告、分析、低延迟直播和厂商 SLA 是硬需求的产品；代价是 license、包体、供应商锁定与 Flutter API 覆盖度。
- Flutter binding 自身的 MIT 不等于底层商业 Player SDK 免费；必须按厂商合同与功能许可评估。
- 资料地址：https://pub.dev/packages/bitmovin_player

## GStreamer 查询状态

- GStreamer 官方网页入口本轮返回 503，但其官方 GitLab 文档源可读取：GStreamer iOS/tvOS 支持 iOS 12+；从 1.28 起以 `GStreamer.xcframework` 发布，可直接导入 Xcode，C 内核配合 Objective-C iOS API。
- Flutter 没有与 `video_player`/media_kit 同等级的官方一站式 GStreamer package；通常需要自行做 FFI/MethodChannel、纹理渲染、生命周期与插件裁剪，适合已有 GStreamer pipeline/实时流媒体能力的团队，不适合作为本项目低成本替换。
- 资料地址：https://gitlab.freedesktop.org/gstreamer/gstreamer/-/raw/main/subprojects/gst-docs/markdown/installing/for-ios-development.md

## iOS PiP 鉴权边界

- Dart MethodChannel 参数虽然包含 `headers`，但 Swift `PictureInPictureRequest` 只解析 URL、进度和 autoplay；原生侧明确不使用非公开的 `AVURLAssetHTTPHeaderFieldsKey`。
- 同服务器媒体通常已由 `resolveProtectedUrl` 把 token 放进 query，MKV 等不受 AVPlayer 支持的容器也会切到带 query token 的临时 HLS，因此项目主路径可工作。
- 若未来接入必须依赖自定义 HTTP header、且 URL 本身不带签名/token 的外部 MP4/HLS，libmpv 主播放可以成功，但 AVPlayer PiP 会丢失 header 并可能鉴权失败。这是当前双内核设计的明确能力边界。

## 验证结果

- `flutter analyze lib/features/player lib/features/movie_detail/movie_detail_page.dart lib/main.dart`：通过，无问题。
- 12 个播放器相关测试文件共 46 个测试全部通过，覆盖播放决策、续播、手势、错误分类、设备状态、解码状态、设置和字幕。
- 当前环境是 Windows，且仓库 iOS 工程由 CI 动态生成；本轮未执行 iOS 真机/模拟器编译与 PiP、VideoToolbox、HDR、PGS 字幕的端到端验证。

## 内核对比结论

| iOS 内核 | 常见 Flutter 接入 | 优势 | 主要边界 | 本项目适配度 |
| --- | --- | --- | --- | --- |
| AVPlayer / AVFoundation | `video_player`；Chewie/Better Player 为上层 | 系统 HLS、FairPlay、AirPlay、PiP、能耗和系统兼容性最佳 | MKV/复杂字幕/非常规 codec 与协议受限 | 适合作为 PiP/DRM/标准流旁路，不适合替代当前广格式主播放器 |
| libmpv + FFmpeg | `media_kit` + `media_kit_video` | 宽格式/协议、轨道与字幕、mpv 属性、VideoToolbox + 软解回退 | 包体、许可证、原生 SDK 集成；系统 PiP/FairPlay 需旁路 | 最高，已深度使用且功能匹配 |
| libVLC / VLCKit | `flutter_vlc_player` | 宽协议/格式、RTSP/IPTV、投屏/录制生态 | 包体、VLCKit 集成与许可、API 迁移成本 | 中；只有 VLC 特有协议/功能成为硬需求时才值得迁移 |
| libmdk / MDK SDK | `fvp`（替换 `video_player` 后端或独立 API） | Metal、默认硬解、FFmpeg 软解、`video_player` API 复用 | 闭源/商业 SDK 许可与供应商依赖 | 中；新项目可评估，本项目迁移收益不足 |
| IJKPlayer | `fijkplayer`；旧 `flutter_ijkplayer` | 传统 FFmpeg 路线、VideoToolbox、参数可调 | Flutter 封装陈旧、Dart 3 兼容与 GPL/自编译风险 | 低，不建议新迁移 |
| GStreamer | 自研 FFI/MethodChannel + texture | pipeline、实时音视频、协议/插件可组合 | Flutter 集成和裁剪成本最高 | 低，除非业务需要自定义媒体 pipeline |
| 商业播放器 SDK | Bitmovin/THEOplayer/JW Player 等 bindings | 多 DRM、广告、分析、低延迟、SLA | 费用、供应商锁定、Flutter API 覆盖 | 条件适用；商业 DRM/运营能力优先时考虑 |

## 项目建议

1. 保留 `media_kit/libmpv` 主内核。当前 App 的私有媒体库、MKV/多轨/复杂字幕、直传优先、mpv 缓冲调优和 HLS 转码兜底都与它高度耦合，换 AVPlayer/VLC/MDK 会产生大规模重写且没有明确收益。
2. 把 native 二进制升级验证列为最高优先级：比较当前 `libmpv-darwin-build v0.6.0` 与最新 `v0.7.2`，或评估官方 `media_kit_libs_video 1.0.7`。先建回归矩阵，再决定是否移除本地 PGS fork。
3. 真机回归至少覆盖：MP4/MKV、H.264/HEVC 8/10-bit、VideoToolbox 成功与软解回退、HLS、PGS/ASS/WebVTT、内嵌多音轨、续播/seek/倍速、后台音频、PiP 进入/退出/进度接力、token query 与 header-only 源。
4. 若未来引入 FairPlay DRM，不要强行让 libmpv 承担；新增 AVPlayer/Better Player 或商业 SDK 的受保护内容专用路径更合理。
5. 详情页 `_TrailerViewer` 目前绕过 `PlayerControllerHost`。公开 MP4 预告片可保持简单；一旦需要鉴权、统一缓冲或失败回退，应复用/抽取同一 host 能力。

## 概念澄清

- FFmpeg 通常是解封装/编解码基础库，不等于完整 Flutter 播放器内核；在本项目中它位于 libmpv 内部。
- Chewie、Better Player 是控制/UI/业务功能封装，iOS 最终仍落到 `video_player` 的 AVPlayer。
- Flutter `Video`/texture 是画面嵌入层，也不是解码内核。

# iOS 多内核实施记录（2026-08-24）

## 已确认决策

- iOS 使用自研 AVPlayer Flutter 插件；Android 继续固定 media_kit/libmpv。
- `player.ios_engine` 缺失或未知值回退 `libmpv`，设置只影响下一次媒体会话。
- AVPlayer 回退顺序固定为原生直放、后端 remux/direct-stream/transcode、当前会话一次性 libmpv 回退。
- 统一 UI 依赖 `PlayerSessionController`，能力差异由 `PlaybackEngineCapabilities` 驱动，不在 Widget 内写平台/内核分支。

## 待实现证据点

- iOS 本地 wrapper 版本、podspec、Makefile 和 lockfile必须同步升级。
- 需要确认当前 `PlayerControllerHost`、`PlayerControls`、字幕 Overlay、预览帧和 `_TrailerViewer` 的精确调用面，再做最小迁移。
- 需要确认移动端 playback DTO 已解析的后端字段，避免重复造模型或丢弃 `audio_stream_index` / `subtitle_track_id`。

## 多内核收尾发现

- 详情页嵌入式 `_TrailerViewer` 已固定 `MediaKitPlaybackEngine`，但 `_playTrailer()` 打开的完整 `PlayerPage` 未传递内核约束，会错误读取 iOS 默认 AVPlayer 设置。
- 最小修复是在 `PlayerPage` 增加只读的可选会话级 `engineKind` 覆盖；仅预告片完整播放入口传 `libmpv`，普通影片仍在新会话初始化时读取设置。
- Pigeon 26.3.4 生成的 Swift `OmmAvPlayerHostApi` 方法签名与 `AvPlayerManager` 实现逐项一致，包括同步 `throws` 方法和异步 `Result<..., Error>` completion 方法。
- CodeGraph 能定位 `AvPlayerSession` 的预览帧与 PiP 方法，但响应未展开这些方法体；后续只对该未覆盖区间做精确文件读取，不重复检索已返回源码。
- Swift 静态复核发现 `AvPlayerViewFactory.manager` 为非可选属性却使用 `manager?.attach(...)`，会导致 iOS 编译错误；应改为直接调用 `manager.attach(...)`。
- AVPlayer 预览帧复用当前 `AVPlayerItem.asset`，新请求先取消旧 `AVAssetImageGenerator`；PiP 由当前同一个 `AVPlayerLayer` 构造，结束后清理 delegate/controller，`dispose()` 可重复调用。
- 新插件目录存在生成期 `.dart_tool/` 和独立 `pubspec.lock`；仓库其他 `packages/*` 不提交插件级 lock，二者均不属于交付源码。
- 现有测试未覆盖详情页 `_playTrailer()` 到 `PlayerPage` 的路由；本次保持修复为构造参数直传，避免为了单一静态约束引入播放器插件初始化型 Widget 测试。
- 最终边界扫描发现 `PlayerPage` 和 `_TrailerViewer` 虽已不使用 `media_kit` 类型，仍直接实例化具体 engine adapter；新增统一 `createPlayerSession` 工厂后，UI 只传 `PlaybackEngineKind` 并持有 `PlayerSessionController`。
- AVPlayer 的 engine open/运行时错误已有单次回退，但播放决策请求失败或 `stream_url` 缺失发生在首次 `open` 之前，当前 `_canFallback` 因没有 `_lastOpenRequest` 不会触发；需由会话控制器提供“切换内核后重新决策”的同一单次回退门闩。
- 现有 `FakePlaybackEngine` 已能验证“不打开旧 URL、只更换内核”的决策阶段回退；新增测试应确认第二次请求不会再次创建 libmpv，确保与 open/运行时回退共用一次性门闩。
- 最终 UI 扫描确认 `PlayerPage`、`PlayerControls`、字幕层和详情页均不再引用 `media_kit` package、`Player`、`VideoController` 或具体 engine adapter；具体内核创建只存在于统一会话工厂。
- iOS libmpv 元数据最终一致：wrapper/pubspec/podspec 均为 `1.1.5`，Makefile 固定 `v0.7.2`、`video-full` 下载名和指定 SHA-256。
- Pigeon 生成的 Dart 文件被根 `.gitignore` 的 `*.g.dart` 规则排除；必须仅对 `packages/omm_avplayer/lib/src/av_player_api.g.dart` 增加例外，才能满足生成 Dart/Swift 一并提交。
- 更严格按“UI 不写平台或内核判断”复核后，`PlayerPage` 仍有 iOS 默认选择和 AVPlayer 路由/音轨/字幕分支；应继续把默认内核解析、client caps、路由和轨道策略收进会话层，只让页面读取 capabilities/统一决策结果。
- 策略下沉完成后，四个 UI/页面文件对 `_host.kind`、`PlaybackEngineKind.avPlayer`、平台判断和具体 adapter 的联合扫描无命中；Android 显式 AVPlayer 覆盖也由会话工厂强制回落 libmpv。

# AVPlayer 弱网缓冲改造发现（2026-08-24）

- 当前原生会话使用 `playImmediately(atRate:)`，会优先立即起播，未充分使用 AVPlayer 的最小化卡顿等待策略。
- 改造前 `AVPlayerItem` 未设置 `preferredForwardBufferDuration`，插件也没有 AVPlayer 专属时间型缓冲配置。
- `timeControlStatus == .waitingToPlayAtSpecifiedRate` 当前同时上报 `playing=false` 与 `buffering=true`，把系统等待错误映射为用户暂停语义。
- 当前只监听正常播放结束，未监听 `AVPlayerItemPlaybackStalled` 和 `AVPlayerItemFailedToPlayToEndTime`。
- 最终方案为固定 60 秒 `preferredForwardBufferDuration`、`automaticallyWaitsToMinimizeStalling=true`、独立 `wantsToPlay`，并对卡顿执行一次有界恢复。
- 固定缓冲属于 AVPlayer 内部默认策略，因此 `customBuffering` 仍保持 `false`；现有 libmpv 字节档位继续只作用于 libmpv。
- `AVPlayerItemFailedToPlayToEndTime` 现在统一进入既有 Dart 错误流，可触发现有当前会话单次 libmpv 回退。

# AVPlayer 起播与详情页测试入口发现（2026-08-24）

- AVPlayer 当前设置 `automaticallyWaitsToMinimizeStalling=true`、60 秒 `preferredForwardBufferDuration`，初始自动播放调用普通 `play()`；在弱网或系统预测不足时会延迟真正播放。
- AVPlayer 的 `open` 在 `readyToPlay` 后才完成；存在续播位置时还会等待零容差精确 seek。
- 页面在 `open` 之后继续同步等待默认字幕/音轨，AVPlayer 原生音轨状态为空时最多等待 2 秒，期间 `_loading` 仍为 true，播放器 Surface 不渲染。
- AVPlayer 仍可保留 60 秒继续预取；首次播放与断流恢复使用 `playImmediately(atRate:)`，60 秒窗口在播放期间后台继续填充，不成为首帧或恢复门槛。
- 影片详情播放入口位于 `_MovieActionRow` 的 `ElevatedButton`，当前直接调用 `PlayerPage.open`，而 `PlayerPage` 已支持可选 `engineKind` 会话级覆盖，因此长按入口无需修改播放页协议或持久化设置。
- `resolvePlaybackEngineKind` 已保证非 iOS 平台强制回落 libmpv；可在同一工厂模块提供“当前平台可选择内核”列表，避免详情页自行写平台判断。
- 现有本地化资源已经有 `playerEngineLibmpv` 与 `playerEngineNative`，只需补充测试选择器标题/说明类文案。
- 实际资源只有 `playerEngineNative`，`libmpv` 在设置页作为不可翻译产品名直接显示；选择器可沿用该规则，并新增“选择播放器 / 仅用于本次播放”两项 ARB 文案。
- Swift 卡顿恢复原先调用普通 `player.play()`，会重新进入系统最小化卡顿等待；按用户澄清改为有限次 `playImmediately(atRate:)`，尽快恢复后继续填充 60 秒窗口。
- 现有 Dart contract 测试已覆盖 AVPlayer 音轨映射与平台内核解析，适合直接补充单音轨快速路径和可选择内核列表测试。
- AVPlayer 缓冲进度改为取“包含当前位置并向后连续”的 `loadedTimeRanges`，避免 seek 后把旧的不连续缓存区间误显示成当前可用缓冲。
- 有续播位置时仍需先定位再播放，但初始 seek 使用 0.5 秒容差，用户拖动 seek 继续保持原有精确语义。

# AVPlayer 起播、回退与进度故障发现（2026-08-24）

- `PlayerPage._body()` 在 `_loading=true` 时完全不构建 `_host.buildSurface()`；AVPlayer 的 `AVPlayerLayer` 因此要等后端决策、`readyToPlay`、默认字幕/音轨全部完成后才挂载，首帧优化无法在加载期间产生可见效果。
- `_loadInternal()` 在 `_host.open()` 后仍同步等待 `_applyDefaultTracks()` 才关闭加载页，多音轨或默认字幕网络请求会继续放大可见起播时间。
- AVPlayer 原生错误事件会由 `PlayerSessionController._handleEngineState()` 抢先触发内部 `_performFallbackToLibmpv()`；该路径直接让 libmpv 打开 AVPlayer 的旧 `stream_url`，不会用 libmpv capabilities 重新请求后端决策，且与 `open()` 抛错存在并发回退竞态。
- 页面已有 `fallbackToLibmpvForReload()` 后重新执行 `_loadInternal()` 的正确决策级回退路径；运行时错误需要改为同样的“切内核 → 通知页面重新决策”，不能继续在会话层复用旧 URL。
- AVPlayer 只在 `readyToPlay` 瞬间读取一次 `item.duration`；HLS/远程流当时常为 indefinite，后续没有 duration KVO，导致统一进度条总时长保持 0。
- AVPlayer 缓冲只在 `loadedTimeRanges` 变化时按当时的 currentTime 计算；seek 或播放位置跨区间但 ranges 未变化时不会刷新，可能残留错误 secondary progress。
- `AvPlayerPlaybackEngine.open()` 未清零上一媒体的 duration/buffered，切源和回退期间会短暂保留旧进度状态。
- Swift 复核确认 `duration` 与 `loadedTimeRanges` 均为 item 级 KVO，通知型 stalled/failed/end 观察器显式使用主队列；seek 完成后同时上报 position 与按当前位置计算的连续 buffered 末端。
- 会话层运行时错误先切换到全新 libmpv engine，再通过 `PlaybackReloadRequest` 要求页面重新走后端决策；页面显式携带当前 quality 和恢复位置，已不复用 AVPlayer 的旧 `stream_url`。
- 新发现：AVPlayer 的 `reportPlaybackFailure` 会先将 `wantsToPlay=false` 并上报 `playing=false`，之后才上报 error；运行时回退若从失败后的 `PlaybackViewState.playing` 推断恢复意图，会错误得到暂停状态。这会让重新打开成功的 libmpv 随即被页面暂停，必须由 `PlayerSessionController` 独立保存用户播放意图。
- 统一进度条把 `PlaybackViewState.buffered` 当作媒体时间轴上的绝对结束位置传给 `Slider.secondaryTrackValue`；AVPlayer 的连续缓存计算单位与此一致。当前 UI 只把 buffered 限制在 `[0, duration]`，如果 seek 后暂时没有覆盖当前位置的 loaded range，原生会上报 0，次进度可能落到主进度后方；显示层应至少钳制到当前 position。
- 起播路径虽调用 `playImmediately(atRate:)`，但 `AVPlayerItem` 在首帧前已设置 `preferredForwardBufferDuration=60`；该值不是硬性起播门槛，但会参与 AVPlayer 的缓冲策略。为从实现上隔离起播与预取，首帧前应保持 0，`AVPlayerLayer.isReadyForDisplay` 后立即切换为 60 秒持续前向预取。

## 本次实施：iOS 接入 KSPlayer

- KSPlayer 仓库已有改动已提交并推送：`9a80ee3`、`2fdbf66`；工作区应保持 clean。
- `mobile_app` 只应引用固定远程 KSPlayer commit，不引用相邻本地目录。
- Flutter 统一播放抽象已增加 `PlaybackEngineKind.ksPlayer`、KSPlayer capabilities 和泛化 fallback；Android/Web 仍强制 `libmpv`。
- KSPlayer 插件位于 `packages/omm_ksplayer`，使用 Pigeon、Swift Platform View 和 KSPlayerLayer，不启用原生控制栏/手势。
- KSPlayer 的 PGS/burn-in 字幕走能力声明并触发后端重决策；外挂文本字幕仍由 Flutter 统一处理，原生轨道失败且存在外挂地址时会降级到外挂字幕。
- KSPlayer 无可靠 `loadedTimeRanges` 结束点时不伪造缓冲百分比。
- Windows 环境无法编译 Swift、执行 CocoaPods 或 `flutter build ios`；必须记录为 macOS CI/真机验收项。
- KSPlayer 的 CocoaPods README 与 Podspec 还依赖 `DisplayCriteria`、`Libass`；CI 已补充固定来源注入，许可证声明覆盖这两个相关 Pod。
- `KsPlayerManager.dispose` 已通过 `MainActor.assumeIsolated` 调用 `KsPlayerSession.dispose`，避免跨 actor 直接访问。
- KSPlayer 生成的 `lib/src/ks_player_api.g.dart` 已加入 `.gitignore` 例外；`git diff --check` 通过。
- Dart 最终验证：`flutter analyze` 无问题，`flutter test` 共 `394` 项全部通过。

## KSPlayer 音轨切换故障（2026-08-25）

- `PlayerSessionController.trySelectAudioTrack` 原先将所有非 AVPlayer 内核直接传入 `track.index.toString()`；这会把 KSPlayer 当作 `libmpv`。
- `OmmKsplayerPlugin.audioTracks()` 返回 `String(track.trackID)`，其值是 AVFoundation 原生 `trackID`，不保证等于后端音轨 index。
- KSPlayer 的 `selectAudioTrack` 以原生 `trackID` 查找轨道；找不到时返回 `KsPlayerPluginError.missingTrack`，Pigeon 最终表现为截图中的 `PlatformException`。
- 修复方向是仅 `libmpv` 继续直传 index，AVPlayer/KSPlayer 共用现有语言、标题、ordinal 原生轨道映射；单音轨不发起不必要的原生选择。

# 播放器调试模式（2026-08-25）

- 应用更新入口为 `AppUpdateSettingsPage`；设置主页版本卡片五击后进入该页面。
- `PlayerSettings` 已集中持久化播放器显示偏好，但当前没有 debug 模式字段。
- `PlaybackViewState` 当前只有内核、尺寸、时间、轨道等状态，没有码率、FPS、编码/容器字段。
- KSPlayer Pigeon 事件当前只有 ready/playing/buffering/position/duration/size/completed/error/firstFrame/PiP，需要新增受控媒体元数据事件或字段。
- 调试信息应通过统一 `PlaybackViewState` 供 Flutter overlay 使用；关闭开关时不构建 overlay，不影响播放命令和性能。

# Oh-My-Media Logo 替换（2026-08-25）

- 用户附件只作为视觉参考：黑色背景、深蓝紫色圆角方形底、粉紫到蓝色霓虹渐变、中央白色圆角媒体标记、环形光轨和星芒装饰。
- 当前工作区已存在历史规划记录；本次任务追加独立章节，保留既有业务改动。
- `.codegraph/` 存在，已优先使用 CodeGraph 进行源码入口初查；资源文件和构建配置仍需用文件清单与文本检查确认。
- 现有入口资源：Android 使用 `android/app/src/main/res/mipmap-*/ic_launcher.png`；iOS 使用 `ios/Runner/Assets.xcassets/AppIcon.appiconset`；iOS 启动页另有 `LaunchLogo.imageset`；Web 使用 `web/favicon.png` 与 `web/icons/*`；macOS 使用 `macos/Runner/Assets.xcassets/AppIcon.appiconset`；Windows 使用 `windows/runner/resources/app_icon.ico`。
- 已生成新主图：`C:\Users\KleinerSource\.codex\generated_images\01a0383e-1b4a-73f3-8598-a75fd826f235\exec-85862656-e14a-41ca-8873-cd320338fa88.png`。预览检查通过：`oh`、`my`、`media` 拼写清晰，白色播放三角、粉紫蓝渐变、环形光轨与星芒均符合参考风格。
- Android 没有 adaptive icon XML，Manifest、Android 12 splash 和 launch background 均直接引用 `@mipmap/ic_launcher`；只替换现有 `ic_launcher.png` 各密度文件即可。
- Web 图标尺寸为 16/192/512；Windows `app_icon.ico` 当前含 256px 图像，需输出多尺寸 ICO 以保持桌面/任务栏清晰度。
- 首次批量导出因手工记录生成会话目录 ID 时出错，在源文件存在性检查处停止，未修改任何 Logo 目标文件；后续以工具返回的完整路径为准。
- 资源验证结果：Android 48/72/96/144/192；iOS AppIcon 全部 manifest 尺寸；iOS LaunchLogo 3 份；Web 16/192/512；macOS 16/32/64/128/256/512/1024；Windows ICO 读取正常。
- 全量验证：`flutter analyze --no-pub` 无问题，`flutter test --no-pub` 399 项全部通过，`git diff --check` 通过。
- 最终 manifest/文件完整性检查验证了 44 个图像文件；Android/iOS 的 tracked 资源在 Git 差异中，Web/macOS/Windows 资源因仓库规则被忽略。

# Android Actions 编译失败（2026-08-25）

- 最新 Android 运行：`32831761951`，提交 `f45ea8cf122c6b155da8f161d270129738b44a0a`，失败于 `build android apk`。
- 同一提交的 iOS 运行 `32831761928` 已成功；Android 的 `build_runner`、`analyze` 和 `test` 均已通过，失败仅发生在 Kotlin 编译。
- 失败任务：`:app:compileReleaseKotlin`。
- 具体错误：`android/app/src/main/kotlin/com/ohmymedia/MainActivity.kt:80:36` 和 `:142:9` 的 `result(...)` 被解析为未定义引用。
- CodeGraph 当前源码确认：`result` 是 `MethodChannel.Result` 参数，`getBrightness` 和 `setWindowBrightness` 应调用 `result.success(...)`，而不是把对象当函数调用。
- Dart 通道契约要求 `getBrightness` 返回 `double?`，`setBrightness` 返回空结果。
- 本地 `flutter build apk --release --target-platform android-arm64 --no-pub --dart-define=BUILD_CHANNEL=dev` 无法启动，Flutter 报 `No Android SDK found`；不是本次 Kotlin 修复引起的构建错误。

# KSPlayer 服务器解码切回设备解码故障（2026-08-25）

- 普通影片入口由 `home_page.dart` 或 `movie_detail_page.dart` 调用 `PlayerPage.open`，不传 `directUrl`；`directUrl` 仅用于预告片，因此 `_onQualityChanged` 的早退不是普通影片质量切换根因。
- 质量切换流程是：`PlayerControls._qualityButton` → `PlayerPage._onQualityChanged` → `_load` → `_loadInternal`；`original` 由 `playbackRouteForQuality` 解析为 direct，固定质量解析为 HLS。
- `_loadInternal` 在新加载开始时先 `_stopTranscodeSession()`、`_stopPlayer()`，但旧 `_bindProgress` 的 `_errorSub` 在 `_bindProgress()` 重新执行前仍监听同一个 `PlayerSessionController.errorStream`。
- KSPlayer 原生 `stop()` 调用 `layer.stop()`，KSPlayer 可能在切源时迟到发送 `.error`/finish error；这条旧媒体错误会进入 `_showPlaybackError`，而 `_load` 已重置 `_playbackErrorReported`，导致当前质量切换加载被判定为失败。
- `KsPlayerPlaybackEngine` 目前将所有错误直接更新为 `PlaybackLifecycle.failed`，没有区分 stop/open 代次；`PlayerPage` 也没有在切源阶段屏蔽旧错误订阅。
- 低风险修复方向：在播放器页切换质量/媒体时先取消当前进度与错误订阅，完成新媒体打开并绑定新订阅；同时在 KSPlayer Dart engine/native bridge 对 stop 产生的迟到错误做代次隔离，避免旧错误污染下一次 open。
- 已实施：`PlayerPage._loadInternal` 在停止旧媒体前调用 `_unbindProgress()`；KSPlayer engine 在 `stop()` 到下一次 `open()` 前抑制错误，并在 `opening` 状态忽略由 `open()` Future 负责返回的打开错误。
- 已补充质量路由回归断言：KSPlayer 的 `original` 为设备直传，固定档位为服务端 HLS/托管转码；`libmpv` 路径未改动。
- 定向播放器测试 16 项、完整 Flutter 测试 401 项和静态分析均通过；未修改 KSPlayer Swift 依赖或 Android 播放路径。
