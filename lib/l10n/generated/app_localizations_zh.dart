// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppL10nZh extends AppL10n {
  AppL10nZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'Oh My Media';

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
    return '$n 已选';
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
  String get more => '更多';

  @override
  String get close => '关闭';

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
  String get settingsServerSettingsSub => '媒体库设置';

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
  String get settingsGenres => '类型管理';

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
  String get settingsMappingGenres => '类型映射';

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
  String get fileOpenAsText => '以文本方式打开';

  @override
  String get fileTextEdit => '编辑';

  @override
  String get fileTextSave => '保存';

  @override
  String get fileTextSaving => '保存中...';

  @override
  String get fileTextSaveSuccess => '保存成功';

  @override
  String fileTextSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get fileTextUnsavedTitle => '未保存修改';

  @override
  String get fileTextUnsavedMessage => '有未保存的修改，是否保存后离开？';

  @override
  String get fileTextDiscard => '放弃修改';

  @override
  String get fileTextSaveAndLeave => '保存并离开';

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
  String get settingsPerformanceMonitor => '性能监视器';

  @override
  String get settingsPerformanceMonitorSub => '显示 FPS、应用 CPU 和 RAM 使用量';

  @override
  String get settingsHapticIntensity => '震动反馈强度';

  @override
  String get settingsServerSelectionShowUsername => '连接页显示用户名';

  @override
  String get settingsServerSelectionShowUsernameSub =>
      '使用 Emby/Jellyfin/FNOS 登录用户名，否则显示服务器名称';

  @override
  String get settingsServerSelectionShowAvatar => '连接页显示用户头像';

  @override
  String get settingsServerSelectionShowAvatarSub =>
      '使用 Emby/Jellyfin 登录用户头像，否则显示服务器头像或 Logo';

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

  @override
  String get playerLyricsTitle => '歌词';

  @override
  String get playerLyricsUnavailable => '暂无歌词';

  @override
  String get playerDjDeck => 'DJ 唱盘';

  @override
  String get playerDjDeckA => 'DECK A';

  @override
  String get playerDjPlaying => '播放中';

  @override
  String get playerDjPaused => '已暂停';

  @override
  String get playerDjGestureHint => '点按播放或暂停，旋拧唱片定位';

  @override
  String get playerDjPitch => '速度';

  @override
  String get playerClose => '关闭';

  @override
  String get commonRetry => '重试';

  @override
  String get commonNoData => '暂无数据';

  @override
  String get commonSelectAll => '全选';

  @override
  String get commonClearSelection => '清空';

  @override
  String get commonExitSelection => '退出多选';

  @override
  String get paginationNoMore => '没有更多内容';

  @override
  String get paginationLoadFailedRetry => '加载更多失败，点击重试';

  @override
  String get posterOnlinePlay => '在线播放';

  @override
  String get movieCardSubExternal => '外挂字幕';

  @override
  String get movieCardSubAi => 'AI 字幕';

  @override
  String get movieCardSubMuxedTrack => '内嵌字幕轨道';

  @override
  String get movieCardSubFilename => '内嵌字幕';

  @override
  String movieCardSubStack(int n) {
    return '字幕 ×$n（点按展开）';
  }

  @override
  String get movieCardSubChinese => '中字';

  @override
  String get movieCardRestricted => '受限影片';

  @override
  String get movieCardUntitledTitle => '未命名影片';

  @override
  String get movieCardUntitledCode => '未命名番号';

  @override
  String get movieCardNoMeta => '暂无信息';

  @override
  String get movieCardCrack => '破解 / 无码';

  @override
  String get statusIdle => '准备中';

  @override
  String get statusPending => '排队中';

  @override
  String get statusRunning => '进行中';

  @override
  String get statusPaused => '已暂停';

  @override
  String get statusCompleted => '已完成';

  @override
  String get statusSkipped => '已跳过';

  @override
  String get statusCanceled => '已取消';

  @override
  String get statusFailed => '失败';

  @override
  String get statusUnknown => '未知';

  @override
  String get commonClearInput => '清空';

  @override
  String get securityVerifyIncomplete => '验证未完成，请重试或使用其他解锁方式';

  @override
  String get securityPinIncorrect => '数字密码不正确';

  @override
  String get securityPatternIncorrect => '手势密码不正确';

  @override
  String get securityAppLocked => '应用已锁定';

  @override
  String get securityUnlockPrompt => '验证身份后继续使用 Oh My Media';

  @override
  String get securityBiometricUnlock => '使用面容/指纹解锁';

  @override
  String get securityVerifying => '验证中…';

  @override
  String get securityPasswordUnlock => '使用密码/滑动解锁';

  @override
  String get securityPinCode => '数字密码';

  @override
  String get securitySwipeUnlock => '滑动解锁';

  @override
  String get securityUnavailable => '安全验证不可用，请重试';

  @override
  String get securityBiometricReason => '请验证身份以进入 Oh My Media';

  @override
  String get accessControlTitle => '访问控制';

  @override
  String get badgeCodec => '角标编码';

  @override
  String get cacheCategoryMusic => '音乐';

  @override
  String get commonAdd => '添加';

  @override
  String get commonLoading => '读取中…';

  @override
  String get commonReadFailed => '读取失败';

  @override
  String get commonSaveSettings => '保存设置';

  @override
  String get commonSaving => '保存中...';

  @override
  String get commonUnknown => '未知';

  @override
  String get dbOnlineAscending => '升序';

  @override
  String get dbOnlineAutoLoadMoreHint => '滚动到底部自动加载更多。';

  @override
  String get dbOnlineBackendConfigSubtitle => '配置 DB Online 后端';

  @override
  String get dbOnlineBackendConfigTitle => 'DB Online 后端';

  @override
  String get dbOnlineBadgeSubtitle => 'DB Online 数据';

  @override
  String get dbOnlineCategoryAnime => '动漫';

  @override
  String get dbOnlineCategoryCensored => '有码';

  @override
  String get dbOnlineCategorySection => '类型';

  @override
  String get dbOnlineCategoryUncensored => '无码';

  @override
  String get dbOnlineCategoryWestern => '欧美';

  @override
  String get dbOnlineConfigLoadError => 'DB Online 配置加载失败';

  @override
  String get dbOnlineConnectionFailed => '连接失败';

  @override
  String get dbOnlineConnectionOk => '连接正常';

  @override
  String dbOnlineDefaultPlaySource(int id) {
    return '播放源 $id';
  }

  @override
  String get dbOnlineDescending => '降序';

  @override
  String get dbOnlineDetailDate => '发布日期';

  @override
  String get dbOnlineDetailRatingCount => '评分人数';

  @override
  String get dbOnlineDetailsSection => '详情';

  @override
  String dbOnlineEpisodeNumber(int number) {
    return '第 $number 集';
  }

  @override
  String get dbOnlineEpisodesSection => '集数';

  @override
  String get dbOnlineFieldApiUrl => 'API 地址';

  @override
  String get dbOnlineFieldApiUrlHint => '后端 API 地址。';

  @override
  String get dbOnlineFieldAuthorization => '授权';

  @override
  String get dbOnlineFieldAutoplay => '自动播放';

  @override
  String get dbOnlineFieldCaptions => '字幕';

  @override
  String get dbOnlineFieldCategoryId => '类型 ID';

  @override
  String get dbOnlineFieldCategoryIdHint => '填写数据源对应的类型 ID';

  @override
  String get dbOnlineFieldCategoryOptional => '类型（可选）';

  @override
  String get dbOnlineFieldCheckIntervalHint => '设置自动检查配置的时间间隔';

  @override
  String get dbOnlineFieldCheckIntervalMinutes => '检查间隔（分钟）';

  @override
  String get dbOnlineFieldConcurrency => '并发数';

  @override
  String get dbOnlineFieldCookie => 'Cookie';

  @override
  String get dbOnlineFieldDeviceId => '设备 ID';

  @override
  String get dbOnlineFieldEnablePlayer => '启用播放器';

  @override
  String get dbOnlineFieldEnableProxy => '启用代理';

  @override
  String get dbOnlineFieldEnableRetry => '启用重试';

  @override
  String get dbOnlineFieldEnableSubscription => '启用订阅';

  @override
  String get dbOnlineFieldEnabled => '已启用';

  @override
  String get dbOnlineFieldFullscreen => '全屏';

  @override
  String get dbOnlineFieldHost => '主机';

  @override
  String get dbOnlineFieldImageMode => '图片模式';

  @override
  String get dbOnlineFieldImageUrlReplacePrefix => '图片 URL 替换前缀';

  @override
  String get dbOnlineFieldImageUrlReplacePrefixHint => '将图片地址中的指定前缀替换为代理地址';

  @override
  String get dbOnlineFieldIntervalRangeHint => '设置允许的检查间隔范围';

  @override
  String get dbOnlineFieldIntervalRangeSeconds => '间隔范围（秒）';

  @override
  String get dbOnlineFieldKeyboard => '键盘';

  @override
  String get dbOnlineFieldMaskHint => '敏感信息将被遮罩';

  @override
  String get dbOnlineFieldOptionalMaskHint => '可选；留空以保留当前值';

  @override
  String get dbOnlineFieldParentFolderId => '父文件夹 ID';

  @override
  String get dbOnlineFieldPassword => '密码';

  @override
  String get dbOnlineFieldPasswordOptional => '密码（可选）';

  @override
  String get dbOnlineFieldPip => '画中画';

  @override
  String get dbOnlineFieldPort => '端口';

  @override
  String get dbOnlineFieldProtocol => '协议';

  @override
  String get dbOnlineFieldRequestTimeoutSeconds => '请求超时（秒）';

  @override
  String get dbOnlineFieldReserveQuotaGb => '保留配额（GB）';

  @override
  String get dbOnlineFieldRetryCount => '重试次数';

  @override
  String get dbOnlineFieldRetryIntervalSeconds => '重试间隔（秒）';

  @override
  String get dbOnlineFieldRpcSecret => 'RPC 密钥';

  @override
  String get dbOnlineFieldSavePath => '保存路径';

  @override
  String get dbOnlineFieldTimeoutSeconds => '超时时间（秒）';

  @override
  String get dbOnlineFieldUseHttps => '使用 HTTPS';

  @override
  String get dbOnlineFieldUsername => '用户名';

  @override
  String get dbOnlineFieldUsernameOptional => '用户名（可选）';

  @override
  String get dbOnlineFilterMovieType => '筛选影片类型';

  @override
  String get dbOnlineGroupDownloader => '下载器';

  @override
  String get dbOnlineGroupMediaLibrary => '媒体库';

  @override
  String get dbOnlineGroupSystem => '系统';

  @override
  String get dbOnlineHidePassword => '隐藏密码';

  @override
  String get dbOnlineImageModeDecrypt => '解密';

  @override
  String get dbOnlineImageModeReplace => '替换';

  @override
  String get dbOnlineInLibrary => '已在媒体库';

  @override
  String get dbOnlineLatestReleased => '最新上架';

  @override
  String get dbOnlineLibrarySection => '媒体库';

  @override
  String get dbOnlineNoData => '暂无数据';

  @override
  String get dbOnlineNoMeta => '暂无元数据';

  @override
  String get dbOnlineNoPlaySources => '暂无播放源';

  @override
  String get dbOnlineNoPlayableEpisodes => '暂无可播放剧集';

  @override
  String get dbOnlineOnlineOnly => '仅在线播';

  @override
  String get dbOnlinePlayOnline => '在线播放';

  @override
  String get dbOnlinePlaySource => '播放源';

  @override
  String get dbOnlinePlayTooltip => '播放 · 长按选择内核';

  @override
  String get dbOnlinePreviewSection => '预览';

  @override
  String get dbOnlineQualityTooltip => '选择清晰度 · 长按列表选择内核';

  @override
  String get dbOnlineRecentUpdated => '最近更新';

  @override
  String get dbOnlineRefreshEpisodes => '刷新剧集';

  @override
  String get dbOnlineRelatedSection => '相关推荐';

  @override
  String get dbOnlineRetry => '重试';

  @override
  String get dbOnlineSameActorSection => '同演员作品';

  @override
  String get dbOnlineSaved => '已保存';

  @override
  String dbOnlineSectionFieldCount(int count) {
    return '$count 个字段';
  }

  @override
  String get dbOnlineSectionPan115 => '115 网盘';

  @override
  String get dbOnlineSectionPlayer => '播放器';

  @override
  String get dbOnlineSectionProxy => '代理';

  @override
  String get dbOnlineSectionScopeHint => '修改后仅更新当前配置分区。';

  @override
  String get dbOnlineSectionSubscription => '订阅';

  @override
  String get dbOnlineSectionSupportsTest => '支持测试';

  @override
  String get dbOnlineSectionThunder => '迅雷';

  @override
  String get dbOnlineSeriesSection => '系列';

  @override
  String get dbOnlineShowPassword => '显示密码';

  @override
  String get dbOnlineSort => '排序';

  @override
  String get dbOnlineTestConnection => '测试连接';

  @override
  String get dbOnlineUncensored => '无码';

  @override
  String get homeBadgeNew => '新';

  @override
  String get homeLibraries => '我的媒体库';

  @override
  String get homeNoData => '暂无数据';

  @override
  String get homeSwitchAuthFailed => '验证失败';

  @override
  String get homeSwitchAuthTimeout => '验证超时';

  @override
  String get homeSwitchBackToPassword => '改用密码';

  @override
  String get homeSwitchCancel => '取消切换';

  @override
  String homeSwitchCannotConnect(String name) {
    return '无法连接 $name';
  }

  @override
  String get homeSwitchCheckNetwork => '检查网络连接';

  @override
  String get homeSwitchCheckingAuth => '正在检查服务器鉴权状态…';

  @override
  String homeSwitchConnecting(String name) {
    return '连接 $name';
  }

  @override
  String get homeSwitchConnectionFailed => '连接失败';

  @override
  String get homeSwitchInvalidTarget => '目标服务器无效';

  @override
  String get homeSwitchNeedPassword => '需要密码';

  @override
  String homeSwitchNeedTotp(int length) {
    return '请输入 $length 位动态验证码';
  }

  @override
  String get homeSwitchNeedUsername => '需要用户名';

  @override
  String get homeSwitchPasswordHint => '请输入此服务器的密码继续。';

  @override
  String get homeSwitchPasswordLabel => '密码';

  @override
  String homeSwitchRestoreFailed(String error) {
    return '恢复会话失败：$error';
  }

  @override
  String get homeSwitchServer => '服务器';

  @override
  String get homeSwitchSignInAndSwitch => '登录并切换';

  @override
  String get homeSwitchTargetMissingMessage => '无法找到目标服务器，请返回后重试。';

  @override
  String get homeSwitchTargetMissingTitle => '服务器配置无效';

  @override
  String get homeSwitchTotpHint => '输入动态验证码完成切换。';

  @override
  String get homeSwitchUsernameLabel => '用户名';

  @override
  String get homeSwitchUsernamePasswordHint => '请输入此服务器的用户名和密码继续。';

  @override
  String get homeSwitchVerifyAndSwitch => '验证并切换';

  @override
  String get homeSwitchVerifying => '验证中…';

  @override
  String mediaBrowserActionFailed(String error) {
    return '操作失败：$error';
  }

  @override
  String get mediaBrowserActorWorks => '演员作品';

  @override
  String get mediaBrowserAddPath => '添加路径';

  @override
  String get mediaBrowserAdminRequired => '需要管理员账号';

  @override
  String get mediaBrowserAdminRequiredHint => '请使用管理员账号管理媒体库。';

  @override
  String get mediaBrowserAscending => '升序';

  @override
  String mediaBrowserBatchRemoveFailed(String error) {
    return '批量取消收藏失败：$error';
  }

  @override
  String get mediaBrowserContentType => '内容类型';

  @override
  String get mediaBrowserContentTypeReadonly => '内容类型（只读）';

  @override
  String get mediaBrowserContentTypeRequired => '请选择内容类型';

  @override
  String mediaBrowserDeleteFailed(String error) {
    return '删除媒体库失败：$error';
  }

  @override
  String mediaBrowserDeleteLibraryBody(String name) {
    return '确定删除媒体库“$name”吗？服务器上的媒体文件不会被删除。';
  }

  @override
  String get mediaBrowserDeleteLibraryTitle => '删除媒体库';

  @override
  String get mediaBrowserDescending => '降序';

  @override
  String get mediaBrowserDisableAction => '停用';

  @override
  String get mediaBrowserDisableLibraryHint => '停用后将不再显示该媒体库。';

  @override
  String mediaBrowserDisc(int number) {
    return '碟片 $number';
  }

  @override
  String get mediaBrowserEditLibrarySubtitle => '编辑媒体库设置';

  @override
  String get mediaBrowserEditLibraryTitle => '编辑媒体库';

  @override
  String get mediaBrowserEnableAction => '启用';

  @override
  String get mediaBrowserEnableLibraryHint => '启用后将在媒体库中显示。';

  @override
  String get mediaBrowserEnableLibraryLabel => '启用媒体库';

  @override
  String get mediaBrowserFavoriteAction => '收藏';

  @override
  String get mediaBrowserFilterContentType => '筛选内容类型';

  @override
  String mediaBrowserItemCount(int count) {
    return '$count 个条目';
  }

  @override
  String get mediaBrowserLatestAdded => '最新入库';

  @override
  String get mediaBrowserLibrariesTitle => '媒体库';

  @override
  String get mediaBrowserLibrariesUnavailable => '无法访问媒体库';

  @override
  String get mediaBrowserLibraryCreated => '媒体库已创建';

  @override
  String get mediaBrowserLibraryDeleted => '媒体库已删除';

  @override
  String get mediaBrowserLibraryDisabled => '媒体库已停用';

  @override
  String get mediaBrowserLibraryEnabled => '媒体库已启用';

  @override
  String get mediaBrowserLibraryManageSubtitle => '管理服务器上的虚拟媒体库与媒体路径。';

  @override
  String get mediaBrowserLibraryManageTitle => '媒体库管理';

  @override
  String get mediaBrowserLibraryNameHint => '例如：电影、电视剧、音乐';

  @override
  String get mediaBrowserLibraryNameLabel => '媒体库名称';

  @override
  String get mediaBrowserLibraryNameRequired => '请输入媒体库名称';

  @override
  String mediaBrowserLibraryRefreshStarted(String name) {
    return '已开始刷新「$name」';
  }

  @override
  String get mediaBrowserLibrarySettingsSaved => '媒体库设置已保存';

  @override
  String get mediaBrowserMarkWatched => '标记为已看';

  @override
  String get mediaBrowserMediaPathsLabel => '媒体路径';

  @override
  String get mediaBrowserNewLibrarySubtitle => '添加媒体库名称、类型和路径';

  @override
  String get mediaBrowserNewLibraryTitle => '新建媒体库';

  @override
  String get mediaBrowserNoData => '暂无数据';

  @override
  String get mediaBrowserNoFavorites => '暂无收藏内容';

  @override
  String get mediaBrowserNoFavoritesHint => '在详情页点击 ♡ 加入收藏';

  @override
  String get mediaBrowserNoFavoritesYet => '暂无收藏';

  @override
  String get mediaBrowserNoLibrariesHint => '请先创建或启用一个媒体库。';

  @override
  String get mediaBrowserNoLibrariesYet => '还没有媒体库';

  @override
  String get mediaBrowserNoMatchingItems => '没有匹配的内容';

  @override
  String get mediaBrowserNoTracks => '暂无音轨';

  @override
  String get mediaBrowserNotMediaServer => '当前服务器不是可用的媒体服务器。';

  @override
  String get mediaBrowserPathHint => '添加媒体库路径';

  @override
  String mediaBrowserPathNumber(int number) {
    return '路径 $number';
  }

  @override
  String get mediaBrowserPathRequired => '请输入媒体库路径';

  @override
  String get mediaBrowserPlayAll => '全部播放';

  @override
  String get mediaBrowserRefresh => '刷新';

  @override
  String mediaBrowserRefreshFailed(String error) {
    return '刷新失败：$error';
  }

  @override
  String mediaBrowserRemoveFavoriteFailed(String error) {
    return '取消收藏失败：$error';
  }

  @override
  String mediaBrowserRemoveFavoritesBody(int count) {
    return '确定取消收藏已选的 $count 个条目吗？';
  }

  @override
  String get mediaBrowserRemoveFavoritesTitle => '移除收藏';

  @override
  String get mediaBrowserRemovePath => '移除路径';

  @override
  String mediaBrowserRemovedItem(String name) {
    return '已取消收藏：$name';
  }

  @override
  String mediaBrowserRemovedNItems(int count) {
    return '已取消收藏 $count 个条目';
  }

  @override
  String mediaBrowserRemovedNItemsWithFailed(int count, int failed) {
    return '已取消收藏 $count 个条目，$failed 个失败';
  }

  @override
  String get mediaBrowserRetry => '重试';

  @override
  String mediaBrowserSaveFailed(String error) {
    return '保存媒体库失败：$error';
  }

  @override
  String get mediaBrowserSort => '排序';

  @override
  String get mediaBrowserSortBy => '排序方式';

  @override
  String get mediaBrowserSortName => '按名称';

  @override
  String get mediaBrowserSortNameAZ => '名称（A-Z）';

  @override
  String get mediaBrowserSortRating => '按评分';

  @override
  String get mediaBrowserSortRecent => '按最近添加';

  @override
  String get mediaBrowserSortTopRated => '按评分最高';

  @override
  String get mediaBrowserSortYear => '按年份';

  @override
  String get mediaBrowserSortYearDesc => '按年份（降序）';

  @override
  String get mediaBrowserStatEpisodes => '剧集数';

  @override
  String get mediaBrowserStatMovies => '影片数';

  @override
  String get mediaBrowserStatSeries => '系列数';

  @override
  String get mediaBrowserStatsLoadFailed => '统计加载失败';

  @override
  String get mediaBrowserStatusDisabled => '已禁用';

  @override
  String get mediaBrowserStatusEnabled => '已启用';

  @override
  String get mediaBrowserTracks => '音轨';

  @override
  String get mediaBrowserTypeAlbums => '专辑';

  @override
  String get mediaBrowserTypeMixed => '混合内容';

  @override
  String get mediaBrowserTypeMovies => '电影';

  @override
  String get mediaBrowserTypeMusic => '音乐';

  @override
  String get mediaBrowserTypeMusicVideos => '音乐视频';

  @override
  String get mediaBrowserTypeSongs => '歌曲';

  @override
  String get mediaBrowserTypeTvShows => '电视剧';

  @override
  String get mediaBrowserUnfavoriteAction => '取消收藏';

  @override
  String get mediaBrowserUnmarkWatched => '标记为未观看';

  @override
  String get playerSettingBufferGroup => '播放缓冲';

  @override
  String get playerSettingButtonsGroup => '播放按钮';

  @override
  String get playerSettingDefaultEngine => '默认播放内核';

  @override
  String playerSettingDefaultEngineSub(String engine) {
    return '当前：$engine';
  }

  @override
  String get playerSettingDoubleTapCenter => '双击屏幕中间';

  @override
  String get playerSettingDoubleTapCenterSub => '暂停 / 播放';

  @override
  String get playerSettingDoubleTapEdges => '双击屏幕两边';

  @override
  String get playerSettingDoubleTapEdgesSub => '左侧快退,右侧快进';

  @override
  String get playerSettingDoubleTapGroup => '双击手势';

  @override
  String get playerSettingEntryOrientation => '进入播放器屏幕方向';

  @override
  String get playerSettingHapticGroup => '震动反馈';

  @override
  String get playerSettingHapticLongPress => '长按屏幕';

  @override
  String get playerSettingHapticProgressBar => '拖动进度条';

  @override
  String get playerSettingHapticRate => '滑动调节倍速';

  @override
  String get playerSettingHapticSeek => '滑动调节进度';

  @override
  String get playerSettingIosEngineGroup => 'iOS 播放内核';

  @override
  String get playerSettingLandscapeSide => '设备横屏方向';

  @override
  String get playerSettingMediaSwitchButton => '切换媒体按钮';

  @override
  String get playerSettingMediaSwitchButtonSub => '上一部 / 下一部';

  @override
  String get playerSettingOrientationButton => '旋屏按钮';

  @override
  String get playerSettingOrientationGroup => '屏幕方向';

  @override
  String get playerSettingOsdBattery => '设备电量';

  @override
  String get playerSettingOsdBatterySub => '显示当前电池电量';

  @override
  String get playerSettingOsdClock => '系统时间';

  @override
  String get playerSettingOsdClockSub => '在播放器上显示当前时间';

  @override
  String get playerSettingOsdCpu => 'CPU 占用率';

  @override
  String get playerSettingOsdCpuSub => '显示设备实时 CPU 使用率';

  @override
  String get playerSettingOsdGroup => 'OSD 信息';

  @override
  String get playerSettingOsdNetwork => '设备网速';

  @override
  String get playerSettingOsdNetworkSub => '显示 Wi-Fi、4G/5G 网络类型和当前下载速度';

  @override
  String get playerSettingPipButton => '画中画按钮';

  @override
  String get playerSettingPlayPauseButton => '播放 / 暂停按钮';

  @override
  String get playerSettingPreloadSize => '预载缓冲大小';

  @override
  String playerSettingPreloadSizeSub(String size) {
    return '当前：$size';
  }

  @override
  String get playerSettingResumeLast => '从上次进度播放';

  @override
  String get playerSettingResumeLastSub => '打开影片时自动恢复上次观看位置';

  @override
  String get playerSettingSeekButtons => '快进 / 快退按钮';

  @override
  String get playerSettingSpeedButton => '速度调节按钮';

  @override
  String get posterBadgeAllHidden => '已隐藏所有技术角标';

  @override
  String get posterBadgeDetailPoster => '影片详情海报';

  @override
  String get posterBadgePageSubtitle => '控制影片详情海报上显示的技术信息';

  @override
  String get posterBadgePreviewCodec => '视频编码: HEVC';

  @override
  String get posterBadgePreviewHd => '720p 及以上';

  @override
  String get posterBadgePreviewHdr => '动态范围: HDR10 (PQ)';

  @override
  String get posterBadgePreviewHint => '开关会实时更新预览和影片详情页海报。';

  @override
  String get posterBadgePreviewStrm => 'STRM 视频文件';

  @override
  String get posterBadgePreviewTitle => 'ABC-123  示例影片';

  @override
  String get posterBadgeVisible => '显示';

  @override
  String get serverAddTitle => '添加服务器';

  @override
  String get serverAdded => '服务器已添加';

  @override
  String get serverCurrent => '当前服务器';

  @override
  String serverDeleteBody(String name) {
    return '确定删除服务器“$name”及其线路吗？';
  }

  @override
  String serverDeleteFailed(String error) {
    return '删除失败：$error';
  }

  @override
  String get serverDeleteTitle => '删除服务器';

  @override
  String get serverEditAction => '编辑服务器';

  @override
  String get serverLineAdd => '添加线路';

  @override
  String get serverLineAutoSelect => '自动选择线路';

  @override
  String get serverLineAutoTestNoResult => '自动测试未返回结果';

  @override
  String serverLineCount(int count) {
    return '$count条线路';
  }

  @override
  String get serverLineDefaultName => '服务器线路';

  @override
  String get serverLineDeleteActiveBlocked => '当前线路正在使用，无法删除';

  @override
  String serverLineDeleteBody(String name) {
    return '确定删除线路“$name”吗？';
  }

  @override
  String get serverLineDeleteTitle => '删除线路';

  @override
  String get serverLineDeleted => '线路已删除';

  @override
  String get serverLineDisable => '禁用';

  @override
  String get serverLineDisabled => '服务器线路已禁用';

  @override
  String get serverLineDuplicateUrl => '已存在相同的线路地址';

  @override
  String get serverLineEditorAddTitle => '添加服务器线路';

  @override
  String get serverLineEditorEditTitle => '编辑服务器线路';

  @override
  String get serverLineEnable => '启用线路';

  @override
  String serverLineFastest(String name) {
    return '最快线路：$name';
  }

  @override
  String get serverLineKeepOne => '至少保留一条服务器线路';

  @override
  String get serverLineKeepOneEnabled => '至少保留一条启用线路';

  @override
  String get serverLineNameHint => '例如：主线路';

  @override
  String get serverLineNameLabel => '线路名称';

  @override
  String get serverLineNoFallback => '没有可用的备用线路';

  @override
  String get serverLineNoResponse => '服务器线路无响应';

  @override
  String get serverLineNoneEnabled => '当前没有启用的线路';

  @override
  String get serverLineProbeFailed => '线路检测失败';

  @override
  String get serverLineProbeFailedNotSaved => '服务器检测失败，线路未保存';

  @override
  String serverLineSaved(int latency) {
    return '已保存，延迟 $latency ms';
  }

  @override
  String serverLineSelected(String name, int latency) {
    return '已选择 $name（$latency ms）';
  }

  @override
  String serverLineSwitchedTo(String name) {
    return '已切换到线路：$name';
  }

  @override
  String serverLineTestFailed(String error) {
    return '线路测试失败：$error';
  }

  @override
  String get serverLineTesting => '正在检测线路';

  @override
  String get serverLineUpdatedAndSwitched => '线路已更新并切换';

  @override
  String get serverLineUse => '使用线路';

  @override
  String get serverLinesEmptyBody => '添加备用线路，让服务器保持可访问';

  @override
  String get serverLinesEmptyTitle => '暂无线路';

  @override
  String serverLinesEyebrow(String name) {
    return '服务器 · $name';
  }

  @override
  String get serverLinesNotConfigured => '尚未配置服务器线路';

  @override
  String get serverLinesServerMissing => '服务器不存在或已被删除';

  @override
  String get serverLinesSubtitle => '管理服务器线路';

  @override
  String get serverLinesTitle => '服务器线路';

  @override
  String get serverListSubtitle => '服务器列表';

  @override
  String get serverManageLines => '管理线路';

  @override
  String get serverSettingsAccessSub => '登录密码、会话策略与 TOTP';

  @override
  String get serverSettingsAudioSub => '已提取音频资产与字幕转译进度';

  @override
  String get serverSettingsAvdb => 'AVDB 数据源';

  @override
  String get serverSettingsAvdbSub => '演员关联同步';

  @override
  String get serverSettingsDboSub => '影片信息、资源和演员关联';

  @override
  String get serverSettingsModalTranscription => '云端字幕转译';

  @override
  String get serverSettingsModalTranscriptionSub => 'Modal GPU 云端转译和任务并行配置';

  @override
  String get serverSettingsTranscoding => '转码';

  @override
  String get serverSettingsTranscodingSub => '硬件解码、后端选择和失败回退';

  @override
  String get serverSetupConnectTitle => '连接到服务器';

  @override
  String serverSetupDuplicate(String name) {
    return '已存在相同连接的 $name 服务器';
  }

  @override
  String get serverSetupEditSubtitle => '编辑服务器连接信息';

  @override
  String get serverSetupHostLabel => '主机';

  @override
  String get serverSetupHostRequired => '请输入主机';

  @override
  String get serverSetupInvalidFileConfig => '文件服务器配置无效';

  @override
  String get serverSetupLoginUsernameRequired => '已填写密码，请输入用户名';

  @override
  String get serverSetupNameLabel => '服务器名称';

  @override
  String get serverSetupNameRequired => '请输入服务器名称';

  @override
  String get serverSetupNewSubtitle => '添加新的服务器连接';

  @override
  String get serverSetupPasswordLabel => '密码';

  @override
  String get serverSetupPasswordEditLabel => '密码（留空为不更改）';

  @override
  String get serverSetupPasswordOptionalLabel => '密码（可选）';

  @override
  String get serverSetupPasswordRequired => '请输入密码';

  @override
  String get serverSetupPathHintOpenList => '点击此处从文件列表选择路径';

  @override
  String get serverSetupPathHintSmb => '共享名或 /';

  @override
  String get serverSetupPathLabel => '路径';

  @override
  String get serverSetupPathRequired => '请输入路径';

  @override
  String get serverSetupPortInvalid => '请输入 1-65535 之间的端口';

  @override
  String get serverSetupPortLabel => '端口';

  @override
  String get serverSetupProjectLabel => '服务器类型';

  @override
  String get serverSetupProtocolLabel => '协议';

  @override
  String get serverSetupReplaceTitle => '更换服务器';

  @override
  String get serverSetupRootPathLabel => '根路径';

  @override
  String get serverSetupSelectProject => '请选择服务器类型';

  @override
  String get serverSetupTotpClearStored => '清除已保存的密钥';

  @override
  String get serverSetupTotpKeyHint => '开启两步验证的服务器填入，登录时将自动生成验证码';

  @override
  String get serverSetupTotpKeyInvalid => 'TOTP 密钥格式无效（应为 base32 字符串）';

  @override
  String get serverSetupTotpKeyLabel => 'TOTP 密钥（可选）';

  @override
  String get serverSetupTotpKeyEditLabel => 'TOTP 密钥（留空为不更改）';

  @override
  String get serverSetupTotpRequired =>
      '该服务器开启了两步验证，请填写 TOTP 密钥或清空密码保存后再从登录页登录';

  @override
  String get serverSetupUserLabel => '用户名';

  @override
  String get serverSetupUserEditLabel => '用户名（留空为不更改）';

  @override
  String get serverSetupUserOptionalGenericLabel => '用户名（可选）';

  @override
  String get serverSetupUserOptionalLabel => '用户名（API Key 登录可留空）';

  @override
  String get serverSetupUserRequired => '请输入用户名';

  @override
  String get serverSetupStashApiKeyLabel => 'Stash API Key';

  @override
  String get serverSetupStashApiKeyEditLabel => 'Stash API Key（留空为不更改）';

  @override
  String get serverSetupStashApiKeyHint => '在 Stash 设置 → 安全中创建；密钥仅保存在安全存储中';

  @override
  String get serverSetupStashApiKeyClear => '清除已保存的 Stash API Key';

  @override
  String get serverSetupStashApiKeyRequired => '请输入 Stash API Key';

  @override
  String get homeSwitchStashApiKeyHint => '请输入 Stash API Key 以切换服务器';

  @override
  String get homeSwitchOpenServerSettings => '前往服务器设置';

  @override
  String get serverTestAndSave => '测试并保存';

  @override
  String get serverUpdated => '服务器已更新';

  @override
  String get serverUrlRequired => '请输入服务器地址';

  @override
  String get serverUrlSchemeRequired => '地址必须以 http:// 或 https:// 开头';

  @override
  String get settingsAudioManagement => '音频管理';

  @override
  String settingsCacheCategoryCleared(String category) {
    return '已清理：$category';
  }

  @override
  String get settingsCacheClear => '清理缓存';

  @override
  String settingsCacheClearCategoryBody(String category) {
    return '将删除当前$category中的全部文件，此操作不可撤销。';
  }

  @override
  String settingsCacheClearCategoryTitle(String category) {
    return '确认清理$category';
  }

  @override
  String settingsCacheClearFailed(String error) {
    return '清理缓存失败：$error';
  }

  @override
  String get settingsCacheClearMusicBody => '确定清理音乐缓存吗？';

  @override
  String get settingsCacheClearMusicTitle => '清理音乐缓存';

  @override
  String get settingsCacheMusicCleared => '音乐缓存已清理';

  @override
  String get settingsCheckForUpdates => '检查更新';

  @override
  String get settingsLogoutConfirmBody => '退出登录后需要重新验证服务器账号。';

  @override
  String get settingsLogoutConfirmTitle => '确认退出登录？';

  @override
  String get settingsServerList => '服务器列表';

  @override
  String settingsServerListSub(int count) {
    return '$count 台服务器 · 可分别配置线路';
  }

  @override
  String get stageLabel => '阶段';

  @override
  String get subtitleBackgroundColor => '背景颜色';

  @override
  String get subtitleBehaviorGroup => '字幕行为';

  @override
  String get subtitleBold => '加粗';

  @override
  String get subtitleFont => '字幕字体';

  @override
  String get subtitleFontColor => '字幕字体颜色';

  @override
  String get subtitleFontMonospace => '等宽字体';

  @override
  String get subtitleFontSerif => '衬线字体';

  @override
  String get subtitleFontSystem => '系统字体';

  @override
  String get subtitleIgnoreAssStyle => '忽略 ASS 字幕样式';

  @override
  String get subtitleIgnoreAssStyleSub => '使用下面的客户端字体和颜色设置';

  @override
  String get subtitleIgnoreSrtStyle => '忽略 SRT 字幕样式';

  @override
  String get subtitleIgnoreSrtStyleSub => '忽略字幕中的 HTML 样式标签';

  @override
  String get subtitleItalic => '斜体';

  @override
  String get subtitleOutlineColor => '描边颜色';

  @override
  String get subtitleOutlineShadowGroup => '描边与阴影';

  @override
  String get subtitleOutlineWidth => '描边粗细';

  @override
  String get subtitlePreviewText => '字幕预览';

  @override
  String get subtitleRememberSelection => '记住所选字幕';

  @override
  String get subtitleRememberSelectionSub => '下次播放时自动恢复最近使用的字幕轨道';

  @override
  String get subtitleResetDefaults => '恢复默认';

  @override
  String get subtitleResetDefaultsSub => '恢复字体、颜色、描边和字幕行为设置';

  @override
  String get subtitleResetDone => '字幕设置已重置';

  @override
  String get subtitleResetGroup => '重置';

  @override
  String get subtitleShadowColor => '阴影颜色';

  @override
  String get subtitleShadowSize => '阴影大小';

  @override
  String get subtitleStylePreview => '样式预览';

  @override
  String get subtitleTextStyleGroup => '文字样式';

  @override
  String get subtitleTransparent => '透明';

  @override
  String get taskCenterTitle => '任务中心';

  @override
  String get transcriptionAddToken => '添加令牌';

  @override
  String get transcriptionAddTokenSubtitle => '添加 Modal 令牌';

  @override
  String get transcriptionConfiguredKeepHint => '已配置的令牌将继续使用，留空不会修改。';

  @override
  String get transcriptionCredentialKeepHint => '已配置，留空则不修改';

  @override
  String get transcriptionDisabledSubtitle => '云端字幕转译已禁用';

  @override
  String get transcriptionDuplicateTokenId => '存在重复的 Modal Token ID';

  @override
  String get transcriptionEditTokenSubtitle => '编辑转录令牌设置';

  @override
  String get transcriptionEditTokenTitle => '编辑令牌';

  @override
  String get transcriptionEnable => '启用转录';

  @override
  String get transcriptionEnabledSubtitle => '云端字幕转译已启用';

  @override
  String get transcriptionFollowMaxWorkers => '跟随最大工作线程数';

  @override
  String get transcriptionGpuHelp => '启用 GPU 可加速转录，但需要兼容的运行环境。';

  @override
  String get transcriptionGpuLabel => '云端 GPU';

  @override
  String get transcriptionHfTokenHint => '填写 Hugging Face 令牌以访问私有模型。';

  @override
  String get transcriptionHfTokenOptional => 'Hugging Face 令牌（可选）';

  @override
  String get transcriptionMaxWorkersHelp => '限制同时运行的转录任务数量。';

  @override
  String get transcriptionMaxWorkersLabel => '最大工作线程数';

  @override
  String get transcriptionModelBranchHelp => '填写模型仓库中的分支或版本名称。';

  @override
  String get transcriptionModelBranchLabel => '模型分支';

  @override
  String get transcriptionNeedToken => '启用云端字幕转译时至少需要添加一个 Modal 令牌';

  @override
  String get transcriptionNewHfTokenHint => '输入新的 Hugging Face 令牌；留空则保持原值。';

  @override
  String get transcriptionNoTokensHint => '还没有配置转录令牌。';

  @override
  String get transcriptionPerTokenSliderLabel => '每个令牌的并发数';

  @override
  String get transcriptionPerTokenWorkersHelp => '为每个令牌分配的最大工作线程数。';

  @override
  String get transcriptionPerTokenWorkersLabel => '每个令牌的工作线程数';

  @override
  String get transcriptionPerTokenWorkersRange => '单令牌并发上限必须在 0-10 之间';

  @override
  String get transcriptionSaveButton => '保存云端转译配置';

  @override
  String get transcriptionSaved => '云端字幕转译配置已保存';

  @override
  String get transcriptionStrategyFillFirst => '优先使用第一个令牌';

  @override
  String get transcriptionStrategyRoundRobin => '轮流使用令牌';

  @override
  String get transcriptionSubtitle => '转录字幕';

  @override
  String get transcriptionTitle => '云端字幕转译';

  @override
  String get transcriptionTokenConfigured => '已配置';

  @override
  String get transcriptionTokenDraft => '新令牌 · 保存后生效';

  @override
  String get transcriptionTokenIdExists => '已存在相同 Token ID 的令牌';

  @override
  String get transcriptionTokenIdHint => '填写服务商提供的令牌 ID。';

  @override
  String get transcriptionTokenIdLabel => 'Token ID';

  @override
  String get transcriptionTokenIncomplete =>
      '新增令牌必须同时填写 Token ID 和 Token Secret';

  @override
  String transcriptionTokenLimit(int count) {
    return '最多 $count 个令牌';
  }

  @override
  String get transcriptionTokenListHint => '可添加多个 Modal 令牌，最多 20 个';

  @override
  String get transcriptionTokenNameHint => '为令牌添加备注';

  @override
  String get transcriptionTokenNameLabel => '备注（可选）';

  @override
  String transcriptionTokenNumber(int number) {
    return '令牌 $number';
  }

  @override
  String get transcriptionTokenSecretHint => '填写服务商提供的 Token Secret';

  @override
  String get transcriptionTokenSecretLabel => 'Token Secret';

  @override
  String get transcriptionTokenStrategyHelp => '选择多个令牌的分配方式。';

  @override
  String get transcriptionTokenStrategyLabel => '令牌使用策略';

  @override
  String transcriptionTokensCount(int count, int limit) {
    return '已配置 $count 个 · 上限 $limit 个';
  }

  @override
  String get transcriptionTokensEmptyHint => '启用云端转译至少需要配置一个 Modal 令牌';

  @override
  String get transcriptionTokensLabel => 'MODAL 令牌';

  @override
  String get transcriptionWorkersRange => '并行数必须在 1-10 之间';

  @override
  String get transcriptionWorkersSliderLabel => '工作线程数';

  @override
  String get translationApiUrlHelp => '支持 OpenAI / OpenRouter 等兼容服务';

  @override
  String get translationConfiguredKeepHint => '已配置的 API 凭据将继续使用，留空不会修改。';

  @override
  String get translationDisabledSubtitle => '翻译已禁用';

  @override
  String get translationEnable => '启用翻译';

  @override
  String get translationEnabledSubtitle => '翻译已启用';

  @override
  String get translationLangAutoDetect => '自动检测';

  @override
  String get translationLangChinese => '中文';

  @override
  String get translationLangEnglish => '英语';

  @override
  String get translationLangFrench => '法语';

  @override
  String get translationLangGerman => '德语';

  @override
  String get translationLangJapanese => '日语';

  @override
  String get translationLangKorean => '韩语';

  @override
  String get translationLangRussian => '俄语';

  @override
  String get translationLangSpanish => '西班牙语';

  @override
  String get translationLoadModels => '加载模型';

  @override
  String translationLoadModelsFailed(String error) {
    return '加载模型失败：$error';
  }

  @override
  String get translationModelNameHelp => '填写翻译服务使用的模型名称。';

  @override
  String get translationModelNameLabel => '模型名称';

  @override
  String get translationNeedApiKey => '请先配置 API 密钥。';

  @override
  String get translationNeedApiUrl => '请先配置 API 地址。';

  @override
  String get translationNewApiKeyHint => '输入新的 API 密钥；留空则保持原值。';

  @override
  String get translationNoModels => '没有可用的模型';

  @override
  String translationPromptTemplateHelp(String variables) {
    return '可用变量：$variables';
  }

  @override
  String get translationPromptTemplateLabel => '提示词模板';

  @override
  String get translationSaved => '翻译已保存';

  @override
  String translationSelectModel(int count) {
    return '选择模型（$count 个）';
  }

  @override
  String get translationSourceLanguage => '源语言';

  @override
  String get translationSubtitle => '配置翻译服务';

  @override
  String get translationTargetLanguage => '目标语言';

  @override
  String get translationTestButton => '测试翻译';

  @override
  String get translationBatchFailed => '批量翻译失败';

  @override
  String translationTestFailed(String error) {
    return '测试失败：$error';
  }

  @override
  String get translationTestPassed => '测试通过';

  @override
  String get translationTestResult => '测试结果';

  @override
  String get translationTitle => '翻译设置';

  @override
  String get accessBindTotp => '绑定 TOTP';

  @override
  String get accessChangePassword => '修改密码';

  @override
  String get accessChangePasswordHelp => '修改用于访问应用的本地密码。';

  @override
  String get accessConfigSaved => '访问配置已保存';

  @override
  String get accessControlSubtitle => '访问控制';

  @override
  String get accessDeleteTotp => '删除 TOTP';

  @override
  String get accessDeleteTotpConfirm => '确定删除已绑定的 TOTP？';

  @override
  String get accessDisabled => '访问保护已禁用';

  @override
  String get accessEnabled => '访问保护已启用';

  @override
  String get accessEnableFirst => '请先启用访问保护';

  @override
  String get accessLoadFailed => '加载访问控制失败';

  @override
  String get accessLockDuration => '锁定时长';

  @override
  String get accessLockMinutesHelp => '范围 1-1440 分钟。';

  @override
  String get accessMaxAttemptsHelp => '范围 1-100 次，达到后临时锁定。';

  @override
  String get accessMaxFailedAttempts => '最大失败次数';

  @override
  String get accessNewPasswordHint => '输入新密码';

  @override
  String get accessPasskeyConfiguredInfo =>
      '服务器已配置 Passkey。移动端暂不支持注册或管理 Passkey，请在网页端访问控制中操作。';

  @override
  String get accessPasskeyOnlyInfo =>
      '服务器当前仅允许 Passkey 登录，移动端暂不支持 Passkey 登录或管理，请在网页端访问控制中操作。';

  @override
  String get accessPasswordMinHint => '密码至少需要 4 位。';

  @override
  String get accessPasswordTooShort => '访问密码至少需要 8 位字符';

  @override
  String accessRangeError(String label, int min, int max) {
    return '$label 必须在 $min–$max 之间';
  }

  @override
  String get accessRebindTotp => '重新绑定 TOTP';

  @override
  String get accessRefreshDaysHelp => '范围 1-90 天；Access Token 固定 24 小时自动刷新。';

  @override
  String get accessRefreshTokenDays => '有效期';

  @override
  String get accessSectionMfa => '双重验证';

  @override
  String get accessSectionMfaHelp => '使用 TOTP 为敏感操作增加一层保护。';

  @override
  String get accessSectionProtection => '访问保护';

  @override
  String get accessSectionProtectionHelp => '设置进入应用时需要的本地验证方式。';

  @override
  String get accessSectionSession => '会话';

  @override
  String get accessSectionSessionHelp => '管理登录会话和自动退出行为。';

  @override
  String get accessSetPassword => '修改访问密码';

  @override
  String get accessSetPasswordHelp => '设置用于本地验证的密码。';

  @override
  String get accessStatusActive => '访问保护已启用';

  @override
  String get accessStatusActiveDesc => 'API、媒体资源与实时任务均需要有效登录会话。';

  @override
  String get accessStatusConfigured => '访问状态已配置';

  @override
  String get accessStatusConfiguredDesc => '保存并启用后，未登录访问将被拦截。';

  @override
  String get accessStatusNotConfigured => '尚未配置登录凭据';

  @override
  String get accessStatusNotConfiguredDesc => '设置至少一个登录凭据后即可启用访问控制。';

  @override
  String get accessTotpBoundDesc => '已绑定 TOTP，可用于双重验证。';

  @override
  String get accessTotpCode => '验证码';

  @override
  String get accessTotpCodeHint => '输入验证器中的验证码';

  @override
  String get accessTotpConfirmBind => '确认绑定 TOTP';

  @override
  String get accessTotpDeleted => 'TOTP 已删除';

  @override
  String get accessTotpEnabled => 'TOTP 已启用';

  @override
  String get accessTotpManualKey => '无法扫描时，可手动输入密钥：';

  @override
  String get accessTotpTwoFactor => 'TOTP 两步验证';

  @override
  String get accessTotpUnboundDesc => '尚未绑定 TOTP。';

  @override
  String get actorAssocActionAppendAlias => '追加别名';

  @override
  String get actorAssocActionSync => '同步';

  @override
  String actorAssocAvatarCandidate(int index) {
    return '候选头像 $index';
  }

  @override
  String actorAssocAvatarConfirm(int count) {
    return '确定（$count 张）';
  }

  @override
  String actorAssocAvatarPickerCount(String name, int selected, int total) {
    return '为“$name”选择头像（已选 $selected/$total）';
  }

  @override
  String actorAssocAvatarPickerCountWithFailed(
    String name,
    int selected,
    int total,
    int failed,
  ) {
    return '为“$name”选择头像（已选 $selected/$total，$failed 个加载失败）';
  }

  @override
  String get actorAssocAvatarPickerNameFallback => '未命名演员';

  @override
  String get actorAssocAvatarPickerTitle => '选择演员头像';

  @override
  String get actorAssocAvatarRetry => '点击重试';

  @override
  String actorAssocAvatarRetrySemantics(int index) {
    return '重试第 $index 张演员头像';
  }

  @override
  String get actorAssocAvatarSelected => '已选择头像';

  @override
  String actorAssocAvatarSelectSemantics(int index) {
    return '选择第 $index 张演员头像';
  }

  @override
  String get actorAssocDeletedToast => '演员关联已删除';

  @override
  String actorAssocDeleteFailed(String error) {
    return '删除失败：$error';
  }

  @override
  String actorAssocDeleteMessage(String name, int count) {
    return '确定删除“$name”及其 $count 个关联名称吗？';
  }

  @override
  String get actorAssocDeleteTitle => '删除演员关联';

  @override
  String get actorAssocDeselectAll => '取消全选';

  @override
  String get actorAssocEditorAliasHint => '多个值用换行分隔';

  @override
  String get actorAssocEditorAliasLabel => '别名';

  @override
  String get actorAssocEditorAliasPlaceholder => '一行一个, 或用 , ; 、 分隔';

  @override
  String get actorAssocEditorCanonicalExample => '填写标准演员名';

  @override
  String get actorAssocEditorCanonicalHint => '标准演员名用于匹配影片中的演员';

  @override
  String get actorAssocEditorCanonicalLabel => '标准演员';

  @override
  String get actorAssocEditorCanonicalLocked => '标准演员名已锁定';

  @override
  String get actorAssocEditorCreate => '创建';

  @override
  String actorAssocEditorExistingAliases(int count) {
    return '已有 $count 个关联名称，将在此基础上追加';
  }

  @override
  String get actorAssocEditorNewAliasLabel => '新增别名';

  @override
  String get actorAssocEditorSeparatorHint => '多个名称可用换行、逗号或分号分隔';

  @override
  String get actorAssocEditorTitleAppend => '追加别名';

  @override
  String get actorAssocEditorTitleCreate => '新建演员关联';

  @override
  String get actorAssocEditorTitleEdit => '编辑关联';

  @override
  String get actorAssocEmpty => '暂无演员关联';

  @override
  String get actorAssocErrAliasRequired => '请输入别名';

  @override
  String get actorAssocErrAtLeastOneAlias => '请至少添加一个关联名称';

  @override
  String get actorAssocErrNameRequired => '请输入演员名称';

  @override
  String get actorAssocNoNewAliases => '没有新的关联名称';

  @override
  String actorAssocSaved(String name) {
    return '已保存：$name';
  }

  @override
  String actorAssocSaveFailed(String name, String error) {
    return '保存“$name”失败：$error';
  }

  @override
  String get actorAssocSearchHint => '搜索演员关联';

  @override
  String get actorAssocSourceMixed => '混合来源';

  @override
  String get actorAssocSyncApply => '确认添加';

  @override
  String actorAssocSyncApplyFailed(String error) {
    return '同步应用失败：$error';
  }

  @override
  String get actorAssocSyncApplying => '正在添加…';

  @override
  String get actorAssocSyncAvatarExists => '已有头像';

  @override
  String get actorAssocSyncAvatarFailed => '获取头像失败';

  @override
  String get actorAssocSyncAvatarLabel => '演员头像';

  @override
  String get actorAssocSyncAvatarLoading => '正在获取头像...';

  @override
  String get actorAssocSyncAvatarLoadingReplace => '正在获取数据源头像，可多选后替换本地';

  @override
  String get actorAssocSyncAvatarNoneSelected => '未选择头像（点头像候选调整）';

  @override
  String actorAssocSyncAvatarWillReplace(int count) {
    return '将用已选 $count 张头像替换当前头像';
  }

  @override
  String actorAssocSyncAvatarWillSync(int count) {
    return '将同步 $count 张头像';
  }

  @override
  String get actorAssocSyncCanonicalLabel => '标准演员';

  @override
  String get actorAssocSyncDone => '同步完成';

  @override
  String get actorAssocSyncExistingTitle => '已有关联';

  @override
  String actorAssocSyncNewAliasesTitle(int selected, int total) {
    return '新关联名称（已选 $selected/$total）';
  }

  @override
  String actorAssocSyncNoMatchHint(String name) {
    return '未找到“$name”的匹配结果';
  }

  @override
  String get actorAssocSyncNoMatchTitle => '没有匹配结果';

  @override
  String get actorAssocSyncNoNewAliases => '没有可添加的新名称';

  @override
  String get actorAssocSyncNoPreviewHint => '暂无预览内容';

  @override
  String get actorAssocSyncNoPreviewTitle => '暂无预览';

  @override
  String get actorAssocSyncPickAvatar => '选择演员头像';

  @override
  String get actorAssocSyncRequestFailed => '请求失败';

  @override
  String get actorAssocSyncSourceFailed => '请求失败';

  @override
  String get actorAssocSyncSourceNoMatch => '无匹配';

  @override
  String get actorAssocSyncSourceQuerying => '查询中';

  @override
  String get actorAssocSyncSourcesRequired =>
      '请先在服务器设置中配置并启用 DB Online 或 AVDB 数据源';

  @override
  String get actorAssocSyncMixedFailed => '混合渠道查询失败';

  @override
  String get actorAssocSyncPreviewTimedOut => '混合渠道预览超时';

  @override
  String get actorAssocSyncSourcesLabel => '数据源';

  @override
  String get actorAssocSyncSourcesLoading => '正在加载数据源…';

  @override
  String get actorAssocSyncSubtitle => '同步演员关联';

  @override
  String actorAssocSyncTitle(String name) {
    return '同步演员：$name';
  }

  @override
  String get actorAssocTitle => '演员关联管理';

  @override
  String get actorEditorBiographyLabel => '演员简介';

  @override
  String get appLogClear => '清空日志';

  @override
  String get appLogCleared => '日志已清空';

  @override
  String get appLogClearSub => '清空后重新复现，可减少无关信息';

  @override
  String get appLogContent => '日志内容';

  @override
  String get appLogCopied => '日志已复制';

  @override
  String get appLogCopyAll => '复制全部日志';

  @override
  String appLogCount(int count) {
    return '日志（$count）';
  }

  @override
  String get appLogEmpty => '暂无日志';

  @override
  String get appLogEmptyHint => '暂无日志\n先播放一次 SMB / WebDAV 视频';

  @override
  String get appLogSubtitle => '复现问题后返回此页，复制日志发给开发者分析';

  @override
  String get appLogTitle => '播放日志';

  @override
  String get audioActionCancelExtraction => '取消提取';

  @override
  String get audioActionCancelTranscription => '取消转录';

  @override
  String get audioActionDeleteAudio => '删除音频';

  @override
  String get audioActionEnqueueTranscription => '加入转译';

  @override
  String get audioActionRetryTranscription => '重试转录';

  @override
  String get audioAssetCountSuffix => '个音频资产';

  @override
  String audioCancelExtractionFailed(String error) {
    return '取消提取失败：$error';
  }

  @override
  String get audioCancelExtractionSubmitted => '已提交取消提取';

  @override
  String get audioCancelSubmitted => '已提交取消任务';

  @override
  String audioCancelTranscriptionFailed(String error) {
    return '取消转录失败：$error';
  }

  @override
  String get audioDeleteBatchAction => '批量删除';

  @override
  String get audioDeleteBatchTitle => '批量删除音频';

  @override
  String audioDeleted(int count) {
    return '已删除 $count 个音频资产';
  }

  @override
  String audioDeleteFailed(String error) {
    return '删除音频失败：$error';
  }

  @override
  String get audioDeleteFileFallback => '音频文件';

  @override
  String audioDeleteMessageBatch(int count) {
    return '确定删除已选的 $count 个音频文件吗？';
  }

  @override
  String audioDeleteMessageSingle(String name) {
    return '确定删除“$name”吗？';
  }

  @override
  String audioDeleteResult(int deleted, String rejected) {
    return '删除完成：成功 $deleted 个，$rejected';
  }

  @override
  String get audioDeleteTitle => '删除音频';

  @override
  String get audioEmptyHint => '从影片中提取音频后即可在此查看';

  @override
  String get audioEmptySearchHint => '没有匹配的音频文件';

  @override
  String get audioEmptySearchTitle => '未找到音频';

  @override
  String get audioEmptyTitle => '暂无音频文件';

  @override
  String get audioEnqueueBatchTitle => '批量加入转录任务';

  @override
  String get audioEnqueueConfirm => '确认加入转录队列';

  @override
  String audioEnqueued(int count) {
    return '已加入 $count 个字幕转译任务';
  }

  @override
  String audioEnqueuedMixed(int accepted, String rejected) {
    return '已加入 $accepted 个任务 · $rejected';
  }

  @override
  String audioEnqueueFailed(String error) {
    return '加入转录任务失败：$error';
  }

  @override
  String audioEnqueueMessageBatch(int count) {
    return '将 $count 个音频资产加入云端转译队列。';
  }

  @override
  String audioEnqueueMessageSingle(String name) {
    return '确定为“$name”创建转录任务吗？';
  }

  @override
  String get audioEnqueueTitle => '加入转录任务';

  @override
  String get audioExtractingSection => '正在提取音频';

  @override
  String get audioEyebrow => '媒体工具';

  @override
  String get audioFileMissing => '文件缺失';

  @override
  String get audioOverwriteExistingSubtitle => '覆盖已有字幕';

  @override
  String get audioRequeued => '已重新加入队列';

  @override
  String audioRetryFailed(String error) {
    return '重试转录失败：$error';
  }

  @override
  String audioRetryMessage(String name) {
    return '重新提交「$name」的字幕转译任务。';
  }

  @override
  String get audioRetryTitle => '重试';

  @override
  String get audioSearchHint => '搜索音频';

  @override
  String audioSearchSubtitle(String query) {
    return '搜索：$query';
  }

  @override
  String get audioStageCanceled => '已取消';

  @override
  String get audioStageCompleted => '已完成';

  @override
  String get audioStageConnecting => '连接中';

  @override
  String get audioStageDownloading => '下载中';

  @override
  String get audioStageFailed => '失败';

  @override
  String get audioStagePreparing => '准备中';

  @override
  String get audioStageQueued => '排队中';

  @override
  String get audioStageRegistering => '注册中';

  @override
  String get audioStageSandbox => '沙盒处理中';

  @override
  String get audioStageSkipped => '已跳过';

  @override
  String get audioStageStarting => '启动中';

  @override
  String get audioStageTranscribing => '转录中';

  @override
  String get audioStageTranscribingFallback => '转录中（备用）';

  @override
  String get audioStageUploading => '上传中';

  @override
  String get audioStatusCanceled => '已取消';

  @override
  String get audioStatusFailed => '失败';

  @override
  String get audioStatusNotTranscribed => '未转译';

  @override
  String get audioStatusTranscribed => '已转译';

  @override
  String get audioSubtitle => '音频转录';

  @override
  String get audioTaskExtracting => '音频提取';

  @override
  String get audioTaskQueued => '音频转录';

  @override
  String get audioTitle => '音频';

  @override
  String get audioTranscriptionCanceledHint => '转录任务已取消';

  @override
  String get avdbEnableOff => '已停用 AVDB';

  @override
  String get avdbEnableOn => '演员同步可选择 AVDB';

  @override
  String get avdbEnableTitle => '启用 AVDB 数据源';

  @override
  String get avdbKeyConfigured => '已配置 · 留空则保留当前密钥';

  @override
  String get avdbKeyHide => '隐藏密钥';

  @override
  String get avdbKeyKeepHint => '留空保留当前密钥';

  @override
  String get avdbKeyPrompt => 'API 密钥';

  @override
  String get avdbKeyShow => '显示 API 密钥';

  @override
  String get avdbSavedToast => 'AVDB 配置已保存';

  @override
  String get avdbServerSection => '服务地址';

  @override
  String get avdbStatusSection => '启用状态';

  @override
  String get avdbSubtitle => '用于演员关联同步。请先配置并启用 AVDB 数据源。';

  @override
  String get avdbTitle => 'AVDB 数据源';

  @override
  String get badgePreviewMovieTitle => '影片标题';

  @override
  String get cacheCategoryImage => '图片';

  @override
  String get cacheCategoryOther => '其他缓存';

  @override
  String get codecUnknown => '编码未知';

  @override
  String get commonActions => '操作';

  @override
  String get commonChange => '更改';

  @override
  String get commonClear => '清空';

  @override
  String get commonDownloading => '下载中';

  @override
  String get commonHidePassword => '隐藏密码';

  @override
  String get commonIgnore => '忽略';

  @override
  String get commonIosOnly => '仅支持 iOS';

  @override
  String get commonLater => '稍后';

  @override
  String get commonShowPassword => '显示密码';

  @override
  String get configInputPrompt => '配置输入提示词';

  @override
  String get configSavedToast => '配置已保存';

  @override
  String dboAgePreview(String years) {
    return '最大年龄：$years 年';
  }

  @override
  String get dboApiKeyConfiguredHint => '已配置 · 留空则保留';

  @override
  String get dboBaseUrlExampleHint => '例: http://10.0.0.50:9090';

  @override
  String get dboEnabledHelpOff => '关闭后将不会使用 DB Online 数据源。';

  @override
  String get dboEnabledHelpOn => '启用后可从 DB Online 获取影片信息。';

  @override
  String get dboEnabledLabel => '启用 DB Online';

  @override
  String get dboEnableSwitchLabel => '启用 DB Online';

  @override
  String get dboErrBothSet => '不能同时设置最大年龄和资源月份';

  @override
  String get dboErrMonthFormat => '请输入 YYYY-MM 格式的月份';

  @override
  String get dboFilterLast10Years => '近 10 年';

  @override
  String get dboFilterLast2Years => '近 2 年';

  @override
  String get dboFilterLast5Years => '近 5 年';

  @override
  String get dboFilterLastYear => '近 1 年';

  @override
  String get dboFilterNoFilter => '不过滤';

  @override
  String get dboMonthsUnit => '月';

  @override
  String get dboNewApiKeyHint => '输入新的 API Key';

  @override
  String get dboResourceFilterHelp => '限制可用于匹配的资源类型。';

  @override
  String get dboResourceFilterLabel => '资源过滤器';

  @override
  String get dboStartMonthHelp => '设置从哪个月份开始同步数据。';

  @override
  String get dboStartMonthHint => '例如 2024-01';

  @override
  String get dboStartMonthLabel => '起始年月';

  @override
  String get dboSubtitle => 'Base URL + API Key,用于影片信息、资源和演员关联同步';

  @override
  String get favoritesEmptyHint => '收藏影片会显示在这里';

  @override
  String get favoritesEmptyTitle => '暂无收藏';

  @override
  String get favoritesRemoveAction => '移除收藏';

  @override
  String favoritesRemoveBatchFailed(String error) {
    return '批量移除收藏失败：$error';
  }

  @override
  String favoritesRemoveConfirm(int count) {
    return '确定移除已选的 $count 部影片吗？';
  }

  @override
  String favoritesRemovedN(int count) {
    return '已移除 $count 部';
  }

  @override
  String favoritesRemovedOne(String name) {
    return '已移除收藏：$name';
  }

  @override
  String favoritesRemoveFailed(String error) {
    return '移除收藏失败：$error';
  }

  @override
  String get favoritesRemoveTitle => '移除收藏';

  @override
  String favoritesScanConfirm(int count) {
    return '确定扫描 $count 部收藏影片吗？';
  }

  @override
  String favoritesScanCreateFailed(String error) {
    return '创建扫描任务失败：$error';
  }

  @override
  String favoritesScanSkippedSuffix(int count) {
    return '，跳过 $count 部无效影片';
  }

  @override
  String get favoritesScanStart => '开始扫描';

  @override
  String favoritesScanSubmitted(int count) {
    return '已提交 $count 个扫描任务';
  }

  @override
  String get favoritesScanTitle => '扫描收藏影片';

  @override
  String get favoritesScanTooltip => '扫描收藏影片';

  @override
  String get favoritesSortRating => '按评分排序';

  @override
  String get favoritesSortRecent => '最近收藏';

  @override
  String get favoritesSortSheetTitle => '收藏排序';

  @override
  String get favoritesSortTitle => '排序收藏';

  @override
  String get favoritesSortYearDesc => '年份（从新到旧）';

  @override
  String get ffmpegAudioSection => '音频提取';

  @override
  String get ffmpegAudioThreadsSubtitle => '每个 FFmpeg 音频编码任务使用的线程数。';

  @override
  String get ffmpegAudioThreadsTitle => '音频提取编码线程数';

  @override
  String get ffmpegAudioWorkersSubtitle => '同时执行的音频提取任务数量。';

  @override
  String get ffmpegAudioWorkersTitle => '音频提取最大并发任务数';

  @override
  String get ffmpegFallbackOff => '关闭回退';

  @override
  String get ffmpegFallbackOn => '启用回退';

  @override
  String get ffmpegFallbackTitle => '硬解失败自动回退';

  @override
  String get ffmpegHwBackendLabel => '硬件后端';

  @override
  String get ffmpegHwEnableTitle => '启用硬件解码';

  @override
  String get ffmpegHwNone => '不使用硬件加速';

  @override
  String get ffmpegHwOff => '关闭硬件解码';

  @override
  String get ffmpegHwOn => '启用硬件解码';

  @override
  String get ffmpegHwSection => '硬件解码';

  @override
  String ffmpegPathHint(String name) {
    return '选择 $name 路径';
  }

  @override
  String get ffmpegPathsSection => 'FFmpeg 路径';

  @override
  String get ffmpegSavedToast => 'FFmpeg 配置已保存';

  @override
  String get ffmpegSubtitle => '配置服务端转码、硬件解码和硬解失败回退策略。';

  @override
  String get ffmpegTitle => 'FFmpeg 与硬解';

  @override
  String libraryBatchAccepted(int count, String scanType) {
    return '已提交 $count 个媒体库的$scanType';
  }

  @override
  String libraryBatchFailedShort(int count) {
    return ' · $count 个提交失败';
  }

  @override
  String get libraryBatchNoEnabled => '没有启用的媒体库';

  @override
  String libraryBatchNoTasks(String scanType) {
    return '没有可提交的$scanType任务';
  }

  @override
  String libraryBatchReused(int count) {
    return ' · $count 个复用现有任务';
  }

  @override
  String libraryBatchScanFailed(String error) {
    return '批量扫描失败：$error';
  }

  @override
  String get libraryBatchScanFull => '批量全量扫描';

  @override
  String get libraryBatchScanIncremental => '一键增量扫描';

  @override
  String get libraryBatchScanTitle => '批量扫描（仅启用媒体库）';

  @override
  String libraryBatchSkippedDisabled(int count) {
    return ' · 已忽略 $count 个停用媒体库';
  }

  @override
  String libraryBatchSubmitFailedCount(int count) {
    return '，$count 个媒体库提交失败';
  }

  @override
  String libraryCardMeta(int files, int directories) {
    return '$files 个文件 · $directories 个目录';
  }

  @override
  String get libraryCreatedToast => '媒体库已创建';

  @override
  String libraryDefaultDirName(int index) {
    return '目录 $index';
  }

  @override
  String libraryDeleteConfirm(String name) {
    return '确定删除媒体库“$name”吗？';
  }

  @override
  String get libraryDeletedToast => '媒体库已删除';

  @override
  String libraryDeleteFailed(String error) {
    return '删除媒体库失败：$error';
  }

  @override
  String get libraryDeleteTitle => '删除媒体库';

  @override
  String get libraryDisable => '停用';

  @override
  String get libraryDisabledBadge => '已禁用';

  @override
  String get libraryDisabledToast => '媒体库已禁用';

  @override
  String get libraryEditorAddDir => '添加目录';

  @override
  String get libraryEditorEnableHint => '停用媒体库后不会参与扫描和展示。';

  @override
  String get libraryEditorNameHint => '例: 我的电影';

  @override
  String get libraryEditorTitleEdit => '编辑媒体库';

  @override
  String get libraryEditorTitleNew => '新建媒体库';

  @override
  String get libraryEmptyHint => '创建媒体库后开始扫描媒体';

  @override
  String get libraryEmptyTitle => '暂无媒体库';

  @override
  String get libraryEnable => '启用';

  @override
  String get libraryEnabledToast => '媒体库已启用';

  @override
  String libraryErrDirDuplicate(String path) {
    return '目录路径重复: $path';
  }

  @override
  String get libraryErrDirRequired => '至少需要一个目录';

  @override
  String get libraryErrNameRequired => '请填写媒体库名称';

  @override
  String libraryErrNotDirectory(String path) {
    return '不是目录：$path';
  }

  @override
  String libraryErrPathNotFound(String path) {
    return '路径不存在：$path';
  }

  @override
  String libraryErrPathUsed(String path) {
    return '路径已被使用：$path';
  }

  @override
  String get libraryManageTitle => '管理媒体库';

  @override
  String get libraryMoviesEmpty => '暂无影片';

  @override
  String get libraryScan => '扫描';

  @override
  String libraryScanFailed(String error) {
    return '扫描失败：$error';
  }

  @override
  String get libraryScanFull => '全量扫描';

  @override
  String get libraryScanFullStarted => '已开始全量扫描';

  @override
  String get libraryScanIncremental => '增量扫描';

  @override
  String get libraryScanIncrementalStarted => '已开始增量扫描';

  @override
  String libraryScanSheetTitle(String name) {
    return '扫描媒体库：$name';
  }

  @override
  String get librarySubmitting => '提交中';

  @override
  String get listActionsTitle => '操作';

  @override
  String get listAddToTitle => '添加到列表';

  @override
  String get listCreate => '创建列表';

  @override
  String get listDelete => '删除列表';

  @override
  String get listDeleteConfirmBody => '确定删除此列表吗？';

  @override
  String get listEmptyHint => '创建列表来整理收藏内容';

  @override
  String get listEmptyTitle => '暂无列表';

  @override
  String listHeroCount(int count) {
    return '$count 部影片';
  }

  @override
  String get listHeroEyebrow => '影片列表';

  @override
  String get listMissing => '列表不存在';

  @override
  String get listNameHint => '列表名称';

  @override
  String listRemoveConfirm(String name) {
    return '确定从列表中移除“$name”吗？';
  }

  @override
  String get listRemoveTitle => '从列表移除';

  @override
  String get listRename => '重命名';

  @override
  String get listRenameTitle => '重命名列表';

  @override
  String get mappingBadgeConvert => '转换映射';

  @override
  String mappingBatchDeleteConfirm(int count) {
    return '确定删除已选的 $count 条映射吗？';
  }

  @override
  String mappingBatchDeleted(int count) {
    return '已删除 $count 条映射';
  }

  @override
  String mappingBatchDeleteFailed(String error) {
    return '批量删除映射失败：$error';
  }

  @override
  String get mappingBatchDeleteTitle => '批量删除映射';

  @override
  String get mappingCountSuffix => '条映射';

  @override
  String get mappingCreatedToast => '映射已创建';

  @override
  String get mappingDeletedToast => '映射已删除';

  @override
  String mappingDeleteFailed(String error) {
    return '删除映射失败：$error';
  }

  @override
  String mappingDeleteRuleConfirm(String name) {
    return '确定删除映射“$name”吗？';
  }

  @override
  String get mappingDeleteRuleTitle => '删除映射规则';

  @override
  String mappingEditorTitleEdit(String type) {
    return '编辑$type映射';
  }

  @override
  String mappingEditorTitleNew(String type) {
    return '新建$type映射';
  }

  @override
  String get mappingEmptyHint => '还没有映射规则';

  @override
  String mappingEmptyTitle(String type) {
    return '暂无$type映射';
  }

  @override
  String get mappingFilterConvert => '转换规则';

  @override
  String get mappingFilterDelete => '删除规则';

  @override
  String get mappingMappedDeleteHint => '删除映射后的值';

  @override
  String get mappingMappedHint => '输入映射后的值';

  @override
  String get mappingMappedPlaceholder => '请输入映射后的值';

  @override
  String get mappingMappedValueEyebrow => '映射后值';

  @override
  String get mappingOriginalMultiHint => '可填写多个原始值，每行一个';

  @override
  String get mappingOriginalMultiPlaceholder => '输入多个原始值';

  @override
  String get mappingOriginalPlaceholder => '输入原始值';

  @override
  String get mappingOriginalSingleHint => '填写需要替换的原始值';

  @override
  String get mappingOriginalValuesEyebrow => '原始值';

  @override
  String get mappingSearchHint => '搜索映射规则';

  @override
  String get mappingSummaryDiscard => '放弃更改';

  @override
  String mappingTypeTitle(String type) {
    return '$type映射';
  }

  @override
  String get mediaBrowserContainer => '容器';

  @override
  String get mediaBrowserDetails => '详情';

  @override
  String get mediaBrowserDirectors => '导演';

  @override
  String mediaBrowserEpisodeNumber(int number) {
    return '第 $number 集';
  }

  @override
  String get mediaBrowserEpisodes => '集数';

  @override
  String mediaBrowserEpisodeWithRuntime(int number, int minutes) {
    return '第 $number 集 · $minutes 分钟';
  }

  @override
  String get mediaBrowserFilePath => '文件路径';

  @override
  String get mediaBrowserFileSize => '文件大小';

  @override
  String get mediaBrowserGenres => '类型';

  @override
  String get mediaBrowserMediaInfo => '媒体信息';

  @override
  String get mediaBrowserMediaSources => '片源';

  @override
  String mediaBrowserMediaSourceNumber(int number) {
    return '片源 $number';
  }

  @override
  String get mediaBrowserVideoParts => '分集';

  @override
  String get mediaBrowserPlayAllParts => '连续播放全部分集';

  @override
  String mediaBrowserVideoPartNumber(int number) {
    return '第 $number 分集';
  }

  @override
  String get mediaBrowserNextUp => '接下来播放';

  @override
  String get mediaBrowserNoEpisodesInSeason => '本季暂无剧集';

  @override
  String get mediaBrowserNoSeasons => '暂无季';

  @override
  String get mediaBrowserOriginalTitle => '原名';

  @override
  String get mediaBrowserSearchHint => '搜索电影、剧集、音乐…';

  @override
  String mediaBrowserSeasonNumber(int number) {
    return '第 $number 季';
  }

  @override
  String get mediaBrowserSeriesLabel => '所属剧集';

  @override
  String get mediaBrowserSpecialSeason => '特别篇';

  @override
  String get mediaBrowserTranscodePlay => '转码播放';

  @override
  String get mediaBrowserTypeBooks => '书籍';

  @override
  String get mediaBrowserTypeHomeVideos => '家庭视频';

  @override
  String get mediaBrowserTypePhotos => '照片';

  @override
  String get mediaBrowserTypeUnknown => '未知类型';

  @override
  String mediaBrowserTypeUnknownWithValue(String value) {
    return '未知类型（$value）';
  }

  @override
  String get mediaBrowserNow => '现在';

  @override
  String mediaBrowserEpisodeCount(int count) {
    return '$count集';
  }

  @override
  String mediaBrowserTrackCount(int count) {
    return '$count 首';
  }

  @override
  String mediaDurationMinutes(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String get mediaBrowserEmptyDefault => '暂无内容';

  @override
  String mediaBrowserUpdatedNItems(int count) {
    return '已更新 $count 个条目';
  }

  @override
  String mediaBrowserUpdatedNItemsWithFailed(int count, int failed) {
    return '已更新 $count 个条目，$failed 个失败';
  }

  @override
  String get mediaBrowserWatched => '已看';

  @override
  String operationFailed(String error) {
    return '操作失败：$error';
  }

  @override
  String get playerAudioNowPlaying => '正在播放';

  @override
  String get playerAudioPlaybackFailed => '音频播放失败';

  @override
  String playerDebugAudioBitrate(String value) {
    return '音频码率：$value';
  }

  @override
  String playerDebugAudioCodec(String value) {
    return '音频编码：$value';
  }

  @override
  String playerDebugContainer(String value) {
    return '容器：$value';
  }

  @override
  String playerDebugDecoder(String value) {
    return '解码器：$value';
  }

  @override
  String playerDebugEngine(String value) {
    return '播放器内核：$value';
  }

  @override
  String playerDebugFps(String value) {
    return '帧率：$value';
  }

  @override
  String playerDebugInternalPlayer(String value) {
    return '内部播放器：$value';
  }

  @override
  String playerDebugResolution(String value) {
    return '分辨率：$value';
  }

  @override
  String playerDebugVideoBitrate(String value) {
    return '视频码率：$value';
  }

  @override
  String playerDebugVideoCodec(String value) {
    return '视频编码：$value';
  }

  @override
  String get playerDecisionMissing => '播放决策缺少 direct_url';

  @override
  String get playerDecodeLocalHardware => '本地硬解';

  @override
  String get playerDecodeLocalSoftware => '本地软解';

  @override
  String get playerDecodeServerHardware => '服务端硬解';

  @override
  String get playerDecodeServerSoftware => '服务端软解';

  @override
  String get playerDecodeServerSoftwareFallback => '服务端软解回退';

  @override
  String get playerEngineAudio => '音频播放内核';

  @override
  String get playerErrorCopied => '播放器错误已复制';

  @override
  String get playerErrorCopy => '复制';

  @override
  String get playerErrorCopyFailed => '复制失败';

  @override
  String get playerErrorCopyFull => '复制完整错误信息';

  @override
  String get playerErrorDetailsTitle => '完整错误详情';

  @override
  String get playerErrorExport => '导出';

  @override
  String get playerErrorExportFailed => '导出播放错误失败，可尝试复制完整错误';

  @override
  String get playerErrorExportFull => '导出完整错误信息';

  @override
  String get playerErrorExportUnsupported => '当前设备不支持导出，请复制完整错误';

  @override
  String get playerErrorShareBody => 'Oh My Media 播放错误日志';

  @override
  String get playerErrorShareSubject => 'Oh My Media 播放错误';

  @override
  String get playerErrorTitle => '播放失败';

  @override
  String get playerErrorViewDetails => '查看详情';

  @override
  String get playerExit => '退出播放器';

  @override
  String get playerExitPlayback => '退出播放';

  @override
  String get playerFramePreviewUnavailable => '当前无法预览画面';

  @override
  String get playerLoadingVideo => '正在加载视频';

  @override
  String get playerNetworkCellular => '蜂窝网络';

  @override
  String get playerNetworkEthernet => '以太网';

  @override
  String get playerNetworkOffline => '离线';

  @override
  String get playerNetworkUnknown => '未知网络';

  @override
  String get playerNextMedia => '下一个媒体';

  @override
  String get playerNextTrack => '下一曲';

  @override
  String get playerPictureInPicture => '画中画';

  @override
  String get playerPipEngineUnsupported => '当前播放内核不支持画中画';

  @override
  String get playerPipSourceUnsupported => '当前媒体源不支持画中画';

  @override
  String get playerPipStartFailed => '启动画中画失败';

  @override
  String playerPlaybackSpeed(String rate) {
    return '播放速度：$rate';
  }

  @override
  String get playerPreviousMedia => '上一个媒体';

  @override
  String get playerPreviousTrack => '上一曲';

  @override
  String get playerQualityAuto => '自动';

  @override
  String get playerSeekBack10Seconds => '快退 10 秒';

  @override
  String get playerSeekForward10Seconds => '快进 10 秒';

  @override
  String get playerSelectAudioTrack => '选择音频轨道';

  @override
  String get playerSelectQuality => '选择画质';

  @override
  String get playerSelectSubtitle => '选择字幕';

  @override
  String playerSliderPosition(String position) {
    return '播放位置：$position';
  }

  @override
  String playerSliderPositionBuffered(String position, String buffered) {
    return '播放位置：$position，已缓冲至 $buffered';
  }

  @override
  String playerSpeedActive(String rate) {
    return '速度 $rate';
  }

  @override
  String playerSubtitleLoadFailed(String error) {
    return '字幕加载失败：$error';
  }

  @override
  String playerSubtitleLoadFailedContinue(String error) {
    return '字幕加载失败，继续播放：$error';
  }

  @override
  String get playerSubtitleName => '字幕名称';

  @override
  String get playerSubtitleOff => '关闭字幕';

  @override
  String get playerSwitchToLandscape => '切换为横屏';

  @override
  String get playerSwitchToPortrait => '切换为竖屏';

  @override
  String get scanActionFailed => '操作失败';

  @override
  String get scanBackgroundButton => '后台';

  @override
  String get scanCancelFailed => '取消失败';

  @override
  String get scanClose => '关闭';

  @override
  String get scanCurrentEyebrow => '当前扫描';

  @override
  String get scanDoneClose => '完成并关闭';

  @override
  String get scanFailedClose => '关闭并返回';

  @override
  String get scanPause => '暂停';

  @override
  String get scanPauseFailed => '暂停失败';

  @override
  String get scanPreparing => '准备中';

  @override
  String get scanProgressTitle => '扫描进度';

  @override
  String get scanResume => '继续';

  @override
  String get scanResumeFailed => '恢复失败';

  @override
  String get scanStatAdded => '新增';

  @override
  String get scanStatRemoved => '已移除';

  @override
  String get scanStatUpdated => '更新';

  @override
  String get securityAppPassword => '进入密码';

  @override
  String get securityBiometricDisabled => '生物识别已禁用';

  @override
  String get securityBiometricNeedsPin => '请先设置数字密码';

  @override
  String get securityBiometricOnDesc => '使用生物识别解锁应用';

  @override
  String get securityBiometricUnavailable => '当前设备不支持生物识别';

  @override
  String securityBiometricUpdateFailed(String error) {
    return '生物识别更新失败：$error';
  }

  @override
  String get securityClearConfirmBody => '清除安全设置后，将无法使用已配置的本地验证方式。';

  @override
  String securityClearFailed(String error) {
    return '清理安全设置失败：$error';
  }

  @override
  String get securityClearGesture => '清除手势密码';

  @override
  String get securityClearPinRequiresBiometricDisabled => '请先关闭生物识别，再清除进入密码';

  @override
  String get securityClearPin => '清除数字密码';

  @override
  String get securityGestureMin => '手势密码至少需要 4 个点';

  @override
  String get securityGesturePassword => '手势密码';

  @override
  String get securityGestureSaved => '手势密码已保存';

  @override
  String securityGestureSaveFailed(String error) {
    return '保存手势密码失败：$error';
  }

  @override
  String get securityGestureSet => '手势密码已设置';

  @override
  String securityLoadFailed(String error) {
    return '加载安全设置失败：$error';
  }

  @override
  String get securityLockVerifyDesc => '配置任意一种方式后，应用启动和回到前台时会要求验证。';

  @override
  String get securityLockVerifyTitle => '应用锁定时验证';

  @override
  String get securityNotSet => '未设置';

  @override
  String get securityPatternEnterAgain => '请再次绘制手势密码';

  @override
  String get securityPatternEnterFirst => '请先绘制手势密码';

  @override
  String get securityPatternMismatch => '两次绘制的手势密码不一致';

  @override
  String get securityPatternTooFew => '手势密码至少需要 4 个点';

  @override
  String get securityPinEnterAgain => '请再次输入数字密码';

  @override
  String get securityPinEnterFirst => '请输入数字密码';

  @override
  String get securityPinInvalid => '数字密码错误';

  @override
  String get securityPinMismatch => '两次输入的数字密码不一致';

  @override
  String get securityPinSaved => '数字密码已保存';

  @override
  String securityPinSaveFailed(String error) {
    return '保存数字密码失败：$error';
  }

  @override
  String get securityPinSet => '数字密码已设置';

  @override
  String get securitySetPatternTitle => '设置手势密码';

  @override
  String get securitySetPinFirst => '设置数字密码';

  @override
  String get securitySetPinTitle => '设置数字密码';

  @override
  String get securitySettingsSub => '配置进入 Oh My Media 时使用的本地验证方式';

  @override
  String get securityUnlockMethodCleared => '解锁方式已清除';

  @override
  String get securityUnlockMethods => '解锁方式';

  @override
  String get securityUsageNotes => '使用说明';

  @override
  String get settingsAppUpdate => '应用更新';

  @override
  String get settingsAppUpdateSub => '填写 GitHub 仓库地址，自动检查对应平台的安装包';

  @override
  String get settingsCacheCategories => '缓存分类';

  @override
  String get settingsCacheCleanAll => '一键清理';

  @override
  String get settingsCacheClearAllBody => '将清理全部缓存内容。';

  @override
  String get settingsCacheClearAllTitle => '清理全部缓存';

  @override
  String get settingsCacheCleared => '缓存已清理';

  @override
  String get settingsCacheTotal => '缓存总量';

  @override
  String get settingsCacheTotalSize => '总缓存大小';

  @override
  String get settingsCheckUpdateFailed => '检查更新失败';

  @override
  String get settingsChoosePlayerEngine => '选择播放器内核';

  @override
  String get settingsClearUpdateSource => '清除更新来源';

  @override
  String get settingsClearUpdateSourceBody => '清除已保存的更新来源设置？';

  @override
  String get settingsClearUpdateSourceTitle => '清除更新来源';

  @override
  String get settingsCurrentCache => '当前缓存';

  @override
  String get settingsCurrentVersion => '当前版本';

  @override
  String get settingsDebug => '调试';

  @override
  String get settingsDevM3u8Title => '开发接口 · m3u8';

  @override
  String get settingsDevTools => '开发接口';

  @override
  String get settingsDownloadAndInstall => '下载并安装';

  @override
  String settingsDownloadingPercent(int percent) {
    return '正在下载… $percent%';
  }

  @override
  String settingsDownloadingUpdatePercent(int percent) {
    return '正在下载更新… $percent%';
  }

  @override
  String get settingsDownloadUpdateFailed => '下载更新失败';

  @override
  String get settingsEditUpdateSource => '编辑更新来源';

  @override
  String get settingsGithubRepoLabel => 'GitHub 仓库地址';

  @override
  String get settingsIncludeDevelopment => '检测开发版';

  @override
  String get settingsIncludeDevelopmentSub => '开启后同时检测标准版与开发版，并选择版本更高的安装包';

  @override
  String get settingsInstalledVersion => '已安装版本';

  @override
  String get settingsInstallerOpened => '安装程序已打开';

  @override
  String get settingsInstallUpdate => '安装更新';

  @override
  String get settingsIosInstallerOpened => 'iOS 安装程序已打开';

  @override
  String get settingsKsPlayerIosOnly => 'KSPlayer 仅支持 iOS';

  @override
  String get settingsKsPlayerIosOnlyError => 'KSPlayer 仅支持 iOS，请选择 libmpv';

  @override
  String get settingsM3u8Hint => '输入 M3U8 播放地址';

  @override
  String get settingsM3u8Invalid => '请输入有效的 http/https m3u8 地址';

  @override
  String get settingsM3u8UrlLabel => 'm3u8 地址';

  @override
  String get settingsNewVersionFound => '发现新版本';

  @override
  String get settingsNoUpdateNotes => '暂无更新说明';

  @override
  String get settingsOpeningInstaller => '正在打开安装器…';

  @override
  String get settingsPlatformNotSupported => '当前平台不支持此操作';

  @override
  String get settingsPlayerDebugMode => '播放器 Debug 模式';

  @override
  String get settingsPlayerDebugModeSub => '在播放画面显示内核、编码、码率、帧率等信息';

  @override
  String get settingsPlayerEngine => '播放器内核';

  @override
  String get settingsPlayM3u8 => '播放 M3U8';

  @override
  String get settingsSaveDevPrefFailed => '保存开发者设置失败';

  @override
  String get settingsSaveIgnoreFailed => '保存忽略设置失败';

  @override
  String get settingsSaveUpdateSource => '保存更新来源';

  @override
  String get settingsSaveUpdateSourceFailed => '保存更新来源失败';

  @override
  String get settingsUpdateFailed => '更新失败';

  @override
  String settingsUpdateFound(String version) {
    return '发现新版本 $version';
  }

  @override
  String get settingsUpdateNotesTitle => '本次构建包含以下更新：';

  @override
  String get settingsUpdateNow => '立即更新';

  @override
  String get settingsUpdateResult => '检测结果';

  @override
  String get settingsUpdateSource => '更新来源';

  @override
  String get settingsUpdateSourceCleared => '更新源已清除';

  @override
  String get settingsUpdateSourceHint => '输入 GitHub 仓库或更新地址';

  @override
  String get settingsUpdateSourceSaved => '更新来源已保存';

  @override
  String get settingsUpToDate => '已是最新版本';

  @override
  String get settingsViewPlaybackLogs => '查看播放日志';

  @override
  String get settingsViewPlaybackLogsSub => 'SMB / WebDAV 视频持续加载时，复制日志给开发者';

  @override
  String get statMinutes => '分钟';

  @override
  String get subtitleDecrease => '减少';

  @override
  String get subtitleDelayOffset => '延迟偏移';

  @override
  String subtitleEditField(String field) {
    return '编辑$field';
  }

  @override
  String get subtitleIncrease => '增加';

  @override
  String get subtitleInvalidNumber => '请输入有效数字';

  @override
  String get subtitleLandscape => '横屏字幕';

  @override
  String get subtitleNoLimit => '无限制';

  @override
  String get subtitleOpacity => '不透明度';

  @override
  String subtitleOrientationHint(String orientation) {
    return '当前调节：$orientation';
  }

  @override
  String get subtitlePortrait => '竖屏字幕';

  @override
  String subtitleRange(String range) {
    return '范围：$range';
  }

  @override
  String get subtitleResetForPlayback => '恢复本次播放默认';

  @override
  String get subtitleSizeScale => '大小缩放';

  @override
  String get subtitleSourceEmbedded => '内嵌字幕';

  @override
  String get subtitleSourceExternal => '外挂字幕';

  @override
  String get subtitleSourceUnknown => '字幕来源未知';

  @override
  String subtitleTooHigh(String value) {
    return '不能高于 $value';
  }

  @override
  String subtitleTooLow(String value) {
    return '不能低于 $value';
  }

  @override
  String get subtitleUnitPixels => '像素';

  @override
  String get subtitleUnitSeconds => '秒';

  @override
  String get subtitleVerticalOffset => '垂直偏移';

  @override
  String get taskActionBusy => '处理中';

  @override
  String get taskActionRetry => '重试';

  @override
  String get taskCancelSubmitted => '已提交取消任务';

  @override
  String get taskCenterEyebrow => '后台任务';

  @override
  String taskCenterSubtitleActive(int active, int total) {
    return '$active 条任务正在执行 · 共 $total 条记录';
  }

  @override
  String taskCenterSubtitleIdle(int total) {
    return '暂无进行中的任务 · 共 $total 条记录';
  }

  @override
  String get taskEmptyActive => '没有正在执行的任务';

  @override
  String get taskEmptyAll => '暂无任务';

  @override
  String get taskEmptyCanceled => '没有已取消的任务';

  @override
  String get taskEmptyCompleted => '没有已完成的任务';

  @override
  String get taskEmptyFailed => '暂无失败任务';

  @override
  String get taskEmptyHint => 'NFO、云端转译、音频提取和扫库任务会显示在这里';

  @override
  String get taskErrCancelExtract => '取消音频提取失败';

  @override
  String get taskErrCancelTranscribe => '取消转录失败';

  @override
  String get taskErrRetryTranscribe => '重试转录失败';

  @override
  String get taskFilterActive => '执行中';

  @override
  String get taskFilterAll => '全部';

  @override
  String get taskFilterCanceled => '已取消';

  @override
  String get taskFilterCompleted => '已完成';

  @override
  String get taskFilterFailed => '失败';

  @override
  String get taskMsgCanceled => '任务已取消';

  @override
  String get taskMsgRequeued => '任务已重新排队';

  @override
  String get taskMsgScanPreparing => '正在准备扫描';

  @override
  String get taskMsgScanQueued => '扫描任务已排队';

  @override
  String taskMsgScanQueuedAt(int position) {
    return '排队中（第 $position 位）';
  }

  @override
  String get taskMsgWaitingUpdate => '等待更新';

  @override
  String get taskNameActorSync => '演员同步';

  @override
  String get taskNameAudioExtract => '音频提取';

  @override
  String get taskNameFallback => '后台任务';

  @override
  String get taskNameNfoSync => 'NFO 同步';

  @override
  String get taskNameResourceScan => '资源扫描';

  @override
  String get taskNameScan => '扫库';

  @override
  String get taskNameTranscribe => '字幕转译';

  @override
  String get taskRecordRemoved => '任务记录已移除';

  @override
  String get taskUndo => '撤销';

  @override
  String get unitDays => '天';

  @override
  String get unitMinutes => '分钟';

  @override
  String get unitTimes => '次';

  @override
  String get videoExtensionsAddLabel => '添加扩展名';

  @override
  String get videoExtensionsCurrentLabel => '当前扩展名';

  @override
  String get videoExtensionsDotHint => '支持带点号或不带点号';

  @override
  String get videoExtensionsEmpty => '暂无视频扩展名';

  @override
  String get videoExtensionsSaveFailed => '视频扩展名保存失败';

  @override
  String get videoExtensionsSubtitle => '视频扩展名设置';

  @override
  String get actorBatchDeleteTitle => '批量删除演员';

  @override
  String actorBatchDeleteWithRelations(int count) {
    return '已选择 $count 位演员，其中包含影片关联。强制删除会解除关联，影片本身不会被删除。';
  }

  @override
  String actorBatchDeleteConfirm(int count) {
    return '确定删除已选择的 $count 位演员吗？';
  }

  @override
  String actorBatchDeleted(int count) {
    return '已删除 $count 位演员';
  }

  @override
  String actorBatchDeleteFailed(String error) {
    return '批量删除失败：$error';
  }

  @override
  String actorCount(int count) {
    return '$count 位演员';
  }

  @override
  String get actorCountSuffix => '位演员';

  @override
  String actorMovieCount(int count) {
    return '$count 部';
  }

  @override
  String get actorSearchHint => '搜索演员名称';

  @override
  String get actorSortMovieCount => '影片数';

  @override
  String get actorSortName => '名称';

  @override
  String get actorSortCreatedAt => '创建时间';

  @override
  String get actorEditAction => '编辑';

  @override
  String get actorDeleteAction => '删除';

  @override
  String get actorCancelAction => '取消';

  @override
  String get actorEditorEditTitle => '编辑演员';

  @override
  String get actorEditorCreateTitle => '新建演员';

  @override
  String get actorEditorNameLabel => '演员名称';

  @override
  String get actorEditorNameHint => '演员名称';

  @override
  String get actorEditorBiographyHint => '填写演员简介（可选）';

  @override
  String get actorEditorAssociationLabel => '关联名称';

  @override
  String get actorEditorAssociationHint => '每行一个，可选';

  @override
  String get actorEditorSaveAction => '保存';

  @override
  String get actorEditorCreateAction => '创建';

  @override
  String get actorSaved => '演员已保存';

  @override
  String get actorCreated => '演员已创建';

  @override
  String actorActionFailed(String error) {
    return '操作失败：$error';
  }

  @override
  String get actorDeleteTitle => '删除演员';

  @override
  String actorDeleteWithMovies(String name, int count) {
    return '「$name」关联了 $count 部影片。强制删除将解除关联,影片本身不会被删除。';
  }

  @override
  String actorDeleteAssociation(String name) {
    return '「$name」是关联名称,删除将解除其影片关联,影片本身不会被删除。';
  }

  @override
  String actorDeleteConfirm(String name) {
    return '确定删除「$name」?';
  }

  @override
  String get actorForceDeleteAction => '强制删除';

  @override
  String get actorDeleted => '演员已删除';

  @override
  String actorDeleteFailed(String error) {
    return '删除失败：$error';
  }

  @override
  String get actorAssociationBadge => '关联';

  @override
  String get actorEmptyTitle => '还没有演员';

  @override
  String get actorEmptyHint => '点击右上角添加演员';

  @override
  String get serverSelectionTitle => '连接';

  @override
  String get serverSelectionSearchHint => '搜索服务器';

  @override
  String get serverSelectionNoMatch => '没有找到匹配的连接';

  @override
  String get serverSelectionAddServer => '添加服务器';

  @override
  String serverSelectionSelectServer(String name) {
    return '选择$name';
  }

  @override
  String get serverCancelAction => '取消';

  @override
  String get serverDeleteAction => '删除服务器';

  @override
  String get serverLatency => '延迟';

  @override
  String get serverProjectFeiniu => '飞牛影视';

  @override
  String get serverProjectDefault => '服务器';

  @override
  String get serverLineMain => '主线路';

  @override
  String get forceDelete => '强制删除';

  @override
  String get merge => '合并';

  @override
  String get create => '创建';

  @override
  String get saved => '已保存';

  @override
  String get created => '已创建';

  @override
  String get deleted => '已删除';

  @override
  String deleteFailed(String error) {
    return '删除失败：$error';
  }

  @override
  String get translating => '翻译中';

  @override
  String get translate => '翻译';

  @override
  String get merging => '合并中';

  @override
  String get confirmMerge => '确认合并';

  @override
  String get reset => '重置';

  @override
  String get include => '包含';

  @override
  String get exclude => '排除';

  @override
  String get unlimited => '不限';

  @override
  String get done => '完成';

  @override
  String get use => '使用';

  @override
  String loadFailedWithError(String error) {
    return '加载失败：$error';
  }

  @override
  String get advancedFilterTitle => '高级筛选';

  @override
  String get advancedFilterSubtitle => '按标签、类型、系列、年份、评分和文件属性组合筛选';

  @override
  String get advancedFilterYearAndRating => '年份与评分';

  @override
  String get advancedFilterYearRange => '年份范围';

  @override
  String get advancedFilterYearFrom => '起始年份';

  @override
  String get advancedFilterYearTo => '结束年份';

  @override
  String get advancedFilterYearRangeInvalid => '起始年份不能大于结束年份';

  @override
  String get advancedFilterRatingRange => '评分范围';

  @override
  String get advancedFilterMinRating => '最低评分';

  @override
  String get advancedFilterMaxRating => '最高评分';

  @override
  String advancedFilterRatingAbove(int rating) {
    return '$rating 分以上';
  }

  @override
  String advancedFilterRatingBelow(int rating) {
    return '$rating 分以下';
  }

  @override
  String get advancedFilterSubtitlesAndFiles => '字幕与文件';

  @override
  String get advancedFilterExternalSubtitles => '外挂字幕';

  @override
  String get advancedFilterIncludeExternalSubtitles => '包含外挂字幕';

  @override
  String get advancedFilterExcludeExternalSubtitles => '排除外挂字幕';

  @override
  String get advancedFilterFileFilter => '文件过滤器';

  @override
  String get advancedFilterOnlyStandard => '仅限标准';

  @override
  String get advancedFilterOnlyCrack => '仅限破解';

  @override
  String get advancedFilterOnlyChineseSubtitle => '仅限中字';

  @override
  String get advancedFilterOnlyChineseCrack => '仅限中字破解';

  @override
  String get advancedFilterApply => '应用筛选';

  @override
  String get resourceGenresManage => '类型管理';

  @override
  String get resourceTagsManage => '标签管理';

  @override
  String get resourceSeriesManage => '系列管理';

  @override
  String get resourceGenresSearchHint => '搜索类型名称';

  @override
  String get resourceTagsSearchHint => '搜索标签名称';

  @override
  String get resourceSeriesSearchHint => '搜索系列名称';

  @override
  String resourceBatchDeleteTitle(String kind) {
    return '批量删除$kind';
  }

  @override
  String resourceBatchDeleteWithMovies(int count, String kind) {
    return '已选择 $count 个$kind，其中包含影片关联。强制删除会解除关联，影片本身不会被删除。';
  }

  @override
  String resourceBatchDeleteConfirm(int count, String kind) {
    return '确定删除已选择的 $count 个$kind吗？';
  }

  @override
  String resourceBatchDeleted(int count, String kind) {
    return '已删除 $count 个$kind';
  }

  @override
  String resourceBatchDeleteFailed(String error) {
    return '批量删除失败：$error';
  }

  @override
  String resourceCountSuffix(String kind) {
    return '个$kind';
  }

  @override
  String get resourceSortName => '名称';

  @override
  String get resourceSortMovieCount => '影片数';

  @override
  String get resourceSortCreatedAt => '创建时间';

  @override
  String get resourceTranslateEmpty => '名称内容为空，无需翻译';

  @override
  String get resourceTranslateNoResult => '名称翻译为空';

  @override
  String get resourceTranslateSuccess => '名称翻译成功';

  @override
  String resourceTranslateFailed(String error) {
    return '名称翻译失败：$error';
  }

  @override
  String resourceEditTitle(String kind) {
    return '编辑$kind';
  }

  @override
  String resourceCreateTitle(String kind) {
    return '新建$kind';
  }

  @override
  String resourceNameHint(String kind) {
    return '$kind名称';
  }

  @override
  String get resourceAutoMapping => '自动映射';

  @override
  String resourceDeleteTitle(String kind) {
    return '删除$kind';
  }

  @override
  String resourceDeleteWithMovies(String name, int count) {
    return '「$name」关联了 $count 部影片。强制删除将解除所有关联,影片本身不会被删。';
  }

  @override
  String resourceDeleteConfirm(String name) {
    return '确定删除「$name」?';
  }

  @override
  String resourceEmptyTitle(String kind) {
    return '还没有$kind';
  }

  @override
  String get resourceEmptyHint => '点击右上角添加按钮创建第一个';

  @override
  String get resourceMoviesEmpty => '这个维度下还没有影片';

  @override
  String resourceMovieCount(int count) {
    return '$count 部影片';
  }

  @override
  String resourceMovieCountWithName(String name, int count) {
    return '$name · $count 部影片';
  }

  @override
  String resourceMergeTitle(String kind) {
    return '批量合并$kind';
  }

  @override
  String resourceMergeSubtitle(int count, String kind) {
    return '将 $count 个$kind合并为一个，影片关联会转移到保留项。';
  }

  @override
  String resourceMergeKeep(String kind) {
    return '保留的$kind';
  }

  @override
  String resourceMergeFailed(String error) {
    return '合并失败：$error';
  }

  @override
  String entityPickerTitle(String kind) {
    return '选择$kind';
  }

  @override
  String entityPickerSelected(int count) {
    return '已选 $count 项';
  }

  @override
  String get entityPickerSearchName => '搜索名称';

  @override
  String get entityPickerSearchNameOrAlias => '搜索名称 / 别名';

  @override
  String get entityPickerNoResourceMatch => '没有匹配的资源';

  @override
  String get entityPickerNoActorMatch => '没有匹配的演员';

  @override
  String get entityPickerNoSeriesMatch => '未找到匹配的系列';

  @override
  String entityPickerSelect(String kind) {
    return '选择$kind…';
  }

  @override
  String movieCountShort(int count) {
    return '$count 部';
  }

  @override
  String get batchEditNothingSelected => '请至少选择一项要添加、移除或裁剪的内容';

  @override
  String batchEditWatermarkResult(int success, int failed) {
    return '海报裁剪：成功 $success，失败 $failed';
  }

  @override
  String get batchEditSaved => '批量编辑成功';

  @override
  String batchEditFailed(String error) {
    return '批量编辑失败：$error';
  }

  @override
  String batchEditTitle(int count) {
    return '批量编辑 $count 部';
  }

  @override
  String get batchEditSubtitle => '集中调整标签、类型、系列和快速标记';

  @override
  String get batchEditQuickFlags => '快速标记';

  @override
  String get batchEditQuickFlagsSubtitle => '保存时会同步裁剪海报水印';

  @override
  String get movieFlagSubtitle => '字幕';

  @override
  String get movieFlagExternalSubtitle => '外挂字幕';

  @override
  String get movieFlagCrack => '破解';

  @override
  String get batchEditSubtitleExclusive => '字幕与外挂字幕互斥';

  @override
  String get batchEditTagSubtitle => '分别指定要追加和移除的标签集合';

  @override
  String batchEditAdd(String kind) {
    return '添加$kind';
  }

  @override
  String batchEditRemoveCommon(String kind) {
    return '移除$kind（仅共有）';
  }

  @override
  String get batchEditSeriesSubtitle => '可统一设置系列';

  @override
  String batchEditNoCommon(String kind) {
    return '无共有$kind';
  }

  @override
  String get loadingEllipsis => '加载中…';

  @override
  String get batchEditSeriesSearchFailed => '搜索系列失败，请稍后重试';

  @override
  String get batchEditSeriesLoadMoreFailed => '加载更多系列失败，请稍后重试';

  @override
  String get batchEditSeriesSearchHint => '搜索系列…';

  @override
  String get batchEditSeriesEmpty => '暂无系列';

  @override
  String get batchEditClearSeries => '清空选择';

  @override
  String get detailActorRelatedMovies => '演员相关影片';

  @override
  String get detailFile => '文件';

  @override
  String get detailMovieFile => '影片文件';

  @override
  String get detailFilePath => '文件路径';

  @override
  String get detailNumber => '编号';

  @override
  String get detailCountry => '国家/地区';

  @override
  String get detailRuntime => '时长';

  @override
  String detailRuntimeMinutes(Object minutes) {
    return '$minutes 分钟';
  }

  @override
  String get detailFileSize => '文件大小';

  @override
  String get detailPart => '分部';

  @override
  String get detailDownloadedAt => '下载时间';

  @override
  String get detailContainer => '容器';

  @override
  String get detailSize => '大小';

  @override
  String get detailMediaInfo => '媒体信息';

  @override
  String detailDurationHours(int hours, String minutes, String seconds) {
    return '$hours小时 $minutes分 $seconds秒';
  }

  @override
  String detailDurationMinutes(int minutes, String seconds) {
    return '$minutes分 $seconds秒';
  }

  @override
  String get detailAudioExtractionSubmitted => '音频提取任务已提交';

  @override
  String get detailSyncNfoTitle => '同步到 NFO';

  @override
  String get detailSyncNfoMessage => '把当前元数据写入磁盘 NFO 文件?';

  @override
  String get detailSyncNfoSuccess => '已同步到 NFO';

  @override
  String get detailRefreshNfoTitle => '从 NFO 刷新';

  @override
  String get detailRefreshNfoMessage => '从磁盘 NFO 重新加载,会覆盖当前元数据。';

  @override
  String get detailRefreshNfoSuccess => '已从 NFO 重载';

  @override
  String get detailEditMovie => '编辑影片';

  @override
  String get detailFetchMetadata => '获取元数据';

  @override
  String get detailFetchResources => '获取资源';

  @override
  String get detailFetchSubtitles => '获取字幕';

  @override
  String get detailExtractAudio => '提取音频';

  @override
  String get detailDeleteMovieTitle => '删除影片';

  @override
  String detailDeleteMovieMessage(String title) {
    return '确定删除「$title」?\n影片文件、海报、剧照、NFO 等关联资源都会被删除,且不可恢复。';
  }

  @override
  String get detailPlotTitle => '简介';

  @override
  String get detailPlotViewFull => '查看完整简介';

  @override
  String get fanartFetchDone => '额外预览图获取完成';

  @override
  String fanartFetchFailed(String error) {
    return '获取额外预览图失败：$error';
  }

  @override
  String get fanartTitle => '预览图';

  @override
  String get fanartRefresh => '刷新预览图';

  @override
  String get fanartFetch => '获取预览图';

  @override
  String get fanartLoading => '正在加载预览图…';

  @override
  String fanartLoadFailed(String error) {
    return '预览图加载失败：$error';
  }

  @override
  String get fanartEmpty => '暂无预览图';

  @override
  String get fanartClose => '关闭预览图';

  @override
  String get fanartTrailerPlaybackFailed => '预告片播放失败';

  @override
  String coverBadgeCodecTooltip(String codec) {
    return '视频编码：$codec';
  }

  @override
  String coverBadgeRangeTooltip(String range) {
    return '动态范围：$range';
  }

  @override
  String get coverBadgeStrmTooltip => 'STRM 视频文件';

  @override
  String get coverBadgeEmbeddedSubtitleTooltip => '内嵌字幕';

  @override
  String get coverBadgeCrackTooltip => '破解/无码';

  @override
  String get coverBadgeResolutionUhdTooltip => '2160p / 4K';

  @override
  String get coverBadgeResolutionHdTooltip => '720p 及以上';

  @override
  String get mediaStreamVideo => '视频';

  @override
  String mediaStreamAudio(int ordinal) {
    return '音频 $ordinal';
  }

  @override
  String get mediaStreamSubtitles => '字幕';

  @override
  String get mediaStreamDefault => '默认';

  @override
  String get mediaStreamForced => '强制';

  @override
  String get mediaStreamText => '文本';

  @override
  String get mediaStreamBitmap => '位图';

  @override
  String mediaStreamCount(int count) {
    return '$count 条';
  }

  @override
  String get mediaStreamEncoding => '编码';

  @override
  String get mediaStreamProfile => '配置';

  @override
  String get mediaStreamLevel => '等级';

  @override
  String get mediaStreamResolution => '分辨率';

  @override
  String get mediaStreamAspectRatio => '长宽比';

  @override
  String get mediaStreamFrameRate => '帧率';

  @override
  String get mediaStreamColorPrimaries => '基色';

  @override
  String get mediaStreamColorSpace => '色彩空间';

  @override
  String get mediaStreamTransfer => '传递特性';

  @override
  String get mediaStreamRange => '色彩范围';

  @override
  String get mediaStreamBitDepth => '位深';

  @override
  String get mediaStreamPixelFormat => '像素格式';

  @override
  String get mediaStreamBitrate => '码率';

  @override
  String get mediaStreamLanguage => '语言';

  @override
  String get mediaStreamLayout => '布局';

  @override
  String get mediaStreamChannelsLabel => '声道';

  @override
  String mediaStreamChannels(int count) {
    return '$count 声道';
  }

  @override
  String get mediaStreamSampleRate => '采样率';

  @override
  String get mediaStreamTitle => '标题';

  @override
  String get mediaLanguageJapanese => '日语';

  @override
  String get mediaLanguageEnglish => '英语';

  @override
  String get mediaLanguageChinese => '中文';

  @override
  String get mediaLanguageCantonese => '粤语';

  @override
  String get mediaLanguageKorean => '韩语';

  @override
  String get mediaLanguageFrench => '法语';

  @override
  String get mediaLanguageRussian => '俄语';

  @override
  String get mediaLanguageSpanish => '西班牙语';

  @override
  String get mediaLanguageGerman => '德语';

  @override
  String get mediaLanguageThai => '泰语';

  @override
  String get mediaLanguageUndetermined => '未指定';

  @override
  String get moviesFilterDuplicateNum => '重复番号';

  @override
  String get moviesFilterNewResources => '新资源';

  @override
  String get moviesScanResources => '扫描资源';

  @override
  String get moviesScanning => '扫描中';

  @override
  String get moviesBatchEdit => '编辑';

  @override
  String get moviesBatchDownload => '下载';

  @override
  String get moviesBatchScan => '扫描';

  @override
  String get moviesBatchCompare => '比较';

  @override
  String get moviesBatchMerge => '合并';

  @override
  String moviesFavoriteAdded(String title) {
    return '已收藏「$title」';
  }

  @override
  String moviesFavoriteRemoved(String title) {
    return '已取消收藏「$title」';
  }

  @override
  String moviesOperationFailed(String error) {
    return '操作失败：$error';
  }

  @override
  String get moviesNoScannable => '当前没有可扫描的影片';

  @override
  String get moviesScanSelectedTitle => '扫描已选影片';

  @override
  String get moviesScanFilteredTitle => '扫描筛选结果';

  @override
  String moviesScanSelectedMessage(int count) {
    return '将扫描已选的 $count 部影片，确定继续吗？';
  }

  @override
  String moviesScanFilteredMessage(int count) {
    return '将扫描当前筛选结果中的 $count 部影片（包含全部分页），确定继续吗？';
  }

  @override
  String get moviesStartScan => '开始扫描';

  @override
  String moviesScanSubmitted(int count, String skipped) {
    return '已提交 $count 部影片$skipped';
  }

  @override
  String moviesScanSkipped(int count) {
    return '，跳过 $count 部无效影片';
  }

  @override
  String moviesScanCreateFailed(String error) {
    return '创建资源扫描任务失败：$error';
  }

  @override
  String get moviesNeedSameNumber => '需选择 2 部以上相同番号影片';

  @override
  String get moviesSortSheetTitle => '排序';

  @override
  String get moviesSortAscending => '升序';

  @override
  String get moviesSortDescending => '降序';

  @override
  String get moviesSortFileSize => '文件大小';

  @override
  String get moviesSortCreatedAt => '创建';

  @override
  String get moviesSortUpdatedAt => '更新';

  @override
  String get moviesSortDownloadedAt => '下载日期';

  @override
  String get moviesUpdatedStatus => '更新状态';

  @override
  String get moviesUpdated => '已更新';

  @override
  String get moviesNotUpdated => '未更新';

  @override
  String get moviesUnlimited => '不限';

  @override
  String get moviesFavorite => '收藏';

  @override
  String get moviesUnfavorite => '取消收藏';

  @override
  String moviesBatchDownloadTitle(int count) {
    return '批量下载 $count 部';
  }

  @override
  String get moviesBatchDownloadSubtitle => '按条件批量提交下载请求，缺失番号会自动跳过';

  @override
  String get moviesDownloadQuality => '画质偏好';

  @override
  String get moviesDownloadQualityHint => '如 4k、hd、uhd 等，留空不限';

  @override
  String get moviesDownloadMinSize => '最小大小 (MB)';

  @override
  String get moviesDownloadMaxSize => '最大大小 (MB)';

  @override
  String get moviesDownloadMaxFiles => '最大文件数';

  @override
  String get moviesDownloadDate => '截止日期';

  @override
  String get moviesDownloadNoLimit => '0 = 不限';

  @override
  String get moviesDownloadRequireSubtitle => '要求字幕';

  @override
  String get moviesDownloadRequireUncensored => '要求无码';

  @override
  String get moviesDownloadWashMode => '精洗模式';

  @override
  String get moviesDownloadWashModeHint => '已存在影片也重新下载';

  @override
  String moviesDownloadFailed(String error) {
    return '下载请求失败：$error';
  }

  @override
  String get moviesSubmitting => '提交中…';

  @override
  String get moviesConfirmSubmit => '确认提交';

  @override
  String get moviesMergeStarted => '已启动合并任务';

  @override
  String moviesMergeFailed(String error) {
    return '合并失败：$error';
  }

  @override
  String moviesMergeTitle(int count) {
    return '合并 $count 部重复影片';
  }

  @override
  String get moviesMergeSubtitle => '选择主导影片，其他相关文件会移到该影片所在目录';

  @override
  String get moviesMergeWarning => '同名视频文件会被覆盖，文件名冲突时非主导记录将被删除';

  @override
  String get moviesMergeSameFolder => '所有选中影片已在同一目录，无需合并';

  @override
  String get moviesMerging => '合并中…';

  @override
  String get moviesConfirmMerge => '确认合并';

  @override
  String get moviesUntitled => '未命名';

  @override
  String get moviesNoCode => '无番号';

  @override
  String get moviesPathUnavailable => '路径不可用';

  @override
  String get moviesNfoSynced => 'NFO 已同步';

  @override
  String moviesApplyFailed(String error) {
    return '应用失败：$error';
  }

  @override
  String get moviesCompareNfoTitle => '比较重复 NFO';

  @override
  String get moviesCompareNfoSubtitle => '为每个字段选择同步来源';

  @override
  String get moviesCompareNfoNoChanges => '影片标题、描述、概要、评分均一致，无需选择';

  @override
  String get moviesApplying => '应用中…';

  @override
  String get moviesApplySync => '应用同步';

  @override
  String moviesMovieWithId(int id) {
    return '影片 $id';
  }

  @override
  String get moviesEmptyValue => '(空)';

  @override
  String get resourceScanTitle => '扫描资源';

  @override
  String get resourceScanProgress => '资源扫描进度';

  @override
  String get resourceScanConnecting => '正在连接…';

  @override
  String get resourceScanSuccess => '成功';

  @override
  String get resourceScanFailed => '失败';

  @override
  String get resourceScanNewResources => '新资源';

  @override
  String get resourceScanBackground => '后台运行';

  @override
  String get resourceScanClose => '关闭';

  @override
  String get resourceScanDone => '完成';

  @override
  String get resourceScanPreparing => '准备中';

  @override
  String get resourceScanRunning => '扫描中';

  @override
  String get resourceScanCompleted => '已完成';

  @override
  String get moviesNfoFieldTitle => '标题';

  @override
  String get moviesNfoFieldDescription => '描述';

  @override
  String get moviesNfoFieldPlot => '简介';

  @override
  String get moviesNfoFieldRating => '评分';

  @override
  String get moviesNfoFieldYear => '年份';

  @override
  String get moviesNfoFieldRuntime => '时长';

  @override
  String get moviesNfoFieldDate => '日期';

  @override
  String subtitlePreviewFailed(String error) {
    return '预览失败：$error';
  }

  @override
  String subtitleDownloaded(String name) {
    return '已下载 $name';
  }

  @override
  String subtitleDownloadFailed(String error) {
    return '下载失败：$error';
  }

  @override
  String get subtitleExistsTitle => '字幕已存在';

  @override
  String get subtitleExistsMessage => '同名字幕文件已存在，是否覆盖？';

  @override
  String get subtitlePreviewTitle => '字幕预览';

  @override
  String get subtitleSearchTitle => '获取字幕';

  @override
  String subtitleSearchKeyword(String keyword) {
    return '关键词：$keyword';
  }

  @override
  String get subtitleNoMatch => '没有找到匹配的字幕';

  @override
  String get subtitlePreview => '预览';

  @override
  String get subtitleDownload => '下载';

  @override
  String get subtitleCopy => '复制';

  @override
  String get subtitleCopied => '已复制全部内容';

  @override
  String get audioExtractTitle => '提取音频';

  @override
  String get audioExtractFormat => '输出格式';

  @override
  String get audioExtractBitrate => '目标码率';

  @override
  String get audioExtractFailed => '音频提取任务创建失败';

  @override
  String get audioExtractSubmitting => '提交中…';

  @override
  String get audioExtractSubmit => '提交任务';

  @override
  String dboAppliedFields(int count) {
    return '已应用 $count 个字段';
  }

  @override
  String dboApplyFailed(String error) {
    return '应用失败：$error';
  }

  @override
  String get dboTitle => 'DB Online 元数据';

  @override
  String get dboUpToDate => '本地元数据已是最新';

  @override
  String get dboNoOverridableFields => '没有可覆盖的字段';

  @override
  String get dboSelectAll => '全选';

  @override
  String get dboClear => '清空';

  @override
  String dboApplyCount(int count) {
    return '应用 ($count)';
  }

  @override
  String get dboSelectFields => '请选择字段';

  @override
  String get dboCurrent => '当前：';

  @override
  String get dboSectionInfo => '影片信息';

  @override
  String get dboSectionSeries => '系列';

  @override
  String get dboSectionGenres => '类型';

  @override
  String get dboSectionActors => '演员';

  @override
  String get dboFemale => '女';

  @override
  String get dboMale => '男';

  @override
  String get dboFieldTitle => '标题';

  @override
  String get dboFieldRating => '评分';

  @override
  String get dboFieldYear => '年份';

  @override
  String get dboFieldRuntime => '时长';

  @override
  String get dboFieldPlot => '剧情简介';

  @override
  String get dboRemove => '移除';

  @override
  String get movieEditorQuickActions => '封面水印 · 快捷操作';

  @override
  String get movieEditorFanartCrop => '封面裁剪 (Fanart)';

  @override
  String get movieEditorTitle => '编辑影片';

  @override
  String get movieEditorOriginalTitle => '原标题';

  @override
  String get movieEditorNumber => '番号';

  @override
  String get movieEditorYear => '年份';

  @override
  String get movieEditorRating => '评分';

  @override
  String get movieEditorRuntime => '时长 (min)';

  @override
  String get movieEditorSeries => '系列';

  @override
  String get movieEditorGenre => '类型';

  @override
  String get movieEditorTag => '标签';

  @override
  String get movieEditorActor => '演员';

  @override
  String get movieEditorFieldTitle => '标题';

  @override
  String get movieEditorFieldCountry => '国家';

  @override
  String get movieEditorFieldPlot => '简介';

  @override
  String movieEditorSelectEntity(String entity) {
    return '点击选择$entity';
  }

  @override
  String movieEditorUntitledEntity(String entity) {
    return '未命名$entity';
  }

  @override
  String movieEditorQuickActionFailed(String error) {
    return '快捷操作失败：$error';
  }

  @override
  String get movieEditorBatchTranslating => '批量翻译中';

  @override
  String get movieEditorBatchTranslate => '批量翻译';

  @override
  String movieEditorFieldEmpty(String label) {
    return '$label 内容为空，无需翻译';
  }

  @override
  String movieEditorTranslationEmpty(String label) {
    return '$label 翻译为空';
  }

  @override
  String movieEditorTranslationSuccess(String label) {
    return '$label 翻译成功';
  }

  @override
  String movieEditorTranslationFailed(String label, String error) {
    return '$label 翻译失败：$error';
  }

  @override
  String get movieEditorNoTranslatableContent => '没有可翻译的内容';

  @override
  String movieEditorBatchResult(int success, int total) {
    return '批量翻译：成功 $success / $total';
  }

  @override
  String get movieEditorBatchNoResult => '批量翻译未返回结果';

  @override
  String movieEditorBatchFailed(String error) {
    return '批量翻译失败：$error';
  }

  @override
  String get movieEditorTranslating => '翻译中';

  @override
  String get resourceSourceDetail => '影片详情资源';

  @override
  String get resourceSourceCustom => '自定义资源';

  @override
  String get resourceSourceNyaa => 'Nyaa 资源';

  @override
  String get resourceNoDownloaders => '未配置可用下载器';

  @override
  String get resourceSelectDownloader => '选择下载器';

  @override
  String resourcePushFailed(String error) {
    return '推送失败：$error';
  }

  @override
  String get resourceOnline => '在线资源';

  @override
  String resourceMagnetCount(int count) {
    return '磁力 ($count)';
  }

  @override
  String resourceEd2kCount(int count) {
    return 'ED2K ($count)';
  }

  @override
  String get resourceLoadingOnline => '正在加载在线资源…';

  @override
  String get resourceWaitingSources => '已返回的渠道暂无资源，继续等待其他渠道…';

  @override
  String get resourceNoMagnet => '没有磁力资源';

  @override
  String get resourceNoEd2k => '没有 ED2K 资源';

  @override
  String get resourceFallbackTitle => '资源';

  @override
  String resourceFrom(String source) {
    return '来自 $source';
  }

  @override
  String get resourceCopy => '复制';

  @override
  String get resourceCopied => '已复制';

  @override
  String get resourcePushing => '推送中';

  @override
  String get resourcePushDownload => '推送下载';

  @override
  String resourceRecentlyDownloaded(String value) {
    return '最近下载 $value';
  }

  @override
  String resourceRecentlyDownloadedAt(String date) {
    return '最近下载 $date';
  }

  @override
  String get playerBuffering => '正在缓冲…';

  @override
  String get audioNotificationChannelName => '音乐播放';

  @override
  String get audioNotificationChannelDescription => '文件管理器音乐播放控制';

  @override
  String get audioUnknownTitle => '未知音频';

  @override
  String get audioFileManagerAlbum => '文件管理器';

  @override
  String audioPlaybackFailed(String error) {
    return '音频播放失败：$error';
  }

  @override
  String get audioPlaybackFailedGeneric => '音频播放失败';

  @override
  String get personNoMovies => '没有该演员的影片';

  @override
  String get personSyncAssociations => '同步演员关联';

  @override
  String get mediaBrowserSimilar => '更多类似';

  @override
  String get posterCropEnableHint => '勾选上方快捷操作启用裁剪';

  @override
  String get posterCropGestureHint => '左右拖动或点击定位裁剪范围';

  @override
  String get playerLandscapeCameraLeft => '摄像头在左侧';

  @override
  String get playerLandscapeCameraRight => '摄像头在右侧';

  @override
  String get playerOrientationUnchanged => '无变化';

  @override
  String get playerOrientationForceLandscape => '强制横屏';

  @override
  String get playerOrientationForcePortrait => '强制竖屏';

  @override
  String get playerPreload250Mb => '250MB';

  @override
  String get playerPreload500Mb => '500MB';

  @override
  String get playerPreload750Mb => '750MB';

  @override
  String get playerPreload1Gb => '1GB';

  @override
  String get hapticIntensityOff => '关闭';

  @override
  String get hapticIntensityLow => '轻';

  @override
  String get hapticIntensityStandard => '标准';

  @override
  String get hapticIntensityHigh => '强';

  @override
  String get favoriteListAllTimeBest => '最爱';

  @override
  String get favoriteListAfterHours => '私藏';
}
