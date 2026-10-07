import 'package:flutter/material.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'omm_admin_repository.dart';
import 'omm_admin_widgets.dart';

class OmmMaintenancePage extends StatelessWidget {
  const OmmMaintenancePage({super.key, this.mappingCache = false});
  final bool mappingCache;
  @override
  Widget build(BuildContext context) => OmmAdminScope(
    builder: (repository) =>
        _MaintenanceView(repository: repository, mappingCache: mappingCache),
  );
}

class _MaintenanceView extends StatefulWidget {
  const _MaintenanceView({
    required this.repository,
    required this.mappingCache,
  });
  final OmmAdminRepository repository;
  final bool mappingCache;
  @override
  State<_MaintenanceView> createState() => _MaintenanceViewState();
}

class _MaintenanceViewState extends State<_MaintenanceView> {
  Map<String, dynamic>? _data;
  String? _result;
  String? _error;
  bool _busy = false;
  bool get _active => mounted && widget.repository.isActive;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = widget.mappingCache
          ? await widget.repository.cacheInfo()
          : await widget.repository.orphanedCount();
      if (_active) setState(() => _data = data);
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

  Future<void> _change({bool invalidate = false}) async {
    if (_busy || !_active) return;
    final l = AppL10n.of(context);
    setState(() => _busy = true);
    try {
      if (!widget.mappingCache &&
          !await confirmOmmAction(context, l.ommCleanup, l.ommCleanupConfirm)) {
        return;
      }
      if (!_active) return;
      if (widget.mappingCache) {
        if (invalidate) {
          await widget.repository.invalidateCache();
        } else {
          await widget.repository.refreshCache();
        }
      } else {
        final removed = await widget.repository.cleanupOrphans();
        if (!_active) return;
        _result = l.ommCleanedCount(
          removed.values.whereType<num>().fold<int>(
            0,
            (sum, count) => sum + count.toInt(),
          ),
        );
      }
      if (!_active) return;
      final data = widget.mappingCache
          ? await widget.repository.cacheInfo()
          : await widget.repository.orphanedCount();
      if (_active) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } catch (error) {
      if (_active) setState(() => _error = localizedErrorMessage(l, error));
    } finally {
      if (_active) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final data = _data;
    return OmmAdminScaffold(
      title: widget.mappingCache ? l.ommMappingCache : l.ommMaintenance,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 40),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (data != null && widget.mappingCache) ...[
            OmmInfoRow(
              l.ommCacheState,
              data['loaded'] == true
                  ? (data['expired'] == true ? l.ommExpired : l.ommReady)
                  : l.ommNotLoaded,
            ),
            OmmInfoRow(l.ommCacheSize, '${data['cache_size'] ?? 0}'),
            OmmInfoRow(
              l.ommCacheTypes,
              (data['types'] as List? ?? []).join(', '),
            ),
            OmmInfoRow(
              l.ommLastUpdated,
              data['last_updated']?.toString() ?? '',
            ),
            OmmInfoRow(l.ommCacheTtl, '${data['ttl_seconds'] ?? 0} s'),
          ],
          if (data != null && !widget.mappingCache) ...[
            Text(l.ommCleanupHint, style: AppText.body(context)),
            OmmInfoRow(
              l.ommOrphanCount,
              '${data.values.whereType<num>().fold<int>(0, (sum, count) => sum + count.toInt())}',
            ),
          ],
          if (_result != null) Text(_result!),
          if (_error != null)
            Text(_error!, style: TextStyle(color: appColors(context).danger)),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _busy ? null : _load,
            child: Text(l.ommRefreshStatus),
          ),
          FilledButton(
            onPressed: _busy || data == null ? null : () => _change(),
            child: Text(widget.mappingCache ? l.ommRefreshCache : l.ommCleanup),
          ),
          if (widget.mappingCache)
            OutlinedButton(
              onPressed: _busy || data == null
                  ? null
                  : () => _change(invalidate: true),
              child: Text(l.ommInvalidateCache),
            ),
        ],
      ),
    );
  }
}
