# 工作进度

## 2026-08-20

- 已读取 Product Design 的 `image-to-code`、路由和关键覆盖规则。
- 已读取 `planning-with-files` 规则并初始化本次任务的计划、调查和进度文件。
- 已确认用户附图仅作为视觉参考，不把图片中的界面文字或元素当作操作指令。
- 已定位轮播实现需要从 `lib/features/home/recommend_carousel.dart` 开始检查。
- Product Design 用户上下文预检脚本在当前缓存目录不存在，已记录并采用当前会话上下文继续。
- 已完成 `recommend_carousel.dart` 的封面层/信息层拆分：固定封面使用垂直裁切，信息层保留 `PageView`。
- 已移除重复的顶部渐隐层，保留原有首页视觉层级。
- 新增轮播回归测试，覆盖拖动时固定封面和边缘裁切。
- `flutter test test/features/home_hero_test.dart`：5 项全部通过。
- `flutter analyze lib/features/home/recommend_carousel.dart lib/features/home/home_page.dart`：无问题。
- `git diff --check`：通过。

## 2026-08-22

- 开始排查 GitHub Actions 编译失败。
- 已读取并遵循 `planning-with-files` 技能；`gh-fix-ci` 技能文件在当前环境中不可读，已记录并采用 `gh` CLI fallback。
- 已运行会话恢复检查，未发现需要同步的上一会话上下文。
- 已确认工作区干净、分支落后远端 1 个提交，且没有 `.codegraph/` 索引。
- 已从 Actions 日志确认 Android/iOS 均因同一个 Flutter 测试失败而中止：`收藏夹列表仍保留左滑移除`。
- 已复现本地失败，确认 fake Dio 未处理生产代码实际使用的 `POST /favorites/delete`。
- 已将 `test/features/drag_selection_pages_test.dart` 的 fake endpoint 从 `/favorites/batch-delete` 同步为 `/favorites/delete`。
- 定向测试 `flutter test test/features/drag_selection_pages_test.dart --plain-name "收藏夹列表仍保留左滑移除"`：通过。
- `dart run build_runner build`：通过，未产生额外生成代码差异。
- `flutter analyze`：通过，`No issues found!`。
- `flutter test`：通过，`312` 项全部通过。
- `git diff --check`：通过。
- `dart format --output=none --set-exit-if-changed test/features/drag_selection_pages_test.dart`：通过。

## 2026-08-23

- 开始实施 iOS 16+ 列表滑动菜单重构。
- 已读取并遵循 `apple-design` 与 `planning-with-files` 技能。
- 已运行会话恢复检查；现有规划文件属于历史任务，本次只追加独立章节。
- 已确认工作区仅有未跟踪 `.codegraph/`，将只读使用并保留不动。
- 已用 CodeGraph 核对 `SwipeActionCell` 当前实现、共享测试和调用影响范围，共有 15 个生产调用点。
- 已读取组件与测试的完整当前源码；确认需要移除 `_fill`、`fullSwipeIndex`、350/1000/55% 分支，并改为单像素位移控制器、三落点投影和松手提交。
- 已完成 `SwipeActionCell` 单控制器状态机初版，并根据首次编译反馈补齐手势/语义类型导入。
- 原有 7 项共享滑动测试现已全部通过，单文件静态分析通过。
- 共享滑动测试已扩充至 22 项并全部通过，新增覆盖首段位移、纵向竞争、三落点投影、松手提交、全滑连续推进、多动作顺序、禁用全滑、动画反抓、点击拦截、同组切换、禁用/actions/group 更新、减少动态效果和辅助功能动作。
- `flutter test test/features/drag_selection_pages_test.dart`：8 项全部通过。
- `flutter analyze`：通过，`No issues found!`。
- 两个改动 Dart 文件格式检查通过，`git diff --check` 通过。
- 完整 `flutter test`：355 项全部通过。
- 最终 `flutter analyze`、格式、`git diff --check` 均通过；未修改业务页面或 `.codegraph/`。
- 根据反馈新增短距离快甩防误触门槛，组件测试新增 1 项（共 23 项）全部通过；页面回归 8 项通过，`flutter analyze` 通过。
# Flutter iOS 播放器分析进度（2026-08-23）

