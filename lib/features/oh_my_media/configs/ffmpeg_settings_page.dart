import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/models/ffmpeg_config.dart';
import 'package:omm/core/platform/app_haptics.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'configs_providers.dart';

class FfmpegSettingsPage extends ConsumerStatefulWidget {
  const FfmpegSettingsPage({super.key});

  @override
  ConsumerState<FfmpegSettingsPage> createState() => _FfmpegSettingsPageState();
}

class _FfmpegSettingsPageState extends ConsumerState<FfmpegSettingsPage> {
  final _ffmpegPath = TextEditingController();
  final _ffprobePath = TextEditingController();
  bool _enabled = true;
  bool _fallback = true;
  String _hwAccel = 'amf';
  int _audioExtractWorkers = FfmpegConfig.defaultAudioExtractWorkers;
  int _audioExtractThreads = FfmpegConfig.defaultAudioExtractThreads;
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _ffmpegPath.dispose();
    _ffprobePath.dispose();
    super.dispose();
  }

  void _hydrate(FfmpegConfig cfg) {
    if (_loaded) return;
    _loaded = true;
    _ffmpegPath.text = cfg.ffmpegPath;
    _ffprobePath.text = cfg.ffprobePath;
    _hwAccel = cfg.hwAccel;
    _enabled = cfg.enabled;
    _fallback = cfg.hwFallback;
    _audioExtractWorkers = cfg.audioExtractWorkers;
    _audioExtractThreads = cfg.audioExtractThreads;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(configsRepositoryProvider)
          .saveFfmpeg(
            FfmpegConfig(
              ffmpegPath: _ffmpegPath.text.trim(),
              ffprobePath: _ffprobePath.text.trim(),
              hwAccel: _hwAccel,
              enabled: _enabled,
              hwFallback: _fallback,
              audioExtractWorkers: _audioExtractWorkers,
              audioExtractThreads: _audioExtractThreads,
            ),
          );
      if (!mounted) return;
      ref.invalidate(ffmpegConfigProvider);
      AppHaptics.medium();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.of(context).ffmpegSavedToast)),
      );
    } catch (e) {
      if (mounted) setState(() => _error = toApiException(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final async = ref.watch(ffmpegConfigProvider);
    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(
                '${AppL10n.of(context).loadFailed}: ${toApiException(error).message}',
              ),
            ),
            data: (cfg) {
              _hydrate(cfg);
              return _buildForm(c);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildForm(AppColors c) {
    final l = AppL10n.of(context);
    return SettingsFixedHeaderLayout(
      header: SettingsSubPageHeader(
        eyebrow: l.settingsGroupTools,
        title: l.ffmpegTitle,
        subtitle: l.ffmpegSubtitle,
      ),
      body: ListView(
        primary: true,
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
        children: [
          _sectionLabel(l.ffmpegHwSection),
          _switchCard(
            c,
            title: l.ffmpegHwEnableTitle,
            subtitle: _enabled ? l.ffmpegHwOn : l.ffmpegHwOff,
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: settingsInputDecoration(
              context,
              labelText: l.ffmpegHwBackendLabel,
              prefixIcon: const Icon(Icons.memory_outlined),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _hwAccel,
                isExpanded: true,
                isDense: true,
                style: TextStyle(
                  color: c.text,
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                items: [
                  for (final value in FfmpegConfig.supportedHardwareAccels)
                    DropdownMenuItem(
                      value: value,
                      child: Text(_hardwareLabel(l, value)),
                    ),
                ],
                onChanged: _enabled
                    ? (value) {
                        if (value != null && value != _hwAccel) {
                          AppHaptics.selection();
                          setState(() => _hwAccel = value);
                        }
                      }
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _switchCard(
            c,
            title: l.ffmpegFallbackTitle,
            subtitle: _fallback ? l.ffmpegFallbackOn : l.ffmpegFallbackOff,
            value: _fallback,
            onChanged: _enabled
                ? (value) => setState(() => _fallback = value)
                : null,
          ),
          const SizedBox(height: 22),
          _sectionLabel(l.ffmpegPathsSection),
          _pathField(_ffmpegPath, l.ffmpegPathHint('ffmpeg')),
          const SizedBox(height: 12),
          _pathField(_ffprobePath, l.ffmpegPathHint('ffprobe')),
          const SizedBox(height: 22),
          _sectionLabel(l.ffmpegAudioSection),
          _audioSettingCard(
            c,
            title: l.ffmpegAudioWorkersTitle,
            subtitle: l.ffmpegAudioWorkersSubtitle,
            value: _audioExtractWorkers,
            icon: Icons.queue_music_outlined,
            onChanged: (value) =>
                setState(() => _audioExtractWorkers = value.round()),
          ),
          const SizedBox(height: 12),
          _audioSettingCard(
            c,
            title: l.ffmpegAudioThreadsTitle,
            subtitle: l.ffmpegAudioThreadsSubtitle,
            value: _audioExtractThreads,
            icon: Icons.memory_outlined,
            onChanged: (value) =>
                setState(() => _audioExtractThreads = value.round()),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _errorBox(c, _error!),
          ],
          const SizedBox(height: 28),
          SettingsSaveButton(onPressed: _save, saving: _saving),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text.toUpperCase(), style: AppText.eyebrow(context)),
  );

  Widget _pathField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      textAlignVertical: TextAlignVertical.center,
      decoration: settingsInputDecoration(
        context,
        hintText: hint,
        prefixIcon: const Icon(Icons.folder_open_outlined),
      ),
    );
  }

  Widget _switchCard(
    AppColors c, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: settingsCardDecoration(context),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: c.text, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: AppText.meta(context)),
              ],
            ),
          ),
          SettingsSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _audioSettingCard(
    AppColors c, {
    required String title,
    required String subtitle,
    required int value,
    required IconData icon,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: settingsCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: c.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: c.text, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '$value',
                style: AppText.mono(context, size: 16, color: c.text),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: AppText.meta(context)),
          HapticSlider(
            value: value.toDouble(),
            min: FfmpegConfig.minAudioSetting.toDouble(),
            max: FfmpegConfig.maxAudioSetting.toDouble(),
            divisions:
                FfmpegConfig.maxAudioSetting - FfmpegConfig.minAudioSetting,
            label: '$value',
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _errorBox(AppColors c, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.danger.withValues(alpha: 0.10),
        border: Border.all(color: c.danger.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: TextStyle(color: c.danger)),
    );
  }

  String _hardwareLabel(AppL10n l, String value) => switch (value) {
    'none' => l.ffmpegHwNone,
    'amf' => 'AMD AMF',
    'nvenc' => 'NVIDIA NVENC',
    'qsv' => 'Intel Quick Sync',
    _ => value,
  };
}
