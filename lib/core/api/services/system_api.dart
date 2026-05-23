import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'system_api.g.dart';

@RestApi()
abstract class SystemApi {
  factory SystemApi(Dio dio, {String baseUrl}) = _SystemApi;

  @GET('/health')
  Future<dynamic> health();

  @GET('/version')
  Future<dynamic> version();

  @GET('/database/stats')
  Future<dynamic> stats();

  /// 已配置的下载器列表 · 返回 { downloaders: [{name, display_name, ...}] }
  @GET('/downloaders')
  Future<dynamic> getDownloaders();

  /// 推送 URL 到下载器 · body: {
  ///   urls, downloader, save_path, video_info, record_resources, movie_id
  /// }
  @POST('/download')
  Future<dynamic> pushDownload(@Body() Map<String, dynamic> body);
}