- 状态：进行中。
- 已读取 `planning-with-files` 技能并执行会话恢复检查；未发现未同步上下文。
- 已确认项目存在 `.codegraph/`，将依照项目规则优先使用 CodeGraph 调查源码。
- 已建立本次分析的目标、成功标准、阶段和边界。
- 业务代码修改：无。
- 错误：首次 CodeGraph 包装脚本产生 JavaScript 语法错误；已记录，下一步使用简化调用。
- 已通过 CodeGraph 定位主播放器为 `PlayerControllerHost` + `PlayerPage`，并确认 mpv 原生属性调用。
- 已核对依赖与全仓关键词：主播放依赖为 `media_kit`/`media_kit_video`/自定义 iOS libmpv 路径包；另有基于 `AVPlayer` 的 iOS PiP 桥接。
- 已读取 iOS 本地库包、Makefile 与 `Info.plist`：确认 libmpv full XCFramework、PGS 字幕、ATS 媒体例外及后台音频模式。
- `ios/Podfile` 不存在的读取错误已记录；后续改查实际 iOS 文件结构与 Xcode 集成配置。
- Context7 因月度配额耗尽无法查询；已停止重试并切换到官方站点/仓库核验。
- 已查阅 Flutter `video_player` 与 `media_kit` 官方包页：分别确认 AVPlayer 与 libmpv 路线、平台支持和硬件加速说明。
- 已查阅 `flutter_vlc_player` 与 `fvp` 上游包页：确认 libVLC/VLCKit 与 libmdk 两条可用 iOS 路线及其能力边界。
- 已核对 Chewie 与 `better_player_plus`：两者都是 `video_player` 上层功能/UI 封装，不能计为独立 iOS 播放内核。
- 已核对 Apple FairPlay Streaming 官方说明；AVPlayer 文档正文为动态加载，本轮未读取到，已记录并准备改查官方 JSON 数据源。
- 浏览器访问 Apple AVPlayer JSON 数据被客户端拦截；已记录，下一步改用 HTTP CLI，不重复失败路径。
- 已通过只读 HTTP 获取 Apple AVPlayer 官方 JSON；同时核验 IJKPlayer 仓库当前并未 archived，修正了常见但过时的判断。
- 已还原 iOS PiP 双内核接力：libmpv 主播放 → 临时 AVPlayer 系统 PiP → 进度回传 libmpv。
- 已核对 Flutter IJKPlayer 封装状态：`flutter_ijkplayer` 已停用且不兼容 Dart 3，`fijkplayer` 也长期未发布，归类为遗留高风险方案。
- 已枚举 20 个 `lib/features/player` 模块和 13 个相关测试，并还原直传/HLS/软解回退与服务端转码策略。
- 已确认全局入口调用 `MediaKit.ensureInitialized()`；同时确认完整 iOS 工程由 CI 动态脚手架生成，部署目标为 iOS 16.0，并经 CocoaPods 集成本地 libmpv 包。
- 已确认详情页灯箱预告片是第二个直接使用 media_kit 的轻量播放器；完整预告片入口仍复用 `PlayerPage`。
- 已检查本地 iOS 库许可证与上游构建说明，识别出 native v0.6.0 固定版本、full 构建许可审计和 podspec 版本不同步三项维护风险。
- 查询最新 pub.dev/native release 状态的首个 PowerShell 命令有管道语法错误；已记录并将改用变量收集输出。
- 已成功核对当前上游版本：Dart 层已是最新，iOS native 构建落后两个以上发布周期；官方现推荐跨平台 `media_kit_libs_video`。
- 已核对 Bitmovin 官方 Flutter SDK，补充商业播放器路线；GStreamer 官方页面 503 已记录并切换文档源。
- 已从 GStreamer 官方 GitLab 文档确认 iOS 12+ 与 1.28 XCFramework 路线；项目发现和外部资料核验阶段完成，开始汇总对比与建议。
- 静态分析通过；12 个相关测试文件的 46 个测试全部通过。
- 已确认 PiP 的 headers 不会进入 AVPlayer；同服务器 token query/HLS 路径正常，header-only 外部源是未覆盖边界。
- 已形成七类 iOS 播放内核/SDK 对比表与五项项目建议，进入最终证据与工作区检查。
- 最终检查完成：业务代码无改动；仅更新 `task_plan.md`、`findings.md`、`progress.md` 调查记录；`git diff --check` 通过。
- 状态：完成。

