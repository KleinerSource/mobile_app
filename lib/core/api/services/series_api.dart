import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'series_api.g.dart';

@RestApi()
abstract class SeriesApi {
  factory SeriesApi(Dio dio, {String baseUrl}) = _SeriesApi;

  @GET('/series')
  Future<Map<String, dynamic>> list(@Queries() Map<String, dynamic> q);
}
