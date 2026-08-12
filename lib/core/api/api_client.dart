import 'package:dio/dio.dart';

import '../auth/auth_session_repository.dart';
import '../config/server_config.dart';
import 'dio_factory.dart';
import 'services/auth_api.dart';
import 'services/actors_api.dart';
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
import 'services/mappings_extended_api.dart';
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
        translation = TranslationApi(dio),
        mappings = MappingsApi(dio),
        mappingsExtended = MappingsExtendedApi(dio),
        configs = ConfigsApi(dio),
        configsExtended = ConfigsExtendedApi(dio);

  factory ApiClient.fromConfig(
    ServerConfig config, {
    AuthSessionRepository? sessionRepository,
    void Function()? onSessionExpired,
  }) {
    return ApiClient(
      buildDio(
        config,
        sessionRepository: sessionRepository,
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
  final TranslationApi translation;
  final MappingsApi mappings;
  final MappingsExtendedApi mappingsExtended;
  final ConfigsApi configs;
  final ConfigsExtendedApi configsExtended;
  final SystemExtendedApi systemExtended;
}