## 2026-08-24

- 开始实施 iOS 多播放器内核与 libmpv v0.7.2 升级。
- 已沿用 `planning-with-files` 持久化规划流程并运行会话恢复脚本。
- 已确认 `.codegraph/` 存在，后续源码定位优先使用 CodeGraph。
- 已确认规划文件含历史任务内容，本任务仅追加章节，不覆盖已有记录。
- 已建立六阶段实施与验证清单；当前正在核对播放器代码、依赖和测试基线。
- 已补齐详情页完整预告片入口的会话级 `libmpv` 覆盖，普通影片仍在创建新会话时读取 iOS 默认内核。
- Swift 静态复核修正了非可选 `manager` 的错误可选链；Pigeon Host API 签名与 Swift 实现一致。
- 已删除新插件不应提交的独立 `pubspec.lock`；生成缓存 `.dart_tool/` 由仓库根忽略规则排除。
- `flutter analyze`：通过，`No issues found!`。
- 完整 `flutter test`：374 项全部通过（包含新增双内核 contract、UI 一致性、路由与单次回退测试）。
- 补齐首次 `open` 前的 AVPlayer 播放决策失败回退：切换至 libmpv 后以其 capabilities 重新决策，并与运行时回退共用一次性门闩。
- 最终完整 `flutter test`：377 项全部通过。
- 最终 UI 具体播放器类型扫描无命中；Android 目录零差异；`git diff --check` 通过。
- Pigeon 生成 Dart/Swift 文件均已进入可提交清单；插件级 `pubspec.lock` 已移除，`.dart_tool/` 由根忽略规则排除。
- 当前 Windows 环境无法执行 CocoaPods/Xcode/Swift XCTest；iOS 无签名构建与真机媒体矩阵保留给 macOS CI 和 iOS 16+/最新稳定系统验收。
- 将平台默认解析、client caps、播放路由、AVPlayer 音轨映射和字幕重决策判断继续下沉至统一会话层，`PlayerPage` 不再按平台或具体内核分支。
- 新增平台解析与 AVPlayer 音轨映射契约测试；最终 `flutter analyze`、UI 边界扫描、Android 零差异和补丁卫生检查全部通过。
- 开始 AVPlayer 弱网缓冲与自动续播改造；已读取 `planning-with-files` 技能并执行会话恢复检查。
- 已确认本轮采用固定 60 秒前向缓冲，不复用 libmpv 字节档位、不新增设置项、不修改 Android。
- 已在原生会话启用 `automaticallyWaitsToMinimizeStalling` 和 60 秒 `preferredForwardBufferDuration`，并以 `play()` + `defaultRate` 替代 `playImmediately(atRate:)`。
- 已增加独立播放意图、卡顿通知、单次延迟恢复、播放到结尾失败上报及完整观察器清理。
- 已补充 Swift 测试，覆盖缓冲状态映射、前向缓冲配置、卡顿事件和错误去重。
- `flutter analyze --no-pub`：通过，`No issues found!`。
- 完整 `flutter test --no-pub`：377 项全部通过。
- `git diff --check`：通过；Android 与 `packages/media_kit_libs_android_video` 零差异。
- 当前 Windows 环境无 Swift/Xcode 工具链，Swift XCTest 需由 macOS CI 执行。

