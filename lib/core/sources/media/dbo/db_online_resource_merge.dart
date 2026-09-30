import 'db_online_movie.dart';

const _resourceSourceOrder = ['javdb', 'custom', 'nyaa'];

List<DbOnlineMagnet> mergeDbOnlineMagnets(
  Map<String, List<DbOnlineMagnet>> bySource,
) => _mergeResources(
  bySource,
  urlOf: (item) => item.magnet,
  hashOf: dbOnlineMagnetHash,
  dateOf: (item) => item.date,
);

List<DbOnlineEd2k> mergeDbOnlineEd2ks(
  Map<String, List<DbOnlineEd2k>> bySource,
) => _mergeResources(
  bySource,
  urlOf: (item) => item.ed2k,
  hashOf: dbOnlineEd2kHash,
  dateOf: (item) => item.date,
);

List<T> _mergeResources<T>(
  Map<String, List<T>> bySource, {
  required String Function(T item) urlOf,
  required String Function(String url) hashOf,
  required Object? Function(T item) dateOf,
}) {
  final merged = <T>[];
  final indexByHash = <String, int>{};
  for (final source in _resourceSourceOrder) {
    for (final item in bySource[source] ?? <T>[]) {
      final hash = hashOf(urlOf(item));
      if (hash.isEmpty) {
        merged.add(item);
        continue;
      }
      final existingIndex = indexByHash[hash];
      if (existingIndex == null) {
        indexByHash[hash] = merged.length;
        merged.add(item);
      } else if (_isOlder(dateOf(item), dateOf(merged[existingIndex]))) {
        merged[existingIndex] = item;
      }
    }
  }

  final dated = [
    for (var index = 0; index < merged.length; index++)
      (
        index: index,
        item: merged[index],
        date: _parseResourceDate(dateOf(merged[index])),
      ),
  ];
  dated.sort((a, b) {
    if (a.date == null && b.date == null) return a.index.compareTo(b.index);
    if (a.date == null) return 1;
    if (b.date == null) return -1;
    final result = b.date!.compareTo(a.date!);
    return result != 0 ? result : a.index.compareTo(b.index);
  });
  return [for (final entry in dated) entry.item];
}

bool _isOlder(Object? candidate, Object? current) {
  final candidateDate = _parseResourceDate(candidate);
  final currentDate = _parseResourceDate(current);
  if (candidateDate == null) return false;
  if (currentDate == null) return true;
  return candidateDate.isBefore(currentDate);
}

DateTime? _parseResourceDate(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is num) return _epochToDate(raw.toDouble());
  final text = raw.toString().trim();
  if (text.isEmpty) return null;
  final parsed = DateTime.tryParse(text.replaceAll('/', '-'));
  if (parsed != null) return parsed;
  final epoch = double.tryParse(text);
  return epoch == null ? null : _epochToDate(epoch);
}

DateTime _epochToDate(double value) {
  final millis = value >= 1e11 ? value : value * 1000;
  return DateTime.fromMillisecondsSinceEpoch(millis.round());
}

String dbOnlineMagnetHash(String value) {
  final match = RegExp(
    r'(?:^|[?&])xt=urn:btih:([A-Za-z0-9]+)',
    caseSensitive: false,
  ).firstMatch(value.trim());
  return match?.group(1)?.toUpperCase() ?? '';
}

String dbOnlineEd2kHash(String value) {
  final parts = value.split('|');
  if (parts.length < 5) return '';
  return parts[4].trim().toUpperCase();
}
