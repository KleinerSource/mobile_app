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

## 2026-08-25 应用更新开发版检测开关

- 已读取并遵循 `planning-with-files`，会话恢复检查未发现未同步上下文。
- 已确认工作区初始无未提交代码改动，当前 `dev` 相对 `origin/dev` 领先 2 个提交。
- 已完成现有更新链路、Release 标签、远端 master/dev push build 和测试基线调查。
- 已追加本任务的计划、发现和进度章节，未覆盖历史任务记录。
- 已按仓库规则使用 CodeGraph 复核候选选择、设置持久化、协调器、启动检查和更新页面的当前源码及影响范围。
- 已新增默认关闭的开发版检测偏好、回滚式 Notifier，并在切换时清除已忽略版本。
- 已扩展四个滚动 Release 标签，并让候选选择在关闭时同时过滤 `*-dev` Release 与 `omm_dev_` 资产。
- 已将 `includeDevelopment` 贯穿服务、协调器、更新页和启动检查，并在“当前版本”卡片加入禁用感知开关。
- 已补充仓库偏好、四个标签、混合渠道候选、Release 列表回退、开发标签缺失和同版本时间排序测试。
- 已新增服务级 Dio stub 测试，直接验证实际标签请求集合与标准版严格回退。
- 已新增更新页 Widget 测试，验证开关所在卡片、说明文案、默认值及持久化恢复。
- 更新相关定向测试共 20 项全部通过；CodeGraph 复核确认修改文件索引已同步，唯一待同步文件是本任务未触碰的播放器文件。
- `flutter analyze --no-pub` 通过；完整 `flutter test --no-pub` 共 417 项全部通过。
- 最终差异复核发现列表回退仍拼接未过滤 draft 的滚动 Release，已改为复用 `publishedRollingReleases`，避免草稿资产进入候选。
- 已增加草稿滚动 Release 的服务回归测试；最终更新模块定向测试 21 项全部通过。
- 最终状态再次运行 `flutter analyze --no-pub` 与完整 `flutter test --no-pub`，静态分析无问题，418 项全部通过。
- Dart 格式检查、`git diff --check` 和改动范围复核均通过；未修改 GitHub Actions、依赖或平台安装代码。
- 本次未提交或推送；本地 `dev` 仍包含用户原有的 2 个未推送提交，远端 push build 需在用户后续推送后验证。

## 2026-08-25 dev 构建版本号持久化

- 已读取并遵循 `planning-with-files`，并核对当前工作区包含上一任务的未提交更新功能改动，后续将完整保留。
- 已确认版本持久化职责在 iOS workflow；当前仅 master 会提交，dev 只在 runner 临时文件中递增。
- 已确定保持单写入者，仅扩展 iOS workflow 条件与动态目标分支。
- 已扩展 iOS workflow：仅 `master/dev` 的 `push` 或 `workflow_dispatch` 持久化版本，并通过 `GITHUB_REF_NAME` 推送回触发分支。
- 首次使用 `bash` 的验证因 Windows `PATH` 未包含 Bash 而失败；已记录并改用 Git for Windows 的显式路径继续验证。
- 已用 `C:\Program Files\Git\bin\bash.exe` 通过 Shell 语法检查和真值表验证：`push + dev` → `dev`、`workflow_dispatch + master` → `master`，PR 与 feature 分支均跳过。
- `.github/workflows/ios-build.yml` 已通过 UTF-8 YAML 解析；`git diff --check` 通过，仅有 LF/CRLF 转换提示。
- 最终差异仅把 iOS workflow 的版本持久化从 master 扩展到 master/dev；Android workflow 和版本计算脚本均未修改。

## 2026-08-25 合并 dev 到 master