- 开始 AVPlayer 起播优化与详情页长按选择内核任务。
- 已恢复既有规划记录并确认工作区包含上一轮播放器改动，后续将在其上做外科式增量修改。
- 已确认起播链路存在系统初始等待、默认音轨最多 2 秒等待以及加载页阻止 Surface 挂载三项可见延迟来源。
- 已记录 PowerShell 多值 `-Filter` 和首次规划追加上下文错误，并分别改用直接读取与稳定末行追加。
- 已定位影片详情播放按钮和 `PlayerPage.open(engineKind:)` 的现有一次性覆盖接缝。
- 已确认播放器工厂是平台能力判断的合适归属，详情页长按只消费可选内核列表。
- 已按用户澄清区分“播放期间持续预取”与“停顿后重新攒缓冲”：60 秒只用于前者，首次起播和有限恢复均不等待填满该窗口。
- 已核对本地化生成配置和现有 contract 测试结构，准备进入实现阶段。
- 已保留 `preferredForwardBufferDuration = 60` 作为播放期间持续预取目标；首次无续播位置时在 item 装载后立即表达播放意图，断流有限恢复也不等待填满 60 秒窗口。
- 已为 AVPlayer 单音轨加入无需等待原生轨道枚举的快速路径，移除最多 2 秒无意义阻塞。
- 已在播放器工厂增加当前平台可选内核列表；详情页播放按钮普通点击不变，iOS 长按弹出本次会话的 `libmpv / 原生` 选择器，Android 不启用长按入口。
- 已补齐中英文 ARB 文案并重新生成本地化文件；已新增内核列表、单音轨快速路径和选择器 Widget 测试。
- 定向测试通过：播放器 contract、内核选择器和设置本地化共 14 项全部通过。
- `flutter analyze --no-pub` 通过，`No issues found!`；`git diff --check` 通过；Android 目录保持零差异。
- 完整 `flutter test --no-pub`：380 项全部通过。
- AVPlayer 缓冲进度已改为当前位置连续缓存区间，续播初始 seek 使用 0.5 秒容差；用户拖动定位仍保持精确 seek。
- staged 与工作树补丁卫生检查均通过，本地化中英文生成结果已核对。
- 当前 Windows 环境不能运行 Swift XCTest 或测量 iOS 真机首帧耗时；原生实现与新增 XCTest 需由 macOS CI/真机完成最终确认。

