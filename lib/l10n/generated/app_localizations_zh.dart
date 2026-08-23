// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppL10nZh extends AppL10n {
  AppL10nZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'MD Center';

  @override
  String get tabHome => '首页';

  @override
  String get tabLibrary => '影片库';

  @override
  String get tabSearch => '搜索';

  @override
  String get tabYou => '我的';

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
  String get settingsServerSettingsSub => '服务器 / 系统配置 / 媒体库 / 映射规则 / 工具';

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
  String get languageSystem => '跟随系统';

  @override
  String get languageZh => '简体中文';

  @override
  String get languageEn => 'English';

  @override
  String get privacyLockedTitle => '已锁定';

  @override
  String get privacyMode => '隐私模式';
}
