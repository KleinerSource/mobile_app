// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Oh My Media';

  @override
  String get tabHome => 'Home';

  @override
  String get tabLibrary => 'Library';

  @override
  String get tabSearch => 'Search';

  @override
  String get tabYou => 'You';

  @override
  String get tabFiles => 'Files';

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
  String get settingsServerSettingsSub => 'Media library settings';

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

  @override
  String get fileEyebrow => 'Files';

  @override
  String get fileListTitle => 'Files';

  @override
  String get fileSelectTargetDirectory => 'Choose destination folder';

  @override
  String get fileSelectThisDirectory => 'Select this folder';

  @override
  String get fileBatchActions => 'Batch actions';

  @override
  String get fileMoreActions => 'More';

  @override
  String get fileForceRefresh => 'Force refresh';

  @override
  String get fileCreateDirectory => 'New folder';

  @override
  String get fileUpload => 'Upload file';

  @override
  String get fileSelect => 'Select';

  @override
  String get fileShowHidden => 'Show hidden files';

  @override
  String get fileSortName => 'Name';

  @override
  String get fileSortDate => 'Date';

  @override
  String get fileSortSize => 'Size';

  @override
  String get fileSortCategory => 'Type';

  @override
  String fileSortBy(String label) {
    return 'Sort by $label';
  }

  @override
  String fileSortByAsc(String label) {
    return 'Sort by $label ↑';
  }

  @override
  String fileSortByDesc(String label) {
    return 'Sort by $label ↓';
  }

  @override
  String get fileExitSelection => 'Exit selection';

  @override
  String get fileCancelPicker => 'Cancel';

  @override
  String get fileBackToParent => 'Go up one level';

  @override
  String get fileBackToServers => 'Back to server selection';

  @override
  String get fileRootDirectory => 'Root';

  @override
  String get fileEmptyDirectory => 'This folder is empty';

  @override
  String get fileFavoritesSection => 'Favorites';

  @override
  String get fileFavoritesEmpty =>
      'No favorite files or folders yet. Use the file menu to save frequent items';

  @override
  String get fileFavoriteDirectoriesSection => 'Favorite folders';

  @override
  String get fileAllFilesSection => 'All files';

  @override
  String get fileUnfavorite => 'Remove from favorites';

  @override
  String get fileFavorite => 'Favorite';

  @override
  String fileFavoriteAdded(String name) {
    return 'Added \"$name\" to favorites';
  }

  @override
  String fileFavoriteRemoved(String name) {
    return 'Removed \"$name\" from favorites';
  }

  @override
  String get fileEntryActions => 'File actions';

  @override
  String get fileDetails => 'Details';

  @override
  String get fileRename => 'Rename';

  @override
  String get fileMove => 'Move';

  @override
  String get fileSelectAll => 'Select all';

  @override
  String get fileClearSelection => 'Clear';

  @override
  String get fileDeleteSelected => 'Delete selected';

  @override
  String get fileFolderNameLabel => 'Folder name';

  @override
  String get fileCreateDirectoryFailed => 'Failed to create folder';

  @override
  String get fileLocalPathLabel => 'Local file path';

  @override
  String get fileLocalFileMissing => 'Local file does not exist';

  @override
  String get fileUploadFailed => 'Upload failed';

  @override
  String get fileUploadDone => 'Upload complete';

  @override
  String get fileUploadCanceled => 'Upload canceled';

  @override
  String get fileNewNameLabel => 'New name';

  @override
  String get fileRenameFailed => 'Failed to rename';

  @override
  String get fileMoveFailed => 'Failed to move';

  @override
  String get fileInvalidMoveTarget =>
      'A folder cannot be moved into itself or one of its subfolders';

  @override
  String get fileBatchMoveFailed => 'Batch move failed';

  @override
  String get fileTargetExists => 'Target already exists';

  @override
  String fileBatchOverwritePrompt(int count, String action) {
    return '$count target(s) already exist. Overwrite and continue with $action?';
  }

  @override
  String fileOverwritePrompt(String path) {
    return 'Overwrite \"$path\"?';
  }

  @override
  String get fileOverwrite => 'Overwrite';

  @override
  String get fileBatchRenameFailed => 'Batch rename failed';

  @override
  String get fileNoRenameChanges => 'No applicable name changes';

  @override
  String get fileRenameDuplicatePreview =>
      'The preview contains duplicate names. Adjust the rename rules.';

  @override
  String get fileRenameCollision =>
      'Cannot batch rename to an existing name of another selected item';

  @override
  String get fileBatchRenameTitle => 'Batch rename';

  @override
  String get fileBatchRenameSubtitle => 'Pick a rule and preview the result';

  @override
  String get fileRenameMode => 'Rename mode';

  @override
  String get fileRenameModeReplace => 'Replace text';

  @override
  String get fileRenameModeAdd => 'Add text';

  @override
  String get fileRenameSearchLabel => 'Find';

  @override
  String get fileRenameReplaceLabel => 'Replace with';

  @override
  String get fileRenameAddTextLabel => 'Text to add';

  @override
  String get fileRenameAddPosition => 'Position';

  @override
  String get fileRenameAddBefore => 'Before the name';

  @override
  String get fileRenameAddAfter => 'After the name';

  @override
  String get filePreviewSection => 'Preview';

  @override
  String get fileApply => 'Apply';

  @override
  String get fileDeleteConfirmTitle => 'Delete?';

  @override
  String fileDeleteConfirmBody(String name) {
    return 'This will delete \"$name\" from the remote file source. This cannot be undone.';
  }

  @override
  String get fileDeleteFailed => 'Delete failed';

  @override
  String get fileBatchDeleteConfirmTitle => 'Delete selected?';

  @override
  String fileBatchDeleteConfirmBody(int n) {
    return 'This will delete the $n selected item(s) from the remote file source. This cannot be undone.';
  }

  @override
  String get fileBatchDeleteFailed => 'Batch delete failed';

  @override
  String get fileDirectoryDetails => 'Folder details';

  @override
  String get fileFileDetails => 'File details';

  @override
  String filePathLabel(String path) {
    return 'Path: $path';
  }

  @override
  String fileSizeLabel(String size) {
    return 'Size: $size';
  }

  @override
  String fileTypeLabel(String type) {
    return 'Type: $type';
  }

  @override
  String fileModifiedAtLabel(String time) {
    return 'Modified: $time';
  }

  @override
  String get fileWebDavDirectUrlMissing =>
      'The server did not provide a direct HTTP URL. Playback stopped (no fallback to the local proxy).';

  @override
  String fileVideoPreviewFailed(String error) {
    return 'Video preview failed: $error';
  }

  @override
  String fileAudioPreviewFailed(String error) {
    return 'Audio preview failed: $error';
  }

  @override
  String fileImagePreviewFailed(String error) {
    return 'Image preview failed: $error';
  }

  @override
  String fileTextPreviewFailed(String error) {
    return 'Text preview failed: $error';
  }

  @override
  String get fileOpenAsText => 'Open as text';

  @override
  String get fileTextEdit => 'Edit';

  @override
  String get fileTextSave => 'Save';

  @override
  String get fileTextSaving => 'Saving...';

  @override
  String get fileTextSaveSuccess => 'Saved';

  @override
  String fileTextSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get fileTextUnsavedTitle => 'Unsaved changes';

  @override
  String get fileTextUnsavedMessage =>
      'You have unsaved changes. Save before leaving?';

  @override
  String get fileTextDiscard => 'Discard changes';

  @override
  String get fileTextSaveAndLeave => 'Save and leave';

  @override
  String get fileRetry => 'Retry';

  @override
  String get fileUploadAction => 'Upload';

  @override
  String get fileFileOperation => 'File operation';

  @override
  String fileOperationRunning(String action) {
    return '$action in progress';
  }

  @override
  String fileOperationCompleted(String action) {
    return '$action complete';
  }

  @override
  String fileOperationCanceled(String action) {
    return '$action canceled';
  }

  @override
  String fileOperationFailed(String action) {
    return '$action failed';
  }

  @override
  String fileOperationPending(String action) {
    return '$action pending';
  }

  @override
  String get filePlaybackProgress => 'Playback progress';

  @override
  String get fileNotFileServer => 'The current server is not a file server';

  @override
  String get fileChooseFileServer => 'Choose a file server';

  @override
  String get fileNoAvailableSource => 'No available file source on this server';

  @override
  String get fileManageServers => 'Manage servers';

  @override
  String get settingsGroupGeneral => 'General';

  @override
  String get settingsGroupFileManager => 'File manager';

  @override
  String get settingsGroupPlayer => 'Player';

  @override
  String get settingsSecurity => 'Security';

  @override
  String get settingsSecuritySub =>
      'Face ID / fingerprint, app lock, gesture password';

  @override
  String get settingsPosterBadges => 'Poster badge display';

  @override
  String get settingsPosterBadgesSub =>
      'Codec / HDR / STRM / Subtitles / Crack / HD';

  @override
  String get settingsPlayerSettings => 'Player settings';

  @override
  String get settingsPlayerSettingsSub =>
      'Progress / orientation / OSD / buttons / haptics';

  @override
  String get settingsSubtitleSettings => 'Subtitle settings';

  @override
  String get settingsSubtitleSettingsSub =>
      'Memory / font / color / outline / shadow';

  @override
  String get settingsCacheManagement => 'Cache management';

  @override
  String get settingsCacheManagementSub =>
      'Disk cache limit / categories / cleanup';

  @override
  String get settingsPerformanceMonitor => 'Performance monitor';

  @override
  String get settingsPerformanceMonitorSub =>
      'Show FPS, app CPU, and RAM usage';

  @override
  String get settingsHapticIntensity => 'Haptic intensity';

  @override
  String settingsHapticCurrent(String label) {
    return 'Current: $label';
  }

  @override
  String get settingsImagePreview => 'Image thumbnails';

  @override
  String get settingsImagePreviewSub =>
      'Show image thumbnails in the file list';

  @override
  String get settingsMoveStartLocation => 'Move start location';

  @override
  String get settingsMoveStartCurrentRoot => 'Current: Root';

  @override
  String get settingsMoveStartCurrentHere => 'Current: Current folder';

  @override
  String get settingsMoveStartHere => 'Current folder';

  @override
  String get settingsMoveStartRootSub =>
      'Always pick a move destination starting from the root folder';

  @override
  String get settingsMoveStartHereSub =>
      'Pick a move destination starting from the folder you are in';

  @override
  String fileSelectedItems(int n) {
    return '$n selected';
  }

  @override
  String get playerShuffleOn => 'Turn on shuffle';

  @override
  String get playerShuffleOff => 'Turn off shuffle';

  @override
  String get playerRepeatOff => 'Repeat: Off';

  @override
  String get playerRepeatOne => 'Repeat: One';

  @override
  String get playerRepeatAll => 'Repeat: All';

  @override
  String get playerLyricsTitle => 'Lyrics';

  @override
  String get playerLyricsUnavailable => 'No lyrics';

  @override
  String get playerDjDeck => 'DJ deck';

  @override
  String get playerDjDeckA => 'DECK A';

  @override
  String get playerDjPlaying => 'Playing';

  @override
  String get playerDjPaused => 'Paused';

  @override
  String get playerDjGestureHint =>
      'Tap to play or pause, rotate the record to seek';

  @override
  String get playerDjPitch => 'Pitch';

  @override
  String get playerClose => 'Close';
}
