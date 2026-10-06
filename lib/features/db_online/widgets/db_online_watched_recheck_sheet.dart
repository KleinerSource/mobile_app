import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/providers.dart';
import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/core/sources/media/dbo/db_online_watched.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'package:omm/shared/sheet_controls.dart';

import 'db_online_download_requirements_fields.dart';

class DbOnlineWatchedRecheckSheet extends ConsumerStatefulWidget {
  const DbOnlineWatchedRecheckSheet({
    super.key,
    required this.serverId,
    required this.filter,
  });
  final String serverId;
  final DbOnlineWatchedFilter filter;

  @override
  ConsumerState<DbOnlineWatchedRecheckSheet> createState() =>
      _DbOnlineWatchedRecheckSheetState();
}

class _DbOnlineWatchedRecheckSheetState
    extends ConsumerState<DbOnlineWatchedRecheckSheet> {
  final _requirements = DbOnlineDownloadRequirementsController();
  bool _loading = true;
  bool _submitting = false;
  String? _presetError;

  bool get _current =>
      mounted &&
      ref.read(mediaRuntimeConfigProvider)?.activeServerId == widget.serverId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current) unawaited(_loadPreset());
    });
  }

  @override
  void dispose() {
    _requirements.dispose();
    super.dispose();
  }

  Future<void> _loadPreset() async {
    if (!_current) return;
    setState(() {
      _loading = true;
      _presetError = null;
    });
    final l = AppL10n.of(context);
    final api = ref.read(requiredApiClientProvider).dbOnline;
    try {
      final data = await api.subscriptions.getSubscriptionPreset();
      if (!_current) return;
      final preset = data is Map ? data['preset'] : null;
      _requirements.load(
        preset is Map && preset['enabled'] == true
            ? DbOnlineRecheckRequirements.fromJson(
                Map<String, dynamic>.from(preset),
              )
            : const DbOnlineRecheckRequirements(),
      );
    } catch (error) {
      if (_current) _presetError = localizedErrorMessage(l, error);
    } finally {
      if (_current) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_current || _loading || _submitting) return;
    final l = AppL10n.of(context);
    final error = _requirements.validationMessage(l);
    if (error != null) {
      _notify(error);
      return;
    }
    final api = ref.read(requiredApiClientProvider).dbOnline;
    final value = _requirements.value;
    setState(() => _submitting = true);
    try {
      final total = await api.recheckWatchedVideos(
        filter: widget.filter,
        requirements: value,
      );
      if (mounted && _current) Navigator.of(context).pop(total);
    } catch (error) {
      if (mounted && _current) {
        _notify(localizedErrorMessage(l, error));
      }
    } finally {
      if (_current) setState(() => _submitting = false);
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SheetHeader(
                    icon: Icons.manage_search_rounded,
                    title: l.dbOnlineWatchedRecheck,
                  ),
                  Text(l.dbOnlineWatchedRecheckHint),
                  const SizedBox(height: 12),
                  if (_loading) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(l.dbOnlineWatchedPresetLoading),
                  ],
                  if (_presetError != null) ...[
                    Text(_presetError!),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: _loadPreset,
                          child: Text(l.dbOnlineRetry),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _requirements.load(
                              const DbOnlineRecheckRequirements(),
                            );
                            _presetError = null;
                          }),
                          child: Text(l.dbOnlineWatchedUseDefaults),
                        ),
                      ],
                    ),
                  ],
                  DbOnlineDownloadRequirementsFields(
                    controller: _requirements,
                    enabled: !_loading && !_submitting,
                  ),
                ],
              ),
            ),
          ),
          SheetActionBar.buttons(
            buttons: [
              OutlinedButton(
                onPressed: _submitting
                    ? null
                    : () => Navigator.of(context).pop(),
                style: sheetSecondaryButtonStyle(context),
                child: Text(l.dbOnlineSubscriptionCancel),
              ),
              FilledButton(
                onPressed: _loading || _submitting || _presetError != null
                    ? null
                    : _submit,
                style: sheetPrimaryButtonStyle(context),
                child: _submitting
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : Text(l.dbOnlineWatchedStart),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
