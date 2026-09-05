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
  /// **'{n} 已选'**
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

  /// No description provided for @more.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get more;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

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
  /// **'媒体库设置'**
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
  /// **'评分 / 字幕、破解、清晰度 / 新资源'**
  String get settingsBadgePositionsSub;

  /// No description provided for @badgeRating.
  ///
  /// In zh, this message translates to:
  /// **'评分'**
  String get badgeRating;

  /// No description provided for @badgeContentGroup.
  ///
  /// In zh, this message translates to:
  /// **'字幕 / 破解 / 清晰度'**
  String get badgeContentGroup;

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

  /// No description provided for @badgePositionController.
  ///
  /// In zh, this message translates to:
  /// **'统一角位控制器'**
  String get badgePositionController;

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
  /// **'类型管理'**
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
  /// **'类型映射'**
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

  /// No description provided for @fileOpenAsText.
  ///
  /// In zh, this message translates to:
  /// **'以文本方式打开'**
  String get fileOpenAsText;

  /// No description provided for @fileTextEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get fileTextEdit;

  /// No description provided for @fileTextSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get fileTextSave;

  /// No description provided for @fileTextSaving.
  ///
  /// In zh, this message translates to:
  /// **'保存中...'**
  String get fileTextSaving;

  /// No description provided for @fileTextSaveSuccess.
  ///
  /// In zh, this message translates to:
  /// **'保存成功'**
  String get fileTextSaveSuccess;

  /// No description provided for @fileTextSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败：{error}'**
  String fileTextSaveFailed(String error);

  /// No description provided for @fileTextUnsavedTitle.
  ///
  /// In zh, this message translates to:
  /// **'未保存修改'**
  String get fileTextUnsavedTitle;

  /// No description provided for @fileTextUnsavedMessage.
  ///
  /// In zh, this message translates to:
  /// **'有未保存的修改，是否保存后离开？'**
  String get fileTextUnsavedMessage;

  /// No description provided for @fileTextDiscard.
  ///
  /// In zh, this message translates to:
  /// **'放弃修改'**
  String get fileTextDiscard;

  /// No description provided for @fileTextSaveAndLeave.
  ///
  /// In zh, this message translates to:
  /// **'保存并离开'**
  String get fileTextSaveAndLeave;

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

  /// No description provided for @settingsPerformanceMonitor.
  ///
  /// In zh, this message translates to:
  /// **'性能监视器'**
  String get settingsPerformanceMonitor;

  /// No description provided for @settingsPerformanceMonitorSub.
  ///
  /// In zh, this message translates to:
  /// **'显示 FPS、应用 CPU 和 RAM 使用量'**
  String get settingsPerformanceMonitorSub;

  /// No description provided for @settingsHapticIntensity.
  ///
  /// In zh, this message translates to:
  /// **'震动反馈强度'**
  String get settingsHapticIntensity;

  /// No description provided for @settingsServerSelectionShowUsername.
  ///
  /// In zh, this message translates to:
  /// **'显示用户名'**
  String get settingsServerSelectionShowUsername;

  /// No description provided for @settingsServerSelectionShowUsernameSub.
  ///
  /// In zh, this message translates to:
  /// **'连接页显示用户名，否则显示指定名称'**
  String get settingsServerSelectionShowUsernameSub;

  /// No description provided for @settingsServerSelectionShowAvatar.
  ///
  /// In zh, this message translates to:
  /// **'显示用户头像'**
  String get settingsServerSelectionShowAvatar;

  /// No description provided for @settingsServerSelectionShowAvatarSub.
  ///
  /// In zh, this message translates to:
  /// **'连接页显示头像，否则显示服务器Logo'**
  String get settingsServerSelectionShowAvatarSub;

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

  /// No description provided for @playerLyricsTitle.
  ///
  /// In zh, this message translates to:
  /// **'歌词'**
  String get playerLyricsTitle;

  /// No description provided for @playerLyricsUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'暂无歌词'**
  String get playerLyricsUnavailable;

  /// No description provided for @playerDjDeck.
  ///
  /// In zh, this message translates to:
  /// **'DJ 唱盘'**
  String get playerDjDeck;

  /// No description provided for @playerDjDeckA.
  ///
  /// In zh, this message translates to:
  /// **'DECK A'**
  String get playerDjDeckA;

  /// No description provided for @playerDjPlaying.
  ///
  /// In zh, this message translates to:
  /// **'播放中'**
  String get playerDjPlaying;

  /// No description provided for @playerDjPaused.
  ///
  /// In zh, this message translates to:
  /// **'已暂停'**
  String get playerDjPaused;

  /// No description provided for @playerDjGestureHint.
  ///
  /// In zh, this message translates to:
  /// **'点按播放或暂停，旋拧唱片定位'**
  String get playerDjGestureHint;

  /// No description provided for @playerDjPitch.
  ///
  /// In zh, this message translates to:
  /// **'速度'**
  String get playerDjPitch;

  /// No description provided for @playerClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get playerClose;

  /// No description provided for @commonRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get commonRetry;

  /// No description provided for @commonNoData.
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get commonNoData;

  /// No description provided for @commonSelectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get commonSelectAll;

  /// No description provided for @commonClearSelection.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get commonClearSelection;

  /// No description provided for @commonExitSelection.
  ///
  /// In zh, this message translates to:
  /// **'退出多选'**
  String get commonExitSelection;

  /// No description provided for @paginationNoMore.
  ///
  /// In zh, this message translates to:
  /// **'没有更多内容'**
  String get paginationNoMore;

  /// No description provided for @paginationLoadFailedRetry.
  ///
  /// In zh, this message translates to:
  /// **'加载更多失败，点击重试'**
  String get paginationLoadFailedRetry;

  /// No description provided for @posterOnlinePlay.
  ///
  /// In zh, this message translates to:
  /// **'在线播放'**
  String get posterOnlinePlay;

  /// No description provided for @movieCardSubExternal.
  ///
  /// In zh, this message translates to:
  /// **'外挂字幕'**
  String get movieCardSubExternal;

  /// No description provided for @movieCardSubAi.
  ///
  /// In zh, this message translates to:
  /// **'AI 字幕'**
  String get movieCardSubAi;

  /// No description provided for @movieCardSubMuxedTrack.
  ///
  /// In zh, this message translates to:
  /// **'内嵌字幕轨道'**
  String get movieCardSubMuxedTrack;

  /// No description provided for @movieCardSubFilename.
  ///
  /// In zh, this message translates to:
  /// **'内嵌字幕'**
  String get movieCardSubFilename;

  /// No description provided for @movieCardSubStack.
  ///
  /// In zh, this message translates to:
  /// **'字幕 ×{n}（点按展开）'**
  String movieCardSubStack(int n);

  /// No description provided for @movieCardSubChinese.
  ///
  /// In zh, this message translates to:
  /// **'中字'**
  String get movieCardSubChinese;

  /// No description provided for @movieCardRestricted.
  ///
  /// In zh, this message translates to:
  /// **'受限影片'**
  String get movieCardRestricted;

  /// No description provided for @movieCardUntitledTitle.
  ///
  /// In zh, this message translates to:
  /// **'未命名影片'**
  String get movieCardUntitledTitle;

  /// No description provided for @movieCardUntitledCode.
  ///
  /// In zh, this message translates to:
  /// **'未命名番号'**
  String get movieCardUntitledCode;

  /// No description provided for @movieCardNoMeta.
  ///
  /// In zh, this message translates to:
  /// **'暂无信息'**
  String get movieCardNoMeta;

  /// No description provided for @movieCardCrack.
  ///
  /// In zh, this message translates to:
  /// **'破解 / 无码'**
  String get movieCardCrack;

  /// No description provided for @statusIdle.
  ///
  /// In zh, this message translates to:
  /// **'准备中'**
  String get statusIdle;

  /// No description provided for @statusPending.
  ///
  /// In zh, this message translates to:
  /// **'排队中'**
  String get statusPending;

  /// No description provided for @statusRunning.
  ///
  /// In zh, this message translates to:
  /// **'进行中'**
  String get statusRunning;

  /// No description provided for @statusPaused.
  ///
  /// In zh, this message translates to:
  /// **'已暂停'**
  String get statusPaused;

  /// No description provided for @statusCompleted.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get statusCompleted;

  /// No description provided for @statusSkipped.
  ///
  /// In zh, this message translates to:
  /// **'已跳过'**
  String get statusSkipped;

  /// No description provided for @statusCanceled.
  ///
  /// In zh, this message translates to:
  /// **'已取消'**
  String get statusCanceled;

  /// No description provided for @statusFailed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get statusFailed;

  /// No description provided for @statusUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get statusUnknown;

  /// No description provided for @commonClearInput.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get commonClearInput;

  /// No description provided for @securityVerifyIncomplete.
  ///
  /// In zh, this message translates to:
  /// **'验证未完成，请重试或使用其他解锁方式'**
  String get securityVerifyIncomplete;

  /// No description provided for @securityPinIncorrect.
  ///
  /// In zh, this message translates to:
  /// **'数字密码不正确'**
  String get securityPinIncorrect;

  /// No description provided for @securityPatternIncorrect.
  ///
  /// In zh, this message translates to:
  /// **'手势密码不正确'**
  String get securityPatternIncorrect;

  /// No description provided for @securityAppLocked.
  ///
  /// In zh, this message translates to:
  /// **'应用已锁定'**
  String get securityAppLocked;

  /// No description provided for @securityUnlockPrompt.
  ///
  /// In zh, this message translates to:
  /// **'验证身份后继续使用 Oh My Media'**
  String get securityUnlockPrompt;

  /// No description provided for @securityBiometricUnlock.
  ///
  /// In zh, this message translates to:
  /// **'使用面容/指纹解锁'**
  String get securityBiometricUnlock;

  /// No description provided for @securityVerifying.
  ///
  /// In zh, this message translates to:
  /// **'验证中…'**
  String get securityVerifying;

  /// No description provided for @securityPasswordUnlock.
  ///
  /// In zh, this message translates to:
  /// **'使用密码/滑动解锁'**
  String get securityPasswordUnlock;

  /// No description provided for @securityPinCode.
  ///
  /// In zh, this message translates to:
  /// **'数字密码'**
  String get securityPinCode;

  /// No description provided for @securitySwipeUnlock.
  ///
  /// In zh, this message translates to:
  /// **'滑动解锁'**
  String get securitySwipeUnlock;

  /// No description provided for @securityUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'安全验证不可用，请重试'**
  String get securityUnavailable;

  /// No description provided for @securityBiometricReason.
  ///
  /// In zh, this message translates to:
  /// **'请验证身份以进入 Oh My Media'**
  String get securityBiometricReason;

  /// No description provided for @accessControlTitle.
  ///
  /// In zh, this message translates to:
  /// **'访问控制'**
  String get accessControlTitle;

  /// No description provided for @badgeCodec.
  ///
  /// In zh, this message translates to:
  /// **'角标编码'**
  String get badgeCodec;

  /// No description provided for @cacheCategoryMusic.
  ///
  /// In zh, this message translates to:
  /// **'音乐'**
  String get cacheCategoryMusic;

  /// No description provided for @commonAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get commonAdd;

  /// No description provided for @commonLoading.
  ///
  /// In zh, this message translates to:
  /// **'读取中…'**
  String get commonLoading;

  /// No description provided for @commonReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'读取失败'**
  String get commonReadFailed;

  /// No description provided for @commonSaveSettings.
  ///
  /// In zh, this message translates to:
  /// **'保存设置'**
  String get commonSaveSettings;

  /// No description provided for @commonSaving.
  ///
  /// In zh, this message translates to:
  /// **'保存中...'**
  String get commonSaving;

  /// No description provided for @commonUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get commonUnknown;

  /// No description provided for @dbOnlineAscending.
  ///
  /// In zh, this message translates to:
  /// **'升序'**
  String get dbOnlineAscending;

  /// No description provided for @dbOnlineAutoLoadMoreHint.
  ///
  /// In zh, this message translates to:
  /// **'滚动到底部自动加载更多。'**
  String get dbOnlineAutoLoadMoreHint;

  /// No description provided for @dbOnlineBackendConfigSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'配置 DB Online 后端'**
  String get dbOnlineBackendConfigSubtitle;

  /// No description provided for @dbOnlineBackendConfigTitle.
  ///
  /// In zh, this message translates to:
  /// **'DB Online 后端'**
  String get dbOnlineBackendConfigTitle;

  /// No description provided for @dbOnlineBadgeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'DB Online 数据'**
  String get dbOnlineBadgeSubtitle;

  /// No description provided for @dbOnlineCategoryAnime.
  ///
  /// In zh, this message translates to:
  /// **'动漫'**
  String get dbOnlineCategoryAnime;

  /// No description provided for @dbOnlineCategoryCensored.
  ///
  /// In zh, this message translates to:
  /// **'有码'**
  String get dbOnlineCategoryCensored;

  /// No description provided for @dbOnlineCategorySection.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get dbOnlineCategorySection;

  /// No description provided for @dbOnlineCategoryUncensored.
  ///
  /// In zh, this message translates to:
  /// **'无码'**
  String get dbOnlineCategoryUncensored;

  /// No description provided for @dbOnlineCategoryWestern.
  ///
  /// In zh, this message translates to:
  /// **'欧美'**
  String get dbOnlineCategoryWestern;

  /// No description provided for @dbOnlineConfigLoadError.
  ///
  /// In zh, this message translates to:
  /// **'DB Online 配置加载失败'**
  String get dbOnlineConfigLoadError;

  /// No description provided for @dbOnlineConnectionFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败'**
  String get dbOnlineConnectionFailed;

  /// No description provided for @dbOnlineConnectionOk.
  ///
  /// In zh, this message translates to:
  /// **'连接正常'**
  String get dbOnlineConnectionOk;

  /// No description provided for @dbOnlineDefaultPlaySource.
  ///
  /// In zh, this message translates to:
  /// **'播放源 {id}'**
  String dbOnlineDefaultPlaySource(int id);

  /// No description provided for @dbOnlineDescending.
  ///
  /// In zh, this message translates to:
  /// **'降序'**
  String get dbOnlineDescending;

  /// No description provided for @dbOnlineDetailDate.
  ///
  /// In zh, this message translates to:
  /// **'发布日期'**
  String get dbOnlineDetailDate;

  /// No description provided for @dbOnlineDetailRatingCount.
  ///
  /// In zh, this message translates to:
  /// **'评分人数'**
  String get dbOnlineDetailRatingCount;

  /// No description provided for @dbOnlineDetailsSection.
  ///
  /// In zh, this message translates to:
  /// **'详情'**
  String get dbOnlineDetailsSection;

  /// No description provided for @dbOnlineEpisodeNumber.
  ///
  /// In zh, this message translates to:
  /// **'第 {number} 集'**
  String dbOnlineEpisodeNumber(int number);

  /// No description provided for @dbOnlineEpisodesSection.
  ///
  /// In zh, this message translates to:
  /// **'集数'**
  String get dbOnlineEpisodesSection;

  /// No description provided for @dbOnlineFieldApiUrl.
  ///
  /// In zh, this message translates to:
  /// **'API 地址'**
  String get dbOnlineFieldApiUrl;

  /// No description provided for @dbOnlineFieldApiUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'后端 API 地址。'**
  String get dbOnlineFieldApiUrlHint;

  /// No description provided for @dbOnlineFieldAuthorization.
  ///
  /// In zh, this message translates to:
  /// **'授权'**
  String get dbOnlineFieldAuthorization;

  /// No description provided for @dbOnlineFieldAutoplay.
  ///
  /// In zh, this message translates to:
  /// **'自动播放'**
  String get dbOnlineFieldAutoplay;

  /// No description provided for @dbOnlineFieldCaptions.
  ///
  /// In zh, this message translates to:
  /// **'字幕'**
  String get dbOnlineFieldCaptions;

  /// No description provided for @dbOnlineFieldCategoryId.
  ///
  /// In zh, this message translates to:
  /// **'类型 ID'**
  String get dbOnlineFieldCategoryId;

  /// No description provided for @dbOnlineFieldCategoryIdHint.
  ///
  /// In zh, this message translates to:
  /// **'填写数据源对应的类型 ID'**
  String get dbOnlineFieldCategoryIdHint;

  /// No description provided for @dbOnlineFieldCategoryOptional.
  ///
  /// In zh, this message translates to:
  /// **'类型（可选）'**
  String get dbOnlineFieldCategoryOptional;

  /// No description provided for @dbOnlineFieldCheckIntervalHint.
  ///
  /// In zh, this message translates to:
  /// **'设置自动检查配置的时间间隔'**
  String get dbOnlineFieldCheckIntervalHint;

  /// No description provided for @dbOnlineFieldCheckIntervalMinutes.
  ///
  /// In zh, this message translates to:
  /// **'检查间隔（分钟）'**
  String get dbOnlineFieldCheckIntervalMinutes;

  /// No description provided for @dbOnlineFieldConcurrency.
  ///
  /// In zh, this message translates to:
  /// **'并发数'**
  String get dbOnlineFieldConcurrency;

  /// No description provided for @dbOnlineFieldCookie.
  ///
  /// In zh, this message translates to:
  /// **'Cookie'**
  String get dbOnlineFieldCookie;

  /// No description provided for @dbOnlineFieldDeviceId.
  ///
  /// In zh, this message translates to:
  /// **'设备 ID'**
  String get dbOnlineFieldDeviceId;

  /// No description provided for @dbOnlineFieldEnablePlayer.
  ///
  /// In zh, this message translates to:
  /// **'启用播放器'**
  String get dbOnlineFieldEnablePlayer;

  /// No description provided for @dbOnlineFieldEnableProxy.
  ///
  /// In zh, this message translates to:
  /// **'启用代理'**
  String get dbOnlineFieldEnableProxy;

  /// No description provided for @dbOnlineFieldEnableRetry.
  ///
  /// In zh, this message translates to:
  /// **'启用重试'**
  String get dbOnlineFieldEnableRetry;

  /// No description provided for @dbOnlineFieldEnableSubscription.
  ///
  /// In zh, this message translates to:
  /// **'启用订阅'**
  String get dbOnlineFieldEnableSubscription;

  /// No description provided for @dbOnlineFieldEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已启用'**
  String get dbOnlineFieldEnabled;

  /// No description provided for @dbOnlineFieldFullscreen.
  ///
  /// In zh, this message translates to:
  /// **'全屏'**
  String get dbOnlineFieldFullscreen;

  /// No description provided for @dbOnlineFieldHost.
  ///
  /// In zh, this message translates to:
  /// **'主机'**
  String get dbOnlineFieldHost;

  /// No description provided for @dbOnlineFieldImageMode.
  ///
  /// In zh, this message translates to:
  /// **'图片模式'**
  String get dbOnlineFieldImageMode;

  /// No description provided for @dbOnlineFieldImageUrlReplacePrefix.
  ///
  /// In zh, this message translates to:
  /// **'图片 URL 替换前缀'**
  String get dbOnlineFieldImageUrlReplacePrefix;

  /// No description provided for @dbOnlineFieldImageUrlReplacePrefixHint.
  ///
  /// In zh, this message translates to:
  /// **'将图片地址中的指定前缀替换为代理地址'**
  String get dbOnlineFieldImageUrlReplacePrefixHint;

  /// No description provided for @dbOnlineFieldIntervalRangeHint.
  ///
  /// In zh, this message translates to:
  /// **'设置允许的检查间隔范围'**
  String get dbOnlineFieldIntervalRangeHint;

  /// No description provided for @dbOnlineFieldIntervalRangeSeconds.
  ///
  /// In zh, this message translates to:
  /// **'间隔范围（秒）'**
  String get dbOnlineFieldIntervalRangeSeconds;

  /// No description provided for @dbOnlineFieldKeyboard.
  ///
  /// In zh, this message translates to:
  /// **'键盘'**
  String get dbOnlineFieldKeyboard;

  /// No description provided for @dbOnlineFieldMaskHint.
  ///
  /// In zh, this message translates to:
  /// **'敏感信息将被遮罩'**
  String get dbOnlineFieldMaskHint;

  /// No description provided for @dbOnlineFieldOptionalMaskHint.
  ///
  /// In zh, this message translates to:
  /// **'可选；留空以保留当前值'**
  String get dbOnlineFieldOptionalMaskHint;

  /// No description provided for @dbOnlineFieldParentFolderId.
  ///
  /// In zh, this message translates to:
  /// **'父文件夹 ID'**
  String get dbOnlineFieldParentFolderId;

  /// No description provided for @dbOnlineFieldPassword.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get dbOnlineFieldPassword;

  /// No description provided for @dbOnlineFieldPasswordOptional.
  ///
  /// In zh, this message translates to:
  /// **'密码（可选）'**
  String get dbOnlineFieldPasswordOptional;

  /// No description provided for @dbOnlineFieldPip.
  ///
  /// In zh, this message translates to:
  /// **'画中画'**
  String get dbOnlineFieldPip;

  /// No description provided for @dbOnlineFieldPort.
  ///
  /// In zh, this message translates to:
  /// **'端口'**
  String get dbOnlineFieldPort;

  /// No description provided for @dbOnlineFieldProtocol.
  ///
  /// In zh, this message translates to:
  /// **'协议'**
  String get dbOnlineFieldProtocol;

  /// No description provided for @dbOnlineFieldRequestTimeoutSeconds.
  ///
  /// In zh, this message translates to:
  /// **'请求超时（秒）'**
  String get dbOnlineFieldRequestTimeoutSeconds;

  /// No description provided for @dbOnlineFieldReserveQuotaGb.
  ///
  /// In zh, this message translates to:
  /// **'保留配额（GB）'**
  String get dbOnlineFieldReserveQuotaGb;

  /// No description provided for @dbOnlineFieldRetryCount.
  ///
  /// In zh, this message translates to:
  /// **'重试次数'**
  String get dbOnlineFieldRetryCount;

  /// No description provided for @dbOnlineFieldRetryIntervalSeconds.
  ///
  /// In zh, this message translates to:
  /// **'重试间隔（秒）'**
  String get dbOnlineFieldRetryIntervalSeconds;

  /// No description provided for @dbOnlineFieldRpcSecret.
  ///
  /// In zh, this message translates to:
  /// **'RPC 密钥'**
  String get dbOnlineFieldRpcSecret;

  /// No description provided for @dbOnlineFieldSavePath.
  ///
  /// In zh, this message translates to:
  /// **'保存路径'**
  String get dbOnlineFieldSavePath;

  /// No description provided for @dbOnlineFieldTimeoutSeconds.
  ///
  /// In zh, this message translates to:
  /// **'超时时间（秒）'**
  String get dbOnlineFieldTimeoutSeconds;

  /// No description provided for @dbOnlineFieldUseHttps.
  ///
  /// In zh, this message translates to:
  /// **'使用 HTTPS'**
  String get dbOnlineFieldUseHttps;

  /// No description provided for @dbOnlineFieldUsername.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get dbOnlineFieldUsername;

  /// No description provided for @dbOnlineFieldUsernameOptional.
  ///
  /// In zh, this message translates to:
  /// **'用户名（可选）'**
  String get dbOnlineFieldUsernameOptional;

  /// No description provided for @dbOnlineFilterMovieType.
  ///
  /// In zh, this message translates to:
  /// **'筛选影片类型'**
  String get dbOnlineFilterMovieType;

  /// No description provided for @dbOnlineGroupDownloader.
  ///
  /// In zh, this message translates to:
  /// **'下载器'**
  String get dbOnlineGroupDownloader;

  /// No description provided for @dbOnlineGroupMediaLibrary.
  ///
  /// In zh, this message translates to:
  /// **'媒体库'**
  String get dbOnlineGroupMediaLibrary;

  /// No description provided for @dbOnlineGroupSystem.
  ///
  /// In zh, this message translates to:
  /// **'系统'**
  String get dbOnlineGroupSystem;

  /// No description provided for @dbOnlineHidePassword.
  ///
  /// In zh, this message translates to:
  /// **'隐藏密码'**
  String get dbOnlineHidePassword;

  /// No description provided for @dbOnlineImageModeDecrypt.
  ///
  /// In zh, this message translates to:
  /// **'解密'**
  String get dbOnlineImageModeDecrypt;

  /// No description provided for @dbOnlineImageModeReplace.
  ///
  /// In zh, this message translates to:
  /// **'替换'**
  String get dbOnlineImageModeReplace;

  /// No description provided for @dbOnlineInLibrary.
  ///
  /// In zh, this message translates to:
  /// **'已在媒体库'**
  String get dbOnlineInLibrary;

  /// No description provided for @dbOnlineLatestReleased.
  ///
  /// In zh, this message translates to:
  /// **'最新上架'**
  String get dbOnlineLatestReleased;

  /// No description provided for @dbOnlineLibrarySection.
  ///
  /// In zh, this message translates to:
  /// **'媒体库'**
  String get dbOnlineLibrarySection;

  /// No description provided for @dbOnlineNoData.
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get dbOnlineNoData;

  /// No description provided for @dbOnlineNoMeta.
  ///
  /// In zh, this message translates to:
  /// **'暂无元数据'**
  String get dbOnlineNoMeta;

  /// No description provided for @dbOnlineNoPlaySources.
  ///
  /// In zh, this message translates to:
  /// **'暂无播放源'**
  String get dbOnlineNoPlaySources;

  /// No description provided for @dbOnlineNoPlayableEpisodes.
  ///
  /// In zh, this message translates to:
  /// **'暂无可播放剧集'**
  String get dbOnlineNoPlayableEpisodes;

  /// No description provided for @dbOnlineOnlineOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅在线播'**
  String get dbOnlineOnlineOnly;

  /// No description provided for @dbOnlinePlayOnline.
  ///
  /// In zh, this message translates to:
  /// **'在线播放'**
  String get dbOnlinePlayOnline;

  /// No description provided for @dbOnlinePlaySource.
  ///
  /// In zh, this message translates to:
  /// **'播放源'**
  String get dbOnlinePlaySource;

  /// No description provided for @dbOnlinePlayTooltip.
  ///
  /// In zh, this message translates to:
  /// **'播放 · 长按选择内核'**
  String get dbOnlinePlayTooltip;

  /// No description provided for @dbOnlinePreviewSection.
  ///
  /// In zh, this message translates to:
  /// **'预览'**
  String get dbOnlinePreviewSection;

  /// No description provided for @dbOnlineQualityTooltip.
  ///
  /// In zh, this message translates to:
  /// **'选择清晰度 · 长按列表选择内核'**
  String get dbOnlineQualityTooltip;

  /// No description provided for @dbOnlineRecentUpdated.
  ///
  /// In zh, this message translates to:
  /// **'最近更新'**
  String get dbOnlineRecentUpdated;

  /// No description provided for @dbOnlineRefreshEpisodes.
  ///
  /// In zh, this message translates to:
  /// **'刷新剧集'**
  String get dbOnlineRefreshEpisodes;

  /// No description provided for @dbOnlineRelatedSection.
  ///
  /// In zh, this message translates to:
  /// **'相关推荐'**
  String get dbOnlineRelatedSection;

  /// No description provided for @dbOnlineRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get dbOnlineRetry;

  /// No description provided for @dbOnlineSameActorSection.
  ///
  /// In zh, this message translates to:
  /// **'同演员作品'**
  String get dbOnlineSameActorSection;

  /// No description provided for @dbOnlineSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get dbOnlineSaved;

  /// No description provided for @dbOnlineSectionFieldCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个字段'**
  String dbOnlineSectionFieldCount(int count);

  /// No description provided for @dbOnlineSectionPan115.
  ///
  /// In zh, this message translates to:
  /// **'115 网盘'**
  String get dbOnlineSectionPan115;

  /// No description provided for @dbOnlineSectionPlayer.
  ///
  /// In zh, this message translates to:
  /// **'播放器'**
  String get dbOnlineSectionPlayer;

  /// No description provided for @dbOnlineSectionProxy.
  ///
  /// In zh, this message translates to:
  /// **'代理'**
  String get dbOnlineSectionProxy;

  /// No description provided for @dbOnlineSectionScopeHint.
  ///
  /// In zh, this message translates to:
  /// **'修改后仅更新当前配置分区。'**
  String get dbOnlineSectionScopeHint;

  /// No description provided for @dbOnlineSectionSubscription.
  ///
  /// In zh, this message translates to:
  /// **'订阅'**
  String get dbOnlineSectionSubscription;

  /// No description provided for @dbOnlineSectionSupportsTest.
  ///
  /// In zh, this message translates to:
  /// **'支持测试'**
  String get dbOnlineSectionSupportsTest;

  /// No description provided for @dbOnlineSectionThunder.
  ///
  /// In zh, this message translates to:
  /// **'迅雷'**
  String get dbOnlineSectionThunder;

  /// No description provided for @dbOnlineSeriesSection.
  ///
  /// In zh, this message translates to:
  /// **'系列'**
  String get dbOnlineSeriesSection;

  /// No description provided for @dbOnlineShowPassword.
  ///
  /// In zh, this message translates to:
  /// **'显示密码'**
  String get dbOnlineShowPassword;

  /// No description provided for @dbOnlineSort.
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get dbOnlineSort;

  /// No description provided for @dbOnlineTestConnection.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get dbOnlineTestConnection;

  /// No description provided for @dbOnlineUncensored.
  ///
  /// In zh, this message translates to:
  /// **'无码'**
  String get dbOnlineUncensored;

  /// No description provided for @homeBadgeNew.
  ///
  /// In zh, this message translates to:
  /// **'新'**
  String get homeBadgeNew;

  /// No description provided for @homeLibraries.
  ///
  /// In zh, this message translates to:
  /// **'我的媒体库'**
  String get homeLibraries;

  /// No description provided for @homeNoData.
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get homeNoData;

  /// No description provided for @homeSwitchAuthFailed.
  ///
  /// In zh, this message translates to:
  /// **'验证失败'**
  String get homeSwitchAuthFailed;

  /// No description provided for @homeSwitchAuthTimeout.
  ///
  /// In zh, this message translates to:
  /// **'验证超时'**
  String get homeSwitchAuthTimeout;

  /// No description provided for @homeSwitchBackToPassword.
  ///
  /// In zh, this message translates to:
  /// **'改用密码'**
  String get homeSwitchBackToPassword;

  /// No description provided for @homeSwitchCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消切换'**
  String get homeSwitchCancel;

  /// No description provided for @homeSwitchCannotConnect.
  ///
  /// In zh, this message translates to:
  /// **'无法连接 {name}'**
  String homeSwitchCannotConnect(String name);

  /// No description provided for @homeSwitchCheckNetwork.
  ///
  /// In zh, this message translates to:
  /// **'检查网络连接'**
  String get homeSwitchCheckNetwork;

  /// No description provided for @homeSwitchCheckingAuth.
  ///
  /// In zh, this message translates to:
  /// **'正在检查服务器鉴权状态…'**
  String get homeSwitchCheckingAuth;

  /// No description provided for @homeSwitchConnecting.
  ///
  /// In zh, this message translates to:
  /// **'连接 {name}'**
  String homeSwitchConnecting(String name);

  /// No description provided for @homeSwitchConnectionFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败'**
  String get homeSwitchConnectionFailed;

  /// No description provided for @homeSwitchInvalidTarget.
  ///
  /// In zh, this message translates to:
  /// **'目标服务器无效'**
  String get homeSwitchInvalidTarget;

  /// No description provided for @homeSwitchNeedPassword.
  ///
  /// In zh, this message translates to:
  /// **'需要密码'**
  String get homeSwitchNeedPassword;

  /// No description provided for @homeSwitchNeedTotp.
  ///
  /// In zh, this message translates to:
  /// **'请输入 {length} 位动态验证码'**
  String homeSwitchNeedTotp(int length);

  /// No description provided for @homeSwitchNeedUsername.
  ///
  /// In zh, this message translates to:
  /// **'需要用户名'**
  String get homeSwitchNeedUsername;

  /// No description provided for @homeSwitchPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入此服务器的密码继续。'**
  String get homeSwitchPasswordHint;

  /// No description provided for @homeSwitchPasswordLabel.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get homeSwitchPasswordLabel;

  /// No description provided for @homeSwitchRestoreFailed.
  ///
  /// In zh, this message translates to:
  /// **'恢复会话失败：{error}'**
  String homeSwitchRestoreFailed(String error);

  /// No description provided for @homeSwitchServer.
  ///
  /// In zh, this message translates to:
  /// **'服务器'**
  String get homeSwitchServer;

  /// No description provided for @homeSwitchSignInAndSwitch.
  ///
  /// In zh, this message translates to:
  /// **'登录并切换'**
  String get homeSwitchSignInAndSwitch;

  /// No description provided for @homeSwitchTargetMissingMessage.
  ///
  /// In zh, this message translates to:
  /// **'无法找到目标服务器，请返回后重试。'**
  String get homeSwitchTargetMissingMessage;

  /// No description provided for @homeSwitchTargetMissingTitle.
  ///
  /// In zh, this message translates to:
  /// **'服务器配置无效'**
  String get homeSwitchTargetMissingTitle;

  /// No description provided for @homeSwitchTotpHint.
  ///
  /// In zh, this message translates to:
  /// **'输入动态验证码完成切换。'**
  String get homeSwitchTotpHint;

  /// No description provided for @homeSwitchUsernameLabel.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get homeSwitchUsernameLabel;

  /// No description provided for @homeSwitchUsernamePasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入此服务器的用户名和密码继续。'**
  String get homeSwitchUsernamePasswordHint;

  /// No description provided for @homeSwitchVerifyAndSwitch.
  ///
  /// In zh, this message translates to:
  /// **'验证并切换'**
  String get homeSwitchVerifyAndSwitch;

  /// No description provided for @homeSwitchVerifying.
  ///
  /// In zh, this message translates to:
  /// **'验证中…'**
  String get homeSwitchVerifying;

  /// No description provided for @mediaBrowserActionFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作失败：{error}'**
  String mediaBrowserActionFailed(String error);

  /// No description provided for @mediaBrowserActorWorks.
  ///
  /// In zh, this message translates to:
  /// **'演员作品'**
  String get mediaBrowserActorWorks;

  /// No description provided for @mediaBrowserAddPath.
  ///
  /// In zh, this message translates to:
  /// **'添加路径'**
  String get mediaBrowserAddPath;

  /// No description provided for @mediaBrowserAdminRequired.
  ///
  /// In zh, this message translates to:
  /// **'需要管理员账号'**
  String get mediaBrowserAdminRequired;

  /// No description provided for @mediaBrowserAdminRequiredHint.
  ///
  /// In zh, this message translates to:
  /// **'请使用管理员账号管理媒体库。'**
  String get mediaBrowserAdminRequiredHint;

  /// No description provided for @mediaBrowserAscending.
  ///
  /// In zh, this message translates to:
  /// **'升序'**
  String get mediaBrowserAscending;

  /// No description provided for @mediaBrowserBatchRemoveFailed.
  ///
  /// In zh, this message translates to:
  /// **'批量取消收藏失败：{error}'**
  String mediaBrowserBatchRemoveFailed(String error);

  /// No description provided for @mediaBrowserContentType.
  ///
  /// In zh, this message translates to:
  /// **'内容类型'**
  String get mediaBrowserContentType;

  /// No description provided for @mediaBrowserContentTypeReadonly.
  ///
  /// In zh, this message translates to:
  /// **'内容类型（只读）'**
  String get mediaBrowserContentTypeReadonly;

  /// No description provided for @mediaBrowserContentTypeRequired.
  ///
  /// In zh, this message translates to:
  /// **'请选择内容类型'**
  String get mediaBrowserContentTypeRequired;

  /// No description provided for @mediaBrowserDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除媒体库失败：{error}'**
  String mediaBrowserDeleteFailed(String error);

  /// No description provided for @mediaBrowserDeleteLibraryBody.
  ///
  /// In zh, this message translates to:
  /// **'确定删除媒体库“{name}”吗？服务器上的媒体文件不会被删除。'**
  String mediaBrowserDeleteLibraryBody(String name);

  /// No description provided for @mediaBrowserDeleteLibraryTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除媒体库'**
  String get mediaBrowserDeleteLibraryTitle;

  /// No description provided for @mediaBrowserDescending.
  ///
  /// In zh, this message translates to:
  /// **'降序'**
  String get mediaBrowserDescending;

  /// No description provided for @mediaBrowserDisableAction.
  ///
  /// In zh, this message translates to:
  /// **'停用'**
  String get mediaBrowserDisableAction;

  /// No description provided for @mediaBrowserDisableLibraryHint.
  ///
  /// In zh, this message translates to:
  /// **'停用后将不再显示该媒体库。'**
  String get mediaBrowserDisableLibraryHint;

  /// No description provided for @mediaBrowserDisc.
  ///
  /// In zh, this message translates to:
  /// **'碟片 {number}'**
  String mediaBrowserDisc(int number);

  /// No description provided for @mediaBrowserEditLibrarySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑媒体库设置'**
  String get mediaBrowserEditLibrarySubtitle;

  /// No description provided for @mediaBrowserEditLibraryTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑媒体库'**
  String get mediaBrowserEditLibraryTitle;

  /// No description provided for @mediaBrowserEnableAction.
  ///
  /// In zh, this message translates to:
  /// **'启用'**
  String get mediaBrowserEnableAction;

  /// No description provided for @mediaBrowserEnableLibraryHint.
  ///
  /// In zh, this message translates to:
  /// **'启用后将在媒体库中显示。'**
  String get mediaBrowserEnableLibraryHint;

  /// No description provided for @mediaBrowserEnableLibraryLabel.
  ///
  /// In zh, this message translates to:
  /// **'启用媒体库'**
  String get mediaBrowserEnableLibraryLabel;

  /// No description provided for @mediaBrowserFavoriteAction.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get mediaBrowserFavoriteAction;

  /// No description provided for @mediaBrowserFilterContentType.
  ///
  /// In zh, this message translates to:
  /// **'筛选内容类型'**
  String get mediaBrowserFilterContentType;

  /// No description provided for @mediaBrowserItemCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个条目'**
  String mediaBrowserItemCount(int count);

  /// No description provided for @mediaBrowserLatestAdded.
  ///
  /// In zh, this message translates to:
  /// **'最新入库'**
  String get mediaBrowserLatestAdded;

  /// No description provided for @mediaBrowserLibrariesTitle.
  ///
  /// In zh, this message translates to:
  /// **'媒体库'**
  String get mediaBrowserLibrariesTitle;

  /// No description provided for @mediaBrowserLibrariesUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'无法访问媒体库'**
  String get mediaBrowserLibrariesUnavailable;

  /// No description provided for @mediaBrowserLibraryCreated.
  ///
  /// In zh, this message translates to:
  /// **'媒体库已创建'**
  String get mediaBrowserLibraryCreated;

  /// No description provided for @mediaBrowserLibraryDeleted.
  ///
  /// In zh, this message translates to:
  /// **'媒体库已删除'**
  String get mediaBrowserLibraryDeleted;

  /// No description provided for @mediaBrowserLibraryDisabled.
  ///
  /// In zh, this message translates to:
  /// **'媒体库已停用'**
  String get mediaBrowserLibraryDisabled;

  /// No description provided for @mediaBrowserLibraryEnabled.
  ///
  /// In zh, this message translates to:
  /// **'媒体库已启用'**
  String get mediaBrowserLibraryEnabled;

  /// No description provided for @mediaBrowserLibraryManageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'管理服务器上的虚拟媒体库与媒体路径。'**
  String get mediaBrowserLibraryManageSubtitle;

  /// No description provided for @mediaBrowserLibraryManageTitle.
  ///
  /// In zh, this message translates to:
  /// **'媒体库管理'**
  String get mediaBrowserLibraryManageTitle;

  /// No description provided for @mediaBrowserLibraryNameHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：电影、电视剧、音乐'**
  String get mediaBrowserLibraryNameHint;

  /// No description provided for @mediaBrowserLibraryNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'媒体库名称'**
  String get mediaBrowserLibraryNameLabel;

  /// No description provided for @mediaBrowserLibraryNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入媒体库名称'**
  String get mediaBrowserLibraryNameRequired;

  /// No description provided for @mediaBrowserLibraryRefreshStarted.
  ///
  /// In zh, this message translates to:
  /// **'已开始刷新「{name}」'**
  String mediaBrowserLibraryRefreshStarted(String name);

  /// No description provided for @mediaBrowserLibrarySettingsSaved.
  ///
  /// In zh, this message translates to:
  /// **'媒体库设置已保存'**
  String get mediaBrowserLibrarySettingsSaved;

  /// No description provided for @mediaBrowserMarkWatched.
  ///
  /// In zh, this message translates to:
  /// **'标记为已看'**
  String get mediaBrowserMarkWatched;

  /// No description provided for @mediaBrowserMediaPathsLabel.
  ///
  /// In zh, this message translates to:
  /// **'媒体路径'**
  String get mediaBrowserMediaPathsLabel;

  /// No description provided for @mediaBrowserNewLibrarySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'添加媒体库名称、类型和路径'**
  String get mediaBrowserNewLibrarySubtitle;

  /// No description provided for @mediaBrowserNewLibraryTitle.
  ///
  /// In zh, this message translates to:
  /// **'新建媒体库'**
  String get mediaBrowserNewLibraryTitle;

  /// No description provided for @mediaBrowserNoData.
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get mediaBrowserNoData;

  /// No description provided for @mediaBrowserNoFavorites.
  ///
  /// In zh, this message translates to:
  /// **'暂无收藏内容'**
  String get mediaBrowserNoFavorites;

  /// No description provided for @mediaBrowserNoFavoritesHint.
  ///
  /// In zh, this message translates to:
  /// **'在详情页点击 ♡ 加入收藏'**
  String get mediaBrowserNoFavoritesHint;

  /// No description provided for @mediaBrowserNoFavoritesYet.
  ///
  /// In zh, this message translates to:
  /// **'暂无收藏'**
  String get mediaBrowserNoFavoritesYet;

  /// No description provided for @mediaBrowserNoLibrariesHint.
  ///
  /// In zh, this message translates to:
  /// **'请先创建或启用一个媒体库。'**
  String get mediaBrowserNoLibrariesHint;

  /// No description provided for @mediaBrowserNoLibrariesYet.
  ///
  /// In zh, this message translates to:
  /// **'还没有媒体库'**
  String get mediaBrowserNoLibrariesYet;

  /// No description provided for @mediaBrowserNoMatchingItems.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的内容'**
  String get mediaBrowserNoMatchingItems;

  /// No description provided for @mediaBrowserNoTracks.
  ///
  /// In zh, this message translates to:
  /// **'暂无音轨'**
  String get mediaBrowserNoTracks;

  /// No description provided for @mediaBrowserNotMediaServer.
  ///
  /// In zh, this message translates to:
  /// **'当前服务器不是可用的媒体服务器。'**
  String get mediaBrowserNotMediaServer;

  /// No description provided for @mediaBrowserPathHint.
  ///
  /// In zh, this message translates to:
  /// **'添加媒体库路径'**
  String get mediaBrowserPathHint;

  /// No description provided for @mediaBrowserPathNumber.
  ///
  /// In zh, this message translates to:
  /// **'路径 {number}'**
  String mediaBrowserPathNumber(int number);

  /// No description provided for @mediaBrowserPathRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入媒体库路径'**
  String get mediaBrowserPathRequired;

  /// No description provided for @mediaBrowserPlayAll.
  ///
  /// In zh, this message translates to:
  /// **'全部播放'**
  String get mediaBrowserPlayAll;

  /// No description provided for @mediaBrowserRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get mediaBrowserRefresh;

  /// No description provided for @mediaBrowserRefreshFailed.
  ///
  /// In zh, this message translates to:
  /// **'刷新失败：{error}'**
  String mediaBrowserRefreshFailed(String error);

  /// No description provided for @mediaBrowserRemoveFavoriteFailed.
  ///
  /// In zh, this message translates to:
  /// **'取消收藏失败：{error}'**
  String mediaBrowserRemoveFavoriteFailed(String error);

  /// No description provided for @mediaBrowserRemoveFavoritesBody.
  ///
  /// In zh, this message translates to:
  /// **'确定取消收藏已选的 {count} 个条目吗？'**
  String mediaBrowserRemoveFavoritesBody(int count);

  /// No description provided for @mediaBrowserRemoveFavoritesTitle.
  ///
  /// In zh, this message translates to:
  /// **'移除收藏'**
  String get mediaBrowserRemoveFavoritesTitle;

  /// No description provided for @mediaBrowserRemovePath.
  ///
  /// In zh, this message translates to:
  /// **'移除路径'**
  String get mediaBrowserRemovePath;

  /// No description provided for @mediaBrowserRemovedItem.
  ///
  /// In zh, this message translates to:
  /// **'已取消收藏：{name}'**
  String mediaBrowserRemovedItem(String name);

  /// No description provided for @mediaBrowserRemovedNItems.
  ///
  /// In zh, this message translates to:
  /// **'已取消收藏 {count} 个条目'**
  String mediaBrowserRemovedNItems(int count);

  /// No description provided for @mediaBrowserRemovedNItemsWithFailed.
  ///
  /// In zh, this message translates to:
  /// **'已取消收藏 {count} 个条目，{failed} 个失败'**
  String mediaBrowserRemovedNItemsWithFailed(int count, int failed);

  /// No description provided for @mediaBrowserRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get mediaBrowserRetry;

  /// No description provided for @mediaBrowserSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存媒体库失败：{error}'**
  String mediaBrowserSaveFailed(String error);

  /// No description provided for @mediaBrowserSort.
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get mediaBrowserSort;

  /// No description provided for @mediaBrowserSortBy.
  ///
  /// In zh, this message translates to:
  /// **'排序方式'**
  String get mediaBrowserSortBy;

  /// No description provided for @mediaBrowserSortName.
  ///
  /// In zh, this message translates to:
  /// **'按名称'**
  String get mediaBrowserSortName;

  /// No description provided for @mediaBrowserSortNameAZ.
  ///
  /// In zh, this message translates to:
  /// **'名称（A-Z）'**
  String get mediaBrowserSortNameAZ;

  /// No description provided for @mediaBrowserSortRating.
  ///
  /// In zh, this message translates to:
  /// **'按评分'**
  String get mediaBrowserSortRating;

  /// No description provided for @mediaBrowserSortRecent.
  ///
  /// In zh, this message translates to:
  /// **'按最近添加'**
  String get mediaBrowserSortRecent;

  /// No description provided for @mediaBrowserSortTopRated.
  ///
  /// In zh, this message translates to:
  /// **'按评分最高'**
  String get mediaBrowserSortTopRated;

  /// No description provided for @mediaBrowserSortYear.
  ///
  /// In zh, this message translates to:
  /// **'按年份'**
  String get mediaBrowserSortYear;

  /// No description provided for @mediaBrowserSortYearDesc.
  ///
  /// In zh, this message translates to:
  /// **'按年份（降序）'**
  String get mediaBrowserSortYearDesc;

  /// No description provided for @mediaBrowserStatEpisodes.
  ///
  /// In zh, this message translates to:
  /// **'剧集数'**
  String get mediaBrowserStatEpisodes;

  /// No description provided for @mediaBrowserStatMovies.
  ///
  /// In zh, this message translates to:
  /// **'影片数'**
  String get mediaBrowserStatMovies;

  /// No description provided for @mediaBrowserStatSeries.
  ///
  /// In zh, this message translates to:
  /// **'系列数'**
  String get mediaBrowserStatSeries;

  /// No description provided for @mediaBrowserStatsLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'统计加载失败'**
  String get mediaBrowserStatsLoadFailed;

  /// No description provided for @mediaBrowserStatusDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已禁用'**
  String get mediaBrowserStatusDisabled;

  /// No description provided for @mediaBrowserStatusEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已启用'**
  String get mediaBrowserStatusEnabled;

  /// No description provided for @mediaBrowserTracks.
  ///
  /// In zh, this message translates to:
  /// **'音轨'**
  String get mediaBrowserTracks;

  /// No description provided for @mediaBrowserTypeAlbums.
  ///
  /// In zh, this message translates to:
  /// **'专辑'**
  String get mediaBrowserTypeAlbums;

  /// No description provided for @mediaBrowserTypeMixed.
  ///
  /// In zh, this message translates to:
  /// **'混合内容'**
  String get mediaBrowserTypeMixed;

  /// No description provided for @mediaBrowserTypeMovies.
  ///
  /// In zh, this message translates to:
  /// **'电影'**
  String get mediaBrowserTypeMovies;

  /// No description provided for @mediaBrowserTypeMusic.
  ///
  /// In zh, this message translates to:
  /// **'音乐'**
  String get mediaBrowserTypeMusic;

  /// No description provided for @mediaBrowserTypeMusicVideos.
  ///
  /// In zh, this message translates to:
  /// **'音乐视频'**
  String get mediaBrowserTypeMusicVideos;

  /// No description provided for @mediaBrowserTypeSongs.
  ///
  /// In zh, this message translates to:
  /// **'歌曲'**
  String get mediaBrowserTypeSongs;

  /// No description provided for @mediaBrowserTypeTvShows.
  ///
  /// In zh, this message translates to:
  /// **'电视剧'**
  String get mediaBrowserTypeTvShows;

  /// No description provided for @mediaBrowserUnfavoriteAction.
  ///
  /// In zh, this message translates to:
  /// **'取消收藏'**
  String get mediaBrowserUnfavoriteAction;

  /// No description provided for @mediaBrowserUnmarkWatched.
  ///
  /// In zh, this message translates to:
  /// **'标记为未观看'**
  String get mediaBrowserUnmarkWatched;

  /// No description provided for @playerSettingBufferGroup.
  ///
  /// In zh, this message translates to:
  /// **'播放缓冲'**
  String get playerSettingBufferGroup;

  /// No description provided for @playerSettingButtonsGroup.
  ///
  /// In zh, this message translates to:
  /// **'播放按钮'**
  String get playerSettingButtonsGroup;

  /// No description provided for @playerSettingDefaultEngine.
  ///
  /// In zh, this message translates to:
  /// **'默认播放内核'**
  String get playerSettingDefaultEngine;

  /// No description provided for @playerSettingDefaultEngineSub.
  ///
  /// In zh, this message translates to:
  /// **'当前：{engine}'**
  String playerSettingDefaultEngineSub(String engine);

  /// No description provided for @playerSettingDoubleTapCenter.
  ///
  /// In zh, this message translates to:
  /// **'双击屏幕中间'**
  String get playerSettingDoubleTapCenter;

  /// No description provided for @playerSettingDoubleTapCenterSub.
  ///
  /// In zh, this message translates to:
  /// **'暂停 / 播放'**
  String get playerSettingDoubleTapCenterSub;

  /// No description provided for @playerSettingDoubleTapEdges.
  ///
  /// In zh, this message translates to:
  /// **'双击屏幕两边'**
  String get playerSettingDoubleTapEdges;

  /// No description provided for @playerSettingDoubleTapEdgesSub.
  ///
  /// In zh, this message translates to:
  /// **'左侧快退,右侧快进'**
  String get playerSettingDoubleTapEdgesSub;

  /// No description provided for @playerSettingDoubleTapGroup.
  ///
  /// In zh, this message translates to:
  /// **'双击手势'**
  String get playerSettingDoubleTapGroup;

  /// No description provided for @playerSettingEntryOrientation.
  ///
  /// In zh, this message translates to:
  /// **'进入播放器屏幕方向'**
  String get playerSettingEntryOrientation;

  /// No description provided for @playerOrientationLockGyroscope.
  ///
  /// In zh, this message translates to:
  /// **'旋转锁定'**
  String get playerOrientationLockGyroscope;

  /// No description provided for @playerOrientationUnlockGyroscope.
  ///
  /// In zh, this message translates to:
  /// **'解除锁定'**
  String get playerOrientationUnlockGyroscope;

  /// No description provided for @playerSettingHapticGroup.
  ///
  /// In zh, this message translates to:
  /// **'震动反馈'**
  String get playerSettingHapticGroup;

  /// No description provided for @playerSettingHapticLongPress.
  ///
  /// In zh, this message translates to:
  /// **'长按屏幕'**
  String get playerSettingHapticLongPress;

  /// No description provided for @playerSettingHapticProgressBar.
  ///
  /// In zh, this message translates to:
  /// **'拖动进度条'**
  String get playerSettingHapticProgressBar;

  /// No description provided for @playerSettingHapticRate.
  ///
  /// In zh, this message translates to:
  /// **'滑动调节倍速'**
  String get playerSettingHapticRate;

  /// No description provided for @playerSettingHapticSeek.
  ///
  /// In zh, this message translates to:
  /// **'滑动调节进度'**
  String get playerSettingHapticSeek;

  /// No description provided for @playerSettingIosEngineGroup.
  ///
  /// In zh, this message translates to:
  /// **'iOS 播放内核'**
  String get playerSettingIosEngineGroup;

  /// No description provided for @playerSettingLandscapeSide.
  ///
  /// In zh, this message translates to:
  /// **'设备横屏方向'**
  String get playerSettingLandscapeSide;

  /// No description provided for @playerSettingMediaSwitchButton.
  ///
  /// In zh, this message translates to:
  /// **'切换媒体按钮'**
  String get playerSettingMediaSwitchButton;

  /// No description provided for @playerSettingMediaSwitchButtonSub.
  ///
  /// In zh, this message translates to:
  /// **'上一部 / 下一部'**
  String get playerSettingMediaSwitchButtonSub;

  /// No description provided for @playerSettingOrientationButton.
  ///
  /// In zh, this message translates to:
  /// **'旋屏按钮'**
  String get playerSettingOrientationButton;

  /// No description provided for @playerSettingOrientationGroup.
  ///
  /// In zh, this message translates to:
  /// **'屏幕方向'**
  String get playerSettingOrientationGroup;

  /// No description provided for @playerSettingOsdBattery.
  ///
  /// In zh, this message translates to:
  /// **'设备电量'**
  String get playerSettingOsdBattery;

  /// No description provided for @playerSettingOsdBatterySub.
  ///
  /// In zh, this message translates to:
  /// **'显示当前电池电量'**
  String get playerSettingOsdBatterySub;

  /// No description provided for @playerSettingOsdClock.
  ///
  /// In zh, this message translates to:
  /// **'系统时间'**
  String get playerSettingOsdClock;

  /// No description provided for @playerSettingOsdClockSub.
  ///
  /// In zh, this message translates to:
  /// **'在播放器上显示当前时间'**
  String get playerSettingOsdClockSub;

  /// No description provided for @playerSettingOsdCpu.
  ///
  /// In zh, this message translates to:
  /// **'CPU 占用率'**
  String get playerSettingOsdCpu;

  /// No description provided for @playerSettingOsdCpuSub.
  ///
  /// In zh, this message translates to:
  /// **'显示设备实时 CPU 使用率'**
  String get playerSettingOsdCpuSub;

  /// No description provided for @playerSettingOsdGroup.
  ///
  /// In zh, this message translates to:
  /// **'OSD 信息'**
  String get playerSettingOsdGroup;

  /// No description provided for @playerSettingOsdNetwork.
  ///
  /// In zh, this message translates to:
  /// **'设备网速'**
  String get playerSettingOsdNetwork;

  /// No description provided for @playerSettingOsdNetworkSub.
  ///
  /// In zh, this message translates to:
  /// **'显示 Wi-Fi、4G/5G 网络类型和当前下载速度'**
  String get playerSettingOsdNetworkSub;

  /// No description provided for @playerSettingPipButton.
  ///
  /// In zh, this message translates to:
  /// **'画中画按钮'**
  String get playerSettingPipButton;

  /// No description provided for @playerSettingPlayPauseButton.
  ///
  /// In zh, this message translates to:
  /// **'播放 / 暂停按钮'**
  String get playerSettingPlayPauseButton;

  /// No description provided for @playerSettingPreloadSize.
  ///
  /// In zh, this message translates to:
  /// **'预载缓冲大小'**
  String get playerSettingPreloadSize;

  /// No description provided for @playerSettingPreloadSizeSub.
  ///
  /// In zh, this message translates to:
  /// **'当前：{size}'**
  String playerSettingPreloadSizeSub(String size);

  /// No description provided for @playerSettingResumeLast.
  ///
  /// In zh, this message translates to:
  /// **'从上次进度播放'**
  String get playerSettingResumeLast;

  /// No description provided for @playerSettingResumeLastSub.
  ///
  /// In zh, this message translates to:
  /// **'打开影片时自动恢复上次观看位置'**
  String get playerSettingResumeLastSub;

  /// No description provided for @playerSettingSeekButtons.
  ///
  /// In zh, this message translates to:
  /// **'快进 / 快退按钮'**
  String get playerSettingSeekButtons;

  /// No description provided for @playerSettingSpeedButton.
  ///
  /// In zh, this message translates to:
  /// **'速度调节按钮'**
  String get playerSettingSpeedButton;

  /// No description provided for @posterBadgeAllHidden.
  ///
  /// In zh, this message translates to:
  /// **'已隐藏所有技术角标'**
  String get posterBadgeAllHidden;

  /// No description provided for @posterBadgeDetailPoster.
  ///
  /// In zh, this message translates to:
  /// **'影片详情海报'**
  String get posterBadgeDetailPoster;

  /// No description provided for @posterBadgePageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'控制影片详情海报上显示的技术信息'**
  String get posterBadgePageSubtitle;

  /// No description provided for @posterBadgePreviewCodec.
  ///
  /// In zh, this message translates to:
  /// **'视频编码: HEVC'**
  String get posterBadgePreviewCodec;

  /// No description provided for @posterBadgePreviewHd.
  ///
  /// In zh, this message translates to:
  /// **'720p 及以上'**
  String get posterBadgePreviewHd;

  /// No description provided for @posterBadgePreviewHdr.
  ///
  /// In zh, this message translates to:
  /// **'动态范围: HDR10 (PQ)'**
  String get posterBadgePreviewHdr;

  /// No description provided for @posterBadgePreviewHint.
  ///
  /// In zh, this message translates to:
  /// **'开关会实时更新预览和影片详情页海报。'**
  String get posterBadgePreviewHint;

  /// No description provided for @posterBadgePreviewStrm.
  ///
  /// In zh, this message translates to:
  /// **'STRM 视频文件'**
  String get posterBadgePreviewStrm;

  /// No description provided for @posterBadgePreviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'ABC-123  示例影片'**
  String get posterBadgePreviewTitle;

  /// No description provided for @posterBadgeVisible.
  ///
  /// In zh, this message translates to:
  /// **'显示'**
  String get posterBadgeVisible;

  /// No description provided for @serverAddTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加服务器'**
  String get serverAddTitle;

  /// No description provided for @serverAdded.
  ///
  /// In zh, this message translates to:
  /// **'服务器已添加'**
  String get serverAdded;

  /// No description provided for @serverCurrent.
  ///
  /// In zh, this message translates to:
  /// **'当前服务器'**
  String get serverCurrent;

  /// No description provided for @serverDeleteBody.
  ///
  /// In zh, this message translates to:
  /// **'确定删除服务器“{name}”及其线路吗？'**
  String serverDeleteBody(String name);

  /// No description provided for @serverDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败：{error}'**
  String serverDeleteFailed(String error);

  /// No description provided for @serverDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除服务器'**
  String get serverDeleteTitle;

  /// No description provided for @serverEditAction.
  ///
  /// In zh, this message translates to:
  /// **'编辑服务器'**
  String get serverEditAction;

  /// No description provided for @serverLineAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加线路'**
  String get serverLineAdd;

  /// No description provided for @serverLineAutoSelect.
  ///
  /// In zh, this message translates to:
  /// **'自动选择线路'**
  String get serverLineAutoSelect;

  /// No description provided for @serverLineAutoTestNoResult.
  ///
  /// In zh, this message translates to:
  /// **'自动测试未返回结果'**
  String get serverLineAutoTestNoResult;

  /// No description provided for @serverLineCount.
  ///
  /// In zh, this message translates to:
  /// **'{count}条线路'**
  String serverLineCount(int count);

  /// No description provided for @serverLineDefaultName.
  ///
  /// In zh, this message translates to:
  /// **'服务器线路'**
  String get serverLineDefaultName;

  /// No description provided for @serverLineDeleteActiveBlocked.
  ///
  /// In zh, this message translates to:
  /// **'当前线路正在使用，无法删除'**
  String get serverLineDeleteActiveBlocked;

  /// No description provided for @serverLineDeleteBody.
  ///
  /// In zh, this message translates to:
  /// **'确定删除线路“{name}”吗？'**
  String serverLineDeleteBody(String name);

  /// No description provided for @serverLineDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除线路'**
  String get serverLineDeleteTitle;

  /// No description provided for @serverLineDeleted.
  ///
  /// In zh, this message translates to:
  /// **'线路已删除'**
  String get serverLineDeleted;

  /// No description provided for @serverLineDisable.
  ///
  /// In zh, this message translates to:
  /// **'禁用'**
  String get serverLineDisable;

  /// No description provided for @serverLineDisabled.
  ///
  /// In zh, this message translates to:
  /// **'服务器线路已禁用'**
  String get serverLineDisabled;

  /// No description provided for @serverLineDuplicateUrl.
  ///
  /// In zh, this message translates to:
  /// **'已存在相同的线路地址'**
  String get serverLineDuplicateUrl;

  /// No description provided for @serverLineEditorAddTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加服务器线路'**
  String get serverLineEditorAddTitle;

  /// No description provided for @serverLineEditorEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑服务器线路'**
  String get serverLineEditorEditTitle;

  /// No description provided for @serverLineEnable.
  ///
  /// In zh, this message translates to:
  /// **'启用线路'**
  String get serverLineEnable;

  /// No description provided for @serverLineFastest.
  ///
  /// In zh, this message translates to:
  /// **'最快线路：{name}'**
  String serverLineFastest(String name);

  /// No description provided for @serverLineKeepOne.
  ///
  /// In zh, this message translates to:
  /// **'至少保留一条服务器线路'**
  String get serverLineKeepOne;

  /// No description provided for @serverLineKeepOneEnabled.
  ///
  /// In zh, this message translates to:
  /// **'至少保留一条启用线路'**
  String get serverLineKeepOneEnabled;

  /// No description provided for @serverLineNameHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：主线路'**
  String get serverLineNameHint;

  /// No description provided for @serverLineNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'线路名称'**
  String get serverLineNameLabel;

  /// No description provided for @serverLineNoFallback.
  ///
  /// In zh, this message translates to:
  /// **'没有可用的备用线路'**
  String get serverLineNoFallback;

  /// No description provided for @serverLineNoResponse.
  ///
  /// In zh, this message translates to:
  /// **'服务器线路无响应'**
  String get serverLineNoResponse;

  /// No description provided for @serverLineNoneEnabled.
  ///
  /// In zh, this message translates to:
  /// **'当前没有启用的线路'**
  String get serverLineNoneEnabled;

  /// No description provided for @serverLineProbeFailed.
  ///
  /// In zh, this message translates to:
  /// **'线路检测失败'**
  String get serverLineProbeFailed;

  /// No description provided for @serverLineProbeFailedNotSaved.
  ///
  /// In zh, this message translates to:
  /// **'服务器检测失败，线路未保存'**
  String get serverLineProbeFailedNotSaved;

  /// No description provided for @serverLineSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存，延迟 {latency} ms'**
  String serverLineSaved(int latency);

  /// No description provided for @serverLineSelected.
  ///
  /// In zh, this message translates to:
  /// **'已选择 {name}（{latency} ms）'**
  String serverLineSelected(String name, int latency);

  /// No description provided for @serverLineSwitchedTo.
  ///
  /// In zh, this message translates to:
  /// **'已切换到线路：{name}'**
  String serverLineSwitchedTo(String name);

  /// No description provided for @serverLineTestFailed.
  ///
  /// In zh, this message translates to:
  /// **'线路测试失败：{error}'**
  String serverLineTestFailed(String error);

  /// No description provided for @serverLineTesting.
  ///
  /// In zh, this message translates to:
  /// **'正在检测线路'**
  String get serverLineTesting;

  /// No description provided for @serverLineUpdatedAndSwitched.
  ///
  /// In zh, this message translates to:
  /// **'线路已更新并切换'**
  String get serverLineUpdatedAndSwitched;

  /// No description provided for @serverLineUse.
  ///
  /// In zh, this message translates to:
  /// **'使用线路'**
  String get serverLineUse;

  /// No description provided for @serverLinesEmptyBody.
  ///
  /// In zh, this message translates to:
  /// **'添加备用线路，让服务器保持可访问'**
  String get serverLinesEmptyBody;

  /// No description provided for @serverLinesEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无线路'**
  String get serverLinesEmptyTitle;

  /// No description provided for @serverLinesEyebrow.
  ///
  /// In zh, this message translates to:
  /// **'服务器 · {name}'**
  String serverLinesEyebrow(String name);

  /// No description provided for @serverLinesNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'尚未配置服务器线路'**
  String get serverLinesNotConfigured;

  /// No description provided for @serverLinesServerMissing.
  ///
  /// In zh, this message translates to:
  /// **'服务器不存在或已被删除'**
  String get serverLinesServerMissing;

  /// No description provided for @serverLinesSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'管理服务器线路'**
  String get serverLinesSubtitle;

  /// No description provided for @serverLinesTitle.
  ///
  /// In zh, this message translates to:
  /// **'服务器线路'**
  String get serverLinesTitle;

  /// No description provided for @serverListSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'服务器列表'**
  String get serverListSubtitle;

  /// No description provided for @serverManageLines.
  ///
  /// In zh, this message translates to:
  /// **'管理线路'**
  String get serverManageLines;

  /// No description provided for @serverSettingsAccessSub.
  ///
  /// In zh, this message translates to:
  /// **'登录密码、会话策略与 TOTP'**
  String get serverSettingsAccessSub;

  /// No description provided for @serverSettingsAudioSub.
  ///
  /// In zh, this message translates to:
  /// **'已提取音频资产与字幕转译进度'**
  String get serverSettingsAudioSub;

  /// No description provided for @serverSettingsAvdb.
  ///
  /// In zh, this message translates to:
  /// **'AVDB 数据源'**
  String get serverSettingsAvdb;

  /// No description provided for @serverSettingsAvdbSub.
  ///
  /// In zh, this message translates to:
  /// **'演员关联同步'**
  String get serverSettingsAvdbSub;

  /// No description provided for @serverSettingsDboSub.
  ///
  /// In zh, this message translates to:
  /// **'影片信息、资源和演员关联'**
  String get serverSettingsDboSub;

  /// No description provided for @serverSettingsModalTranscription.
  ///
  /// In zh, this message translates to:
  /// **'云端字幕转译'**
  String get serverSettingsModalTranscription;

  /// No description provided for @serverSettingsModalTranscriptionSub.
  ///
  /// In zh, this message translates to:
  /// **'Modal GPU 云端转译和任务并行配置'**
  String get serverSettingsModalTranscriptionSub;

  /// No description provided for @serverSettingsTranscoding.
  ///
  /// In zh, this message translates to:
  /// **'转码'**
  String get serverSettingsTranscoding;

  /// No description provided for @serverSettingsTranscodingSub.
  ///
  /// In zh, this message translates to:
  /// **'硬件解码、后端选择和失败回退'**
  String get serverSettingsTranscodingSub;

  /// No description provided for @serverSetupConnectTitle.
  ///
  /// In zh, this message translates to:
  /// **'连接到服务器'**
  String get serverSetupConnectTitle;

  /// No description provided for @serverSetupDuplicate.
  ///
  /// In zh, this message translates to:
  /// **'已存在相同连接的 {name} 服务器'**
  String serverSetupDuplicate(String name);

  /// No description provided for @serverSetupEditSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑服务器连接信息'**
  String get serverSetupEditSubtitle;

  /// No description provided for @serverSetupHostLabel.
  ///
  /// In zh, this message translates to:
  /// **'主机'**
  String get serverSetupHostLabel;

  /// No description provided for @serverSetupHostRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入主机'**
  String get serverSetupHostRequired;

  /// No description provided for @serverSetupInvalidFileConfig.
  ///
  /// In zh, this message translates to:
  /// **'文件服务器配置无效'**
  String get serverSetupInvalidFileConfig;

  /// No description provided for @serverSetupLoginUsernameRequired.
  ///
  /// In zh, this message translates to:
  /// **'已填写密码，请输入用户名'**
  String get serverSetupLoginUsernameRequired;

  /// No description provided for @serverSetupNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'服务器名称'**
  String get serverSetupNameLabel;

  /// No description provided for @serverSetupNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入服务器名称'**
  String get serverSetupNameRequired;

  /// No description provided for @serverSetupNewSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'添加新的服务器连接'**
  String get serverSetupNewSubtitle;

  /// No description provided for @serverSetupPasswordLabel.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get serverSetupPasswordLabel;

  /// No description provided for @serverSetupPasswordEditLabel.
  ///
  /// In zh, this message translates to:
  /// **'密码（留空为不更改）'**
  String get serverSetupPasswordEditLabel;

  /// No description provided for @serverSetupPasswordOptionalLabel.
  ///
  /// In zh, this message translates to:
  /// **'密码（可选）'**
  String get serverSetupPasswordOptionalLabel;

  /// No description provided for @serverSetupPasswordRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get serverSetupPasswordRequired;

  /// No description provided for @serverSetupPathHintOpenList.
  ///
  /// In zh, this message translates to:
  /// **'点击此处从文件列表选择路径'**
  String get serverSetupPathHintOpenList;

  /// No description provided for @serverSetupPathHintSmb.
  ///
  /// In zh, this message translates to:
  /// **'共享名或 /'**
  String get serverSetupPathHintSmb;

  /// No description provided for @serverSetupPathLabel.
  ///
  /// In zh, this message translates to:
  /// **'路径'**
  String get serverSetupPathLabel;

  /// No description provided for @serverSetupPathRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入路径'**
  String get serverSetupPathRequired;

  /// No description provided for @serverSetupPortInvalid.
  ///
  /// In zh, this message translates to:
  /// **'请输入 1-65535 之间的端口'**
  String get serverSetupPortInvalid;

  /// No description provided for @serverSetupPortLabel.
  ///
  /// In zh, this message translates to:
  /// **'端口'**
  String get serverSetupPortLabel;

  /// No description provided for @serverSetupProjectLabel.
  ///
  /// In zh, this message translates to:
  /// **'服务器类型'**
  String get serverSetupProjectLabel;

  /// No description provided for @serverSetupProtocolLabel.
  ///
  /// In zh, this message translates to:
  /// **'协议'**
  String get serverSetupProtocolLabel;

  /// No description provided for @serverSetupReplaceTitle.
  ///
  /// In zh, this message translates to:
  /// **'更换服务器'**
  String get serverSetupReplaceTitle;

  /// No description provided for @serverSetupRootPathLabel.
  ///
  /// In zh, this message translates to:
  /// **'根路径'**
  String get serverSetupRootPathLabel;

  /// No description provided for @serverSetupSelectProject.
  ///
  /// In zh, this message translates to:
  /// **'请选择服务器类型'**
  String get serverSetupSelectProject;

  /// No description provided for @serverSetupTotpClearStored.
  ///
  /// In zh, this message translates to:
  /// **'清除已保存的密钥'**
  String get serverSetupTotpClearStored;

  /// No description provided for @serverSetupTotpKeyHint.
  ///
  /// In zh, this message translates to:
  /// **'开启两步验证的服务器填入，登录时将自动生成验证码'**
  String get serverSetupTotpKeyHint;

  /// No description provided for @serverSetupTotpKeyInvalid.
  ///
  /// In zh, this message translates to:
  /// **'TOTP 密钥格式无效（应为 base32 字符串）'**
  String get serverSetupTotpKeyInvalid;

  /// No description provided for @serverSetupTotpKeyLabel.
  ///
  /// In zh, this message translates to:
  /// **'TOTP 密钥（可选）'**
  String get serverSetupTotpKeyLabel;

  /// No description provided for @serverSetupTotpKeyEditLabel.
  ///
  /// In zh, this message translates to:
  /// **'TOTP 密钥（留空为不更改）'**
  String get serverSetupTotpKeyEditLabel;

  /// No description provided for @serverSetupTotpRequired.
  ///
  /// In zh, this message translates to:
  /// **'该服务器开启了两步验证，请填写 TOTP 密钥或清空密码保存后再从登录页登录'**
  String get serverSetupTotpRequired;

  /// No description provided for @serverSetupUserLabel.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get serverSetupUserLabel;

  /// No description provided for @serverSetupUserEditLabel.
  ///
  /// In zh, this message translates to:
  /// **'用户名（留空为不更改）'**
  String get serverSetupUserEditLabel;

  /// No description provided for @serverSetupUserOptionalGenericLabel.
  ///
  /// In zh, this message translates to:
  /// **'用户名（可选）'**
  String get serverSetupUserOptionalGenericLabel;

  /// No description provided for @serverSetupUserOptionalLabel.
  ///
  /// In zh, this message translates to:
  /// **'用户名（API Key 登录可留空）'**
  String get serverSetupUserOptionalLabel;

  /// No description provided for @serverSetupUserRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入用户名'**
  String get serverSetupUserRequired;

  /// No description provided for @serverSetupStashApiKeyLabel.
  ///
  /// In zh, this message translates to:
  /// **'Stash API Key'**
  String get serverSetupStashApiKeyLabel;

  /// No description provided for @serverSetupStashApiKeyEditLabel.
  ///
  /// In zh, this message translates to:
  /// **'Stash API Key（留空为不更改）'**
  String get serverSetupStashApiKeyEditLabel;

  /// No description provided for @serverSetupStashApiKeyHint.
  ///
  /// In zh, this message translates to:
  /// **'在 Stash 设置 → 安全中创建；密钥仅保存在安全存储中'**
  String get serverSetupStashApiKeyHint;

  /// No description provided for @serverSetupStashApiKeyClear.
  ///
  /// In zh, this message translates to:
  /// **'清除已保存的 Stash API Key'**
  String get serverSetupStashApiKeyClear;

  /// No description provided for @serverSetupStashApiKeyRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入 Stash API Key'**
  String get serverSetupStashApiKeyRequired;

  /// No description provided for @homeSwitchStashApiKeyHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入 Stash API Key 以切换服务器'**
  String get homeSwitchStashApiKeyHint;

  /// No description provided for @homeSwitchOpenServerSettings.
  ///
  /// In zh, this message translates to:
  /// **'前往服务器设置'**
  String get homeSwitchOpenServerSettings;

  /// No description provided for @serverTestAndSave.
  ///
  /// In zh, this message translates to:
  /// **'测试并保存'**
  String get serverTestAndSave;

  /// No description provided for @serverUpdated.
  ///
  /// In zh, this message translates to:
  /// **'服务器已更新'**
  String get serverUpdated;

  /// No description provided for @serverUrlRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入服务器地址'**
  String get serverUrlRequired;

  /// No description provided for @serverUrlSchemeRequired.
  ///
  /// In zh, this message translates to:
  /// **'地址必须以 http:// 或 https:// 开头'**
  String get serverUrlSchemeRequired;

  /// No description provided for @settingsAudioManagement.
  ///
  /// In zh, this message translates to:
  /// **'音频管理'**
  String get settingsAudioManagement;

  /// No description provided for @settingsCacheCategoryCleared.
  ///
  /// In zh, this message translates to:
  /// **'已清理：{category}'**
  String settingsCacheCategoryCleared(String category);

  /// No description provided for @settingsCacheClear.
  ///
  /// In zh, this message translates to:
  /// **'清理缓存'**
  String get settingsCacheClear;

  /// No description provided for @settingsCacheClearCategoryBody.
  ///
  /// In zh, this message translates to:
  /// **'将删除当前{category}中的全部文件，此操作不可撤销。'**
  String settingsCacheClearCategoryBody(String category);

  /// No description provided for @settingsCacheClearCategoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认清理{category}'**
  String settingsCacheClearCategoryTitle(String category);

  /// No description provided for @settingsCacheClearFailed.
  ///
  /// In zh, this message translates to:
  /// **'清理缓存失败：{error}'**
  String settingsCacheClearFailed(String error);

  /// No description provided for @settingsCacheClearMusicBody.
  ///
  /// In zh, this message translates to:
  /// **'确定清理音乐缓存吗？'**
  String get settingsCacheClearMusicBody;

  /// No description provided for @settingsCacheClearMusicTitle.
  ///
  /// In zh, this message translates to:
  /// **'清理音乐缓存'**
  String get settingsCacheClearMusicTitle;

  /// No description provided for @settingsCacheMusicCleared.
  ///
  /// In zh, this message translates to:
  /// **'音乐缓存已清理'**
  String get settingsCacheMusicCleared;

  /// No description provided for @settingsCheckForUpdates.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get settingsCheckForUpdates;

  /// No description provided for @settingsLogoutConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'退出登录后需要重新验证服务器账号。'**
  String get settingsLogoutConfirmBody;

  /// No description provided for @settingsLogoutConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认退出登录？'**
  String get settingsLogoutConfirmTitle;

  /// No description provided for @settingsServerList.
  ///
  /// In zh, this message translates to:
  /// **'服务器列表'**
  String get settingsServerList;

  /// No description provided for @settingsServerListSub.
  ///
  /// In zh, this message translates to:
  /// **'{count} 台服务器 · 可分别配置线路'**
  String settingsServerListSub(int count);

  /// No description provided for @stageLabel.
  ///
  /// In zh, this message translates to:
  /// **'阶段'**
  String get stageLabel;

  /// No description provided for @subtitleBackgroundColor.
  ///
  /// In zh, this message translates to:
  /// **'背景颜色'**
  String get subtitleBackgroundColor;

  /// No description provided for @subtitleBehaviorGroup.
  ///
  /// In zh, this message translates to:
  /// **'字幕行为'**
  String get subtitleBehaviorGroup;

  /// No description provided for @subtitleBold.
  ///
  /// In zh, this message translates to:
  /// **'加粗'**
  String get subtitleBold;

  /// No description provided for @subtitleFont.
  ///
  /// In zh, this message translates to:
  /// **'字幕字体'**
  String get subtitleFont;

  /// No description provided for @subtitleFontColor.
  ///
  /// In zh, this message translates to:
  /// **'字幕字体颜色'**
  String get subtitleFontColor;

  /// No description provided for @subtitleFontMonospace.
  ///
  /// In zh, this message translates to:
  /// **'等宽字体'**
  String get subtitleFontMonospace;

  /// No description provided for @subtitleFontSerif.
  ///
  /// In zh, this message translates to:
  /// **'衬线字体'**
  String get subtitleFontSerif;

  /// No description provided for @subtitleFontSystem.
  ///
  /// In zh, this message translates to:
  /// **'系统字体'**
  String get subtitleFontSystem;

  /// No description provided for @subtitleIgnoreAssStyle.
  ///
  /// In zh, this message translates to:
  /// **'忽略 ASS 字幕样式'**
  String get subtitleIgnoreAssStyle;

  /// No description provided for @subtitleIgnoreAssStyleSub.
  ///
  /// In zh, this message translates to:
  /// **'使用下面的客户端字体和颜色设置'**
  String get subtitleIgnoreAssStyleSub;

  /// No description provided for @subtitleIgnoreSrtStyle.
  ///
  /// In zh, this message translates to:
  /// **'忽略 SRT 字幕样式'**
  String get subtitleIgnoreSrtStyle;

  /// No description provided for @subtitleIgnoreSrtStyleSub.
  ///
  /// In zh, this message translates to:
  /// **'忽略字幕中的 HTML 样式标签'**
  String get subtitleIgnoreSrtStyleSub;

  /// No description provided for @subtitleItalic.
  ///
  /// In zh, this message translates to:
  /// **'斜体'**
  String get subtitleItalic;

  /// No description provided for @subtitleOutlineColor.
  ///
  /// In zh, this message translates to:
  /// **'描边颜色'**
  String get subtitleOutlineColor;

  /// No description provided for @subtitleOutlineShadowGroup.
  ///
  /// In zh, this message translates to:
  /// **'描边与阴影'**
  String get subtitleOutlineShadowGroup;

  /// No description provided for @subtitleOutlineWidth.
  ///
  /// In zh, this message translates to:
  /// **'描边粗细'**
  String get subtitleOutlineWidth;

  /// No description provided for @subtitlePreviewText.
  ///
  /// In zh, this message translates to:
  /// **'字幕预览'**
  String get subtitlePreviewText;

  /// No description provided for @subtitleRememberSelection.
  ///
  /// In zh, this message translates to:
  /// **'记住所选字幕'**
  String get subtitleRememberSelection;

  /// No description provided for @subtitleRememberSelectionSub.
  ///
  /// In zh, this message translates to:
  /// **'下次播放时自动恢复最近使用的字幕轨道'**
  String get subtitleRememberSelectionSub;

  /// No description provided for @subtitleResetDefaults.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get subtitleResetDefaults;

  /// No description provided for @subtitleResetDefaultsSub.
  ///
  /// In zh, this message translates to:
  /// **'恢复字体、颜色、描边和字幕行为设置'**
  String get subtitleResetDefaultsSub;

  /// No description provided for @subtitleResetDone.
  ///
  /// In zh, this message translates to:
  /// **'字幕设置已重置'**
  String get subtitleResetDone;

  /// No description provided for @subtitleResetGroup.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get subtitleResetGroup;

  /// No description provided for @subtitleShadowColor.
  ///
  /// In zh, this message translates to:
  /// **'阴影颜色'**
  String get subtitleShadowColor;

  /// No description provided for @subtitleShadowSize.
  ///
  /// In zh, this message translates to:
  /// **'阴影大小'**
  String get subtitleShadowSize;

  /// No description provided for @subtitleStylePreview.
  ///
  /// In zh, this message translates to:
  /// **'样式预览'**
  String get subtitleStylePreview;

  /// No description provided for @subtitleTextStyleGroup.
  ///
  /// In zh, this message translates to:
  /// **'文字样式'**
  String get subtitleTextStyleGroup;

  /// No description provided for @subtitleTransparent.
  ///
  /// In zh, this message translates to:
  /// **'透明'**
  String get subtitleTransparent;

  /// No description provided for @taskCenterTitle.
  ///
  /// In zh, this message translates to:
  /// **'任务中心'**
  String get taskCenterTitle;

  /// No description provided for @transcriptionAddToken.
  ///
  /// In zh, this message translates to:
  /// **'添加令牌'**
  String get transcriptionAddToken;

  /// No description provided for @transcriptionAddTokenSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'添加 Modal 令牌'**
  String get transcriptionAddTokenSubtitle;

  /// No description provided for @transcriptionConfiguredKeepHint.
  ///
  /// In zh, this message translates to:
  /// **'已配置的令牌将继续使用，留空不会修改。'**
  String get transcriptionConfiguredKeepHint;

  /// No description provided for @transcriptionCredentialKeepHint.
  ///
  /// In zh, this message translates to:
  /// **'已配置，留空则不修改'**
  String get transcriptionCredentialKeepHint;

  /// No description provided for @transcriptionDisabledSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'云端字幕转译已禁用'**
  String get transcriptionDisabledSubtitle;

  /// No description provided for @transcriptionDuplicateTokenId.
  ///
  /// In zh, this message translates to:
  /// **'存在重复的 Modal Token ID'**
  String get transcriptionDuplicateTokenId;

  /// No description provided for @transcriptionEditTokenSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑转录令牌设置'**
  String get transcriptionEditTokenSubtitle;

  /// No description provided for @transcriptionEditTokenTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑令牌'**
  String get transcriptionEditTokenTitle;

  /// No description provided for @transcriptionEnable.
  ///
  /// In zh, this message translates to:
  /// **'启用转录'**
  String get transcriptionEnable;

  /// No description provided for @transcriptionEnabledSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'云端字幕转译已启用'**
  String get transcriptionEnabledSubtitle;

  /// No description provided for @transcriptionFollowMaxWorkers.
  ///
  /// In zh, this message translates to:
  /// **'跟随最大工作线程数'**
  String get transcriptionFollowMaxWorkers;

  /// No description provided for @transcriptionGpuHelp.
  ///
  /// In zh, this message translates to:
  /// **'启用 GPU 可加速转录，但需要兼容的运行环境。'**
  String get transcriptionGpuHelp;

  /// No description provided for @transcriptionGpuLabel.
  ///
  /// In zh, this message translates to:
  /// **'云端 GPU'**
  String get transcriptionGpuLabel;

  /// No description provided for @transcriptionHfTokenHint.
  ///
  /// In zh, this message translates to:
  /// **'填写 Hugging Face 令牌以访问私有模型。'**
  String get transcriptionHfTokenHint;

  /// No description provided for @transcriptionHfTokenOptional.
  ///
  /// In zh, this message translates to:
  /// **'Hugging Face 令牌（可选）'**
  String get transcriptionHfTokenOptional;

  /// No description provided for @transcriptionMaxWorkersHelp.
  ///
  /// In zh, this message translates to:
  /// **'限制同时运行的转录任务数量。'**
  String get transcriptionMaxWorkersHelp;

  /// No description provided for @transcriptionMaxWorkersLabel.
  ///
  /// In zh, this message translates to:
  /// **'最大工作线程数'**
  String get transcriptionMaxWorkersLabel;

  /// No description provided for @transcriptionModelBranchHelp.
  ///
  /// In zh, this message translates to:
  /// **'填写模型仓库中的分支或版本名称。'**
  String get transcriptionModelBranchHelp;

  /// No description provided for @transcriptionModelBranchLabel.
  ///
  /// In zh, this message translates to:
  /// **'模型分支'**
  String get transcriptionModelBranchLabel;

  /// No description provided for @transcriptionNeedToken.
  ///
  /// In zh, this message translates to:
  /// **'启用云端字幕转译时至少需要添加一个 Modal 令牌'**
  String get transcriptionNeedToken;

  /// No description provided for @transcriptionNewHfTokenHint.
  ///
  /// In zh, this message translates to:
  /// **'输入新的 Hugging Face 令牌；留空则保持原值。'**
  String get transcriptionNewHfTokenHint;

  /// No description provided for @transcriptionNoTokensHint.
  ///
  /// In zh, this message translates to:
  /// **'还没有配置转录令牌。'**
  String get transcriptionNoTokensHint;

  /// No description provided for @transcriptionPerTokenSliderLabel.
  ///
  /// In zh, this message translates to:
  /// **'每个令牌的并发数'**
  String get transcriptionPerTokenSliderLabel;

  /// No description provided for @transcriptionPerTokenWorkersHelp.
  ///
  /// In zh, this message translates to:
  /// **'为每个令牌分配的最大工作线程数。'**
  String get transcriptionPerTokenWorkersHelp;

  /// No description provided for @transcriptionPerTokenWorkersLabel.
  ///
  /// In zh, this message translates to:
  /// **'每个令牌的工作线程数'**
  String get transcriptionPerTokenWorkersLabel;

  /// No description provided for @transcriptionPerTokenWorkersRange.
  ///
  /// In zh, this message translates to:
  /// **'单令牌并发上限必须在 0-10 之间'**
  String get transcriptionPerTokenWorkersRange;

  /// No description provided for @transcriptionSaveButton.
  ///
  /// In zh, this message translates to:
  /// **'保存云端转译配置'**
  String get transcriptionSaveButton;

  /// No description provided for @transcriptionSaved.
  ///
  /// In zh, this message translates to:
  /// **'云端字幕转译配置已保存'**
  String get transcriptionSaved;

  /// No description provided for @transcriptionStrategyFillFirst.
  ///
  /// In zh, this message translates to:
  /// **'优先使用第一个令牌'**
  String get transcriptionStrategyFillFirst;

  /// No description provided for @transcriptionStrategyRoundRobin.
  ///
  /// In zh, this message translates to:
  /// **'轮流使用令牌'**
  String get transcriptionStrategyRoundRobin;

  /// No description provided for @transcriptionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'转录字幕'**
  String get transcriptionSubtitle;

  /// No description provided for @transcriptionTitle.
  ///
  /// In zh, this message translates to:
  /// **'云端字幕转译'**
  String get transcriptionTitle;

  /// No description provided for @transcriptionTokenConfigured.
  ///
  /// In zh, this message translates to:
  /// **'已配置'**
  String get transcriptionTokenConfigured;

  /// No description provided for @transcriptionTokenDraft.
  ///
  /// In zh, this message translates to:
  /// **'新令牌 · 保存后生效'**
  String get transcriptionTokenDraft;

  /// No description provided for @transcriptionTokenIdExists.
  ///
  /// In zh, this message translates to:
  /// **'已存在相同 Token ID 的令牌'**
  String get transcriptionTokenIdExists;

  /// No description provided for @transcriptionTokenIdHint.
  ///
  /// In zh, this message translates to:
  /// **'填写服务商提供的令牌 ID。'**
  String get transcriptionTokenIdHint;

  /// No description provided for @transcriptionTokenIdLabel.
  ///
  /// In zh, this message translates to:
  /// **'Token ID'**
  String get transcriptionTokenIdLabel;

  /// No description provided for @transcriptionTokenIncomplete.
  ///
  /// In zh, this message translates to:
  /// **'新增令牌必须同时填写 Token ID 和 Token Secret'**
  String get transcriptionTokenIncomplete;

  /// No description provided for @transcriptionTokenLimit.
  ///
  /// In zh, this message translates to:
  /// **'最多 {count} 个令牌'**
  String transcriptionTokenLimit(int count);

  /// No description provided for @transcriptionTokenListHint.
  ///
  /// In zh, this message translates to:
  /// **'可添加多个 Modal 令牌，最多 20 个'**
  String get transcriptionTokenListHint;

  /// No description provided for @transcriptionTokenNameHint.
  ///
  /// In zh, this message translates to:
  /// **'为令牌添加备注'**
  String get transcriptionTokenNameHint;

  /// No description provided for @transcriptionTokenNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'备注（可选）'**
  String get transcriptionTokenNameLabel;

  /// No description provided for @transcriptionTokenNumber.
  ///
  /// In zh, this message translates to:
  /// **'令牌 {number}'**
  String transcriptionTokenNumber(int number);

  /// No description provided for @transcriptionTokenSecretHint.
  ///
  /// In zh, this message translates to:
  /// **'填写服务商提供的 Token Secret'**
  String get transcriptionTokenSecretHint;

  /// No description provided for @transcriptionTokenSecretLabel.
  ///
  /// In zh, this message translates to:
  /// **'Token Secret'**
  String get transcriptionTokenSecretLabel;

  /// No description provided for @transcriptionTokenStrategyHelp.
  ///
  /// In zh, this message translates to:
  /// **'选择多个令牌的分配方式。'**
  String get transcriptionTokenStrategyHelp;

  /// No description provided for @transcriptionTokenStrategyLabel.
  ///
  /// In zh, this message translates to:
  /// **'令牌使用策略'**
  String get transcriptionTokenStrategyLabel;

  /// No description provided for @transcriptionTokensCount.
  ///
  /// In zh, this message translates to:
  /// **'已配置 {count} 个 · 上限 {limit} 个'**
  String transcriptionTokensCount(int count, int limit);

  /// No description provided for @transcriptionTokensEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'启用云端转译至少需要配置一个 Modal 令牌'**
  String get transcriptionTokensEmptyHint;

  /// No description provided for @transcriptionTokensLabel.
  ///
  /// In zh, this message translates to:
  /// **'MODAL 令牌'**
  String get transcriptionTokensLabel;

  /// No description provided for @transcriptionWorkersRange.
  ///
  /// In zh, this message translates to:
  /// **'并行数必须在 1-10 之间'**
  String get transcriptionWorkersRange;

  /// No description provided for @transcriptionWorkersSliderLabel.
  ///
  /// In zh, this message translates to:
  /// **'工作线程数'**
  String get transcriptionWorkersSliderLabel;

  /// No description provided for @translationApiUrlHelp.
  ///
  /// In zh, this message translates to:
  /// **'支持 OpenAI / OpenRouter 等兼容服务'**
  String get translationApiUrlHelp;

  /// No description provided for @translationConfiguredKeepHint.
  ///
  /// In zh, this message translates to:
  /// **'已配置的 API 凭据将继续使用，留空不会修改。'**
  String get translationConfiguredKeepHint;

  /// No description provided for @translationDisabledSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'翻译已禁用'**
  String get translationDisabledSubtitle;

  /// No description provided for @translationEnable.
  ///
  /// In zh, this message translates to:
  /// **'启用翻译'**
  String get translationEnable;

  /// No description provided for @translationEnabledSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'翻译已启用'**
  String get translationEnabledSubtitle;

  /// No description provided for @translationLangAutoDetect.
  ///
  /// In zh, this message translates to:
  /// **'自动检测'**
  String get translationLangAutoDetect;

  /// No description provided for @translationLangChinese.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get translationLangChinese;

  /// No description provided for @translationLangEnglish.
  ///
  /// In zh, this message translates to:
  /// **'英语'**
  String get translationLangEnglish;

  /// No description provided for @translationLangFrench.
  ///
  /// In zh, this message translates to:
  /// **'法语'**
  String get translationLangFrench;

  /// No description provided for @translationLangGerman.
  ///
  /// In zh, this message translates to:
  /// **'德语'**
  String get translationLangGerman;

  /// No description provided for @translationLangJapanese.
  ///
  /// In zh, this message translates to:
  /// **'日语'**
  String get translationLangJapanese;

  /// No description provided for @translationLangKorean.
  ///
  /// In zh, this message translates to:
  /// **'韩语'**
  String get translationLangKorean;

  /// No description provided for @translationLangRussian.
  ///
  /// In zh, this message translates to:
  /// **'俄语'**
  String get translationLangRussian;

  /// No description provided for @translationLangSpanish.
  ///
  /// In zh, this message translates to:
  /// **'西班牙语'**
  String get translationLangSpanish;

  /// No description provided for @translationLoadModels.
  ///
  /// In zh, this message translates to:
  /// **'加载模型'**
  String get translationLoadModels;

  /// No description provided for @translationLoadModelsFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载模型失败：{error}'**
  String translationLoadModelsFailed(String error);

  /// No description provided for @translationModelNameHelp.
  ///
  /// In zh, this message translates to:
  /// **'填写翻译服务使用的模型名称。'**
  String get translationModelNameHelp;

  /// No description provided for @translationModelNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'模型名称'**
  String get translationModelNameLabel;

  /// No description provided for @translationNeedApiKey.
  ///
  /// In zh, this message translates to:
  /// **'请先配置 API 密钥。'**
  String get translationNeedApiKey;

  /// No description provided for @translationNeedApiUrl.
  ///
  /// In zh, this message translates to:
  /// **'请先配置 API 地址。'**
  String get translationNeedApiUrl;

  /// No description provided for @translationNewApiKeyHint.
  ///
  /// In zh, this message translates to:
  /// **'输入新的 API 密钥；留空则保持原值。'**
  String get translationNewApiKeyHint;

  /// No description provided for @translationNoModels.
  ///
  /// In zh, this message translates to:
  /// **'没有可用的模型'**
  String get translationNoModels;

  /// No description provided for @translationPromptTemplateHelp.
  ///
  /// In zh, this message translates to:
  /// **'可用变量：{variables}'**
  String translationPromptTemplateHelp(String variables);

  /// No description provided for @translationPromptTemplateLabel.
  ///
  /// In zh, this message translates to:
  /// **'提示词模板'**
  String get translationPromptTemplateLabel;

  /// No description provided for @translationSaved.
  ///
  /// In zh, this message translates to:
  /// **'翻译已保存'**
  String get translationSaved;

  /// No description provided for @translationSelectModel.
  ///
  /// In zh, this message translates to:
  /// **'选择模型（{count} 个）'**
  String translationSelectModel(int count);

  /// No description provided for @translationSourceLanguage.
  ///
  /// In zh, this message translates to:
  /// **'源语言'**
  String get translationSourceLanguage;

  /// No description provided for @translationSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'配置翻译服务'**
  String get translationSubtitle;

  /// No description provided for @translationTargetLanguage.
  ///
  /// In zh, this message translates to:
  /// **'目标语言'**
  String get translationTargetLanguage;

  /// No description provided for @translationTestButton.
  ///
  /// In zh, this message translates to:
  /// **'测试翻译'**
  String get translationTestButton;

  /// No description provided for @translationBatchFailed.
  ///
  /// In zh, this message translates to:
  /// **'批量翻译失败'**
  String get translationBatchFailed;

  /// No description provided for @translationTestFailed.
  ///
  /// In zh, this message translates to:
  /// **'测试失败：{error}'**
  String translationTestFailed(String error);

  /// No description provided for @translationTestPassed.
  ///
  /// In zh, this message translates to:
  /// **'测试通过'**
  String get translationTestPassed;

  /// No description provided for @translationTestResult.
  ///
  /// In zh, this message translates to:
  /// **'测试结果'**
  String get translationTestResult;

  /// No description provided for @translationTitle.
  ///
  /// In zh, this message translates to:
  /// **'翻译设置'**
  String get translationTitle;

  /// No description provided for @accessBindTotp.
  ///
  /// In zh, this message translates to:
  /// **'绑定 TOTP'**
  String get accessBindTotp;

  /// No description provided for @accessChangePassword.
  ///
  /// In zh, this message translates to:
  /// **'修改密码'**
  String get accessChangePassword;

  /// No description provided for @accessChangePasswordHelp.
  ///
  /// In zh, this message translates to:
  /// **'修改用于访问应用的本地密码。'**
  String get accessChangePasswordHelp;

  /// No description provided for @accessConfigSaved.
  ///
  /// In zh, this message translates to:
  /// **'访问配置已保存'**
  String get accessConfigSaved;

  /// No description provided for @accessControlSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'访问控制'**
  String get accessControlSubtitle;

  /// No description provided for @accessDeleteTotp.
  ///
  /// In zh, this message translates to:
  /// **'删除 TOTP'**
  String get accessDeleteTotp;

  /// No description provided for @accessDeleteTotpConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除已绑定的 TOTP？'**
  String get accessDeleteTotpConfirm;

  /// No description provided for @accessDisabled.
  ///
  /// In zh, this message translates to:
  /// **'访问保护已禁用'**
  String get accessDisabled;

  /// No description provided for @accessEnabled.
  ///
  /// In zh, this message translates to:
  /// **'访问保护已启用'**
  String get accessEnabled;

  /// No description provided for @accessEnableFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先启用访问保护'**
  String get accessEnableFirst;

  /// No description provided for @accessLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载访问控制失败'**
  String get accessLoadFailed;

  /// No description provided for @accessLockDuration.
  ///
  /// In zh, this message translates to:
  /// **'锁定时长'**
  String get accessLockDuration;

  /// No description provided for @accessLockMinutesHelp.
  ///
  /// In zh, this message translates to:
  /// **'范围 1-1440 分钟。'**
  String get accessLockMinutesHelp;

  /// No description provided for @accessMaxAttemptsHelp.
  ///
  /// In zh, this message translates to:
  /// **'范围 1-100 次，达到后临时锁定。'**
  String get accessMaxAttemptsHelp;

  /// No description provided for @accessMaxFailedAttempts.
  ///
  /// In zh, this message translates to:
  /// **'最大失败次数'**
  String get accessMaxFailedAttempts;

  /// No description provided for @accessNewPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'输入新密码'**
  String get accessNewPasswordHint;

  /// No description provided for @accessPasskeyConfiguredInfo.
  ///
  /// In zh, this message translates to:
  /// **'服务器已配置 Passkey。移动端暂不支持注册或管理 Passkey，请在网页端访问控制中操作。'**
  String get accessPasskeyConfiguredInfo;

  /// No description provided for @accessPasskeyOnlyInfo.
  ///
  /// In zh, this message translates to:
  /// **'服务器当前仅允许 Passkey 登录，移动端暂不支持 Passkey 登录或管理，请在网页端访问控制中操作。'**
  String get accessPasskeyOnlyInfo;

  /// No description provided for @accessPasswordMinHint.
  ///
  /// In zh, this message translates to:
  /// **'密码至少需要 4 位。'**
  String get accessPasswordMinHint;

  /// No description provided for @accessPasswordTooShort.
  ///
  /// In zh, this message translates to:
  /// **'访问密码至少需要 8 位字符'**
  String get accessPasswordTooShort;

  /// No description provided for @accessRangeError.
  ///
  /// In zh, this message translates to:
  /// **'{label} 必须在 {min}–{max} 之间'**
  String accessRangeError(String label, int min, int max);

  /// No description provided for @accessRebindTotp.
  ///
  /// In zh, this message translates to:
  /// **'重新绑定 TOTP'**
  String get accessRebindTotp;

  /// No description provided for @accessRefreshDaysHelp.
  ///
  /// In zh, this message translates to:
  /// **'范围 1-90 天；Access Token 固定 24 小时自动刷新。'**
  String get accessRefreshDaysHelp;

  /// No description provided for @accessRefreshTokenDays.
  ///
  /// In zh, this message translates to:
  /// **'有效期'**
  String get accessRefreshTokenDays;

  /// No description provided for @accessSectionMfa.
  ///
  /// In zh, this message translates to:
  /// **'双重验证'**
  String get accessSectionMfa;

  /// No description provided for @accessSectionMfaHelp.
  ///
  /// In zh, this message translates to:
  /// **'使用 TOTP 为敏感操作增加一层保护。'**
  String get accessSectionMfaHelp;

  /// No description provided for @accessSectionProtection.
  ///
  /// In zh, this message translates to:
  /// **'访问保护'**
  String get accessSectionProtection;

  /// No description provided for @accessSectionProtectionHelp.
  ///
  /// In zh, this message translates to:
  /// **'设置进入应用时需要的本地验证方式。'**
  String get accessSectionProtectionHelp;

  /// No description provided for @accessSectionSession.
  ///
  /// In zh, this message translates to:
  /// **'会话'**
  String get accessSectionSession;

  /// No description provided for @accessSectionSessionHelp.
  ///
  /// In zh, this message translates to:
  /// **'管理登录会话和自动退出行为。'**
  String get accessSectionSessionHelp;

  /// No description provided for @accessSetPassword.
  ///
  /// In zh, this message translates to:
  /// **'修改访问密码'**
  String get accessSetPassword;

  /// No description provided for @accessSetPasswordHelp.
  ///
  /// In zh, this message translates to:
  /// **'设置用于本地验证的密码。'**
  String get accessSetPasswordHelp;

  /// No description provided for @accessStatusActive.
  ///
  /// In zh, this message translates to:
  /// **'访问保护已启用'**
  String get accessStatusActive;

  /// No description provided for @accessStatusActiveDesc.
  ///
  /// In zh, this message translates to:
  /// **'API、媒体资源与实时任务均需要有效登录会话。'**
  String get accessStatusActiveDesc;

  /// No description provided for @accessStatusConfigured.
  ///
  /// In zh, this message translates to:
  /// **'访问状态已配置'**
  String get accessStatusConfigured;

  /// No description provided for @accessStatusConfiguredDesc.
  ///
  /// In zh, this message translates to:
  /// **'保存并启用后，未登录访问将被拦截。'**
  String get accessStatusConfiguredDesc;

  /// No description provided for @accessStatusNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'尚未配置登录凭据'**
  String get accessStatusNotConfigured;

  /// No description provided for @accessStatusNotConfiguredDesc.
  ///
  /// In zh, this message translates to:
  /// **'设置至少一个登录凭据后即可启用访问控制。'**
  String get accessStatusNotConfiguredDesc;

  /// No description provided for @accessTotpBoundDesc.
  ///
  /// In zh, this message translates to:
  /// **'已绑定 TOTP，可用于双重验证。'**
  String get accessTotpBoundDesc;

  /// No description provided for @accessTotpCode.
  ///
  /// In zh, this message translates to:
  /// **'验证码'**
  String get accessTotpCode;

  /// No description provided for @accessTotpCodeHint.
  ///
  /// In zh, this message translates to:
  /// **'输入验证器中的验证码'**
  String get accessTotpCodeHint;

  /// No description provided for @accessTotpConfirmBind.
  ///
  /// In zh, this message translates to:
  /// **'确认绑定 TOTP'**
  String get accessTotpConfirmBind;

  /// No description provided for @accessTotpDeleted.
  ///
  /// In zh, this message translates to:
  /// **'TOTP 已删除'**
  String get accessTotpDeleted;

  /// No description provided for @accessTotpEnabled.
  ///
  /// In zh, this message translates to:
  /// **'TOTP 已启用'**
  String get accessTotpEnabled;

  /// No description provided for @accessTotpManualKey.
  ///
  /// In zh, this message translates to:
  /// **'无法扫描时，可手动输入密钥：'**
  String get accessTotpManualKey;

  /// No description provided for @accessTotpTwoFactor.
  ///
  /// In zh, this message translates to:
  /// **'TOTP 两步验证'**
  String get accessTotpTwoFactor;

  /// No description provided for @accessTotpUnboundDesc.
  ///
  /// In zh, this message translates to:
  /// **'尚未绑定 TOTP。'**
  String get accessTotpUnboundDesc;

  /// No description provided for @actorAssocActionAppendAlias.
  ///
  /// In zh, this message translates to:
  /// **'追加别名'**
  String get actorAssocActionAppendAlias;

  /// No description provided for @actorAssocActionSync.
  ///
  /// In zh, this message translates to:
  /// **'同步'**
  String get actorAssocActionSync;

  /// No description provided for @actorAssocAvatarCandidate.
  ///
  /// In zh, this message translates to:
  /// **'候选头像 {index}'**
  String actorAssocAvatarCandidate(int index);

  /// No description provided for @actorAssocAvatarConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定（{count} 张）'**
  String actorAssocAvatarConfirm(int count);

  /// No description provided for @actorAssocAvatarPickerCount.
  ///
  /// In zh, this message translates to:
  /// **'为“{name}”选择头像（已选 {selected}/{total}）'**
  String actorAssocAvatarPickerCount(String name, int selected, int total);

  /// No description provided for @actorAssocAvatarPickerCountWithFailed.
  ///
  /// In zh, this message translates to:
  /// **'为“{name}”选择头像（已选 {selected}/{total}，{failed} 个加载失败）'**
  String actorAssocAvatarPickerCountWithFailed(
    String name,
    int selected,
    int total,
    int failed,
  );

  /// No description provided for @actorAssocAvatarPickerNameFallback.
  ///
  /// In zh, this message translates to:
  /// **'未命名演员'**
  String get actorAssocAvatarPickerNameFallback;

  /// No description provided for @actorAssocAvatarPickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择演员头像'**
  String get actorAssocAvatarPickerTitle;

  /// No description provided for @actorAssocAvatarRetry.
  ///
  /// In zh, this message translates to:
  /// **'点击重试'**
  String get actorAssocAvatarRetry;

  /// No description provided for @actorAssocAvatarRetrySemantics.
  ///
  /// In zh, this message translates to:
  /// **'重试第 {index} 张演员头像'**
  String actorAssocAvatarRetrySemantics(int index);

  /// No description provided for @actorAssocAvatarSelected.
  ///
  /// In zh, this message translates to:
  /// **'已选择头像'**
  String get actorAssocAvatarSelected;

  /// No description provided for @actorAssocAvatarSelectSemantics.
  ///
  /// In zh, this message translates to:
  /// **'选择第 {index} 张演员头像'**
  String actorAssocAvatarSelectSemantics(int index);

  /// No description provided for @actorAssocDeletedToast.
  ///
  /// In zh, this message translates to:
  /// **'演员关联已删除'**
  String get actorAssocDeletedToast;

  /// No description provided for @actorAssocDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败：{error}'**
  String actorAssocDeleteFailed(String error);

  /// No description provided for @actorAssocDeleteMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定删除“{name}”及其 {count} 个关联名称吗？'**
  String actorAssocDeleteMessage(String name, int count);

  /// No description provided for @actorAssocDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除演员关联'**
  String get actorAssocDeleteTitle;

  /// No description provided for @actorAssocDeselectAll.
  ///
  /// In zh, this message translates to:
  /// **'取消全选'**
  String get actorAssocDeselectAll;

  /// No description provided for @actorAssocEditorAliasHint.
  ///
  /// In zh, this message translates to:
  /// **'多个值用换行分隔'**
  String get actorAssocEditorAliasHint;

  /// No description provided for @actorAssocEditorAliasLabel.
  ///
  /// In zh, this message translates to:
  /// **'别名'**
  String get actorAssocEditorAliasLabel;

  /// No description provided for @actorAssocEditorAliasPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'一行一个, 或用 , ; 、 分隔'**
  String get actorAssocEditorAliasPlaceholder;

  /// No description provided for @actorAssocEditorCanonicalExample.
  ///
  /// In zh, this message translates to:
  /// **'填写标准演员名'**
  String get actorAssocEditorCanonicalExample;

  /// No description provided for @actorAssocEditorCanonicalHint.
  ///
  /// In zh, this message translates to:
  /// **'标准演员名用于匹配影片中的演员'**
  String get actorAssocEditorCanonicalHint;

  /// No description provided for @actorAssocEditorCanonicalLabel.
  ///
  /// In zh, this message translates to:
  /// **'标准演员'**
  String get actorAssocEditorCanonicalLabel;

  /// No description provided for @actorAssocEditorCanonicalLocked.
  ///
  /// In zh, this message translates to:
  /// **'标准演员名已锁定'**
  String get actorAssocEditorCanonicalLocked;

  /// No description provided for @actorAssocEditorCreate.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get actorAssocEditorCreate;

  /// No description provided for @actorAssocEditorExistingAliases.
  ///
  /// In zh, this message translates to:
  /// **'已有 {count} 个关联名称，将在此基础上追加'**
  String actorAssocEditorExistingAliases(int count);

  /// No description provided for @actorAssocEditorNewAliasLabel.
  ///
  /// In zh, this message translates to:
  /// **'新增别名'**
  String get actorAssocEditorNewAliasLabel;

  /// No description provided for @actorAssocEditorSeparatorHint.
  ///
  /// In zh, this message translates to:
  /// **'多个名称可用换行、逗号或分号分隔'**
  String get actorAssocEditorSeparatorHint;

  /// No description provided for @actorAssocEditorTitleAppend.
  ///
  /// In zh, this message translates to:
  /// **'追加别名'**
  String get actorAssocEditorTitleAppend;

  /// No description provided for @actorAssocEditorTitleCreate.
  ///
  /// In zh, this message translates to:
  /// **'新建演员关联'**
  String get actorAssocEditorTitleCreate;

  /// No description provided for @actorAssocEditorTitleEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑关联'**
  String get actorAssocEditorTitleEdit;

  /// No description provided for @actorAssocEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无演员关联'**
  String get actorAssocEmpty;

  /// No description provided for @actorAssocErrAliasRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入别名'**
  String get actorAssocErrAliasRequired;

  /// No description provided for @actorAssocErrAtLeastOneAlias.
  ///
  /// In zh, this message translates to:
  /// **'请至少添加一个关联名称'**
  String get actorAssocErrAtLeastOneAlias;

  /// No description provided for @actorAssocErrNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入演员名称'**
  String get actorAssocErrNameRequired;

  /// No description provided for @actorAssocNoNewAliases.
  ///
  /// In zh, this message translates to:
  /// **'没有新的关联名称'**
  String get actorAssocNoNewAliases;

  /// No description provided for @actorAssocSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存：{name}'**
  String actorAssocSaved(String name);

  /// No description provided for @actorAssocSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存“{name}”失败：{error}'**
  String actorAssocSaveFailed(String name, String error);

  /// No description provided for @actorAssocSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索演员关联'**
  String get actorAssocSearchHint;

  /// No description provided for @actorAssocSourceMixed.
  ///
  /// In zh, this message translates to:
  /// **'混合来源'**
  String get actorAssocSourceMixed;

  /// No description provided for @actorAssocSyncApply.
  ///
  /// In zh, this message translates to:
  /// **'确认添加'**
  String get actorAssocSyncApply;

  /// No description provided for @actorAssocSyncApplyFailed.
  ///
  /// In zh, this message translates to:
  /// **'同步应用失败：{error}'**
  String actorAssocSyncApplyFailed(String error);

  /// No description provided for @actorAssocSyncApplying.
  ///
  /// In zh, this message translates to:
  /// **'正在添加…'**
  String get actorAssocSyncApplying;

  /// No description provided for @actorAssocSyncAvatarExists.
  ///
  /// In zh, this message translates to:
  /// **'已有头像'**
  String get actorAssocSyncAvatarExists;

  /// No description provided for @actorAssocSyncAvatarFailed.
  ///
  /// In zh, this message translates to:
  /// **'获取头像失败'**
  String get actorAssocSyncAvatarFailed;

  /// No description provided for @actorAssocSyncAvatarLabel.
  ///
  /// In zh, this message translates to:
  /// **'演员头像'**
  String get actorAssocSyncAvatarLabel;

  /// No description provided for @actorAssocSyncAvatarLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在获取头像...'**
  String get actorAssocSyncAvatarLoading;

  /// No description provided for @actorAssocSyncAvatarLoadingReplace.
  ///
  /// In zh, this message translates to:
  /// **'正在获取数据源头像，可多选后替换本地'**
  String get actorAssocSyncAvatarLoadingReplace;

  /// No description provided for @actorAssocSyncAvatarNoneSelected.
  ///
  /// In zh, this message translates to:
  /// **'未选择头像（点头像候选调整）'**
  String get actorAssocSyncAvatarNoneSelected;

  /// No description provided for @actorAssocSyncAvatarWillReplace.
  ///
  /// In zh, this message translates to:
  /// **'将用已选 {count} 张头像替换当前头像'**
  String actorAssocSyncAvatarWillReplace(int count);

  /// No description provided for @actorAssocSyncAvatarWillSync.
  ///
  /// In zh, this message translates to:
  /// **'将同步 {count} 张头像'**
  String actorAssocSyncAvatarWillSync(int count);

  /// No description provided for @actorAssocSyncCanonicalLabel.
  ///
  /// In zh, this message translates to:
  /// **'标准演员'**
  String get actorAssocSyncCanonicalLabel;

  /// No description provided for @actorAssocSyncDone.
  ///
  /// In zh, this message translates to:
  /// **'同步完成'**
  String get actorAssocSyncDone;

  /// No description provided for @actorAssocSyncExistingTitle.
  ///
  /// In zh, this message translates to:
  /// **'已有关联'**
  String get actorAssocSyncExistingTitle;

  /// No description provided for @actorAssocSyncNewAliasesTitle.
  ///
  /// In zh, this message translates to:
  /// **'新关联名称（已选 {selected}/{total}）'**
  String actorAssocSyncNewAliasesTitle(int selected, int total);

  /// No description provided for @actorAssocSyncNoMatchHint.
  ///
  /// In zh, this message translates to:
  /// **'未找到“{name}”的匹配结果'**
  String actorAssocSyncNoMatchHint(String name);

  /// No description provided for @actorAssocSyncNoMatchTitle.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配结果'**
  String get actorAssocSyncNoMatchTitle;

  /// No description provided for @actorAssocSyncNoNewAliases.
  ///
  /// In zh, this message translates to:
  /// **'没有可添加的新名称'**
  String get actorAssocSyncNoNewAliases;

  /// No description provided for @actorAssocSyncNoPreviewHint.
  ///
  /// In zh, this message translates to:
  /// **'暂无预览内容'**
  String get actorAssocSyncNoPreviewHint;

  /// No description provided for @actorAssocSyncNoPreviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无预览'**
  String get actorAssocSyncNoPreviewTitle;

  /// No description provided for @actorAssocSyncPickAvatar.
  ///
  /// In zh, this message translates to:
  /// **'选择演员头像'**
  String get actorAssocSyncPickAvatar;

  /// No description provided for @actorAssocSyncRequestFailed.
  ///
  /// In zh, this message translates to:
  /// **'请求失败'**
  String get actorAssocSyncRequestFailed;

  /// No description provided for @actorAssocSyncSourceFailed.
  ///
  /// In zh, this message translates to:
  /// **'请求失败'**
  String get actorAssocSyncSourceFailed;

  /// No description provided for @actorAssocSyncSourceNoMatch.
  ///
  /// In zh, this message translates to:
  /// **'无匹配'**
  String get actorAssocSyncSourceNoMatch;

  /// No description provided for @actorAssocSyncSourceQuerying.
  ///
  /// In zh, this message translates to:
  /// **'查询中'**
  String get actorAssocSyncSourceQuerying;

  /// No description provided for @actorAssocSyncSourcesRequired.
  ///
  /// In zh, this message translates to:
  /// **'请先在服务器设置中配置并启用 DB Online 或 AVDB 数据源'**
  String get actorAssocSyncSourcesRequired;

  /// No description provided for @actorAssocSyncMixedFailed.
  ///
  /// In zh, this message translates to:
  /// **'混合渠道查询失败'**
  String get actorAssocSyncMixedFailed;

  /// No description provided for @actorAssocSyncPreviewTimedOut.
  ///
  /// In zh, this message translates to:
  /// **'混合渠道预览超时'**
  String get actorAssocSyncPreviewTimedOut;

  /// No description provided for @actorAssocSyncSourcesLabel.
  ///
  /// In zh, this message translates to:
  /// **'数据源'**
  String get actorAssocSyncSourcesLabel;

  /// No description provided for @actorAssocSyncSourcesLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在加载数据源…'**
  String get actorAssocSyncSourcesLoading;

  /// No description provided for @actorAssocSyncSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'同步演员关联'**
  String get actorAssocSyncSubtitle;

  /// No description provided for @actorAssocSyncTitle.
  ///
  /// In zh, this message translates to:
  /// **'同步演员：{name}'**
  String actorAssocSyncTitle(String name);

  /// No description provided for @actorAssocTitle.
  ///
  /// In zh, this message translates to:
  /// **'演员关联管理'**
  String get actorAssocTitle;

  /// No description provided for @actorEditorBiographyLabel.
  ///
  /// In zh, this message translates to:
  /// **'演员简介'**
  String get actorEditorBiographyLabel;

  /// No description provided for @appLogClear.
  ///
  /// In zh, this message translates to:
  /// **'清空日志'**
  String get appLogClear;

  /// No description provided for @appLogCleared.
  ///
  /// In zh, this message translates to:
  /// **'日志已清空'**
  String get appLogCleared;

  /// No description provided for @appLogClearSub.
  ///
  /// In zh, this message translates to:
  /// **'清空后重新复现，可减少无关信息'**
  String get appLogClearSub;

  /// No description provided for @appLogContent.
  ///
  /// In zh, this message translates to:
  /// **'日志内容'**
  String get appLogContent;

  /// No description provided for @appLogCopied.
  ///
  /// In zh, this message translates to:
  /// **'日志已复制'**
  String get appLogCopied;

  /// No description provided for @appLogCopyAll.
  ///
  /// In zh, this message translates to:
  /// **'复制全部日志'**
  String get appLogCopyAll;

  /// No description provided for @appLogCount.
  ///
  /// In zh, this message translates to:
  /// **'日志（{count}）'**
  String appLogCount(int count);

  /// No description provided for @appLogEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无日志'**
  String get appLogEmpty;

  /// No description provided for @appLogEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'暂无日志\n先播放一次 SMB / WebDAV 视频'**
  String get appLogEmptyHint;

  /// No description provided for @appLogSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'复现问题后返回此页，复制日志发给开发者分析'**
  String get appLogSubtitle;

  /// No description provided for @appLogTitle.
  ///
  /// In zh, this message translates to:
  /// **'播放日志'**
  String get appLogTitle;

  /// No description provided for @audioActionCancelExtraction.
  ///
  /// In zh, this message translates to:
  /// **'取消提取'**
  String get audioActionCancelExtraction;

  /// No description provided for @audioActionCancelTranscription.
  ///
  /// In zh, this message translates to:
  /// **'取消转录'**
  String get audioActionCancelTranscription;

  /// No description provided for @audioActionDeleteAudio.
  ///
  /// In zh, this message translates to:
  /// **'删除音频'**
  String get audioActionDeleteAudio;

  /// No description provided for @audioActionEnqueueTranscription.
  ///
  /// In zh, this message translates to:
  /// **'加入转译'**
  String get audioActionEnqueueTranscription;

  /// No description provided for @audioActionRetryTranscription.
  ///
  /// In zh, this message translates to:
  /// **'重试转录'**
  String get audioActionRetryTranscription;

  /// No description provided for @audioAssetCountSuffix.
  ///
  /// In zh, this message translates to:
  /// **'个音频资产'**
  String get audioAssetCountSuffix;

  /// No description provided for @audioCancelExtractionFailed.
  ///
  /// In zh, this message translates to:
  /// **'取消提取失败：{error}'**
  String audioCancelExtractionFailed(String error);

  /// No description provided for @audioCancelExtractionSubmitted.
  ///
  /// In zh, this message translates to:
  /// **'已提交取消提取'**
  String get audioCancelExtractionSubmitted;

  /// No description provided for @audioCancelSubmitted.
  ///
  /// In zh, this message translates to:
  /// **'已提交取消任务'**
  String get audioCancelSubmitted;

  /// No description provided for @audioCancelTranscriptionFailed.
  ///
  /// In zh, this message translates to:
  /// **'取消转录失败：{error}'**
  String audioCancelTranscriptionFailed(String error);

  /// No description provided for @audioDeleteBatchAction.
  ///
  /// In zh, this message translates to:
  /// **'批量删除'**
  String get audioDeleteBatchAction;

  /// No description provided for @audioDeleteBatchTitle.
  ///
  /// In zh, this message translates to:
  /// **'批量删除音频'**
  String get audioDeleteBatchTitle;

  /// No description provided for @audioDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除 {count} 个音频资产'**
  String audioDeleted(int count);

  /// No description provided for @audioDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除音频失败：{error}'**
  String audioDeleteFailed(String error);

  /// No description provided for @audioDeleteFileFallback.
  ///
  /// In zh, this message translates to:
  /// **'音频文件'**
  String get audioDeleteFileFallback;

  /// No description provided for @audioDeleteMessageBatch.
  ///
  /// In zh, this message translates to:
  /// **'确定删除已选的 {count} 个音频文件吗？'**
  String audioDeleteMessageBatch(int count);

  /// No description provided for @audioDeleteMessageSingle.
  ///
  /// In zh, this message translates to:
  /// **'确定删除“{name}”吗？'**
  String audioDeleteMessageSingle(String name);

  /// No description provided for @audioDeleteResult.
  ///
  /// In zh, this message translates to:
  /// **'删除完成：成功 {deleted} 个，{rejected}'**
  String audioDeleteResult(int deleted, String rejected);

  /// No description provided for @audioDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除音频'**
  String get audioDeleteTitle;

  /// No description provided for @audioEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'从影片中提取音频后即可在此查看'**
  String get audioEmptyHint;

  /// No description provided for @audioEmptySearchHint.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的音频文件'**
  String get audioEmptySearchHint;

  /// No description provided for @audioEmptySearchTitle.
  ///
  /// In zh, this message translates to:
  /// **'未找到音频'**
  String get audioEmptySearchTitle;

  /// No description provided for @audioEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无音频文件'**
  String get audioEmptyTitle;

  /// No description provided for @audioEnqueueBatchTitle.
  ///
  /// In zh, this message translates to:
  /// **'批量加入转录任务'**
  String get audioEnqueueBatchTitle;

  /// No description provided for @audioEnqueueConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认加入转录队列'**
  String get audioEnqueueConfirm;

  /// No description provided for @audioEnqueued.
  ///
  /// In zh, this message translates to:
  /// **'已加入 {count} 个字幕转译任务'**
  String audioEnqueued(int count);

  /// No description provided for @audioEnqueuedMixed.
  ///
  /// In zh, this message translates to:
  /// **'已加入 {accepted} 个任务 · {rejected}'**
  String audioEnqueuedMixed(int accepted, String rejected);

  /// No description provided for @audioEnqueueFailed.
  ///
  /// In zh, this message translates to:
  /// **'加入转录任务失败：{error}'**
  String audioEnqueueFailed(String error);

  /// No description provided for @audioEnqueueMessageBatch.
  ///
  /// In zh, this message translates to:
  /// **'将 {count} 个音频资产加入云端转译队列。'**
  String audioEnqueueMessageBatch(int count);

  /// No description provided for @audioEnqueueMessageSingle.
  ///
  /// In zh, this message translates to:
  /// **'确定为“{name}”创建转录任务吗？'**
  String audioEnqueueMessageSingle(String name);

  /// No description provided for @audioEnqueueTitle.
  ///
  /// In zh, this message translates to:
  /// **'加入转录任务'**
  String get audioEnqueueTitle;

  /// No description provided for @audioExtractingSection.
  ///
  /// In zh, this message translates to:
  /// **'正在提取音频'**
  String get audioExtractingSection;

  /// No description provided for @audioEyebrow.
  ///
  /// In zh, this message translates to:
  /// **'媒体工具'**
  String get audioEyebrow;

  /// No description provided for @audioFileMissing.
  ///
  /// In zh, this message translates to:
  /// **'文件缺失'**
  String get audioFileMissing;

  /// No description provided for @audioOverwriteExistingSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'覆盖已有字幕'**
  String get audioOverwriteExistingSubtitle;

  /// No description provided for @audioRequeued.
  ///
  /// In zh, this message translates to:
  /// **'已重新加入队列'**
  String get audioRequeued;

  /// No description provided for @audioRetryFailed.
  ///
  /// In zh, this message translates to:
  /// **'重试转录失败：{error}'**
  String audioRetryFailed(String error);

  /// No description provided for @audioRetryMessage.
  ///
  /// In zh, this message translates to:
  /// **'重新提交「{name}」的字幕转译任务。'**
  String audioRetryMessage(String name);

  /// No description provided for @audioRetryTitle.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get audioRetryTitle;

  /// No description provided for @audioSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索音频'**
  String get audioSearchHint;

  /// No description provided for @audioSearchSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'搜索：{query}'**
  String audioSearchSubtitle(String query);

  /// No description provided for @audioStageCanceled.
  ///
  /// In zh, this message translates to:
  /// **'已取消'**
  String get audioStageCanceled;

  /// No description provided for @audioStageCompleted.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get audioStageCompleted;

  /// No description provided for @audioStageConnecting.
  ///
  /// In zh, this message translates to:
  /// **'连接中'**
  String get audioStageConnecting;

  /// No description provided for @audioStageDownloading.
  ///
  /// In zh, this message translates to:
  /// **'下载中'**
  String get audioStageDownloading;

  /// No description provided for @audioStageFailed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get audioStageFailed;

  /// No description provided for @audioStagePreparing.
  ///
  /// In zh, this message translates to:
  /// **'准备中'**
  String get audioStagePreparing;

  /// No description provided for @audioStageQueued.
  ///
  /// In zh, this message translates to:
  /// **'排队中'**
  String get audioStageQueued;

  /// No description provided for @audioStageRegistering.
  ///
  /// In zh, this message translates to:
  /// **'注册中'**
  String get audioStageRegistering;

  /// No description provided for @audioStageSandbox.
  ///
  /// In zh, this message translates to:
  /// **'沙盒处理中'**
  String get audioStageSandbox;

  /// No description provided for @audioStageSkipped.
  ///
  /// In zh, this message translates to:
  /// **'已跳过'**
  String get audioStageSkipped;

  /// No description provided for @audioStageStarting.
  ///
  /// In zh, this message translates to:
  /// **'启动中'**
  String get audioStageStarting;

  /// No description provided for @audioStageTranscribing.
  ///
  /// In zh, this message translates to:
  /// **'转录中'**
  String get audioStageTranscribing;

  /// No description provided for @audioStageTranscribingFallback.
  ///
  /// In zh, this message translates to:
  /// **'转录中（备用）'**
  String get audioStageTranscribingFallback;

  /// No description provided for @audioStageUploading.
  ///
  /// In zh, this message translates to:
  /// **'上传中'**
  String get audioStageUploading;

  /// No description provided for @audioStatusCanceled.
  ///
  /// In zh, this message translates to:
  /// **'已取消'**
  String get audioStatusCanceled;

  /// No description provided for @audioStatusFailed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get audioStatusFailed;

  /// No description provided for @audioStatusNotTranscribed.
  ///
  /// In zh, this message translates to:
  /// **'未转译'**
  String get audioStatusNotTranscribed;

  /// No description provided for @audioStatusTranscribed.
  ///
  /// In zh, this message translates to:
  /// **'已转译'**
  String get audioStatusTranscribed;

  /// No description provided for @audioSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'音频转录'**
  String get audioSubtitle;

  /// No description provided for @audioTaskExtracting.
  ///
  /// In zh, this message translates to:
  /// **'音频提取'**
  String get audioTaskExtracting;

  /// No description provided for @audioTaskQueued.
  ///
  /// In zh, this message translates to:
  /// **'音频转录'**
  String get audioTaskQueued;

  /// No description provided for @audioTitle.
  ///
  /// In zh, this message translates to:
  /// **'音频'**
  String get audioTitle;

  /// No description provided for @audioTranscriptionCanceledHint.
  ///
  /// In zh, this message translates to:
  /// **'转录任务已取消'**
  String get audioTranscriptionCanceledHint;

  /// No description provided for @avdbEnableOff.
  ///
  /// In zh, this message translates to:
  /// **'已停用 AVDB'**
  String get avdbEnableOff;

  /// No description provided for @avdbEnableOn.
  ///
  /// In zh, this message translates to:
  /// **'演员同步可选择 AVDB'**
  String get avdbEnableOn;

  /// No description provided for @avdbEnableTitle.
  ///
  /// In zh, this message translates to:
  /// **'启用 AVDB 数据源'**
  String get avdbEnableTitle;

  /// No description provided for @avdbKeyConfigured.
  ///
  /// In zh, this message translates to:
  /// **'已配置 · 留空则保留当前密钥'**
  String get avdbKeyConfigured;

  /// No description provided for @avdbKeyHide.
  ///
  /// In zh, this message translates to:
  /// **'隐藏密钥'**
  String get avdbKeyHide;

  /// No description provided for @avdbKeyKeepHint.
  ///
  /// In zh, this message translates to:
  /// **'留空保留当前密钥'**
  String get avdbKeyKeepHint;

  /// No description provided for @avdbKeyPrompt.
  ///
  /// In zh, this message translates to:
  /// **'API 密钥'**
  String get avdbKeyPrompt;

  /// No description provided for @avdbKeyShow.
  ///
  /// In zh, this message translates to:
  /// **'显示 API 密钥'**
  String get avdbKeyShow;

  /// No description provided for @avdbSavedToast.
  ///
  /// In zh, this message translates to:
  /// **'AVDB 配置已保存'**
  String get avdbSavedToast;

  /// No description provided for @avdbServerSection.
  ///
  /// In zh, this message translates to:
  /// **'服务地址'**
  String get avdbServerSection;

  /// No description provided for @avdbStatusSection.
  ///
  /// In zh, this message translates to:
  /// **'启用状态'**
  String get avdbStatusSection;

  /// No description provided for @avdbSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'用于演员关联同步。请先配置并启用 AVDB 数据源。'**
  String get avdbSubtitle;

  /// No description provided for @avdbTitle.
  ///
  /// In zh, this message translates to:
  /// **'AVDB 数据源'**
  String get avdbTitle;

  /// No description provided for @badgePreviewMovieTitle.
  ///
  /// In zh, this message translates to:
  /// **'影片标题'**
  String get badgePreviewMovieTitle;

  /// No description provided for @cacheCategoryImage.
  ///
  /// In zh, this message translates to:
  /// **'图片'**
  String get cacheCategoryImage;

  /// No description provided for @cacheCategoryOther.
  ///
  /// In zh, this message translates to:
  /// **'其他缓存'**
  String get cacheCategoryOther;

  /// No description provided for @codecUnknown.
  ///
  /// In zh, this message translates to:
  /// **'编码未知'**
  String get codecUnknown;

  /// No description provided for @commonActions.
  ///
  /// In zh, this message translates to:
  /// **'操作'**
  String get commonActions;

  /// No description provided for @commonChange.
  ///
  /// In zh, this message translates to:
  /// **'更改'**
  String get commonChange;

  /// No description provided for @commonClear.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get commonClear;

  /// No description provided for @commonDownloading.
  ///
  /// In zh, this message translates to:
  /// **'下载中'**
  String get commonDownloading;

  /// No description provided for @commonHidePassword.
  ///
  /// In zh, this message translates to:
  /// **'隐藏密码'**
  String get commonHidePassword;

  /// No description provided for @commonIgnore.
  ///
  /// In zh, this message translates to:
  /// **'忽略'**
  String get commonIgnore;

  /// No description provided for @commonIosOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅支持 iOS'**
  String get commonIosOnly;

  /// No description provided for @commonLater.
  ///
  /// In zh, this message translates to:
  /// **'稍后'**
  String get commonLater;

  /// No description provided for @commonShowPassword.
  ///
  /// In zh, this message translates to:
  /// **'显示密码'**
  String get commonShowPassword;

  /// No description provided for @configInputPrompt.
  ///
  /// In zh, this message translates to:
  /// **'配置输入提示词'**
  String get configInputPrompt;

  /// No description provided for @configSavedToast.
  ///
  /// In zh, this message translates to:
  /// **'配置已保存'**
  String get configSavedToast;

  /// No description provided for @dboAgePreview.
  ///
  /// In zh, this message translates to:
  /// **'最大年龄：{years} 年'**
  String dboAgePreview(String years);

  /// No description provided for @dboApiKeyConfiguredHint.
  ///
  /// In zh, this message translates to:
  /// **'已配置 · 留空则保留'**
  String get dboApiKeyConfiguredHint;

  /// No description provided for @dboBaseUrlExampleHint.
  ///
  /// In zh, this message translates to:
  /// **'例: http://10.0.0.50:9090'**
  String get dboBaseUrlExampleHint;

  /// No description provided for @dboEnabledHelpOff.
  ///
  /// In zh, this message translates to:
  /// **'关闭后将不会使用 DB Online 数据源。'**
  String get dboEnabledHelpOff;

  /// No description provided for @dboEnabledHelpOn.
  ///
  /// In zh, this message translates to:
  /// **'启用后可从 DB Online 获取影片信息。'**
  String get dboEnabledHelpOn;

  /// No description provided for @dboEnabledLabel.
  ///
  /// In zh, this message translates to:
  /// **'启用 DB Online'**
  String get dboEnabledLabel;

  /// No description provided for @dboEnableSwitchLabel.
  ///
  /// In zh, this message translates to:
  /// **'启用 DB Online'**
  String get dboEnableSwitchLabel;

  /// No description provided for @dboErrBothSet.
  ///
  /// In zh, this message translates to:
  /// **'不能同时设置最大年龄和资源月份'**
  String get dboErrBothSet;

  /// No description provided for @dboErrMonthFormat.
  ///
  /// In zh, this message translates to:
  /// **'请输入 YYYY-MM 格式的月份'**
  String get dboErrMonthFormat;

  /// No description provided for @dboFilterLast10Years.
  ///
  /// In zh, this message translates to:
  /// **'近 10 年'**
  String get dboFilterLast10Years;

  /// No description provided for @dboFilterLast2Years.
  ///
  /// In zh, this message translates to:
  /// **'近 2 年'**
  String get dboFilterLast2Years;

  /// No description provided for @dboFilterLast5Years.
  ///
  /// In zh, this message translates to:
  /// **'近 5 年'**
  String get dboFilterLast5Years;

  /// No description provided for @dboFilterLastYear.
  ///
  /// In zh, this message translates to:
  /// **'近 1 年'**
  String get dboFilterLastYear;

  /// No description provided for @dboFilterNoFilter.
  ///
  /// In zh, this message translates to:
  /// **'不过滤'**
  String get dboFilterNoFilter;

  /// No description provided for @dboMonthsUnit.
  ///
  /// In zh, this message translates to:
  /// **'月'**
  String get dboMonthsUnit;

  /// No description provided for @dboNewApiKeyHint.
  ///
  /// In zh, this message translates to:
  /// **'输入新的 API Key'**
  String get dboNewApiKeyHint;

  /// No description provided for @dboResourceFilterHelp.
  ///
  /// In zh, this message translates to:
  /// **'限制可用于匹配的资源类型。'**
  String get dboResourceFilterHelp;

  /// No description provided for @dboResourceFilterLabel.
  ///
  /// In zh, this message translates to:
  /// **'资源过滤器'**
  String get dboResourceFilterLabel;

  /// No description provided for @dboStartMonthHelp.
  ///
  /// In zh, this message translates to:
  /// **'设置从哪个月份开始同步数据。'**
  String get dboStartMonthHelp;

  /// No description provided for @dboStartMonthHint.
  ///
  /// In zh, this message translates to:
  /// **'例如 2024-01'**
  String get dboStartMonthHint;

  /// No description provided for @dboStartMonthLabel.
  ///
  /// In zh, this message translates to:
  /// **'起始年月'**
  String get dboStartMonthLabel;

  /// No description provided for @dboSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'Base URL + API Key,用于影片信息、资源和演员关联同步'**
  String get dboSubtitle;

  /// No description provided for @favoritesEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'收藏影片会显示在这里'**
  String get favoritesEmptyHint;

  /// No description provided for @favoritesEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无收藏'**
  String get favoritesEmptyTitle;

  /// No description provided for @favoritesRemoveAction.
  ///
  /// In zh, this message translates to:
  /// **'移除收藏'**
  String get favoritesRemoveAction;

  /// No description provided for @favoritesRemoveBatchFailed.
  ///
  /// In zh, this message translates to:
  /// **'批量移除收藏失败：{error}'**
  String favoritesRemoveBatchFailed(String error);

  /// No description provided for @favoritesRemoveConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定移除已选的 {count} 部影片吗？'**
  String favoritesRemoveConfirm(int count);

  /// No description provided for @favoritesRemovedN.
  ///
  /// In zh, this message translates to:
  /// **'已移除 {count} 部'**
  String favoritesRemovedN(int count);

  /// No description provided for @favoritesRemovedOne.
  ///
  /// In zh, this message translates to:
  /// **'已移除收藏：{name}'**
  String favoritesRemovedOne(String name);

  /// No description provided for @favoritesRemoveFailed.
  ///
  /// In zh, this message translates to:
  /// **'移除收藏失败：{error}'**
  String favoritesRemoveFailed(String error);

  /// No description provided for @favoritesRemoveTitle.
  ///
  /// In zh, this message translates to:
  /// **'移除收藏'**
  String get favoritesRemoveTitle;

  /// No description provided for @favoritesScanConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定扫描 {count} 部收藏影片吗？'**
  String favoritesScanConfirm(int count);

  /// No description provided for @favoritesScanCreateFailed.
  ///
  /// In zh, this message translates to:
  /// **'创建扫描任务失败：{error}'**
  String favoritesScanCreateFailed(String error);

  /// No description provided for @favoritesScanSkippedSuffix.
  ///
  /// In zh, this message translates to:
  /// **'，跳过 {count} 部无效影片'**
  String favoritesScanSkippedSuffix(int count);

  /// No description provided for @favoritesScanStart.
  ///
  /// In zh, this message translates to:
  /// **'开始扫描'**
  String get favoritesScanStart;

  /// No description provided for @favoritesScanSubmitted.
  ///
  /// In zh, this message translates to:
  /// **'已提交 {count} 个扫描任务'**
  String favoritesScanSubmitted(int count);

  /// No description provided for @favoritesScanTitle.
  ///
  /// In zh, this message translates to:
  /// **'扫描收藏影片'**
  String get favoritesScanTitle;

  /// No description provided for @favoritesScanTooltip.
  ///
  /// In zh, this message translates to:
  /// **'扫描收藏影片'**
  String get favoritesScanTooltip;

  /// No description provided for @favoritesSortRating.
  ///
  /// In zh, this message translates to:
  /// **'按评分排序'**
  String get favoritesSortRating;

  /// No description provided for @favoritesSortRecent.
  ///
  /// In zh, this message translates to:
  /// **'最近收藏'**
  String get favoritesSortRecent;

  /// No description provided for @favoritesSortSheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'收藏排序'**
  String get favoritesSortSheetTitle;

  /// No description provided for @favoritesSortTitle.
  ///
  /// In zh, this message translates to:
  /// **'排序收藏'**
  String get favoritesSortTitle;

  /// No description provided for @favoritesSortYearDesc.
  ///
  /// In zh, this message translates to:
  /// **'年份（从新到旧）'**
  String get favoritesSortYearDesc;

  /// No description provided for @ffmpegAudioSection.
  ///
  /// In zh, this message translates to:
  /// **'音频提取'**
  String get ffmpegAudioSection;

  /// No description provided for @ffmpegAudioThreadsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'每个 FFmpeg 音频编码任务使用的线程数。'**
  String get ffmpegAudioThreadsSubtitle;

  /// No description provided for @ffmpegAudioThreadsTitle.
  ///
  /// In zh, this message translates to:
  /// **'音频提取编码线程数'**
  String get ffmpegAudioThreadsTitle;

  /// No description provided for @ffmpegAudioWorkersSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'同时执行的音频提取任务数量。'**
  String get ffmpegAudioWorkersSubtitle;

  /// No description provided for @ffmpegAudioWorkersTitle.
  ///
  /// In zh, this message translates to:
  /// **'音频提取最大并发任务数'**
  String get ffmpegAudioWorkersTitle;

  /// No description provided for @ffmpegFallbackOff.
  ///
  /// In zh, this message translates to:
  /// **'关闭回退'**
  String get ffmpegFallbackOff;

  /// No description provided for @ffmpegFallbackOn.
  ///
  /// In zh, this message translates to:
  /// **'启用回退'**
  String get ffmpegFallbackOn;

  /// No description provided for @ffmpegFallbackTitle.
  ///
  /// In zh, this message translates to:
  /// **'硬解失败自动回退'**
  String get ffmpegFallbackTitle;

  /// No description provided for @ffmpegHwBackendLabel.
  ///
  /// In zh, this message translates to:
  /// **'硬件后端'**
  String get ffmpegHwBackendLabel;

  /// No description provided for @ffmpegHwEnableTitle.
  ///
  /// In zh, this message translates to:
  /// **'启用硬件解码'**
  String get ffmpegHwEnableTitle;

  /// No description provided for @ffmpegHwNone.
  ///
  /// In zh, this message translates to:
  /// **'不使用硬件加速'**
  String get ffmpegHwNone;

  /// No description provided for @ffmpegHwOff.
  ///
  /// In zh, this message translates to:
  /// **'关闭硬件解码'**
  String get ffmpegHwOff;

  /// No description provided for @ffmpegHwOn.
  ///
  /// In zh, this message translates to:
  /// **'启用硬件解码'**
  String get ffmpegHwOn;

  /// No description provided for @ffmpegHwSection.
  ///
  /// In zh, this message translates to:
  /// **'硬件解码'**
  String get ffmpegHwSection;

  /// No description provided for @ffmpegPathHint.
  ///
  /// In zh, this message translates to:
  /// **'选择 {name} 路径'**
  String ffmpegPathHint(String name);

  /// No description provided for @ffmpegPathsSection.
  ///
  /// In zh, this message translates to:
  /// **'FFmpeg 路径'**
  String get ffmpegPathsSection;

  /// No description provided for @ffmpegSavedToast.
  ///
  /// In zh, this message translates to:
  /// **'FFmpeg 配置已保存'**
  String get ffmpegSavedToast;

  /// No description provided for @ffmpegSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'配置服务端转码、硬件解码和硬解失败回退策略。'**
  String get ffmpegSubtitle;

  /// No description provided for @ffmpegTitle.
  ///
  /// In zh, this message translates to:
  /// **'FFmpeg 与硬解'**
  String get ffmpegTitle;

  /// No description provided for @settingsPreview.
  ///
  /// In zh, this message translates to:
  /// **'预览生成'**
  String get settingsPreview;

  /// No description provided for @settingsPreviewSub.
  ///
  /// In zh, this message translates to:
  /// **'配置预览视频、Sprite 和 VTT 生成'**
  String get settingsPreviewSub;

  /// No description provided for @previewSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'预览生成'**
  String get previewSettingsTitle;

  /// No description provided for @previewSettingsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'配置预览视频、Sprite 和 VTT 的生成策略。'**
  String get previewSettingsSubtitle;

  /// No description provided for @previewAutoGenerate.
  ///
  /// In zh, this message translates to:
  /// **'扫描完成后自动生成'**
  String get previewAutoGenerate;

  /// No description provided for @previewAutoGenerateSub.
  ///
  /// In zh, this message translates to:
  /// **'新影片扫描完成后自动排队生成预览。'**
  String get previewAutoGenerateSub;

  /// No description provided for @previewAudio.
  ///
  /// In zh, this message translates to:
  /// **'保留音频'**
  String get previewAudio;

  /// No description provided for @previewAudioSub.
  ///
  /// In zh, this message translates to:
  /// **'预览视频中包含原视频音频。'**
  String get previewAudioSub;

  /// No description provided for @previewVideoSection.
  ///
  /// In zh, this message translates to:
  /// **'视频片段'**
  String get previewVideoSection;

  /// No description provided for @previewSegments.
  ///
  /// In zh, this message translates to:
  /// **'片段数量'**
  String get previewSegments;

  /// No description provided for @previewSegmentsSub.
  ///
  /// In zh, this message translates to:
  /// **'在视频中抽取的片段数量（1-60）。'**
  String get previewSegmentsSub;

  /// No description provided for @previewSegmentDuration.
  ///
  /// In zh, this message translates to:
  /// **'每段时长（秒）'**
  String get previewSegmentDuration;

  /// No description provided for @previewSegmentDurationSub.
  ///
  /// In zh, this message translates to:
  /// **'每个预览片段的时长，大于 0 且不超过 30 秒。'**
  String get previewSegmentDurationSub;

  /// No description provided for @previewExcludeStart.
  ///
  /// In zh, this message translates to:
  /// **'片头排除比例（%）'**
  String get previewExcludeStart;

  /// No description provided for @previewExcludeEnd.
  ///
  /// In zh, this message translates to:
  /// **'片尾排除比例（%）'**
  String get previewExcludeEnd;

  /// No description provided for @previewExcludeSub.
  ///
  /// In zh, this message translates to:
  /// **'片头和片尾排除比例合计必须小于 100%。'**
  String get previewExcludeSub;

  /// No description provided for @previewEncodingSection.
  ///
  /// In zh, this message translates to:
  /// **'编码'**
  String get previewEncodingSection;

  /// No description provided for @previewPreset.
  ///
  /// In zh, this message translates to:
  /// **'编码速度'**
  String get previewPreset;

  /// No description provided for @previewSpriteSection.
  ///
  /// In zh, this message translates to:
  /// **'Sprite 与 VTT'**
  String get previewSpriteSection;

  /// No description provided for @previewSpriteInterval.
  ///
  /// In zh, this message translates to:
  /// **'Sprite 间隔（秒）'**
  String get previewSpriteInterval;

  /// No description provided for @previewSpriteMinimum.
  ///
  /// In zh, this message translates to:
  /// **'最小帧数'**
  String get previewSpriteMinimum;

  /// No description provided for @previewSpriteMaximum.
  ///
  /// In zh, this message translates to:
  /// **'最大帧数'**
  String get previewSpriteMaximum;

  /// No description provided for @previewSpriteSize.
  ///
  /// In zh, this message translates to:
  /// **'帧尺寸（像素）'**
  String get previewSpriteSize;

  /// No description provided for @previewSavedToast.
  ///
  /// In zh, this message translates to:
  /// **'预览配置已保存'**
  String get previewSavedToast;

  /// No description provided for @previewInvalidValue.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的预览配置。'**
  String get previewInvalidValue;

  /// No description provided for @taskNamePreview.
  ///
  /// In zh, this message translates to:
  /// **'预览生成'**
  String get taskNamePreview;

  /// No description provided for @taskNamePreviewDownload.
  ///
  /// In zh, this message translates to:
  /// **'预览图下载'**
  String get taskNamePreviewDownload;

  /// No description provided for @taskNameDuplicateMerge.
  ///
  /// In zh, this message translates to:
  /// **'重复番号合并'**
  String get taskNameDuplicateMerge;

  /// No description provided for @taskNameIncrementalScan.
  ///
  /// In zh, this message translates to:
  /// **'增量扫描'**
  String get taskNameIncrementalScan;

  /// No description provided for @taskNameFullScan.
  ///
  /// In zh, this message translates to:
  /// **'全量扫描'**
  String get taskNameFullScan;

  /// No description provided for @taskNameScheduledScan.
  ///
  /// In zh, this message translates to:
  /// **'定时增量扫描'**
  String get taskNameScheduledScan;

  /// No description provided for @previewStatusTitle.
  ///
  /// In zh, this message translates to:
  /// **'预览资产'**
  String get previewStatusTitle;

  /// No description provided for @previewSourceReady.
  ///
  /// In zh, this message translates to:
  /// **'源文件可生成'**
  String get previewSourceReady;

  /// No description provided for @previewSourceUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'源文件不支持预览生成'**
  String get previewSourceUnsupported;

  /// No description provided for @previewVideoAsset.
  ///
  /// In zh, this message translates to:
  /// **'预览视频'**
  String get previewVideoAsset;

  /// No description provided for @previewSpriteAsset.
  ///
  /// In zh, this message translates to:
  /// **'Sprite'**
  String get previewSpriteAsset;

  /// No description provided for @previewVttAsset.
  ///
  /// In zh, this message translates to:
  /// **'VTT'**
  String get previewVttAsset;

  /// No description provided for @previewReady.
  ///
  /// In zh, this message translates to:
  /// **'已就绪'**
  String get previewReady;

  /// No description provided for @previewNotReady.
  ///
  /// In zh, this message translates to:
  /// **'未生成'**
  String get previewNotReady;

  /// No description provided for @previewGenerate.
  ///
  /// In zh, this message translates to:
  /// **'生成预览'**
  String get previewGenerate;

  /// No description provided for @previewGenerating.
  ///
  /// In zh, this message translates to:
  /// **'正在生成预览…'**
  String get previewGenerating;

  /// No description provided for @previewQueued.
  ///
  /// In zh, this message translates to:
  /// **'已排队'**
  String get previewQueued;

  /// No description provided for @previewCompleted.
  ///
  /// In zh, this message translates to:
  /// **'预览生成完成'**
  String get previewCompleted;

  /// No description provided for @previewFailed.
  ///
  /// In zh, this message translates to:
  /// **'预览生成失败'**
  String get previewFailed;

  /// No description provided for @previewCancelled.
  ///
  /// In zh, this message translates to:
  /// **'预览生成已取消'**
  String get previewCancelled;

  /// No description provided for @libraryBatchAccepted.
  ///
  /// In zh, this message translates to:
  /// **'已提交 {count} 个媒体库的{scanType}'**
  String libraryBatchAccepted(int count, String scanType);

  /// No description provided for @libraryBatchFailedShort.
  ///
  /// In zh, this message translates to:
  /// **' · {count} 个提交失败'**
  String libraryBatchFailedShort(int count);

  /// No description provided for @libraryBatchNoEnabled.
  ///
  /// In zh, this message translates to:
  /// **'没有启用的媒体库'**
  String get libraryBatchNoEnabled;

  /// No description provided for @libraryBatchNoTasks.
  ///
  /// In zh, this message translates to:
  /// **'没有可提交的{scanType}任务'**
  String libraryBatchNoTasks(String scanType);

  /// No description provided for @libraryBatchReused.
  ///
  /// In zh, this message translates to:
  /// **' · {count} 个复用现有任务'**
  String libraryBatchReused(int count);

  /// No description provided for @libraryBatchScanFailed.
  ///
  /// In zh, this message translates to:
  /// **'批量扫描失败：{error}'**
  String libraryBatchScanFailed(String error);

  /// No description provided for @libraryBatchScanFull.
  ///
  /// In zh, this message translates to:
  /// **'批量全量扫描'**
  String get libraryBatchScanFull;

  /// No description provided for @libraryBatchScanIncremental.
  ///
  /// In zh, this message translates to:
  /// **'一键增量扫描'**
  String get libraryBatchScanIncremental;

  /// No description provided for @libraryBatchScanTitle.
  ///
  /// In zh, this message translates to:
  /// **'批量扫描（仅启用媒体库）'**
  String get libraryBatchScanTitle;

  /// No description provided for @libraryBatchSkippedDisabled.
  ///
  /// In zh, this message translates to:
  /// **' · 已忽略 {count} 个停用媒体库'**
  String libraryBatchSkippedDisabled(int count);

  /// No description provided for @libraryBatchSubmitFailedCount.
  ///
  /// In zh, this message translates to:
  /// **'，{count} 个媒体库提交失败'**
  String libraryBatchSubmitFailedCount(int count);

  /// No description provided for @libraryCardMeta.
  ///
  /// In zh, this message translates to:
  /// **'{files} 个文件 · {directories} 个目录'**
  String libraryCardMeta(int files, int directories);

  /// No description provided for @libraryCreatedToast.
  ///
  /// In zh, this message translates to:
  /// **'媒体库已创建'**
  String get libraryCreatedToast;

  /// No description provided for @libraryDefaultDirName.
  ///
  /// In zh, this message translates to:
  /// **'目录 {index}'**
  String libraryDefaultDirName(int index);

  /// No description provided for @libraryDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除媒体库“{name}”吗？'**
  String libraryDeleteConfirm(String name);

  /// No description provided for @libraryDeletedToast.
  ///
  /// In zh, this message translates to:
  /// **'媒体库已删除'**
  String get libraryDeletedToast;

  /// No description provided for @libraryDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除媒体库失败：{error}'**
  String libraryDeleteFailed(String error);

  /// No description provided for @libraryDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除媒体库'**
  String get libraryDeleteTitle;

  /// No description provided for @libraryDisable.
  ///
  /// In zh, this message translates to:
  /// **'停用'**
  String get libraryDisable;

  /// No description provided for @libraryDisabledBadge.
  ///
  /// In zh, this message translates to:
  /// **'已禁用'**
  String get libraryDisabledBadge;

  /// No description provided for @libraryDisabledToast.
  ///
  /// In zh, this message translates to:
  /// **'媒体库已禁用'**
  String get libraryDisabledToast;

  /// No description provided for @libraryEditorAddDir.
  ///
  /// In zh, this message translates to:
  /// **'添加目录'**
  String get libraryEditorAddDir;

  /// No description provided for @libraryEditorEnableHint.
  ///
  /// In zh, this message translates to:
  /// **'停用媒体库后不会参与扫描和展示。'**
  String get libraryEditorEnableHint;

  /// No description provided for @libraryEditorNameHint.
  ///
  /// In zh, this message translates to:
  /// **'例: 我的电影'**
  String get libraryEditorNameHint;

  /// No description provided for @libraryEditorTitleEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑媒体库'**
  String get libraryEditorTitleEdit;

  /// No description provided for @libraryEditorTitleNew.
  ///
  /// In zh, this message translates to:
  /// **'新建媒体库'**
  String get libraryEditorTitleNew;

  /// No description provided for @libraryEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'创建媒体库后开始扫描媒体'**
  String get libraryEmptyHint;

  /// No description provided for @libraryEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无媒体库'**
  String get libraryEmptyTitle;

  /// No description provided for @libraryEnable.
  ///
  /// In zh, this message translates to:
  /// **'启用'**
  String get libraryEnable;

  /// No description provided for @libraryEnabledToast.
  ///
  /// In zh, this message translates to:
  /// **'媒体库已启用'**
  String get libraryEnabledToast;

  /// No description provided for @libraryErrDirDuplicate.
  ///
  /// In zh, this message translates to:
  /// **'目录路径重复: {path}'**
  String libraryErrDirDuplicate(String path);

  /// No description provided for @libraryErrDirRequired.
  ///
  /// In zh, this message translates to:
  /// **'至少需要一个目录'**
  String get libraryErrDirRequired;

  /// No description provided for @libraryErrNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写媒体库名称'**
  String get libraryErrNameRequired;

  /// No description provided for @libraryErrNotDirectory.
  ///
  /// In zh, this message translates to:
  /// **'不是目录：{path}'**
  String libraryErrNotDirectory(String path);

  /// No description provided for @libraryErrPathNotFound.
  ///
  /// In zh, this message translates to:
  /// **'路径不存在：{path}'**
  String libraryErrPathNotFound(String path);

  /// No description provided for @libraryErrPathUsed.
  ///
  /// In zh, this message translates to:
  /// **'路径已被使用：{path}'**
  String libraryErrPathUsed(String path);

  /// No description provided for @libraryManageTitle.
  ///
  /// In zh, this message translates to:
  /// **'管理媒体库'**
  String get libraryManageTitle;

  /// No description provided for @libraryMoviesEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无影片'**
  String get libraryMoviesEmpty;

  /// No description provided for @libraryScan.
  ///
  /// In zh, this message translates to:
  /// **'扫描'**
  String get libraryScan;

  /// No description provided for @libraryScanFailed.
  ///
  /// In zh, this message translates to:
  /// **'扫描失败：{error}'**
  String libraryScanFailed(String error);

  /// No description provided for @libraryScanFull.
  ///
  /// In zh, this message translates to:
  /// **'全量扫描'**
  String get libraryScanFull;

  /// No description provided for @libraryScanFullStarted.
  ///
  /// In zh, this message translates to:
  /// **'已开始全量扫描'**
  String get libraryScanFullStarted;

  /// No description provided for @libraryScanIncremental.
  ///
  /// In zh, this message translates to:
  /// **'增量扫描'**
  String get libraryScanIncremental;

  /// No description provided for @libraryScanIncrementalStarted.
  ///
  /// In zh, this message translates to:
  /// **'已开始增量扫描'**
  String get libraryScanIncrementalStarted;

  /// No description provided for @libraryScanSheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'扫描媒体库：{name}'**
  String libraryScanSheetTitle(String name);

  /// No description provided for @librarySubmitting.
  ///
  /// In zh, this message translates to:
  /// **'提交中'**
  String get librarySubmitting;

  /// No description provided for @listActionsTitle.
  ///
  /// In zh, this message translates to:
  /// **'操作'**
  String get listActionsTitle;

  /// No description provided for @listAddToTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加到列表'**
  String get listAddToTitle;

  /// No description provided for @listCreate.
  ///
  /// In zh, this message translates to:
  /// **'创建列表'**
  String get listCreate;

  /// No description provided for @listDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除列表'**
  String get listDelete;

  /// No description provided for @listDeleteConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'确定删除此列表吗？'**
  String get listDeleteConfirmBody;

  /// No description provided for @listEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'创建列表来整理收藏内容'**
  String get listEmptyHint;

  /// No description provided for @listEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无列表'**
  String get listEmptyTitle;

  /// No description provided for @listHeroCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 部影片'**
  String listHeroCount(int count);

  /// No description provided for @listHeroEyebrow.
  ///
  /// In zh, this message translates to:
  /// **'影片列表'**
  String get listHeroEyebrow;

  /// No description provided for @listMissing.
  ///
  /// In zh, this message translates to:
  /// **'列表不存在'**
  String get listMissing;

  /// No description provided for @listNameHint.
  ///
  /// In zh, this message translates to:
  /// **'列表名称'**
  String get listNameHint;

  /// No description provided for @listRemoveConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定从列表中移除“{name}”吗？'**
  String listRemoveConfirm(String name);

  /// No description provided for @listRemoveTitle.
  ///
  /// In zh, this message translates to:
  /// **'从列表移除'**
  String get listRemoveTitle;

  /// No description provided for @listRename.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get listRename;

  /// No description provided for @listRenameTitle.
  ///
  /// In zh, this message translates to:
  /// **'重命名列表'**
  String get listRenameTitle;

  /// No description provided for @mappingBadgeConvert.
  ///
  /// In zh, this message translates to:
  /// **'转换映射'**
  String get mappingBadgeConvert;

  /// No description provided for @mappingBatchDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除已选的 {count} 条映射吗？'**
  String mappingBatchDeleteConfirm(int count);

  /// No description provided for @mappingBatchDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除 {count} 条映射'**
  String mappingBatchDeleted(int count);

  /// No description provided for @mappingBatchDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'批量删除映射失败：{error}'**
  String mappingBatchDeleteFailed(String error);

  /// No description provided for @mappingBatchDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'批量删除映射'**
  String get mappingBatchDeleteTitle;

  /// No description provided for @mappingCountSuffix.
  ///
  /// In zh, this message translates to:
  /// **'条映射'**
  String get mappingCountSuffix;

  /// No description provided for @mappingCreatedToast.
  ///
  /// In zh, this message translates to:
  /// **'映射已创建'**
  String get mappingCreatedToast;

  /// No description provided for @mappingDeletedToast.
  ///
  /// In zh, this message translates to:
  /// **'映射已删除'**
  String get mappingDeletedToast;

  /// No description provided for @mappingDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除映射失败：{error}'**
  String mappingDeleteFailed(String error);

  /// No description provided for @mappingDeleteRuleConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除映射“{name}”吗？'**
  String mappingDeleteRuleConfirm(String name);

  /// No description provided for @mappingDeleteRuleTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除映射规则'**
  String get mappingDeleteRuleTitle;

  /// No description provided for @mappingEditorTitleEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑{type}映射'**
  String mappingEditorTitleEdit(String type);

  /// No description provided for @mappingEditorTitleNew.
  ///
  /// In zh, this message translates to:
  /// **'新建{type}映射'**
  String mappingEditorTitleNew(String type);

  /// No description provided for @mappingEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'还没有映射规则'**
  String get mappingEmptyHint;

  /// No description provided for @mappingEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无{type}映射'**
  String mappingEmptyTitle(String type);

  /// No description provided for @mappingFilterConvert.
  ///
  /// In zh, this message translates to:
  /// **'转换规则'**
  String get mappingFilterConvert;

  /// No description provided for @mappingFilterDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除规则'**
  String get mappingFilterDelete;

  /// No description provided for @mappingMappedDeleteHint.
  ///
  /// In zh, this message translates to:
  /// **'删除映射后的值'**
  String get mappingMappedDeleteHint;

  /// No description provided for @mappingMappedHint.
  ///
  /// In zh, this message translates to:
  /// **'输入映射后的值'**
  String get mappingMappedHint;

  /// No description provided for @mappingMappedPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'请输入映射后的值'**
  String get mappingMappedPlaceholder;

  /// No description provided for @mappingMappedValueEyebrow.
  ///
  /// In zh, this message translates to:
  /// **'映射后值'**
  String get mappingMappedValueEyebrow;

  /// No description provided for @mappingOriginalMultiHint.
  ///
  /// In zh, this message translates to:
  /// **'可填写多个原始值，每行一个'**
  String get mappingOriginalMultiHint;

  /// No description provided for @mappingOriginalMultiPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'输入多个原始值'**
  String get mappingOriginalMultiPlaceholder;

  /// No description provided for @mappingOriginalPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'输入原始值'**
  String get mappingOriginalPlaceholder;

  /// No description provided for @mappingOriginalSingleHint.
  ///
  /// In zh, this message translates to:
  /// **'填写需要替换的原始值'**
  String get mappingOriginalSingleHint;

  /// No description provided for @mappingOriginalValuesEyebrow.
  ///
  /// In zh, this message translates to:
  /// **'原始值'**
  String get mappingOriginalValuesEyebrow;

  /// No description provided for @mappingSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索映射规则'**
  String get mappingSearchHint;

  /// No description provided for @mappingSummaryDiscard.
  ///
  /// In zh, this message translates to:
  /// **'放弃更改'**
  String get mappingSummaryDiscard;

  /// No description provided for @mappingTypeTitle.
  ///
  /// In zh, this message translates to:
  /// **'{type}映射'**
  String mappingTypeTitle(String type);

  /// No description provided for @mediaBrowserContainer.
  ///
  /// In zh, this message translates to:
  /// **'容器'**
  String get mediaBrowserContainer;

  /// No description provided for @mediaBrowserDetails.
  ///
  /// In zh, this message translates to:
  /// **'详情'**
  String get mediaBrowserDetails;

  /// No description provided for @mediaBrowserDirectors.
  ///
  /// In zh, this message translates to:
  /// **'导演'**
  String get mediaBrowserDirectors;

  /// No description provided for @mediaBrowserEpisodeNumber.
  ///
  /// In zh, this message translates to:
  /// **'第 {number} 集'**
  String mediaBrowserEpisodeNumber(int number);

  /// No description provided for @mediaBrowserEpisodes.
  ///
  /// In zh, this message translates to:
  /// **'集数'**
  String get mediaBrowserEpisodes;

  /// No description provided for @mediaBrowserEpisodeWithRuntime.
  ///
  /// In zh, this message translates to:
  /// **'第 {number} 集 · {minutes} 分钟'**
  String mediaBrowserEpisodeWithRuntime(int number, int minutes);

  /// No description provided for @mediaBrowserFilePath.
  ///
  /// In zh, this message translates to:
  /// **'文件路径'**
  String get mediaBrowserFilePath;

  /// No description provided for @mediaBrowserFileSize.
  ///
  /// In zh, this message translates to:
  /// **'文件大小'**
  String get mediaBrowserFileSize;

  /// No description provided for @mediaBrowserGenres.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get mediaBrowserGenres;

  /// No description provided for @mediaBrowserMediaInfo.
  ///
  /// In zh, this message translates to:
  /// **'媒体信息'**
  String get mediaBrowserMediaInfo;

  /// No description provided for @mediaBrowserMediaSources.
  ///
  /// In zh, this message translates to:
  /// **'片源'**
  String get mediaBrowserMediaSources;

  /// No description provided for @mediaBrowserMediaSourceNumber.
  ///
  /// In zh, this message translates to:
  /// **'片源 {number}'**
  String mediaBrowserMediaSourceNumber(int number);

  /// No description provided for @mediaBrowserVideoParts.
  ///
  /// In zh, this message translates to:
  /// **'分集'**
  String get mediaBrowserVideoParts;

  /// No description provided for @mediaBrowserPlayAllParts.
  ///
  /// In zh, this message translates to:
  /// **'连续播放全部分集'**
  String get mediaBrowserPlayAllParts;

  /// No description provided for @mediaBrowserVideoPartNumber.
  ///
  /// In zh, this message translates to:
  /// **'第 {number} 分集'**
  String mediaBrowserVideoPartNumber(int number);

  /// No description provided for @mediaBrowserNextUp.
  ///
  /// In zh, this message translates to:
  /// **'接下来播放'**
  String get mediaBrowserNextUp;

  /// No description provided for @mediaBrowserNoEpisodesInSeason.
  ///
  /// In zh, this message translates to:
  /// **'本季暂无剧集'**
  String get mediaBrowserNoEpisodesInSeason;

  /// No description provided for @mediaBrowserNoSeasons.
  ///
  /// In zh, this message translates to:
  /// **'暂无季'**
  String get mediaBrowserNoSeasons;

  /// No description provided for @mediaBrowserOriginalTitle.
  ///
  /// In zh, this message translates to:
  /// **'原名'**
  String get mediaBrowserOriginalTitle;

  /// No description provided for @mediaBrowserSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索电影、剧集、音乐…'**
  String get mediaBrowserSearchHint;

  /// No description provided for @mediaBrowserSeasonNumber.
  ///
  /// In zh, this message translates to:
  /// **'第 {number} 季'**
  String mediaBrowserSeasonNumber(int number);

  /// No description provided for @mediaBrowserSeriesLabel.
  ///
  /// In zh, this message translates to:
  /// **'所属剧集'**
  String get mediaBrowserSeriesLabel;

  /// No description provided for @mediaBrowserSpecialSeason.
  ///
  /// In zh, this message translates to:
  /// **'特别篇'**
  String get mediaBrowserSpecialSeason;

  /// No description provided for @mediaBrowserTranscodePlay.
  ///
  /// In zh, this message translates to:
  /// **'转码播放'**
  String get mediaBrowserTranscodePlay;

  /// No description provided for @mediaBrowserTypeBooks.
  ///
  /// In zh, this message translates to:
  /// **'书籍'**
  String get mediaBrowserTypeBooks;

  /// No description provided for @mediaBrowserTypeHomeVideos.
  ///
  /// In zh, this message translates to:
  /// **'家庭视频'**
  String get mediaBrowserTypeHomeVideos;

  /// No description provided for @mediaBrowserTypePhotos.
  ///
  /// In zh, this message translates to:
  /// **'照片'**
  String get mediaBrowserTypePhotos;

  /// No description provided for @mediaBrowserTypeUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知类型'**
  String get mediaBrowserTypeUnknown;

  /// No description provided for @mediaBrowserTypeUnknownWithValue.
  ///
  /// In zh, this message translates to:
  /// **'未知类型（{value}）'**
  String mediaBrowserTypeUnknownWithValue(String value);

  /// No description provided for @mediaBrowserNow.
  ///
  /// In zh, this message translates to:
  /// **'现在'**
  String get mediaBrowserNow;

  /// No description provided for @mediaBrowserEpisodeCount.
  ///
  /// In zh, this message translates to:
  /// **'{count}集'**
  String mediaBrowserEpisodeCount(int count);

  /// No description provided for @mediaBrowserTrackCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 首'**
  String mediaBrowserTrackCount(int count);

  /// No description provided for @mediaDurationMinutes.
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分钟'**
  String mediaDurationMinutes(int minutes);

  /// No description provided for @mediaBrowserEmptyDefault.
  ///
  /// In zh, this message translates to:
  /// **'暂无内容'**
  String get mediaBrowserEmptyDefault;

  /// No description provided for @mediaBrowserUpdatedNItems.
  ///
  /// In zh, this message translates to:
  /// **'已更新 {count} 个条目'**
  String mediaBrowserUpdatedNItems(int count);

  /// No description provided for @mediaBrowserUpdatedNItemsWithFailed.
  ///
  /// In zh, this message translates to:
  /// **'已更新 {count} 个条目，{failed} 个失败'**
  String mediaBrowserUpdatedNItemsWithFailed(int count, int failed);

  /// No description provided for @mediaBrowserWatched.
  ///
  /// In zh, this message translates to:
  /// **'已看'**
  String get mediaBrowserWatched;

  /// No description provided for @operationFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作失败：{error}'**
  String operationFailed(String error);

  /// No description provided for @playerAudioNowPlaying.
  ///
  /// In zh, this message translates to:
  /// **'正在播放'**
  String get playerAudioNowPlaying;

  /// No description provided for @playerAudioPlaybackFailed.
  ///
  /// In zh, this message translates to:
  /// **'音频播放失败'**
  String get playerAudioPlaybackFailed;

  /// No description provided for @playerDebugAudioBitrate.
  ///
  /// In zh, this message translates to:
  /// **'音频码率：{value}'**
  String playerDebugAudioBitrate(String value);

  /// No description provided for @playerDebugAudioCodec.
  ///
  /// In zh, this message translates to:
  /// **'音频编码：{value}'**
  String playerDebugAudioCodec(String value);

  /// No description provided for @playerDebugContainer.
  ///
  /// In zh, this message translates to:
  /// **'容器：{value}'**
  String playerDebugContainer(String value);

  /// No description provided for @playerDebugDecoder.
  ///
  /// In zh, this message translates to:
  /// **'解码器：{value}'**
  String playerDebugDecoder(String value);

  /// No description provided for @playerDebugEngine.
  ///
  /// In zh, this message translates to:
  /// **'播放器内核：{value}'**
  String playerDebugEngine(String value);

  /// No description provided for @playerDebugFps.
  ///
  /// In zh, this message translates to:
  /// **'帧率：{value}'**
  String playerDebugFps(String value);

  /// No description provided for @playerDebugInternalPlayer.
  ///
  /// In zh, this message translates to:
  /// **'内部播放器：{value}'**
  String playerDebugInternalPlayer(String value);

  /// No description provided for @playerDebugResolution.
  ///
  /// In zh, this message translates to:
  /// **'分辨率：{value}'**
  String playerDebugResolution(String value);

  /// No description provided for @playerDebugVideoBitrate.
  ///
  /// In zh, this message translates to:
  /// **'视频码率：{value}'**
  String playerDebugVideoBitrate(String value);

  /// No description provided for @playerDebugVideoCodec.
  ///
  /// In zh, this message translates to:
  /// **'视频编码：{value}'**
  String playerDebugVideoCodec(String value);

  /// No description provided for @playerDecisionMissing.
  ///
  /// In zh, this message translates to:
  /// **'播放决策缺少 direct_url'**
  String get playerDecisionMissing;

  /// No description provided for @playerDecodeLocalHardware.
  ///
  /// In zh, this message translates to:
  /// **'本地硬解'**
  String get playerDecodeLocalHardware;

  /// No description provided for @playerDecodeLocalSoftware.
  ///
  /// In zh, this message translates to:
  /// **'本地软解'**
  String get playerDecodeLocalSoftware;

  /// No description provided for @playerDecodeServerHardware.
  ///
  /// In zh, this message translates to:
  /// **'服务端硬解'**
  String get playerDecodeServerHardware;

  /// No description provided for @playerDecodeServerSoftware.
  ///
  /// In zh, this message translates to:
  /// **'服务端软解'**
  String get playerDecodeServerSoftware;

  /// No description provided for @playerDecodeServerSoftwareFallback.
  ///
  /// In zh, this message translates to:
  /// **'服务端软解回退'**
  String get playerDecodeServerSoftwareFallback;

  /// No description provided for @playerEngineAudio.
  ///
  /// In zh, this message translates to:
  /// **'音频播放内核'**
  String get playerEngineAudio;

  /// No description provided for @playerErrorCopied.
  ///
  /// In zh, this message translates to:
  /// **'播放器错误已复制'**
  String get playerErrorCopied;

  /// No description provided for @playerErrorCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get playerErrorCopy;

  /// No description provided for @playerErrorCopyFailed.
  ///
  /// In zh, this message translates to:
  /// **'复制失败'**
  String get playerErrorCopyFailed;

  /// No description provided for @playerErrorCopyFull.
  ///
  /// In zh, this message translates to:
  /// **'复制完整错误信息'**
  String get playerErrorCopyFull;

  /// No description provided for @playerErrorDetailsTitle.
  ///
  /// In zh, this message translates to:
  /// **'完整错误详情'**
  String get playerErrorDetailsTitle;

  /// No description provided for @playerErrorExport.
  ///
  /// In zh, this message translates to:
  /// **'导出'**
  String get playerErrorExport;

  /// No description provided for @playerErrorExportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出播放错误失败，可尝试复制完整错误'**
  String get playerErrorExportFailed;

  /// No description provided for @playerErrorExportFull.
  ///
  /// In zh, this message translates to:
  /// **'导出完整错误信息'**
  String get playerErrorExportFull;

  /// No description provided for @playerErrorExportUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前设备不支持导出，请复制完整错误'**
  String get playerErrorExportUnsupported;

  /// No description provided for @playerErrorShareBody.
  ///
  /// In zh, this message translates to:
  /// **'Oh My Media 播放错误日志'**
  String get playerErrorShareBody;

  /// No description provided for @playerErrorShareSubject.
  ///
  /// In zh, this message translates to:
  /// **'Oh My Media 播放错误'**
  String get playerErrorShareSubject;

  /// No description provided for @playerErrorTitle.
  ///
  /// In zh, this message translates to:
  /// **'播放失败'**
  String get playerErrorTitle;

  /// No description provided for @playerErrorViewDetails.
  ///
  /// In zh, this message translates to:
  /// **'查看详情'**
  String get playerErrorViewDetails;

  /// No description provided for @playerExit.
  ///
  /// In zh, this message translates to:
  /// **'退出播放器'**
  String get playerExit;

  /// No description provided for @playerExitPlayback.
  ///
  /// In zh, this message translates to:
  /// **'退出播放'**
  String get playerExitPlayback;

  /// No description provided for @playerFramePreviewUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'当前无法预览画面'**
  String get playerFramePreviewUnavailable;

  /// No description provided for @playerLoadingVideo.
  ///
  /// In zh, this message translates to:
  /// **'正在加载视频'**
  String get playerLoadingVideo;

  /// No description provided for @playerNetworkCellular.
  ///
  /// In zh, this message translates to:
  /// **'蜂窝网络'**
  String get playerNetworkCellular;

  /// No description provided for @playerNetworkEthernet.
  ///
  /// In zh, this message translates to:
  /// **'以太网'**
  String get playerNetworkEthernet;

  /// No description provided for @playerNetworkOffline.
  ///
  /// In zh, this message translates to:
  /// **'离线'**
  String get playerNetworkOffline;

  /// No description provided for @playerNetworkUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知网络'**
  String get playerNetworkUnknown;

  /// No description provided for @playerNextMedia.
  ///
  /// In zh, this message translates to:
  /// **'下一个媒体'**
  String get playerNextMedia;

  /// No description provided for @playerNextTrack.
  ///
  /// In zh, this message translates to:
  /// **'下一曲'**
  String get playerNextTrack;

  /// No description provided for @playerPictureInPicture.
  ///
  /// In zh, this message translates to:
  /// **'画中画'**
  String get playerPictureInPicture;

  /// No description provided for @playerPipEngineUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前播放内核不支持画中画'**
  String get playerPipEngineUnsupported;

  /// No description provided for @playerPipSourceUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前媒体源不支持画中画'**
  String get playerPipSourceUnsupported;

  /// No description provided for @playerPipStartFailed.
  ///
  /// In zh, this message translates to:
  /// **'启动画中画失败'**
  String get playerPipStartFailed;

  /// No description provided for @playerPlaybackSpeed.
  ///
  /// In zh, this message translates to:
  /// **'播放速度：{rate}'**
  String playerPlaybackSpeed(String rate);

  /// No description provided for @playerPreviousMedia.
  ///
  /// In zh, this message translates to:
  /// **'上一个媒体'**
  String get playerPreviousMedia;

  /// No description provided for @playerPreviousTrack.
  ///
  /// In zh, this message translates to:
  /// **'上一曲'**
  String get playerPreviousTrack;

  /// No description provided for @playerQualityAuto.
  ///
  /// In zh, this message translates to:
  /// **'自动'**
  String get playerQualityAuto;

  /// No description provided for @playerSeekBack10Seconds.
  ///
  /// In zh, this message translates to:
  /// **'快退 10 秒'**
  String get playerSeekBack10Seconds;

  /// No description provided for @playerSeekForward10Seconds.
  ///
  /// In zh, this message translates to:
  /// **'快进 10 秒'**
  String get playerSeekForward10Seconds;

  /// No description provided for @playerSelectAudioTrack.
  ///
  /// In zh, this message translates to:
  /// **'选择音频轨道'**
  String get playerSelectAudioTrack;

  /// No description provided for @playerSelectQuality.
  ///
  /// In zh, this message translates to:
  /// **'选择画质'**
  String get playerSelectQuality;

  /// No description provided for @playerSelectSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择字幕'**
  String get playerSelectSubtitle;

  /// No description provided for @playerSliderPosition.
  ///
  /// In zh, this message translates to:
  /// **'播放位置：{position}'**
  String playerSliderPosition(String position);

  /// No description provided for @playerSliderPositionBuffered.
  ///
  /// In zh, this message translates to:
  /// **'播放位置：{position}，已缓冲至 {buffered}'**
  String playerSliderPositionBuffered(String position, String buffered);

  /// No description provided for @playerSpeedActive.
  ///
  /// In zh, this message translates to:
  /// **'速度 {rate}'**
  String playerSpeedActive(String rate);

  /// No description provided for @playerSubtitleLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'字幕加载失败：{error}'**
  String playerSubtitleLoadFailed(String error);

  /// No description provided for @playerSubtitleLoadFailedContinue.
  ///
  /// In zh, this message translates to:
  /// **'字幕加载失败，继续播放：{error}'**
  String playerSubtitleLoadFailedContinue(String error);

  /// No description provided for @playerSubtitleName.
  ///
  /// In zh, this message translates to:
  /// **'字幕名称'**
  String get playerSubtitleName;

  /// No description provided for @playerSubtitleOff.
  ///
  /// In zh, this message translates to:
  /// **'关闭字幕'**
  String get playerSubtitleOff;

  /// No description provided for @playerSwitchToLandscape.
  ///
  /// In zh, this message translates to:
  /// **'切换为横屏'**
  String get playerSwitchToLandscape;

  /// No description provided for @playerSwitchToPortrait.
  ///
  /// In zh, this message translates to:
  /// **'切换为竖屏'**
  String get playerSwitchToPortrait;

  /// No description provided for @scanActionFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作失败'**
  String get scanActionFailed;

  /// No description provided for @scanBackgroundButton.
  ///
  /// In zh, this message translates to:
  /// **'后台'**
  String get scanBackgroundButton;

  /// No description provided for @scanCancelFailed.
  ///
  /// In zh, this message translates to:
  /// **'取消失败'**
  String get scanCancelFailed;

  /// No description provided for @scanClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get scanClose;

  /// No description provided for @scanCurrentEyebrow.
  ///
  /// In zh, this message translates to:
  /// **'当前扫描'**
  String get scanCurrentEyebrow;

  /// No description provided for @scanDoneClose.
  ///
  /// In zh, this message translates to:
  /// **'完成并关闭'**
  String get scanDoneClose;

  /// No description provided for @scanFailedClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭并返回'**
  String get scanFailedClose;

  /// No description provided for @scanPause.
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get scanPause;

  /// No description provided for @scanPauseFailed.
  ///
  /// In zh, this message translates to:
  /// **'暂停失败'**
  String get scanPauseFailed;

  /// No description provided for @scanPreparing.
  ///
  /// In zh, this message translates to:
  /// **'准备中'**
  String get scanPreparing;

  /// No description provided for @scanProgressTitle.
  ///
  /// In zh, this message translates to:
  /// **'扫描进度'**
  String get scanProgressTitle;

  /// No description provided for @scanResume.
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get scanResume;

  /// No description provided for @scanResumeFailed.
  ///
  /// In zh, this message translates to:
  /// **'恢复失败'**
  String get scanResumeFailed;

  /// No description provided for @scanStatAdded.
  ///
  /// In zh, this message translates to:
  /// **'新增'**
  String get scanStatAdded;

  /// No description provided for @scanStatRemoved.
  ///
  /// In zh, this message translates to:
  /// **'已移除'**
  String get scanStatRemoved;

  /// No description provided for @scanStatUpdated.
  ///
  /// In zh, this message translates to:
  /// **'更新'**
  String get scanStatUpdated;

  /// No description provided for @securityAppPassword.
  ///
  /// In zh, this message translates to:
  /// **'进入密码'**
  String get securityAppPassword;

  /// No description provided for @securityBiometricDisabled.
  ///
  /// In zh, this message translates to:
  /// **'生物识别已禁用'**
  String get securityBiometricDisabled;

  /// No description provided for @securityBiometricNeedsPin.
  ///
  /// In zh, this message translates to:
  /// **'请先设置数字密码'**
  String get securityBiometricNeedsPin;

  /// No description provided for @securityBiometricOnDesc.
  ///
  /// In zh, this message translates to:
  /// **'使用生物识别解锁应用'**
  String get securityBiometricOnDesc;

  /// No description provided for @securityBiometricUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'当前设备不支持生物识别'**
  String get securityBiometricUnavailable;

  /// No description provided for @securityBiometricUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'生物识别更新失败：{error}'**
  String securityBiometricUpdateFailed(String error);

  /// No description provided for @securityClearConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'清除安全设置后，将无法使用已配置的本地验证方式。'**
  String get securityClearConfirmBody;

  /// No description provided for @securityClearFailed.
  ///
  /// In zh, this message translates to:
  /// **'清理安全设置失败：{error}'**
  String securityClearFailed(String error);

  /// No description provided for @securityClearGesture.
  ///
  /// In zh, this message translates to:
  /// **'清除手势密码'**
  String get securityClearGesture;

  /// No description provided for @securityClearPinRequiresBiometricDisabled.
  ///
  /// In zh, this message translates to:
  /// **'请先关闭生物识别，再清除进入密码'**
  String get securityClearPinRequiresBiometricDisabled;

  /// No description provided for @securityClearPin.
  ///
  /// In zh, this message translates to:
  /// **'清除数字密码'**
  String get securityClearPin;

  /// No description provided for @securityGestureMin.
  ///
  /// In zh, this message translates to:
  /// **'手势密码至少需要 4 个点'**
  String get securityGestureMin;

  /// No description provided for @securityGesturePassword.
  ///
  /// In zh, this message translates to:
  /// **'手势密码'**
  String get securityGesturePassword;

  /// No description provided for @securityGestureSaved.
  ///
  /// In zh, this message translates to:
  /// **'手势密码已保存'**
  String get securityGestureSaved;

  /// No description provided for @securityGestureSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存手势密码失败：{error}'**
  String securityGestureSaveFailed(String error);

  /// No description provided for @securityGestureSet.
  ///
  /// In zh, this message translates to:
  /// **'手势密码已设置'**
  String get securityGestureSet;

  /// No description provided for @securityLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载安全设置失败：{error}'**
  String securityLoadFailed(String error);

  /// No description provided for @securityLockVerifyDesc.
  ///
  /// In zh, this message translates to:
  /// **'配置任意一种方式后，应用启动和回到前台时会要求验证。'**
  String get securityLockVerifyDesc;

  /// No description provided for @securityLockVerifyTitle.
  ///
  /// In zh, this message translates to:
  /// **'应用锁定时验证'**
  String get securityLockVerifyTitle;

  /// No description provided for @securityNotSet.
  ///
  /// In zh, this message translates to:
  /// **'未设置'**
  String get securityNotSet;

  /// No description provided for @securityPatternEnterAgain.
  ///
  /// In zh, this message translates to:
  /// **'请再次绘制手势密码'**
  String get securityPatternEnterAgain;

  /// No description provided for @securityPatternEnterFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先绘制手势密码'**
  String get securityPatternEnterFirst;

  /// No description provided for @securityPatternMismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次绘制的手势密码不一致'**
  String get securityPatternMismatch;

  /// No description provided for @securityPatternTooFew.
  ///
  /// In zh, this message translates to:
  /// **'手势密码至少需要 4 个点'**
  String get securityPatternTooFew;

  /// No description provided for @securityPinEnterAgain.
  ///
  /// In zh, this message translates to:
  /// **'请再次输入数字密码'**
  String get securityPinEnterAgain;

  /// No description provided for @securityPinEnterFirst.
  ///
  /// In zh, this message translates to:
  /// **'请输入数字密码'**
  String get securityPinEnterFirst;

  /// No description provided for @securityPinInvalid.
  ///
  /// In zh, this message translates to:
  /// **'数字密码错误'**
  String get securityPinInvalid;

  /// No description provided for @securityPinMismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次输入的数字密码不一致'**
  String get securityPinMismatch;

  /// No description provided for @securityPinSaved.
  ///
  /// In zh, this message translates to:
  /// **'数字密码已保存'**
  String get securityPinSaved;

  /// No description provided for @securityPinSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存数字密码失败：{error}'**
  String securityPinSaveFailed(String error);

  /// No description provided for @securityPinSet.
  ///
  /// In zh, this message translates to:
  /// **'数字密码已设置'**
  String get securityPinSet;

  /// No description provided for @securitySetPatternTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置手势密码'**
  String get securitySetPatternTitle;

  /// No description provided for @securitySetPinFirst.
  ///
  /// In zh, this message translates to:
  /// **'设置数字密码'**
  String get securitySetPinFirst;

  /// No description provided for @securitySetPinTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置数字密码'**
  String get securitySetPinTitle;

  /// No description provided for @securitySettingsSub.
  ///
  /// In zh, this message translates to:
  /// **'配置进入 Oh My Media 时使用的本地验证方式'**
  String get securitySettingsSub;

  /// No description provided for @securityUnlockMethodCleared.
  ///
  /// In zh, this message translates to:
  /// **'解锁方式已清除'**
  String get securityUnlockMethodCleared;

  /// No description provided for @securityUnlockMethods.
  ///
  /// In zh, this message translates to:
  /// **'解锁方式'**
  String get securityUnlockMethods;

  /// No description provided for @securityUsageNotes.
  ///
  /// In zh, this message translates to:
  /// **'使用说明'**
  String get securityUsageNotes;

  /// No description provided for @settingsAppUpdate.
  ///
  /// In zh, this message translates to:
  /// **'应用更新'**
  String get settingsAppUpdate;

  /// No description provided for @settingsAppUpdateSub.
  ///
  /// In zh, this message translates to:
  /// **'填写 GitHub 仓库地址，自动检查对应平台的安装包'**
  String get settingsAppUpdateSub;

  /// No description provided for @settingsCacheCategories.
  ///
  /// In zh, this message translates to:
  /// **'缓存分类'**
  String get settingsCacheCategories;

  /// No description provided for @settingsCacheCleanAll.
  ///
  /// In zh, this message translates to:
  /// **'一键清理'**
  String get settingsCacheCleanAll;

  /// No description provided for @settingsCacheClearAllBody.
  ///
  /// In zh, this message translates to:
  /// **'将清理全部缓存内容。'**
  String get settingsCacheClearAllBody;

  /// No description provided for @settingsCacheClearAllTitle.
  ///
  /// In zh, this message translates to:
  /// **'清理全部缓存'**
  String get settingsCacheClearAllTitle;

  /// No description provided for @settingsCacheCleared.
  ///
  /// In zh, this message translates to:
  /// **'缓存已清理'**
  String get settingsCacheCleared;

  /// No description provided for @settingsCacheTotal.
  ///
  /// In zh, this message translates to:
  /// **'缓存总量'**
  String get settingsCacheTotal;

  /// No description provided for @settingsCacheTotalSize.
  ///
  /// In zh, this message translates to:
  /// **'总缓存大小'**
  String get settingsCacheTotalSize;

  /// No description provided for @settingsCheckUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'检查更新失败'**
  String get settingsCheckUpdateFailed;

  /// No description provided for @settingsChoosePlayerEngine.
  ///
  /// In zh, this message translates to:
  /// **'选择播放器内核'**
  String get settingsChoosePlayerEngine;

  /// No description provided for @settingsClearUpdateSource.
  ///
  /// In zh, this message translates to:
  /// **'清除更新来源'**
  String get settingsClearUpdateSource;

  /// No description provided for @settingsClearUpdateSourceBody.
  ///
  /// In zh, this message translates to:
  /// **'清除已保存的更新来源设置？'**
  String get settingsClearUpdateSourceBody;

  /// No description provided for @settingsClearUpdateSourceTitle.
  ///
  /// In zh, this message translates to:
  /// **'清除更新来源'**
  String get settingsClearUpdateSourceTitle;

  /// No description provided for @settingsCurrentCache.
  ///
  /// In zh, this message translates to:
  /// **'当前缓存'**
  String get settingsCurrentCache;

  /// No description provided for @settingsCurrentVersion.
  ///
  /// In zh, this message translates to:
  /// **'当前版本'**
  String get settingsCurrentVersion;

  /// No description provided for @settingsDebug.
  ///
  /// In zh, this message translates to:
  /// **'调试'**
  String get settingsDebug;

  /// No description provided for @settingsDevM3u8Title.
  ///
  /// In zh, this message translates to:
  /// **'开发接口 · m3u8'**
  String get settingsDevM3u8Title;

  /// No description provided for @settingsDevTools.
  ///
  /// In zh, this message translates to:
  /// **'开发接口'**
  String get settingsDevTools;

  /// No description provided for @settingsDownloadAndInstall.
  ///
  /// In zh, this message translates to:
  /// **'下载并安装'**
  String get settingsDownloadAndInstall;

  /// No description provided for @settingsDownloadingPercent.
  ///
  /// In zh, this message translates to:
  /// **'正在下载… {percent}%'**
  String settingsDownloadingPercent(int percent);

  /// No description provided for @settingsDownloadingUpdatePercent.
  ///
  /// In zh, this message translates to:
  /// **'正在下载更新… {percent}%'**
  String settingsDownloadingUpdatePercent(int percent);

  /// No description provided for @settingsDownloadUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'下载更新失败'**
  String get settingsDownloadUpdateFailed;

  /// No description provided for @settingsEditUpdateSource.
  ///
  /// In zh, this message translates to:
  /// **'编辑更新来源'**
  String get settingsEditUpdateSource;

  /// No description provided for @settingsGithubRepoLabel.
  ///
  /// In zh, this message translates to:
  /// **'GitHub 仓库地址'**
  String get settingsGithubRepoLabel;

  /// No description provided for @settingsIncludeDevelopment.
  ///
  /// In zh, this message translates to:
  /// **'检测开发版'**
  String get settingsIncludeDevelopment;

  /// No description provided for @settingsIncludeDevelopmentSub.
  ///
  /// In zh, this message translates to:
  /// **'开启后同时检测标准版与开发版，并选择版本更高的安装包'**
  String get settingsIncludeDevelopmentSub;

  /// No description provided for @settingsInstalledVersion.
  ///
  /// In zh, this message translates to:
  /// **'已安装版本'**
  String get settingsInstalledVersion;

  /// No description provided for @settingsInstallerOpened.
  ///
  /// In zh, this message translates to:
  /// **'安装程序已打开'**
  String get settingsInstallerOpened;

  /// No description provided for @settingsInstallUpdate.
  ///
  /// In zh, this message translates to:
  /// **'安装更新'**
  String get settingsInstallUpdate;

  /// No description provided for @settingsIosInstallerOpened.
  ///
  /// In zh, this message translates to:
  /// **'iOS 安装程序已打开'**
  String get settingsIosInstallerOpened;

  /// No description provided for @settingsKsPlayerIosOnly.
  ///
  /// In zh, this message translates to:
  /// **'KSPlayer 仅支持 iOS'**
  String get settingsKsPlayerIosOnly;

  /// No description provided for @settingsKsPlayerIosOnlyError.
  ///
  /// In zh, this message translates to:
  /// **'KSPlayer 仅支持 iOS，请选择 libmpv'**
  String get settingsKsPlayerIosOnlyError;

  /// No description provided for @settingsM3u8Hint.
  ///
  /// In zh, this message translates to:
  /// **'输入 M3U8 播放地址'**
  String get settingsM3u8Hint;

  /// No description provided for @settingsM3u8Invalid.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的 http/https m3u8 地址'**
  String get settingsM3u8Invalid;

  /// No description provided for @settingsM3u8UrlLabel.
  ///
  /// In zh, this message translates to:
  /// **'m3u8 地址'**
  String get settingsM3u8UrlLabel;

  /// No description provided for @settingsNewVersionFound.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本'**
  String get settingsNewVersionFound;

  /// No description provided for @settingsNoUpdateNotes.
  ///
  /// In zh, this message translates to:
  /// **'暂无更新说明'**
  String get settingsNoUpdateNotes;

  /// No description provided for @settingsOpeningInstaller.
  ///
  /// In zh, this message translates to:
  /// **'正在打开安装器…'**
  String get settingsOpeningInstaller;

  /// No description provided for @settingsPlatformNotSupported.
  ///
  /// In zh, this message translates to:
  /// **'当前平台不支持此操作'**
  String get settingsPlatformNotSupported;

  /// No description provided for @settingsPlayerDebugMode.
  ///
  /// In zh, this message translates to:
  /// **'播放器 Debug 模式'**
  String get settingsPlayerDebugMode;

  /// No description provided for @settingsPlayerDebugModeSub.
  ///
  /// In zh, this message translates to:
  /// **'在播放画面显示内核、编码、码率、帧率等信息'**
  String get settingsPlayerDebugModeSub;

  /// No description provided for @settingsPlayerEngine.
  ///
  /// In zh, this message translates to:
  /// **'播放器内核'**
  String get settingsPlayerEngine;

  /// No description provided for @settingsPlayM3u8.
  ///
  /// In zh, this message translates to:
  /// **'播放 M3U8'**
  String get settingsPlayM3u8;

  /// No description provided for @settingsSaveDevPrefFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存开发者设置失败'**
  String get settingsSaveDevPrefFailed;

  /// No description provided for @settingsSaveIgnoreFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存忽略设置失败'**
  String get settingsSaveIgnoreFailed;

  /// No description provided for @settingsSaveUpdateSource.
  ///
  /// In zh, this message translates to:
  /// **'保存更新来源'**
  String get settingsSaveUpdateSource;

  /// No description provided for @settingsSaveUpdateSourceFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存更新来源失败'**
  String get settingsSaveUpdateSourceFailed;

  /// No description provided for @settingsUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'更新失败'**
  String get settingsUpdateFailed;

  /// No description provided for @settingsUpdateFound.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本 {version}'**
  String settingsUpdateFound(String version);

  /// No description provided for @settingsUpdateNotesTitle.
  ///
  /// In zh, this message translates to:
  /// **'本次构建包含以下更新：'**
  String get settingsUpdateNotesTitle;

  /// No description provided for @settingsUpdateNow.
  ///
  /// In zh, this message translates to:
  /// **'立即更新'**
  String get settingsUpdateNow;

  /// No description provided for @settingsUpdateResult.
  ///
  /// In zh, this message translates to:
  /// **'检测结果'**
  String get settingsUpdateResult;

  /// No description provided for @settingsUpdateSource.
  ///
  /// In zh, this message translates to:
  /// **'更新来源'**
  String get settingsUpdateSource;

  /// No description provided for @settingsUpdateSourceCleared.
  ///
  /// In zh, this message translates to:
  /// **'更新源已清除'**
  String get settingsUpdateSourceCleared;

  /// No description provided for @settingsUpdateSourceHint.
  ///
  /// In zh, this message translates to:
  /// **'输入 GitHub 仓库或更新地址'**
  String get settingsUpdateSourceHint;

  /// No description provided for @settingsUpdateSourceSaved.
  ///
  /// In zh, this message translates to:
  /// **'更新来源已保存'**
  String get settingsUpdateSourceSaved;

  /// No description provided for @settingsUpToDate.
  ///
  /// In zh, this message translates to:
  /// **'已是最新版本'**
  String get settingsUpToDate;

  /// No description provided for @settingsViewPlaybackLogs.
  ///
  /// In zh, this message translates to:
  /// **'查看播放日志'**
  String get settingsViewPlaybackLogs;

  /// No description provided for @settingsViewPlaybackLogsSub.
  ///
  /// In zh, this message translates to:
  /// **'SMB / WebDAV 视频持续加载时，复制日志给开发者'**
  String get settingsViewPlaybackLogsSub;

  /// No description provided for @statMinutes.
  ///
  /// In zh, this message translates to:
  /// **'分钟'**
  String get statMinutes;

  /// No description provided for @subtitleDecrease.
  ///
  /// In zh, this message translates to:
  /// **'减少'**
  String get subtitleDecrease;

  /// No description provided for @subtitleDelayOffset.
  ///
  /// In zh, this message translates to:
  /// **'延迟偏移'**
  String get subtitleDelayOffset;

  /// No description provided for @subtitleEditField.
  ///
  /// In zh, this message translates to:
  /// **'编辑{field}'**
  String subtitleEditField(String field);

  /// No description provided for @subtitleIncrease.
  ///
  /// In zh, this message translates to:
  /// **'增加'**
  String get subtitleIncrease;

  /// No description provided for @subtitleInvalidNumber.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效数字'**
  String get subtitleInvalidNumber;

  /// No description provided for @subtitleLandscape.
  ///
  /// In zh, this message translates to:
  /// **'横屏字幕'**
  String get subtitleLandscape;

  /// No description provided for @subtitleNoLimit.
  ///
  /// In zh, this message translates to:
  /// **'无限制'**
  String get subtitleNoLimit;

  /// No description provided for @subtitleOpacity.
  ///
  /// In zh, this message translates to:
  /// **'不透明度'**
  String get subtitleOpacity;

  /// No description provided for @subtitleOrientationHint.
  ///
  /// In zh, this message translates to:
  /// **'当前调节：{orientation}'**
  String subtitleOrientationHint(String orientation);

  /// No description provided for @subtitlePortrait.
  ///
  /// In zh, this message translates to:
  /// **'竖屏字幕'**
  String get subtitlePortrait;

  /// No description provided for @subtitleRange.
  ///
  /// In zh, this message translates to:
  /// **'范围：{range}'**
  String subtitleRange(String range);

  /// No description provided for @subtitleResetForPlayback.
  ///
  /// In zh, this message translates to:
  /// **'恢复本次播放默认'**
  String get subtitleResetForPlayback;

  /// No description provided for @subtitleSizeScale.
  ///
  /// In zh, this message translates to:
  /// **'大小缩放'**
  String get subtitleSizeScale;

  /// No description provided for @subtitleSourceEmbedded.
  ///
  /// In zh, this message translates to:
  /// **'内嵌字幕'**
  String get subtitleSourceEmbedded;

  /// No description provided for @subtitleSourceExternal.
  ///
  /// In zh, this message translates to:
  /// **'外挂字幕'**
  String get subtitleSourceExternal;

  /// No description provided for @subtitleSourceUnknown.
  ///
  /// In zh, this message translates to:
  /// **'字幕来源未知'**
  String get subtitleSourceUnknown;

  /// No description provided for @subtitleTooHigh.
  ///
  /// In zh, this message translates to:
  /// **'不能高于 {value}'**
  String subtitleTooHigh(String value);

  /// No description provided for @subtitleTooLow.
  ///
  /// In zh, this message translates to:
  /// **'不能低于 {value}'**
  String subtitleTooLow(String value);

  /// No description provided for @subtitleUnitPixels.
  ///
  /// In zh, this message translates to:
  /// **'像素'**
  String get subtitleUnitPixels;

  /// No description provided for @subtitleUnitSeconds.
  ///
  /// In zh, this message translates to:
  /// **'秒'**
  String get subtitleUnitSeconds;

  /// No description provided for @subtitleVerticalOffset.
  ///
  /// In zh, this message translates to:
  /// **'垂直偏移'**
  String get subtitleVerticalOffset;

  /// No description provided for @taskActionBusy.
  ///
  /// In zh, this message translates to:
  /// **'处理中'**
  String get taskActionBusy;

  /// No description provided for @taskLoadMore.
  ///
  /// In zh, this message translates to:
  /// **'加载更多'**
  String get taskLoadMore;

  /// No description provided for @taskLoadingMore.
  ///
  /// In zh, this message translates to:
  /// **'加载中…'**
  String get taskLoadingMore;

  /// No description provided for @taskRecordDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定从服务端删除这条任务记录吗？删除后无法恢复。'**
  String get taskRecordDeleteConfirm;

  /// No description provided for @taskActionRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get taskActionRetry;

  /// No description provided for @taskCancelSubmitted.
  ///
  /// In zh, this message translates to:
  /// **'已提交取消任务'**
  String get taskCancelSubmitted;

  /// No description provided for @taskCenterEyebrow.
  ///
  /// In zh, this message translates to:
  /// **'后台任务'**
  String get taskCenterEyebrow;

  /// No description provided for @taskCenterSubtitleActive.
  ///
  /// In zh, this message translates to:
  /// **'{active} 条任务正在执行 · 共 {total} 条记录'**
  String taskCenterSubtitleActive(int active, int total);

  /// No description provided for @taskCenterSubtitleIdle.
  ///
  /// In zh, this message translates to:
  /// **'暂无进行中的任务 · 共 {total} 条记录'**
  String taskCenterSubtitleIdle(int total);

  /// No description provided for @taskEmptyActive.
  ///
  /// In zh, this message translates to:
  /// **'没有正在执行的任务'**
  String get taskEmptyActive;

  /// No description provided for @taskEmptyAll.
  ///
  /// In zh, this message translates to:
  /// **'暂无任务'**
  String get taskEmptyAll;

  /// No description provided for @taskEmptyCanceled.
  ///
  /// In zh, this message translates to:
  /// **'没有已取消的任务'**
  String get taskEmptyCanceled;

  /// No description provided for @taskEmptyCompleted.
  ///
  /// In zh, this message translates to:
  /// **'没有已完成的任务'**
  String get taskEmptyCompleted;

  /// No description provided for @taskEmptyFailed.
  ///
  /// In zh, this message translates to:
  /// **'暂无失败任务'**
  String get taskEmptyFailed;

  /// No description provided for @taskEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'NFO、云端转译、音频提取和扫库任务会显示在这里'**
  String get taskEmptyHint;

  /// No description provided for @taskErrCancelExtract.
  ///
  /// In zh, this message translates to:
  /// **'取消音频提取失败'**
  String get taskErrCancelExtract;

  /// No description provided for @taskErrCancelTranscribe.
  ///
  /// In zh, this message translates to:
  /// **'取消转录失败'**
  String get taskErrCancelTranscribe;

  /// No description provided for @taskErrRetryTranscribe.
  ///
  /// In zh, this message translates to:
  /// **'重试转录失败'**
  String get taskErrRetryTranscribe;

  /// No description provided for @taskFilterActive.
  ///
  /// In zh, this message translates to:
  /// **'执行中'**
  String get taskFilterActive;

  /// No description provided for @taskFilterAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get taskFilterAll;

  /// No description provided for @taskFilterCanceled.
  ///
  /// In zh, this message translates to:
  /// **'已取消'**
  String get taskFilterCanceled;

  /// No description provided for @taskFilterCompleted.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get taskFilterCompleted;

  /// No description provided for @taskFilterFailed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get taskFilterFailed;

  /// No description provided for @taskMsgCanceled.
  ///
  /// In zh, this message translates to:
  /// **'任务已取消'**
  String get taskMsgCanceled;

  /// No description provided for @taskMsgRequeued.
  ///
  /// In zh, this message translates to:
  /// **'任务已重新排队'**
  String get taskMsgRequeued;

  /// No description provided for @taskMsgScanPreparing.
  ///
  /// In zh, this message translates to:
  /// **'正在准备扫描'**
  String get taskMsgScanPreparing;

  /// No description provided for @taskMsgScanQueued.
  ///
  /// In zh, this message translates to:
  /// **'扫描任务已排队'**
  String get taskMsgScanQueued;

  /// No description provided for @taskMsgScanQueuedAt.
  ///
  /// In zh, this message translates to:
  /// **'排队中（第 {position} 位）'**
  String taskMsgScanQueuedAt(int position);

  /// No description provided for @taskMsgWaitingUpdate.
  ///
  /// In zh, this message translates to:
  /// **'等待更新'**
  String get taskMsgWaitingUpdate;

  /// No description provided for @taskNameActorSync.
  ///
  /// In zh, this message translates to:
  /// **'演员同步'**
  String get taskNameActorSync;

  /// No description provided for @taskNameAudioExtract.
  ///
  /// In zh, this message translates to:
  /// **'音频提取'**
  String get taskNameAudioExtract;

  /// No description provided for @taskNameFallback.
  ///
  /// In zh, this message translates to:
  /// **'后台任务'**
  String get taskNameFallback;

  /// No description provided for @taskNameNfoSync.
  ///
  /// In zh, this message translates to:
  /// **'NFO 同步'**
  String get taskNameNfoSync;

  /// No description provided for @taskNameResourceScan.
  ///
  /// In zh, this message translates to:
  /// **'资源扫描'**
  String get taskNameResourceScan;

  /// No description provided for @taskNameScan.
  ///
  /// In zh, this message translates to:
  /// **'扫库'**
  String get taskNameScan;

  /// No description provided for @taskNameTranscribe.
  ///
  /// In zh, this message translates to:
  /// **'字幕转译'**
  String get taskNameTranscribe;

  /// No description provided for @taskRecordRemoved.
  ///
  /// In zh, this message translates to:
  /// **'任务记录已移除'**
  String get taskRecordRemoved;

  /// No description provided for @taskUndo.
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get taskUndo;

  /// No description provided for @unitDays.
  ///
  /// In zh, this message translates to:
  /// **'天'**
  String get unitDays;

  /// No description provided for @unitMinutes.
  ///
  /// In zh, this message translates to:
  /// **'分钟'**
  String get unitMinutes;

  /// No description provided for @unitTimes.
  ///
  /// In zh, this message translates to:
  /// **'次'**
  String get unitTimes;

  /// No description provided for @videoExtensionsAddLabel.
  ///
  /// In zh, this message translates to:
  /// **'添加扩展名'**
  String get videoExtensionsAddLabel;

  /// No description provided for @videoExtensionsCurrentLabel.
  ///
  /// In zh, this message translates to:
  /// **'当前扩展名'**
  String get videoExtensionsCurrentLabel;

  /// No description provided for @videoExtensionsDotHint.
  ///
  /// In zh, this message translates to:
  /// **'支持带点号或不带点号'**
  String get videoExtensionsDotHint;

  /// No description provided for @videoExtensionsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无视频扩展名'**
  String get videoExtensionsEmpty;

  /// No description provided for @videoExtensionsSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'视频扩展名保存失败'**
  String get videoExtensionsSaveFailed;

  /// No description provided for @videoExtensionsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'视频扩展名设置'**
  String get videoExtensionsSubtitle;

  /// No description provided for @actorBatchDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'批量删除演员'**
  String get actorBatchDeleteTitle;

  /// No description provided for @actorBatchDeleteWithRelations.
  ///
  /// In zh, this message translates to:
  /// **'已选择 {count} 位演员，其中包含影片关联。强制删除会解除关联，影片本身不会被删除。'**
  String actorBatchDeleteWithRelations(int count);

  /// No description provided for @actorBatchDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除已选择的 {count} 位演员吗？'**
  String actorBatchDeleteConfirm(int count);

  /// No description provided for @actorBatchDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除 {count} 位演员'**
  String actorBatchDeleted(int count);

  /// No description provided for @actorBatchDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'批量删除失败：{error}'**
  String actorBatchDeleteFailed(String error);

  /// No description provided for @actorCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 位演员'**
  String actorCount(int count);

  /// No description provided for @actorCountSuffix.
  ///
  /// In zh, this message translates to:
  /// **'位演员'**
  String get actorCountSuffix;

  /// No description provided for @actorMovieCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 部'**
  String actorMovieCount(int count);

  /// No description provided for @actorSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索演员名称'**
  String get actorSearchHint;

  /// No description provided for @actorSortMovieCount.
  ///
  /// In zh, this message translates to:
  /// **'影片数'**
  String get actorSortMovieCount;

  /// No description provided for @actorSortName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get actorSortName;

  /// No description provided for @actorSortCreatedAt.
  ///
  /// In zh, this message translates to:
  /// **'创建时间'**
  String get actorSortCreatedAt;

  /// No description provided for @actorEditAction.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get actorEditAction;

  /// No description provided for @actorDeleteAction.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get actorDeleteAction;

  /// No description provided for @actorCancelAction.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get actorCancelAction;

  /// No description provided for @actorEditorEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑演员'**
  String get actorEditorEditTitle;

  /// No description provided for @actorEditorCreateTitle.
  ///
  /// In zh, this message translates to:
  /// **'新建演员'**
  String get actorEditorCreateTitle;

  /// No description provided for @actorEditorNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'演员名称'**
  String get actorEditorNameLabel;

  /// No description provided for @actorEditorNameHint.
  ///
  /// In zh, this message translates to:
  /// **'演员名称'**
  String get actorEditorNameHint;

  /// No description provided for @actorEditorBiographyHint.
  ///
  /// In zh, this message translates to:
  /// **'填写演员简介（可选）'**
  String get actorEditorBiographyHint;

  /// No description provided for @actorEditorAssociationLabel.
  ///
  /// In zh, this message translates to:
  /// **'关联名称'**
  String get actorEditorAssociationLabel;

  /// No description provided for @actorEditorAssociationHint.
  ///
  /// In zh, this message translates to:
  /// **'每行一个，可选'**
  String get actorEditorAssociationHint;

  /// No description provided for @actorEditorSaveAction.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get actorEditorSaveAction;

  /// No description provided for @actorEditorCreateAction.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get actorEditorCreateAction;

  /// No description provided for @actorSaved.
  ///
  /// In zh, this message translates to:
  /// **'演员已保存'**
  String get actorSaved;

  /// No description provided for @actorCreated.
  ///
  /// In zh, this message translates to:
  /// **'演员已创建'**
  String get actorCreated;

  /// No description provided for @actorActionFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作失败：{error}'**
  String actorActionFailed(String error);

  /// No description provided for @actorDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除演员'**
  String get actorDeleteTitle;

  /// No description provided for @actorDeleteWithMovies.
  ///
  /// In zh, this message translates to:
  /// **'「{name}」关联了 {count} 部影片。强制删除将解除关联,影片本身不会被删除。'**
  String actorDeleteWithMovies(String name, int count);

  /// No description provided for @actorDeleteAssociation.
  ///
  /// In zh, this message translates to:
  /// **'「{name}」是关联名称,删除将解除其影片关联,影片本身不会被删除。'**
  String actorDeleteAssociation(String name);

  /// No description provided for @actorDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除「{name}」?'**
  String actorDeleteConfirm(String name);

  /// No description provided for @actorForceDeleteAction.
  ///
  /// In zh, this message translates to:
  /// **'强制删除'**
  String get actorForceDeleteAction;

  /// No description provided for @actorDeleted.
  ///
  /// In zh, this message translates to:
  /// **'演员已删除'**
  String get actorDeleted;

  /// No description provided for @actorDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败：{error}'**
  String actorDeleteFailed(String error);

  /// No description provided for @actorAssociationBadge.
  ///
  /// In zh, this message translates to:
  /// **'关联'**
  String get actorAssociationBadge;

  /// No description provided for @actorEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有演员'**
  String get actorEmptyTitle;

  /// No description provided for @actorEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'点击右上角添加演员'**
  String get actorEmptyHint;

  /// No description provided for @serverSelectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'连接'**
  String get serverSelectionTitle;

  /// No description provided for @serverSelectionSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索服务器'**
  String get serverSelectionSearchHint;

  /// No description provided for @serverSelectionNoMatch.
  ///
  /// In zh, this message translates to:
  /// **'没有找到匹配的连接'**
  String get serverSelectionNoMatch;

  /// No description provided for @serverSelectionAddServer.
  ///
  /// In zh, this message translates to:
  /// **'添加服务器'**
  String get serverSelectionAddServer;

  /// No description provided for @serverSelectionSelectServer.
  ///
  /// In zh, this message translates to:
  /// **'选择{name}'**
  String serverSelectionSelectServer(String name);

  /// No description provided for @serverCancelAction.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get serverCancelAction;

  /// No description provided for @serverDeleteAction.
  ///
  /// In zh, this message translates to:
  /// **'删除服务器'**
  String get serverDeleteAction;

  /// No description provided for @serverLatency.
  ///
  /// In zh, this message translates to:
  /// **'延迟'**
  String get serverLatency;

  /// No description provided for @serverProjectFeiniu.
  ///
  /// In zh, this message translates to:
  /// **'飞牛影视'**
  String get serverProjectFeiniu;

  /// No description provided for @serverProjectDefault.
  ///
  /// In zh, this message translates to:
  /// **'服务器'**
  String get serverProjectDefault;

  /// No description provided for @serverLineMain.
  ///
  /// In zh, this message translates to:
  /// **'主线路'**
  String get serverLineMain;

  /// No description provided for @forceDelete.
  ///
  /// In zh, this message translates to:
  /// **'强制删除'**
  String get forceDelete;

  /// No description provided for @merge.
  ///
  /// In zh, this message translates to:
  /// **'合并'**
  String get merge;

  /// No description provided for @create.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get create;

  /// No description provided for @saved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get saved;

  /// No description provided for @created.
  ///
  /// In zh, this message translates to:
  /// **'已创建'**
  String get created;

  /// No description provided for @deleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get deleted;

  /// No description provided for @deleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败：{error}'**
  String deleteFailed(String error);

  /// No description provided for @translating.
  ///
  /// In zh, this message translates to:
  /// **'翻译中'**
  String get translating;

  /// No description provided for @translate.
  ///
  /// In zh, this message translates to:
  /// **'翻译'**
  String get translate;

  /// No description provided for @merging.
  ///
  /// In zh, this message translates to:
  /// **'合并中'**
  String get merging;

  /// No description provided for @confirmMerge.
  ///
  /// In zh, this message translates to:
  /// **'确认合并'**
  String get confirmMerge;

  /// No description provided for @reset.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get reset;

  /// No description provided for @include.
  ///
  /// In zh, this message translates to:
  /// **'包含'**
  String get include;

  /// No description provided for @exclude.
  ///
  /// In zh, this message translates to:
  /// **'排除'**
  String get exclude;

  /// No description provided for @unlimited.
  ///
  /// In zh, this message translates to:
  /// **'不限'**
  String get unlimited;

  /// No description provided for @done.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get done;

  /// No description provided for @use.
  ///
  /// In zh, this message translates to:
  /// **'使用'**
  String get use;

  /// No description provided for @loadFailedWithError.
  ///
  /// In zh, this message translates to:
  /// **'加载失败：{error}'**
  String loadFailedWithError(String error);

  /// No description provided for @advancedFilterTitle.
  ///
  /// In zh, this message translates to:
  /// **'高级筛选'**
  String get advancedFilterTitle;

  /// No description provided for @advancedFilterSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'按标签、类型、系列、年份、评分和文件属性组合筛选'**
  String get advancedFilterSubtitle;

  /// No description provided for @advancedFilterYearAndRating.
  ///
  /// In zh, this message translates to:
  /// **'年份与评分'**
  String get advancedFilterYearAndRating;

  /// No description provided for @advancedFilterYearRange.
  ///
  /// In zh, this message translates to:
  /// **'年份范围'**
  String get advancedFilterYearRange;

  /// No description provided for @advancedFilterYearFrom.
  ///
  /// In zh, this message translates to:
  /// **'起始年份'**
  String get advancedFilterYearFrom;

  /// No description provided for @advancedFilterYearTo.
  ///
  /// In zh, this message translates to:
  /// **'结束年份'**
  String get advancedFilterYearTo;

  /// No description provided for @advancedFilterYearRangeInvalid.
  ///
  /// In zh, this message translates to:
  /// **'起始年份不能大于结束年份'**
  String get advancedFilterYearRangeInvalid;

  /// No description provided for @advancedFilterRatingRange.
  ///
  /// In zh, this message translates to:
  /// **'评分范围'**
  String get advancedFilterRatingRange;

  /// No description provided for @advancedFilterMinRating.
  ///
  /// In zh, this message translates to:
  /// **'最低评分'**
  String get advancedFilterMinRating;

  /// No description provided for @advancedFilterMaxRating.
  ///
  /// In zh, this message translates to:
  /// **'最高评分'**
  String get advancedFilterMaxRating;

  /// No description provided for @advancedFilterRatingAbove.
  ///
  /// In zh, this message translates to:
  /// **'{rating} 分以上'**
  String advancedFilterRatingAbove(int rating);

  /// No description provided for @advancedFilterRatingBelow.
  ///
  /// In zh, this message translates to:
  /// **'{rating} 分以下'**
  String advancedFilterRatingBelow(int rating);

  /// No description provided for @advancedFilterSubtitlesAndFiles.
  ///
  /// In zh, this message translates to:
  /// **'字幕与文件'**
  String get advancedFilterSubtitlesAndFiles;

  /// No description provided for @advancedFilterExternalSubtitles.
  ///
  /// In zh, this message translates to:
  /// **'外挂字幕'**
  String get advancedFilterExternalSubtitles;

  /// No description provided for @advancedFilterIncludeExternalSubtitles.
  ///
  /// In zh, this message translates to:
  /// **'包含外挂字幕'**
  String get advancedFilterIncludeExternalSubtitles;

  /// No description provided for @advancedFilterExcludeExternalSubtitles.
  ///
  /// In zh, this message translates to:
  /// **'排除外挂字幕'**
  String get advancedFilterExcludeExternalSubtitles;

  /// No description provided for @advancedFilterFileFilter.
  ///
  /// In zh, this message translates to:
  /// **'文件过滤器'**
  String get advancedFilterFileFilter;

  /// No description provided for @advancedFilterOnlyStandard.
  ///
  /// In zh, this message translates to:
  /// **'仅限标准'**
  String get advancedFilterOnlyStandard;

  /// No description provided for @advancedFilterOnlyCrack.
  ///
  /// In zh, this message translates to:
  /// **'仅限破解'**
  String get advancedFilterOnlyCrack;

  /// No description provided for @advancedFilterOnlyChineseSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'仅限中字'**
  String get advancedFilterOnlyChineseSubtitle;

  /// No description provided for @advancedFilterOnlyChineseCrack.
  ///
  /// In zh, this message translates to:
  /// **'仅限中字破解'**
  String get advancedFilterOnlyChineseCrack;

  /// No description provided for @advancedFilterApply.
  ///
  /// In zh, this message translates to:
  /// **'应用筛选'**
  String get advancedFilterApply;

  /// No description provided for @resourceGenresManage.
  ///
  /// In zh, this message translates to:
  /// **'类型管理'**
  String get resourceGenresManage;

  /// No description provided for @resourceTagsManage.
  ///
  /// In zh, this message translates to:
  /// **'标签管理'**
  String get resourceTagsManage;

  /// No description provided for @resourceSeriesManage.
  ///
  /// In zh, this message translates to:
  /// **'系列管理'**
  String get resourceSeriesManage;

  /// No description provided for @resourceGenresSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索类型名称'**
  String get resourceGenresSearchHint;

  /// No description provided for @resourceTagsSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索标签名称'**
  String get resourceTagsSearchHint;

  /// No description provided for @resourceSeriesSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索系列名称'**
  String get resourceSeriesSearchHint;

  /// No description provided for @resourceBatchDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'批量删除{kind}'**
  String resourceBatchDeleteTitle(String kind);

  /// No description provided for @resourceBatchDeleteWithMovies.
  ///
  /// In zh, this message translates to:
  /// **'已选择 {count} 个{kind}，其中包含影片关联。强制删除会解除关联，影片本身不会被删除。'**
  String resourceBatchDeleteWithMovies(int count, String kind);

  /// No description provided for @resourceBatchDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除已选择的 {count} 个{kind}吗？'**
  String resourceBatchDeleteConfirm(int count, String kind);

  /// No description provided for @resourceBatchDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除 {count} 个{kind}'**
  String resourceBatchDeleted(int count, String kind);

  /// No description provided for @resourceBatchDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'批量删除失败：{error}'**
  String resourceBatchDeleteFailed(String error);

  /// No description provided for @resourceCountSuffix.
  ///
  /// In zh, this message translates to:
  /// **'个{kind}'**
  String resourceCountSuffix(String kind);

  /// No description provided for @resourceSortName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get resourceSortName;

  /// No description provided for @resourceSortMovieCount.
  ///
  /// In zh, this message translates to:
  /// **'影片数'**
  String get resourceSortMovieCount;

  /// No description provided for @resourceSortCreatedAt.
  ///
  /// In zh, this message translates to:
  /// **'创建时间'**
  String get resourceSortCreatedAt;

  /// No description provided for @resourceTranslateEmpty.
  ///
  /// In zh, this message translates to:
  /// **'名称内容为空，无需翻译'**
  String get resourceTranslateEmpty;

  /// No description provided for @resourceTranslateNoResult.
  ///
  /// In zh, this message translates to:
  /// **'名称翻译为空'**
  String get resourceTranslateNoResult;

  /// No description provided for @resourceTranslateSuccess.
  ///
  /// In zh, this message translates to:
  /// **'名称翻译成功'**
  String get resourceTranslateSuccess;

  /// No description provided for @resourceTranslateFailed.
  ///
  /// In zh, this message translates to:
  /// **'名称翻译失败：{error}'**
  String resourceTranslateFailed(String error);

  /// No description provided for @resourceEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑{kind}'**
  String resourceEditTitle(String kind);

  /// No description provided for @resourceCreateTitle.
  ///
  /// In zh, this message translates to:
  /// **'新建{kind}'**
  String resourceCreateTitle(String kind);

  /// No description provided for @resourceNameHint.
  ///
  /// In zh, this message translates to:
  /// **'{kind}名称'**
  String resourceNameHint(String kind);

  /// No description provided for @resourceAutoMapping.
  ///
  /// In zh, this message translates to:
  /// **'自动映射'**
  String get resourceAutoMapping;

  /// No description provided for @resourceDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除{kind}'**
  String resourceDeleteTitle(String kind);

  /// No description provided for @resourceDeleteWithMovies.
  ///
  /// In zh, this message translates to:
  /// **'「{name}」关联了 {count} 部影片。强制删除将解除所有关联,影片本身不会被删。'**
  String resourceDeleteWithMovies(String name, int count);

  /// No description provided for @resourceDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除「{name}」?'**
  String resourceDeleteConfirm(String name);

  /// No description provided for @resourceEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有{kind}'**
  String resourceEmptyTitle(String kind);

  /// No description provided for @resourceEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'点击右上角添加按钮创建第一个'**
  String get resourceEmptyHint;

  /// No description provided for @resourceMoviesEmpty.
  ///
  /// In zh, this message translates to:
  /// **'这个维度下还没有影片'**
  String get resourceMoviesEmpty;

  /// No description provided for @resourceMovieCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 部影片'**
  String resourceMovieCount(int count);

  /// No description provided for @resourceMovieCountWithName.
  ///
  /// In zh, this message translates to:
  /// **'{name} · {count} 部影片'**
  String resourceMovieCountWithName(String name, int count);

  /// No description provided for @resourceMergeTitle.
  ///
  /// In zh, this message translates to:
  /// **'批量合并{kind}'**
  String resourceMergeTitle(String kind);

  /// No description provided for @resourceMergeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'将 {count} 个{kind}合并为一个，影片关联会转移到保留项。'**
  String resourceMergeSubtitle(int count, String kind);

  /// No description provided for @resourceMergeKeep.
  ///
  /// In zh, this message translates to:
  /// **'保留的{kind}'**
  String resourceMergeKeep(String kind);

  /// No description provided for @resourceMergeFailed.
  ///
  /// In zh, this message translates to:
  /// **'合并失败：{error}'**
  String resourceMergeFailed(String error);

  /// No description provided for @entityPickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择{kind}'**
  String entityPickerTitle(String kind);

  /// No description provided for @entityPickerSelected.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 项'**
  String entityPickerSelected(int count);

  /// No description provided for @entityPickerSearchName.
  ///
  /// In zh, this message translates to:
  /// **'搜索名称'**
  String get entityPickerSearchName;

  /// No description provided for @entityPickerSearchNameOrAlias.
  ///
  /// In zh, this message translates to:
  /// **'搜索名称 / 别名'**
  String get entityPickerSearchNameOrAlias;

  /// No description provided for @entityPickerNoResourceMatch.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的资源'**
  String get entityPickerNoResourceMatch;

  /// No description provided for @entityPickerNoActorMatch.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的演员'**
  String get entityPickerNoActorMatch;

  /// No description provided for @entityPickerNoSeriesMatch.
  ///
  /// In zh, this message translates to:
  /// **'未找到匹配的系列'**
  String get entityPickerNoSeriesMatch;

  /// No description provided for @entityPickerSelect.
  ///
  /// In zh, this message translates to:
  /// **'选择{kind}…'**
  String entityPickerSelect(String kind);

  /// No description provided for @movieCountShort.
  ///
  /// In zh, this message translates to:
  /// **'{count} 部'**
  String movieCountShort(int count);

  /// No description provided for @batchEditNothingSelected.
  ///
  /// In zh, this message translates to:
  /// **'请至少选择一项要添加、移除或裁剪的内容'**
  String get batchEditNothingSelected;

  /// No description provided for @batchEditWatermarkResult.
  ///
  /// In zh, this message translates to:
  /// **'海报裁剪：成功 {success}，失败 {failed}'**
  String batchEditWatermarkResult(int success, int failed);

  /// No description provided for @batchEditSaved.
  ///
  /// In zh, this message translates to:
  /// **'批量编辑成功'**
  String get batchEditSaved;

  /// No description provided for @batchEditFailed.
  ///
  /// In zh, this message translates to:
  /// **'批量编辑失败：{error}'**
  String batchEditFailed(String error);

  /// No description provided for @batchEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'批量编辑 {count} 部'**
  String batchEditTitle(int count);

  /// No description provided for @batchEditSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'集中调整标签、类型、系列和快速标记'**
  String get batchEditSubtitle;

  /// No description provided for @batchEditQuickFlags.
  ///
  /// In zh, this message translates to:
  /// **'快速标记'**
  String get batchEditQuickFlags;

  /// No description provided for @batchEditQuickFlagsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'保存时会同步裁剪海报水印'**
  String get batchEditQuickFlagsSubtitle;

  /// No description provided for @movieFlagSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'字幕'**
  String get movieFlagSubtitle;

  /// No description provided for @movieFlagExternalSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'外挂字幕'**
  String get movieFlagExternalSubtitle;

  /// No description provided for @movieFlagCrack.
  ///
  /// In zh, this message translates to:
  /// **'破解'**
  String get movieFlagCrack;

  /// No description provided for @batchEditSubtitleExclusive.
  ///
  /// In zh, this message translates to:
  /// **'字幕与外挂字幕互斥'**
  String get batchEditSubtitleExclusive;

  /// No description provided for @batchEditTagSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'分别指定要追加和移除的标签集合'**
  String get batchEditTagSubtitle;

  /// No description provided for @batchEditAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加{kind}'**
  String batchEditAdd(String kind);

  /// No description provided for @batchEditRemoveCommon.
  ///
  /// In zh, this message translates to:
  /// **'移除{kind}（仅共有）'**
  String batchEditRemoveCommon(String kind);

  /// No description provided for @batchEditSeriesSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'可统一设置系列'**
  String get batchEditSeriesSubtitle;

  /// No description provided for @batchEditNoCommon.
  ///
  /// In zh, this message translates to:
  /// **'无共有{kind}'**
  String batchEditNoCommon(String kind);

  /// No description provided for @loadingEllipsis.
  ///
  /// In zh, this message translates to:
  /// **'加载中…'**
  String get loadingEllipsis;

  /// No description provided for @batchEditSeriesSearchFailed.
  ///
  /// In zh, this message translates to:
  /// **'搜索系列失败，请稍后重试'**
  String get batchEditSeriesSearchFailed;

  /// No description provided for @batchEditSeriesLoadMoreFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载更多系列失败，请稍后重试'**
  String get batchEditSeriesLoadMoreFailed;

  /// No description provided for @batchEditSeriesSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索系列…'**
  String get batchEditSeriesSearchHint;

  /// No description provided for @batchEditSeriesEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无系列'**
  String get batchEditSeriesEmpty;

  /// No description provided for @batchEditClearSeries.
  ///
  /// In zh, this message translates to:
  /// **'清空选择'**
  String get batchEditClearSeries;

  /// No description provided for @detailActorRelatedMovies.
  ///
  /// In zh, this message translates to:
  /// **'演员相关影片'**
  String get detailActorRelatedMovies;

  /// No description provided for @detailFile.
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get detailFile;

  /// No description provided for @detailMovieFile.
  ///
  /// In zh, this message translates to:
  /// **'影片文件'**
  String get detailMovieFile;

  /// No description provided for @detailFilePath.
  ///
  /// In zh, this message translates to:
  /// **'文件路径'**
  String get detailFilePath;

  /// No description provided for @detailNumber.
  ///
  /// In zh, this message translates to:
  /// **'编号'**
  String get detailNumber;

  /// No description provided for @detailCountry.
  ///
  /// In zh, this message translates to:
  /// **'国家/地区'**
  String get detailCountry;

  /// No description provided for @detailRuntime.
  ///
  /// In zh, this message translates to:
  /// **'时长'**
  String get detailRuntime;

  /// No description provided for @detailRuntimeMinutes.
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分钟'**
  String detailRuntimeMinutes(Object minutes);

  /// No description provided for @detailFileSize.
  ///
  /// In zh, this message translates to:
  /// **'文件大小'**
  String get detailFileSize;

  /// No description provided for @detailPart.
  ///
  /// In zh, this message translates to:
  /// **'分部'**
  String get detailPart;

  /// No description provided for @detailDownloadedAt.
  ///
  /// In zh, this message translates to:
  /// **'下载时间'**
  String get detailDownloadedAt;

  /// No description provided for @detailContainer.
  ///
  /// In zh, this message translates to:
  /// **'容器'**
  String get detailContainer;

  /// No description provided for @detailSize.
  ///
  /// In zh, this message translates to:
  /// **'大小'**
  String get detailSize;

  /// No description provided for @detailMediaInfo.
  ///
  /// In zh, this message translates to:
  /// **'媒体信息'**
  String get detailMediaInfo;

  /// No description provided for @detailDurationHours.
  ///
  /// In zh, this message translates to:
  /// **'{hours}小时 {minutes}分 {seconds}秒'**
  String detailDurationHours(int hours, String minutes, String seconds);

  /// No description provided for @detailDurationMinutes.
  ///
  /// In zh, this message translates to:
  /// **'{minutes}分 {seconds}秒'**
  String detailDurationMinutes(int minutes, String seconds);

  /// No description provided for @detailAudioExtractionSubmitted.
  ///
  /// In zh, this message translates to:
  /// **'音频提取任务已提交'**
  String get detailAudioExtractionSubmitted;

  /// No description provided for @detailSyncNfoTitle.
  ///
  /// In zh, this message translates to:
  /// **'同步到 NFO'**
  String get detailSyncNfoTitle;

  /// No description provided for @detailSyncNfoMessage.
  ///
  /// In zh, this message translates to:
  /// **'把当前元数据写入磁盘 NFO 文件?'**
  String get detailSyncNfoMessage;

  /// No description provided for @detailSyncNfoSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已同步到 NFO'**
  String get detailSyncNfoSuccess;

  /// No description provided for @detailRefreshNfoTitle.
  ///
  /// In zh, this message translates to:
  /// **'从 NFO 刷新'**
  String get detailRefreshNfoTitle;

  /// No description provided for @detailRefreshNfoMessage.
  ///
  /// In zh, this message translates to:
  /// **'从磁盘 NFO 重新加载,会覆盖当前元数据。'**
  String get detailRefreshNfoMessage;

  /// No description provided for @detailRefreshNfoSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已从 NFO 重载'**
  String get detailRefreshNfoSuccess;

  /// No description provided for @detailEditMovie.
  ///
  /// In zh, this message translates to:
  /// **'编辑影片'**
  String get detailEditMovie;

  /// No description provided for @detailFetchMetadata.
  ///
  /// In zh, this message translates to:
  /// **'获取元数据'**
  String get detailFetchMetadata;

  /// No description provided for @detailFetchResources.
  ///
  /// In zh, this message translates to:
  /// **'获取资源'**
  String get detailFetchResources;

  /// No description provided for @detailFetchSubtitles.
  ///
  /// In zh, this message translates to:
  /// **'获取字幕'**
  String get detailFetchSubtitles;

  /// No description provided for @detailExtractAudio.
  ///
  /// In zh, this message translates to:
  /// **'提取音频'**
  String get detailExtractAudio;

  /// No description provided for @detailDeleteMovieTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除影片'**
  String get detailDeleteMovieTitle;

  /// No description provided for @detailDeleteMovieMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定删除「{title}」?\n影片文件、海报、剧照、NFO 等关联资源都会被删除,且不可恢复。'**
  String detailDeleteMovieMessage(String title);

  /// No description provided for @detailPlotTitle.
  ///
  /// In zh, this message translates to:
  /// **'简介'**
  String get detailPlotTitle;

  /// No description provided for @detailPlotViewFull.
  ///
  /// In zh, this message translates to:
  /// **'查看完整简介'**
  String get detailPlotViewFull;

  /// No description provided for @fanartFetchDone.
  ///
  /// In zh, this message translates to:
  /// **'额外预览图获取完成'**
  String get fanartFetchDone;

  /// No description provided for @fanartFetchFailed.
  ///
  /// In zh, this message translates to:
  /// **'获取额外预览图失败：{error}'**
  String fanartFetchFailed(String error);

  /// No description provided for @fanartTitle.
  ///
  /// In zh, this message translates to:
  /// **'预览图'**
  String get fanartTitle;

  /// No description provided for @fanartRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新预览图'**
  String get fanartRefresh;

  /// No description provided for @fanartFetch.
  ///
  /// In zh, this message translates to:
  /// **'获取预览图'**
  String get fanartFetch;

  /// No description provided for @fanartLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在加载预览图…'**
  String get fanartLoading;

  /// No description provided for @fanartLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'预览图加载失败：{error}'**
  String fanartLoadFailed(String error);

  /// No description provided for @fanartEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无预览图'**
  String get fanartEmpty;

  /// No description provided for @fanartClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭预览图'**
  String get fanartClose;

  /// No description provided for @fanartTrailerPlaybackFailed.
  ///
  /// In zh, this message translates to:
  /// **'预告片播放失败'**
  String get fanartTrailerPlaybackFailed;

  /// No description provided for @coverBadgeCodecTooltip.
  ///
  /// In zh, this message translates to:
  /// **'视频编码：{codec}'**
  String coverBadgeCodecTooltip(String codec);

  /// No description provided for @coverBadgeRangeTooltip.
  ///
  /// In zh, this message translates to:
  /// **'动态范围：{range}'**
  String coverBadgeRangeTooltip(String range);

  /// No description provided for @coverBadgeStrmTooltip.
  ///
  /// In zh, this message translates to:
  /// **'STRM 视频文件'**
  String get coverBadgeStrmTooltip;

  /// No description provided for @coverBadgeEmbeddedSubtitleTooltip.
  ///
  /// In zh, this message translates to:
  /// **'内嵌字幕'**
  String get coverBadgeEmbeddedSubtitleTooltip;

  /// No description provided for @coverBadgeCrackTooltip.
  ///
  /// In zh, this message translates to:
  /// **'破解/无码'**
  String get coverBadgeCrackTooltip;

  /// No description provided for @coverBadgeResolutionUhdTooltip.
  ///
  /// In zh, this message translates to:
  /// **'2160p / 4K'**
  String get coverBadgeResolutionUhdTooltip;

  /// No description provided for @coverBadgeResolutionHdTooltip.
  ///
  /// In zh, this message translates to:
  /// **'720p 及以上'**
  String get coverBadgeResolutionHdTooltip;

  /// No description provided for @mediaStreamVideo.
  ///
  /// In zh, this message translates to:
  /// **'视频'**
  String get mediaStreamVideo;

  /// No description provided for @mediaStreamAudio.
  ///
  /// In zh, this message translates to:
  /// **'音频 {ordinal}'**
  String mediaStreamAudio(int ordinal);

  /// No description provided for @mediaStreamSubtitles.
  ///
  /// In zh, this message translates to:
  /// **'字幕'**
  String get mediaStreamSubtitles;

  /// No description provided for @mediaStreamDefault.
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get mediaStreamDefault;

  /// No description provided for @mediaStreamForced.
  ///
  /// In zh, this message translates to:
  /// **'强制'**
  String get mediaStreamForced;

  /// No description provided for @mediaStreamText.
  ///
  /// In zh, this message translates to:
  /// **'文本'**
  String get mediaStreamText;

  /// No description provided for @mediaStreamBitmap.
  ///
  /// In zh, this message translates to:
  /// **'位图'**
  String get mediaStreamBitmap;

  /// No description provided for @mediaStreamCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 条'**
  String mediaStreamCount(int count);

  /// No description provided for @mediaStreamEncoding.
  ///
  /// In zh, this message translates to:
  /// **'编码'**
  String get mediaStreamEncoding;

  /// No description provided for @mediaStreamProfile.
  ///
  /// In zh, this message translates to:
  /// **'配置'**
  String get mediaStreamProfile;

  /// No description provided for @mediaStreamLevel.
  ///
  /// In zh, this message translates to:
  /// **'等级'**
  String get mediaStreamLevel;

  /// No description provided for @mediaStreamResolution.
  ///
  /// In zh, this message translates to:
  /// **'分辨率'**
  String get mediaStreamResolution;

  /// No description provided for @mediaStreamAspectRatio.
  ///
  /// In zh, this message translates to:
  /// **'长宽比'**
  String get mediaStreamAspectRatio;

  /// No description provided for @mediaStreamFrameRate.
  ///
  /// In zh, this message translates to:
  /// **'帧率'**
  String get mediaStreamFrameRate;

  /// No description provided for @mediaStreamColorPrimaries.
  ///
  /// In zh, this message translates to:
  /// **'基色'**
  String get mediaStreamColorPrimaries;

  /// No description provided for @mediaStreamColorSpace.
  ///
  /// In zh, this message translates to:
  /// **'色彩空间'**
  String get mediaStreamColorSpace;

  /// No description provided for @mediaStreamTransfer.
  ///
  /// In zh, this message translates to:
  /// **'传递特性'**
  String get mediaStreamTransfer;

  /// No description provided for @mediaStreamRange.
  ///
  /// In zh, this message translates to:
  /// **'色彩范围'**
  String get mediaStreamRange;

  /// No description provided for @mediaStreamBitDepth.
  ///
  /// In zh, this message translates to:
  /// **'位深'**
  String get mediaStreamBitDepth;

  /// No description provided for @mediaStreamPixelFormat.
  ///
  /// In zh, this message translates to:
  /// **'像素格式'**
  String get mediaStreamPixelFormat;

  /// No description provided for @mediaStreamBitrate.
  ///
  /// In zh, this message translates to:
  /// **'码率'**
  String get mediaStreamBitrate;

  /// No description provided for @mediaStreamLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get mediaStreamLanguage;

  /// No description provided for @mediaStreamLayout.
  ///
  /// In zh, this message translates to:
  /// **'布局'**
  String get mediaStreamLayout;

  /// No description provided for @mediaStreamChannelsLabel.
  ///
  /// In zh, this message translates to:
  /// **'声道'**
  String get mediaStreamChannelsLabel;

  /// No description provided for @mediaStreamChannels.
  ///
  /// In zh, this message translates to:
  /// **'{count} 声道'**
  String mediaStreamChannels(int count);

  /// No description provided for @mediaStreamSampleRate.
  ///
  /// In zh, this message translates to:
  /// **'采样率'**
  String get mediaStreamSampleRate;

  /// No description provided for @mediaStreamTitle.
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get mediaStreamTitle;

  /// No description provided for @mediaLanguageJapanese.
  ///
  /// In zh, this message translates to:
  /// **'日语'**
  String get mediaLanguageJapanese;

  /// No description provided for @mediaLanguageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'英语'**
  String get mediaLanguageEnglish;

  /// No description provided for @mediaLanguageChinese.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get mediaLanguageChinese;

  /// No description provided for @mediaLanguageCantonese.
  ///
  /// In zh, this message translates to:
  /// **'粤语'**
  String get mediaLanguageCantonese;

  /// No description provided for @mediaLanguageKorean.
  ///
  /// In zh, this message translates to:
  /// **'韩语'**
  String get mediaLanguageKorean;

  /// No description provided for @mediaLanguageFrench.
  ///
  /// In zh, this message translates to:
  /// **'法语'**
  String get mediaLanguageFrench;

  /// No description provided for @mediaLanguageRussian.
  ///
  /// In zh, this message translates to:
  /// **'俄语'**
  String get mediaLanguageRussian;

  /// No description provided for @mediaLanguageSpanish.
  ///
  /// In zh, this message translates to:
  /// **'西班牙语'**
  String get mediaLanguageSpanish;

  /// No description provided for @mediaLanguageGerman.
  ///
  /// In zh, this message translates to:
  /// **'德语'**
  String get mediaLanguageGerman;

  /// No description provided for @mediaLanguageThai.
  ///
  /// In zh, this message translates to:
  /// **'泰语'**
  String get mediaLanguageThai;

  /// No description provided for @mediaLanguageUndetermined.
  ///
  /// In zh, this message translates to:
  /// **'未指定'**
  String get mediaLanguageUndetermined;

  /// No description provided for @moviesFilterDuplicateNum.
  ///
  /// In zh, this message translates to:
  /// **'重复番号'**
  String get moviesFilterDuplicateNum;

  /// No description provided for @moviesFilterNewResources.
  ///
  /// In zh, this message translates to:
  /// **'新资源'**
  String get moviesFilterNewResources;

  /// No description provided for @moviesScanResources.
  ///
  /// In zh, this message translates to:
  /// **'扫描资源'**
  String get moviesScanResources;

  /// No description provided for @moviesScanning.
  ///
  /// In zh, this message translates to:
  /// **'扫描中'**
  String get moviesScanning;

  /// No description provided for @moviesBatchEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get moviesBatchEdit;

  /// No description provided for @moviesBatchDownload.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get moviesBatchDownload;

  /// No description provided for @moviesBatchScan.
  ///
  /// In zh, this message translates to:
  /// **'扫描'**
  String get moviesBatchScan;

  /// No description provided for @moviesBatchCompare.
  ///
  /// In zh, this message translates to:
  /// **'比较'**
  String get moviesBatchCompare;

  /// No description provided for @moviesBatchMerge.
  ///
  /// In zh, this message translates to:
  /// **'合并'**
  String get moviesBatchMerge;

  /// No description provided for @moviesFavoriteAdded.
  ///
  /// In zh, this message translates to:
  /// **'已收藏「{title}」'**
  String moviesFavoriteAdded(String title);

  /// No description provided for @moviesFavoriteRemoved.
  ///
  /// In zh, this message translates to:
  /// **'已取消收藏「{title}」'**
  String moviesFavoriteRemoved(String title);

  /// No description provided for @moviesOperationFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作失败：{error}'**
  String moviesOperationFailed(String error);

  /// No description provided for @moviesNoScannable.
  ///
  /// In zh, this message translates to:
  /// **'当前没有可扫描的影片'**
  String get moviesNoScannable;

  /// No description provided for @moviesScanSelectedTitle.
  ///
  /// In zh, this message translates to:
  /// **'扫描已选影片'**
  String get moviesScanSelectedTitle;

  /// No description provided for @moviesScanFilteredTitle.
  ///
  /// In zh, this message translates to:
  /// **'扫描筛选结果'**
  String get moviesScanFilteredTitle;

  /// No description provided for @moviesScanSelectedMessage.
  ///
  /// In zh, this message translates to:
  /// **'将扫描已选的 {count} 部影片，确定继续吗？'**
  String moviesScanSelectedMessage(int count);

  /// No description provided for @moviesScanFilteredMessage.
  ///
  /// In zh, this message translates to:
  /// **'将扫描当前筛选结果中的 {count} 部影片（包含全部分页），确定继续吗？'**
  String moviesScanFilteredMessage(int count);

  /// No description provided for @moviesStartScan.
  ///
  /// In zh, this message translates to:
  /// **'开始扫描'**
  String get moviesStartScan;

  /// No description provided for @moviesScanSubmitted.
  ///
  /// In zh, this message translates to:
  /// **'已提交 {count} 部影片{skipped}'**
  String moviesScanSubmitted(int count, String skipped);

  /// No description provided for @moviesScanSkipped.
  ///
  /// In zh, this message translates to:
  /// **'，跳过 {count} 部无效影片'**
  String moviesScanSkipped(int count);

  /// No description provided for @moviesScanCreateFailed.
  ///
  /// In zh, this message translates to:
  /// **'创建资源扫描任务失败：{error}'**
  String moviesScanCreateFailed(String error);

  /// No description provided for @moviesNeedSameNumber.
  ///
  /// In zh, this message translates to:
  /// **'需选择 2 部以上相同番号影片'**
  String get moviesNeedSameNumber;

  /// No description provided for @moviesSortSheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get moviesSortSheetTitle;

  /// No description provided for @moviesSortAscending.
  ///
  /// In zh, this message translates to:
  /// **'升序'**
  String get moviesSortAscending;

  /// No description provided for @moviesSortDescending.
  ///
  /// In zh, this message translates to:
  /// **'降序'**
  String get moviesSortDescending;

  /// No description provided for @moviesSortFileSize.
  ///
  /// In zh, this message translates to:
  /// **'文件大小'**
  String get moviesSortFileSize;

  /// No description provided for @moviesSortCreatedAt.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get moviesSortCreatedAt;

  /// No description provided for @moviesSortUpdatedAt.
  ///
  /// In zh, this message translates to:
  /// **'更新'**
  String get moviesSortUpdatedAt;

  /// No description provided for @moviesSortDownloadedAt.
  ///
  /// In zh, this message translates to:
  /// **'下载日期'**
  String get moviesSortDownloadedAt;

  /// No description provided for @moviesUpdatedStatus.
  ///
  /// In zh, this message translates to:
  /// **'更新状态'**
  String get moviesUpdatedStatus;

  /// No description provided for @moviesUpdated.
  ///
  /// In zh, this message translates to:
  /// **'已更新'**
  String get moviesUpdated;

  /// No description provided for @moviesNotUpdated.
  ///
  /// In zh, this message translates to:
  /// **'未更新'**
  String get moviesNotUpdated;

  /// No description provided for @moviesUnlimited.
  ///
  /// In zh, this message translates to:
  /// **'不限'**
  String get moviesUnlimited;

  /// No description provided for @moviesFavorite.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get moviesFavorite;

  /// No description provided for @moviesUnfavorite.
  ///
  /// In zh, this message translates to:
  /// **'取消收藏'**
  String get moviesUnfavorite;

  /// No description provided for @moviesBatchDownloadTitle.
  ///
  /// In zh, this message translates to:
  /// **'批量下载 {count} 部'**
  String moviesBatchDownloadTitle(int count);

  /// No description provided for @moviesBatchDownloadSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'按条件批量提交下载请求，缺失番号会自动跳过'**
  String get moviesBatchDownloadSubtitle;

  /// No description provided for @moviesDownloadQuality.
  ///
  /// In zh, this message translates to:
  /// **'画质偏好'**
  String get moviesDownloadQuality;

  /// No description provided for @moviesDownloadQualityHint.
  ///
  /// In zh, this message translates to:
  /// **'如 4k、hd、uhd 等，留空不限'**
  String get moviesDownloadQualityHint;

  /// No description provided for @moviesDownloadMinSize.
  ///
  /// In zh, this message translates to:
  /// **'最小大小 (MB)'**
  String get moviesDownloadMinSize;

  /// No description provided for @moviesDownloadMaxSize.
  ///
  /// In zh, this message translates to:
  /// **'最大大小 (MB)'**
  String get moviesDownloadMaxSize;

  /// No description provided for @moviesDownloadMaxFiles.
  ///
  /// In zh, this message translates to:
  /// **'最大文件数'**
  String get moviesDownloadMaxFiles;

  /// No description provided for @moviesDownloadDate.
  ///
  /// In zh, this message translates to:
  /// **'截止日期'**
  String get moviesDownloadDate;

  /// No description provided for @moviesDownloadNoLimit.
  ///
  /// In zh, this message translates to:
  /// **'0 = 不限'**
  String get moviesDownloadNoLimit;

  /// No description provided for @moviesDownloadRequireSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'要求字幕'**
  String get moviesDownloadRequireSubtitle;

  /// No description provided for @moviesDownloadRequireUncensored.
  ///
  /// In zh, this message translates to:
  /// **'要求无码'**
  String get moviesDownloadRequireUncensored;

  /// No description provided for @moviesDownloadWashMode.
  ///
  /// In zh, this message translates to:
  /// **'精洗模式'**
  String get moviesDownloadWashMode;

  /// No description provided for @moviesDownloadWashModeHint.
  ///
  /// In zh, this message translates to:
  /// **'已存在影片也重新下载'**
  String get moviesDownloadWashModeHint;

  /// No description provided for @moviesDownloadFailed.
  ///
  /// In zh, this message translates to:
  /// **'下载请求失败：{error}'**
  String moviesDownloadFailed(String error);

  /// No description provided for @moviesSubmitting.
  ///
  /// In zh, this message translates to:
  /// **'提交中…'**
  String get moviesSubmitting;

  /// No description provided for @moviesConfirmSubmit.
  ///
  /// In zh, this message translates to:
  /// **'确认提交'**
  String get moviesConfirmSubmit;

  /// No description provided for @moviesMergeStarted.
  ///
  /// In zh, this message translates to:
  /// **'已启动合并任务'**
  String get moviesMergeStarted;

  /// No description provided for @moviesMergeFailed.
  ///
  /// In zh, this message translates to:
  /// **'合并失败：{error}'**
  String moviesMergeFailed(String error);

  /// No description provided for @moviesMergeTitle.
  ///
  /// In zh, this message translates to:
  /// **'合并 {count} 部重复影片'**
  String moviesMergeTitle(int count);

  /// No description provided for @moviesMergeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择主导影片，其他相关文件会移到该影片所在目录'**
  String get moviesMergeSubtitle;

  /// No description provided for @moviesMergeWarning.
  ///
  /// In zh, this message translates to:
  /// **'同名视频文件会被覆盖，文件名冲突时非主导记录将被删除'**
  String get moviesMergeWarning;

  /// No description provided for @moviesMergeSameFolder.
  ///
  /// In zh, this message translates to:
  /// **'所有选中影片已在同一目录，无需合并'**
  String get moviesMergeSameFolder;

  /// No description provided for @moviesMerging.
  ///
  /// In zh, this message translates to:
  /// **'合并中…'**
  String get moviesMerging;

  /// No description provided for @moviesConfirmMerge.
  ///
  /// In zh, this message translates to:
  /// **'确认合并'**
  String get moviesConfirmMerge;

  /// No description provided for @moviesUntitled.
  ///
  /// In zh, this message translates to:
  /// **'未命名'**
  String get moviesUntitled;

  /// No description provided for @moviesNoCode.
  ///
  /// In zh, this message translates to:
  /// **'无番号'**
  String get moviesNoCode;

  /// No description provided for @moviesPathUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'路径不可用'**
  String get moviesPathUnavailable;

  /// No description provided for @moviesNfoSynced.
  ///
  /// In zh, this message translates to:
  /// **'NFO 已同步'**
  String get moviesNfoSynced;

  /// No description provided for @moviesApplyFailed.
  ///
  /// In zh, this message translates to:
  /// **'应用失败：{error}'**
  String moviesApplyFailed(String error);

  /// No description provided for @moviesCompareNfoTitle.
  ///
  /// In zh, this message translates to:
  /// **'比较重复 NFO'**
  String get moviesCompareNfoTitle;

  /// No description provided for @moviesCompareNfoSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'为每个字段选择同步来源'**
  String get moviesCompareNfoSubtitle;

  /// No description provided for @moviesCompareNfoNoChanges.
  ///
  /// In zh, this message translates to:
  /// **'影片标题、描述、概要、评分均一致，无需选择'**
  String get moviesCompareNfoNoChanges;

  /// No description provided for @moviesApplying.
  ///
  /// In zh, this message translates to:
  /// **'应用中…'**
  String get moviesApplying;

  /// No description provided for @moviesApplySync.
  ///
  /// In zh, this message translates to:
  /// **'应用同步'**
  String get moviesApplySync;

  /// No description provided for @moviesMovieWithId.
  ///
  /// In zh, this message translates to:
  /// **'影片 {id}'**
  String moviesMovieWithId(int id);

  /// No description provided for @moviesEmptyValue.
  ///
  /// In zh, this message translates to:
  /// **'(空)'**
  String get moviesEmptyValue;

  /// No description provided for @resourceScanTitle.
  ///
  /// In zh, this message translates to:
  /// **'扫描资源'**
  String get resourceScanTitle;

  /// No description provided for @resourceScanProgress.
  ///
  /// In zh, this message translates to:
  /// **'资源扫描进度'**
  String get resourceScanProgress;

  /// No description provided for @resourceScanConnecting.
  ///
  /// In zh, this message translates to:
  /// **'正在连接…'**
  String get resourceScanConnecting;

  /// No description provided for @resourceScanSuccess.
  ///
  /// In zh, this message translates to:
  /// **'成功'**
  String get resourceScanSuccess;

  /// No description provided for @resourceScanFailed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get resourceScanFailed;

  /// No description provided for @resourceScanNewResources.
  ///
  /// In zh, this message translates to:
  /// **'新资源'**
  String get resourceScanNewResources;

  /// No description provided for @resourceScanBackground.
  ///
  /// In zh, this message translates to:
  /// **'后台运行'**
  String get resourceScanBackground;

  /// No description provided for @resourceScanClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get resourceScanClose;

  /// No description provided for @resourceScanDone.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get resourceScanDone;

  /// No description provided for @resourceScanPreparing.
  ///
  /// In zh, this message translates to:
  /// **'准备中'**
  String get resourceScanPreparing;

  /// No description provided for @resourceScanRunning.
  ///
  /// In zh, this message translates to:
  /// **'扫描中'**
  String get resourceScanRunning;

  /// No description provided for @resourceScanCompleted.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get resourceScanCompleted;

  /// No description provided for @moviesNfoFieldTitle.
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get moviesNfoFieldTitle;

  /// No description provided for @moviesNfoFieldDescription.
  ///
  /// In zh, this message translates to:
  /// **'描述'**
  String get moviesNfoFieldDescription;

  /// No description provided for @moviesNfoFieldPlot.
  ///
  /// In zh, this message translates to:
  /// **'简介'**
  String get moviesNfoFieldPlot;

  /// No description provided for @moviesNfoFieldRating.
  ///
  /// In zh, this message translates to:
  /// **'评分'**
  String get moviesNfoFieldRating;

  /// No description provided for @moviesNfoFieldYear.
  ///
  /// In zh, this message translates to:
  /// **'年份'**
  String get moviesNfoFieldYear;

  /// No description provided for @moviesNfoFieldRuntime.
  ///
  /// In zh, this message translates to:
  /// **'时长'**
  String get moviesNfoFieldRuntime;

  /// No description provided for @moviesNfoFieldDate.
  ///
  /// In zh, this message translates to:
  /// **'日期'**
  String get moviesNfoFieldDate;

  /// No description provided for @subtitlePreviewFailed.
  ///
  /// In zh, this message translates to:
  /// **'预览失败：{error}'**
  String subtitlePreviewFailed(String error);

  /// No description provided for @subtitleDownloaded.
  ///
  /// In zh, this message translates to:
  /// **'已下载 {name}'**
  String subtitleDownloaded(String name);

  /// No description provided for @subtitleDownloadFailed.
  ///
  /// In zh, this message translates to:
  /// **'下载失败：{error}'**
  String subtitleDownloadFailed(String error);

  /// No description provided for @subtitleExistsTitle.
  ///
  /// In zh, this message translates to:
  /// **'字幕已存在'**
  String get subtitleExistsTitle;

  /// No description provided for @subtitleExistsMessage.
  ///
  /// In zh, this message translates to:
  /// **'同名字幕文件已存在，是否覆盖？'**
  String get subtitleExistsMessage;

  /// No description provided for @subtitlePreviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'字幕预览'**
  String get subtitlePreviewTitle;

  /// No description provided for @subtitleSearchTitle.
  ///
  /// In zh, this message translates to:
  /// **'获取字幕'**
  String get subtitleSearchTitle;

  /// No description provided for @subtitleSearchKeyword.
  ///
  /// In zh, this message translates to:
  /// **'关键词：{keyword}'**
  String subtitleSearchKeyword(String keyword);

  /// No description provided for @subtitleNoMatch.
  ///
  /// In zh, this message translates to:
  /// **'没有找到匹配的字幕'**
  String get subtitleNoMatch;

  /// No description provided for @subtitlePreview.
  ///
  /// In zh, this message translates to:
  /// **'预览'**
  String get subtitlePreview;

  /// No description provided for @subtitleDownload.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get subtitleDownload;

  /// No description provided for @subtitleCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get subtitleCopy;

  /// No description provided for @subtitleCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制全部内容'**
  String get subtitleCopied;

  /// No description provided for @audioExtractTitle.
  ///
  /// In zh, this message translates to:
  /// **'提取音频'**
  String get audioExtractTitle;

  /// No description provided for @audioExtractFormat.
  ///
  /// In zh, this message translates to:
  /// **'输出格式'**
  String get audioExtractFormat;

  /// No description provided for @audioExtractBitrate.
  ///
  /// In zh, this message translates to:
  /// **'目标码率'**
  String get audioExtractBitrate;

  /// No description provided for @audioExtractFailed.
  ///
  /// In zh, this message translates to:
  /// **'音频提取任务创建失败'**
  String get audioExtractFailed;

  /// No description provided for @audioExtractSubmitting.
  ///
  /// In zh, this message translates to:
  /// **'提交中…'**
  String get audioExtractSubmitting;

  /// No description provided for @audioExtractSubmit.
  ///
  /// In zh, this message translates to:
  /// **'提交任务'**
  String get audioExtractSubmit;

  /// No description provided for @dboAppliedFields.
  ///
  /// In zh, this message translates to:
  /// **'已应用 {count} 个字段'**
  String dboAppliedFields(int count);

  /// No description provided for @dboApplyFailed.
  ///
  /// In zh, this message translates to:
  /// **'应用失败：{error}'**
  String dboApplyFailed(String error);

  /// No description provided for @dboTitle.
  ///
  /// In zh, this message translates to:
  /// **'DB Online 元数据'**
  String get dboTitle;

  /// No description provided for @dboUpToDate.
  ///
  /// In zh, this message translates to:
  /// **'本地元数据已是最新'**
  String get dboUpToDate;

  /// No description provided for @dboNoOverridableFields.
  ///
  /// In zh, this message translates to:
  /// **'没有可覆盖的字段'**
  String get dboNoOverridableFields;

  /// No description provided for @dboSelectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get dboSelectAll;

  /// No description provided for @dboClear.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get dboClear;

  /// No description provided for @dboApplyCount.
  ///
  /// In zh, this message translates to:
  /// **'应用 ({count})'**
  String dboApplyCount(int count);

  /// No description provided for @dboSelectFields.
  ///
  /// In zh, this message translates to:
  /// **'请选择字段'**
  String get dboSelectFields;

  /// No description provided for @dboCurrent.
  ///
  /// In zh, this message translates to:
  /// **'当前：'**
  String get dboCurrent;

  /// No description provided for @dboSectionInfo.
  ///
  /// In zh, this message translates to:
  /// **'影片信息'**
  String get dboSectionInfo;

  /// No description provided for @dboSectionSeries.
  ///
  /// In zh, this message translates to:
  /// **'系列'**
  String get dboSectionSeries;

  /// No description provided for @dboSectionGenres.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get dboSectionGenres;

  /// No description provided for @dboSectionActors.
  ///
  /// In zh, this message translates to:
  /// **'演员'**
  String get dboSectionActors;

  /// No description provided for @dboFemale.
  ///
  /// In zh, this message translates to:
  /// **'女'**
  String get dboFemale;

  /// No description provided for @dboMale.
  ///
  /// In zh, this message translates to:
  /// **'男'**
  String get dboMale;

  /// No description provided for @dboFieldTitle.
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get dboFieldTitle;

  /// No description provided for @dboFieldRating.
  ///
  /// In zh, this message translates to:
  /// **'评分'**
  String get dboFieldRating;

  /// No description provided for @dboFieldYear.
  ///
  /// In zh, this message translates to:
  /// **'年份'**
  String get dboFieldYear;

  /// No description provided for @dboFieldRuntime.
  ///
  /// In zh, this message translates to:
  /// **'时长'**
  String get dboFieldRuntime;

  /// No description provided for @dboFieldPlot.
  ///
  /// In zh, this message translates to:
  /// **'剧情简介'**
  String get dboFieldPlot;

  /// No description provided for @dboRemove.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get dboRemove;

  /// No description provided for @movieEditorQuickActions.
  ///
  /// In zh, this message translates to:
  /// **'封面水印 · 快捷操作'**
  String get movieEditorQuickActions;

  /// No description provided for @movieEditorFanartCrop.
  ///
  /// In zh, this message translates to:
  /// **'封面裁剪 (Fanart)'**
  String get movieEditorFanartCrop;

  /// No description provided for @movieEditorTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑影片'**
  String get movieEditorTitle;

  /// No description provided for @movieEditorOriginalTitle.
  ///
  /// In zh, this message translates to:
  /// **'原标题'**
  String get movieEditorOriginalTitle;

  /// No description provided for @movieEditorNumber.
  ///
  /// In zh, this message translates to:
  /// **'番号'**
  String get movieEditorNumber;

  /// No description provided for @movieEditorYear.
  ///
  /// In zh, this message translates to:
  /// **'年份'**
  String get movieEditorYear;

  /// No description provided for @movieEditorRating.
  ///
  /// In zh, this message translates to:
  /// **'评分'**
  String get movieEditorRating;

  /// No description provided for @movieEditorRuntime.
  ///
  /// In zh, this message translates to:
  /// **'时长 (min)'**
  String get movieEditorRuntime;

  /// No description provided for @movieEditorSeries.
  ///
  /// In zh, this message translates to:
  /// **'系列'**
  String get movieEditorSeries;

  /// No description provided for @movieEditorGenre.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get movieEditorGenre;

  /// No description provided for @movieEditorTag.
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get movieEditorTag;

  /// No description provided for @movieEditorActor.
  ///
  /// In zh, this message translates to:
  /// **'演员'**
  String get movieEditorActor;

  /// No description provided for @movieEditorFieldTitle.
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get movieEditorFieldTitle;

  /// No description provided for @movieEditorFieldCountry.
  ///
  /// In zh, this message translates to:
  /// **'国家'**
  String get movieEditorFieldCountry;

  /// No description provided for @movieEditorFieldPlot.
  ///
  /// In zh, this message translates to:
  /// **'简介'**
  String get movieEditorFieldPlot;

  /// No description provided for @movieEditorSelectEntity.
  ///
  /// In zh, this message translates to:
  /// **'点击选择{entity}'**
  String movieEditorSelectEntity(String entity);

  /// No description provided for @movieEditorUntitledEntity.
  ///
  /// In zh, this message translates to:
  /// **'未命名{entity}'**
  String movieEditorUntitledEntity(String entity);

  /// No description provided for @movieEditorQuickActionFailed.
  ///
  /// In zh, this message translates to:
  /// **'快捷操作失败：{error}'**
  String movieEditorQuickActionFailed(String error);

  /// No description provided for @movieEditorBatchTranslating.
  ///
  /// In zh, this message translates to:
  /// **'批量翻译中'**
  String get movieEditorBatchTranslating;

  /// No description provided for @movieEditorBatchTranslate.
  ///
  /// In zh, this message translates to:
  /// **'批量翻译'**
  String get movieEditorBatchTranslate;

  /// No description provided for @movieEditorFieldEmpty.
  ///
  /// In zh, this message translates to:
  /// **'{label} 内容为空，无需翻译'**
  String movieEditorFieldEmpty(String label);

  /// No description provided for @movieEditorTranslationEmpty.
  ///
  /// In zh, this message translates to:
  /// **'{label} 翻译为空'**
  String movieEditorTranslationEmpty(String label);

  /// No description provided for @movieEditorTranslationSuccess.
  ///
  /// In zh, this message translates to:
  /// **'{label} 翻译成功'**
  String movieEditorTranslationSuccess(String label);

  /// No description provided for @movieEditorTranslationFailed.
  ///
  /// In zh, this message translates to:
  /// **'{label} 翻译失败：{error}'**
  String movieEditorTranslationFailed(String label, String error);

  /// No description provided for @movieEditorNoTranslatableContent.
  ///
  /// In zh, this message translates to:
  /// **'没有可翻译的内容'**
  String get movieEditorNoTranslatableContent;

  /// No description provided for @movieEditorBatchResult.
  ///
  /// In zh, this message translates to:
  /// **'批量翻译：成功 {success} / {total}'**
  String movieEditorBatchResult(int success, int total);

  /// No description provided for @movieEditorBatchNoResult.
  ///
  /// In zh, this message translates to:
  /// **'批量翻译未返回结果'**
  String get movieEditorBatchNoResult;

  /// No description provided for @movieEditorBatchFailed.
  ///
  /// In zh, this message translates to:
  /// **'批量翻译失败：{error}'**
  String movieEditorBatchFailed(String error);

  /// No description provided for @movieEditorTranslating.
  ///
  /// In zh, this message translates to:
  /// **'翻译中'**
  String get movieEditorTranslating;

  /// No description provided for @resourceSourceDetail.
  ///
  /// In zh, this message translates to:
  /// **'影片详情资源'**
  String get resourceSourceDetail;

  /// No description provided for @resourceSourceCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义资源'**
  String get resourceSourceCustom;

  /// No description provided for @resourceSourceNyaa.
  ///
  /// In zh, this message translates to:
  /// **'Nyaa 资源'**
  String get resourceSourceNyaa;

  /// No description provided for @resourceNoDownloaders.
  ///
  /// In zh, this message translates to:
  /// **'未配置可用下载器'**
  String get resourceNoDownloaders;

  /// No description provided for @resourceSelectDownloader.
  ///
  /// In zh, this message translates to:
  /// **'选择下载器'**
  String get resourceSelectDownloader;

  /// No description provided for @resourcePushFailed.
  ///
  /// In zh, this message translates to:
  /// **'推送失败：{error}'**
  String resourcePushFailed(String error);

  /// No description provided for @resourceOnline.
  ///
  /// In zh, this message translates to:
  /// **'在线资源'**
  String get resourceOnline;

  /// No description provided for @resourceMagnetCount.
  ///
  /// In zh, this message translates to:
  /// **'磁力 ({count})'**
  String resourceMagnetCount(int count);

  /// No description provided for @resourceEd2kCount.
  ///
  /// In zh, this message translates to:
  /// **'ED2K ({count})'**
  String resourceEd2kCount(int count);

  /// No description provided for @resourceLoadingOnline.
  ///
  /// In zh, this message translates to:
  /// **'正在加载在线资源…'**
  String get resourceLoadingOnline;

  /// No description provided for @resourceWaitingSources.
  ///
  /// In zh, this message translates to:
  /// **'已返回的渠道暂无资源，继续等待其他渠道…'**
  String get resourceWaitingSources;

  /// No description provided for @resourceNoMagnet.
  ///
  /// In zh, this message translates to:
  /// **'没有磁力资源'**
  String get resourceNoMagnet;

  /// No description provided for @resourceNoEd2k.
  ///
  /// In zh, this message translates to:
  /// **'没有 ED2K 资源'**
  String get resourceNoEd2k;

  /// No description provided for @resourceFallbackTitle.
  ///
  /// In zh, this message translates to:
  /// **'资源'**
  String get resourceFallbackTitle;

  /// No description provided for @resourceFrom.
  ///
  /// In zh, this message translates to:
  /// **'来自 {source}'**
  String resourceFrom(String source);

  /// No description provided for @resourceCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get resourceCopy;

  /// No description provided for @resourceCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制'**
  String get resourceCopied;

  /// No description provided for @resourcePushing.
  ///
  /// In zh, this message translates to:
  /// **'推送中'**
  String get resourcePushing;

  /// No description provided for @resourcePushDownload.
  ///
  /// In zh, this message translates to:
  /// **'推送下载'**
  String get resourcePushDownload;

  /// No description provided for @resourceRecentlyDownloaded.
  ///
  /// In zh, this message translates to:
  /// **'最近下载 {value}'**
  String resourceRecentlyDownloaded(String value);

  /// No description provided for @resourceRecentlyDownloadedAt.
  ///
  /// In zh, this message translates to:
  /// **'最近下载 {date}'**
  String resourceRecentlyDownloadedAt(String date);

  /// No description provided for @playerBuffering.
  ///
  /// In zh, this message translates to:
  /// **'正在缓冲…'**
  String get playerBuffering;

  /// No description provided for @audioNotificationChannelName.
  ///
  /// In zh, this message translates to:
  /// **'音乐播放'**
  String get audioNotificationChannelName;

  /// No description provided for @audioNotificationChannelDescription.
  ///
  /// In zh, this message translates to:
  /// **'文件管理器音乐播放控制'**
  String get audioNotificationChannelDescription;

  /// No description provided for @audioUnknownTitle.
  ///
  /// In zh, this message translates to:
  /// **'未知音频'**
  String get audioUnknownTitle;

  /// No description provided for @audioFileManagerAlbum.
  ///
  /// In zh, this message translates to:
  /// **'文件管理器'**
  String get audioFileManagerAlbum;

  /// No description provided for @audioPlaybackFailed.
  ///
  /// In zh, this message translates to:
  /// **'音频播放失败：{error}'**
  String audioPlaybackFailed(String error);

  /// No description provided for @audioPlaybackFailedGeneric.
  ///
  /// In zh, this message translates to:
  /// **'音频播放失败'**
  String get audioPlaybackFailedGeneric;

  /// No description provided for @personNoMovies.
  ///
  /// In zh, this message translates to:
  /// **'没有该演员的影片'**
  String get personNoMovies;

  /// No description provided for @personSyncAssociations.
  ///
  /// In zh, this message translates to:
  /// **'同步演员关联'**
  String get personSyncAssociations;

  /// No description provided for @mediaBrowserSimilar.
  ///
  /// In zh, this message translates to:
  /// **'更多类似'**
  String get mediaBrowserSimilar;

  /// No description provided for @posterCropEnableHint.
  ///
  /// In zh, this message translates to:
  /// **'勾选上方快捷操作启用裁剪'**
  String get posterCropEnableHint;

  /// No description provided for @posterCropGestureHint.
  ///
  /// In zh, this message translates to:
  /// **'左右拖动或点击定位裁剪范围'**
  String get posterCropGestureHint;

  /// No description provided for @playerLandscapeCameraLeft.
  ///
  /// In zh, this message translates to:
  /// **'摄像头在左侧'**
  String get playerLandscapeCameraLeft;

  /// No description provided for @playerLandscapeCameraRight.
  ///
  /// In zh, this message translates to:
  /// **'摄像头在右侧'**
  String get playerLandscapeCameraRight;

  /// No description provided for @playerOrientationUnchanged.
  ///
  /// In zh, this message translates to:
  /// **'无变化'**
  String get playerOrientationUnchanged;

  /// No description provided for @playerOrientationForceLandscape.
  ///
  /// In zh, this message translates to:
  /// **'强制横屏'**
  String get playerOrientationForceLandscape;

  /// No description provided for @playerOrientationForcePortrait.
  ///
  /// In zh, this message translates to:
  /// **'强制竖屏'**
  String get playerOrientationForcePortrait;

  /// No description provided for @playerPreload250Mb.
  ///
  /// In zh, this message translates to:
  /// **'250MB'**
  String get playerPreload250Mb;

  /// No description provided for @playerPreload500Mb.
  ///
  /// In zh, this message translates to:
  /// **'500MB'**
  String get playerPreload500Mb;

  /// No description provided for @playerPreload750Mb.
  ///
  /// In zh, this message translates to:
  /// **'750MB'**
  String get playerPreload750Mb;

  /// No description provided for @playerPreload1Gb.
  ///
  /// In zh, this message translates to:
  /// **'1GB'**
  String get playerPreload1Gb;

  /// No description provided for @hapticIntensityOff.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get hapticIntensityOff;

  /// No description provided for @hapticIntensityLow.
  ///
  /// In zh, this message translates to:
  /// **'轻'**
  String get hapticIntensityLow;

  /// No description provided for @hapticIntensityStandard.
  ///
  /// In zh, this message translates to:
  /// **'标准'**
  String get hapticIntensityStandard;

  /// No description provided for @hapticIntensityHigh.
  ///
  /// In zh, this message translates to:
  /// **'强'**
  String get hapticIntensityHigh;

  /// No description provided for @favoriteListAllTimeBest.
  ///
  /// In zh, this message translates to:
  /// **'最爱'**
  String get favoriteListAllTimeBest;

  /// No description provided for @favoriteListAfterHours.
  ///
  /// In zh, this message translates to:
  /// **'私藏'**
  String get favoriteListAfterHours;
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
