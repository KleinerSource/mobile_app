import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/sheet_controls.dart';
import 'movies_providers.dart';

const _kDownloadPrefsKey = 'batchDownloadParams';

/// 批量下载 sheet · 对齐 frontend_new BatchDownloadModal
class BatchDownloadSheet extends ConsumerStatefulWidget {
  const BatchDownloadSheet({super.key, required this.movieIds});
  final List<int> movieIds;

  static Future<bool?> show(BuildContext context, List<int> ids) {
    return showGlassSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BatchDownloadSheet(movieIds: ids),
    );
  }

  @override
  ConsumerState<BatchDownloadSheet> createState() => _BatchDownloadSheetState();
}

class _BatchDownloadSheetState extends ConsumerState<BatchDownloadSheet> {
  final _qualityCtl = TextEditingController();
  final _minSizeCtl = TextEditingController(text: '1500');
  final _maxSizeCtl = TextEditingController(text: '0');
  final _maxFilesCtl = TextEditingController(text: '0');
  final _afterDateCtl = TextEditingController(text: '2024-01-01');
  bool _requireSub = true;
  bool _requireUncensored = false;
  bool _washMode = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kDownloadPrefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (!mounted) return;
      setState(() {
        _qualityCtl.text = (m['quality'] ?? '').toString();
        _requireSub = m['require_sub'] != false;
        _requireUncensored = m['require_uncensored'] == true;
        _minSizeCtl.text = (m['min_size_mb'] ?? 1500).toString();
        _maxSizeCtl.text = (m['max_size_mb'] ?? 0).toString();
        _maxFilesCtl.text = (m['max_file_count'] ?? 0).toString();
        _afterDateCtl.text = (m['after_date'] ?? '2024-01-01').toString();
        _washMode = m['wash_mode'] == true;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _qualityCtl.dispose();
    _minSizeCtl.dispose();
    _maxSizeCtl.dispose();
    _maxFilesCtl.dispose();
    _afterDateCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final requirements = <String, dynamic>{
        'quality': _qualityCtl.text.trim(),
        'require_sub': _requireSub,
        'require_uncensored': _requireUncensored,
        'min_size_mb': int.tryParse(_minSizeCtl.text.trim()) ?? 0,
        'max_size_mb': int.tryParse(_maxSizeCtl.text.trim()) ?? 0,
        'max_file_count': int.tryParse(_maxFilesCtl.text.trim()) ?? 0,
        'after_date': _afterDateCtl.text.trim(),
        'wash_mode': _washMode,
      };
      final msg = await ref
          .read(mediaRepositoryProvider)
          .requestDownload(
            movieIds: widget.movieIds,
            requirements: requirements,
          );
      // 保存到 prefs
      final p = await SharedPreferences.getInstance();
      await p.setString(_kDownloadPrefsKey, jsonEncode(requirements));
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(msg)));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppL10n.of(context).moviesDownloadFailed(toApiException(e).message),
          ),
        ),
      );
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeader(
          icon: Icons.cloud_download_outlined,
          title: l.moviesBatchDownloadTitle(widget.movieIds.length),
          subtitle: l.moviesBatchDownloadSubtitle,
        ),
        Flexible(
          fit: FlexFit.loose,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
            children: [
              _Field(
                label: l.moviesDownloadQuality,
                hint: l.moviesDownloadQualityHint,
                controller: _qualityCtl,
                icon: Icons.high_quality_outlined,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _NumField(
                      label: l.moviesDownloadMinSize,
                      controller: _minSizeCtl,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _NumField(
                      label: l.moviesDownloadMaxSize,
                      controller: _maxSizeCtl,
                      hint: l.moviesDownloadNoLimit,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _NumField(
                label: l.moviesDownloadMaxFiles,
                controller: _maxFilesCtl,
                hint: l.moviesDownloadNoLimit,
              ),
              const SizedBox(height: 12),
              _Field(
                label: l.moviesDownloadDate,
                hint: 'YYYY-MM-DD',
                controller: _afterDateCtl,
                icon: Icons.calendar_today_outlined,
              ),
              const SizedBox(height: 12),
              SheetSwitchTile(
                title: l.moviesDownloadRequireSubtitle,
                value: _requireSub,
                onChanged: (v) => setState(() => _requireSub = v),
              ),
              SheetSwitchTile(
                title: l.moviesDownloadRequireUncensored,
                value: _requireUncensored,
                onChanged: (v) => setState(() => _requireUncensored = v),
              ),
              SheetSwitchTile(
                title: l.moviesDownloadWashMode,
                subtitle: l.moviesDownloadWashModeHint,
                value: _washMode,
                onChanged: (v) => setState(() => _washMode = v),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        SheetActionBar(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  style: sheetSecondaryButtonStyle(context),
                  child: Text(l.cancel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_download_outlined, size: 18),
                  style: sheetPrimaryButtonStyle(context),
                  label: Text(
                    _submitting ? l.moviesSubmitting : l.moviesConfirmSubmit,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    this.hint,
    required this.controller,
    this.icon,
  });
  final String label;
  final String? hint;
  final TextEditingController controller;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.meta(context)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          textAlignVertical: TextAlignVertical.center,
          decoration: sheetInputDecoration(
            context,
            hintText: hint,
            prefixIcon: icon == null ? null : Icon(icon),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField({required this.label, this.hint, required this.controller});
  final String label;
  final String? hint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.meta(context)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlignVertical: TextAlignVertical.center,
          decoration: sheetInputDecoration(
            context,
            hintText: hint,
            prefixIcon: const Icon(Icons.pin_outlined),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}
