import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/models/preview_config.dart';
import 'package:omm/core/platform/app_haptics.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/glow_background.dart';
import 'configs_providers.dart';

class PreviewSettingsPage extends ConsumerStatefulWidget {
  const PreviewSettingsPage({super.key});

  @override
  ConsumerState<PreviewSettingsPage> createState() =>
      _PreviewSettingsPageState();
}

class _PreviewSettingsPageState extends ConsumerState<PreviewSettingsPage> {
  final _segments = TextEditingController();
  final _duration = TextEditingController();
  final _excludeStart = TextEditingController();
  final _excludeEnd = TextEditingController();
  final _spriteInterval = TextEditingController();
  final _spriteMinimum = TextEditingController();
  final _spriteMaximum = TextEditingController();
  final _spriteSize = TextEditingController();
  bool _autoGenerate = false;
  bool _audio = true;
  String _preset = 'slow';
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _segments,
      _duration,
      _excludeStart,
      _excludeEnd,
      _spriteInterval,
      _spriteMinimum,
      _spriteMaximum,
      _spriteSize,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _hydrate(PreviewConfig config) {
    if (_loaded) return;
    _loaded = true;
    _autoGenerate = config.autoGenerateOnScan;
    _audio = config.audio;
    _preset = config.preset;
    _segments.text = '${config.segments}';
    _duration.text = '${config.segmentDuration}';
    _excludeStart.text = '${config.excludeStart}';
    _excludeEnd.text = '${config.excludeEnd}';
    _spriteInterval.text = '${config.spriteInterval}';
    _spriteMinimum.text = '${config.spriteMinimum}';
    _spriteMaximum.text = '${config.spriteMaximum}';
    _spriteSize.text = '${config.spriteSize}';
  }

  Future<void> _save() async {
    final config = _readConfig();
    if (config == null) return;
    final error = config.validationError;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(configsRepositoryProvider).savePreview(config);
      if (!mounted) return;
      ref.invalidate(previewConfigProvider);
      AppHaptics.medium();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.of(context).previewSavedToast)),
      );
    } catch (error) {
      if (mounted) setState(() => _error = toApiException(error).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  PreviewConfig? _readConfig() {
    final segments = int.tryParse(_segments.text.trim());
    final duration = double.tryParse(_duration.text.trim());
    final excludeStart = double.tryParse(_excludeStart.text.trim());
    final excludeEnd = double.tryParse(_excludeEnd.text.trim());
    final spriteInterval = int.tryParse(_spriteInterval.text.trim());
    final spriteMinimum = int.tryParse(_spriteMinimum.text.trim());
    final spriteMaximum = int.tryParse(_spriteMaximum.text.trim());
    final spriteSize = int.tryParse(_spriteSize.text.trim());
    if ([
      segments,
      duration,
      excludeStart,
      excludeEnd,
      spriteInterval,
      spriteMinimum,
      spriteMaximum,
      spriteSize,
    ].any((value) => value == null)) {
      setState(() => _error = AppL10n.of(context).previewInvalidValue);
      return null;
    }
    return PreviewConfig(
      autoGenerateOnScan: _autoGenerate,
      audio: _audio,
      segments: segments!,
      segmentDuration: duration!,
      excludeStart: excludeStart!,
      excludeEnd: excludeEnd!,
      preset: _preset,
      spriteInterval: spriteInterval!,
      spriteMinimum: spriteMinimum!,
      spriteMaximum: spriteMaximum!,
      spriteSize: spriteSize!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final async = ref.watch(previewConfigProvider);
    return Scaffold(
      backgroundColor: colors.bg,
      body: GlowBackground(
        child: SafeArea(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(
                '${AppL10n.of(context).loadFailed}: ${toApiException(error).message}',
              ),
            ),
            data: (config) {
              _hydrate(config);
              return _buildForm(colors);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildForm(AppColors colors) {
    final l = AppL10n.of(context);
    return SettingsFixedHeaderLayout(
      header: SettingsSubPageHeader(
        eyebrow: l.settingsGroupTools,
        title: l.previewSettingsTitle,
        subtitle: l.previewSettingsSubtitle,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
        children: [
          _switchCard(
            colors,
            title: l.previewAutoGenerate,
            subtitle: l.previewAutoGenerateSub,
            value: _autoGenerate,
            onChanged: (value) => setState(() => _autoGenerate = value),
          ),
          const SizedBox(height: 12),
          _switchCard(
            colors,
            title: l.previewAudio,
            subtitle: l.previewAudioSub,
            value: _audio,
            onChanged: (value) => setState(() => _audio = value),
          ),
          const SizedBox(height: 22),
          _sectionLabel(l.previewVideoSection),
          _numberField(_segments, l.previewSegments, l.previewSegmentsSub),
          _numberField(
            _duration,
            l.previewSegmentDuration,
            l.previewSegmentDurationSub,
            decimal: true,
          ),
          _numberField(
            _excludeStart,
            l.previewExcludeStart,
            l.previewExcludeSub,
            decimal: true,
          ),
          _numberField(
            _excludeEnd,
            l.previewExcludeEnd,
            l.previewExcludeSub,
            decimal: true,
          ),
          const SizedBox(height: 22),
          _sectionLabel(l.previewEncodingSection),
          _presetField(colors, l.previewPreset),
          const SizedBox(height: 22),
          _sectionLabel(l.previewSpriteSection),
          _numberField(_spriteInterval, l.previewSpriteInterval, ''),
          _numberField(_spriteMinimum, l.previewSpriteMinimum, ''),
          _numberField(_spriteMaximum, l.previewSpriteMaximum, ''),
          _numberField(_spriteSize, l.previewSpriteSize, ''),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _errorBox(colors, _error!),
          ],
          const SizedBox(height: 24),
          SettingsSaveButton(onPressed: _save, saving: _saving),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text.toUpperCase(), style: AppText.eyebrow(context)),
  );

  Widget _numberField(
    TextEditingController controller,
    String label,
    String subtitle, {
    bool decimal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [
          if (decimal)
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
          else
            FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: settingsInputDecoration(
          context,
          labelText: label,
          hintText: subtitle.isEmpty ? null : subtitle,
          prefixIcon: const Icon(Icons.tune_outlined),
        ),
      ),
    );
  }

  Widget _presetField(AppColors colors, String label) {
    return InputDecorator(
      decoration: settingsInputDecoration(
        context,
        labelText: label,
        prefixIcon: const Icon(Icons.speed_outlined),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: PreviewConfig.supportedPresets.contains(_preset)
              ? _preset
              : 'slow',
          isExpanded: true,
          isDense: true,
          style: TextStyle(
            color: colors.text,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          items: [
            for (final preset in PreviewConfig.supportedPresets)
              DropdownMenuItem(value: preset, child: Text(preset)),
          ],
          onChanged: (value) {
            if (value == null) return;
            AppHaptics.selection();
            setState(() => _preset = value);
          },
        ),
      ),
    );
  }

  Widget _switchCard(
    AppColors colors, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
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
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
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

  Widget _errorBox(AppColors colors, String message) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: colors.danger.withValues(alpha: 0.10),
      border: Border.all(color: colors.danger.withValues(alpha: 0.28)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(message, style: TextStyle(color: colors.danger)),
  );
}
