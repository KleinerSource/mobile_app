import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'series_api.g.dart';

@RestApi()
abstract class SeriesApi {
  factory SeriesApi(Dio dio, {String baseUrl}) = _SeriesApi;

  @GET('/series')
  Future<dynamic> list(@Queries() Map<String, dynamic> q);

  @POST('/series')
  Future<dynamic> create(@Body() Map<String, dynamic> body);

  @PATCH('/series/{id}')
  Future<dynamic> update(
    @Path('id') int id,
    @Body() Map<String, dynamic> body,
  );

  @POST('/series/batch-delete')
  Future<dynamic> batchDelete(@Body() Map<String, dynamic> body);
}
