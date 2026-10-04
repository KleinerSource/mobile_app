import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

/// 搜索历史按服务器独立保存：同一服务器跨媒体项目共享一条历史，
/// 换服务器互不干扰。
class SearchHistoryStore {
  SearchHistoryStore(this._prefs);

  final SharedPreferences _prefs;

  static const _keyPrefix = 'search.history.v1.';
  static const maxEntries = 20;

  List<String> load(String serverId) {
    final raw = _prefs.getString('$_keyPrefix$serverId');
    if (raw == null || raw.isEmpty) return const <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <String>[];
      return decoded
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .take(maxEntries)
          .toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }

  /// 新记录置顶；重复关键词移动到最前；超出上限丢弃最旧的。
  Future<void> add(String serverId, String query) async {
    final value = query.trim();
    if (value.isEmpty) return;
    final entries = [
      value,
      ...load(serverId).where((item) => item != value),
    ].take(maxEntries).toList(growable: false);
    await _prefs.setString('$_keyPrefix$serverId', jsonEncode(entries));
  }

  Future<void> clear(String serverId) async {
    await _prefs.remove('$_keyPrefix$serverId');
  }
}

final searchHistoryStoreProvider = Provider<SearchHistoryStore>((ref) {
  return SearchHistoryStore(ref.watch(sharedPrefsProvider));
});

/// 搜索页空态下的历史记录区：横向换行 chips，点击直接搜索，
/// 右上提供清空按钮。为防误触需点两次：第一次进入确认态并高亮，
/// 再次点击才真正清空；确认态 3 秒后自动复位。
class SearchHistorySection extends StatefulWidget {
  const SearchHistorySection({
    super.key,
    required this.entries,
    required this.onSelected,
    required this.onClear,
  });

  final List<String> entries;
  final ValueChanged<String> onSelected;
  final VoidCallback onClear;

  @override
  State<SearchHistorySection> createState() => _SearchHistorySectionState();
}

class _SearchHistorySectionState extends State<SearchHistorySection> {
  static const _confirmResetDelay = Duration(seconds: 3);

  Timer? _confirmResetTimer;
  bool _confirming = false;

  @override
  void didUpdateWidget(SearchHistorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切换服务器会换一批历史记录，确认态不应延续到新列表。
    if (oldWidget.entries != widget.entries) _resetConfirm();
  }

  @override
  void dispose() {
    _confirmResetTimer?.cancel();
    super.dispose();
  }

  void _resetConfirm() {
    _confirmResetTimer?.cancel();
    _confirmResetTimer = null;
    if (_confirming) setState(() => _confirming = false);
  }

  void _handleClearTap() {
    if (!_confirming) {
      setState(() => _confirming = true);
      _confirmResetTimer?.cancel();
      _confirmResetTimer = Timer(_confirmResetDelay, _resetConfirm);
      return;
    }
    _resetConfirm();
    widget.onClear();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) return const SizedBox.shrink();
    final colors = appColors(context);
    final l = AppL10n.of(context);
    return ListView(
      // 接入所在搜索 Tab 的 PrimaryScrollController，状态栏点击可回顶。
      primary: true,
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 120),
      children: [
        Row(
          children: [
            Icon(Icons.history_rounded, size: 15, color: colors.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l.searchHistoryTitle,
                style: AppText.eyebrow(context),
              ),
            ),
            TextButton.icon(
              onPressed: _handleClearTap,
              icon: Icon(
                _confirming
                    ? Icons.delete_sweep_rounded
                    : Icons.delete_sweep_outlined,
                size: 15,
              ),
              label: Text(
                _confirming ? l.searchHistoryClearConfirm : l.searchHistoryClear,
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: _confirming ? colors.danger : colors.muted,
                textStyle: AppText.meta(context),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in widget.entries)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Material(
                  color: colors.chipBg,
                  borderRadius: BorderRadius.circular(100),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(100),
                    onTap: () {
                      _resetConfirm();
                      widget.onSelected(entry);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              entry,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.text2,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
