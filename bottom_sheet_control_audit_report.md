# 底部弹出面板控件一致性审计报告

## 1. 报告信息

| 项目 | 内容 |
|---|---|
| 报告版本 | v1.2 |
| 审计日期 | 2026-08-28 |
| 审计方式 | 源码级静态检查 |
| 当前状态 | 第一阶段高优先级统一已实施，待运行态视觉验收 |
| 后续用途 | 作为分阶段统一设计和回归验收清单 |

## 2. 审计范围

本报告只覆盖之前统一过、带毛玻璃面板和拖拽把手的底部弹出面板：

- 通过 `showGlassSheet` 进入的面板。
- 通过 `showAppActionSheet` 间接进入的面板。
- 面板内部的按钮、输入框、选择器、开关、复选控件、标签、列表行、状态反馈和底部操作区。

明确排除：

- 灯箱组件、`Dialog`、`AlertDialog` 和普通弹窗。
- 播放器内部控制层和播放器手势。
- 浏览器预览、运行态截图和像素级视觉验证。

当前共盘点 36 个业务文件、47 处相关调用。47 处包含公共 action sheet 转发调用、同一文件中的多个面板以及嵌套选择面板。

## 3. 统一基准

### 3.1 面板外壳

基准文件：`lib/shared/glass.dart:154-210`

- `GlassPanel`：毛玻璃、半透明 `sheetBackground`、统一描边。
- 顶部圆角：24px。
- `GlassSheetHandle`：宽 36px、高 4px、圆角 100px。
- 公共层负责顶部和底部 `SafeArea`。
- 遮罩、透明背景、拖拽行为由 `showGlassSheet` 统一处理。

### 3.2 色彩

基准文件：`lib/core/platform/app_theme.dart:7-118`

- 主色：`c.accent`。
- 主文本：`c.text`。
- 次文本：`c.text2`。
- 辅助文本：`c.muted` / `c.muted2`。
- 卡片背景：`c.surface`。
- 描边和分割线：`c.cardBorder` / `c.divider`。
- 危险色：`c.danger`。
- 警告色：`c.warning`。
- 面板背景：`c.sheetBackground`。

### 3.3 公共控件

基准文件：`lib/shared/sheet_controls.dart`、`lib/features/settings/settings_common.dart`

- `SheetHeader`：左对齐标题、用途图标、副标题和右侧操作的统一头部。
- `SheetActionBar`：透明底部操作区，只保留统一内边距，不再覆盖不透明页面背景。
- `sheetInputDecoration`：12px 圆角、`c.surface` 填充、统一内边距、焦点 `c.accent` 边框和错误态 `c.danger` 边框。
- `SheetSwitch` / `SheetSwitchTile`：固定 Material 开关视觉和统一触觉反馈。
- `sheetPrimaryButtonStyle` / `sheetSecondaryButtonStyle`：48px 最小高度、12px 圆角和统一主次色。
- `settingsInputDecoration` 已委托到 `sheetInputDecoration`，设置页和底部面板共享同一输入框令牌。

- `SettingsTile`：标准设置行、标题、辅助文本、点击反馈和触觉反馈。
- `SettingsSwitch`：统一开关颜色、轨道、拇指、描边和触觉反馈。
- `settingsInputDecoration`：12px 输入框圆角、统一填充、内边距和焦点态。
- `settingsCardDecoration`：16px 卡片圆角、统一背景和描边。
- `SettingsSaveButton`：48px 最小高度、12px 圆角、统一保存按钮和加载状态。

## 4. 总体结论

面板外壳已经基本统一，但内部控件仍存在明显的多套实现。最影响整体观感的不是业务内容，而是以下六类结构性差异：

1. 批量面板底部实色操作栏覆盖毛玻璃层次。
2. 开关混用公共 `SettingsSwitch` 和 `SwitchListTile.adaptive`。
3. 输入框混用公共 helper、局部容器和 Material 默认边框。
4. 按钮组件、圆角、颜色、禁用态和布局没有统一来源。
5. 选择列表混用 `ListTile`、`SettingsTile`、自定义行、`ChoiceChip` 和自定义胶囊。
6. 触觉反馈、安全区和语义色的处理路径不一致。