- 已读取并遵循 `planning-with-files`，会话恢复脚本无额外输出。
- 合并前本地位于 `dev`，工作区干净，当前相对 `origin/dev` 领先 3 个提交。
- 已刷新远端引用；待推送提交为 `1c2404b`、`0a675ea`、`162ca24`，最新提交是开发版更新检查与版本持久化功能。
- `origin/master...dev` 当前分叉为 master 独有 1 个、dev 独有 39 个提交；合并时需保留 master 的独有提交。
- master 独有提交仅为 `fc51a0b chore: bump build metadata to 0.38.22+409 [skip ci]`；最新 dev 功能提交 `162ca24` 包含更新检测开关、workflow 与对应测试。
- 合并预演生成树 `66b723fc9e6ab809cb2b78b4c0e1b7e854d85b27` 且无冲突；合并需要保留 master 较新的 `0.38.22+409` 版本基线。
- 已临时保存本轮计划日志后执行 `git push origin dev`，远端从 `230122f` 快进到 `162ca24`；随后已恢复计划日志。
- 推送后首次查询提交 `162ca24` 的 Actions 返回空列表，判断为 GitHub 尚未创建/索引运行，后续只轮询状态，不重复推送。
- 已确认本次 dev push 创建两条运行：Android `32866052468`、iOS `32866052358`，两者当前均为 `in_progress`。
- dev 的 Android `32866052468` 与 iOS `32866052358` 已完成且结论均为 `success`。
- 首次并行查询远端版本、iOS 日志和 Release 时，JavaScript 包装参数拼写错误导致调用未执行；未产生任何仓库或远端变更，已改用修正后的调用。
- 已确认版本持久化实测成功：iOS 日志显示生成 `0.39.0+409`、提交 `57c9d66` 并推送 `HEAD -> dev`。
- `latest-android-dev` 已发布 `omm_dev_0.39.0+409.apk`，`latest-ios-dev` 已发布 `omm_dev_0.39.0+409.ipa`，均为非草稿 prerelease。
- 最新合并预演仅在 `pubspec.yaml` 出现版本冲突；计划在真实合并时保留 dev 的 `0.39.0+409`，避免标准版退回 master 的 `0.38.22` 功能版本。
- 已用 CodeGraph 核对 `version_policy.dart`：普通 merge message 会走 bugFix；因此合并提交使用 `[no-version]`，让 master workflow 只增加 build 号而不重复增加 patch/minor。
- 已更新本地 dev 到版本回写提交 `57c9d66`，切换并快进本地 master 到 `fc51a0b`。
- 真实合并仅冲突 `pubspec.yaml`；已保留 `0.39.0+409`，无其他未解决文件，`git diff --check` 通过。
- 已创建双父合并提交 `56ba45d chore: merge dev into master [no-version]` 并正常推送 `origin/master`。
- master push 已启动 Android `32868044178` 与 iOS `32868044174`，当前均为 `in_progress`。
- 收到用户关于 master Actions 显示 dev 信息的反馈后已暂停完成判断并核验：两条运行 API 均明确返回 `headBranch: master`、`headSha: 56ba45d`；workflow 的构建、资产和 Release 渠道仍按 `GITHUB_REF == refs/heads/dev` 分支判断。
- 已刷新远端确认 master 版本持久化成功：`fb3510f` 将版本写为 `0.39.0+410`；dev 仍是 `57c9d66 / 0.39.0+409`，不存在渠道串线。
- master 的 Android `32868044178` 与 iOS `32868044174` 已完成且结论均为 `success`。
- `latest-android` 已发布 `omm_0.39.0+410.apk`，`latest` 已发布 `omm_0.39.0+410.ipa`。
- 开发版 `latest-android-dev` / `latest-ios-dev` 仍分别保持 `omm_dev_0.39.0+409.apk/.ipa`，确认标准与开发渠道没有互相覆盖。

## 2026-08-26 KSPlayer 连续切换清晰度失效

