import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'translation_api.g.dart';

@RestApi()
abstract class TranslationApi {
  factory TranslationApi(Dio dio, {String baseUrl}) = _TranslationApi;

  @GET('/translation/config')
  Future<dynamic> getConfig();

  @POST('/translation/config')
  Future<dynamic> saveConfig(@Body() Map<String, dynamic> body);

  /// 测试翻译 · 后端用 130s timeout
  @POST('/translation/test')
  Future<dynamic> test(@Body() Map<String, dynamic> body);

  @GET('/translation/status')
  Future<dynamic> status();

  /// 拉取可用模型 · body: { api_url, api_key }
  @POST('/translation/models')
  Future<dynamic> fetchModels(@Body() Map<String, dynamic> body);

  /// 直接调用翻译 (非主用,做样例 + 测试时备用)
  @POST('/translation/translate')
  Future<dynamic> translate(@Body() Map<String, dynamic> body);
}