## 5. 高优先级问题

### H1：底部操作栏使用不透明页面背景

涉及文件：

- `lib/features/movies/advanced_filter_sheet.dart:374-411`
- `lib/features/movies/batch_download_sheet.dart:214-247`
- `lib/features/movies/batch_duplicate_nfo_sheet.dart:245-280`
- `lib/features/movies/batch_edit_sheet.dart:351-385`
- `lib/features/movies/batch_merge_sheet.dart:213-253`

当前实现使用：

```dart
decoration: BoxDecoration(
  color: c.bg,
  border: Border(top: BorderSide(color: c.divider)),
)
```

问题：`c.bg` 是页面背景色，而公共 `GlassPanel` 使用 `c.sheetBackground`。因此这些面板底部会出现一条不透明的横向色带，和上方毛玻璃区域形成明显断层。

调整建议：

- 底部操作区保持透明，直接继承面板材质。
- 如需要分隔，仅使用低透明度分割线。
- 统一使用公共按钮容器，不再由每个批量面板单独绘制底栏背景。

验收标准：浅色和深色主题下，操作区与面板主体保持连续的玻璃层次，不出现实色横带。

实施状态：已完成。5 个批量面板已改用 `SheetActionBar`，移除 `color: c.bg` 和顶部结构性分割线。

### H2：开关控件存在平台样式分裂

涉及文件：

- `lib/features/movies/batch_download_sheet.dart:185-209`
- 基准：`lib/features/settings/settings_common.dart:166-187`

`batch_download_sheet.dart` 使用 3 个 `SwitchListTile.adaptive`，而设置、翻译、音频、映射和安全设置主要使用 `SettingsSwitch`。

差异：

- `adaptive` 会根据平台切换尺寸和视觉样式。
- 当前文件未显式指定开关颜色。
- `SwitchListTile` 同时控制整行布局，和普通设置行的内边距、标题基线不同。
- 其他位置通过 `SettingsTile` 或自定义 `Row` 布局，点击区域也不同。

调整建议：将开关本身统一为 `SettingsSwitch`，标题和副标题统一使用 `SheetSettingRow` 或现有 `SettingsTile`。

实施状态：已完成。批量下载面板的 3 个 `SwitchListTile.adaptive` 已改为 `SheetSwitchTile`；`SettingsSwitch` 也复用 `SheetSwitch`。

### H3：危险操作的语义色不完整

涉及文件：

- 公共能力：`lib/core/platform/app_action_sheet.dart:5-39`
- 具体问题：`lib/features/settings/server_selection_page.dart:118-126`

公共 `AppActionSheetAction` 已支持 `destructive`，但“删除服务器”面板直接使用默认 `ListTile`，和“编辑服务器”同色同层级。

调整建议：危险操作统一使用 `c.danger` 图标、标题和点击反馈；警告色仅用于可逆或需要提醒的操作。

实施状态：已完成。服务器操作面板的删除入口已使用 `c.danger` 图标和标题，并补充统一的“服务器操作”面板标题。

## 6. 中优先级问题

### M1：输入框样式分成多套

公共基准：`lib/features/settings/settings_common.dart:192-218`

| 实现 | 源码位置 | 当前差异 |
|---|---|---|
| 高级筛选数字输入 | `advanced_filter_sheet.dart:527-549` | 8px 圆角，没有统一焦点态 |
| 批量下载输入 | `batch_download_sheet.dart:274-318` | 使用默认 `OutlineInputBorder`，边框和圆角依赖主题默认值 |
| 批量编辑搜索 | `batch_edit_sheet.dart:727-745` | 使用默认边框，未复用 helper |
| 翻译配置 | `translation_settings_page.dart:442-510` | 局部 `Container + TextField`，密码框另有一套实现 |
| 映射规则 | `mapping_rules_page.dart:555-651` | 局部边框、内边距和字体定义 |
| 影片编辑 | `movie_editor_sheet.dart:810-845` | 局部输入框，焦点边框未统一 |
| 资源编辑 | `resource_list_page.dart:716-749` | 局部输入框，和设置页 helper 不同 |
| 演员关联编辑 | `actor_association_editor_sheet.dart:184-245` | 创建和编辑状态的背景色、字体和装饰局部定义 |

