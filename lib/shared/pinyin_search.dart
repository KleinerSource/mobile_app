import 'package:lpinyin/lpinyin.dart';

typedef PinyinSearchTokens = ({String pinyin, String firstLetters});

PinyinSearchTokens pinyinSearchTokens(String name) {
  return (
    pinyin: PinyinHelper.getPinyinE(name, separator: '', defPinyin: '?')
        .toLowerCase(),
    firstLetters: PinyinHelper.getShortPinyin(name).toLowerCase(),
  );
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
  return index.pinyin.contains(q) || index.firstLetters.contains(q);
}
