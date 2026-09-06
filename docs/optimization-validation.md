# 优化实施与验证记录

实施日期：2026-09-06。保持功能、界面、中英文本地化、服务器协议和持久化格式；未提交、发布或执行大版本迁移。

## 已实施

1. 新增 `PagedRequestCoordinator`，接入 16 个分页生产页面（含部分文件中的多个结果状态），统一请求代次、同页去重、销毁保护。刷新/筛选使旧票据失效，成功与失败都检查有效性；后台刷新与普通翻页共用协调器。
2. 影片库、收藏及四个管理页刷新等待实际请求结束；收藏不再固定等待 600ms。分页 4.x 在首屏加载时 refresh 可能不重新请求，公共 `refreshPagedController` 在帧末补发、由协调器去重。音频管理保留原列表的刷新路径也接入完成通知和旧结果隔离。
3. 缩略图采用页面共享的两并发下载队列、条目持有请求；取消条目时取消传输和流，队列跳过释放的条目。图片按显示尺寸和 DPR 解码，卸载时逐项移除 MemoryImage 缓存键，页面不再长期保存原图 Future。来源未提供缩略图接口时仍需读取完整单文件；本轮控制并发和持有周期，未宣称减少单张图片的传输量。
4. 四个管理页复用 PagedSelectionController，演员/映射/资源页复用 PagedSelectionScope。音频页保留禁用资产过滤的原拖选装配。ErrorView.list 替换四处列表错误占位；影片库/收藏/搜索复用 180ms 预览控制器；服务器头像、项目标签和缓存分类标签收敛。
5. 将 DBO、MediaBrowser、飞牛、Stash 的 11 个协议文件移到 core/sources/media；设备统计移到 core/platform。检查移动前后内容，除 import/export/part URI 和空白外相同；core 到 features 的 import/export 为零。
6. 五个大型模块按文件操作/预览/目录选择、播放器进度/转码/设备、服务器操作/卡片、演员同步会话/应用/展示、服务器切换流程/转场拆分。使用 Dart part 和私有 State extension 保留同一个 State 及既有 Session/Tracker 的资源所有权；没有新增一套状态或通用仓储。
7. 删除旧 MediaInfo、isCupertino、LibraryMoviesPage、HomeLibrariesSection 和无引用兼容导出。保留条件导出的 smb2_api_web、测试 sources.dart、json_annotation、本地媒体库与原生注册插件。旧进度组件场景迁到生产使用的 MediaBrowserLibraryRefreshIndicator；现有库隐私首次揭示、首页隐私轮播及库设置侧滑刷新测试保留。
8. Dio 升至 5.11.1、flutter_riverpod/riverpod 升至 3.4.3。保留其余版本及 CI Flutter 3.44.0。新增共用原生准备脚本、Android 按 ABI 下载逻辑；保留工作流其它步骤和已有用户修改。README、原生版本说明、大版本迁移路线已补齐。
9. 修复 `prepare_native.dart configure android` 在 CI package cache 布局差异下抛出 `Bad state: No element`：package config 现在兼容绝对/相对 URI 和无尾斜杠路径，插件 Gradle 文件支持 `.gradle`/`.gradle.kts` 及受限递归回退查找；找不到时返回包含检查路径的诊断错误。

## 验证

本机：Windows，Flutter 3.47.0 stable / Dart 3.13.0。

| 检查 | 结果 |
|---|---|
| `dart run build_runner build` | 成功，写出 52 个生成输出；有 SDK 3.13 高于 analyzer 语言 3.12 的提示，未扩大依赖升级范围 |
| `flutter analyze --no-pub` | 通过，No issues found |
| `flutter test --no-pub --reporter expanded` | 全部 1,115 项通过（约 1 分 42 秒） |
| Dart 格式化、`git diff --check`、UTF-8 解码检查 | 通过；已撤回确认无关的单纯格式变更 |
| `flutter test --no-pub test/tool/prepare_native_test.dart --reporter expanded` | 6 项通过，覆盖幂等性、含空格/绝对 URI、缺失 Gradle 文件诊断 |
| `dart tool/prepare_native.dart configure android` | 本机成功；CI package cache 差异路径已覆盖回归测试 |
| core → features 引用扫描 | 0 项 |
| `flutter build apk --release --target-platform android-arm64 --no-pub` | 未通过：No Android SDK found，尚未进入 Gradle 编译 |
| iOS 构建、真机/内存/帧率 | 本机不可执行，尚未验证 |

新增回归覆盖：首屏慢请求晚到、旧请求失败、连续刷新合并、首屏加载中切换筛选、请求中退出、后台刷新与翻页交错、后台刷新后销毁、音频保留列表刷新成功/失败、缩略图两并发/排队/取消/像素比解码/缓存释放、预览防抖与销毁、准备脚本幂等性与含空格路径。

本地完整运行日志位于 `.dart_tool/optimization/`（忽略目录）：`codegen.log`、`analyze-complete.log`、`test-complete.log`、`android-build.log`。早期失败日志属于重构中间状态，不作为最终通过证据。

## 尚需完成的发布验收

- 在 CI Flutter 3.44.0 上重新执行完整检查。
- 配置 Android SDK 后构建 APK，验证仅 arm64、切换 ABI 缓存和 full 解码器/PGS 字幕。
- macOS 构建 iOS，并真机验证续播、队列、后台恢复、字幕、方向、代理与转码释放一次。
- 大图片目录真机连续滚动，测量内存与帧率。本轮没有将单元测试结果替代原生或性能验收。

后续版本升级按 [依赖迁移路线](dependency-migrations.md) 独立进行；平台固定版本及准备步骤见 [原生依赖说明](native-dependencies.md)。
