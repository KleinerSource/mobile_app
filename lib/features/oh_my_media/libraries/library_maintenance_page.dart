import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/localized_error_message.dart';
import '../configs/omm_admin_repository.dart';
import '../configs/omm_admin_widgets.dart';
import 'libraries_providers.dart';

class LibraryMaintenancePage extends StatelessWidget {
  const LibraryMaintenancePage({super.key});
  @override
  Widget build(BuildContext context) => OmmAdminScope(
    builder: (repository) => _LibraryMaintenanceView(repository),
  );
}

class _LibraryMaintenanceView extends ConsumerStatefulWidget {
  const _LibraryMaintenanceView(this.repository);
  final OmmAdminRepository repository;
  @override
  ConsumerState<_LibraryMaintenanceView> createState() =>
      _LibraryMaintenanceViewState();
}

class _LibraryMaintenanceViewState
    extends ConsumerState<_LibraryMaintenanceView> {
  List<Map<String, dynamic>>? _stats;
  bool _busy = false;
  String? _error;
  String? _result;
  bool get _active => mounted && widget.repository.isActive;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_busy || !_active) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await widget.repository.libraryStats();
      if (_active) setState(() => _stats = data);
    } catch (error) {
      if (_active) {
        setState(
          () => _error = localizedErrorMessage(AppL10n.of(context), error),
        );
      }
    } finally {
      if (_active) setState(() => _busy = false);
    }
  }

  Future<void> _regenerate([int? id]) async {
    if (_busy || !_active) return;
    final l = AppL10n.of(context);
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      if (!await confirmOmmAction(
            context,
            l.ommRegenerateCover,
            id == null
                ? l.ommRegenerateAllConfirm
                : l.ommRegenerateCoverConfirm,
          ) ||
          !_active) {
        return;
      }
      final data = await widget.repository.regenerateCovers(id);
      if (!_active) return;
      ref.invalidate(librariesAllProvider);
      ref.invalidate(libraryCoverImagesProvider);
      setState(
        () => _result = id == null
            ? l.ommCoverResult(
                (data['success_count'] as num? ?? 0).toInt(),
                (data['failed_count'] as num? ?? 0).toInt(),
              )
            : l.ommCoverRegenerated,
      );
    } catch (error) {
      if (_active) setState(() => _error = localizedErrorMessage(l, error));
    } finally {
      if (_active) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return OmmAdminScaffold(
      title: l.ommLibraryMaintenance,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 40),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(_error!, style: TextStyle(color: appColors(context).danger)),
          if (_result != null) Text(_result!),
          OutlinedButton(
            onPressed: _busy ? null : _load,
            child: Text(l.ommRefreshStatus),
          ),
          FilledButton(
            onPressed: _busy || _stats == null || _stats!.isEmpty
                ? null
                : _regenerate,
            child: Text(l.ommRegenerateAll),
          ),
          for (final library in _stats ?? <Map<String, dynamic>>[])
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      library['name']?.toString() ?? '',
                      style: AppText.body(context),
                    ),
                    Text(
                      l.ommLibraryCounts(
                        (library['dir_count'] as num? ?? 0).toInt(),
                        (library['movie_count'] as num? ?? 0).toInt(),
                      ),
                    ),
                    Text(
                      library['enabled'] == true
                          ? l.libraryEnable
                          : l.libraryDisable,
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _regenerate((library['id'] as num).toInt()),
                      icon: const Icon(Icons.image_outlined),
                      label: Text(l.ommRegenerateCover),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