调整建议：

- 抽取 `SheetInputField`，底层复用 `settingsInputDecoration`。
- 允许 `numeric`、`mono`、`multiline` 等少量语义参数。
- 业务字段可保留等宽字体，但不再重复定义边框和内边距。
- 密码框统一使用同一套可见性按钮和输入容器。

### M2：按钮组件和层级不统一

公共基准：`lib/features/settings/settings_common.dart:261-306`

当前混用：

- `FilledButton`。
- `FilledButton.icon`。
- `OutlinedButton`。
- `OutlinedButton.icon`。
- `ElevatedButton`。
- 顶部 `TextButton`。
- 默认主题按钮和局部 `styleFrom`。

典型差异：

- `SettingsSaveButton` 使用 `c.text/c.bg`，12px 圆角，48px 高度。
- 批量面板多数使用默认按钮样式。
- 扫描进度面板使用 `ElevatedButton`，其他面板主要使用 `FilledButton`。
- DBO 差异面板使用 100px 胶囊圆角。
- 音频提取、演员编辑、映射规则等面板使用全宽按钮，但圆角、padding 和 loading 样式由各自定义。

调整建议：

- `SheetPrimaryButton`：主提交操作。
- `SheetSecondaryButton`：取消、返回、后台运行。
- `SheetDangerButton`：删除、清除、不可逆操作。
- `SheetWarningButton`：合并、覆盖等需要额外提醒的操作。
- 统一高度、圆角、禁用态和加载指示器。

### M3：选择列表缺少统一行组件

涉及代表位置：


- `lib/core/platform/app_action_sheet.dart:26-38`
- `lib/features/db_online/db_online_library_page.dart:171-186`
- `lib/features/movies/movies_page.dart:988-999`
- `lib/features/settings/app_settings_page.dart:220-232`
- `lib/features/settings/player_settings_page.dart:327-339`
- `lib/features/settings/subtitle_settings_page.dart:308-320`
- `lib/features/movie_detail/entity_picker_sheet.dart:820-905`

当前混用：

- 默认 `ListTile`。
- `SettingsTile`。
- 自定义 `Material + InkWell` 行。
- `ChoiceChip`。
- 自定义圆形勾选框和单选图标。

差异包括标题字号、左右内边距、`dense` 行高、选中图标大小、点击水波纹和辅助文本位置。

调整建议：

- 简单单选统一使用 `SheetChoiceRow`。
- 多选统一使用 `SheetCheckboxRow`。
- 破坏性动作使用 `SheetActionRow(destructive: true)`。
- 播放源和颜色选择等特殊对象保留专用组件，但共享颜色、圆角、文字和选中态 token。

### M4：安全区和键盘 inset 规则不统一

公共层：`lib/shared/glass.dart:183-187`

公共 `showGlassSheet` 已处理顶部和底部 `SafeArea`，但业务面板仍混用：

- 默认 `SafeArea`：`add_to_list_sheet.dart:42`、`translation_settings_page.dart:114`、`favorites_page.dart:425`。
- `SafeArea(top: false)`：`db_online_library_page.dart:150`、`movies_page.dart:933`、`resources_sheet.dart:355`。
- 显式 `useSafeArea: true`：`db_online_movie_detail_page.dart:549-553`。
- 表单另行叠加 `MediaQuery.viewInsets.bottom + 22`。

这不一定都会造成运行时重复留白，但源码规则不一致，会增加后续调整时的不可预测性。

调整建议：公共层负责设备安全区；业务层只处理键盘 `viewInsets`，并抽取统一的 `sheetKeyboardPadding`。

### M5：触觉反馈和点击逻辑不统一

已有公共反馈：

