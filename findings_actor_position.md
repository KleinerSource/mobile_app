# mobile_app 演员管理列表位置修复发现

## 已确认

- `mobile_app` 是 Flutter 客户端；演员管理入口为 `lib/features/actors/actor_management_page.dart`。
- 系列、分类、标签使用通用资源列表页，入口路径为 `lib/features/resources/resource_list_page.dart`。
- 演员同步相关代码位于 `lib/features/actor_associations/`，同步选择弹层为 `widgets/actor_association_sync_sheet.dart`。
- `ResourceListPage` 已有完整的滚动位置保留：持有 `_scrollController`，编辑成功时把当前 offset 传给 `_reload(preserveScrollOffset: ...)`，请求完成后在下一帧 clamp 并 `jumpTo` 恢复。
- `ActorManagementPage` 当前只有 `PagingController`，没有自己的 `ScrollController`、待恢复 offset 或 `_reload` 的位置参数；编辑保存和删除完成后直接 `_refresh()`，这与系列/分类页的实现不一致。
- 演员管理的编辑器保存关联名称后也走 `_refresh()`；因此演员数据编辑/关联同步完成后的刷新会丢失滚动位置。
- `PersonDetailPage._syncActor` 在同步弹层成功后调用父页 `onUpdated`，演员页原先传入 `_refresh`；修复通过闭包传入 `preserveScroll: true`，覆盖用户描述的实际链路。

## 待确认

- 演员页面使用的分页列表组件是否接受并正确绑定 `ScrollController`。
- 是否需要单独给同步弹层增加回调，还是现有演员编辑保存链路已覆盖用户场景。

## 验证

- 新增 widget 回归测试用内存 `Dio` 模拟演员列表、详情影片列表、同步预览和应用接口，验证同步后返回演员管理列表的 offset 保持不变。
- 该回归测试已通过。
