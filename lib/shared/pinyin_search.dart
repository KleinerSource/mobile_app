import 'package:lpinyin/lpinyin.dart';

typedef PinyinSearchTokens = ({
  String pinyin,
  List<int> pinyinOffsets,
  String firstLetters,
});

PinyinSearchTokens pinyinSearchTokens(String name) {
  final syllables =
      PinyinHelper.getPinyinE(name, separator: ' ', defPinyin: '?')
          .toLowerCase()
          .split(' ')
          .where((syllable) => syllable.isNotEmpty)
          .toList(growable: false);
  final offsets = <int>[];
  var offset = 0;
  for (final syllable in syllables) {
    offsets.add(offset);
    offset += syllable.length;
  }
  return (
    pinyin: syllables.join(),
    pinyinOffsets: List<int>.unmodifiable(offsets),
    firstLetters: PinyinHelper.getShortPinyin(name).toLowerCase(),
  );
}

bool _matchesFullPinyin(PinyinSearchTokens tokens, String query) {
  for (final offset in tokens.pinyinOffsets) {
    if (tokens.pinyin.startsWith(query, offset)) return true;
  }
  return false;
}

bool matchesPinyinSearch(
  String name,
  String query, {
  PinyinSearchTokens? tokens,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  if (name.toLowerCase().contains(q)) return true;

  final index = tokens ?? pinyinSearchTokens(name);
  return _matchesFullPinyin(index, q) || index.firstLetters.contains(q);
}