- `SettingsTile` 点击时调用 `AppHaptics.selection()`。
- `SettingsSwitch` 通过 `AppHaptics.wrapToggle()` 处理开关反馈。

未统一接入的典型位置：

- `advanced_filter_sheet.dart:472` 的自定义 `GestureDetector`。
- `batch_edit_sheet.dart:921` 的快捷标记。
- `movie_editor_sheet.dart:879` 的选择器卡片。
- `db_online_movie_detail_page.dart:709` 的 `ChoiceChip`。
- 资源标签和部分头像选择项的自定义 `InkWell`。

操作逻辑本身存在合理差异，应按类型保留：

- 单选：点击后立即关闭面板。
- 多选：保持面板打开，通过“完成”提交。
- 复选集合：点击后立即更新状态并保持打开。
- 播放源：点击后留在面板内刷新剧集。
- 表单：填写后通过保存动作提交。
- 进度：允许暂停、后台运行、关闭或重试。

建议统一的是反馈入口和状态过渡，不是强行让所有面板采用同一种关闭逻辑。

## 7. 第一阶段实施清单

### 7.1 已统一的面板标题

以下底部面板已接入 `SheetHeader`，标题统一左对齐并补充用途图标：

- 高级筛选、批量下载、重复 NFO、批量编辑、批量合并。
- 音频提取、影片编辑、在线资源、DB Online 元数据、获取字幕。
- 实体选择、资源编辑、资源合并、映射规则、演员关联编辑与同步、头像选择。
- 媒体库扫描、资源扫描、服务器操作、集合操作。
- 语言/主题/播放器/字幕/角标设置选择、翻译模型选择、Modal Token 编辑。
- 排序/更新状态等通用 action sheet。

标题与主体之间原有的结构性 `Divider` 已删除；资源列表、字幕列表、设置项之间仍保留必要的内容分组线。

### 7.2 输入框迁移结果

已优先迁移高级筛选、批量下载、批量编辑系列搜索、影片编辑、资源编辑、映射规则、实体选择、资源合并和演员关联编辑等表单。保留番号、Token、映射原值等字段的等宽字体语义，但边框、填充、圆角和焦点态统一由公共 decoration 提供。

### 7.3 播放源面板高度

`lib/features/movie_detail/resources_sheet.dart` 已移除屏幕高度比例固定值和内容区强制 `Expanded`。面板现在按标题、筛选器、状态提示和资源列表的实际内容自适应；资源较多时仅通过最大高度约束进入列表滚动。底部安全区继续由 `showGlassSheet` 的统一 `SafeArea` 处理，同时保留下滑关闭面板的能力。

### 7.4 本阶段未覆盖

- 灯箱、`Dialog`、`AlertDialog` 和播放器内部浮层，按需求继续排除。
- 运行态截图、浏览器预览和像素级视觉验收，按需求未调用浏览器。
- 选择列表行、复杂标签卡片及进度面板内部统计卡的细节进一步收敛，留作下一阶段，不影响本阶段标题/输入框/操作栏统一。

## 8. 验证记录

- `dart format`：已执行，涉及源码格式化通过。
- `flutter analyze --no-pub`：通过，`No issues found`。
- `flutter test --no-pub`：通过，`All tests passed!`。

## 9. 下一阶段回归入口

新增底部面板必须通过 `showGlassSheet`，标题必须使用 `SheetHeader`，输入框必须使用 `sheetInputDecoration` 或 `settingsInputDecoration`，底部操作区必须使用 `SheetActionBar`。新增语义色时优先使用 `AppColors`，禁止在业务面板中重新定义圆角、边框和主题色。

## 7. 低优先级问题

### L1：状态提示透明度缺少 token

当前出现的透明度包括：

- 背景 `0.08`、`0.10`、`0.12`、`0.15`、`0.18`。
- 边框 `0.20`、`0.28`、`0.35`、`0.40`、`0.45`、`0.50`、`0.55`、`0.60`。

代表位置：

