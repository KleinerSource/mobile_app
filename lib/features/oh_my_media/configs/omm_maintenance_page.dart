import 'package:flutter/material.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'omm_admin_repository.dart';
import 'omm_admin_widgets.dart';

class OmmMaintenancePage extends StatelessWidget {
  const OmmMaintenancePage({super.key});
  @override
  Widget build(BuildContext context) => OmmAdminScope(
    builder: (repository) => _MaintenanceView(repository: repository),
  );
}

class _MaintenanceView extends StatefulWidget {
  const _MaintenanceView({required this.repository});
  final OmmAdminRepository repository;
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
      final data = await widget.repository.orphanedCount();
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

  Future<void> _change() async {
    if (_busy || !_active) return;
    final l = AppL10n.of(context);
    setState(() => _busy = true);
    try {
      if (!await confirmOmmAction(context, l.ommCleanup, l.ommCleanupConfirm)) {
        return;
      }
      if (!_active) return;
      final removed = await widget.repository.cleanupOrphans();
      if (!_active) return;
      _result = l.ommCleanedCount(
        removed.values.whereType<num>().fold<int>(
          0,
          (sum, count) => sum + count.toInt(),
        ),
      );
      final data = await widget.repository.orphanedCount();
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
      title: l.ommMaintenance,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 40),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (data != null) ...[
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
            onPressed: _busy || data == null ? null : _change,
            child: Text(l.ommCleanup),
          ),
        ],
      ),
    );
  }
}
