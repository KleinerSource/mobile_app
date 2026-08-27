// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Oh-My-Media';

  @override
  String get tabHome => 'Home';

  @override
  String get tabLibrary => 'Library';

  @override
  String get tabSearch => 'Search';

  @override
  String get tabYou => 'You';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get greetingNight => 'Late night picks';

  @override
  String get homePickupTitle => 'Pick up where you left off';

  @override
  String get homeFreshTitle => 'Fresh in your library';

  @override
  String get homeYourLibraries => 'Your libraries';

  @override
  String get homeSeeAll => 'See all';

  @override
  String get homeResume => 'Resume';

  @override
  String homeMinutesLeft(int n) {
    return '${n}m left';
  }

  @override
  String get libraryTitle => 'Library';

  @override
  String libraryCount(int n) {
    return '$n titles';
  }

  @override
  String get libraryCountSuffix => 'titles';

  @override
  String get filterAll => 'All';

  @override
  String get filterRecent => 'Recent';

  @override
  String get filterRating => 'Rating';

  @override
  String get filterTopRated => 'Top rated';

  @override
  String get filterUnwatched => 'Unwatched';

  @override
  String get viewGrid => 'Grid';

  @override
  String get viewList => 'List';

  @override
  String get searchHintAll => 'Search titles, people, tags';

  @override
  String resultsSortedBy(int n, String sort) {
    return '$n results · sorted by $sort';
  }

  @override
  String sortedByOnly(String sort) {
    return 'Sorted by $sort';
  }

  @override
  String get loadFailed => 'Load failed';

  @override
  String get loadFailedRetry => 'Load failed, tap to retry';

  @override
  String get noResultFound => 'No matching titles';

  @override
  String get watchedDone => 'Watched';

  @override
  String get sortByCreatedAt => 'created at';

  @override
  String get sortByRating => 'rating';

  @override
  String get sortByTitle => 'title';

  @override
  String get sortByYear => 'year';

  @override
  String get sortByReleaseDate => 'release date';

  @override
  String get searchHint2 => 'Title / cast / code / tag';

  @override
  String searchFailed(String error) {
    return 'Search failed: $error';
  }

  @override
  String get favoritesTitle => 'Favorites';

  @override
  String favoritesSubtitle(int n, int l) {
    return '$n saved · across $l lists';
  }

  @override
  String get statSaved => 'Saved';

  @override
  String get statWatched => 'Watched';

  @override
  String get statHours => 'Hours';

  @override
  String get yourLists => 'Your lists';

  @override
  String get newList => '+ New list';

  @override
  String get allFavorites => 'All favorites';

  @override
  String get upNext => 'Up next';

  @override
  String get watchlist => 'Watchlist';

  @override
  String selectedN(int n) {
    return '$n selected';
  }

  @override
  String get remove => 'Remove';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get back => 'Back';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchFind => 'Find anything';

  @override
  String get searchEmpty => 'Type to start searching';

  @override
  String get searchNoResult => 'No matching content';

  @override
  String get searchModeTitle => 'Movies';

  @override
  String get searchModeList => 'List search';

  @override
  String get searchModeActorSearch => 'Actor search';

  @override
  String get searchModeSeries => 'Series search';

  @override
  String get searchModeNum => 'Code';

  @override
  String get searchModeActor => 'Actor';

  @override
  String get searchModeFilename => 'Filename';

  @override
  String get searchPlaceholderTitle => 'Search movie titles...';

  @override
  String get searchPlaceholderList => 'Search titles, codes, or actors...';

  @override
  String get searchPlaceholderSeries => 'Search series names...';

  @override
  String get searchPlaceholderNum => 'Search codes...';

  @override
  String get searchPlaceholderActor => 'Search actors...';

  @override
  String get searchPlaceholderFilename => 'Search filenames...';

  @override
  String get detailPlay => 'Play';

  @override
  String get detailAddList => '+ List';

  @override
  String get detailTrailer => 'Trailer';

  @override
  String get detailCast => 'Cast';

  @override
  String get detailDetails => 'Details';

  @override
  String get detailFilmography => 'Filmography';

  @override
  String get detailFavorited => 'Added to favorites';

  @override
  String get detailUnfavorited => 'Removed from favorites';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsPreferences => 'Preferences';

  @override
  String get settingsGroupServer => 'Server';

  @override
  String get settingsGroupLibrary => 'Library';

  @override
  String get settingsGroupSystem => 'System configuration';

  @override
  String get settingsGroupMappings => 'Mapping rules';

  @override
  String get settingsGroupTools => 'Tools';

  @override
  String get settingsGroupPrivacy => 'Privacy';

  @override
  String get settingsGroupAbout => 'About';

  @override
  String get settingsServerSettings => 'Server settings';

  @override
  String get settingsServerSettingsSub =>
      'Server / system configuration / library / mapping rules / tools';

  @override
  String get settingsAppSettings => 'App settings';

  @override
  String get settingsAppSettingsSub =>
      'Language / privacy / display preferences';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSub => 'Light / dark appearance';

  @override
  String get themeSystem => 'Follow system';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsBadgePositions => 'Cover badge positions';

  @override
  String get settingsBadgePositionsSub =>
      'Rating / subtitle / crack / resolution / new resources';

  @override
  String get badgeRating => 'Rating';

  @override
  String get badgeSubtitle => 'Subtitle';

  @override
  String get badgeCrack => 'Crack';

  @override
  String get badgeResolution => 'Resolution';

  @override
  String get badgeNewResources => 'New resources';

  @override
  String get badgeHidden => 'Hidden';

  @override
  String get previewTitle => 'Preview';

  @override
  String get badgeOffsetTitle => 'Fine tuning';

  @override
  String get badgeOffsetHorizontal => 'Horizontal';

  @override
  String get badgeOffsetVertical => 'Vertical';

  @override
  String get cornerTopLeft => 'Top left';

  @override
  String get cornerTopRight => 'Top right';

  @override
  String get cornerBottomLeft => 'Bottom left';

  @override
  String get cornerBottomRight => 'Bottom right';

  @override
  String get settingsServerUrl => 'Server URL';

  @override
  String get settingsServerNotConfigured => 'Not configured';

  @override
  String get settingsLibraries => 'Libraries';

  @override
  String get settingsLibrariesSub => 'Add / edit / scan';

  @override
  String get libraryEditorName => 'Name';

  @override
  String get libraryEditorDirectories => 'Directories';

  @override
  String get settingsActors => 'Actor management';

  @override
  String get settingsActorsSub => 'Actor metadata and movie relationships';

  @override
  String get settingsGenres => 'Genres';

  @override
  String get settingsTags => 'Tags';

  @override
  String get settingsSeries => 'Series';

  @override
  String get settingsTranslation => 'Translation';

  @override
  String get settingsTranslationSub =>
      'ChatGPT API · auto translate titles/plot';

  @override
  String get settingsMappingTags => 'Tags mapping';

  @override
  String get settingsMappingGenres => 'Genres mapping';

  @override
  String get settingsMappingSeries => 'Series mapping';

  @override
  String get settingsMappingSub => 'Rename / delete rules';

  @override
  String get settingsActorAssociations => 'Actor associations';

  @override
  String get settingsActorAssociationsSub =>
      'Canonical name + aliases, sync actor associations';

  @override
  String get settingsDbo => 'DB Online data source';

  @override
  String get settingsDboSub => 'Movie download / sync actor associations';

  @override
  String get settingsExtensions => 'Video extensions';

  @override
  String get settingsExtensionsSub => 'File suffixes recognized by scanner';

  @override
  String get settingsPrivacyShield => 'Privacy shield';

  @override
  String get settingsPrivacyShieldSub => 'Mask preview when in background';

  @override
  String get settingsShakePrivacy => 'Shake to toggle privacy mode';

  @override
  String get settingsShakePrivacySub =>
      'Shake the device to turn privacy mode on or off';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSub => 'Interface language';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsLogout => 'Log out';

  @override
  String get playerEnginePickerTitle => 'Choose player';

  @override
  String get playerEnginePickerSubtitle =>
      'Applies to this playback only and does not change your default';

  @override
  String get playerEnginePickerDefaultBadge => 'Default';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageZh => '简体中文';

  @override
  String get languageEn => 'English';

  @override
  String get privacyLockedTitle => 'Locked';

  @override
  String get privacyMode => 'PRIVACY MODE';
}