- `audio_extraction_sheet.dart:208-210`
- `resource_scan_progress_sheet.dart:204-207`
- `batch_merge_sheet.dart:150-188`
- `dbo_diff_sheet.dart:638-645`
- `actor_association_sync_sheet.dart:822-826`

错误、警告、成功和选中状态允许使用不同语义色，但建议抽取 `SheetStatusColors` 或统一 token，避免后续出现同语义不同视觉重量。

### L2：语义色和硬编码色未集中管理

涉及位置：

- `resources_sheet.dart:799`：已下载绿色边框。
- `resources_sheet.dart:872-896`：资源标签的多组硬编码颜色。
- `dbo_diff_sheet.dart:850-854`：性别蓝色、粉色。
- `translation_settings_page.dart:349-369`：成功结果使用 `AppHues.mint`。

这些不应全部替换为主色，因为它们表达了资源状态、媒体标签或内容属性。但应集中定义，并在暗色主题下检查对比度。

## 8. 分组调整路线

### 阶段 0：建立控件规范和 token

状态：`[ ] 未开始`

目标：先冻结规则，避免每个面板继续各自扩展。

建议产物：

- `SheetPrimaryButton` / `SheetSecondaryButton` / `SheetDangerButton`。
- `SheetInputField`。
- `SheetChoiceRow` / `SheetCheckboxRow`。
- `SheetStatusBox`。
- `SheetChip`。
- 统一圆角、间距、控件高度和状态透明度 token。

验收：新增面板只需要组合公共控件，不再直接定义按钮和输入框外观。

### 阶段 1：修复高优先级视觉断层

状态：`[ ] 未开始`

任务：

- [ ] 移除 5 个批量面板的 `c.bg` 底部操作栏背景。
- [ ] 替换 `batch_download_sheet.dart` 中的 3 个 `SwitchListTile.adaptive`。
- [ ] 修复服务器删除操作的危险色。

验收：面板外壳、底部操作区和设置开关在浅色/深色主题下保持同一风格。

### 阶段 2：统一表单控件

状态：`[ ] 未开始`

任务：

- [ ] 统一高级筛选、批量下载、批量编辑输入框。
- [ ] 统一演员、影片、资源、映射、翻译表单输入框。
- [ ] 保留数字字段和代码字段的等宽字体语义。
- [ ] 统一键盘弹出时的底部 inset。

验收：输入框圆角、背景、描边、焦点态、图标位置和内边距一致。

### 阶段 3：统一按钮和选择控件

状态：`[ ] 未开始`

任务：

- [ ] 将批量面板按钮迁移到统一主次按钮。
- [ ] 统一取消、保存、应用、删除、合并的语义色。
- [ ] 将普通单选列表迁移到统一选择行。
- [ ] 将多选实体列表迁移到统一复选行。
- [ ] 保留播放源、颜色、头像等专用布局，但复用 token。

验收：同一类操作在不同面板具有一致的高度、圆角、颜色、选中态和点击反馈。

### 阶段 4：统一反馈和语义状态

状态：`[ ] 未开始`

任务：

- [ ] 为自定义 `GestureDetector` / `InkWell` 接入统一触觉反馈。
- [ ] 抽取错误、警告、成功状态容器。
- [ ] 集中管理资源状态色和媒体标签色。
- [ ] 清理不必要的业务层 `SafeArea`。

验收：相同语义的状态提示和交互反馈具有相同视觉重量与触觉行为。

### 阶段 5：验证

状态：`[ ] 未开始`

建议执行：

- [ ] `flutter analyze`。
- [ ] 全量 `flutter test`。
- [ ] 检查浅色和深色主题。
- [ ] 检查键盘弹出、底部安全区和长列表滚动。
- [ ] 检查单选、多选、提交、取消、加载、失败、重试和后台运行逻辑。
- [ ] 新增面板静态检查规则或代码评审清单，防止重新出现局部样式。

## 9. 文件调整追踪表

以下为本次覆盖的全部业务文件。文件可以在后续阶段逐项标记：`未开始`、`进行中`、`已完成`、`无需调整`。

