import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/glass.dart';
import 'lrc_parser.dart';
import '../common/playback_engine.dart';
import '../common/player_session_controller.dart';

class AudioLyricsView extends StatelessWidget {
  const AudioLyricsView({
    super.key,
    required this.controller,
    required this.lyrics,
  });

  final PlayerSessionController controller;
  final LrcDocument? lyrics;

  @override
  Widget build(BuildContext context) {
    final document = lyrics;
    if (document == null || document.isEmpty) return const SizedBox.shrink();

    return ValueListenableBuilder<PlaybackViewState>(
      valueListenable: controller,
      builder: (context, state, _) {
        final index = document.indexAt(state.position);
        final cue = index >= 0 ? document.cues[index] : null;
        final l10n = AppL10n.of(context);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showLyricsSheet(context, document),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40, maxHeight: 72),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Text(
                cue?.text ?? l10n.playerLyricsUnavailable,
                key: ValueKey<String>(cue?.text ?? 'empty'),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showLyricsSheet(
    BuildContext context,
    LrcDocument document,
  ) async {
    await showGlassSheet<void>(
      context: context,
      builder: (_) =>
          _AudioLyricsSheet(controller: controller, lyrics: document),
    );
  }
}

class _AudioLyricsSheet extends StatefulWidget {
  const _AudioLyricsSheet({required this.controller, required this.lyrics});

  final PlayerSessionController controller;
  final LrcDocument lyrics;

  @override
  State<_AudioLyricsSheet> createState() => _AudioLyricsSheetState();
}

class _AudioLyricsSheetState extends State<_AudioLyricsSheet> {
  static const double _rowExtent = 58.0;
  static const double _listTopPadding = 24.0;

  final ScrollController _scrollController = ScrollController();
  StreamSubscription<Duration>? _positionSubscription;
  int _lastIndex = -1;
  int? _pendingIndex;
  bool _scrollScheduled = false;
  bool _initialPositioned = false;

  @override
  void initState() {
    super.initState();
    _positionSubscription = widget.controller.positionStream.listen(
      _onPlaybackChanged,
    );
    _scheduleScroll(widget.controller.position);
  }

  @override
  void dispose() {
    final subscription = _positionSubscription;
    _positionSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    _scrollController.dispose();
    super.dispose();
  }

  void _onPlaybackChanged(Duration position) {
    if (!mounted) return;
    final index = widget.lyrics.indexAt(position);
    if (index == _lastIndex || index == _pendingIndex) return;
    _pendingIndex = index;
    setState(() {});
    _scheduleScroll(position);
  }

  void _scheduleScroll(Duration position) {
    _pendingIndex = widget.lyrics.indexAt(position);
    if (_scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!mounted) return;
      final index =
          _pendingIndex ?? widget.lyrics.indexAt(widget.controller.position);
      _pendingIndex = null;
      if (!_scrollController.hasClients ||
          !_scrollController.position.hasContentDimensions) {
        _scheduleScroll(widget.controller.position);
        return;
      }
      if (index < 0) {
        _lastIndex = index;
        return;
      }
      _lastIndex = index;
      final position = _scrollController.position;
      // 行高固定为 _rowExtent，可直接推导当前行中心，把该中心滚到视口中央。
      final target =
          _listTopPadding +
          index * _rowExtent +
          _rowExtent / 2 -
          position.viewportDimension / 2;
      final clamped = target.clamp(0.0, position.maxScrollExtent).toDouble();
      if (!_initialPositioned) {
        // 首次打开直接落位，之后的行切换才做连续滚动。
        _initialPositioned = true;
        _scrollController.jumpTo(clamped);
        return;
      }
      _scrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.lyrics.indexAt(
      widget.controller.value.position,
    );
    final l10n = AppL10n.of(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.78,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text(
                  l10n.playerLyricsTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: l10n.playerClose,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 72),
              itemExtent: _rowExtent,
              itemCount: widget.lyrics.cues.length,
              itemBuilder: (context, index) {
                final active = index == currentIndex;
                // 固定行高保证滚动定位精确，且高亮字号变化不再抖动布局。
                return Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    style: TextStyle(
                      color: active
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: active ? 21 : 17,
                      height: 1.35,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                    child: Text(
                      widget.lyrics.cues[index].text,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
