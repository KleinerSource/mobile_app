import '../../core/api/envelope.dart';
import '../../core/api/services/translation_api.dart';
import '../../core/models/translation_config.dart';

class TranslationRepository {
  TranslationRepository(this._api);
  final TranslationApi _api;

  Future<TranslationConfig> getConfig() async {
    final raw = await _api.getConfig();
    return unwrapStd<TranslationConfig>(raw, (d) {
      if (d is Map) {
        return TranslationConfig.fromJson(Map<String, dynamic>.from(d));
      }
      return const TranslationConfig();
    });
  }

  Future<TranslationConfig> saveConfig(TranslationConfig cfg,
      {bool keepApiKey = false}) async {
    final body = cfg.toJson();
    if (keepApiKey) {
      // 留空 api_key 让后端保留已存的
      body.remove('api_key');
    }
    final raw = await _api.saveConfig(body);
    return unwrapStd<TranslationConfig>(raw, (d) {
      if (d is Map) {
        return TranslationConfig.fromJson(Map<String, dynamic>.from(d));
      }
      return cfg;
    });
  }

  /// 拉可用模型 · 返回 [{id, name?}, ...]
  Future<List<TranslationModel>> fetchModels(String apiUrl, String apiKey) async {
    final raw = await _api.fetchModels({
      'api_url': apiUrl,
      'api_key': apiKey,
    });
    if (raw is! Map || raw['success'] != true) return const [];
    final data = raw['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => TranslationModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  /// 测试连通 · 返回后端返回的字符串结果
  Future<String> test() async {
    final raw = await _api.test({});
    return unwrapStd<String>(raw, (d) {
      if (d is Map) {
        return d['translated_text']?.toString() ?? d['message']?.toString() ?? '';
      }
      return d?.toString() ?? '';
    });
  }
}
