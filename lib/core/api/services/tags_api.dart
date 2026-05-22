import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'tags_api.g.dart';

@RestApi()
abstract class TagsApi {
  factory TagsApi(Dio dio, {String baseUrl}) = _TagsApi;

  @GET('/tags')
  Future<dynamic> list(@Queries() Map<String, dynamic> q);
}
