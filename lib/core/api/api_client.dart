import 'package:dio/dio.dart';

import '../auth/auth_session_repository.dart';
import '../config/server_config.dart';
import 'dio_factory.dart';
import '../../features/media_browser/api/feiniu_api.dart';
import 'services/auth_api.dart';
import 'server_compatibility.dart';
import 'services/actors_api.dart';
import 'services/audio_api.dart';
import 'services/configs_api.dart';
import 'services/favorites_api.dart';
import 'services/genres_api.dart';
import 'services/libraries_api.dart';
import 'services/mappings_api.dart';
import 'services/movies_api.dart';
import 'services/playback_api.dart';
import 'services/movies_extended_api.dart';
import 'services/libraries_extended_api.dart';
import 'services/catalog_extended_api.dart';
import 'services/configs_extended_api.dart';
import 'package:omm/features/db_online/api/db_online_api.dart';
import 'package:omm/features/media_browser/api/media_browser_api.dart';
import 'package:omm/features/media_browser/api/media_browser_config.dart';
import 'services/mappings_extended_api.dart';
import 'services/modal_transcription_api.dart';
import 'services/series_api.dart';
import 'services/system_api.dart';
import 'services/system_extended_api.dart';
import 'services/tags_api.dart';
import 'services/translation_api.dart';

class ApiClient {
  ApiClient(this.dio, {this.config})
    : auth = AuthApi(dio),
      system = SystemApi(dio),
      systemExtended = SystemExtendedApi(dio, config: config),
      movies = MoviesApi(dio),
      moviesExtended = MoviesExtendedApi(dio),
      playback = PlaybackApi(dio),
      favorites = FavoritesApi(dio),
      libraries = LibrariesApi(dio),
      librariesExtended = LibrariesExtendedApi(dio),
      catalog = CatalogExtendedApi(dio),
      tags = TagsApi(dio),
      genres = GenresApi(dio),
      series = SeriesApi(dio),
      actors = ActorsApi(dio),
      audio = AudioApi(dio),
      translation = TranslationApi(dio),
      modalTranscription = ModalTranscriptionApi(dio),
      mappings = MappingsApi(dio),
      mappingsExtended = MappingsExtendedApi(dio),
      configs = ConfigsApi(dio),
      configsExtended = ConfigsExtendedApi(dio),
      dbOnline = DbOnlineApi(dio),
      emby = MediaBrowserApi(dio, MediaBrowserConfig.emby),
      jellyfin = MediaBrowserApi(dio, MediaBrowserConfig.jellyfin),
      feiniu = FeiniuApi(dio);

  factory ApiClient.fromConfig(
    ServerConfig config, {
    AuthSessionRepository? sessionRepository,
    void Function()? onSessionExpired,
  }) {
    final activeProject = config.activeServer?.project;
    // DBO/Emby/Jellyfin 只有 access token，不能参与 OMM 旧版全局令牌迁移。
    final allowLegacyMigration =
        activeProject != ServerProject.dbOnline &&
        activeProject != ServerProject.emby &&
        activeProject != ServerProject.jellyfin &&
        activeProject != ServerProject.feiniu;
    sessionRepository?.setActiveServerId(
      config.activeServerId,
      allowLegacyMigration: allowLegacyMigration,
    );
    final scopedSessionRepository = sessionRepository?.forServer(
      config.activeServerId,
      allowLegacyMigration: allowLegacyMigration,
    );
    return ApiClient(
      buildDio(
        config,
        sessionRepository: scopedSessionRepository,
        onSessionExpired: onSessionExpired,
      ),
      config: config,
    );
  }

  final Dio dio;
  final ServerConfig? config;
  final AuthApi auth;
  final SystemApi system;
  final MoviesApi movies;
  final MoviesExtendedApi moviesExtended;
  final PlaybackApi playback;
  final FavoritesApi favorites;
  final LibrariesApi libraries;
  final LibrariesExtendedApi librariesExtended;
  final CatalogExtendedApi catalog;
  final TagsApi tags;
  final GenresApi genres;
  final SeriesApi series;
  final ActorsApi actors;
  final AudioApi audio;
  final TranslationApi translation;
  final ModalTranscriptionApi modalTranscription;
  final MappingsApi mappings;
  final MappingsExtendedApi mappingsExtended;
  final ConfigsApi configs;
  final ConfigsExtendedApi configsExtended;
  final DbOnlineApi dbOnline;
  final MediaBrowserApi emby;
  final MediaBrowserApi jellyfin;
  final FeiniuApi feiniu;
  final SystemExtendedApi systemExtended;

  /// 取 [config] 对应的 MediaBrowser（Emby/Jellyfin）API 实例。
  MediaBrowserApi mediaBrowserFor(MediaBrowserConfig config) =>
      config.project == ServerProject.jellyfin ? jellyfin : emby;
}
