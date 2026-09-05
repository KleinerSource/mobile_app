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
  String get more => 'More';

  @override
  String get close => 'Close';

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
      'Rating / subtitle, crack, resolution / new resources';

  @override
  String get badgeRating => 'Rating';

  @override
  String get badgeContentGroup => 'Subtitle / crack / resolution';

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
  String get badgePositionController => 'Unified corner controller';

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
  String get settingsServerSelectionShowUsername => 'Show username';

  @override
  String get settingsServerSelectionShowUsernameSub =>
      'Show the username on the connection page; otherwise show the configured name';

  @override
  String get settingsServerSelectionShowAvatar => 'Show user avatar';

  @override
  String get settingsServerSelectionShowAvatarSub =>
      'Show the avatar on the connection page; otherwise show the server logo';

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

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonNoData => 'No data yet';

  @override
  String get commonSelectAll => 'Select all';

  @override
  String get commonClearSelection => 'Clear';

  @override
  String get commonExitSelection => 'Exit selection';

  @override
  String get paginationNoMore => 'No more content';

  @override
  String get paginationLoadFailedRetry => 'Failed to load more, tap to retry';

  @override
  String get posterOnlinePlay => 'Play online';

  @override
  String get movieCardSubExternal => 'External subtitle';

  @override
  String get movieCardSubAi => 'AI subtitle';

  @override
  String get movieCardSubMuxedTrack => 'Embedded subtitle track';

  @override
  String get movieCardSubFilename => 'Filename subtitle';

  @override
  String movieCardSubStack(int n) {
    return 'Subtitles ×$n (tap to expand)';
  }

  @override
  String get movieCardSubChinese => 'Chinese subs';

  @override
  String get movieCardRestricted => 'Restricted';

  @override
  String get movieCardUntitledTitle => 'Untitled title';

  @override
  String get movieCardUntitledCode => 'No ID';

  @override
  String get movieCardNoMeta => 'No info';

  @override
  String get movieCardCrack => 'Cracked / uncensored';

  @override
  String get statusIdle => 'Preparing';

  @override
  String get statusPending => 'Queued';

  @override
  String get statusRunning => 'Running';

  @override
  String get statusPaused => 'Paused';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusSkipped => 'Skipped';

  @override
  String get statusCanceled => 'Canceled';

  @override
  String get statusFailed => 'Failed';

  @override
  String get statusUnknown => 'Unknown';

  @override
  String get commonClearInput => 'Clear';

  @override
  String get securityVerifyIncomplete =>
      'Verification incomplete. Try again or use another unlock method';

  @override
  String get securityPinIncorrect => 'Incorrect PIN';

  @override
  String get securityPatternIncorrect => 'Incorrect pattern';

  @override
  String get securityAppLocked => 'App locked';

  @override
  String get securityUnlockPrompt =>
      'Verify your identity to continue using Oh My Media';

  @override
  String get securityBiometricUnlock => 'Use Face ID / fingerprint';

  @override
  String get securityVerifying => 'Verifying…';

  @override
  String get securityPasswordUnlock => 'Use PIN or pattern';

  @override
  String get securityPinCode => 'PIN';

  @override
  String get securitySwipeUnlock => 'Pattern';

  @override
  String get securityUnavailable => 'Security check unavailable. Try again';

  @override
  String get securityBiometricReason =>
      'Verify your identity to access Oh My Media';

  @override
  String get accessControlTitle => 'Access control';

  @override
  String get badgeCodec => 'Codec';

  @override
  String get cacheCategoryMusic => 'Music';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonReadFailed => 'Failed to read';

  @override
  String get commonSaveSettings => 'Save settings';

  @override
  String get commonSaving => 'Saving…';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get dbOnlineAscending => 'Ascending';

  @override
  String get dbOnlineAutoLoadMoreHint => 'Load more automatically';

  @override
  String get dbOnlineBackendConfigSubtitle => 'Configure the DB Online backend';

  @override
  String get dbOnlineBackendConfigTitle => 'DB Online backend';

  @override
  String get dbOnlineBadgeSubtitle => 'DB Online data';

  @override
  String get dbOnlineCategoryAnime => 'Anime';

  @override
  String get dbOnlineCategoryCensored => 'Censored';

  @override
  String get dbOnlineCategorySection => 'Categories';

  @override
  String get dbOnlineCategoryUncensored => 'Uncensored';

  @override
  String get dbOnlineCategoryWestern => 'Western';

  @override
  String get dbOnlineConfigLoadError =>
      'Failed to load DB Online configuration';

  @override
  String get dbOnlineConnectionFailed => 'Connection failed';

  @override
  String get dbOnlineConnectionOk => 'Connected';

  @override
  String dbOnlineDefaultPlaySource(int id) {
    return 'Source $id';
  }

  @override
  String get dbOnlineDescending => 'Descending';

  @override
  String get dbOnlineDetailDate => 'Release date';

  @override
  String get dbOnlineDetailRatingCount => 'Rating count';

  @override
  String get dbOnlineDetailsSection => 'Details';

  @override
  String dbOnlineEpisodeNumber(int number) {
    return 'Episode $number';
  }

  @override
  String get dbOnlineEpisodesSection => 'Episodes';

  @override
  String get dbOnlineFieldApiUrl => 'API URL';

  @override
  String get dbOnlineFieldApiUrlHint => 'DB Online API address';

  @override
  String get dbOnlineFieldAuthorization => 'Authorization';

  @override
  String get dbOnlineFieldAutoplay => 'Autoplay';

  @override
  String get dbOnlineFieldCaptions => 'Captions';

  @override
  String get dbOnlineFieldCategoryId => 'Category ID';

  @override
  String get dbOnlineFieldCategoryIdHint => 'Category ID';

  @override
  String get dbOnlineFieldCategoryOptional => 'Category (optional)';

  @override
  String get dbOnlineFieldCheckIntervalHint => 'Automatic check interval';

  @override
  String get dbOnlineFieldCheckIntervalMinutes => 'Check interval (minutes)';

  @override
  String get dbOnlineFieldConcurrency => 'Concurrency';

  @override
  String get dbOnlineFieldCookie => 'Cookie';

  @override
  String get dbOnlineFieldDeviceId => 'Device ID';

  @override
  String get dbOnlineFieldEnablePlayer => 'Enable player';

  @override
  String get dbOnlineFieldEnableProxy => 'Enable proxy';

  @override
  String get dbOnlineFieldEnableRetry => 'Enable retries';

  @override
  String get dbOnlineFieldEnableSubscription => 'Enable subscription';

  @override
  String get dbOnlineFieldEnabled => 'Enabled';

  @override
  String get dbOnlineFieldFullscreen => 'Fullscreen';

  @override
  String get dbOnlineFieldHost => 'Host';

  @override
  String get dbOnlineFieldImageMode => 'Image mode';

  @override
  String get dbOnlineFieldImageUrlReplacePrefix =>
      'Image URL replacement prefix';

  @override
  String get dbOnlineFieldImageUrlReplacePrefixHint =>
      'Replace the image URL prefix with a proxy address';

  @override
  String get dbOnlineFieldIntervalRangeHint => 'Allowed check interval';

  @override
  String get dbOnlineFieldIntervalRangeSeconds => 'Interval range (seconds)';

  @override
  String get dbOnlineFieldKeyboard => 'Keyboard';

  @override
  String get dbOnlineFieldMaskHint => 'Mask sensitive values';

  @override
  String get dbOnlineFieldOptionalMaskHint =>
      'Optional; leave blank to keep the current value';

  @override
  String get dbOnlineFieldParentFolderId => 'Parent folder ID';

  @override
  String get dbOnlineFieldPassword => 'Password';

  @override
  String get dbOnlineFieldPasswordOptional => 'Password (optional)';

  @override
  String get dbOnlineFieldPip => 'Picture in picture';

  @override
  String get dbOnlineFieldPort => 'Port';

  @override
  String get dbOnlineFieldProtocol => 'Protocol';

  @override
  String get dbOnlineFieldRequestTimeoutSeconds => 'Request timeout (seconds)';

  @override
  String get dbOnlineFieldReserveQuotaGb => 'Reserved quota (GB)';

  @override
  String get dbOnlineFieldRetryCount => 'Retry count';

  @override
  String get dbOnlineFieldRetryIntervalSeconds => 'Retry interval (seconds)';

  @override
  String get dbOnlineFieldRpcSecret => 'RPC secret';

  @override
  String get dbOnlineFieldSavePath => 'Save path';

  @override
  String get dbOnlineFieldTimeoutSeconds => 'Timeout (seconds)';

  @override
  String get dbOnlineFieldUseHttps => 'Use HTTPS';

  @override
  String get dbOnlineFieldUsername => 'Username';

  @override
  String get dbOnlineFieldUsernameOptional => 'Username (optional)';

  @override
  String get dbOnlineFilterMovieType => 'Movie type';

  @override
  String get dbOnlineGroupDownloader => 'Downloader';

  @override
  String get dbOnlineGroupMediaLibrary => 'Media library';

  @override
  String get dbOnlineGroupSystem => 'System';

  @override
  String get dbOnlineHidePassword => 'Hide password';

  @override
  String get dbOnlineImageModeDecrypt => 'Decrypt';

  @override
  String get dbOnlineImageModeReplace => 'Replace';

  @override
  String get dbOnlineInLibrary => 'In library';

  @override
  String get dbOnlineLatestReleased => 'Latest releases';

  @override
  String get dbOnlineLibrarySection => 'Library';

  @override
  String get dbOnlineNoData => 'No data';

  @override
  String get dbOnlineNoMeta => 'No metadata';

  @override
  String get dbOnlineNoPlaySources => 'No playable sources';

  @override
  String get dbOnlineNoPlayableEpisodes => 'No playable episodes';

  @override
  String get dbOnlineOnlineOnly => 'Online only';

  @override
  String get dbOnlinePlayOnline => 'Play online';

  @override
  String get dbOnlinePlaySource => 'Play source';

  @override
  String get dbOnlinePlayTooltip => 'Play this source';

  @override
  String get dbOnlinePreviewSection => 'Preview';

  @override
  String get dbOnlineQualityTooltip => 'Quality';

  @override
  String get dbOnlineRecentUpdated => 'Recently updated';

  @override
  String get dbOnlineRefreshEpisodes => 'Refresh episodes';

  @override
  String get dbOnlineRelatedSection => 'Related';

  @override
  String get dbOnlineRetry => 'Retry';

  @override
  String get dbOnlineSameActorSection => 'More with this actor';

  @override
  String get dbOnlineSaved => 'Saved';

  @override
  String dbOnlineSectionFieldCount(int count) {
    return '$count fields';
  }

  @override
  String get dbOnlineSectionPan115 => '115';

  @override
  String get dbOnlineSectionPlayer => 'Player';

  @override
  String get dbOnlineSectionProxy => 'Proxy';

  @override
  String get dbOnlineSectionScopeHint => 'Applies to this section';

  @override
  String get dbOnlineSectionSubscription => 'Subscription';

  @override
  String get dbOnlineSectionSupportsTest => 'Supports testing';

  @override
  String get dbOnlineSectionThunder => 'Thunder';

  @override
  String get dbOnlineSeriesSection => 'Series';

  @override
  String get dbOnlineShowPassword => 'Show password';

  @override
  String get dbOnlineSort => 'Sort';

  @override
  String get dbOnlineTestConnection => 'Test connection';

  @override
  String get dbOnlineUncensored => 'Uncensored';

  @override
  String get homeBadgeNew => 'New';

  @override
  String get homeLibraries => 'Libraries';

  @override
  String get homeNoData => 'No data';

  @override
  String get homeSwitchAuthFailed => 'Authentication failed';

  @override
  String get homeSwitchAuthTimeout => 'Authentication timed out';

  @override
  String get homeSwitchBackToPassword => 'Use password instead';

  @override
  String get homeSwitchCancel => 'Cancel switch';

  @override
  String homeSwitchCannotConnect(String name) {
    return 'Cannot connect to $name';
  }

  @override
  String get homeSwitchCheckNetwork => 'Check network connection';

  @override
  String get homeSwitchCheckingAuth => 'Checking authentication';

  @override
  String homeSwitchConnecting(String name) {
    return 'Connecting to $name';
  }

  @override
  String get homeSwitchConnectionFailed => 'Connection failed';

  @override
  String get homeSwitchInvalidTarget => 'Invalid target';

  @override
  String get homeSwitchNeedPassword => 'Enter password';

  @override
  String homeSwitchNeedTotp(int length) {
    return 'Enter the $length-digit verification code';
  }

  @override
  String get homeSwitchNeedUsername => 'Enter username';

  @override
  String get homeSwitchPasswordHint => 'Enter the server password';

  @override
  String get homeSwitchPasswordLabel => 'Password';

  @override
  String homeSwitchRestoreFailed(String error) {
    return 'Failed to restore session: $error';
  }

  @override
  String get homeSwitchServer => 'Switch server';

  @override
  String get homeSwitchSignInAndSwitch => 'Sign in and switch';

  @override
  String get homeSwitchTargetMissingMessage =>
      'The selected server is no longer available';

  @override
  String get homeSwitchTargetMissingTitle => 'Server unavailable';

  @override
  String get homeSwitchTotpHint => 'Enter the verification code';

  @override
  String get homeSwitchUsernameLabel => 'Username';

  @override
  String get homeSwitchUsernamePasswordHint => 'Enter your server credentials';

  @override
  String get homeSwitchVerifyAndSwitch => 'Verify and switch';

  @override
  String get homeSwitchVerifying => 'Verifying…';

  @override
  String mediaBrowserActionFailed(String error) {
    return 'Action failed: $error';
  }

  @override
  String get mediaBrowserActorWorks => 'Actor works';

  @override
  String get mediaBrowserAddPath => 'Add path';

  @override
  String get mediaBrowserAdminRequired => 'Admin required';

  @override
  String get mediaBrowserAdminRequiredHint => 'Admin required';

  @override
  String get mediaBrowserAscending => 'Ascending';

  @override
  String mediaBrowserBatchRemoveFailed(String error) {
    return 'Failed to remove favorites in bulk: $error';
  }

  @override
  String get mediaBrowserContentType => 'Content type';

  @override
  String get mediaBrowserContentTypeReadonly => 'Content type readonly';

  @override
  String get mediaBrowserContentTypeRequired => 'Content type required';

  @override
  String mediaBrowserDeleteFailed(String error) {
    return 'Failed to delete library: $error';
  }

  @override
  String mediaBrowserDeleteLibraryBody(String name) {
    return 'Delete library “$name”? Files on the server will not be deleted.';
  }

  @override
  String get mediaBrowserDeleteLibraryTitle => 'Delete library';

  @override
  String get mediaBrowserDescending => 'Descending';

  @override
  String get mediaBrowserDisableAction => 'Disable';

  @override
  String get mediaBrowserDisableLibraryHint => 'Disable library';

  @override
  String mediaBrowserDisc(int number) {
    return 'Disc $number';
  }

  @override
  String get mediaBrowserEditLibrarySubtitle => 'Edit library';

  @override
  String get mediaBrowserEditLibraryTitle => 'Edit library';

  @override
  String get mediaBrowserEnableAction => 'Enable';

  @override
  String get mediaBrowserEnableLibraryHint => 'Enable library';

  @override
  String get mediaBrowserEnableLibraryLabel => 'Enable library';

  @override
  String get mediaBrowserFavoriteAction => 'Favorite';

  @override
  String get mediaBrowserFilterContentType => 'Filter content type';

  @override
  String mediaBrowserItemCount(int count) {
    return '$count items';
  }

  @override
  String get mediaBrowserLatestAdded => 'Latest added';

  @override
  String get mediaBrowserLibrariesTitle => 'Libraries';

  @override
  String get mediaBrowserLibrariesUnavailable => 'Libraries unavailable';

  @override
  String get mediaBrowserLibraryCreated => 'Library created';

  @override
  String get mediaBrowserLibraryDeleted => 'Library deleted';

  @override
  String get mediaBrowserLibraryDisabled => 'Library disabled';

  @override
  String get mediaBrowserLibraryEnabled => 'Library enabled';

  @override
  String get mediaBrowserLibraryManageSubtitle =>
      'Manage virtual libraries and media paths on the server';

  @override
  String get mediaBrowserLibraryManageTitle => 'Library management';

  @override
  String get mediaBrowserLibraryNameHint => 'Library name';

  @override
  String get mediaBrowserLibraryNameLabel => 'Library name';

  @override
  String get mediaBrowserLibraryNameRequired => 'Library name required';

  @override
  String mediaBrowserLibraryRefreshStarted(String name) {
    return 'Library refresh started: $name';
  }

  @override
  String get mediaBrowserLibrarySettingsSaved => 'Library saved';

  @override
  String get mediaBrowserMarkWatched => 'Mark watched';

  @override
  String get mediaBrowserMediaPathsLabel => 'Media paths';

  @override
  String get mediaBrowserNewLibrarySubtitle => 'New library';

  @override
  String get mediaBrowserNewLibraryTitle => 'New library';

  @override
  String get mediaBrowserNoData => 'No data';

  @override
  String get mediaBrowserNoFavorites => 'No favorites';

  @override
  String get mediaBrowserNoFavoritesHint => 'No favorites';

  @override
  String get mediaBrowserNoFavoritesYet => 'No favorites yet';

  @override
  String get mediaBrowserNoLibrariesHint => 'No libraries';

  @override
  String get mediaBrowserNoLibrariesYet => 'No libraries yet';

  @override
  String get mediaBrowserNoMatchingItems => 'No matching items';

  @override
  String get mediaBrowserNoTracks => 'No tracks';

  @override
  String get mediaBrowserNotMediaServer => 'Not media server';

  @override
  String get mediaBrowserPathHint => 'Path';

  @override
  String mediaBrowserPathNumber(int number) {
    return 'Path $number';
  }

  @override
  String get mediaBrowserPathRequired => 'Path required';

  @override
  String get mediaBrowserPlayAll => 'Play all';

  @override
  String get mediaBrowserRefresh => 'Refresh';

  @override
  String mediaBrowserRefreshFailed(String error) {
    return 'Refresh failed: $error';
  }

  @override
  String mediaBrowserRemoveFavoriteFailed(String error) {
    return 'Failed to remove favorite: $error';
  }

  @override
  String mediaBrowserRemoveFavoritesBody(int count) {
    return 'Remove $count selected items from favorites?';
  }

  @override
  String get mediaBrowserRemoveFavoritesTitle => 'Remove favorites';

  @override
  String get mediaBrowserRemovePath => 'Remove path';

  @override
  String mediaBrowserRemovedItem(String name) {
    return 'Removed from favorites: $name';
  }

  @override
  String mediaBrowserRemovedNItems(int count) {
    return 'Removed $count items from favorites';
  }

  @override
  String mediaBrowserRemovedNItemsWithFailed(int count, int failed) {
    return 'Removed $count items; $failed failed';
  }

  @override
  String get mediaBrowserRetry => 'Retry';

  @override
  String mediaBrowserSaveFailed(String error) {
    return 'Failed to save library: $error';
  }

  @override
  String get mediaBrowserSort => 'Sort';

  @override
  String get mediaBrowserSortBy => 'Sort by';

  @override
  String get mediaBrowserSortName => 'Sort by name';

  @override
  String get mediaBrowserSortNameAZ => 'Name (A–Z)';

  @override
  String get mediaBrowserSortRating => 'Sort by rating';

  @override
  String get mediaBrowserSortRecent => 'Sort by recently added';

  @override
  String get mediaBrowserSortTopRated => 'Sort by highest rating';

  @override
  String get mediaBrowserSortYear => 'Sort by year';

  @override
  String get mediaBrowserSortYearDesc => 'Sort by year (newest first)';

  @override
  String get mediaBrowserStatEpisodes => 'Episodes';

  @override
  String get mediaBrowserStatMovies => 'Movies';

  @override
  String get mediaBrowserStatSeries => 'Series';

  @override
  String get mediaBrowserStatsLoadFailed => 'Stats load failed';

  @override
  String get mediaBrowserStatusDisabled => 'Disabled';

  @override
  String get mediaBrowserStatusEnabled => 'Enabled';

  @override
  String get mediaBrowserTracks => 'Tracks';

  @override
  String get mediaBrowserTypeAlbums => 'Albums';

  @override
  String get mediaBrowserTypeMixed => 'Mixed content';

  @override
  String get mediaBrowserTypeMovies => 'Movies';

  @override
  String get mediaBrowserTypeMusic => 'Music';

  @override
  String get mediaBrowserTypeMusicVideos => 'Music videos';

  @override
  String get mediaBrowserTypeSongs => 'Songs';

  @override
  String get mediaBrowserTypeTvShows => 'TV shows';

  @override
  String get mediaBrowserUnfavoriteAction => 'Unfavorite';

  @override
  String get mediaBrowserUnmarkWatched => 'Unmark watched';

  @override
  String get playerSettingBufferGroup => 'Buffer';

  @override
  String get playerSettingButtonsGroup => 'Buttons';

  @override
  String get playerSettingDefaultEngine => 'Default engine';

  @override
  String playerSettingDefaultEngineSub(String engine) {
    return 'Current: $engine';
  }

  @override
  String get playerSettingDoubleTapCenter => 'Double tap center';

  @override
  String get playerSettingDoubleTapCenterSub => 'Double tap center';

  @override
  String get playerSettingDoubleTapEdges => 'Double tap edges';

  @override
  String get playerSettingDoubleTapEdgesSub => 'Double tap edges';

  @override
  String get playerSettingDoubleTapGroup => 'Double tap';

  @override
  String get playerSettingEntryOrientation => 'Entry orientation';

  @override
  String get playerOrientationLockGyroscope => 'Lock rotation';

  @override
  String get playerOrientationUnlockGyroscope => 'Unlock rotation';

  @override
  String get playerSettingHapticGroup => 'Haptic';

  @override
  String get playerSettingHapticLongPress => 'Haptic long press';

  @override
  String get playerSettingHapticProgressBar => 'Haptic progress bar';

  @override
  String get playerSettingHapticRate => 'Haptic rate';

  @override
  String get playerSettingHapticSeek => 'Haptic seek';

  @override
  String get playerSettingIosEngineGroup => 'iOS engine';

  @override
  String get playerSettingLandscapeSide => 'Landscape side';

  @override
  String get playerSettingMediaSwitchButton => 'Media switch';

  @override
  String get playerSettingMediaSwitchButtonSub => 'Media switch';

  @override
  String get playerSettingOrientationButton => 'Orientation';

  @override
  String get playerSettingOrientationGroup => 'Orientation';

  @override
  String get playerSettingOsdBattery => 'OSD battery';

  @override
  String get playerSettingOsdBatterySub => 'OSD battery';

  @override
  String get playerSettingOsdClock => 'OSD clock';

  @override
  String get playerSettingOsdClockSub => 'OSD clock';

  @override
  String get playerSettingOsdCpu => 'OSD cpu';

  @override
  String get playerSettingOsdCpuSub => 'OSD cpu';

  @override
  String get playerSettingOsdGroup => 'OSD';

  @override
  String get playerSettingOsdNetwork => 'OSD network';

  @override
  String get playerSettingOsdNetworkSub => 'OSD network';

  @override
  String get playerSettingPipButton => 'PiP';

  @override
  String get playerSettingPlayPauseButton => 'Play pause';

  @override
  String get playerSettingPreloadSize => 'Preload size';

  @override
  String playerSettingPreloadSizeSub(String size) {
    return 'Current: $size';
  }

  @override
  String get playerSettingResumeLast => 'Resume last';

  @override
  String get playerSettingResumeLastSub => 'Resume last';

  @override
  String get playerSettingSeekButtons => 'Seek buttons';

  @override
  String get playerSettingSpeedButton => 'Speed';

  @override
  String get posterBadgeAllHidden => 'All hidden';

  @override
  String get posterBadgeDetailPoster => 'Detail poster';

  @override
  String get posterBadgePageSubtitle => 'Page';

  @override
  String get posterBadgePreviewCodec => 'Preview codec';

  @override
  String get posterBadgePreviewHd => 'Preview HD';

  @override
  String get posterBadgePreviewHdr => 'Preview HDR';

  @override
  String get posterBadgePreviewHint => 'Preview';

  @override
  String get posterBadgePreviewStrm => 'Preview strm';

  @override
  String get posterBadgePreviewTitle => 'Preview';

  @override
  String get posterBadgeVisible => 'Visible';

  @override
  String get serverAddTitle => 'Add server';

  @override
  String get serverAdded => 'Server added';

  @override
  String get serverCurrent => 'Current server';

  @override
  String serverDeleteBody(String name) {
    return 'Delete server “$name” and its lines?';
  }

  @override
  String serverDeleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get serverDeleteTitle => 'Delete server';

  @override
  String get serverEditAction => 'Edit server';

  @override
  String get serverLineAdd => 'Add line';

  @override
  String get serverLineAutoSelect => 'Auto-select line';

  @override
  String get serverLineAutoTestNoResult => 'Automatic test returned no result';

  @override
  String serverLineCount(int count) {
    return '$count lines';
  }

  @override
  String get serverLineDefaultName => 'Server line';

  @override
  String get serverLineDeleteActiveBlocked => 'Cannot delete the active line';

  @override
  String serverLineDeleteBody(String name) {
    return 'Delete line “$name”?';
  }

  @override
  String get serverLineDeleteTitle => 'Delete';

  @override
  String get serverLineDeleted => 'Line deleted';

  @override
  String get serverLineDisable => 'Disable';

  @override
  String get serverLineDisabled => 'Line disabled';

  @override
  String get serverLineDuplicateUrl => 'Duplicate URL';

  @override
  String get serverLineEditorAddTitle => 'Add server line';

  @override
  String get serverLineEditorEditTitle => 'Edit server line';

  @override
  String get serverLineEnable => 'Enable';

  @override
  String serverLineFastest(String name) {
    return 'Fastest line: $name';
  }

  @override
  String get serverLineKeepOne => 'Keep at least one line';

  @override
  String get serverLineKeepOneEnabled => 'Keep at least one enabled line';

  @override
  String get serverLineNameHint => 'e.g. Primary line';

  @override
  String get serverLineNameLabel => 'Name';

  @override
  String get serverLineNoFallback => 'No backup line available';

  @override
  String get serverLineNoResponse => 'No response';

  @override
  String get serverLineNoneEnabled => 'No lines enabled';

  @override
  String get serverLineProbeFailed => 'Line check failed';

  @override
  String get serverLineProbeFailedNotSaved =>
      'Server check failed; line was not saved';

  @override
  String serverLineSaved(int latency) {
    return 'Saved, latency $latency ms';
  }

  @override
  String serverLineSelected(String name, int latency) {
    return 'Selected $name ($latency ms)';
  }

  @override
  String serverLineSwitchedTo(String name) {
    return 'Switched to line: $name';
  }

  @override
  String serverLineTestFailed(String error) {
    return 'Line test failed: $error';
  }

  @override
  String get serverLineTesting => 'Testing line';

  @override
  String get serverLineUpdatedAndSwitched => 'Line updated and switched';

  @override
  String get serverLineUse => 'Use line';

  @override
  String get serverLinesEmptyBody =>
      'Add a backup line to keep this server reachable';

  @override
  String get serverLinesEmptyTitle => 'No server lines';

  @override
  String serverLinesEyebrow(String name) {
    return 'Server lines · $name';
  }

  @override
  String get serverLinesNotConfigured => 'Not configured';

  @override
  String get serverLinesServerMissing => 'Server missing';

  @override
  String get serverLinesSubtitle => 'Manage server lines';

  @override
  String get serverLinesTitle => 'Server lines';

  @override
  String get serverListSubtitle => 'Server list';

  @override
  String get serverManageLines => 'Manage lines';

  @override
  String get serverSettingsAccessSub => 'Password, session policy, and TOTP';

  @override
  String get serverSettingsAudioSub =>
      'Extracted audio assets and subtitle transcription progress';

  @override
  String get serverSettingsAvdb => 'AVDB';

  @override
  String get serverSettingsAvdbSub => 'Actor association sync';

  @override
  String get serverSettingsDboSub =>
      'Movie info, resources, and actor associations';

  @override
  String get serverSettingsModalTranscription => 'Cloud subtitle transcription';

  @override
  String get serverSettingsModalTranscriptionSub =>
      'Modal GPU transcription and task concurrency';

  @override
  String get serverSettingsTranscoding => 'Transcoding';

  @override
  String get serverSettingsTranscodingSub =>
      'Hardware decoding, backend selection, and failure fallback';

  @override
  String get serverSetupConnectTitle => 'Connect';

  @override
  String serverSetupDuplicate(String name) {
    return 'A server with the same connection already exists: $name';
  }

  @override
  String get serverSetupEditSubtitle => 'Edit server';

  @override
  String get serverSetupHostLabel => 'Host';

  @override
  String get serverSetupHostRequired => 'Enter a host';

  @override
  String get serverSetupInvalidFileConfig =>
      'Invalid file source configuration';

  @override
  String get serverSetupLoginUsernameRequired =>
      'Username is required when a password is provided';

  @override
  String get serverSetupNameLabel => 'Name';

  @override
  String get serverSetupNameRequired => 'Enter a name';

  @override
  String get serverSetupNewSubtitle => 'New server';

  @override
  String get serverSetupPasswordLabel => 'Password';

  @override
  String get serverSetupPasswordEditLabel =>
      'Password (leave blank to keep unchanged)';

  @override
  String get serverSetupPasswordOptionalLabel => 'Password (optional)';

  @override
  String get serverSetupPasswordRequired => 'Enter a password';

  @override
  String get serverSetupPathHintOpenList => 'OpenList path';

  @override
  String get serverSetupPathHintSmb => 'SMB path';

  @override
  String get serverSetupPathLabel => 'Path';

  @override
  String get serverSetupPathRequired => 'Enter a path';

  @override
  String get serverSetupPortInvalid => 'Invalid port';

  @override
  String get serverSetupPortLabel => 'Port';

  @override
  String get serverSetupProjectLabel => 'Project';

  @override
  String get serverSetupProtocolLabel => 'Protocol';

  @override
  String get serverSetupReplaceTitle => 'Replace server';

  @override
  String get serverSetupRootPathLabel => 'Root path';

  @override
  String get serverSetupSelectProject => 'Select server type';

  @override
  String get serverSetupTotpClearStored => 'Clear saved secret';

  @override
  String get serverSetupTotpKeyHint =>
      'For servers with 2FA; verification codes are generated automatically at sign-in';

  @override
  String get serverSetupTotpKeyInvalid =>
      'Invalid TOTP secret (expected a base32 string)';

  @override
  String get serverSetupTotpKeyLabel => 'TOTP secret (optional)';

  @override
  String get serverSetupTotpKeyEditLabel =>
      'TOTP secret (leave blank to keep unchanged)';

  @override
  String get serverSetupTotpRequired =>
      'This server requires two-step verification. Provide a TOTP secret, or clear the password and sign in from the login page.';

  @override
  String get serverSetupUserLabel => 'Username';

  @override
  String get serverSetupUserEditLabel =>
      'Username (leave blank to keep unchanged)';

  @override
  String get serverSetupUserOptionalGenericLabel => 'Username (optional)';

  @override
  String get serverSetupUserOptionalLabel =>
      'Username (optional when using API key)';

  @override
  String get serverSetupUserRequired => 'Enter a username';

  @override
  String get serverSetupStashApiKeyLabel => 'Stash API Key';

  @override
  String get serverSetupStashApiKeyEditLabel =>
      'Stash API Key (leave blank to keep unchanged)';

  @override
  String get serverSetupStashApiKeyHint =>
      'Create it in Stash Settings → Security; the key is stored securely';

  @override
  String get serverSetupStashApiKeyClear => 'Clear saved Stash API Key';

  @override
  String get serverSetupStashApiKeyRequired => 'Enter a Stash API Key';

  @override
  String get homeSwitchStashApiKeyHint =>
      'Enter the Stash API Key to switch servers';

  @override
  String get homeSwitchOpenServerSettings => 'Open server settings';

  @override
  String get serverTestAndSave => 'Test and save';

  @override
  String get serverUpdated => 'Server updated';

  @override
  String get serverUrlRequired => 'Enter a server URL';

  @override
  String get serverUrlSchemeRequired => 'Server URL must include a scheme';

  @override
  String get settingsAudioManagement => 'Audio management';

  @override
  String settingsCacheCategoryCleared(String category) {
    return 'Cleared: $category';
  }

  @override
  String get settingsCacheClear => 'Clear cache';

  @override
  String settingsCacheClearCategoryBody(String category) {
    return 'Clear the “$category” cache?';
  }

  @override
  String settingsCacheClearCategoryTitle(String category) {
    return 'Clear $category cache';
  }

  @override
  String settingsCacheClearFailed(String error) {
    return 'Failed to clear cache: $error';
  }

  @override
  String get settingsCacheClearMusicBody => 'Clear the music cache?';

  @override
  String get settingsCacheClearMusicTitle => 'Clear music cache';

  @override
  String get settingsCacheMusicCleared => 'Music cache cleared';

  @override
  String get settingsCheckForUpdates => 'Check for updates';

  @override
  String get settingsLogoutConfirmBody =>
      'You will need to authenticate with the server again.';

  @override
  String get settingsLogoutConfirmTitle => 'Log out?';

  @override
  String get settingsServerList => 'Server list';

  @override
  String settingsServerListSub(int count) {
    return '$count servers · Configure lines separately';
  }

  @override
  String get stageLabel => 'Stage';

  @override
  String get subtitleBackgroundColor => 'Background color';

  @override
  String get subtitleBehaviorGroup => 'Behavior';

  @override
  String get subtitleBold => 'Bold';

  @override
  String get subtitleFont => 'Font';

  @override
  String get subtitleFontColor => 'Font color';

  @override
  String get subtitleFontMonospace => 'Monospace';

  @override
  String get subtitleFontSerif => 'Serif';

  @override
  String get subtitleFontSystem => 'System font';

  @override
  String get subtitleIgnoreAssStyle => 'Ignore ASS styling';

  @override
  String get subtitleIgnoreAssStyleSub =>
      'Ignore styling embedded in ASS subtitles';

  @override
  String get subtitleIgnoreSrtStyle => 'Ignore SRT styling';

  @override
  String get subtitleIgnoreSrtStyleSub =>
      'Ignore styling embedded in SRT subtitles';

  @override
  String get subtitleItalic => 'Italic';

  @override
  String get subtitleOutlineColor => 'Outline color';

  @override
  String get subtitleOutlineShadowGroup => 'Outline shadow';

  @override
  String get subtitleOutlineWidth => 'Outline width';

  @override
  String get subtitlePreviewText => 'Preview';

  @override
  String get subtitleRememberSelection => 'Remember selection';

  @override
  String get subtitleRememberSelectionSub =>
      'Remember the last selected subtitle';

  @override
  String get subtitleResetDefaults => 'Reset defaults';

  @override
  String get subtitleResetDefaultsSub => 'Reset defaults';

  @override
  String get subtitleResetDone => 'Subtitle settings reset';

  @override
  String get subtitleResetGroup => 'Reset';

  @override
  String get subtitleShadowColor => 'Shadow color';

  @override
  String get subtitleShadowSize => 'Shadow size';

  @override
  String get subtitleStylePreview => 'Style preview';

  @override
  String get subtitleTextStyleGroup => 'Text style';

  @override
  String get subtitleTransparent => 'Transparent';

  @override
  String get taskCenterTitle => 'Task center';

  @override
  String get transcriptionAddToken => 'Add token';

  @override
  String get transcriptionAddTokenSubtitle => 'Add a Modal transcription token';

  @override
  String get transcriptionConfiguredKeepHint =>
      'Configured · leave blank to keep the current value';

  @override
  String get transcriptionCredentialKeepHint =>
      'Leave blank to keep the current credential';

  @override
  String get transcriptionDisabledSubtitle => 'Cloud transcription is disabled';

  @override
  String get transcriptionDuplicateTokenId => 'Duplicate token ID';

  @override
  String get transcriptionEditTokenSubtitle => 'Edit token';

  @override
  String get transcriptionEditTokenTitle => 'Edit token';

  @override
  String get transcriptionEnable => 'Enable';

  @override
  String get transcriptionEnabledSubtitle => 'Cloud transcription is enabled';

  @override
  String get transcriptionFollowMaxWorkers => 'Follow global worker limit';

  @override
  String get transcriptionGpuHelp => 'GPU';

  @override
  String get transcriptionGpuLabel => 'GPU';

  @override
  String get transcriptionHfTokenHint => 'HF token';

  @override
  String get transcriptionHfTokenOptional =>
      'Optional; leave blank to keep the current token';

  @override
  String get transcriptionMaxWorkersHelp => 'Maximum number of workers';

  @override
  String get transcriptionMaxWorkersLabel => 'Maximum workers';

  @override
  String get transcriptionModelBranchHelp => 'Hugging Face model branch';

  @override
  String get transcriptionModelBranchLabel => 'Model branch';

  @override
  String get transcriptionNeedToken => 'Token required';

  @override
  String get transcriptionNewHfTokenHint => 'New HF token';

  @override
  String get transcriptionNoTokensHint => 'No tokens';

  @override
  String get transcriptionPerTokenSliderLabel => 'Workers per token';

  @override
  String get transcriptionPerTokenWorkersHelp => 'Limit workers for each token';

  @override
  String get transcriptionPerTokenWorkersLabel => 'Workers per token';

  @override
  String get transcriptionPerTokenWorkersRange => 'Workers per token range';

  @override
  String get transcriptionSaveButton => 'Save';

  @override
  String get transcriptionSaved => 'Saved';

  @override
  String get transcriptionStrategyFillFirst => 'Fill first';

  @override
  String get transcriptionStrategyRoundRobin => 'Round robin';

  @override
  String get transcriptionSubtitle => 'Configure transcription';

  @override
  String get transcriptionTitle => 'Cloud transcription';

  @override
  String get transcriptionTokenConfigured => 'Token configured';

  @override
  String get transcriptionTokenDraft => 'Token draft';

  @override
  String get transcriptionTokenIdExists => 'Token ID already exists';

  @override
  String get transcriptionTokenIdHint => 'Token ID';

  @override
  String get transcriptionTokenIdLabel => 'Token ID';

  @override
  String get transcriptionTokenIncomplete => 'Token is incomplete';

  @override
  String transcriptionTokenLimit(int count) {
    return 'Up to $count tokens';
  }

  @override
  String get transcriptionTokenListHint => 'Tokens are tried in this order';

  @override
  String get transcriptionTokenNameHint => 'Token name';

  @override
  String get transcriptionTokenNameLabel => 'Token name';

  @override
  String transcriptionTokenNumber(int number) {
    return 'Token $number';
  }

  @override
  String get transcriptionTokenSecretHint => 'Token secret';

  @override
  String get transcriptionTokenSecretLabel => 'Token secret';

  @override
  String get transcriptionTokenStrategyHelp => 'Token strategy';

  @override
  String get transcriptionTokenStrategyLabel => 'Token strategy';

  @override
  String transcriptionTokensCount(int count, int limit) {
    return '$count/$limit tokens';
  }

  @override
  String get transcriptionTokensEmptyHint =>
      'Add at least one Modal token to enable cloud transcription';

  @override
  String get transcriptionTokensLabel => 'Tokens';

  @override
  String get transcriptionWorkersRange => 'Worker range';

  @override
  String get transcriptionWorkersSliderLabel => 'Workers';

  @override
  String get translationApiUrlHelp => 'API URL';

  @override
  String get translationConfiguredKeepHint =>
      'Configured · leave blank to keep the current value';

  @override
  String get translationDisabledSubtitle => 'Translation is disabled';

  @override
  String get translationEnable => 'Enable translation';

  @override
  String get translationEnabledSubtitle => 'Translation is enabled';

  @override
  String get translationLangAutoDetect => 'Auto-detect';

  @override
  String get translationLangChinese => 'Chinese';

  @override
  String get translationLangEnglish => 'English';

  @override
  String get translationLangFrench => 'French';

  @override
  String get translationLangGerman => 'German';

  @override
  String get translationLangJapanese => 'Japanese';

  @override
  String get translationLangKorean => 'Korean';

  @override
  String get translationLangRussian => 'Russian';

  @override
  String get translationLangSpanish => 'Spanish';

  @override
  String get translationLoadModels => 'Load models';

  @override
  String translationLoadModelsFailed(String error) {
    return 'Failed to load models: $error';
  }

  @override
  String get translationModelNameHelp => 'Name of the translation model';

  @override
  String get translationModelNameLabel => 'Model name';

  @override
  String get translationNeedApiKey => 'API key required';

  @override
  String get translationNeedApiUrl => 'API URL required';

  @override
  String get translationNewApiKeyHint => 'Enter a new API key';

  @override
  String get translationNoModels => 'No models';

  @override
  String translationPromptTemplateHelp(String variables) {
    return 'Available variables: $variables';
  }

  @override
  String get translationPromptTemplateLabel => 'Prompt template';

  @override
  String get translationSaved => 'Saved';

  @override
  String translationSelectModel(int count) {
    return 'Select model ($count)';
  }

  @override
  String get translationSourceLanguage => 'Source language';

  @override
  String get translationSubtitle => 'Configure the translation service';

  @override
  String get translationTargetLanguage => 'Target language';

  @override
  String get translationTestButton => 'Test translation';

  @override
  String get translationBatchFailed => 'Batch translation failed';

  @override
  String translationTestFailed(String error) {
    return 'Test failed: $error';
  }

  @override
  String get translationTestPassed => 'Test passed';

  @override
  String get translationTestResult => 'Test result';

  @override
  String get translationTitle => 'Translation settings';

  @override
  String get accessBindTotp => 'Bind TOTP';

  @override
  String get accessChangePassword => 'Change password';

  @override
  String get accessChangePasswordHelp =>
      'Update the password used to access this app';

  @override
  String get accessConfigSaved => 'Access settings saved';

  @override
  String get accessControlSubtitle => 'Configure access control';

  @override
  String get accessDeleteTotp => 'Delete TOTP';

  @override
  String get accessDeleteTotpConfirm => 'Delete bound TOTP?';

  @override
  String get accessDisabled => 'Access protection disabled';

  @override
  String get accessEnabled => 'Access protection enabled';

  @override
  String get accessEnableFirst => 'Enable access protection first';

  @override
  String get accessLoadFailed => 'Failed to load access control';

  @override
  String get accessLockDuration => 'Lock duration';

  @override
  String get accessLockMinutesHelp =>
      'Lock the app after this many minutes of inactivity';

  @override
  String get accessMaxAttemptsHelp =>
      'Number of failed attempts before locking';

  @override
  String get accessMaxFailedAttempts => 'Maximum failed attempts';

  @override
  String get accessNewPasswordHint => 'Enter a new password';

  @override
  String get accessPasskeyConfiguredInfo => 'Passkey configured';

  @override
  String get accessPasskeyOnlyInfo => 'Passkey-only unlock';

  @override
  String get accessPasswordMinHint => 'Use at least 6 characters';

  @override
  String get accessPasswordTooShort => 'Password is too short';

  @override
  String accessRangeError(String label, int min, int max) {
    return '$label must be between $min and $max';
  }

  @override
  String get accessRebindTotp => 'Rebind TOTP';

  @override
  String get accessRefreshDaysHelp => 'How long a refresh token remains valid';

  @override
  String get accessRefreshTokenDays => 'Refresh token lifetime (days)';

  @override
  String get accessSectionMfa => 'Multi-factor authentication';

  @override
  String get accessSectionMfaHelp => 'Configure TOTP and passkeys';

  @override
  String get accessSectionProtection => 'Protection';

  @override
  String get accessSectionProtectionHelp =>
      'Set the password and lockout policy';

  @override
  String get accessSectionSession => 'Session';

  @override
  String get accessSectionSessionHelp =>
      'Configure session and refresh-token lifetime';

  @override
  String get accessSetPassword => 'Set password';

  @override
  String get accessSetPasswordHelp =>
      'Set the password used to access this app';

  @override
  String get accessStatusActive => 'Active';

  @override
  String get accessStatusActiveDesc => 'Access protection is active';

  @override
  String get accessStatusConfigured => 'Configured';

  @override
  String get accessStatusConfiguredDesc => 'Access method is configured';

  @override
  String get accessStatusNotConfigured => 'Not configured';

  @override
  String get accessStatusNotConfiguredDesc => 'No access method is configured';

  @override
  String get accessTotpBoundDesc => 'TOTP is bound';

  @override
  String get accessTotpCode => 'TOTP code';

  @override
  String get accessTotpCodeHint => 'Enter the 6-digit code';

  @override
  String get accessTotpConfirmBind => 'Confirm TOTP binding';

  @override
  String get accessTotpDeleted => 'TOTP deleted';

  @override
  String get accessTotpEnabled => 'TOTP enabled';

  @override
  String get accessTotpManualKey => 'Manual TOTP key';

  @override
  String get accessTotpTwoFactor => 'Two-factor authentication';

  @override
  String get accessTotpUnboundDesc => 'TOTP is not bound';

  @override
  String get actorAssocActionAppendAlias => 'Append alias';

  @override
  String get actorAssocActionSync => 'Sync';

  @override
  String actorAssocAvatarCandidate(int index) {
    return 'Avatar candidate $index';
  }

  @override
  String actorAssocAvatarConfirm(int count) {
    return 'Use $count selected avatars';
  }

  @override
  String actorAssocAvatarPickerCount(String name, int selected, int total) {
    return 'Choose avatars for “$name” ($selected/$total selected)';
  }

  @override
  String actorAssocAvatarPickerCountWithFailed(
    String name,
    int selected,
    int total,
    int failed,
  ) {
    return 'Choose avatars for “$name” ($selected/$total selected, $failed failed)';
  }

  @override
  String get actorAssocAvatarPickerNameFallback => 'Unknown actor';

  @override
  String get actorAssocAvatarPickerTitle => 'Choose actor avatar';

  @override
  String get actorAssocAvatarRetry => 'Retry';

  @override
  String actorAssocAvatarRetrySemantics(int index) {
    return 'Retry avatar $index';
  }

  @override
  String get actorAssocAvatarSelected => 'Selected';

  @override
  String actorAssocAvatarSelectSemantics(int index) {
    return 'Select avatar $index';
  }

  @override
  String get actorAssocDeletedToast => 'Actor association deleted';

  @override
  String actorAssocDeleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String actorAssocDeleteMessage(String name, int count) {
    return 'Delete “$name” and its $count aliases?';
  }

  @override
  String get actorAssocDeleteTitle => 'Delete actor association';

  @override
  String get actorAssocDeselectAll => 'Deselect all';

  @override
  String get actorAssocEditorAliasHint => 'Add one alias per line';

  @override
  String get actorAssocEditorAliasLabel => 'Aliases';

  @override
  String get actorAssocEditorAliasPlaceholder => 'Add an alias';

  @override
  String get actorAssocEditorCanonicalExample => 'Example canonical name';

  @override
  String get actorAssocEditorCanonicalHint =>
      'Used to match actors in movie metadata';

  @override
  String get actorAssocEditorCanonicalLabel => 'Canonical actor name';

  @override
  String get actorAssocEditorCanonicalLocked => 'Canonical name is locked';

  @override
  String get actorAssocEditorCreate => 'Create';

  @override
  String actorAssocEditorExistingAliases(int count) {
    return '$count existing aliases will be kept';
  }

  @override
  String get actorAssocEditorNewAliasLabel => 'New aliases';

  @override
  String get actorAssocEditorSeparatorHint =>
      'Separate names with line breaks, commas, or semicolons';

  @override
  String get actorAssocEditorTitleAppend => 'Append aliases';

  @override
  String get actorAssocEditorTitleCreate => 'Create actor association';

  @override
  String get actorAssocEditorTitleEdit => 'Edit association';

  @override
  String get actorAssocEmpty => 'No actor associations';

  @override
  String get actorAssocErrAliasRequired => 'Enter an alias';

  @override
  String get actorAssocErrAtLeastOneAlias => 'Add at least one alias';

  @override
  String get actorAssocErrNameRequired => 'Enter an actor name';

  @override
  String get actorAssocNoNewAliases => 'No new aliases';

  @override
  String actorAssocSaved(String name) {
    return 'Saved: $name';
  }

  @override
  String actorAssocSaveFailed(String name, String error) {
    return 'Failed to save “$name”: $error';
  }

  @override
  String get actorAssocSearchHint => 'Search actor associations';

  @override
  String get actorAssocSourceMixed => 'Mixed source';

  @override
  String get actorAssocSyncApply => 'Apply sync';

  @override
  String actorAssocSyncApplyFailed(String error) {
    return 'Failed to apply sync: $error';
  }

  @override
  String get actorAssocSyncApplying => 'Applying…';

  @override
  String get actorAssocSyncAvatarExists => 'Avatar already exists';

  @override
  String get actorAssocSyncAvatarFailed => 'Avatar failed';

  @override
  String get actorAssocSyncAvatarLabel => 'Actor avatar';

  @override
  String get actorAssocSyncAvatarLoading => 'Loading avatar…';

  @override
  String get actorAssocSyncAvatarLoadingReplace =>
      'Loading replacement avatar…';

  @override
  String get actorAssocSyncAvatarNoneSelected => 'No avatar selected';

  @override
  String actorAssocSyncAvatarWillReplace(int count) {
    return 'Replace the current avatar with $count selected avatars';
  }

  @override
  String actorAssocSyncAvatarWillSync(int count) {
    return 'Sync $count avatars';
  }

  @override
  String get actorAssocSyncCanonicalLabel => 'Canonical actor';

  @override
  String get actorAssocSyncDone => 'Sync completed';

  @override
  String get actorAssocSyncExistingTitle => 'Existing association';

  @override
  String actorAssocSyncNewAliasesTitle(int selected, int total) {
    return 'New aliases ($selected/$total selected)';
  }

  @override
  String actorAssocSyncNoMatchHint(String name) {
    return 'No match found for “$name”';
  }

  @override
  String get actorAssocSyncNoMatchTitle => 'No match';

  @override
  String get actorAssocSyncNoNewAliases => 'No new aliases';

  @override
  String get actorAssocSyncNoPreviewHint => 'No preview available';

  @override
  String get actorAssocSyncNoPreviewTitle => 'No preview';

  @override
  String get actorAssocSyncPickAvatar => 'Choose avatar';

  @override
  String get actorAssocSyncRequestFailed => 'Sync request failed';

  @override
  String get actorAssocSyncSourceFailed => 'Source failed';

  @override
  String get actorAssocSyncSourceNoMatch => 'No matching source';

  @override
  String get actorAssocSyncSourceQuerying => 'Searching sources…';

  @override
  String get actorAssocSyncSourcesRequired =>
      'Configure and enable DB Online or AVDB in server settings first';

  @override
  String get actorAssocSyncMixedFailed => 'Mixed-source lookup failed';

  @override
  String get actorAssocSyncPreviewTimedOut => 'Mixed-source preview timed out';

  @override
  String get actorAssocSyncSourcesLabel => 'Sources';

  @override
  String get actorAssocSyncSourcesLoading => 'Loading sources…';

  @override
  String get actorAssocSyncSubtitle => 'Sync actor associations';

  @override
  String actorAssocSyncTitle(String name) {
    return 'Sync actor: $name';
  }

  @override
  String get actorAssocTitle => 'Actor associations';

  @override
  String get actorEditorBiographyLabel => 'Biography';

  @override
  String get appLogClear => 'Clear log';

  @override
  String get appLogCleared => 'Log cleared';

  @override
  String get appLogClearSub => 'Clear the log before reproducing an issue';

  @override
  String get appLogContent => 'Log content';

  @override
  String get appLogCopied => 'Log copied';

  @override
  String get appLogCopyAll => 'Copy all logs';

  @override
  String appLogCount(int count) {
    return 'Logs ($count)';
  }

  @override
  String get appLogEmpty => 'No logs';

  @override
  String get appLogEmptyHint => 'No logs\nPlay an SMB / WebDAV video first';

  @override
  String get appLogSubtitle =>
      'Reproduce the issue, then copy the log for analysis';

  @override
  String get appLogTitle => 'Playback logs';

  @override
  String get audioActionCancelExtraction => 'Cancel extraction';

  @override
  String get audioActionCancelTranscription => 'Cancel transcription';

  @override
  String get audioActionDeleteAudio => 'Delete audio';

  @override
  String get audioActionEnqueueTranscription => 'Enqueue transcription';

  @override
  String get audioActionRetryTranscription => 'Retry transcription';

  @override
  String get audioAssetCountSuffix => 'audio assets';

  @override
  String audioCancelExtractionFailed(String error) {
    return 'Failed to cancel extraction: $error';
  }

  @override
  String get audioCancelExtractionSubmitted => 'Cancel extraction submitted';

  @override
  String get audioCancelSubmitted => 'Cancel submitted';

  @override
  String audioCancelTranscriptionFailed(String error) {
    return 'Failed to cancel transcription: $error';
  }

  @override
  String get audioDeleteBatchAction => 'Delete selected';

  @override
  String get audioDeleteBatchTitle => 'Delete selected audio';

  @override
  String audioDeleted(int count) {
    return 'Deleted $count audio files';
  }

  @override
  String audioDeleteFailed(String error) {
    return 'Failed to delete audio: $error';
  }

  @override
  String get audioDeleteFileFallback => 'Audio file';

  @override
  String audioDeleteMessageBatch(int count) {
    return 'Delete $count selected audio files?';
  }

  @override
  String audioDeleteMessageSingle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String audioDeleteResult(int deleted, String rejected) {
    return 'Deleted $deleted; rejected $rejected';
  }

  @override
  String get audioDeleteTitle => 'Delete';

  @override
  String get audioEmptyHint => 'Extract audio from a movie to see it here';

  @override
  String get audioEmptySearchHint => 'No matching audio files';

  @override
  String get audioEmptySearchTitle => 'No results';

  @override
  String get audioEmptyTitle => 'No audio files';

  @override
  String get audioEnqueueBatchTitle => 'Queue selected audio';

  @override
  String get audioEnqueueConfirm => 'Queue transcription?';

  @override
  String audioEnqueued(int count) {
    return 'Queued $count transcription tasks';
  }

  @override
  String audioEnqueuedMixed(int accepted, String rejected) {
    return 'Queued $accepted; rejected $rejected';
  }

  @override
  String audioEnqueueFailed(String error) {
    return 'Failed to queue transcription: $error';
  }

  @override
  String audioEnqueueMessageBatch(int count) {
    return 'Create transcription tasks for $count audio files?';
  }

  @override
  String audioEnqueueMessageSingle(String name) {
    return 'Create a transcription task for “$name”?';
  }

  @override
  String get audioEnqueueTitle => 'Queue transcription';

  @override
  String get audioExtractingSection => 'Audio extraction';

  @override
  String get audioEyebrow => 'Audio';

  @override
  String get audioFileMissing => 'Audio file missing';

  @override
  String get audioOverwriteExistingSubtitle => 'Overwrite existing subtitles';

  @override
  String get audioRequeued => 'Requeued';

  @override
  String audioRetryFailed(String error) {
    return 'Failed to retry transcription: $error';
  }

  @override
  String audioRetryMessage(String name) {
    return 'Retry transcription for “$name”?';
  }

  @override
  String get audioRetryTitle => 'Retry';

  @override
  String get audioSearchHint => 'Search';

  @override
  String audioSearchSubtitle(String query) {
    return 'Search: $query';
  }

  @override
  String get audioStageCanceled => 'Canceled';

  @override
  String get audioStageCompleted => 'Completed';

  @override
  String get audioStageConnecting => 'Connecting';

  @override
  String get audioStageDownloading => 'Downloading';

  @override
  String get audioStageFailed => 'Failed';

  @override
  String get audioStagePreparing => 'Preparing';

  @override
  String get audioStageQueued => 'Queued';

  @override
  String get audioStageRegistering => 'Registering';

  @override
  String get audioStageSandbox => 'Processing in sandbox';

  @override
  String get audioStageSkipped => 'Skipped';

  @override
  String get audioStageStarting => 'Starting';

  @override
  String get audioStageTranscribing => 'Transcribing';

  @override
  String get audioStageTranscribingFallback => 'Transcribing (fallback)';

  @override
  String get audioStageUploading => 'Uploading';

  @override
  String get audioStatusCanceled => 'Canceled';

  @override
  String get audioStatusFailed => 'Failed';

  @override
  String get audioStatusNotTranscribed => 'Not transcribed';

  @override
  String get audioStatusTranscribed => 'Transcribed';

  @override
  String get audioSubtitle => 'Audio transcription';

  @override
  String get audioTaskExtracting => 'Extracting audio';

  @override
  String get audioTaskQueued => 'Transcription queued';

  @override
  String get audioTitle => 'Audio';

  @override
  String get audioTranscriptionCanceledHint => 'Transcription canceled';

  @override
  String get avdbEnableOff => 'Disabled';

  @override
  String get avdbEnableOn => 'Enable AVDB for actor sync';

  @override
  String get avdbEnableTitle => 'Enable AVDB data source';

  @override
  String get avdbKeyConfigured =>
      'Configured · leave blank to keep the current key';

  @override
  String get avdbKeyHide => 'Hide API key';

  @override
  String get avdbKeyKeepHint => 'Leave blank to keep the current key';

  @override
  String get avdbKeyPrompt => 'API key';

  @override
  String get avdbKeyShow => 'Show API key';

  @override
  String get avdbSavedToast => 'AVDB configuration saved';

  @override
  String get avdbServerSection => 'Server address';

  @override
  String get avdbStatusSection => 'Status';

  @override
  String get avdbSubtitle => 'Configure AVDB';

  @override
  String get avdbTitle => 'AVDB';

  @override
  String get badgePreviewMovieTitle => 'Movie title';

  @override
  String get cacheCategoryImage => 'Image';

  @override
  String get cacheCategoryOther => 'Other';

  @override
  String get codecUnknown => 'Unknown codec';

  @override
  String get commonActions => 'Actions';

  @override
  String get commonChange => 'Change';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonDownloading => 'Downloading';

  @override
  String get commonHidePassword => 'Hide password';

  @override
  String get commonIgnore => 'Ignore';

  @override
  String get commonIosOnly => 'iOS only';

  @override
  String get commonLater => 'Later';

  @override
  String get commonShowPassword => 'Show password';

  @override
  String get configInputPrompt => 'Enter a value';

  @override
  String get configSavedToast => 'Config saved';

  @override
  String dboAgePreview(String years) {
    return 'Max age: $years years';
  }

  @override
  String get dboApiKeyConfiguredHint => 'API key configured';

  @override
  String get dboBaseUrlExampleHint => 'e.g. http://10.0.0.50:9090';

  @override
  String get dboEnabledHelpOff => 'DB Online is disabled';

  @override
  String get dboEnabledHelpOn => 'DB Online is enabled';

  @override
  String get dboEnabledLabel => 'Enabled';

  @override
  String get dboEnableSwitchLabel => 'Enable DB Online';

  @override
  String get dboErrBothSet =>
      'Choose either maximum age or minimum resource month, not both.';

  @override
  String get dboErrMonthFormat => 'Enter the month in YYYY-MM format.';

  @override
  String get dboFilterLast10Years => 'Last 10 years';

  @override
  String get dboFilterLast2Years => 'Last 2 years';

  @override
  String get dboFilterLast5Years => 'Last 5 years';

  @override
  String get dboFilterLastYear => 'Last year';

  @override
  String get dboFilterNoFilter => 'No filter';

  @override
  String get dboMonthsUnit => 'months';

  @override
  String get dboNewApiKeyHint => 'New API key';

  @override
  String get dboResourceFilterHelp => 'Resource filter';

  @override
  String get dboResourceFilterLabel => 'Resource filter';

  @override
  String get dboStartMonthHelp => 'Start month';

  @override
  String get dboStartMonthHint => 'Start month';

  @override
  String get dboStartMonthLabel => 'Start month';

  @override
  String get dboSubtitle => 'Configure DB Online';

  @override
  String get favoritesEmptyHint =>
      'Add a movie to your favorites to see it here';

  @override
  String get favoritesEmptyTitle => 'No favorites yet';

  @override
  String get favoritesRemoveAction => 'Remove';

  @override
  String favoritesRemoveBatchFailed(String error) {
    return 'Failed to remove favorites in bulk: $error';
  }

  @override
  String favoritesRemoveConfirm(int count) {
    return 'Remove $count selected movies?';
  }

  @override
  String favoritesRemovedN(int count) {
    return 'Removed $count movies';
  }

  @override
  String favoritesRemovedOne(String name) {
    return 'Removed from favorites: $name';
  }

  @override
  String favoritesRemoveFailed(String error) {
    return 'Failed to remove favorite: $error';
  }

  @override
  String get favoritesRemoveTitle => 'Remove';

  @override
  String favoritesScanConfirm(int count) {
    return 'Scan $count favorite movies?';
  }

  @override
  String favoritesScanCreateFailed(String error) {
    return 'Failed to create scan task: $error';
  }

  @override
  String favoritesScanSkippedSuffix(int count) {
    return '($count skipped)';
  }

  @override
  String get favoritesScanStart => 'Start scan';

  @override
  String favoritesScanSubmitted(int count) {
    return 'Submitted $count scan tasks';
  }

  @override
  String get favoritesScanTitle => 'Scan';

  @override
  String get favoritesScanTooltip => 'Scan favorite movies';

  @override
  String get favoritesSortRating => 'Sort by rating';

  @override
  String get favoritesSortRecent => 'Sort by recently added';

  @override
  String get favoritesSortSheetTitle => 'Sort favorites';

  @override
  String get favoritesSortTitle => 'Sort';

  @override
  String get favoritesSortYearDesc => 'Sort by year (newest first)';

  @override
  String get ffmpegAudioSection => 'Audio';

  @override
  String get ffmpegAudioThreadsSubtitle => 'Audio threads';

  @override
  String get ffmpegAudioThreadsTitle => 'Audio threads';

  @override
  String get ffmpegAudioWorkersSubtitle => 'Audio workers';

  @override
  String get ffmpegAudioWorkersTitle => 'Audio workers';

  @override
  String get ffmpegFallbackOff => 'Fallback disabled';

  @override
  String get ffmpegFallbackOn => 'Fallback enabled';

  @override
  String get ffmpegFallbackTitle => 'Fallback';

  @override
  String get ffmpegHwBackendLabel => 'Hardware backend';

  @override
  String get ffmpegHwEnableTitle => 'Enable hardware decoding';

  @override
  String get ffmpegHwNone => 'No hardware decoding';

  @override
  String get ffmpegHwOff => 'Hardware decoding disabled';

  @override
  String get ffmpegHwOn => 'Hardware decoding enabled';

  @override
  String get ffmpegHwSection => 'Hardware decoding';

  @override
  String ffmpegPathHint(String name) {
    return 'Choose $name path';
  }

  @override
  String get ffmpegPathsSection => 'Paths';

  @override
  String get ffmpegSavedToast => 'Saved';

  @override
  String get ffmpegSubtitle => 'Configure FFmpeg';

  @override
  String get ffmpegTitle => 'FFmpeg';

  @override
  String get settingsPreview => 'Preview generation';

  @override
  String get settingsPreviewSub =>
      'Configure preview video, Sprite, and VTT generation';

  @override
  String get previewSettingsTitle => 'Preview generation';

  @override
  String get previewSettingsSubtitle =>
      'Configure preview video, Sprite, and VTT generation.';

  @override
  String get previewAutoGenerate => 'Generate after scanning';

  @override
  String get previewAutoGenerateSub =>
      'Queue previews automatically when new movies finish scanning.';

  @override
  String get previewAudio => 'Keep audio';

  @override
  String get previewAudioSub => 'Include the source audio in preview videos.';

  @override
  String get previewVideoSection => 'Video segments';

  @override
  String get previewSegments => 'Segment count';

  @override
  String get previewSegmentsSub =>
      'Number of segments sampled from the video (1-60).';

  @override
  String get previewSegmentDuration => 'Segment duration (seconds)';

  @override
  String get previewSegmentDurationSub =>
      'Duration of each preview segment; greater than 0 and at most 30 seconds.';

  @override
  String get previewExcludeStart => 'Exclude from start (%)';

  @override
  String get previewExcludeEnd => 'Exclude from end (%)';

  @override
  String get previewExcludeSub =>
      'The combined start and end exclusion must be below 100%.';

  @override
  String get previewEncodingSection => 'Encoding';

  @override
  String get previewPreset => 'Encoding speed';

  @override
  String get previewSpriteSection => 'Sprite and VTT';

  @override
  String get previewSpriteInterval => 'Sprite interval (seconds)';

  @override
  String get previewSpriteMinimum => 'Minimum frames';

  @override
  String get previewSpriteMaximum => 'Maximum frames';

  @override
  String get previewSpriteSize => 'Frame size (pixels)';

  @override
  String get previewSavedToast => 'Preview configuration saved';

  @override
  String get previewInvalidValue => 'Enter a valid preview configuration.';

  @override
  String get taskNamePreview => 'Preview generation';

  @override
  String get taskNamePreviewDownload => 'Preview image download';

  @override
  String get taskNameDuplicateMerge => 'Duplicate number merge';

  @override
  String get taskNameIncrementalScan => 'Incremental scan';

  @override
  String get taskNameFullScan => 'Full scan';

  @override
  String get taskNameScheduledScan => 'Scheduled incremental scan';

  @override
  String get previewStatusTitle => 'Preview assets';

  @override
  String get previewSourceReady => 'Source can generate previews';

  @override
  String get previewSourceUnsupported => 'This source cannot generate previews';

  @override
  String get previewVideoAsset => 'Preview video';

  @override
  String get previewSpriteAsset => 'Sprite';

  @override
  String get previewVttAsset => 'VTT';

  @override
  String get previewReady => 'Ready';

  @override
  String get previewNotReady => 'Not generated';

  @override
  String get previewGenerate => 'Generate preview';

  @override
  String get previewGenerating => 'Generating preview…';

  @override
  String get previewQueued => 'Queued';

  @override
  String get previewCompleted => 'Preview generation complete';

  @override
  String get previewFailed => 'Preview generation failed';

  @override
  String get previewCancelled => 'Preview generation canceled';

  @override
  String libraryBatchAccepted(int count, String scanType) {
    return 'Submitted $count $scanType scan tasks';
  }

  @override
  String libraryBatchFailedShort(int count) {
    return '$count failed';
  }

  @override
  String get libraryBatchNoEnabled => 'No enabled libraries';

  @override
  String libraryBatchNoTasks(String scanType) {
    return 'No $scanType tasks to submit';
  }

  @override
  String libraryBatchReused(int count) {
    return '$count reused';
  }

  @override
  String libraryBatchScanFailed(String error) {
    return 'Batch scan failed: $error';
  }

  @override
  String get libraryBatchScanFull => 'Full scan';

  @override
  String get libraryBatchScanIncremental => 'Incremental scan';

  @override
  String get libraryBatchScanTitle => 'Scan libraries';

  @override
  String libraryBatchSkippedDisabled(int count) {
    return 'Skipped $count disabled libraries';
  }

  @override
  String libraryBatchSubmitFailedCount(int count) {
    return '$count submissions failed';
  }

  @override
  String libraryCardMeta(int files, int directories) {
    return '$files files · $directories directories';
  }

  @override
  String get libraryCreatedToast => 'Created';

  @override
  String libraryDefaultDirName(int index) {
    return 'Directory $index';
  }

  @override
  String libraryDeleteConfirm(String name) {
    return 'Delete library “$name”?';
  }

  @override
  String get libraryDeletedToast => 'Deleted';

  @override
  String libraryDeleteFailed(String error) {
    return 'Failed to delete library: $error';
  }

  @override
  String get libraryDeleteTitle => 'Delete';

  @override
  String get libraryDisable => 'Disable';

  @override
  String get libraryDisabledBadge => 'Disabled';

  @override
  String get libraryDisabledToast => 'Disabled';

  @override
  String get libraryEditorAddDir => 'Add directory';

  @override
  String get libraryEditorEnableHint => 'Enable this library';

  @override
  String get libraryEditorNameHint => 'Library name';

  @override
  String get libraryEditorTitleEdit => 'Edit library';

  @override
  String get libraryEditorTitleNew => 'New library';

  @override
  String get libraryEmptyHint => 'Create a library to start scanning media';

  @override
  String get libraryEmptyTitle => 'No libraries yet';

  @override
  String get libraryEnable => 'Enable';

  @override
  String get libraryEnabledToast => 'Enabled';

  @override
  String libraryErrDirDuplicate(String path) {
    return 'Directory already exists: $path';
  }

  @override
  String get libraryErrDirRequired => 'Add at least one directory';

  @override
  String get libraryErrNameRequired => 'Enter a library name';

  @override
  String libraryErrNotDirectory(String path) {
    return 'Not a directory: $path';
  }

  @override
  String libraryErrPathNotFound(String path) {
    return 'Path not found: $path';
  }

  @override
  String libraryErrPathUsed(String path) {
    return 'Path already in use: $path';
  }

  @override
  String get libraryManageTitle => 'Manage libraries';

  @override
  String get libraryMoviesEmpty => 'No movies';

  @override
  String get libraryScan => 'Scan';

  @override
  String libraryScanFailed(String error) {
    return 'Scan failed: $error';
  }

  @override
  String get libraryScanFull => 'Full scan';

  @override
  String get libraryScanFullStarted => 'Full scan started';

  @override
  String get libraryScanIncremental => 'Incremental scan';

  @override
  String get libraryScanIncrementalStarted => 'Incremental scan started';

  @override
  String libraryScanSheetTitle(String name) {
    return 'Scan library: $name';
  }

  @override
  String get librarySubmitting => 'Submitting';

  @override
  String get listActionsTitle => 'Actions';

  @override
  String get listAddToTitle => 'Add to';

  @override
  String get listCreate => 'Create';

  @override
  String get listDelete => 'Delete';

  @override
  String get listDeleteConfirmBody => 'Delete this list?';

  @override
  String get listEmptyHint => 'Create a list to organize your favorites';

  @override
  String get listEmptyTitle => 'No lists yet';

  @override
  String listHeroCount(int count) {
    return '$count movies';
  }

  @override
  String get listHeroEyebrow => 'List';

  @override
  String get listMissing => 'List not found';

  @override
  String get listNameHint => 'List name';

  @override
  String listRemoveConfirm(String name) {
    return 'Remove “$name” from this list?';
  }

  @override
  String get listRemoveTitle => 'Remove';

  @override
  String get listRename => 'Rename';

  @override
  String get listRenameTitle => 'Rename';

  @override
  String get mappingBadgeConvert => 'Convert';

  @override
  String mappingBatchDeleteConfirm(int count) {
    return 'Delete $count selected mappings?';
  }

  @override
  String mappingBatchDeleted(int count) {
    return 'Deleted $count mappings';
  }

  @override
  String mappingBatchDeleteFailed(String error) {
    return 'Failed to delete mappings in bulk: $error';
  }

  @override
  String get mappingBatchDeleteTitle => 'Delete mappings';

  @override
  String get mappingCountSuffix => 'mappings';

  @override
  String get mappingCreatedToast => 'Created';

  @override
  String get mappingDeletedToast => 'Deleted';

  @override
  String mappingDeleteFailed(String error) {
    return 'Failed to delete mapping: $error';
  }

  @override
  String mappingDeleteRuleConfirm(String name) {
    return 'Delete mapping “$name”?';
  }

  @override
  String get mappingDeleteRuleTitle => 'Delete rule';

  @override
  String mappingEditorTitleEdit(String type) {
    return 'Edit $type mapping';
  }

  @override
  String mappingEditorTitleNew(String type) {
    return 'New $type mapping';
  }

  @override
  String get mappingEmptyHint => 'Create a mapping rule to start';

  @override
  String mappingEmptyTitle(String type) {
    return 'No $type mappings';
  }

  @override
  String get mappingFilterConvert => 'Conversion rules';

  @override
  String get mappingFilterDelete => 'Deletion rules';

  @override
  String get mappingMappedDeleteHint => 'Value after deletion';

  @override
  String get mappingMappedHint => 'Value after conversion';

  @override
  String get mappingMappedPlaceholder => 'Enter the converted value';

  @override
  String get mappingMappedValueEyebrow => 'Converted value';

  @override
  String get mappingOriginalMultiHint => 'Enter one original value per line';

  @override
  String get mappingOriginalMultiPlaceholder => 'Enter original values';

  @override
  String get mappingOriginalPlaceholder => 'Enter the original value';

  @override
  String get mappingOriginalSingleHint => 'Enter the original value to replace';

  @override
  String get mappingOriginalValuesEyebrow => 'Original values';

  @override
  String get mappingSearchHint => 'Search';

  @override
  String get mappingSummaryDiscard => 'Discard changes';

  @override
  String mappingTypeTitle(String type) {
    return '$type mappings';
  }

  @override
  String get mediaBrowserContainer => 'Container';

  @override
  String get mediaBrowserDetails => 'Details';

  @override
  String get mediaBrowserDirectors => 'Directors';

  @override
  String mediaBrowserEpisodeNumber(int number) {
    return 'Episode $number';
  }

  @override
  String get mediaBrowserEpisodes => 'Episodes';

  @override
  String mediaBrowserEpisodeWithRuntime(int number, int minutes) {
    return 'Episode $number · $minutes min';
  }

  @override
  String get mediaBrowserFilePath => 'File path';

  @override
  String get mediaBrowserFileSize => 'File size';

  @override
  String get mediaBrowserGenres => 'Genres';

  @override
  String get mediaBrowserMediaInfo => 'Media info';

  @override
  String get mediaBrowserMediaSources => 'Media sources';

  @override
  String mediaBrowserMediaSourceNumber(int number) {
    return 'Source $number';
  }

  @override
  String get mediaBrowserVideoParts => 'Parts';

  @override
  String get mediaBrowserPlayAllParts => 'Play all parts';

  @override
  String mediaBrowserVideoPartNumber(int number) {
    return 'Part $number';
  }

  @override
  String get mediaBrowserNextUp => 'Next up';

  @override
  String get mediaBrowserNoEpisodesInSeason => 'No episodes in season';

  @override
  String get mediaBrowserNoSeasons => 'No seasons';

  @override
  String get mediaBrowserOriginalTitle => 'Original';

  @override
  String get mediaBrowserSearchHint => 'Search';

  @override
  String mediaBrowserSeasonNumber(int number) {
    return 'Season $number';
  }

  @override
  String get mediaBrowserSeriesLabel => 'Series';

  @override
  String get mediaBrowserSpecialSeason => 'Special season';

  @override
  String get mediaBrowserTranscodePlay => 'Transcode playback';

  @override
  String get mediaBrowserTypeBooks => 'Books';

  @override
  String get mediaBrowserTypeHomeVideos => 'Home videos';

  @override
  String get mediaBrowserTypePhotos => 'Photos';

  @override
  String get mediaBrowserTypeUnknown => 'Unknown';

  @override
  String mediaBrowserTypeUnknownWithValue(String value) {
    return 'Unknown type ($value)';
  }

  @override
  String get mediaBrowserNow => 'Now';

  @override
  String mediaBrowserEpisodeCount(int count) {
    return '$count episodes';
  }

  @override
  String mediaBrowserTrackCount(int count) {
    return '$count tracks';
  }

  @override
  String mediaDurationMinutes(int minutes) {
    return '$minutes minutes';
  }

  @override
  String get mediaBrowserEmptyDefault => 'No content';

  @override
  String mediaBrowserUpdatedNItems(int count) {
    return 'Updated $count items';
  }

  @override
  String mediaBrowserUpdatedNItemsWithFailed(int count, int failed) {
    return 'Updated $count items; $failed failed';
  }

  @override
  String get mediaBrowserWatched => 'Watched';

  @override
  String operationFailed(String error) {
    return 'Operation failed: $error';
  }

  @override
  String get playerAudioNowPlaying => 'Audio now playing';

  @override
  String get playerAudioPlaybackFailed => 'Audio playback failed';

  @override
  String playerDebugAudioBitrate(String value) {
    return 'Audio bitrate: $value';
  }

  @override
  String playerDebugAudioCodec(String value) {
    return 'Audio codec: $value';
  }

  @override
  String playerDebugContainer(String value) {
    return 'Container: $value';
  }

  @override
  String playerDebugDecoder(String value) {
    return 'Decoder: $value';
  }

  @override
  String playerDebugEngine(String value) {
    return 'Engine: $value';
  }

  @override
  String playerDebugFps(String value) {
    return 'FPS: $value';
  }

  @override
  String playerDebugInternalPlayer(String value) {
    return 'Internal player: $value';
  }

  @override
  String playerDebugResolution(String value) {
    return 'Resolution: $value';
  }

  @override
  String playerDebugVideoBitrate(String value) {
    return 'Video bitrate: $value';
  }

  @override
  String playerDebugVideoCodec(String value) {
    return 'Video codec: $value';
  }

  @override
  String get playerDecisionMissing => 'Decision missing';

  @override
  String get playerDecodeLocalHardware => 'Local hardware decoding';

  @override
  String get playerDecodeLocalSoftware => 'Local software decoding';

  @override
  String get playerDecodeServerHardware => 'Server hardware decoding';

  @override
  String get playerDecodeServerSoftware => 'Server software decoding';

  @override
  String get playerDecodeServerSoftwareFallback =>
      'Server software decoding (fallback)';

  @override
  String get playerEngineAudio => 'Audio player engine';

  @override
  String get playerErrorCopied => 'Error copied';

  @override
  String get playerErrorCopy => 'Copy error';

  @override
  String get playerErrorCopyFailed => 'Copy failed';

  @override
  String get playerErrorCopyFull => 'Copy full error';

  @override
  String get playerErrorDetailsTitle => 'Error details';

  @override
  String get playerErrorExport => 'Export error';

  @override
  String get playerErrorExportFailed => 'Export failed';

  @override
  String get playerErrorExportFull => 'Export full error';

  @override
  String get playerErrorExportUnsupported => 'Export unavailable';

  @override
  String get playerErrorShareBody => 'Oh My Media playback error log';

  @override
  String get playerErrorShareSubject => 'Oh My Media playback error';

  @override
  String get playerErrorTitle => 'Playback failed';

  @override
  String get playerErrorViewDetails => 'View details';

  @override
  String get playerExit => 'Exit player';

  @override
  String get playerExitPlayback => 'Exit playback';

  @override
  String get playerFramePreviewUnavailable => 'Frame preview unavailable';

  @override
  String get playerLoadingVideo => 'Loading video';

  @override
  String get playerNetworkCellular => 'Cellular network';

  @override
  String get playerNetworkEthernet => 'Ethernet';

  @override
  String get playerNetworkOffline => 'Offline';

  @override
  String get playerNetworkUnknown => 'Unknown network';

  @override
  String get playerNextMedia => 'Next media';

  @override
  String get playerNextTrack => 'Next track';

  @override
  String get playerPictureInPicture => 'Picture in picture';

  @override
  String get playerPipEngineUnsupported => 'PiP engine unsupported';

  @override
  String get playerPipSourceUnsupported => 'PiP source unsupported';

  @override
  String get playerPipStartFailed => 'PiP start failed';

  @override
  String playerPlaybackSpeed(String rate) {
    return 'Playback speed: $rate';
  }

  @override
  String get playerPreviousMedia => 'Previous media';

  @override
  String get playerPreviousTrack => 'Previous track';

  @override
  String get playerQualityAuto => 'Auto';

  @override
  String get playerSeekBack10Seconds => 'Seek back 10 seconds';

  @override
  String get playerSeekForward10Seconds => 'Seek forward 10 seconds';

  @override
  String get playerSelectAudioTrack => 'Select audio track';

  @override
  String get playerSelectQuality => 'Select quality';

  @override
  String get playerSelectSubtitle => 'Select subtitle';

  @override
  String playerSliderPosition(String position) {
    return 'Position: $position';
  }

  @override
  String playerSliderPositionBuffered(String position, String buffered) {
    return 'Position: $position, buffered to $buffered';
  }

  @override
  String playerSpeedActive(String rate) {
    return 'Speed $rate';
  }

  @override
  String playerSubtitleLoadFailed(String error) {
    return 'Failed to load subtitle: $error';
  }

  @override
  String playerSubtitleLoadFailedContinue(String error) {
    return 'Subtitle failed to load; continuing playback: $error';
  }

  @override
  String get playerSubtitleName => 'Name';

  @override
  String get playerSubtitleOff => 'Off';

  @override
  String get playerSwitchToLandscape => 'Switch to landscape';

  @override
  String get playerSwitchToPortrait => 'Switch to portrait';

  @override
  String get scanActionFailed => 'Failed';

  @override
  String get scanBackgroundButton => 'Background';

  @override
  String get scanCancelFailed => 'Cancel failed';

  @override
  String get scanClose => 'Close';

  @override
  String get scanCurrentEyebrow => 'Current';

  @override
  String get scanDoneClose => 'Done and close';

  @override
  String get scanFailedClose => 'Failed close';

  @override
  String get scanPause => 'Pause';

  @override
  String get scanPauseFailed => 'Pause failed';

  @override
  String get scanPreparing => 'Preparing';

  @override
  String get scanProgressTitle => 'Progress';

  @override
  String get scanResume => 'Resume';

  @override
  String get scanResumeFailed => 'Resume failed';

  @override
  String get scanStatAdded => 'Added';

  @override
  String get scanStatRemoved => 'Removed';

  @override
  String get scanStatUpdated => 'Updated';

  @override
  String get securityAppPassword => 'App password';

  @override
  String get securityBiometricDisabled => 'Biometric disabled';

  @override
  String get securityBiometricNeedsPin =>
      'Set a PIN before enabling biometric unlock';

  @override
  String get securityBiometricOnDesc => 'Use biometric unlock to open the app';

  @override
  String get securityBiometricUnavailable =>
      'Biometric unlock is unavailable on this device';

  @override
  String securityBiometricUpdateFailed(String error) {
    return 'Failed to update biometric settings: $error';
  }

  @override
  String get securityClearConfirmBody =>
      'This will remove all configured local verification methods.';

  @override
  String securityClearFailed(String error) {
    return 'Failed to clear security settings: $error';
  }

  @override
  String get securityClearGesture => 'Clear gesture';

  @override
  String get securityClearPinRequiresBiometricDisabled =>
      'Disable biometric unlock before clearing the app password';

  @override
  String get securityClearPin => 'Clear pin';

  @override
  String get securityGestureMin => 'A gesture password needs at least 4 points';

  @override
  String get securityGesturePassword => 'Gesture password';

  @override
  String get securityGestureSaved => 'Gesture saved';

  @override
  String securityGestureSaveFailed(String error) {
    return 'Failed to save gesture password: $error';
  }

  @override
  String get securityGestureSet => 'Gesture password set';

  @override
  String securityLoadFailed(String error) {
    return 'Failed to load security settings: $error';
  }

  @override
  String get securityLockVerifyDesc =>
      'Require verification when the app starts or returns to the foreground';

  @override
  String get securityLockVerifyTitle => 'Verify when app is locked';

  @override
  String get securityNotSet => 'Not configured';

  @override
  String get securityPatternEnterAgain => 'Draw the pattern again';

  @override
  String get securityPatternEnterFirst => 'Draw a pattern to continue';

  @override
  String get securityPatternMismatch => 'The patterns do not match';

  @override
  String get securityPatternTooFew => 'Use at least 4 points';

  @override
  String get securityPinEnterAgain => 'Enter the PIN again';

  @override
  String get securityPinEnterFirst => 'Enter a PIN to continue';

  @override
  String get securityPinInvalid => 'The PIN is incorrect';

  @override
  String get securityPinMismatch => 'The PINs do not match';

  @override
  String get securityPinSaved => 'Pin saved';

  @override
  String securityPinSaveFailed(String error) {
    return 'Failed to save PIN: $error';
  }

  @override
  String get securityPinSet => 'PIN set';

  @override
  String get securitySetPatternTitle => 'Set gesture password';

  @override
  String get securitySetPinFirst => 'Set a PIN';

  @override
  String get securitySetPinTitle => 'Set PIN';

  @override
  String get securitySettingsSub => 'Configure local app unlock';

  @override
  String get securityUnlockMethodCleared => 'Unlock method cleared';

  @override
  String get securityUnlockMethods => 'Unlock methods';

  @override
  String get securityUsageNotes => 'Usage notes';

  @override
  String get settingsAppUpdate => 'App update';

  @override
  String get settingsAppUpdateSub =>
      'Configure a GitHub repository to check for platform updates';

  @override
  String get settingsCacheCategories => 'Cache categories';

  @override
  String get settingsCacheCleanAll => 'Clear all';

  @override
  String get settingsCacheClearAllBody => 'This will clear all cached data.';

  @override
  String get settingsCacheClearAllTitle => 'Clear all cache';

  @override
  String get settingsCacheCleared => 'Cache cleared';

  @override
  String get settingsCacheTotal => 'Total cache';

  @override
  String get settingsCacheTotalSize => 'Total cache size';

  @override
  String get settingsCheckUpdateFailed => 'Check update failed';

  @override
  String get settingsChoosePlayerEngine => 'Choose player engine';

  @override
  String get settingsClearUpdateSource => 'Clear update source';

  @override
  String get settingsClearUpdateSourceBody => 'Clear update source';

  @override
  String get settingsClearUpdateSourceTitle => 'Clear update source';

  @override
  String get settingsCurrentCache => 'Current cache';

  @override
  String get settingsCurrentVersion => 'Current version';

  @override
  String get settingsDebug => 'Debug';

  @override
  String get settingsDevM3u8Title => 'Dev M3U8';

  @override
  String get settingsDevTools => 'Dev tools';

  @override
  String get settingsDownloadAndInstall => 'Download and install';

  @override
  String settingsDownloadingPercent(int percent) {
    return 'Downloading… $percent%';
  }

  @override
  String settingsDownloadingUpdatePercent(int percent) {
    return 'Downloading update… $percent%';
  }

  @override
  String get settingsDownloadUpdateFailed => 'Download update failed';

  @override
  String get settingsEditUpdateSource => 'Edit update source';

  @override
  String get settingsGithubRepoLabel => 'GitHub repository';

  @override
  String get settingsIncludeDevelopment => 'Include development';

  @override
  String get settingsIncludeDevelopmentSub =>
      'Check both stable and development builds';

  @override
  String get settingsInstalledVersion => 'Installed version';

  @override
  String get settingsInstallerOpened => 'Installer opened';

  @override
  String get settingsInstallUpdate => 'Install update';

  @override
  String get settingsIosInstallerOpened => 'iOS installer opened';

  @override
  String get settingsKsPlayerIosOnly => 'KSPlayer is available on iOS only';

  @override
  String get settingsKsPlayerIosOnlyError =>
      'KSPlayer is available on iOS only; choose libmpv instead';

  @override
  String get settingsM3u8Hint => 'Enter an M3U8 playback URL';

  @override
  String get settingsM3u8Invalid => 'Enter a valid HTTP(S) M3U8 URL';

  @override
  String get settingsM3u8UrlLabel => 'M3U8 URL';

  @override
  String get settingsNewVersionFound => 'New version found';

  @override
  String get settingsNoUpdateNotes => 'No update notes';

  @override
  String get settingsOpeningInstaller => 'Opening installer';

  @override
  String get settingsPlatformNotSupported => 'Platform not supported';

  @override
  String get settingsPlayerDebugMode => 'Player debug mode';

  @override
  String get settingsPlayerDebugModeSub =>
      'Show engine, codec, bitrate, frame rate, and other playback details';

  @override
  String get settingsPlayerEngine => 'Player engine';

  @override
  String get settingsPlayM3u8 => 'Play M3U8';

  @override
  String get settingsSaveDevPrefFailed =>
      'Failed to save developer preferences';

  @override
  String get settingsSaveIgnoreFailed => 'Failed to save subtitle preferences';

  @override
  String get settingsSaveUpdateSource => 'Save update source';

  @override
  String get settingsSaveUpdateSourceFailed => 'Failed to save update source';

  @override
  String get settingsUpdateFailed => 'Update failed';

  @override
  String settingsUpdateFound(String version) {
    return 'New version found: $version';
  }

  @override
  String get settingsUpdateNotesTitle => 'Update notes';

  @override
  String get settingsUpdateNow => 'Update now';

  @override
  String get settingsUpdateResult => 'Update result';

  @override
  String get settingsUpdateSource => 'Update source';

  @override
  String get settingsUpdateSourceCleared => 'Update source cleared';

  @override
  String get settingsUpdateSourceHint =>
      'Enter a GitHub repository or update URL';

  @override
  String get settingsUpdateSourceSaved => 'Update source saved';

  @override
  String get settingsUpToDate => 'Up to date';

  @override
  String get settingsViewPlaybackLogs => 'View playback logs';

  @override
  String get settingsViewPlaybackLogsSub =>
      'Copy logs to help diagnose SMB / WebDAV playback issues';

  @override
  String get statMinutes => 'Minutes';

  @override
  String get subtitleDecrease => 'Decrease';

  @override
  String get subtitleDelayOffset => 'Delay offset';

  @override
  String subtitleEditField(String field) {
    return 'Subtitle $field updated';
  }

  @override
  String get subtitleIncrease => 'Increase';

  @override
  String get subtitleInvalidNumber => 'Invalid number';

  @override
  String get subtitleLandscape => 'Landscape';

  @override
  String get subtitleNoLimit => 'No limit';

  @override
  String get subtitleOpacity => 'Opacity';

  @override
  String subtitleOrientationHint(String orientation) {
    return 'Editing: $orientation';
  }

  @override
  String get subtitlePortrait => 'Portrait';

  @override
  String subtitleRange(String range) {
    return 'Range: $range';
  }

  @override
  String get subtitleResetForPlayback => 'Reset for playback';

  @override
  String get subtitleSizeScale => 'Size scale';

  @override
  String get subtitleSourceEmbedded => 'Embedded';

  @override
  String get subtitleSourceExternal => 'External';

  @override
  String get subtitleSourceUnknown => 'Unknown source';

  @override
  String subtitleTooHigh(String value) {
    return 'Cannot be higher than $value';
  }

  @override
  String subtitleTooLow(String value) {
    return 'Cannot be lower than $value';
  }

  @override
  String get subtitleUnitPixels => 'Pixels';

  @override
  String get subtitleUnitSeconds => 'Seconds';

  @override
  String get subtitleVerticalOffset => 'Vertical offset';

  @override
  String get taskActionBusy => 'Busy';

  @override
  String get taskLoadMore => 'Load more';

  @override
  String get taskLoadingMore => 'Loading…';

  @override
  String get taskRecordDeleteConfirm =>
      'Delete this task record from the server? This action cannot be undone.';

  @override
  String get taskActionRetry => 'Retry';

  @override
  String get taskCancelSubmitted => 'Cancel submitted';

  @override
  String get taskCenterEyebrow => 'Background tasks';

  @override
  String taskCenterSubtitleActive(int active, int total) {
    return '$active/$total tasks active';
  }

  @override
  String taskCenterSubtitleIdle(int total) {
    return '$total tasks';
  }

  @override
  String get taskEmptyActive => 'No active tasks';

  @override
  String get taskEmptyAll => 'No tasks';

  @override
  String get taskEmptyCanceled => 'No canceled tasks';

  @override
  String get taskEmptyCompleted => 'No completed tasks';

  @override
  String get taskEmptyFailed => 'No failed tasks';

  @override
  String get taskEmptyHint =>
      'NFO, cloud transcription, audio extraction, and library scan tasks appear here';

  @override
  String get taskErrCancelExtract => 'Failed to cancel audio extraction';

  @override
  String get taskErrCancelTranscribe => 'Failed to cancel transcription';

  @override
  String get taskErrRetryTranscribe => 'Failed to retry transcription';

  @override
  String get taskFilterActive => 'Active';

  @override
  String get taskFilterAll => 'All';

  @override
  String get taskFilterCanceled => 'Canceled';

  @override
  String get taskFilterCompleted => 'Completed';

  @override
  String get taskFilterFailed => 'Failed';

  @override
  String get taskMsgCanceled => 'Task canceled';

  @override
  String get taskMsgRequeued => 'Task requeued';

  @override
  String get taskMsgScanPreparing => 'Preparing scan';

  @override
  String get taskMsgScanQueued => 'Scan queued';

  @override
  String taskMsgScanQueuedAt(int position) {
    return 'Queued (position $position)';
  }

  @override
  String get taskMsgWaitingUpdate => 'Waiting for update';

  @override
  String get taskNameActorSync => 'Actor sync';

  @override
  String get taskNameAudioExtract => 'Audio extraction';

  @override
  String get taskNameFallback => 'Background task';

  @override
  String get taskNameNfoSync => 'NFO sync';

  @override
  String get taskNameResourceScan => 'Resource scan';

  @override
  String get taskNameScan => 'Library scan';

  @override
  String get taskNameTranscribe => 'Transcription';

  @override
  String get taskRecordRemoved => 'Task record removed';

  @override
  String get taskUndo => 'Undo';

  @override
  String get unitDays => 'days';

  @override
  String get unitMinutes => 'Minutes';

  @override
  String get unitTimes => 'times';

  @override
  String get videoExtensionsAddLabel => 'Add';

  @override
  String get videoExtensionsCurrentLabel => 'Current';

  @override
  String get videoExtensionsDotHint => 'Dot';

  @override
  String get videoExtensionsEmpty => 'No video extensions configured';

  @override
  String get videoExtensionsSaveFailed => 'Failed to save video extensions';

  @override
  String get videoExtensionsSubtitle => 'Video extension settings';

  @override
  String get actorBatchDeleteTitle => 'Delete actors in bulk';

  @override
  String actorBatchDeleteWithRelations(int count) {
    return '$count selected actors include movie relationships. Force deletion removes the relationships but not the movies.';
  }

  @override
  String actorBatchDeleteConfirm(int count) {
    return 'Delete the $count selected actors?';
  }

  @override
  String actorBatchDeleted(int count) {
    return 'Deleted $count actors';
  }

  @override
  String actorBatchDeleteFailed(String error) {
    return 'Bulk actor deletion failed: $error';
  }

  @override
  String actorCount(int count) {
    return '$count actors';
  }

  @override
  String get actorCountSuffix => 'actors';

  @override
  String actorMovieCount(int count) {
    return '$count movies';
  }

  @override
  String get actorSearchHint => 'Search actor names';

  @override
  String get actorSortMovieCount => 'Movie count';

  @override
  String get actorSortName => 'Name';

  @override
  String get actorSortCreatedAt => 'Created';

  @override
  String get actorEditAction => 'Edit';

  @override
  String get actorDeleteAction => 'Delete';

  @override
  String get actorCancelAction => 'Cancel';

  @override
  String get actorEditorEditTitle => 'Edit actor';

  @override
  String get actorEditorCreateTitle => 'Create actor';

  @override
  String get actorEditorNameLabel => 'Actor name';

  @override
  String get actorEditorNameHint => 'Actor name';

  @override
  String get actorEditorBiographyHint => 'Enter a biography (optional)';

  @override
  String get actorEditorAssociationLabel => 'Associated names';

  @override
  String get actorEditorAssociationHint => 'One per line, optional';

  @override
  String get actorEditorSaveAction => 'Save';

  @override
  String get actorEditorCreateAction => 'Create';

  @override
  String get actorSaved => 'Actor saved';

  @override
  String get actorCreated => 'Actor created';

  @override
  String actorActionFailed(String error) {
    return 'Action failed: $error';
  }

  @override
  String get actorDeleteTitle => 'Delete actor';

  @override
  String actorDeleteWithMovies(String name, int count) {
    return '“$name” is linked to $count movies. Force deletion removes the relationship but not the movies.';
  }

  @override
  String actorDeleteAssociation(String name) {
    return '“$name” is an associated name. Deletion removes its movie relationships but not the movies.';
  }

  @override
  String actorDeleteConfirm(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get actorForceDeleteAction => 'Force delete';

  @override
  String get actorDeleted => 'Actor deleted';

  @override
  String actorDeleteFailed(String error) {
    return 'Failed to delete actor: $error';
  }

  @override
  String get actorAssociationBadge => 'Associated';

  @override
  String get actorEmptyTitle => 'No actors yet';

  @override
  String get actorEmptyHint => 'Tap the add button in the top right';

  @override
  String get serverSelectionTitle => 'Connections';

  @override
  String get serverSelectionSearchHint => 'Search connections';

  @override
  String get serverSelectionNoMatch => 'No matching connections';

  @override
  String get serverSelectionAddServer => 'Add server';

  @override
  String serverSelectionSelectServer(String name) {
    return 'Select $name';
  }

  @override
  String get serverCancelAction => 'Cancel';

  @override
  String get serverDeleteAction => 'Delete';

  @override
  String get serverLatency => 'Latency';

  @override
  String get serverProjectFeiniu => 'Feiniu';

  @override
  String get serverProjectDefault => 'Server';

  @override
  String get serverLineMain => 'Primary line';

  @override
  String get forceDelete => 'Force delete';

  @override
  String get merge => 'Merge';

  @override
  String get create => 'Create';

  @override
  String get saved => 'Saved';

  @override
  String get created => 'Created';

  @override
  String get deleted => 'Deleted';

  @override
  String deleteFailed(String error) {
    return 'Failed to delete: $error';
  }

  @override
  String get translating => 'Translating';

  @override
  String get translate => 'Translate';

  @override
  String get merging => 'Merging';

  @override
  String get confirmMerge => 'Confirm merge';

  @override
  String get reset => 'Reset';

  @override
  String get include => 'Include';

  @override
  String get exclude => 'Exclude';

  @override
  String get unlimited => 'Any';

  @override
  String get done => 'Done';

  @override
  String get use => 'Use';

  @override
  String loadFailedWithError(String error) {
    return 'Load failed: $error';
  }

  @override
  String get advancedFilterTitle => 'Advanced filters';

  @override
  String get advancedFilterSubtitle =>
      'Combine tags, genres, series, years, ratings, and file properties';

  @override
  String get advancedFilterYearAndRating => 'Year and rating';

  @override
  String get advancedFilterYearRange => 'Year range';

  @override
  String get advancedFilterYearFrom => 'From year';

  @override
  String get advancedFilterYearTo => 'To year';

  @override
  String get advancedFilterYearRangeInvalid =>
      'The start year cannot be later than the end year';

  @override
  String get advancedFilterRatingRange => 'Rating range';

  @override
  String get advancedFilterMinRating => 'Minimum rating';

  @override
  String get advancedFilterMaxRating => 'Maximum rating';

  @override
  String advancedFilterRatingAbove(int rating) {
    return '$rating+ rating';
  }

  @override
  String advancedFilterRatingBelow(int rating) {
    return '$rating- rating';
  }

  @override
  String get advancedFilterSubtitlesAndFiles => 'Subtitles and files';

  @override
  String get advancedFilterExternalSubtitles => 'External subtitles';

  @override
  String get advancedFilterIncludeExternalSubtitles =>
      'With external subtitles';

  @override
  String get advancedFilterExcludeExternalSubtitles =>
      'Without external subtitles';

  @override
  String get advancedFilterFileFilter => 'File filter';

  @override
  String get advancedFilterOnlyStandard => 'Standard only';

  @override
  String get advancedFilterOnlyCrack => 'Cracked only';

  @override
  String get advancedFilterOnlyChineseSubtitle => 'Chinese subtitles only';

  @override
  String get advancedFilterOnlyChineseCrack => 'Chinese cracked only';

  @override
  String get advancedFilterApply => 'Apply filters';

  @override
  String get resourceGenresManage => 'Genre management';

  @override
  String get resourceTagsManage => 'Tag management';

  @override
  String get resourceSeriesManage => 'Series management';

  @override
  String get resourceGenresSearchHint => 'Search genre names';

  @override
  String get resourceTagsSearchHint => 'Search tag names';

  @override
  String get resourceSeriesSearchHint => 'Search series names';

  @override
  String resourceBatchDeleteTitle(String kind) {
    return 'Delete $kind in bulk';
  }

  @override
  String resourceBatchDeleteWithMovies(int count, String kind) {
    return 'The $count selected $kind include movie relationships. Force deletion removes the relationships but not the movies.';
  }

  @override
  String resourceBatchDeleteConfirm(int count, String kind) {
    return 'Delete the $count selected $kind?';
  }

  @override
  String resourceBatchDeleted(int count, String kind) {
    return 'Deleted $count $kind';
  }

  @override
  String resourceBatchDeleteFailed(String error) {
    return 'Bulk deletion failed: $error';
  }

  @override
  String resourceCountSuffix(String kind) {
    return '$kind';
  }

  @override
  String get resourceSortName => 'Name';

  @override
  String get resourceSortMovieCount => 'Movie count';

  @override
  String get resourceSortCreatedAt => 'Created';

  @override
  String get resourceTranslateEmpty =>
      'The name is empty; nothing to translate';

  @override
  String get resourceTranslateNoResult => 'The translated name is empty';

  @override
  String get resourceTranslateSuccess => 'Translated';

  @override
  String resourceTranslateFailed(String error) {
    return 'Translation failed: $error';
  }

  @override
  String resourceEditTitle(String kind) {
    return 'Edit $kind';
  }

  @override
  String resourceCreateTitle(String kind) {
    return 'Create $kind';
  }

  @override
  String resourceNameHint(String kind) {
    return '$kind name';
  }

  @override
  String get resourceAutoMapping => 'Automatic mapping';

  @override
  String resourceDeleteTitle(String kind) {
    return 'Delete $kind';
  }

  @override
  String resourceDeleteWithMovies(String name, int count) {
    return '“$name” is linked to $count movies. Force deletion removes all relationships but not the movies.';
  }

  @override
  String resourceDeleteConfirm(String name) {
    return 'Delete “$name”?';
  }

  @override
  String resourceEmptyTitle(String kind) {
    return 'No $kind yet';
  }

  @override
  String get resourceEmptyHint =>
      'Tap the add button in the top right to create the first one';

  @override
  String get resourceMoviesEmpty => 'No movies in this dimension yet';

  @override
  String resourceMovieCount(int count) {
    return '$count movies';
  }

  @override
  String resourceMovieCountWithName(String name, int count) {
    return '$name · $count movies';
  }

  @override
  String resourceMergeTitle(String kind) {
    return 'Merge $kind in bulk';
  }

  @override
  String resourceMergeSubtitle(int count, String kind) {
    return 'Merge $count $kind into one; movie relationships move to the retained item.';
  }

  @override
  String resourceMergeKeep(String kind) {
    return 'Retain $kind';
  }

  @override
  String resourceMergeFailed(String error) {
    return 'Merge failed: $error';
  }

  @override
  String entityPickerTitle(String kind) {
    return 'Select $kind';
  }

  @override
  String entityPickerSelected(int count) {
    return '$count selected';
  }

  @override
  String get entityPickerSearchName => 'Search names';

  @override
  String get entityPickerSearchNameOrAlias => 'Search names / aliases';

  @override
  String get entityPickerNoResourceMatch => 'No matching resources';

  @override
  String get entityPickerNoActorMatch => 'No matching actors';

  @override
  String get entityPickerNoSeriesMatch => 'No matching series';

  @override
  String entityPickerSelect(String kind) {
    return 'Select $kind…';
  }

  @override
  String movieCountShort(int count) {
    return '$count';
  }

  @override
  String get batchEditNothingSelected =>
      'Select at least one item to add, remove, or crop';

  @override
  String batchEditWatermarkResult(int success, int failed) {
    return 'Poster crop: $success succeeded, $failed failed';
  }

  @override
  String get batchEditSaved => 'Bulk edit completed';

  @override
  String batchEditFailed(String error) {
    return 'Bulk edit failed: $error';
  }

  @override
  String batchEditTitle(int count) {
    return 'Bulk edit $count movies';
  }

  @override
  String get batchEditSubtitle =>
      'Adjust tags, genres, series, and quick flags together';

  @override
  String get batchEditQuickFlags => 'Quick flags';

  @override
  String get batchEditQuickFlagsSubtitle =>
      'Poster watermark cropping is synchronized when saving';

  @override
  String get movieFlagSubtitle => 'Subtitles';

  @override
  String get movieFlagExternalSubtitle => 'External subtitles';

  @override
  String get movieFlagCrack => 'Cracked';

  @override
  String get batchEditSubtitleExclusive =>
      'Embedded and external subtitle flags are mutually exclusive';

  @override
  String get batchEditTagSubtitle => 'Choose tags to add and remove separately';

  @override
  String batchEditAdd(String kind) {
    return 'Add $kind';
  }

  @override
  String batchEditRemoveCommon(String kind) {
    return 'Remove $kind (common only)';
  }

  @override
  String get batchEditSeriesSubtitle =>
      'Set the series for all selected movies';

  @override
  String batchEditNoCommon(String kind) {
    return 'No common $kind';
  }

  @override
  String get loadingEllipsis => 'Loading…';

  @override
  String get batchEditSeriesSearchFailed =>
      'Series search failed; try again later';

  @override
  String get batchEditSeriesLoadMoreFailed =>
      'Loading more series failed; try again later';

  @override
  String get batchEditSeriesSearchHint => 'Search series…';

  @override
  String get batchEditSeriesEmpty => 'No series yet';

  @override
  String get batchEditClearSeries => 'Clear selection';

  @override
  String get detailActorRelatedMovies => 'Movies related to this actor';

  @override
  String get detailFile => 'File';

  @override
  String get detailMovieFile => 'Movie file';

  @override
  String get detailFilePath => 'File path';

  @override
  String get detailNumber => 'Number';

  @override
  String get detailCountry => 'Country/Region';

  @override
  String get detailRuntime => 'Runtime';

  @override
  String detailRuntimeMinutes(Object minutes) {
    return '$minutes minutes';
  }

  @override
  String get detailFileSize => 'File size';

  @override
  String get detailPart => 'Part';

  @override
  String get detailDownloadedAt => 'Downloaded at';

  @override
  String get detailContainer => 'Container';

  @override
  String get detailSize => 'Size';

  @override
  String get detailMediaInfo => 'Media information';

  @override
  String detailDurationHours(int hours, String minutes, String seconds) {
    return '${hours}h ${minutes}m ${seconds}s';
  }

  @override
  String detailDurationMinutes(int minutes, String seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String get detailAudioExtractionSubmitted =>
      'Audio extraction task submitted';

  @override
  String get detailSyncNfoTitle => 'Sync NFO';

  @override
  String get detailSyncNfoMessage =>
      'Sync this movie\'s information to the NFO file?';

  @override
  String get detailSyncNfoSuccess => 'NFO synced successfully';

  @override
  String get detailRefreshNfoTitle => 'Refresh from NFO';

  @override
  String get detailRefreshNfoMessage =>
      'Refresh this movie\'s information from the NFO file?';

  @override
  String get detailRefreshNfoSuccess => 'Movie information refreshed from NFO';

  @override
  String get detailEditMovie => 'Edit movie';

  @override
  String get detailFetchMetadata => 'Fetch metadata';

  @override
  String get detailFetchResources => 'Fetch resources';

  @override
  String get detailFetchSubtitles => 'Fetch subtitles';

  @override
  String get detailExtractAudio => 'Extract audio';

  @override
  String get detailDeleteMovieTitle => 'Delete movie';

  @override
  String detailDeleteMovieMessage(String title) {
    return 'Delete movie \"$title\"?';
  }

  @override
  String get detailPlotTitle => 'Plot';

  @override
  String get detailPlotViewFull => 'View full plot';

  @override
  String get fanartFetchDone => 'Additional previews fetched';

  @override
  String fanartFetchFailed(String error) {
    return 'Failed to fetch additional previews: $error';
  }

  @override
  String get fanartTitle => 'Previews';

  @override
  String get fanartRefresh => 'Refresh previews';

  @override
  String get fanartFetch => 'Fetch previews';

  @override
  String get fanartLoading => 'Loading previews…';

  @override
  String fanartLoadFailed(String error) {
    return 'Failed to load previews: $error';
  }

  @override
  String get fanartEmpty => 'No previews';

  @override
  String get fanartClose => 'Close previews';

  @override
  String get fanartTrailerPlaybackFailed => 'Failed to play trailer';

  @override
  String coverBadgeCodecTooltip(String codec) {
    return 'Video codec: $codec';
  }

  @override
  String coverBadgeRangeTooltip(String range) {
    return 'Dynamic range: $range';
  }

  @override
  String get coverBadgeStrmTooltip => 'STRM video file';

  @override
  String get coverBadgeEmbeddedSubtitleTooltip => 'Embedded subtitle';

  @override
  String get coverBadgeCrackTooltip => 'Crack/uncensored';

  @override
  String get coverBadgeResolutionUhdTooltip => '2160p / 4K';

  @override
  String get coverBadgeResolutionHdTooltip => '720p and above';

  @override
  String get mediaStreamVideo => 'Video';

  @override
  String mediaStreamAudio(int ordinal) {
    return 'Audio $ordinal';
  }

  @override
  String get mediaStreamSubtitles => 'Subtitles';

  @override
  String get mediaStreamDefault => 'Default';

  @override
  String get mediaStreamForced => 'Forced';

  @override
  String get mediaStreamText => 'Text';

  @override
  String get mediaStreamBitmap => 'Bitmap';

  @override
  String mediaStreamCount(int count) {
    return '$count tracks';
  }

  @override
  String get mediaStreamEncoding => 'Encoding';

  @override
  String get mediaStreamProfile => 'Profile';

  @override
  String get mediaStreamLevel => 'Level';

  @override
  String get mediaStreamResolution => 'Resolution';

  @override
  String get mediaStreamAspectRatio => 'Aspect ratio';

  @override
  String get mediaStreamFrameRate => 'Frame rate';

  @override
  String get mediaStreamColorPrimaries => 'Color primaries';

  @override
  String get mediaStreamColorSpace => 'Color space';

  @override
  String get mediaStreamTransfer => 'Transfer characteristics';

  @override
  String get mediaStreamRange => 'Color range';

  @override
  String get mediaStreamBitDepth => 'Bit depth';

  @override
  String get mediaStreamPixelFormat => 'Pixel format';

  @override
  String get mediaStreamBitrate => 'Bitrate';

  @override
  String get mediaStreamLanguage => 'Language';

  @override
  String get mediaStreamLayout => 'Layout';

  @override
  String get mediaStreamChannelsLabel => 'Channels';

  @override
  String mediaStreamChannels(int count) {
    return '$count ch';
  }

  @override
  String get mediaStreamSampleRate => 'Sample rate';

  @override
  String get mediaStreamTitle => 'Title';

  @override
  String get mediaLanguageJapanese => 'Japanese';

  @override
  String get mediaLanguageEnglish => 'English';

  @override
  String get mediaLanguageChinese => 'Chinese';

  @override
  String get mediaLanguageCantonese => 'Cantonese';

  @override
  String get mediaLanguageKorean => 'Korean';

  @override
  String get mediaLanguageFrench => 'French';

  @override
  String get mediaLanguageRussian => 'Russian';

  @override
  String get mediaLanguageSpanish => 'Spanish';

  @override
  String get mediaLanguageGerman => 'German';

  @override
  String get mediaLanguageThai => 'Thai';

  @override
  String get mediaLanguageUndetermined => 'Undetermined';

  @override
  String get moviesFilterDuplicateNum => 'Duplicate code';

  @override
  String get moviesFilterNewResources => 'New resources';

  @override
  String get moviesScanResources => 'Scan resources';

  @override
  String get moviesScanning => 'Scanning';

  @override
  String get moviesBatchEdit => 'Edit';

  @override
  String get moviesBatchDownload => 'Download';

  @override
  String get moviesBatchScan => 'Scan';

  @override
  String get moviesBatchCompare => 'Compare';

  @override
  String get moviesBatchMerge => 'Merge';

  @override
  String moviesFavoriteAdded(String title) {
    return 'Added to favorites: \"$title\"';
  }

  @override
  String moviesFavoriteRemoved(String title) {
    return 'Removed from favorites: \"$title\"';
  }

  @override
  String moviesOperationFailed(String error) {
    return 'Operation failed: $error';
  }

  @override
  String get moviesNoScannable => 'There are no movies to scan';

  @override
  String get moviesScanSelectedTitle => 'Scan selected movies';

  @override
  String get moviesScanFilteredTitle => 'Scan filtered results';

  @override
  String moviesScanSelectedMessage(int count) {
    return 'Scan the $count selected movies?';
  }

  @override
  String moviesScanFilteredMessage(int count) {
    return 'Scan the $count movies in the current filtered result, including all pages?';
  }

  @override
  String get moviesStartScan => 'Start scan';

  @override
  String moviesScanSubmitted(int count, String skipped) {
    return 'Submitted $count movies$skipped';
  }

  @override
  String moviesScanSkipped(int count) {
    return ', skipped $count invalid movies';
  }

  @override
  String moviesScanCreateFailed(String error) {
    return 'Failed to create resource scan task: $error';
  }

  @override
  String get moviesNeedSameNumber =>
      'Select at least 2 movies with the same code';

  @override
  String get moviesSortSheetTitle => 'Sort';

  @override
  String get moviesSortAscending => 'Ascending';

  @override
  String get moviesSortDescending => 'Descending';

  @override
  String get moviesSortFileSize => 'File size';

  @override
  String get moviesSortCreatedAt => 'Created';

  @override
  String get moviesSortUpdatedAt => 'Updated';

  @override
  String get moviesSortDownloadedAt => 'Download date';

  @override
  String get moviesUpdatedStatus => 'Update status';

  @override
  String get moviesUpdated => 'Updated';

  @override
  String get moviesNotUpdated => 'Not updated';

  @override
  String get moviesUnlimited => 'Any';

  @override
  String get moviesFavorite => 'Favorite';

  @override
  String get moviesUnfavorite => 'Unfavorite';

  @override
  String moviesBatchDownloadTitle(int count) {
    return 'Batch download $count movies';
  }

  @override
  String get moviesBatchDownloadSubtitle =>
      'Submit downloads in bulk; movies without a code are skipped';

  @override
  String get moviesDownloadQuality => 'Quality preference';

  @override
  String get moviesDownloadQualityHint =>
      'For example 4k, hd, or uhd; leave blank for any';

  @override
  String get moviesDownloadMinSize => 'Minimum size (MB)';

  @override
  String get moviesDownloadMaxSize => 'Maximum size (MB)';

  @override
  String get moviesDownloadMaxFiles => 'Maximum file count';

  @override
  String get moviesDownloadDate => 'After date';

  @override
  String get moviesDownloadNoLimit => '0 = Any';

  @override
  String get moviesDownloadRequireSubtitle => 'Require subtitles';

  @override
  String get moviesDownloadRequireUncensored => 'Require uncensored';

  @override
  String get moviesDownloadWashMode => 'Wash mode';

  @override
  String get moviesDownloadWashModeHint =>
      'Redownload movies that already exist';

  @override
  String moviesDownloadFailed(String error) {
    return 'Download request failed: $error';
  }

  @override
  String get moviesSubmitting => 'Submitting…';

  @override
  String get moviesConfirmSubmit => 'Submit';

  @override
  String get moviesMergeStarted => 'Merge task started';

  @override
  String moviesMergeFailed(String error) {
    return 'Merge failed: $error';
  }

  @override
  String moviesMergeTitle(int count) {
    return 'Merge $count duplicate movies';
  }

  @override
  String get moviesMergeSubtitle =>
      'Choose the primary movie; other files move into its directory';

  @override
  String get moviesMergeWarning =>
      'Same-name video files will be overwritten; conflicting non-primary records will be deleted';

  @override
  String get moviesMergeSameFolder =>
      'All selected movies are already in the same directory; no merge is needed';

  @override
  String get moviesMerging => 'Merging…';

  @override
  String get moviesConfirmMerge => 'Merge';

  @override
  String get moviesUntitled => 'Untitled';

  @override
  String get moviesNoCode => 'No code';

  @override
  String get moviesPathUnavailable => 'Path unavailable';

  @override
  String get moviesNfoSynced => 'NFO synced';

  @override
  String moviesApplyFailed(String error) {
    return 'Apply failed: $error';
  }

  @override
  String get moviesCompareNfoTitle => 'Compare duplicate NFOs';

  @override
  String get moviesCompareNfoSubtitle => 'Choose a sync source for each field';

  @override
  String get moviesCompareNfoNoChanges =>
      'Titles, descriptions, plots, and ratings are identical; no selection is needed';

  @override
  String get moviesApplying => 'Applying…';

  @override
  String get moviesApplySync => 'Apply sync';

  @override
  String moviesMovieWithId(int id) {
    return 'Movie $id';
  }

  @override
  String get moviesEmptyValue => '(Empty)';

  @override
  String get resourceScanTitle => 'Scan resources';

  @override
  String get resourceScanProgress => 'Resource scan progress';

  @override
  String get resourceScanConnecting => 'Connecting…';

  @override
  String get resourceScanSuccess => 'Success';

  @override
  String get resourceScanFailed => 'Failed';

  @override
  String get resourceScanNewResources => 'New resources';

  @override
  String get resourceScanBackground => 'Run in background';

  @override
  String get resourceScanClose => 'Close';

  @override
  String get resourceScanDone => 'Done';

  @override
  String get resourceScanPreparing => 'Preparing';

  @override
  String get resourceScanRunning => 'Scanning';

  @override
  String get resourceScanCompleted => 'Completed';

  @override
  String get moviesNfoFieldTitle => 'Title';

  @override
  String get moviesNfoFieldDescription => 'Description';

  @override
  String get moviesNfoFieldPlot => 'Plot';

  @override
  String get moviesNfoFieldRating => 'Rating';

  @override
  String get moviesNfoFieldYear => 'Year';

  @override
  String get moviesNfoFieldRuntime => 'Runtime';

  @override
  String get moviesNfoFieldDate => 'Date';

  @override
  String subtitlePreviewFailed(String error) {
    return 'Preview failed: $error';
  }

  @override
  String subtitleDownloaded(String name) {
    return 'Downloaded $name';
  }

  @override
  String subtitleDownloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String get subtitleExistsTitle => 'Subtitle already exists';

  @override
  String get subtitleExistsMessage =>
      'A subtitle file with the same name already exists. Overwrite it?';

  @override
  String get subtitlePreviewTitle => 'Subtitle preview';

  @override
  String get subtitleSearchTitle => 'Fetch subtitles';

  @override
  String subtitleSearchKeyword(String keyword) {
    return 'Keyword: $keyword';
  }

  @override
  String get subtitleNoMatch => 'No matching subtitles found';

  @override
  String get subtitlePreview => 'Preview';

  @override
  String get subtitleDownload => 'Download';

  @override
  String get subtitleCopy => 'Copy';

  @override
  String get subtitleCopied => 'All content copied';

  @override
  String get audioExtractTitle => 'Extract audio';

  @override
  String get audioExtractFormat => 'Output format';

  @override
  String get audioExtractBitrate => 'Target bitrate';

  @override
  String get audioExtractFailed => 'Failed to create audio extraction task';

  @override
  String get audioExtractSubmitting => 'Submitting…';

  @override
  String get audioExtractSubmit => 'Submit task';

  @override
  String dboAppliedFields(int count) {
    return 'Applied $count fields';
  }

  @override
  String dboApplyFailed(String error) {
    return 'Apply failed: $error';
  }

  @override
  String get dboTitle => 'DB Online metadata';

  @override
  String get dboUpToDate => 'Local metadata is up to date';

  @override
  String get dboNoOverridableFields => 'There are no fields to override';

  @override
  String get dboSelectAll => 'Select all';

  @override
  String get dboClear => 'Clear';

  @override
  String dboApplyCount(int count) {
    return 'Apply ($count)';
  }

  @override
  String get dboSelectFields => 'Select fields to apply';

  @override
  String get dboCurrent => 'Current:';

  @override
  String get dboSectionInfo => 'Movie information';

  @override
  String get dboSectionSeries => 'Series';

  @override
  String get dboSectionGenres => 'Genres';

  @override
  String get dboSectionActors => 'Actors';

  @override
  String get dboFemale => 'Female';

  @override
  String get dboMale => 'Male';

  @override
  String get dboFieldTitle => 'Title';

  @override
  String get dboFieldRating => 'Rating';

  @override
  String get dboFieldYear => 'Year';

  @override
  String get dboFieldRuntime => 'Runtime';

  @override
  String get dboFieldPlot => 'Plot';

  @override
  String get dboRemove => 'Remove';

  @override
  String get movieEditorQuickActions => 'Cover watermark · Quick actions';

  @override
  String get movieEditorFanartCrop => 'Cover crop (Fanart)';

  @override
  String get movieEditorTitle => 'Edit movie';

  @override
  String get movieEditorOriginalTitle => 'Original title';

  @override
  String get movieEditorNumber => 'Number';

  @override
  String get movieEditorYear => 'Year';

  @override
  String get movieEditorRating => 'Rating';

  @override
  String get movieEditorRuntime => 'Runtime (min)';

  @override
  String get movieEditorSeries => 'Series';

  @override
  String get movieEditorGenre => 'Genres';

  @override
  String get movieEditorTag => 'Tags';

  @override
  String get movieEditorActor => 'Actors';

  @override
  String get movieEditorFieldTitle => 'Title';

  @override
  String get movieEditorFieldCountry => 'Country';

  @override
  String get movieEditorFieldPlot => 'Plot';

  @override
  String movieEditorSelectEntity(String entity) {
    return 'Tap to select $entity';
  }

  @override
  String movieEditorUntitledEntity(String entity) {
    return 'Unnamed $entity';
  }

  @override
  String movieEditorQuickActionFailed(String error) {
    return 'Quick action failed: $error';
  }

  @override
  String get movieEditorBatchTranslating => 'Translating all fields';

  @override
  String get movieEditorBatchTranslate => 'Translate all';

  @override
  String movieEditorFieldEmpty(String label) {
    return '$label is empty; nothing to translate';
  }

  @override
  String movieEditorTranslationEmpty(String label) {
    return '$label translation is empty';
  }

  @override
  String movieEditorTranslationSuccess(String label) {
    return '$label translated successfully';
  }

  @override
  String movieEditorTranslationFailed(String label, String error) {
    return '$label translation failed: $error';
  }

  @override
  String get movieEditorNoTranslatableContent =>
      'There is no content to translate';

  @override
  String movieEditorBatchResult(int success, int total) {
    return 'Translate all: $success / $total succeeded';
  }

  @override
  String get movieEditorBatchNoResult => 'Translation returned no results';

  @override
  String movieEditorBatchFailed(String error) {
    return 'Batch translation failed: $error';
  }

  @override
  String get movieEditorTranslating => 'Translating';

  @override
  String get resourceSourceDetail => 'Movie details resources';

  @override
  String get resourceSourceCustom => 'Custom resources';

  @override
  String get resourceSourceNyaa => 'Nyaa resources';

  @override
  String get resourceNoDownloaders => 'No available downloader is configured';

  @override
  String get resourceSelectDownloader => 'Select downloader';

  @override
  String resourcePushFailed(String error) {
    return 'Push failed: $error';
  }

  @override
  String get resourceOnline => 'Online resources';

  @override
  String resourceMagnetCount(int count) {
    return 'Magnet ($count)';
  }

  @override
  String resourceEd2kCount(int count) {
    return 'ED2K ($count)';
  }

  @override
  String get resourceLoadingOnline => 'Loading online resources…';

  @override
  String get resourceWaitingSources =>
      'No resources from the returned sources yet; waiting for the others…';

  @override
  String get resourceNoMagnet => 'No magnet resources';

  @override
  String get resourceNoEd2k => 'No ED2K resources';

  @override
  String get resourceFallbackTitle => 'Resource';

  @override
  String resourceFrom(String source) {
    return 'From $source';
  }

  @override
  String get resourceCopy => 'Copy';

  @override
  String get resourceCopied => 'Copied';

  @override
  String get resourcePushing => 'Pushing';

  @override
  String get resourcePushDownload => 'Push download';

  @override
  String resourceRecentlyDownloaded(String value) {
    return 'Downloaded recently: $value';
  }

  @override
  String resourceRecentlyDownloadedAt(String date) {
    return 'Downloaded recently: $date';
  }

  @override
  String get playerBuffering => 'Buffering…';

  @override
  String get audioNotificationChannelName => 'Music playback';

  @override
  String get audioNotificationChannelDescription =>
      'File manager music playback controls';

  @override
  String get audioUnknownTitle => 'Unknown audio';

  @override
  String get audioFileManagerAlbum => 'File manager';

  @override
  String audioPlaybackFailed(String error) {
    return 'Audio playback failed: $error';
  }

  @override
  String get audioPlaybackFailedGeneric => 'Audio playback failed';

  @override
  String get personNoMovies => 'No movies for this actor';

  @override
  String get personSyncAssociations => 'Sync actor associations';

  @override
  String get mediaBrowserSimilar => 'More like this';

  @override
  String get posterCropEnableHint =>
      'Enable cropping with a quick action above';

  @override
  String get posterCropGestureHint =>
      'Drag horizontally or tap to position the crop';

  @override
  String get playerLandscapeCameraLeft => 'Camera on the left';

  @override
  String get playerLandscapeCameraRight => 'Camera on the right';

  @override
  String get playerOrientationUnchanged => 'Unchanged';

  @override
  String get playerOrientationForceLandscape => 'Force landscape';

  @override
  String get playerOrientationForcePortrait => 'Force portrait';

  @override
  String get playerPreload250Mb => '250MB';

  @override
  String get playerPreload500Mb => '500MB';

  @override
  String get playerPreload750Mb => '750MB';

  @override
  String get playerPreload1Gb => '1GB';

  @override
  String get hapticIntensityOff => 'Off';

  @override
  String get hapticIntensityLow => 'Light';

  @override
  String get hapticIntensityStandard => 'Standard';

  @override
  String get hapticIntensityHigh => 'Strong';

  @override
  String get favoriteListAllTimeBest => 'All-time best';

  @override
  String get favoriteListAfterHours => 'Private';
}
