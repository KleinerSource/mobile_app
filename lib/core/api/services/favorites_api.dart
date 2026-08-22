import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'favorites_api.g.dart';

@RestApi()
abstract class FavoritesApi {
  factory FavoritesApi(Dio dio, {String baseUrl}) = _FavoritesApi;

  /// 列出收藏的影片(支持与 /movies 相同的筛选 query)。
  @GET('/favorites')
  Future<dynamic> list(@Queries() Map<String, dynamic> q);

  /// 切换某个影片的收藏状态。返回 { is_favorited: bool }。
  @PUT('/favorites/{movieId}/toggle')
  Future<dynamic> toggle(@Path('movieId') int movieId);

  /// 查询单个影片的收藏状态。
  @GET('/favorites/{movieId}/status')
  Future<dynamic> status(@Path('movieId') int movieId);

  /// 批量添加收藏。
  @POST('/favorites')
  Future<dynamic> addBatch(@Body() Map<String, dynamic> body);

  /// 批量删除收藏。
  @POST('/favorites/delete')
  Future<dynamic> removeBatch(@Body() Map<String, dynamic> body);
}
