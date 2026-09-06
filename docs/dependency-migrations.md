# 依赖迁移路线

本轮仅定向升级 Dio 5.11.0 → 5.11.1、flutter_riverpod/riverpod 3.4.2 → 3.4.3。解析器删除 11 个不再使用的间接依赖，未批量升级其余直接依赖。

下列目标版本来自优化方案的核对记录；实际迁移时需重新核对官方约束，不视为永久的最新版本。

| 后续批次 | 目标 | 迁移内容及验收 |
|---|---|---|
| 分页 | infinite_scroll_pagination 4.1.0 → 5.1.1 | 改用 PagingState/新加载入口，迁移 addPageRequestListener、appendPage 等。保留来源自己的偏移/页码/末页规则，复跑乱序请求、刷新、滚动保持、拖选测试。 |
| 图片 | cached_network_image 3.4.1 → 4.0.0 | 核对 SDK/平台要求；验证 Poster、缓存、鉴权头、错误占位、封面强制刷新。 |
| 认证 | local_auth 2.3.0 → 3.0.2 | 认证选项、异常及后台恢复参数迁移；核对 Android 最低版本要求。真机测生物识别、设备凭据、取消和后台恢复。 |
| 凭据 | flutter_secure_storage 10.3.1 → 11.0.0 | 核对旧算法/存储选项移除及平台要求；必须使用历史安装包写凭据后直接升级测试，不能仅测全新安装。 |
| 平台组 | package_info_plus 9.0.1 → 10.2.1、share_plus 12.0.2 → 13.3.0、wakelock_plus 1.5.2 → 1.8.0 | 联合解析平台依赖，验证包信息、分享结果、iPad 弹出定位、播放锁屏。 |
| 生成器 | build_runner 2.15.1 → 2.16.1、retrofit_generator 10.2.9 → 10.2.11 | 一起核对 analyzer 约束，重新生成并审阅模型/客户端 diff。 |
| SDK/模型 | freezed 3.2.5 → 4.0.1 | 方案核对显示要求 Dart 3.13；先独立升级 CI Flutter 基线，再迁移。 |
| 桥接 | pigeon 26.3.4 → 28.0.0 | 根项目及插件统一版本，Dart/Swift 同步生成；验证播放、事件流、错误序列。 |
| 规则 | flutter_lints 5.0.0 → 6.0.0 | 最后单独处理，避免 lint/格式整理混入行为变更。 |

每批保留独立 diff；先解析、生成、针对性测试，再完整 analyze/test、双平台构建和受影响真机路径回归。认证/存储迁移必须保留历史数据样本。

官方资料：[分页迁移](https://github.com/edsonbueno/infinite_scroll_pagination/blob/master/MIGRATION.md)、[图片缓存](https://pub.dev/packages/cached_network_image/changelog)、[认证](https://pub.dev/packages/local_auth/changelog)、[安全存储](https://pub.dev/packages/flutter_secure_storage/changelog)、[Freezed](https://pub.dev/packages/freezed/changelog)、[Pigeon](https://pub.dev/packages/pigeon/changelog)。
