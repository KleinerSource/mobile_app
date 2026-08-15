# 第三方依赖说明

## KSPlayer

- 项目：https://github.com/kingslay/KSPlayer
- 使用版本：`2.3.4`
- 集成方式：iOS Swift Package Manager
- 许可证：GNU General Public License v3.0（GPLv3）
- 源码与许可证：以 KSPlayer 仓库对应版本为准

KSPlayer 的 Swift Package 还会解析其声明的 `FFmpegKit` 依赖。发布包含 KSPlayer 的构建时，应同时遵守 KSPlayer、FFmpegKit 及其传递依赖的许可证和源代码提供义务。

## FFmpegKit（传递依赖）

- 项目：https://github.com/kingslay/FFmpegKit
- 当前锁定版本：`6.1.4`
- 锁定文件：`ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- 许可证与源码提供义务：以 FFmpegKit 仓库及其所包含组件在对应版本的说明为准。
