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
