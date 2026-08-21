import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/dio_factory.dart';
import '../../core/api/envelope.dart';
import '../../core/api/providers.dart';
import '../../core/models/movie.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glass.dart';
import '../settings/settings_common.dart';

const _audioFormatOptions = <({String value, String label})>[
  (value: 'mp3', label: 'MP3'),
  (value: 'm4a', label: 'M4A / AAC'),
  (value: 'opus', label: 'Opus'),
];

const _audioBitrateOptions = <int>[64, 96, 128, 192, 256, 320];

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

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final raw = await ref
          .read(requiredApiClientProvider)
          .audio
          .extractAudio(
            movieId: widget.movie.id,
            format: _format,
            bitrateKbps: _bitrateKbps,
          );
      final data = unwrapStd<Map<String, dynamic>>(raw, (value) {
        if (value is Map) return Map<String, dynamic>.from(value);
        return <String, dynamic>{};
      });
      final taskId = data['task_id']?.toString().trim() ?? '';
      if (taskId.isEmpty) {
        throw ApiException('音频提取任务创建失败');
      }
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
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.audiotrack_outlined, color: c.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('提取音频', style: AppText.sectionTitle(context)),
                      const SizedBox(height: 2),
                      Text(
                        widget.movie.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.meta(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _format,
              isExpanded: true,
              decoration: settingsInputDecoration(
                context,
                labelText: '输出格式',
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
                labelText: '目标码率',
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: c.text,
                      side: BorderSide(color: c.cardBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: c.text,
                      foregroundColor: c.bg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _submitting
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.bg,
                            ),
                          )
                        : const Icon(Icons.playlist_add, size: 18),
                    label: Text(_submitting ? '提交中...' : '提交任务'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