### 选择 / 排序 / 操作面板

- [ ] `lib/core/platform/app_action_sheet.dart`
- [ ] `lib/features/libraries/libraries_page.dart`
- [ ] `lib/features/lists/add_to_list_sheet.dart`
- [ ] `lib/features/lists/list_detail_page.dart`
- [ ] `lib/features/favorites/favorites_page.dart`
- [ ] `lib/features/movies/movies_page.dart`
- [ ] `lib/features/db_online/db_online_library_page.dart`
- [ ] `lib/features/settings/app_settings_page.dart`
- [ ] `lib/features/settings/player_settings_page.dart`
- [ ] `lib/features/settings/subtitle_settings_page.dart`
- [ ] `lib/features/settings/badge_position_page.dart`
- [ ] `lib/features/settings/server_selection_page.dart`
- [ ] `lib/features/security/security_settings_page.dart`
- [ ] `lib/features/movie_detail/entity_picker_sheet.dart`
- [ ] `lib/features/movie_detail/resources_sheet.dart`
- [ ] `lib/features/movies/batch_edit_sheet.dart`
- [ ] `lib/features/actor_associations/widgets/actor_association_sync_sheet.dart`
- [ ] `lib/features/db_online/db_online_movie_detail_page.dart`

### 表单 / 编辑面板

- [ ] `lib/features/actors/actor_management_page.dart`
- [ ] `lib/features/audio/audio_management_page.dart`
- [ ] `lib/features/actor_associations/widgets/actor_association_editor_sheet.dart`
- [ ] `lib/features/movie_detail/audio_extraction_sheet.dart`
- [ ] `lib/features/mappings/mapping_rules_page.dart`
- [ ] `lib/features/movie_detail/movie_editor_sheet.dart`
- [ ] `lib/features/resources/resource_list_page.dart`
- [ ] `lib/features/translation/modal_transcription_settings_page.dart`
- [ ] `lib/features/translation/translation_settings_page.dart`

### 批量 / 差异处理面板

- [ ] `lib/features/movies/advanced_filter_sheet.dart`
- [ ] `lib/features/movies/batch_download_sheet.dart`
- [ ] `lib/features/movies/batch_duplicate_nfo_sheet.dart`
- [ ] `lib/features/movies/batch_merge_sheet.dart`
- [ ] `lib/features/resources/entity_merge_sheet.dart`
- [ ] `lib/features/movie_detail/dbo_diff_sheet.dart`

### 进度 / 资源浏览面板

- [ ] `lib/features/libraries/scan_progress_sheet.dart`
- [ ] `lib/features/movies/resource_scan_progress_sheet.dart`
- [ ] `lib/features/movie_detail/thunder_subtitle_sheet.dart`

## 10. 设计决策记录

以下差异暂不视为需要强行统一：

- 播放源：横向 `ChoiceChip` 适合快速切换播放源。
- 字幕颜色：圆形色样比普通列表行更符合颜色选择语义。
- 头像选择：网格布局适合图像候选比较。
- DBO 元数据差异：增删、替换需要保留不同语义色。
- 资源标签：格式、来源、字幕、无码等内容标签可使用不同颜色，但颜色应集中定义。
- 单选立即关闭、多选点击完成、播放源留在面板内刷新，属于不同操作模型，不应为了视觉统一而强行改成同一逻辑。

## 11. 当前限制

本报告来自源码级静态检查，没有运行浏览器、没有截图，也没有在不同设备上实际渲染。因此以下内容需要在实施阶段验证：

- Material 默认主题在不同平台的最终按钮、列表和输入框像素表现。
- 深色主题下硬编码语义色的实际对比度。
- SafeArea 嵌套是否在所有设备上产生额外留白。
- 键盘弹出、横屏和小屏设备上的面板高度与滚动行为。

## 12. 变更记录

| 日期 | 版本 | 变更 |
|---|---|---|
| 2026-08-28 | v1.0 | 完成 36 个业务文件、47 处调用的源码级控件一致性审计，建立分组、优先级和阶段性调整清单。 |