- 开始处理 AVPlayer 真机反馈：起播仍慢、失败回退 libmpv 不播放、进度条异常。
- 已重新读取 `planning-with-files` 并恢复现有规划记录；后续保留当前 staged/unstaged 工作区状态。
- 已用 CodeGraph 还原三条故障链路，确认是 Surface 挂载时序、回退复用旧 AVPlayer URL/并发竞态，以及 duration/buffered 更新不完整三个确定性问题。
- 播放加载页现在始终在统一 Surface 上方显示，AVPlayer 的 PlatformView/AVPlayerLayer 可在媒体装载前完成挂载；主媒体 open 后立即关闭加载页，再异步完成默认轨道应用。
- 已移除会话层“libmpv 直接打开旧 AVPlayer URL”的内部回退；open 失败由页面 catch 切换内核后重新决策，运行时失败通过 `PlaybackReloadRequest` 通知页面以 libmpv capabilities 重新请求。
- 运行时回退请求保留位置、播放意图和倍速；页面显式传入当前 quality，避免 `_loadInternal` 复用旧 AVPlayer decision。
- AVPlayer 新增 duration KVO、周期性连续 buffered 刷新和 seek 后 position/buffered 即时刷新；Dart open 同时清零上一媒体的 duration/buffered/size。
- contract 测试已改为覆盖“打开失败重新决策”和“运行时失败不复用旧 URL”两条路径。
- 首次定向测试发现删除旧 URL 内部回退后残留 `_selectedSubtitleTrackId` 赋值，已按编译错误清理，未重复失败操作。
- 收尾静态复核确认 Swift item KVO、周期位置观察器和通知观察器均有对应释放路径；seek 完成会即时刷新 position 与连续 buffered。
- 新发现运行时错误上报前 AVPlayer 会先清空 `playing`，现有测试没有模拟该顺序，导致回退恢复播放意图的缺陷未被覆盖；进入针对性修复与回归测试。
- `PlayerSessionController` 已独立记录 open/play/pause/playOrPause/stop 的播放意图；运行时错误回退不再读取失败事件清空后的 `playing`。契约测试现会模拟 AVPlayer 先上报 `playing=false` 再报错的真实顺序。
- 统一进度条现将 secondary buffered 下限钳制为当前 position，避免 AVPlayer seek/换区间后短暂上报 0 时缓冲进度落到已播放进度后方；同一 Widget 测试覆盖 libmpv 与原生两种 fake engine。
- 定向验证通过：播放器 contract 与控制栏 parity 共 9 项全部通过；四个相关 Dart 文件定向 analyze 无问题。
- AVPlayer 的 60 秒 `preferredForwardBufferDuration` 已从 open 时点延后到 `AVPlayerLayer` 首帧 ready 后启用；首帧前为 0，确保持续预取目标不参与起播。Swift 测试期望同步调整。
- 完整 `flutter test --no-pub`：382 项全部通过；完整 `flutter analyze --no-pub`：`No issues found!`。
- Dart 格式检查、staged/unstaged `git diff --check` 均通过；Android 与 Android libmpv 包 staged/unstaged 均为零差异。Swift 观察器创建/释放和本轮差异已完成静态复核。
- 最终 UI 边界复核中，`player_subtitle_track_resolver.dart` 仍按设计作为 MediaKit adapter 内部解析器导入 `media_kit`；播放页、控制栏、字幕渲染 UI 和详情页需按实际 UI 文件名单独扫描。
- 按实际 UI 文件清单复扫无具体 `media_kit`/`media_kit_video` 导入；最终 staged/unstaged 补丁检查再次通过。本任务状态更新为完成。

## iOS 接入 KSPlayer 完成记录

- Flutter 播放抽象、KSPlayer session、统一 UI capabilities 和一次性 libmpv fallback 已完成。
- `flutter analyze` 通过；`flutter test` 通过，`394` 项全部通过。
- KSPlayer Pigeon 生成文件已加入 Git 忽略例外，干净 checkout 不依赖本地生成产物。
- Swift 静态复核已完成：KSPlayerLayer delegate、轨道选择、截图、PIP、header 和 Platform View 签名与固定 commit 对齐；dispose 的 MainActor 生命周期边界已修正。
- 外挂字幕保留 Flutter 下载/解析/延迟调整；原生轨道失败且存在外挂地址时会统一降级到外挂字幕。
- 已记录 Windows 无法执行 iOS 原生工具链，需在 macOS CI/真机完成最终验收。

## 2026-08-25 KSPlayer 音轨切换修复

- 已用 CodeGraph 和当前源码确认 `trySelectAudioTrack` 的错误分支，以及 KSPlayer 返回原生 `trackID` 的实现。
- 已将后端 index 直传逻辑收窄为仅 `libmpv`；AVPlayer/KSPlayer 统一使用原生轨道映射，单音轨直接视为已选择。
- 已新增 KSPlayer 语言/标题映射、ordinal 映射、单音轨跳过选择和 `libmpv` index 保持不变的 contract 测试。
- 定向 `playback_engine_contract_test.dart`：15 项全部通过。
- `flutter analyze --no-pub`：通过，无问题；完整 `flutter test --no-pub`：399 项全部通过。
- `git diff --check`：通过。
- 已提交 `9e54fae fix(ios): map KSPlayer audio tracks before selection` 并推送 `origin/dev`。
- iOS GitHub Action `32791124296` 成功，耗时 9 分 50 秒；依赖安装、静态分析、测试、release iOS 编译、IPA 打包和发布均通过。

## 2026-08-25 Oh-My-Media Logo 替换

