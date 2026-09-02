import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/playback.dart' as playback_models;
import '../../../l10n/generated/app_localizations.dart';
import '../common/player_gesture_layer.dart';
import '../common/player_overlay_indicators.dart';
import '../common/player_session_controller.dart';
import '../common/player_settings.dart';
import 'player_debug_overlay.dart';
import 'player_decode_status.dart';
import 'player_device_stats.dart';
import 'player_exit_button.dart';
import 'player_status_overlay.dart';
import 'subtitle_rendering.dart';
import 'subtitle_settings.dart';
import 'video_player_controls.dart';

/// 视频播放就绪后的纯展示组合：画面、字幕、手势、状态和控制层。
class VideoPlayerView extends ConsumerWidget {
  const VideoPlayerView({
    super.key,
    required this.controller,
    required this.title,
    required this.decision,
    required this.isDirectPlayback,
    required this.selectedSubtitle,
    required this.subtitleAdjustments,
    required this.onSubtitleOffsetBoundsChanged,
    required this.deviceStats,
    required this.indicator,
    required this.controlsVisible,
    required this.pictureInPictureUrl,
    required this.pictureInPictureHeaders,
    required this.quality,
    required this.decodeStatuses,
    required this.playbackRate,
    required this.isLandscape,
    required this.onToggleControls,
    required this.onDoubleTapCenter,
    required this.onDoubleTapSeek,
    required this.onRateBoost,
    required this.onRateBoostEnd,
    required this.onSeekPreview,
    required this.onSeekCommit,
    required this.onBrightnessDelta,
    required this.onVolumeDelta,
    required this.onHideIndicator,
    required this.onQualityChanged,
    required this.onSubtitleChanged,
    required this.onOpenSubtitleSettings,
    required this.onAudioChanged,
    required this.onPictureInPicture,
    required this.onPreviousMedia,
    required this.onNextMedia,
    required this.onOrientationToggle,
    required this.onTogglePlay,
    required this.onSeekBackward,
    required this.onSeekForward,
    required this.onRateChanged,
    required this.onInteraction,
    required this.onExit,
  });

