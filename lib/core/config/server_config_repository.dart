import 'package:shared_preferences/shared_preferences.dart';

import 'server_config.dart';

class ServerConfigRepository {
  ServerConfigRepository(this._prefs);

  static const _kBaseUrl = 'server.base_url';

  final SharedPreferences _prefs;

  ServerConfig? load() {
    final url = _prefs.getString(_kBaseUrl);
    if (url == null || url.isEmpty) return null;
    return ServerConfig(baseUrl: url);
  }

  Future<void> save(ServerConfig config) async {
    await _prefs.setString(_kBaseUrl, ServerConfig.normalize(config.baseUrl));
  }

  Future<void> clear() async {
    await _prefs.remove(_kBaseUrl);
  }
}
