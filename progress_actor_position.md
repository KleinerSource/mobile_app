# mobile_app 演员管理列表位置修复进度

## 2026-08-18

- 已确认本次任务与既有 Jetsam 修复是不同问题；未改动既有规划文件和代码。
- 已通过 CodeGraph 初步排除 `frontend_new` Web 端为本次目标，转向 `mobile_app` Flutter 客户端。
- 已定位演员管理、演员关联同步、通用资源列表三个源码区域，正在读取具体状态管理和刷新回调。
- 已确认根因方向：`ResourceListPage` 编辑后保存 offset 并在分页首批数据到达后恢复；`ActorManagementPage` 缺少这套 controller/offset 逻辑，保存关联或演员资料后的 `_refresh()` 会使列表回到顶部。
- 已完成首轮实现：演员页新增独立 `ScrollController`、待恢复 offset 和分页请求完成后的下一帧恢复；编辑保存及 `PersonDetailPage` 同步回调改为保留位置刷新，搜索/排序重载仍不传 offset。
- 已对修改后的演员页面运行 `dart format`，格式化通过。
- `flutter analyze lib/features/actors/actor_management_page.dart` 通过，无静态问题。
- 已新增 `test/features/actor_management_scroll_test.dart`，覆盖“滚动演员列表 → 进入详情 → 同步演员关联 → 返回列表”的真实页面链路；定向测试通过。
- 演员页面与回归测试已再次格式化；针对两者的 `flutter analyze` 通过，无问题。
