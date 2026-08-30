import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'Oh My Media'**
  String get appName;

  /// No description provided for @tabHome.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get tabHome;

  /// No description provided for @tabLibrary.
  ///
  /// In zh, this message translates to:
  /// **'影片库'**
  String get tabLibrary;

  /// No description provided for @tabSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get tabSearch;

  /// No description provided for @tabYou.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get tabYou;

  /// No description provided for @tabFiles.
  ///
  /// In zh, this message translates to:
  /// **'文件管理'**
  String get tabFiles;

  /// No description provided for @greetingMorning.
  ///
  /// In zh, this message translates to:
  /// **'早上好'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In zh, this message translates to:
  /// **'下午好'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In zh, this message translates to:
  /// **'晚上好'**
  String get greetingEvening;

  /// No description provided for @greetingNight.
  ///
  /// In zh, this message translates to:
  /// **'夜深了'**
  String get greetingNight;

  /// No description provided for @homePickupTitle.
  ///
  /// In zh, this message translates to:
  /// **'继续观看'**
  String get homePickupTitle;

  /// No description provided for @homeFreshTitle.
  ///
  /// In zh, this message translates to:
  /// **'新加入的影片'**
  String get homeFreshTitle;

  /// No description provided for @homeYourLibraries.
  ///
  /// In zh, this message translates to:
  /// **'我的媒体库'**
  String get homeYourLibraries;

  /// No description provided for @homeSeeAll.
  ///
  /// In zh, this message translates to:
  /// **'查看全部'**
  String get homeSeeAll;

  /// No description provided for @homeResume.
  ///
  /// In zh, this message translates to:
  /// **'继续播放'**
  String get homeResume;

  /// No description provided for @homeMinutesLeft.
  ///
  /// In zh, this message translates to:
  /// **'{n} 分钟剩余'**
  String homeMinutesLeft(int n);

  /// No description provided for @libraryTitle.
  ///
  /// In zh, this message translates to:
  /// **'影片库'**
  String get libraryTitle;

  /// No description provided for @libraryCount.
  ///
  /// In zh, this message translates to:
  /// **'{n} 部影片'**
  String libraryCount(int n);

  /// No description provided for @libraryCountSuffix.
  ///
  /// In zh, this message translates to:
  /// **'部影片'**
  String get libraryCountSuffix;

  /// No description provided for @filterAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get filterAll;

  /// No description provided for @filterRecent.
  ///
  /// In zh, this message translates to:
  /// **'最近'**
  String get filterRecent;

  /// No description provided for @filterRating.
  ///
  /// In zh, this message translates to:
  /// **'评分'**
  String get filterRating;

  /// No description provided for @filterTopRated.
  ///
  /// In zh, this message translates to:
  /// **'高分'**
  String get filterTopRated;

  /// No description provided for @filterUnwatched.
  ///
  /// In zh, this message translates to:
  /// **'未观看'**
  String get filterUnwatched;

  /// No description provided for @viewGrid.
  ///
  /// In zh, this message translates to:
  /// **'网格'**
  String get viewGrid;

  /// No description provided for @viewList.
  ///
  /// In zh, this message translates to:
  /// **'列表'**
  String get viewList;

  /// No description provided for @searchHintAll.
  ///
  /// In zh, this message translates to:
  /// **'搜索片名 / 演员 / 标签'**
  String get searchHintAll;

  /// No description provided for @resultsSortedBy.
  ///
  /// In zh, this message translates to:
  /// **'{n} 个结果 · 按 {sort} 排序'**
  String resultsSortedBy(int n, String sort);

  /// No description provided for @sortedByOnly.
  ///
  /// In zh, this message translates to:
  /// **'按 {sort} 排序'**
  String sortedByOnly(String sort);

  /// No description provided for @loadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get loadFailed;

  /// No description provided for @loadFailedRetry.
  ///
  /// In zh, this message translates to:
  /// **'加载失败，点击重试'**
  String get loadFailedRetry;

  /// No description provided for @noResultFound.
  ///
  /// In zh, this message translates to:
  /// **'没有找到符合条件的影片'**
  String get noResultFound;

  /// No description provided for @watchedDone.
  ///
  /// In zh, this message translates to:
  /// **'已看完'**
  String get watchedDone;

  /// No description provided for @sortByCreatedAt.
  ///
  /// In zh, this message translates to:
  /// **'创建时间'**
  String get sortByCreatedAt;

  /// No description provided for @sortByRating.
  ///
  /// In zh, this message translates to:
  /// **'评分'**
  String get sortByRating;

  /// No description provided for @sortByTitle.
  ///
  /// In zh, this message translates to:
  /// **'片名'**
  String get sortByTitle;

  /// No description provided for @sortByYear.
  ///
  /// In zh, this message translates to:
  /// **'年份'**
  String get sortByYear;

  /// No description provided for @sortByReleaseDate.
  ///
  /// In zh, this message translates to:
  /// **'上映日期'**
  String get sortByReleaseDate;

  /// No description provided for @searchHint2.
  ///
  /// In zh, this message translates to:
  /// **'影片标题 / 演员 / 番号 / 标签'**
  String get searchHint2;

  /// No description provided for @searchFailed.
  ///
  /// In zh, this message translates to:
  /// **'搜索失败: {error}'**
  String searchFailed(String error);

  /// No description provided for @favoritesTitle.
  ///
  /// In zh, this message translates to:
  /// **'收藏夹'**
  String get favoritesTitle;

  /// No description provided for @favoritesSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'已收藏 {n} 部 · 跨 {l} 个集合'**
  String favoritesSubtitle(int n, int l);

  /// No description provided for @statSaved.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get statSaved;

  /// No description provided for @statWatched.
  ///
  /// In zh, this message translates to:
  /// **'已看'**
  String get statWatched;

  /// No description provided for @statHours.
  ///
  /// In zh, this message translates to:
  /// **'小时'**
  String get statHours;

  /// No description provided for @yourLists.
  ///
  /// In zh, this message translates to:
  /// **'我的集合'**
  String get yourLists;

  /// No description provided for @newList.
  ///
  /// In zh, this message translates to:
  /// **'新建集合'**
  String get newList;

  /// No description provided for @allFavorites.
  ///
  /// In zh, this message translates to:
  /// **'全部收藏'**
  String get allFavorites;

  /// No description provided for @upNext.
  ///
  /// In zh, this message translates to:
  /// **'即将观看'**
  String get upNext;

  /// No description provided for @watchlist.
  ///
  /// In zh, this message translates to:
  /// **'观看列表'**
  String get watchlist;

  /// No description provided for @selectedN.
  ///
  /// In zh, this message translates to:
  /// **'已选 {n}'**
  String selectedN(int n);

  /// No description provided for @remove.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get remove;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// No description provided for @back.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get back;

  /// No description provided for @searchTitle.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get searchTitle;

  /// No description provided for @searchFind.
  ///
  /// In zh, this message translates to:
  /// **'查找内容'**
  String get searchFind;

  /// No description provided for @searchEmpty.
  ///
  /// In zh, this message translates to:
  /// **'输入关键词开始搜索'**
  String get searchEmpty;

  /// No description provided for @searchNoResult.
  ///
  /// In zh, this message translates to:
  /// **'没有找到相关内容'**
  String get searchNoResult;

  /// No description provided for @searchModeTitle.
  ///
  /// In zh, this message translates to:
  /// **'影片'**
  String get searchModeTitle;

  /// No description provided for @searchModeList.
  ///
  /// In zh, this message translates to:
  /// **'列表搜索'**
  String get searchModeList;

  /// No description provided for @searchModeActorSearch.
  ///
  /// In zh, this message translates to:
  /// **'演员搜索'**
  String get searchModeActorSearch;

  /// No description provided for @searchModeSeries.
  ///
  /// In zh, this message translates to:
  /// **'系列搜索'**
  String get searchModeSeries;

  /// No description provided for @searchModeNum.
  ///
  /// In zh, this message translates to:
  /// **'番号'**
  String get searchModeNum;

  /// No description provided for @searchModeActor.
  ///
  /// In zh, this message translates to:
  /// **'演员'**
  String get searchModeActor;

  /// No description provided for @searchModeFilename.
  ///
  /// In zh, this message translates to:
  /// **'文件名'**
  String get searchModeFilename;

  /// No description provided for @searchPlaceholderTitle.
  ///
  /// In zh, this message translates to:
  /// **'搜索影片标题...'**
  String get searchPlaceholderTitle;

  /// No description provided for @searchPlaceholderList.
  ///
  /// In zh, this message translates to:
  /// **'搜索影片标题、番号、演员'**
  String get searchPlaceholderList;

  /// No description provided for @searchPlaceholderSeries.
  ///
  /// In zh, this message translates to:
  /// **'搜索系列名称'**
  String get searchPlaceholderSeries;

  /// No description provided for @searchPlaceholderNum.
  ///
  /// In zh, this message translates to:
  /// **'搜索番号...'**
  String get searchPlaceholderNum;

  /// No description provided for @searchPlaceholderActor.
  ///
  /// In zh, this message translates to:
  /// **'搜索演员...'**
  String get searchPlaceholderActor;

  /// No description provided for @searchPlaceholderFilename.
  ///
  /// In zh, this message translates to:
  /// **'搜索文件名...'**
  String get searchPlaceholderFilename;

  /// No description provided for @detailPlay.
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get detailPlay;

  /// No description provided for @detailAddList.
  ///
  /// In zh, this message translates to:
  /// **'+ 集合'**
  String get detailAddList;

  /// No description provided for @detailTrailer.
  ///
  /// In zh, this message translates to:
  /// **'预告片'**
  String get detailTrailer;

  /// No description provided for @detailCast.
  ///
  /// In zh, this message translates to:
  /// **'演员'**
  String get detailCast;

  /// No description provided for @detailDetails.
  ///
  /// In zh, this message translates to:
  /// **'详情'**
  String get detailDetails;

  /// No description provided for @detailFilmography.
  ///
  /// In zh, this message translates to:
  /// **'作品集'**
  String get detailFilmography;

  /// No description provided for @detailFavorited.
  ///
  /// In zh, this message translates to:
  /// **'已收藏'**
  String get detailFavorited;

  /// No description provided for @detailUnfavorited.
  ///
  /// In zh, this message translates to:
  /// **'已移除收藏'**
  String get detailUnfavorited;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @settingsPreferences.
  ///
  /// In zh, this message translates to:
  /// **'偏好设置'**
  String get settingsPreferences;

  /// No description provided for @settingsGroupServer.
  ///
  /// In zh, this message translates to:
  /// **'服务器'**
  String get settingsGroupServer;

  /// No description provided for @settingsGroupLibrary.
  ///
  /// In zh, this message translates to:
  /// **'媒体库'**
  String get settingsGroupLibrary;

  /// No description provided for @settingsGroupSystem.
  ///
  /// In zh, this message translates to:
  /// **'系统配置'**
  String get settingsGroupSystem;

  /// No description provided for @settingsGroupMappings.
  ///
  /// In zh, this message translates to:
  /// **'映射规则'**
  String get settingsGroupMappings;

  /// No description provided for @settingsGroupTools.
  ///
  /// In zh, this message translates to:
  /// **'工具'**
  String get settingsGroupTools;

  /// No description provided for @settingsGroupPrivacy.
  ///
  /// In zh, this message translates to:
  /// **'隐私'**
  String get settingsGroupPrivacy;

  /// No description provided for @settingsGroupAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get settingsGroupAbout;

  /// No description provided for @settingsServerSettings.
  ///
  /// In zh, this message translates to:
  /// **'服务器设置'**
  String get settingsServerSettings;

  /// No description provided for @settingsServerSettingsSub.
  ///
  /// In zh, this message translates to:
  /// **'OMM / DBO 平台配置'**
  String get settingsServerSettingsSub;

  /// No description provided for @settingsAppSettings.
  ///
  /// In zh, this message translates to:
  /// **'应用设置'**
  String get settingsAppSettings;

  /// No description provided for @settingsAppSettingsSub.
  ///
  /// In zh, this message translates to:
  /// **'语言 / 隐私 / 显示偏好'**
  String get settingsAppSettingsSub;

  /// No description provided for @settingsTheme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSub.
  ///
  /// In zh, this message translates to:
  /// **'界面亮色 / 暗色风格'**
  String get settingsThemeSub;

  /// No description provided for @themeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'亮色'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'暗色'**
  String get themeDark;

  /// No description provided for @settingsBadgePositions.
  ///
  /// In zh, this message translates to:
  /// **'封面角标位置'**
  String get settingsBadgePositions;

  /// No description provided for @settingsBadgePositionsSub.
  ///
  /// In zh, this message translates to:
  /// **'评分 / 字幕 / 破解 / 清晰度 / 新资源'**
  String get settingsBadgePositionsSub;

  /// No description provided for @badgeRating.
  ///
  /// In zh, this message translates to:
  /// **'评分'**
  String get badgeRating;

  /// No description provided for @badgeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'字幕'**
  String get badgeSubtitle;

  /// No description provided for @badgeCrack.
  ///
  /// In zh, this message translates to:
  /// **'破解'**
  String get badgeCrack;

  /// No description provided for @badgeResolution.
  ///
  /// In zh, this message translates to:
  /// **'清晰度'**
  String get badgeResolution;

  /// No description provided for @badgeNewResources.
  ///
  /// In zh, this message translates to:
  /// **'新资源'**
  String get badgeNewResources;

  /// No description provided for @badgeHidden.
  ///
  /// In zh, this message translates to:
  /// **'已隐藏'**
  String get badgeHidden;

  /// No description provided for @previewTitle.
  ///
  /// In zh, this message translates to:
  /// **'预览'**
  String get previewTitle;

  /// No description provided for @badgeOffsetTitle.
  ///
  /// In zh, this message translates to:
  /// **'位置微调'**
  String get badgeOffsetTitle;

  /// No description provided for @badgeOffsetHorizontal.
  ///
  /// In zh, this message translates to:
  /// **'左右'**
  String get badgeOffsetHorizontal;

  /// No description provided for @badgeOffsetVertical.
  ///
  /// In zh, this message translates to:
  /// **'上下'**
  String get badgeOffsetVertical;

  /// No description provided for @cornerTopLeft.
  ///
  /// In zh, this message translates to:
  /// **'左上'**
  String get cornerTopLeft;

  /// No description provided for @cornerTopRight.
  ///
  /// In zh, this message translates to:
  /// **'右上'**
  String get cornerTopRight;

  /// No description provided for @cornerBottomLeft.
  ///
  /// In zh, this message translates to:
  /// **'左下'**
  String get cornerBottomLeft;

  /// No description provided for @cornerBottomRight.
  ///
  /// In zh, this message translates to:
  /// **'右下'**
  String get cornerBottomRight;

  /// No description provided for @settingsServerUrl.
  ///
  /// In zh, this message translates to:
  /// **'服务器地址'**
  String get settingsServerUrl;

  /// No description provided for @settingsServerNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置'**
  String get settingsServerNotConfigured;

  /// No description provided for @settingsLibraries.
  ///
  /// In zh, this message translates to:
  /// **'媒体库管理'**
  String get settingsLibraries;

  /// No description provided for @settingsLibrariesSub.
  ///
  /// In zh, this message translates to:
  /// **'添加 / 编辑 / 扫描'**
  String get settingsLibrariesSub;

  /// No description provided for @libraryEditorName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get libraryEditorName;

  /// No description provided for @libraryEditorDirectories.
  ///
  /// In zh, this message translates to:
  /// **'目录'**
  String get libraryEditorDirectories;

  /// No description provided for @settingsActors.
  ///
  /// In zh, this message translates to:
  /// **'演员管理'**
  String get settingsActors;

  /// No description provided for @settingsActorsSub.
  ///
  /// In zh, this message translates to:
  /// **'演员信息、类型与影片关系'**
  String get settingsActorsSub;

  /// No description provided for @settingsGenres.
  ///
  /// In zh, this message translates to:
  /// **'分类管理'**
  String get settingsGenres;

  /// No description provided for @settingsTags.
  ///
  /// In zh, this message translates to:
  /// **'标签管理'**
  String get settingsTags;

  /// No description provided for @settingsSeries.
  ///
  /// In zh, this message translates to:
  /// **'系列管理'**
  String get settingsSeries;

  /// No description provided for @settingsTranslation.
  ///
  /// In zh, this message translates to:
  /// **'AI 翻译配置'**
  String get settingsTranslation;

  /// No description provided for @settingsTranslationSub.
  ///
  /// In zh, this message translates to:
  /// **'ChatGPT API · 自动翻译标题/简介'**
  String get settingsTranslationSub;

  /// No description provided for @settingsMappingTags.
  ///
  /// In zh, this message translates to:
  /// **'标签映射'**
  String get settingsMappingTags;

  /// No description provided for @settingsMappingGenres.
  ///
  /// In zh, this message translates to:
  /// **'分类映射'**
  String get settingsMappingGenres;

  /// No description provided for @settingsMappingSeries.
  ///
  /// In zh, this message translates to:
  /// **'系列映射'**
  String get settingsMappingSeries;

  /// No description provided for @settingsMappingSub.
  ///
  /// In zh, this message translates to:
  /// **'重命名 / 删除规则'**
  String get settingsMappingSub;

  /// No description provided for @settingsActorAssociations.
  ///
  /// In zh, this message translates to:
  /// **'演员关联'**
  String get settingsActorAssociations;

  /// No description provided for @settingsActorAssociationsSub.
  ///
  /// In zh, this message translates to:
  /// **'标准名 + 别名维护, 支持同步演员关联'**
  String get settingsActorAssociationsSub;

  /// No description provided for @settingsDbo.
  ///
  /// In zh, this message translates to:
  /// **'DB Online 数据源'**
  String get settingsDbo;

  /// No description provided for @settingsDboSub.
  ///
  /// In zh, this message translates to:
  /// **'影片下载 / 同步演员关联'**
  String get settingsDboSub;

  /// No description provided for @settingsExtensions.
  ///
  /// In zh, this message translates to:
  /// **'视频扩展名'**
  String get settingsExtensions;

  /// No description provided for @settingsExtensionsSub.
  ///
  /// In zh, this message translates to:
  /// **'扫描时识别的文件后缀'**
  String get settingsExtensionsSub;

  /// No description provided for @settingsPrivacyShield.
  ///
  /// In zh, this message translates to:
  /// **'隐私遮罩'**
  String get settingsPrivacyShield;

  /// No description provided for @settingsPrivacyShieldSub.
  ///
  /// In zh, this message translates to:
  /// **'后台切换时盖住预览图'**
  String get settingsPrivacyShieldSub;

  /// No description provided for @settingsShakePrivacy.
  ///
  /// In zh, this message translates to:
  /// **'摇一摇切换隐私模式'**
  String get settingsShakePrivacy;

  /// No description provided for @settingsShakePrivacySub.
  ///
  /// In zh, this message translates to:
  /// **'摇动设备快速开启或关闭隐私模式'**
  String get settingsShakePrivacySub;

  /// No description provided for @settingsLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSub.
  ///
  /// In zh, this message translates to:
  /// **'界面显示语言'**
  String get settingsLanguageSub;

  /// No description provided for @settingsVersion.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get settingsVersion;

  /// No description provided for @settingsLogout.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get settingsLogout;

  /// No description provided for @playerEnginePickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择播放器'**
  String get playerEnginePickerTitle;

  /// No description provided for @playerEnginePickerSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'仅用于本次播放，不会修改默认设置'**
  String get playerEnginePickerSubtitle;

  /// No description provided for @playerEnginePickerDefaultBadge.
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get playerEnginePickerDefaultBadge;

  /// No description provided for @languageSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get languageSystem;

  /// No description provided for @languageZh.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get languageZh;

  /// No description provided for @languageEn.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @privacyLockedTitle.
  ///
  /// In zh, this message translates to:
  /// **'已锁定'**
  String get privacyLockedTitle;

  /// No description provided for @privacyMode.
  ///
  /// In zh, this message translates to:
  /// **'隐私模式'**
  String get privacyMode;

  /// No description provided for @fileEyebrow.
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get fileEyebrow;

  /// No description provided for @fileListTitle.
  ///
  /// In zh, this message translates to:
  /// **'文件列表'**
  String get fileListTitle;

  /// No description provided for @fileSelectTargetDirectory.
  ///
  /// In zh, this message translates to:
  /// **'选择目标目录'**
  String get fileSelectTargetDirectory;

  /// No description provided for @fileSelectThisDirectory.
  ///
  /// In zh, this message translates to:
  /// **'选择此目录'**
  String get fileSelectThisDirectory;

  /// No description provided for @fileBatchActions.
  ///
  /// In zh, this message translates to:
  /// **'批量操作'**
  String get fileBatchActions;

  /// No description provided for @fileMoreActions.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get fileMoreActions;

  /// No description provided for @fileForceRefresh.
  ///
  /// In zh, this message translates to:
  /// **'强制刷新'**
  String get fileForceRefresh;

  /// No description provided for @fileCreateDirectory.
  ///
  /// In zh, this message translates to:
  /// **'新建文件夹'**
  String get fileCreateDirectory;

  /// No description provided for @fileUpload.
  ///
  /// In zh, this message translates to:
  /// **'上传文件'**
  String get fileUpload;

  /// No description provided for @fileSelect.
  ///
  /// In zh, this message translates to:
  /// **'选择'**
  String get fileSelect;

  /// No description provided for @fileShowHidden.
  ///
  /// In zh, this message translates to:
  /// **'显示隐藏文件'**
  String get fileShowHidden;

  /// No description provided for @fileSortName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get fileSortName;

  /// No description provided for @fileSortDate.
  ///
  /// In zh, this message translates to:
  /// **'日期'**
  String get fileSortDate;

  /// No description provided for @fileSortSize.
  ///
  /// In zh, this message translates to:
  /// **'大小'**
  String get fileSortSize;

  /// No description provided for @fileSortCategory.
  ///
  /// In zh, this message translates to:
  /// **'类别'**
  String get fileSortCategory;

  /// No description provided for @fileSortBy.
  ///
  /// In zh, this message translates to:
  /// **'{label}排序'**
  String fileSortBy(String label);

  /// No description provided for @fileSortByAsc.
  ///
  /// In zh, this message translates to:
  /// **'{label}排序 ↑'**
  String fileSortByAsc(String label);

  /// No description provided for @fileSortByDesc.
  ///
  /// In zh, this message translates to:
  /// **'{label}排序 ↓'**
  String fileSortByDesc(String label);

  /// No description provided for @fileExitSelection.
  ///
  /// In zh, this message translates to:
  /// **'退出选择'**
  String get fileExitSelection;

  /// No description provided for @fileCancelPicker.
  ///
  /// In zh, this message translates to:
  /// **'取消选择'**
  String get fileCancelPicker;

  /// No description provided for @fileBackToParent.
  ///
  /// In zh, this message translates to:
  /// **'返回上一级'**
  String get fileBackToParent;

  /// No description provided for @fileBackToServers.
  ///
  /// In zh, this message translates to:
  /// **'返回服务器选择'**
  String get fileBackToServers;

  /// No description provided for @fileRootDirectory.
  ///
  /// In zh, this message translates to:
  /// **'根目录'**
  String get fileRootDirectory;

  /// No description provided for @fileEmptyDirectory.
  ///
  /// In zh, this message translates to:
  /// **'此目录为空'**
  String get fileEmptyDirectory;

  /// No description provided for @fileFavoritesSection.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get fileFavoritesSection;

  /// No description provided for @fileFavoritesEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有收藏的文件或目录，可在文件列表的菜单中收藏常用内容'**
  String get fileFavoritesEmpty;

  /// No description provided for @fileFavoriteDirectoriesSection.
  ///
  /// In zh, this message translates to:
  /// **'收藏的目录'**
  String get fileFavoriteDirectoriesSection;

  /// No description provided for @fileAllFilesSection.
  ///
  /// In zh, this message translates to:
  /// **'全部文件'**
  String get fileAllFilesSection;

  /// No description provided for @fileUnfavorite.
  ///
  /// In zh, this message translates to:
  /// **'取消收藏'**
  String get fileUnfavorite;

  /// No description provided for @fileFavorite.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get fileFavorite;

  /// No description provided for @fileFavoriteAdded.
  ///
  /// In zh, this message translates to:
  /// **'已收藏“{name}”'**
  String fileFavoriteAdded(String name);

  /// No description provided for @fileFavoriteRemoved.
  ///
  /// In zh, this message translates to:
  /// **'已取消收藏“{name}”'**
  String fileFavoriteRemoved(String name);

  /// No description provided for @fileEntryActions.
  ///
  /// In zh, this message translates to:
  /// **'文件操作'**
  String get fileEntryActions;

  /// No description provided for @fileDetails.
  ///
  /// In zh, this message translates to:
  /// **'详情'**
  String get fileDetails;

  /// No description provided for @fileRename.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get fileRename;

  /// No description provided for @fileMove.
  ///
  /// In zh, this message translates to:
  /// **'移动'**
  String get fileMove;

  /// No description provided for @fileSelectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get fileSelectAll;

  /// No description provided for @fileClearSelection.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get fileClearSelection;

  /// No description provided for @fileDeleteSelected.
  ///
  /// In zh, this message translates to:
  /// **'删除所选'**
  String get fileDeleteSelected;

  /// No description provided for @fileFolderNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'文件夹名称'**
  String get fileFolderNameLabel;

  /// No description provided for @fileCreateDirectoryFailed.
  ///
  /// In zh, this message translates to:
  /// **'创建目录失败'**
  String get fileCreateDirectoryFailed;

  /// No description provided for @fileLocalPathLabel.
  ///
  /// In zh, this message translates to:
  /// **'本地文件路径'**
  String get fileLocalPathLabel;

  /// No description provided for @fileLocalFileMissing.
  ///
  /// In zh, this message translates to:
  /// **'本地文件不存在'**
  String get fileLocalFileMissing;

  /// No description provided for @fileUploadFailed.
  ///
  /// In zh, this message translates to:
  /// **'上传失败'**
  String get fileUploadFailed;

  /// No description provided for @fileUploadDone.
  ///
  /// In zh, this message translates to:
  /// **'上传完成'**
  String get fileUploadDone;

  /// No description provided for @fileUploadCanceled.
  ///
  /// In zh, this message translates to:
  /// **'上传已取消'**
  String get fileUploadCanceled;

  /// No description provided for @fileNewNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'新名称'**
  String get fileNewNameLabel;

  /// No description provided for @fileRenameFailed.
  ///
  /// In zh, this message translates to:
  /// **'重命名失败'**
  String get fileRenameFailed;

  /// No description provided for @fileMoveFailed.
  ///
  /// In zh, this message translates to:
  /// **'移动失败'**
  String get fileMoveFailed;

  /// No description provided for @fileInvalidMoveTarget.
  ///
  /// In zh, this message translates to:
  /// **'不能将目录移动到自身或其子目录'**
  String get fileInvalidMoveTarget;

  /// No description provided for @fileBatchMoveFailed.
  ///
  /// In zh, this message translates to:
  /// **'批量移动失败'**
  String get fileBatchMoveFailed;

  /// No description provided for @fileTargetExists.
  ///
  /// In zh, this message translates to:
  /// **'目标已存在'**
  String get fileTargetExists;

  /// No description provided for @fileBatchOverwritePrompt.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个目标已存在，是否覆盖后继续{action}？'**
  String fileBatchOverwritePrompt(int count, String action);

  /// No description provided for @fileOverwritePrompt.
  ///
  /// In zh, this message translates to:
  /// **'是否覆盖“{path}”？'**
  String fileOverwritePrompt(String path);

  /// No description provided for @fileOverwrite.
  ///
  /// In zh, this message translates to:
  /// **'覆盖'**
  String get fileOverwrite;

  /// No description provided for @fileBatchRenameFailed.
  ///
  /// In zh, this message translates to:
  /// **'批量重命名失败'**
  String get fileBatchRenameFailed;

  /// No description provided for @fileNoRenameChanges.
  ///
  /// In zh, this message translates to:
  /// **'没有可应用的名称变化'**
  String get fileNoRenameChanges;

  /// No description provided for @fileRenameDuplicatePreview.
  ///
  /// In zh, this message translates to:
  /// **'预览结果包含重复名称，请调整重命名规则'**
  String get fileRenameDuplicatePreview;

  /// No description provided for @fileRenameCollision.
  ///
  /// In zh, this message translates to:
  /// **'不能批量重命名为其他已选项的现有名称'**
  String get fileRenameCollision;

  /// No description provided for @fileBatchRenameTitle.
  ///
  /// In zh, this message translates to:
  /// **'批量重命名'**
  String get fileBatchRenameTitle;

  /// No description provided for @fileBatchRenameSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择规则并查看实时预览'**
  String get fileBatchRenameSubtitle;

  /// No description provided for @fileRenameMode.
  ///
  /// In zh, this message translates to:
  /// **'重命名模式'**
  String get fileRenameMode;

  /// No description provided for @fileRenameModeReplace.
  ///
  /// In zh, this message translates to:
  /// **'替换文本'**
  String get fileRenameModeReplace;

  /// No description provided for @fileRenameModeAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加文本'**
  String get fileRenameModeAdd;

  /// No description provided for @fileRenameSearchLabel.
  ///
  /// In zh, this message translates to:
  /// **'查询'**
  String get fileRenameSearchLabel;

  /// No description provided for @fileRenameReplaceLabel.
  ///
  /// In zh, this message translates to:
  /// **'替换为'**
  String get fileRenameReplaceLabel;

  /// No description provided for @fileRenameAddTextLabel.
  ///
  /// In zh, this message translates to:
  /// **'添加文本'**
  String get fileRenameAddTextLabel;

  /// No description provided for @fileRenameAddPosition.
  ///
  /// In zh, this message translates to:
  /// **'添加位置'**
  String get fileRenameAddPosition;

  /// No description provided for @fileRenameAddBefore.
  ///
  /// In zh, this message translates to:
  /// **'在名字之前'**
  String get fileRenameAddBefore;

  /// No description provided for @fileRenameAddAfter.
  ///
  /// In zh, this message translates to:
  /// **'在名字之后'**
  String get fileRenameAddAfter;

  /// No description provided for @filePreviewSection.
  ///
  /// In zh, this message translates to:
  /// **'预览'**
  String get filePreviewSection;

  /// No description provided for @fileApply.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get fileApply;

  /// No description provided for @fileDeleteConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认删除？'**
  String get fileDeleteConfirmTitle;

  /// No description provided for @fileDeleteConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'将从远程文件来源删除“{name}”，此操作不可撤销。'**
  String fileDeleteConfirmBody(String name);

  /// No description provided for @fileDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败'**
  String get fileDeleteFailed;

  /// No description provided for @fileBatchDeleteConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认批量删除？'**
  String get fileBatchDeleteConfirmTitle;

  /// No description provided for @fileBatchDeleteConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'将从远程文件来源删除已选择的 {n} 项，此操作不可撤销。'**
  String fileBatchDeleteConfirmBody(int n);

  /// No description provided for @fileBatchDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'批量删除失败'**
  String get fileBatchDeleteFailed;

  /// No description provided for @fileDirectoryDetails.
  ///
  /// In zh, this message translates to:
  /// **'目录详情'**
  String get fileDirectoryDetails;

  /// No description provided for @fileFileDetails.
  ///
  /// In zh, this message translates to:
  /// **'文件详情'**
  String get fileFileDetails;

  /// No description provided for @filePathLabel.
  ///
  /// In zh, this message translates to:
  /// **'路径：{path}'**
  String filePathLabel(String path);

  /// No description provided for @fileSizeLabel.
  ///
  /// In zh, this message translates to:
  /// **'大小：{size}'**
  String fileSizeLabel(String size);

  /// No description provided for @fileTypeLabel.
  ///
  /// In zh, this message translates to:
  /// **'类型：{type}'**
  String fileTypeLabel(String type);

  /// No description provided for @fileModifiedAtLabel.
  ///
  /// In zh, this message translates to:
  /// **'修改时间：{time}'**
  String fileModifiedAtLabel(String time);

  /// No description provided for @fileWebDavDirectUrlMissing.
  ///
  /// In zh, this message translates to:
  /// **'服务器未提供 HTTP 直连地址，已停止播放（不会回退到本机代理）'**
  String get fileWebDavDirectUrlMissing;

  /// No description provided for @fileVideoPreviewFailed.
  ///
  /// In zh, this message translates to:
  /// **'视频预览失败：{error}'**
  String fileVideoPreviewFailed(String error);

  /// No description provided for @fileAudioPreviewFailed.
  ///
  /// In zh, this message translates to:
  /// **'音频预览失败：{error}'**
  String fileAudioPreviewFailed(String error);

  /// No description provided for @fileImagePreviewFailed.
  ///
  /// In zh, this message translates to:
  /// **'图片预览失败：{error}'**
  String fileImagePreviewFailed(String error);

  /// No description provided for @fileTextPreviewFailed.
  ///
  /// In zh, this message translates to:
  /// **'文本预览失败：{error}'**
  String fileTextPreviewFailed(String error);

  /// No description provided for @fileRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get fileRetry;

  /// No description provided for @fileUploadAction.
  ///
  /// In zh, this message translates to:
  /// **'上传'**
  String get fileUploadAction;

  /// No description provided for @fileFileOperation.
  ///
  /// In zh, this message translates to:
  /// **'文件操作'**
  String get fileFileOperation;

  /// No description provided for @fileOperationRunning.
  ///
  /// In zh, this message translates to:
  /// **'{action}进行中'**
  String fileOperationRunning(String action);

  /// No description provided for @fileOperationCompleted.
  ///
  /// In zh, this message translates to:
  /// **'{action}完成'**
  String fileOperationCompleted(String action);

  /// No description provided for @fileOperationCanceled.
  ///
  /// In zh, this message translates to:
  /// **'{action}已取消'**
  String fileOperationCanceled(String action);

  /// No description provided for @fileOperationFailed.
  ///
  /// In zh, this message translates to:
  /// **'{action}失败'**
  String fileOperationFailed(String action);

  /// No description provided for @fileOperationPending.
  ///
  /// In zh, this message translates to:
  /// **'{action}等待中'**
  String fileOperationPending(String action);

  /// No description provided for @filePlaybackProgress.
  ///
  /// In zh, this message translates to:
  /// **'播放进度'**
  String get filePlaybackProgress;

  /// No description provided for @fileNotFileServer.
  ///
  /// In zh, this message translates to:
  /// **'当前服务器不是文件服务器'**
  String get fileNotFileServer;

  /// No description provided for @fileChooseFileServer.
  ///
  /// In zh, this message translates to:
  /// **'选择文件服务器'**
  String get fileChooseFileServer;

  /// No description provided for @fileNoAvailableSource.
  ///
  /// In zh, this message translates to:
  /// **'当前服务器没有可用的文件来源'**
  String get fileNoAvailableSource;

  /// No description provided for @fileManageServers.
  ///
  /// In zh, this message translates to:
  /// **'管理服务器'**
  String get fileManageServers;

  /// No description provided for @settingsGroupGeneral.
  ///
  /// In zh, this message translates to:
  /// **'通用'**
  String get settingsGroupGeneral;

  /// No description provided for @settingsGroupFileManager.
  ///
  /// In zh, this message translates to:
  /// **'文件管理器'**
  String get settingsGroupFileManager;

  /// No description provided for @settingsGroupPlayer.
  ///
  /// In zh, this message translates to:
  /// **'播放器'**
  String get settingsGroupPlayer;

  /// No description provided for @settingsSecurity.
  ///
  /// In zh, this message translates to:
  /// **'安全设置'**
  String get settingsSecurity;

  /// No description provided for @settingsSecuritySub.
  ///
  /// In zh, this message translates to:
  /// **'面容/指纹、进入密码、手势密码'**
  String get settingsSecuritySub;

  /// No description provided for @settingsPosterBadges.
  ///
  /// In zh, this message translates to:
  /// **'海报角标显示'**
  String get settingsPosterBadges;

  /// No description provided for @settingsPosterBadgesSub.
  ///
  /// In zh, this message translates to:
  /// **'编码 / HDR / STRM / 字幕 / 破解 / HD'**
  String get settingsPosterBadgesSub;

  /// No description provided for @settingsPlayerSettings.
  ///
  /// In zh, this message translates to:
  /// **'播放器设置'**
  String get settingsPlayerSettings;

  /// No description provided for @settingsPlayerSettingsSub.
  ///
  /// In zh, this message translates to:
  /// **'播放进度 / 屏幕方向 / OSD / 播放按钮 / 手势反馈'**
  String get settingsPlayerSettingsSub;

  /// No description provided for @settingsSubtitleSettings.
  ///
  /// In zh, this message translates to:
  /// **'字幕设置'**
  String get settingsSubtitleSettings;

  /// No description provided for @settingsSubtitleSettingsSub.
  ///
  /// In zh, this message translates to:
  /// **'记忆选择 / 字体 / 颜色 / 描边 / 阴影'**
  String get settingsSubtitleSettingsSub;

  /// No description provided for @settingsCacheManagement.
  ///
  /// In zh, this message translates to:
  /// **'缓存管理'**
  String get settingsCacheManagement;

  /// No description provided for @settingsCacheManagementSub.
  ///
  /// In zh, this message translates to:
  /// **'磁盘缓存额度 / 缓存分类 / 一键清理'**
  String get settingsCacheManagementSub;

  /// No description provided for @settingsHapticIntensity.
  ///
  /// In zh, this message translates to:
  /// **'震动反馈强度'**
  String get settingsHapticIntensity;

  /// No description provided for @settingsHapticCurrent.
  ///
  /// In zh, this message translates to:
  /// **'当前：{label}'**
  String settingsHapticCurrent(String label);

  /// No description provided for @settingsImagePreview.
  ///
  /// In zh, this message translates to:
  /// **'图片预览'**
  String get settingsImagePreview;

  /// No description provided for @settingsImagePreviewSub.
  ///
  /// In zh, this message translates to:
  /// **'在文件列表中显示图片缩略图'**
  String get settingsImagePreviewSub;

  /// No description provided for @settingsMoveStartLocation.
  ///
  /// In zh, this message translates to:
  /// **'移动文件起始位置'**
  String get settingsMoveStartLocation;

  /// No description provided for @settingsMoveStartCurrentRoot.
  ///
  /// In zh, this message translates to:
  /// **'当前：根目录'**
  String get settingsMoveStartCurrentRoot;

  /// No description provided for @settingsMoveStartCurrentHere.
  ///
  /// In zh, this message translates to:
  /// **'当前：所在目录'**
  String get settingsMoveStartCurrentHere;

  /// No description provided for @settingsMoveStartHere.
  ///
  /// In zh, this message translates to:
  /// **'当前所在目录'**
  String get settingsMoveStartHere;

  /// No description provided for @settingsMoveStartRootSub.
  ///
  /// In zh, this message translates to:
  /// **'移动文件时每次从根目录开始选择目标'**
  String get settingsMoveStartRootSub;

  /// No description provided for @settingsMoveStartHereSub.
  ///
  /// In zh, this message translates to:
  /// **'移动文件时从当前所在目录开始选择目标'**
  String get settingsMoveStartHereSub;

  /// No description provided for @fileSelectedItems.
  ///
  /// In zh, this message translates to:
  /// **'已选 {n} 项'**
  String fileSelectedItems(int n);

  /// No description provided for @playerShuffleOn.
  ///
  /// In zh, this message translates to:
  /// **'开启随机播放'**
  String get playerShuffleOn;

  /// No description provided for @playerShuffleOff.
  ///
  /// In zh, this message translates to:
  /// **'关闭随机播放'**
  String get playerShuffleOff;

  /// No description provided for @playerRepeatOff.
  ///
  /// In zh, this message translates to:
  /// **'循环：关闭'**
  String get playerRepeatOff;

  /// No description provided for @playerRepeatOne.
  ///
  /// In zh, this message translates to:
  /// **'循环：单曲'**
  String get playerRepeatOne;

  /// No description provided for @playerRepeatAll.
  ///
  /// In zh, this message translates to:
  /// **'循环：列表'**
  String get playerRepeatAll;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'zh':
      return AppL10nZh();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
