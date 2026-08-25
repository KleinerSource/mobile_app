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
  /// **'Oh-My-Media'**
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
  /// **'服务器 / 系统配置 / 媒体库 / 映射规则 / 工具'**
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
