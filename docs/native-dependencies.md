# 原生依赖与验证

本轮保持播放器二进制版本，不裁剪解码器。

| 本地包 | 上游/固定版本 | 定制及保留原因 |
|---|---|---|
| media_kit_libs_android_video 1.3.8 | media-kit/libmpv-android-video-build v1.1.11 | 使用 full ABI jar，保留 FFmpeg 全解码器和 hdmv_pgs_subtitle，维持原 MD5 校验；按 Flutter target-platform 下载/复制。 |
| media_kit_libs_ios_video 1.1.5 | media-kit/libmpv-darwin-build v0.7.2 | iOS universal video-full XCFramework；保留 SHA-256 校验、头文件和 framework 符号链接准备。 |
| omm_ksplayer 0.1.0 | 下表固定的 KSPlayer fork commit | Pigeon 26.3.4 桥接 Dart/Swift；保留播放事件、起播位置、AVPlayer 失败后 FFmpeg 回退、媒体信息与画中画。 |
| omm_scratch_audio 0.1.0 | 仓库内原生实现 | 单盘 DJ 搓碟 PCM 输出，保留插件自动注册。 |

iOS configure 使用现有工作流中的八个环境值（在 macOS 终端导入），源码脚本没有第二套默认版本：

```sh
export KSPLAYER_REPOSITORY=https://github.com/KleinerSource/KSPlayer.git
export KSPLAYER_COMMIT=c34287a220e629e5e796723ffa261d727dbcd7d4
export DISPLAYCRITERIA_REPOSITORY=https://github.com/KleinerSource/KSPlayer.git
export DISPLAYCRITERIA_COMMIT=c34287a220e629e5e796723ffa261d727dbcd7d4
export FFMPEGKIT_REPOSITORY=https://github.com/kingslay/FFmpegKit.git
export FFMPEGKIT_VERSION=6.1.4
export LIBASS_REPOSITORY=https://github.com/kingslay/FFmpegKit.git
export LIBASS_VERSION=6.1.4
```

iOS libmpv 包 SHA-256：`1cce05f2ad1568434beeb0d7fac9f8e8417a69a8c29f320e7e90d568bfe7303b`。后续升级时须一起审阅仓库、commit 和校验值。

准备脚本负责模板工程补齐、Android SDK 模板变量/Wrapper/音量插件修正、iOS 启动屏/部署目标/静态 Pods 注入。版本号、签名、产物扫描、上传发布仍由原工作流负责；脚本没有发布行为。

Android 下载已从配置阶段移到 preBuild 依赖任务，输入记录目标 ABI、输出记录打包目录。ABI 改变会清理打包目录，版本缓存仍复用。`android-arm64` 仅选 arm64；直接 Gradle 构建未传 target-platform 时保留四套。模拟器可选 `android-x64`，但应用工程原有全局 arm64 abiFilters 仍需另行配置才可安装到 x86_64 模拟器，本轮保持平台目标不变。

发布前仍须验证：

1. Flutter 3.44.0 干净 checkout 的 bootstrap/configure、代码生成、analyze/test。
2. Android arm64 APK/ABI 检查，重复构建和切换 ABI 后不混入旧 jar。
3. macOS iOS 无签名构建，验证静态 Pods、libmpv/KSPlayer 符号及插件注册。
4. 真机续播、队列、PGS 字幕、转码、代理释放、后台恢复、方向、画中画及 Scratch Audio。

本机 Windows 缺少 Android SDK，且没有 macOS/真机；原生验收未完成。
