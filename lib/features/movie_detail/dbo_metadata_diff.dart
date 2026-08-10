import '../../core/models/actor.dart';
import '../../core/models/movie.dart';
import '../../core/models/resource.dart';

enum DboMetadataDiffSection { info, series, genres, actors }

enum DboMetadataDiffAction { add, remove, replace }

class DboMetadataDiffItem {
  DboMetadataDiffItem({
    required this.id,
    required this.section,
    required this.action,
    required this.label,
    required this.remoteText,
    this.field,
    this.currentText,
    this.value,
    this.localId,
    this.remoteName,
    this.gender,
  });

  final String id;
  final DboMetadataDiffSection section;
  final DboMetadataDiffAction action;
  final String? field;
  final String label;
  final String? currentText;
  final String remoteText;
  final dynamic value;
  final int? localId;
  final String? remoteName;
  final String? gender;
  bool selected = false;
}

class DboMetadataDiff {
  const DboMetadataDiff({
    required this.code,
    required this.title,
    required this.items,
  });

  final String code;
  final String title;
  final List<DboMetadataDiffItem> items;
}

DboMetadataDiff buildDboMetadataDiff(
  MovieDetail movie,
  Map<String, dynamic> metadata,
) {
  final items = <DboMetadataDiffItem>[];
  final score = _number(metadata['score'] ?? metadata['rating']);
  final duration = _number(metadata['duration'] ?? metadata['runtime']);
  final year = _parseYear(metadata['date'] ?? metadata['year']);
  final overview = _text(
    metadata['overview'] ?? metadata['plot'] ?? metadata['description'],
  );

  _appendTextDiff(
    items,
    field: 'title',
    label: '标题',
    current: movie.title,
    remote: metadata['title'],
  );
  _appendNumberDiff(
    items,
    field: 'rating',
    label: '评分',
    current: movie.rating,
    remote: score,
    decimals: 1,
  );
  _appendNumberDiff(
    items,
    field: 'year',
    label: '年份',
    current: movie.year,
    remote: year,
  );
  _appendNumberDiff(
    items,
    field: 'runtime',
    label: '时长',
    current: movie.runtime,
    remote: duration,
  );
  _appendTextDiff(
    items,
    field: 'plot',
    label: '剧情简介',
    current: movie.plot,
    remote: overview,
  );

  _appendSeriesDiff(items, movie.series, metadata['series']);
  _appendCollectionDiff(
    items,
    section: DboMetadataDiffSection.genres,
    prefix: 'genre',
    label: '分类',
    current: movie.genres,
    remote: metadata['categories'] ?? metadata['genres'],
  );
  _appendCollectionDiff(
    items,
    section: DboMetadataDiffSection.actors,
    prefix: 'actor',
    label: '演员',
    current: movie.actors,
    remote: metadata['actors'],
  );

  return DboMetadataDiff(
    code: _text(metadata['code']),
    title: _text(metadata['title']),
    items: items,
  );
}

void _appendTextDiff(
  List<DboMetadataDiffItem> items, {
  required String field,
  required String label,
  required String? current,
  required dynamic remote,
}) {
  final remoteText = _text(remote);
  if (remoteText.isEmpty) return;
  final currentText = _text(current);
  if (remoteText == currentText) return;

  items.add(DboMetadataDiffItem(
        id: 'info-$field',
        section: DboMetadataDiffSection.info,
        action: DboMetadataDiffAction.replace,
        field: field,
        label: label,
        currentText: currentText.isEmpty ? null : currentText,
        remoteText: remoteText,
        value: remoteText,
      ));
}

void _appendNumberDiff(
  List<DboMetadataDiffItem> items, {
  required String field,
  required String label,
  required num? current,
  required num? remote,
  int decimals = 0,
}) {
  if (remote == null || remote <= 0) return;
  final nextValue = decimals > 0
      ? double.parse(remote.toDouble().toStringAsFixed(decimals))
      : remote.toInt();
  final currentValue = current != null && current > 0
      ? (decimals > 0
          ? double.parse(current.toDouble().toStringAsFixed(decimals))
          : current.toInt())
      : null;
  if (currentValue != null && currentValue == nextValue) return;

  final format = decimals > 0
      ? (num value) => value.toStringAsFixed(decimals)
      : (num value) => value.toInt().toString();
  items.add(DboMetadataDiffItem(
        id: 'info-$field',
        section: DboMetadataDiffSection.info,
        action: DboMetadataDiffAction.replace,
        field: field,
        label: label,
        currentText: currentValue == null ? null : format(currentValue),
        remoteText: format(nextValue),
        value: nextValue,
      ));
}

