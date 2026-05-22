import '../../core/api/envelope.dart';
import '../../core/api/services/libraries_api.dart';
import '../../core/models/library.dart';

class LibrariesRepository {
  LibrariesRepository(this._api);
  final LibrariesApi _api;

  Future<List<LibraryItem>> list({bool enabledOnly = false, bool withCover = true}) async {
    final raw = await _api.list({
      'enabled_only': enabledOnly,
      'with_cover': withCover,
    });
    if (raw['success'] != true) {
      return const [];
    }
    final data = raw['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => LibraryItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (data is Map && data['items'] is List) {
      return (data['items'] as List)
          .whereType<Map>()
          .map((e) => LibraryItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }
}