  final PlayerSessionController controller;
  final String title;
  final playback_models.PlaybackDecision decision;
  final bool isDirectPlayback;
  final playback_models.SubtitleTrack? selectedSubtitle;
  final SubtitleAdjustments subtitleAdjustments;
  final ValueChanged<SubtitleVerticalOffsetBounds>
  onSubtitleOffsetBoundsChanged;
  final PlayerDeviceStats deviceStats;
  final PlayerIndicator? indicator;
  final bool controlsVisible;
  final String? pictureInPictureUrl;
  final Map<String, String>? pictureInPictureHeaders;
  final String quality;
  final List<PlayerDecodeStatus> decodeStatuses;
  final double playbackRate;
  final bool isLandscape;
  final VoidCallback onToggleControls;
  final VoidCallback onDoubleTapCenter;
  final ValueChanged<int> onDoubleTapSeek;
  final ValueChanged<double> onRateBoost;
  final VoidCallback onRateBoostEnd;
  final void Function(Duration target, int deltaMs) onSeekPreview;
  final ValueChanged<Duration> onSeekCommit;
  final ValueChanged<double> onBrightnessDelta;
  final ValueChanged<double> onVolumeDelta;
  final VoidCallback onHideIndicator;
  final ValueChanged<String> onQualityChanged;
  final ValueChanged<playback_models.SubtitleTrack?> onSubtitleChanged;
  final VoidCallback onOpenSubtitleSettings;
  final ValueChanged<playback_models.AudioTrack> onAudioChanged;
  final VoidCallback onPictureInPicture;
  final VoidCallback? onPreviousMedia;
  final VoidCallback? onNextMedia;
  final VoidCallback onOrientationToggle;
  final VoidCallback onTogglePlay;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;
  final ValueChanged<double> onRateChanged;
  final VoidCallback onInteraction;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(playerSettingsProvider);
    final subtitleSettings = ref.watch(subtitleSettingsProvider);
    final capabilities = controller.capabilities;
    return Stack(
      children: [
        Positioned.fill(child: controller.buildSurface()),
        if (capabilities.textSubtitles)
          Positioned.fill(
            child: PlayerSubtitleOverlay(
              controller: controller,
              selectedTrack: selectedSubtitle,
              settings: subtitleSettings,
              adjustments: subtitleAdjustments,
              onVerticalOffsetBoundsChanged: onSubtitleOffsetBoundsChanged,
            ),
          ),
        Positioned.fill(
          child: PlayerGestureLayer(
            positionGetter: () => controller.position,
            durationGetter: () => controller.duration,
            onTap: onToggleControls,
            doubleTapCenterEnabled: settings.doubleTapCenter,
            doubleTapEdgesEnabled: settings.doubleTapEdges,
            onDoubleTapCenter: onDoubleTapCenter,
            onDoubleTapSeek: onDoubleTapSeek,
            hapticLongPress: settings.hapticLongPress,
            hapticSeek: settings.hapticSeek,
            hapticRate: settings.hapticRate,
            rateControlEnabled: capabilities.playbackRate,
            onRateBoost: onRateBoost,
            onRateBoostEnd: onRateBoostEnd,
            onSeekPreview: onSeekPreview,
            onSeekCommit: onSeekCommit,
            onBrightnessDelta: onBrightnessDelta,
            onVolumeDelta: onVolumeDelta,
            onAxisDragEnd: onHideIndicator,
          ),
        ),
        Positioned.fill(child: PlayerOverlayIndicators(indicator: indicator)),
        Positioned(
          top: 8,
          left: 20,
          right: 20,
          child: PlayerStatusOverlay(
            title: title,
            stats: deviceStats,
            showSystemTime: settings.showSystemTime,
            showNetworkSpeed: settings.showNetworkSpeed,
            showCpuUsage: settings.showCpuUsage,
            showBattery: settings.showBattery,
          ),
        ),
        if (settings.debugMode)
          Positioned(
            top: 42,
            left: 20,
            right: 20,
            child: PlayerDebugOverlay(stateListenable: controller),
          ),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !controlsVisible,
            child: AnimatedOpacity(
              opacity: controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: VideoPlayerControls(
                controller: controller,
                previewSourceUri: pictureInPictureUrl,
                previewSourceHeaders: pictureInPictureHeaders,
                quality: quality,
                qualityOptions: decision.qualityOptions,
                showQualityButton: !isDirectPlayback,
                onQualityChanged: onQualityChanged,
                subtitleTracks: capabilities.textSubtitles
                    ? decision.subtitleTracks
                    : const [],
                selectedSubtitle: selectedSubtitle,
                onSubtitleChanged: onSubtitleChanged,
                onOpenSubtitleSettings: onOpenSubtitleSettings,
                audioTracks: capabilities.audioTracks
                    ? decision.audioTracks
                    : const [],
                onAudioChanged: onAudioChanged,
                decodeStatuses: decodeStatuses,
                hapticProgressBar: settings.hapticProgressBar,
                showPlayPauseButton: settings.showPlayPauseButton,
                showSeekButtons: settings.showSeekButtons,
                showSpeedButton:
                    settings.showSpeedButton && capabilities.playbackRate,
                showPipButton:
                    settings.showPipButton && capabilities.pictureInPicture,
                showOrientationButton: settings.showOrientationButton,
                showMediaSwitchButton: settings.showMediaSwitchButton,
                playbackRate: playbackRate,
                onPictureInPicture: onPictureInPicture,
                onPreviousMedia: onPreviousMedia,
                onNextMedia: onNextMedia,
                isLandscape: isLandscape,
                onOrientationToggle: onOrientationToggle,
                onTogglePlay: onTogglePlay,
                onSeekBackward: onSeekBackward,
                onSeekForward: onSeekForward,
                onRateChanged: onRateChanged,
                onSeek: controller.seek,
                onInteraction: onInteraction,
                onExit: onExit,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class VideoPlayerLoadingView extends StatelessWidget {
  const VideoPlayerLoadingView({super.key, required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 12),
              Text(
                AppL10n.of(context).playerLoadingVideo,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        PlayerExitButton(onExit: onExit),
      ],
    );
  }
}
