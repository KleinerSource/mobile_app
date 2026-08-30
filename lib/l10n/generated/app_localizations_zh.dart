// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppL10nZh extends AppL10n {
  AppL10nZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'Oh-My-Media';

  @override
  String get tabHome => '首页';

  @override
  String get tabLibrary => '影片库';

  @override
  String get tabSearch => '搜索';

  @override
  String get tabYou => '我的';

  @override
  String get tabFiles => '文件管理';

  @override
  String get greetingMorning => '早上好';

  @override
  String get greetingAfternoon => '下午好';

  @override
  String get greetingEvening => '晚上好';

  @override
  String get greetingNight => '夜深了';

  @override
  String get homePickupTitle => '继续观看';

  @override
  String get homeFreshTitle => '新加入的影片';

  @override
  String get homeYourLibraries => '我的媒体库';

  @override
  String get homeSeeAll => '查看全部';

  @override
  String get homeResume => '继续播放';

  @override
  String homeMinutesLeft(int n) {
    return '$n 分钟剩余';
  }

  @override
  String get libraryTitle => '影片库';

  @override
  String libraryCount(int n) {
    return '$n 部影片';
  }

  @override
  String get libraryCountSuffix => '部影片';

  @override
  String get filterAll => '全部';

  @override
  String get filterRecent => '最近';

  @override
  String get filterRating => '评分';

  @override
  String get filterTopRated => '高分';

  @override
  String get filterUnwatched => '未观看';

  @override
  String get viewGrid => '网格';

  @override
  String get viewList => '列表';

  @override
  String get searchHintAll => '搜索片名 / 演员 / 标签';

  @override
  String resultsSortedBy(int n, String sort) {
    return '$n 个结果 · 按 $sort 排序';
  }

  @override
  String sortedByOnly(String sort) {
    return '按 $sort 排序';
  }

  @override
  String get loadFailed => '加载失败';

  @override
  String get loadFailedRetry => '加载失败，点击重试';

  @override
  String get noResultFound => '没有找到符合条件的影片';

  @override
  String get watchedDone => '已看完';

  @override
  String get sortByCreatedAt => '创建时间';

  @override
  String get sortByRating => '评分';

  @override
  String get sortByTitle => '片名';

  @override
  String get sortByYear => '年份';

  @override
  String get sortByReleaseDate => '上映日期';

  @override
  String get searchHint2 => '影片标题 / 演员 / 番号 / 标签';

  @override
  String searchFailed(String error) {
    return '搜索失败: $error';
  }

  @override
  String get favoritesTitle => '收藏夹';

  @override
  String favoritesSubtitle(int n, int l) {
    return '已收藏 $n 部 · 跨 $l 个集合';
  }

  @override
  String get statSaved => '收藏';

  @override
  String get statWatched => '已看';

  @override
  String get statHours => '小时';

  @override
  String get yourLists => '我的集合';

  @override
  String get newList => '新建集合';

  @override
  String get allFavorites => '全部收藏';

  @override
  String get upNext => '即将观看';

  @override
  String get watchlist => '观看列表';

  @override
  String selectedN(int n) {
    return '已选 $n';
  }

  @override
  String get remove => '移除';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确定';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get edit => '编辑';

  @override
  String get back => '返回';

  @override
  String get searchTitle => '搜索';

  @override
  String get searchFind => '查找内容';

  @override
  String get searchEmpty => '输入关键词开始搜索';

  @override
  String get searchNoResult => '没有找到相关内容';

  @override
  String get searchModeTitle => '影片';

  @override
  String get searchModeList => '列表搜索';

  @override
  String get searchModeActorSearch => '演员搜索';

  @override
  String get searchModeSeries => '系列搜索';

  @override
  String get searchModeNum => '番号';

  @override
  String get searchModeActor => '演员';

  @override
  String get searchModeFilename => '文件名';

  @override
  String get searchPlaceholderTitle => '搜索影片标题...';

  @override
  String get searchPlaceholderList => '搜索影片标题、番号、演员';

  @override
  String get searchPlaceholderSeries => '搜索系列名称';

  @override
  String get searchPlaceholderNum => '搜索番号...';

  @override
  String get searchPlaceholderActor => '搜索演员...';

  @override
  String get searchPlaceholderFilename => '搜索文件名...';

  @override
  String get detailPlay => '播放';

  @override
  String get detailAddList => '+ 集合';

  @override
  String get detailTrailer => '预告片';

  @override
  String get detailCast => '演员';

  @override
  String get detailDetails => '详情';

  @override
  String get detailFilmography => '作品集';

  @override
  String get detailFavorited => '已收藏';

  @override
  String get detailUnfavorited => '已移除收藏';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsPreferences => '偏好设置';

  @override
  String get settingsGroupServer => '服务器';

  @override
  String get settingsGroupLibrary => '媒体库';

  @override
  String get settingsGroupSystem => '系统配置';

  @override
  String get settingsGroupMappings => '映射规则';

  @override
  String get settingsGroupTools => '工具';

  @override
  String get settingsGroupPrivacy => '隐私';

  @override
  String get settingsGroupAbout => '关于';

  @override
  String get settingsServerSettings => '服务器设置';

  @override
  String get settingsServerSettingsSub => 'OMM / DBO 平台配置';

  @override
  String get settingsAppSettings => '应用设置';

  @override
  String get settingsAppSettingsSub => '语言 / 隐私 / 显示偏好';

  @override
  String get settingsTheme => '主题';

  @override
  String get settingsThemeSub => '界面亮色 / 暗色风格';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '亮色';

  @override
  String get themeDark => '暗色';

  @override
  String get settingsBadgePositions => '封面角标位置';

  @override
  String get settingsBadgePositionsSub => '评分 / 字幕 / 破解 / 清晰度 / 新资源';

  @override
  String get badgeRating => '评分';

  @override
  String get badgeSubtitle => '字幕';

  @override
  String get badgeCrack => '破解';

  @override
  String get badgeResolution => '清晰度';

  @override
  String get badgeNewResources => '新资源';

  @override
  String get badgeHidden => '已隐藏';

  @override
  String get previewTitle => '预览';

  @override
  String get badgeOffsetTitle => '位置微调';

  @override
  String get badgeOffsetHorizontal => '左右';

  @override
  String get badgeOffsetVertical => '上下';

  @override
  String get cornerTopLeft => '左上';

  @override
  String get cornerTopRight => '右上';

  @override
  String get cornerBottomLeft => '左下';

  @override
  String get cornerBottomRight => '右下';

  @override
  String get settingsServerUrl => '服务器地址';

  @override
  String get settingsServerNotConfigured => '未配置';

  @override
  String get settingsLibraries => '媒体库管理';

  @override
  String get settingsLibrariesSub => '添加 / 编辑 / 扫描';

  @override
  String get libraryEditorName => '名称';

  @override
  String get libraryEditorDirectories => '目录';

  @override
  String get settingsActors => '演员管理';

  @override
  String get settingsActorsSub => '演员信息、类型与影片关系';

  @override
  String get settingsGenres => '分类管理';

  @override
  String get settingsTags => '标签管理';

  @override
  String get settingsSeries => '系列管理';

  @override
  String get settingsTranslation => 'AI 翻译配置';

  @override
  String get settingsTranslationSub => 'ChatGPT API · 自动翻译标题/简介';

  @override
  String get settingsMappingTags => '标签映射';

  @override
  String get settingsMappingGenres => '分类映射';

  @override
  String get settingsMappingSeries => '系列映射';

  @override
  String get settingsMappingSub => '重命名 / 删除规则';

  @override
  String get settingsActorAssociations => '演员关联';

  @override
  String get settingsActorAssociationsSub => '标准名 + 别名维护, 支持同步演员关联';

  @override
  String get settingsDbo => 'DB Online 数据源';

  @override
  String get settingsDboSub => '影片下载 / 同步演员关联';

  @override
  String get settingsExtensions => '视频扩展名';

  @override
  String get settingsExtensionsSub => '扫描时识别的文件后缀';

  @override
  String get settingsPrivacyShield => '隐私遮罩';

  @override
  String get settingsPrivacyShieldSub => '后台切换时盖住预览图';

  @override
  String get settingsShakePrivacy => '摇一摇切换隐私模式';

  @override
  String get settingsShakePrivacySub => '摇动设备快速开启或关闭隐私模式';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsLanguageSub => '界面显示语言';

  @override
  String get settingsVersion => '版本';

  @override
  String get settingsLogout => '退出登录';

  @override
  String get playerEnginePickerTitle => '选择播放器';

  @override
  String get playerEnginePickerSubtitle => '仅用于本次播放，不会修改默认设置';

  @override
  String get playerEnginePickerDefaultBadge => '默认';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageZh => '简体中文';

  @override
  String get languageEn => 'English';

  @override
  String get privacyLockedTitle => '已锁定';

  @override
  String get privacyMode => '隐私模式';

  @override
  String get fileEyebrow => '文件';

  @override
  String get fileListTitle => '文件列表';

  @override
  String get fileSelectTargetDirectory => '选择目标目录';

  @override
  String get fileSelectThisDirectory => '选择此目录';

  @override
  String get fileBatchActions => '批量操作';

  @override
  String get fileMoreActions => '更多';

  @override
  String get fileForceRefresh => '强制刷新';

  @override
  String get fileCreateDirectory => '新建文件夹';

  @override
  String get fileUpload => '上传文件';

  @override
  String get fileSelect => '选择';

  @override
  String get fileShowHidden => '显示隐藏文件';

  @override
  String get fileSortName => '名称';

  @override
  String get fileSortDate => '日期';

  @override
  String get fileSortSize => '大小';

  @override
  String get fileSortCategory => '类别';

  @override
  String fileSortBy(String label) {
    return '$label排序';
  }

  @override
  String fileSortByAsc(String label) {
    return '$label排序 ↑';
  }

  @override
  String fileSortByDesc(String label) {
    return '$label排序 ↓';
  }

  @override
  String get fileExitSelection => '退出选择';

  @override
  String get fileCancelPicker => '取消选择';

  @override
  String get fileBackToParent => '返回上一级';

  @override
  String get fileBackToServers => '返回服务器选择';

  @override
  String get fileRootDirectory => '根目录';

  @override
  String get fileEmptyDirectory => '此目录为空';

  @override
  String get fileFavoritesSection => '收藏';

  @override
  String get fileFavoritesEmpty => '还没有收藏的文件或目录，可在文件列表的菜单中收藏常用内容';

  @override
  String get fileFavoriteDirectoriesSection => '收藏的目录';

  @override
  String get fileAllFilesSection => '全部文件';

  @override
  String get fileUnfavorite => '取消收藏';

  @override
  String get fileFavorite => '收藏';

  @override
  String fileFavoriteAdded(String name) {
    return '已收藏“$name”';
  }

  @override
  String fileFavoriteRemoved(String name) {
    return '已取消收藏“$name”';
  }

  @override
  String get fileEntryActions => '文件操作';

  @override
  String get fileDetails => '详情';

  @override
  String get fileRename => '重命名';

  @override
  String get fileMove => '移动';

  @override
  String get fileSelectAll => '全选';

  @override
  String get fileClearSelection => '清空';

  @override
  String get fileDeleteSelected => '删除所选';

  @override
  String get fileFolderNameLabel => '文件夹名称';

  @override
  String get fileCreateDirectoryFailed => '创建目录失败';

  @override
  String get fileLocalPathLabel => '本地文件路径';

  @override
  String get fileLocalFileMissing => '本地文件不存在';

  @override
  String get fileUploadFailed => '上传失败';

  @override
  String get fileUploadDone => '上传完成';

  @override
  String get fileUploadCanceled => '上传已取消';

  @override
  String get fileNewNameLabel => '新名称';

  @override
  String get fileRenameFailed => '重命名失败';

  @override
  String get fileMoveFailed => '移动失败';

  @override
  String get fileInvalidMoveTarget => '不能将目录移动到自身或其子目录';

  @override
  String get fileBatchMoveFailed => '批量移动失败';

  @override
  String get fileTargetExists => '目标已存在';

  @override
  String fileBatchOverwritePrompt(int count, String action) {
    return '$count 个目标已存在，是否覆盖后继续$action？';
  }

  @override
  String fileOverwritePrompt(String path) {
    return '是否覆盖“$path”？';
  }

  @override
  String get fileOverwrite => '覆盖';

  @override
  String get fileBatchRenameFailed => '批量重命名失败';

  @override
  String get fileNoRenameChanges => '没有可应用的名称变化';

  @override
  String get fileRenameDuplicatePreview => '预览结果包含重复名称，请调整重命名规则';

  @override
  String get fileRenameCollision => '不能批量重命名为其他已选项的现有名称';

  @override
  String get fileBatchRenameTitle => '批量重命名';

  @override
  String get fileBatchRenameSubtitle => '选择规则并查看实时预览';

  @override
  String get fileRenameMode => '重命名模式';

  @override
  String get fileRenameModeReplace => '替换文本';

  @override
  String get fileRenameModeAdd => '添加文本';

  @override
  String get fileRenameSearchLabel => '查询';

  @override
  String get fileRenameReplaceLabel => '替换为';

  @override
  String get fileRenameAddTextLabel => '添加文本';

  @override
  String get fileRenameAddPosition => '添加位置';

  @override
  String get fileRenameAddBefore => '在名字之前';

  @override
  String get fileRenameAddAfter => '在名字之后';

  @override
  String get filePreviewSection => '预览';

  @override
  String get fileApply => '应用';

  @override
  String get fileDeleteConfirmTitle => '确认删除？';

  @override
  String fileDeleteConfirmBody(String name) {
    return '将从远程文件来源删除“$name”，此操作不可撤销。';
  }

  @override
  String get fileDeleteFailed => '删除失败';

  @override
  String get fileBatchDeleteConfirmTitle => '确认批量删除？';

  @override
  String fileBatchDeleteConfirmBody(int n) {
    return '将从远程文件来源删除已选择的 $n 项，此操作不可撤销。';
  }

  @override
  String get fileBatchDeleteFailed => '批量删除失败';

  @override
  String get fileDirectoryDetails => '目录详情';

  @override
  String get fileFileDetails => '文件详情';

  @override
  String filePathLabel(String path) {
    return '路径：$path';
  }

  @override
  String fileSizeLabel(String size) {
    return '大小：$size';
  }

  @override
  String fileTypeLabel(String type) {
    return '类型：$type';
  }

  @override
  String fileModifiedAtLabel(String time) {
    return '修改时间：$time';
  }

  @override
  String get fileWebDavDirectUrlMissing => '服务器未提供 HTTP 直连地址，已停止播放（不会回退到本机代理）';

  @override
  String fileVideoPreviewFailed(String error) {
    return '视频预览失败：$error';
  }

  @override
  String fileAudioPreviewFailed(String error) {
    return '音频预览失败：$error';
  }

  @override
  String fileImagePreviewFailed(String error) {
    return '图片预览失败：$error';
  }

  @override
  String fileTextPreviewFailed(String error) {
    return '文本预览失败：$error';
  }

  @override
  String get fileRetry => '重试';

  @override
  String get fileUploadAction => '上传';

  @override
  String get fileFileOperation => '文件操作';

  @override
  String fileOperationRunning(String action) {
    return '$action进行中';
  }

  @override
  String fileOperationCompleted(String action) {
    return '$action完成';
  }

  @override
  String fileOperationCanceled(String action) {
    return '$action已取消';
  }

  @override
  String fileOperationFailed(String action) {
    return '$action失败';
  }

  @override
  String fileOperationPending(String action) {
    return '$action等待中';
  }

  @override
  String get filePlaybackProgress => '播放进度';

  @override
  String get fileNotFileServer => '当前服务器不是文件服务器';

  @override
  String get fileChooseFileServer => '选择文件服务器';

  @override
  String get fileNoAvailableSource => '当前服务器没有可用的文件来源';

  @override
  String get fileManageServers => '管理服务器';

  @override
  String get settingsGroupGeneral => '通用';

  @override
  String get settingsGroupFileManager => '文件管理器';

  @override
  String get settingsGroupPlayer => '播放器';

  @override
  String get settingsSecurity => '安全设置';

  @override
  String get settingsSecuritySub => '面容/指纹、进入密码、手势密码';

  @override
  String get settingsPosterBadges => '海报角标显示';

  @override
  String get settingsPosterBadgesSub => '编码 / HDR / STRM / 字幕 / 破解 / HD';

  @override
  String get settingsPlayerSettings => '播放器设置';

  @override
  String get settingsPlayerSettingsSub => '播放进度 / 屏幕方向 / OSD / 播放按钮 / 手势反馈';

  @override
  String get settingsSubtitleSettings => '字幕设置';

  @override
  String get settingsSubtitleSettingsSub => '记忆选择 / 字体 / 颜色 / 描边 / 阴影';

  @override
  String get settingsCacheManagement => '缓存管理';

  @override
  String get settingsCacheManagementSub => '磁盘缓存额度 / 缓存分类 / 一键清理';

  @override
  String get settingsHapticIntensity => '震动反馈强度';

  @override
  String settingsHapticCurrent(String label) {
    return '当前：$label';
  }

  @override
  String get settingsImagePreview => '图片预览';

  @override
  String get settingsImagePreviewSub => '在文件列表中显示图片缩略图';

  @override
  String get settingsMoveStartLocation => '移动文件起始位置';

  @override
  String get settingsMoveStartCurrentRoot => '当前：根目录';

  @override
  String get settingsMoveStartCurrentHere => '当前：所在目录';

  @override
  String get settingsMoveStartHere => '当前所在目录';

  @override
  String get settingsMoveStartRootSub => '移动文件时每次从根目录开始选择目标';

  @override
  String get settingsMoveStartHereSub => '移动文件时从当前所在目录开始选择目标';

  @override
  String fileSelectedItems(int n) {
    return '已选 $n 项';
  }

  @override
  String get playerShuffleOn => '开启随机播放';

  @override
  String get playerShuffleOff => '关闭随机播放';

  @override
  String get playerRepeatOff => '循环：关闭';

  @override
  String get playerRepeatOne => '循环：单曲';

  @override
  String get playerRepeatAll => '循环：列表';
}