void _appendSeriesDiff(
  List<DboMetadataDiffItem> items,
  ResourceItem? current,
  dynamic remote,
) {
  final remoteItem = _metadataItem(remote);
  final currentName = _text(current?.name);
  final remoteName = _text(remoteItem?['name']);
  if (currentName.isEmpty && remoteName.isNotEmpty) {
    items.add(DboMetadataDiffItem(
          id: 'series-add',
          section: DboMetadataDiffSection.series,
          action: DboMetadataDiffAction.add,
          label: '系列',
          remoteText: remoteName,
          remoteName: remoteName,
          gender: _text(remoteItem?['gender']),
        ));
  } else if (currentName.isNotEmpty && remoteName.isEmpty) {
    items.add(DboMetadataDiffItem(
          id: 'series-remove',
          section: DboMetadataDiffSection.series,
          action: DboMetadataDiffAction.remove,
          label: '系列',
          currentText: currentName,
          remoteText: '移除',
          localId: current?.id,
        ));
  } else if (currentName.isNotEmpty &&
      remoteName.isNotEmpty &&
      !_sameName(currentName, remoteName)) {
    items.add(DboMetadataDiffItem(
          id: 'series-replace',
          section: DboMetadataDiffSection.series,
          action: DboMetadataDiffAction.replace,
          label: '系列',
          currentText: currentName,
          remoteText: remoteName,
          localId: current?.id,
          remoteName: remoteName,
          gender: _text(remoteItem?['gender']),
        ));
  }
}

void _appendCollectionDiff(
  List<DboMetadataDiffItem> items, {
  required DboMetadataDiffSection section,
  required String prefix,
  required String label,
  required List<dynamic> current,
  required dynamic remote,
}) {
  final currentByName = <String, ({int id, String name})>{};
  for (final item in current) {
    final map = item is ResourceItem
        ? (id: item.id, name: item.name)
        : item is ActorItem
            ? (id: item.id, name: item.name)
            : null;
    if (map == null) continue;
    final name = _text(map.name);
    if (name.isNotEmpty) currentByName[_nameKey(name)] = map;
  }

  final remoteByName = <String, ({String name, String gender})>{};
  if (remote is List) {
    for (final raw in remote) {
      final item = _metadataItem(raw);
      final name = _text(item?['name'] ?? raw);
      if (name.isEmpty) continue;
      final key = _nameKey(name);
      remoteByName[key] = (
        name: name,
        gender: _text(item?['gender']),
      );
    }
  }

  for (final entry in remoteByName.entries) {
    if (currentByName.containsKey(entry.key)) continue;
    items.add(DboMetadataDiffItem(
          id: '$prefix-add-${entry.key}',
          section: section,
          action: DboMetadataDiffAction.add,
          label: label,
          remoteText: entry.value.name,
          remoteName: entry.value.name,
          gender: entry.value.gender,
        ));
  }
  for (final entry in currentByName.entries) {
    if (remoteByName.containsKey(entry.key)) continue;
    items.add(DboMetadataDiffItem(
          id: '$prefix-remove-${entry.value.id}',
          section: section,
          action: DboMetadataDiffAction.remove,
          label: label,
          currentText: entry.value.name,
          remoteText: '移除',
          localId: entry.value.id,
        ));
  }
}

Map<String, dynamic>? _metadataItem(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String _text(dynamic value) => value?.toString().trim() ?? '';

String _nameKey(String value) => _text(value).toLowerCase();

bool _sameName(String left, String right) => _nameKey(left) == _nameKey(right);

num? _number(dynamic value) {
  if (value is num) return value;
  return num.tryParse(_text(value));
}

int? _parseYear(dynamic value) {
  final text = _text(value);
  final match = RegExp(r'^(\d{4})').firstMatch(text);
  if (match != null) return int.tryParse(match.group(1)!);
  final number = _number(value)?.toInt();
  return number != null && number > 0 ? number : null;
}