- 已读取并遵循 `planning-with-files`，恢复上下文时工作区干净。
- 首次同时追加三个规划文件因 `findings.md` 锚点不存在而整体失败，未修改任何文件；已改用真实 EOF 锚点分别追加并记录错误。
- 已按仓库规则使用 CodeGraph 复核 `PlayerPage._loadInternal` 调用链；确认当前仍是先停服务端转码、后停本地播放器、最后显示 loading。
- CodeGraph 对少数无关/测试依赖文件提示索引同步中；`player_page.dart` 返回的是当前磁盘源码，测试文件将按提示直接读取。
- 下一步调整共享切源顺序并补充 libmpv/KSPlayer 的 `open → stop → open` 契约测试。
- 已将目标质量、loading 和旧决策清理提前到服务端等待之前；随后按“解绑监听 → 停本地播放器 → 等服务端清理”执行，并在两个异步边界检查任务代次。
- 已让质量切换同时捕获并传递 `_host.playbackIntent`，暂停切换保持暂停，播放中切换继续自动播放。
- 已新增统一契约测试，libmpv/KSPlayer 均覆盖 `open → stop → open`、84 秒续播点以及播放/暂停两种意图。
- 定向播放器与模型测试 27 项通过；`flutter analyze --no-pub` 无问题；完整 `flutter test --no-pub` 419 项全部通过。
- Windows 环境无法执行 iOS 真机验证，最终仍需按既定连续切换矩阵验证 KSPlayer，并用 libmpv 重跑同路径。

## 2026-08-26 KSPlayer 二次切换后无限加载

- 用户真机反馈第二次切换分辨率进入无限 loading，已重新读取并启用 `planning-with-files`。
- 会话恢复确认上一轮播放器代码已进入当前 HEAD；工作区仅三个规划文件有未提交记录。
- CodeGraph 复核确认第二次切换新增的独有等待点是 `_stopTranscodeSession()` 中对 Dio SSE 订阅取消的无界等待，后续仍需结合服务端停止实现验证并补测试。
- 后端复核确认 StopByMovie 有界但 SSE 断连清理会竞争 session 锁；Web 端已有轮询替代 SSE 的同类时序结论，移动端现有 3 秒轮询可作为可靠状态来源。
- Dio 配置复核确认 DELETE 最长有 30 秒接收超时，SSE cancel 则无界；开始设计 API 层取消契约测试，避免依赖 iOS 私有状态或扩大 PlayerPage 注入面。
- SSE 悬挂取消测试未能复现且当前实现已通过，已删除该无效测试并记录；诊断转向 KSPlayer 原生 `finishPendingOpenIfReady()` 对非零 seek 回调的无界依赖。
- 已确认原生插件没有 Swift 单元测试目标；拟为 ready 后的初始 seek 增加 generation-aware 有界完成兜底，并扩展现有统一播放器连续打开契约覆盖非零位置。
- 已实施最小原生修复：ready 后提交初始 seek 即完成 Pigeon open，不再等待可能缺失的 seek completion；AVPlayer 非零起点启用既有延迟位置校验，校验重试沿用原始 autoplay 意图。
- CodeGraph 已复核修改后的 Swift 源码和影响范围；播放器契约、路由、菜单一致性及播放模型定向测试 27 项通过。
- 当前 Windows 没有 Swift 编译/格式化工具，已明确保留 iOS CI/真机验证，不以 Dart 测试替代原生编译结论。
- `flutter analyze --no-pub` 通过；完整 `flutter test --no-pub` 419 项全部通过；最终空白和改动范围检查通过。

## 2026-08-26 KSPlayer 二次切换仍无限加载（续查）

