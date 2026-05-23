import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'configs_api.g.dart';

/// 系统配置类 endpoint · DBO / 视频扩展名 / FFmpeg 等
@RestApi()
abstract class ConfigsApi {
  factory ConfigsApi(Dio dio, {String baseUrl}) = _ConfigsApi;

  // ===== DBOnline =====

  @GET('/configs/dbonline')
  Future<dynamic> getDbo();

  @POST('/configs/dbonline')
  Future<dynamic> saveDbo(@Body() Map<String, dynamic> body);

  // ===== 视频扩展名 =====

  @GET('/configs/video-extensions/current')
  Future<dynamic> getVideoExtensions();

  /// body: { extensions: [".mp4", ...] }
  @POST('/configs/video-extensions/update')
  Future<dynamic> updateVideoExtensions(@Body() Map<String, dynamic> body);
}
