import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/api_exception.dart';
import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/api/envelope.dart';
import 'package:omm/core/config/server_config_provider.dart'
    show sharedPrefsProvider;
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/platform/app_haptics.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/sheet_controls.dart';
import 'package:omm/features/oh_my_media/audio/audio_providers.dart';
import 'package:omm/features/settings/settings_common.dart';

const _audioFormatOptions = <({String value, String label})>[
  (value: 'mp3', label: 'MP3'),
  (value: 'm4a', label: 'M4A / AAC'),
  (value: 'opus', label: 'Opus'),
];

const _audioBitrateOptions = <int>[64, 96, 128, 192, 256, 320];

const _formatPrefsKey = 'audioExtractFormat';
const _bitratePrefsKey = 'audioExtractBitrateKbps';

class AudioExtractionSheet extends ConsumerStatefulWidget {
  const AudioExtractionSheet({super.key, required this.movie});

  final MovieDetail movie;

  static Future<String?> show(
    BuildContext context, {
    required MovieDetail movie,
  }) {
    return showGlassSheet<String>(
      context: context,
      builder: (_) => AudioExtractionSheet(movie: movie),
    );
  }

  @override
  ConsumerState<AudioExtractionSheet> createState() =>
      _AudioExtractionSheetState();
}

class _AudioExtractionSheetState extends ConsumerState<AudioExtractionSheet> {
  String _format = 'mp3';
  int _bitrateKbps = 192;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreLastSelection();
  }

  /// 带回上次提取使用的格式与码率，避免每次重复选择。
  void _restoreLastSelection() {
    final prefs = ref.read(sharedPrefsProvider);
    final savedFormat = prefs.getString(_formatPrefsKey);
    if (savedFormat != null &&
        _audioFormatOptions.any((option) => option.value == savedFormat)) {
      _format = savedFormat;
    }
    final savedBitrate = prefs.getInt(_bitratePrefsKey);
    if (savedBitrate != null && _audioBitrateOptions.contains(savedBitrate)) {
      _bitrateKbps = savedBitrate;
    }
  }

  Future<void> _rememberSelection() {
    final prefs = ref.read(sharedPrefsProvider);
    return Future.wait([
      prefs.setString(_formatPrefsKey, _format),
      prefs.setInt(_bitratePrefsKey, _bitrateKbps),
    ]);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final raw = await ref
          .read(audioRepositoryProvider)
          .extractAudio(
            movieId: widget.movie.id,
            format: _format,
            bitrateKbps: _bitrateKbps,
          );
      if (!mounted) return;
      final data = unwrapStd<Map<String, dynamic>>(raw, (value) {
        if (value is Map) return Map<String, dynamic>.from(value);
        return <String, dynamic>{};
      });
      final taskId = data['task_id']?.toString().trim() ?? '';
      if (taskId.isEmpty) {
        throw ApiException(AppL10n.of(context).audioExtractFailed);
      }
      await _rememberSelection();
      if (mounted) Navigator.of(context).pop(taskId);
    } catch (error) {
      if (mounted) {
        setState(() => _error = toApiException(error).message);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetHeader(
              icon: Icons.audiotrack_outlined,
              title: l.audioExtractTitle,
              subtitle: widget.movie.title,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _format,
              isExpanded: true,
              decoration: settingsInputDecoration(
                context,
                labelText: l.audioExtractFormat,
                prefixIcon: const Icon(Icons.audio_file_outlined),
              ),
              items: [
                for (final option in _audioFormatOptions)
                  DropdownMenuItem(
                    value: option.value,
                    child: Text(option.label),
                  ),
              ],
              onChanged: _submitting
                  ? null
                  : (value) {
                      if (value == null) return;
                      AppHaptics.selection();
                      setState(() => _format = value);
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _bitrateKbps,
              isExpanded: true,
              decoration: settingsInputDecoration(
                context,
                labelText: l.audioExtractBitrate,
                prefixIcon: const Icon(Icons.speed_outlined),
              ),
              items: [
                for (final bitrate in _audioBitrateOptions)
                  DropdownMenuItem(
                    value: bitrate,
                    child: Text('$bitrate kbps'),
                  ),
              ],
              onChanged: _submitting
                  ? null
                  : (value) {
                      if (value == null) return;
                      AppHaptics.selection();
                      setState(() => _bitrateKbps = value);
                    },
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.danger.withValues(alpha: 0.10),
                  border: Border.all(color: c.danger.withValues(alpha: 0.28)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_error!, style: TextStyle(color: c.danger)),
              ),
            ],
            const SizedBox(height: 20),
            SheetActionBar(
              padding: EdgeInsets.zero,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.pop(context),
                      style: sheetSecondaryButtonStyle(context),
                      child: Text(l.cancel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      style: sheetPrimaryButtonStyle(context),
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.playlist_add, size: 18),
                      label: Text(
                        _submitting
                            ? l.audioExtractSubmitting
                            : l.audioExtractSubmit,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
