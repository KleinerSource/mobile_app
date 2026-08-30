import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
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
              duration: const Duration(milliseconds: 220),
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
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
  final ScrollController _scrollController = ScrollController();
  int _lastIndex = -1;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onPlaybackChanged);
    _scheduleScroll();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPlaybackChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onPlaybackChanged() {
    if (!mounted) return;
    final index = widget.lyrics.indexAt(widget.controller.value.position);
    if (index == _lastIndex) return;
    setState(() {});
    _scheduleScroll();
  }

  void _scheduleScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final index = widget.lyrics.indexAt(widget.controller.value.position);
      _lastIndex = index;
      if (index < 0 || !_scrollController.hasClients) return;
      final target = (index * 58.0 - 120).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.lyrics.indexAt(
      widget.controller.value.position,
    );
    final l10n = AppL10n.of(context);
    return SafeArea(
      child: SizedBox(
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
                itemCount: widget.lyrics.cues.length,
                itemBuilder: (context, index) {
                  final active = index == currentIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
