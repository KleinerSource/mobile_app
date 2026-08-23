import '../../core/api/api_exception.dart';
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

  Future<TranslationConfig> saveConfig(
    TranslationConfig cfg, {
    bool keepApiKey = false,
  }) async {
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
  Future<List<TranslationModel>> fetchModels(
    String apiUrl,
    String apiKey,
  ) async {
    final normalizedUrl = apiUrl.trim();
    final normalizedKey = apiKey.trim();
    final raw = await _api.fetchModels({
      'api_url': normalizedUrl,
      // 密钥输入框为空时使用服务器配置中的已保存密钥，避免把空值
      // 传给后端翻译服务。页面会在没有已保存密钥时提前提示用户输入。
      'api_key': normalizedKey.isEmpty ? '__saved__' : normalizedKey,
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
        return d['translated_text']?.toString() ??
            d['message']?.toString() ??
            '';
      }
      return d?.toString() ?? '';
    });
  }

  /// 翻译单个字段
  /// fieldName 例: movie_title / movie_country / movie_outline / movie_plot
  Future<String> translateText(String text, {required String fieldName}) async {
    final raw = await _api.translate({'text': text, 'field_name': fieldName});
    return unwrapStd<String>(raw, (d) {
      if (d is Map) {
        return d['translated_text']?.toString() ?? '';
      }
      return d?.toString() ?? '';
    });
  }

  /// 批量翻译 · 输入 { field_name: text }, 返回 { field_name: translated }
  /// 失败的字段不会出现在返回中
  Future<Map<String, String>> translateBatch(Map<String, String> fields) async {
    final raw = await _api.translateBatch({'fields': fields});
    if (raw is! Map || raw['success'] != true) {
      throw ApiException(
        (raw is Map ? raw['message'] as String? : null) ?? '批量翻译失败',
      );
    }
    final results = (raw['data'] as Map?)?['results'];
    if (results is! Map) return const {};
    final out = <String, String>{};
    results.forEach((k, v) {
      if (v is Map && v['success'] == true) {
        final t = v['translated_text']?.toString();
        if (t != null && t.isNotEmpty) out[k.toString()] = t;
      }
    });
    return out;
  }
}
