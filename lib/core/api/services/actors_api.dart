import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'actors_api.g.dart';

@RestApi()
abstract class ActorsApi {
  factory ActorsApi(Dio dio, {String baseUrl}) = _ActorsApi;

  @GET('/actors')
  Future<dynamic> list(@Queries() Map<String, dynamic> q);

  @GET('/actors/options')
  Future<dynamic> options(@Queries() Map<String, dynamic> q);

  /// 获取外部数据源头像预览图片。
  /// body: { avatar_url, source? }，source=avdb 时按 AVDB 配置下载。
  @POST('/actors/avatar/preview')
  @DioResponseType(ResponseType.bytes)
  Future<HttpResponse<List<int>>> previewAvatar(
    @Body() Map<String, dynamic> body,
  );
}