- 用户确认完整重建后问题仍存在，上一轮解除初始 seek completion 等待未解决故障。
- 会话恢复确认工作区干净，当前 `master` 与 `origin/master` 一致，排除未推送或旧工作树干扰。
- CodeGraph 复核当前加载链：页面进入 loading 后依次等待 `_stopPlayer()`、`_stopTranscodeSession()`、播放决策与 KSPlayer `open()`；KSPlayer Dart `stop()` 会直接等待原生 Pigeon `stop` 回复。
- 原生 `KsPlayerSession.stop()` 与 `recreateLayer()` 都同步调用 `KSPlayerLayer.stop()`；其中 `open()` 在 `recreateLayer()` 中再次停止旧 layer，现阶段这是最需要验证的无界完成边界。
- Pigeon 的 `stop` 是同步 HostApi：Dart 会等待 iOS 主线程执行完 `session.stop()` 后才继续；原生当前直接在该调用栈内执行 `layer.stop()`。
- 每次新 `open()` 又会在 `recreateLayer()` 中对同一旧 layer 执行一次 `stop()`，形成“显式 stop → 再次 stop → 新 prepare”的双重停止序列；该序列没有原生测试覆盖。
- 已定位到固定 KSPlayer 源码副本：`KSPlayerLayer.stop()` 会同步执行 `player.shutdown()`，因此真正阻塞点还要下钻到 `KSAVPlayer`/`KSMEPlayer` 的 shutdown 实现。
- 外部源码检索首次假定 podspec 名为 `omm_ksplayer.podspec`，实际路径不存在；后续先枚举插件目录确认真实文件名，不重复该假设。
- 已确认真实 podspec 位于 `packages/omm_ksplayer/ios/omm_ksplayer.podspec`，插件通过 CocoaPods 依赖 `KSPlayer`。
- 固定 KSPlayer 源码显示：HLS 使用的 `KSAVPlayer.shutdown()` 是同步取消 asset loading、移除 resource loader 并 `replaceCurrentItem(nil)`；FFmpeg 的 `KSMEPlayer.shutdown()` 只调度异步 close operation，不会等待解码线程退出。
- 因此“原生 stop 等待 FFmpeg close 永久阻塞”的假设不成立；下一步转向检查页面 `_loadQueue` 代次串行化和转码 DELETE 的真实 Future 边界，同时核对新 layer 的 `set/prepare` 状态机。
- 页面当前会在 `_transcodeSessionActive` 为 true 时先发起 DELETE，再取消 SSE，随后等待 DELETE；SSE cancel 已在上一轮单测中排除，但 DELETE Future 仍是进入下一播放决策前的硬门槛。
- CodeGraph 返回了 `_onQualityChanged` 与转码清理主体，但没有返回 `_load` 队列封装源码；按其限制，下一步只针对该未覆盖片段做精确文件读取。
- 精确读取确认 `_load` 会把所有请求串到 `_loadQueue`；任一旧任务中真正不返回的 Future 会永久阻塞后续质量选择，即使 `_loadGeneration` 已让旧任务失效。
- 服务端 `StopByMovie` 会先从 manager map 摘除旧会话，再逐个执行 `TranscodeSession.Stop()`；SSE handler 的取消只负责 unsubscribe，不持有 manager 锁，未发现与 DELETE 的互锁证据。
- 服务端 `TranscodeSession.stopLocked()` 的等待严格有界：context cancel 后最多等 2 秒，必要时 kill，再最多等 2 秒；DELETE 不是服务端代码层面的无限等待。
- KSPlayer `set(url:)` 仅在主线程修改 layer URL，`prepareToPlay()` 才触发底层准备；仍需核对 URL `didSet` 与 prepare 的先后是否在连续创建 layer 时发生异步竞态。
- 已确认 `runOnMainThread` 在主线程会同步执行，因此 `set(url:) → URL didSet → player.replace → prepareToPlay()` 的顺序确定，不是异步 URL 赋值竞态。
- 新 layer 会重新挂载到同一 PlatformView 容器；下一步检查 Dart KSPlayer 实例能否在原生 `open` 丢失 ready 回调时重建会话并有限重试，避免 `_loadQueue` 永久悬挂。
- `OmmKsPlayer.open()` 直接返回 Pigeon Future，没有 timeout；`KsPlayerPlaybackEngine` 复用同一个 `OmmKsPlayer`/playerId，任何缺失的原生 open reply 都会直接悬挂页面 `_loadQueue`。
- 现有 surface 绑定在初始化时创建的 `_playerFuture` 上，若在 Dart 层改用新 playerId 重试还需同步重建 PlatformView，改动面较大；优先考虑让原生 open 契约自身有界，并保留 ready/error 事件驱动播放状态。
- `KsPlayerPlaybackEngine.open()` 当前只更新 opening 状态后无界等待 `OmmKsPlayer.open()`；`stop()` 也无 timeout，但原生 stop 主体已确认同步且有限。
- `PlayerSessionController.open()` 只是把请求转给当前 engine；需要继续复核外层 host 的一次性 libmpv fallback，确认原生 open 超时抛错后能否自动恢复，而不是只停在错误页。
- `createPlayerSession()` 只在会话创建时选定 KSPlayer/libmpv，`PlayerSessionController.open()` 本身不切换内核；本轮不能假定 open timeout 会自动落到 libmpv。
- 因此若给 KSPlayer open 加超时，至少应把无限 loading 变为明确错误；若要自动恢复，需要复核页面错误/重载监听是否有另一个内核切换入口。
- 发现更具体的内核路由疑点：所有后端 HLS 打开都把 `_mediaInfoForDecision(decision)` 传给 KSPlayer，而该函数优先使用 `decision.videoCodec`，仅为空时才用 `decision.targetVideo`。
- 原生 `prefersFfmpegPlayer()` 只要收到 HEVC/H.265 codec 就强制选择 `KSMEPlayer`，完全不优先识别 `.m3u8`；如果 `decision.videoCodec` 表示源编码，HEVC 原片的 HLS 转码仍会错误进入 KSPlayer 的 FFmpeg 内核，而不是 AVPlayer。
- 后端源码已证实字段语义：`Decision.VideoCodec` 是源文件编码，`Decision.TargetVideo` 是输出编码；完整 HLS 转码明确输出 H.264 8-bit。
- 当前移动端因此把 HEVC 原片的 HLS 转码错误标成 HEVC 传给原生 KSPlayer，导致 `.m3u8` 被强制交给 `KSMEPlayer`。这与“第一次能开、停止旧转码后第二次无法 ready”高度吻合，也解释了为何 libmpv 路径不受影响。
- 修复方向收敛为：仅在打开后端 HLS 时优先使用 `target_video/target_audio` 描述实际流；direct/original 继续使用源 `video_codec/container`，不改变服务端协议。
- `PlaybackMediaInfo.inferInternalPlayer()` 同样先按 video codec 判定：HEVC 会得到 `KSMEPlayer`，H.264 `.m3u8` 会得到 `AVPlayer`，可作为 Dart 回归断言。
- 修复将只改变后端 HLS 的请求媒体信息，不全局更改 KSPlayer 原生路由；这样固定分辨率的完整转码使用 `target_video=h264`，原生/自动仍保留源 HEVC→FFmpeg 逻辑。
- 计划把“源流/目标流媒体信息选择”下沉到已有 `engine_playback_route.dart`，由其现有路由测试直接覆盖，避免为 `PlayerPage` 私有方法建立额外注入层。
- 首次三文件组合补丁因 `player_page.dart` 的 direct open 调用上下文与预期缩进不一致而整体未应用；未产生代码改动，改为按文件拆分小补丁。
- 已将播放决策的媒体信息映射下沉到 `playbackMediaInfoForDecision()`：direct 默认保留源 `video_codec`，后端 HLS 显式优先 `target_video`。
- `PlayerPage._openBackendStream()` 仅在实际 HLS 时启用目标编码；原生/自动 direct 路径保持原行为。
- 已新增回归测试：HEVC Matroska 原片 direct 仍推断 `KSMEPlayer`，同一决策的 H.264 HLS 转码推断 `AVPlayer`。
- Dart 格式化完成；播放器路由、统一契约、控制栏一致性和播放模型定向测试共 28 项全部通过。
- CodeGraph 复核确认新映射只有 `PlayerPage` 播放打开路径使用，并由路由测试覆盖；未出现索引陈旧提示。
- `flutter analyze --no-pub` 通过，`No issues found!`；`git diff --check` 通过，仅有 Windows LF/CRLF 提示。
- 完整 `flutter test --no-pub` 通过，共 420 项全部成功。
