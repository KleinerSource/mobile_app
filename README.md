# omm 移动端

基于 Flutter、Riverpod 和 Dio 的媒体管理客户端，支持 OMM、DBO、Emby/Jellyfin、飞牛、Stash 及文件来源，包含媒体浏览、批量管理、视频/音频播放。

## 开发环境

- 发布与 CI 基线：Flutter **3.44.0 stable**，使用其自带 Dart。
- 本次优化本地验证：Windows、Flutter **3.47.0 / Dart 3.13.0**；未升级 CI 基线。
- Android：JDK 17、Android SDK 36、Flutter 对应的 NDK；发布目标 `android-arm64`。
- iOS：macOS、Xcode、CocoaPods，部署目标 16.0；已关闭 Swift Package Manager。
- 保留 `pubspec.lock` 和 `packages/` 内本地插件；不要直接用 pub.dev 包替换本地播放器库。

## 初次准备

仓库仅保留部分原生工程文件。准备脚本与 CI 共用，可重复执行；`bootstrap` 仅在工程缺失时调用 `flutter create --no-pub`，随后修正平台配置。在 mobile_app 根目录运行：

```sh
dart tool/prepare_native.dart bootstrap android
flutter pub get
dart tool/prepare_native.dart configure android
dart run build_runner build
flutter analyze --no-pub
dart tool/run_fast_tests.dart
flutter build apk --release --target-platform android-arm64 --no-pub
```

Android `configure` 会修改 package_config 指向的 `flutter_volume_controller` 缓存配置，将 compileSdk 设为 36；重新下载依赖后需再执行。它也将 Wrapper 下载域名改为官方 `downloads.gradle.org`。应用显式 minSdk 23 保持，模板变量回退为原 CI 的 24；targetSdk/compileSdk 模板变量固定为 35/36。

iOS 在 macOS 上执行，先按 [原生依赖说明](docs/native-dependencies.md) 导入固定版本环境变量：

```sh
dart tool/prepare_native.dart bootstrap ios
flutter pub get
dart tool/prepare_native.dart configure ios
cd ios
pod install --repo-update
cd ..
dart run build_runner build
flutter build ios --release --no-codesign --no-pub
```

签名由现有工作流注入；本地 Android 缺少发布证书时使用原有 debug 签名回退，不能替代线上更新证书。

## 测试与 CI

依赖准备和代码生成完成后，在项目根目录运行：

```sh
# 本地快速反馈：固定名单，覆盖认证、配置、API、分页、预览和构建工具。
dart tool/run_fast_tests.dart

# 静态分析与完整回归：包括页面交互、播放器、文件操作及布局测试。
flutter analyze --no-pub
flutter test --no-pub

# Windows 页头截图回归：比较固定平台的截图基线。
flutter test --no-pub --dart-define=HEADER_GOLDENS=true test/shared/header_visual_test.dart --reporter expanded
```

`Full Tests` 是 push、PR 和手动运行的统一入口：先执行静态分析、完整 Flutter 回归和 Windows 页头截图回归，全部成功后才并行启动 Android/iOS 构建。任何前置检查失败、取消或未执行，都会阻止两平台构建及发布。

Android/iOS 与页头截图工作流仅由 `Full Tests` 调用，使用同一次运行的提交；两平台不再重复执行静态分析或快速测试。签名、版本号、产物上传和发布条件沿用现有规则。手动构建时选择 `Full Tests` 的 Run workflow。

同分支的新运行会取消旧的整条流水线。完整测试结果与耗时保存在 `full-test-results`，截图失败差异保存在 `header-visual-differences`，均保留 7 天。`tool/run_fast_tests.dart` 保留用于本地快速反馈；新增测试默认进入 CI 完整回归。

## 结构与代码生成

| 目录 | 职责 |
|---|---|
| `lib/core/sources` | 媒体/文件能力接口、来源适配器及协议客户端/模型 |
| `lib/core/platform` | 平台服务和设备统计采集 |
| `lib/features` | 页面、导航、展示状态及业务编排 |
| `lib/shared` | 多处使用的组件、分页协调、选择和预览逻辑 |
| `packages` | 本地播放器库、KSPlayer 桥接、Scratch Audio |
| `test` / `tool` | 回归测试和本地/CI 共用脚本 |

修改 Freezed/JSON/Retrofit 模型后运行 `dart run build_runner build`；生成的 `.g.dart`、`.freezed.dart` 不入库。修改 ARB 后运行 `flutter gen-l10n`；`lib/l10n/generated/` 不入库，`flutter pub get` 会自动补齐。保留中英 ARB 和 `l10n.yaml`。

修改 KSPlayer Pigeon 接口后，在插件目录用固定的 Pigeon 26.3.4 同时生成 Dart/Swift 两端，并提交两份生成文件（CI 不会自动运行 Pigeon）：

```sh
cd packages/omm_ksplayer
flutter pub get
dart run pigeon --input pigeons/ks_player_api.dart
```

分页仍使用 4.x API。见 [依赖迁移路线](docs/dependency-migrations.md) 和 [优化实施记录](docs/optimization-validation.md)。