- 已读取 `imagegen` 技能，确定使用内置图像生成流程；未启用 CLI/API fallback。
- 已读取 `planning-with-files` 技能并恢复历史规划；当前任务只追加记录，不覆盖既有内容。
- 已确认附件是视觉参考，不含需要执行的文字指令。
- 下一步：枚举 Flutter、Android、iOS、Web、桌面端 Logo 资源和引用，随后生成并替换项目资产。
- 已完成资源枚举；确认需要同步 Android、iOS AppIcon、iOS LaunchLogo、Web、macOS 和 Windows 图标，避免不同平台继续显示旧 Logo。
- 已使用内置 `image_gen` 生成并预览新 Logo，生成图中的 `oh / my / media` 文案准确可读，准备复制到项目并按目标尺寸生成各平台资源。
- 已确认 Android 无额外 adaptive icon 文件，Web 与 Windows 资源尺寸已核对；准备执行一次性资源替换和多尺寸导出。
- 首次导出安全失败于源文件路径校验，未写入资源；已记录错误并准备使用实际生成路径重试。
- 已按实际生成路径完成主资源、Android/iOS/启动图/Web/macOS/Windows 图标导出；平台文件名与现有引用保持不变。
- 视觉复核确认新主图中的 `oh / my / media`、播放三角、霓虹光轨和星芒清晰可见。
- `flutter analyze --no-pub` 通过；`flutter test --no-pub` 通过，399 项全部通过；`git diff --check` 通过。
- 本次未改动业务逻辑；保留了工作区原有的 `MainActivity.kt` 修改。
- 最终资源完整性检查验证 44 个图像文件和全部 AppIcon/LaunchLogo manifest 引用；本任务完成。

## 2026-08-25 Android Actions 编译修复

- 已发现当前仓库路径从旧的 `md_center/mobile_app` 移至 `oh-my-media/mobile_app`，并恢复该仓库的历史规划记录。
- 已通过 `gh run list` 定位最新失败运行 `32831761951`；iOS 同提交运行成功。
- 已通过 job 状态与失败日志确认 `analyze`/`test` 通过，失败点为 `:app:compileReleaseKotlin`。
- CodeGraph 已还原 `MainActivity.kt` 亮度 MethodChannel 的完整源码和 Dart 调用契约；根因是两处把 `MethodChannel.Result` 当函数调用。
- 已将 `MainActivity.kt` 两处返回改为 `result.success(...)`，读取亮度显式转换为 Dart 需要的 `Double`。
- 本地 Android APK 构建受环境阻塞：Flutter 报 `No Android SDK found`；已记录，后续以 Dart 验证和远端 CI 复跑确认。
- `flutter analyze --no-pub`：通过，`No issues found!`。
- `flutter test --no-pub`：通过，`399` 项全部通过。
- `git diff --check`：通过；已确认 Logo 资源和 `assets/branding/` 是此前工作区已有改动，未触碰。

## 2026-08-25 KSPlayer 质量切换修复

- 已恢复历史规划并确认工作区已有 6 个非播放器文件修改，后续不触碰、不重置。
- 已按项目规则先使用 CodeGraph 调查 `PlayerPage` 质量切换、`PlayerSessionController` 路由和 `KsPlayerPlaybackEngine`/Swift stop-open 生命周期。
- 已确认普通影片质量按钮没有被 `_isDirectPlayback` 禁用；故障集中在 KSPlayer 切换 HLS 与 direct 时的旧媒体错误事件竞态。
- 已确认下一步需先完成订阅/代次隔离修复，再补回归测试和执行验证。
- 已完成播放器页旧进度/错误订阅隔离，以及 KSPlayer `opening/stopping` 旧错误抑制。
- 已更新 KSPlayer 错误状态契约测试和质量路由测试，并完成格式、定向测试与分析。
- 定向测试 16 项通过；`flutter analyze --no-pub` 通过；完整 `flutter test --no-pub` 401 项通过。
- 格式检查和 `git diff --check` 通过；iOS 原生/真机切换仍需 macOS CI 验证。
- 本轮未处理工作区其他并行修改，也未主动执行提交、暂存或回滚；当前工作区同时存在既有 staged/unstaged 改动。
