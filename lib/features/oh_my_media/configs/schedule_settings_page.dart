import 'package:flutter/material.dart';
import 'package:omm/core/models/system.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'omm_admin_repository.dart';
import 'omm_admin_widgets.dart';

class ScheduleSettingsPage extends StatelessWidget {
  const ScheduleSettingsPage({super.key});
  @override
  Widget build(BuildContext context) =>
      OmmAdminScope(builder: (repository) => _ScheduleForm(repository));
}

class _ScheduleForm extends StatefulWidget {
  const _ScheduleForm(this.repository);
  final OmmAdminRepository repository;
  @override
  State<_ScheduleForm> createState() => _ScheduleFormState();
}

class _ScheduleFormState extends State<_ScheduleForm> {
  ScheduleStatus? _status;
  bool _enabled = false;
  List<String> _times = [];
  bool _busy = false;
  String? _error;
  bool get _active => mounted && widget.repository.isActive;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool save = false}) async {
    if (_busy || !_active) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final status = save
          ? await widget.repository.saveSchedule(
              _enabled,
              List.of(_times)..sort(),
            )
          : await widget.repository.schedule();
      if (!_active) return;
      setState(() {
        _status = status;
        _enabled = status.enabled;
        _times = List.of(status.times);
      });
      if (save && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppL10n.of(context).saved)));
      }
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

  Future<void> _addTime() async {
    if (_busy || _times.length >= 5) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 3, minute: 0),
    );
    if (!_active || time == null) return;
    final value =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    if (_times.contains(value)) return;
    setState(() {
      _times.add(value);
      _times.sort();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return OmmAdminScaffold(
      title: l.ommSchedule,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 40),
        children: [
          if (_busy) const LinearProgressIndicator(),
          Text(l.ommScheduleHint, style: AppText.body(context)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.ommScheduleEnabled),
            value: _enabled,
            onChanged: _busy || _status == null
                ? null
                : (value) => setState(() => _enabled = value),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final time in _times)
                InputChip(
                  label: Text(time),
                  onDeleted: _busy
                      ? null
                      : () => setState(() => _times.remove(time)),
                ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: _busy || _status == null || _times.length >= 5
                ? null
                : _addTime,
            icon: const Icon(Icons.add),
            label: Text(l.ommAddTime),
          ),
          if (_status != null) ...[
            OmmInfoRow(
              l.ommNextRun,
              _status!.nextRunAt?.toLocal().toString() ?? '',
            ),
            OmmInfoRow(
              l.ommLastRun,
              _status!.lastFiredAt?.toLocal().toString() ?? '',
            ),
            if (_status!.lastSkippedReason.isNotEmpty)
              OmmInfoRow(l.ommSkipReason, _status!.lastSkippedReason),
          ],
          if (_error != null)
            Text(_error!, style: TextStyle(color: appColors(context).danger)),
          const SizedBox(height: 16),
          if (_status == null)
            OutlinedButton(
              onPressed: _busy ? null : _load,
              child: Text(l.ommRefreshStatus),
            ),
          SettingsSaveButton(
            onPressed: _status == null || _busy
                ? null
                : () => _load(save: true),
            saving: _busy,
          ),
        ],
      ),
    );
  }
}
