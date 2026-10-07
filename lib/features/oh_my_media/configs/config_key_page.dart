import 'package:flutter/material.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'omm_admin_repository.dart';
import 'omm_admin_widgets.dart';

class ConfigKeyPage extends StatelessWidget {
  const ConfigKeyPage({super.key});
  @override
  Widget build(BuildContext context) =>
      OmmAdminScope(builder: (repository) => _ConfigKeyForm(repository));
}

class _ConfigKeyForm extends StatefulWidget {
  const _ConfigKeyForm(this.repository);
  final OmmAdminRepository repository;
  @override
  State<_ConfigKeyForm> createState() => _ConfigKeyFormState();
}

class _ConfigKeyFormState extends State<_ConfigKeyForm> {
  final _key = TextEditingController();
  final _value = TextEditingController();
  final _description = TextEditingController();
  String? _loadedKey;
  String? _error;
  bool _busy = false;
  bool get _active => mounted && widget.repository.isActive;
  @override
  void dispose() {
    _key.dispose();
    _value.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _run(String action) async {
    if (_busy || !_active) return;
    final l = AppL10n.of(context);
    final key = _key.text.trim();
    if (key.isEmpty) {
      setState(() => _error = l.ommConfigKeyRequired);
      return;
    }
    final value = _value.text;
    final description = _description.text;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (action == 'delete') {
        if (!await confirmOmmAction(
              context,
              l.delete,
              l.ommDeleteConfigConfirm(key),
            ) ||
            !_active) {
          return;
        }
        await widget.repository.deleteConfig(key);
        if (!_active) return;
        setState(() {
          _loadedKey = null;
          _value.clear();
          _description.clear();
        });
      } else {
        final data = switch (action) {
          'create' => await widget.repository.createConfig(
            key,
            value,
            description,
          ),
          'update' => await widget.repository.updateConfig(
            key,
            value,
            description,
          ),
          _ => await widget.repository.config(key),
        };
        if (!_active) return;
        setState(() {
          _loadedKey = key;
          _value.text = data['config_value']?.toString() ?? '';
          _description.text = data['description']?.toString() ?? '';
        });
      }
      if (action != 'read' && mounted && _active) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(action == 'delete' ? l.deleted : l.saved)),
        );
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
    return OmmAdminScaffold(
      title: l.ommConfigKeys,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 40),
        children: [
          Text(l.ommConfigKeysHint, style: AppText.body(context)),
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            enabled: !_busy,
            autocorrect: false,
            decoration: settingsInputDecoration(
              context,
              labelText: l.ommConfigKey,
            ),
            onChanged: (_) => setState(() {
              _loadedKey = null;
              _error = null;
              _value.clear();
              _description.clear();
            }),
          ),
          OutlinedButton(
            onPressed: _busy ? null : () => _run('read'),
            child: Text(l.ommReadConfig),
          ),
          TextField(
            controller: _value,
            enabled: !_busy,
            minLines: 3,
            maxLines: 12,
            autocorrect: false,
            decoration: settingsInputDecoration(
              context,
              labelText: l.ommConfigValue,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            enabled: !_busy,
            maxLines: 3,
            decoration: settingsInputDecoration(
              context,
              labelText: l.ommConfigDescription,
            ),
          ),
          const SizedBox(height: 12),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(_error!, style: TextStyle(color: appColors(context).danger)),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(_loadedKey == null ? 'create' : 'update'),
            child: Text(_loadedKey == null ? l.create : l.save),
          ),
          if (_loadedKey != null)
            OutlinedButton(
              onPressed: _busy ? null : () => _run('delete'),
              child: Text(l.delete),
            ),
        ],
      ),
    );
  }
}
