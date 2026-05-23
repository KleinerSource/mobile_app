import 'package:dio/dio.dart';

import '../config/server_config.dart';
import 'dio_factory.dart';
import 'services/actors_api.dart';
import 'services/configs_api.dart';
import 'services/directories_api.dart';
import 'services/favorites_api.dart';
import 'services/genres_api.dart';
import 'services/libraries_api.dart';
import 'services/mappings_api.dart';
import 'services/movies_api.dart';
import 'services/series_api.dart';
import 'services/system_api.dart';
import 'services/tags_api.dart';
import 'services/translation_api.dart';

class ApiClient {
  ApiClient(this.dio)
      : system = SystemApi(dio),
        movies = MoviesApi(dio),
        favorites = FavoritesApi(dio),
        libraries = LibrariesApi(dio),
        tags = TagsApi(dio),
        genres = GenresApi(dio),
        series = SeriesApi(dio),
        actors = ActorsApi(dio),
        directories = DirectoriesApi(dio),
        translation = TranslationApi(dio),
        mappings = MappingsApi(dio),
        configs = ConfigsApi(dio);

  factory ApiClient.fromConfig(ServerConfig config) => ApiClient(buildDio(config));

  final Dio dio;
  final SystemApi system;
  final MoviesApi movies;
  final FavoritesApi favorites;
  final LibrariesApi libraries;
  final TagsApi tags;
  final GenresApi genres;
  final SeriesApi series;
  final ActorsApi actors;
  final DirectoriesApi directories;
  final TranslationApi translation;
  final MappingsApi mappings;
  final ConfigsApi configs;
}
