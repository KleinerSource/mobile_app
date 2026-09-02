import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/models/avdb_config.dart';
import 'package:omm/core/platform/app_haptics.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'configs_providers.dart';

class AvdbSettingsPage extends ConsumerStatefulWidget {
  const AvdbSettingsPage({super.key});

  @override
  ConsumerState<AvdbSettingsPage> createState() => _AvdbSettingsPageState();
}

class _AvdbSettingsPageState extends ConsumerState<AvdbSettingsPage> {
  final _baseUrl = TextEditingController();
  final _apiKey = TextEditingController();
  bool _enabled = false;
  bool _showKey = false;
  bool _hasKey = false;
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  void _hydrate(AvdbConfig cfg) {
    if (_loaded) return;
    _loaded = true;
    _enabled = cfg.enabled;
    _baseUrl.text = cfg.baseUrl;
    _apiKey.text = cfg.apiKey;
    _hasKey = cfg.hasApiKey;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final apiKey = _apiKey.text.trim();
      final saved = await ref
          .read(configsRepositoryProvider)
          .saveAvdb(
            AvdbConfig(
              enabled: _enabled,
              baseUrl: _baseUrl.text.trim(),
              apiKey: apiKey,
            ),
            keepApiKey: apiKey.isEmpty && _hasKey,
          );
      if (!mounted) return;
      if (saved.apiKey.trim().isNotEmpty) {
        _apiKey.text = saved.apiKey;
        _hasKey = true;
      }
      ref.invalidate(avdbConfigProvider);
      AppHaptics.medium();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.of(context).avdbSavedToast)),
      );
    } catch (e) {
      if (mounted) setState(() => _error = toApiException(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final async = ref.watch(avdbConfigProvider);
    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(
                '${AppL10n.of(context).loadFailed}: ${toApiException(error).message}',
              ),
            ),
            data: (cfg) {
              _hydrate(cfg);
              return _buildForm(c);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildForm(AppColors c) {
    final l = AppL10n.of(context);
    return SettingsFixedHeaderLayout(
      header: SettingsSubPageHeader(
        eyebrow: l.settingsGroupTools,
        title: l.avdbTitle,
        subtitle: l.avdbSubtitle,
      ),
      body: ListView(
        primary: true,
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
        children: [
          _sectionLabel(l.avdbStatusSection),
          _switchCard(
            c,
            title: l.avdbEnableTitle,
            subtitle: _enabled ? l.avdbEnableOn : l.avdbEnableOff,
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
          ),
          const SizedBox(height: 18),
          _sectionLabel(l.avdbServerSection),
          _field(_baseUrl, hint: 'https://example.com'),
          const SizedBox(height: 18),
          _sectionLabel('API Key'),
          Text(
            _hasKey ? l.avdbKeyConfigured : l.avdbKeyPrompt,
            style: AppText.meta(context),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _apiKey,
            obscureText: !_showKey,
            textAlignVertical: TextAlignVertical.center,
            decoration: settingsInputDecoration(
              context,
              hintText: l.avdbKeyKeepHint,
              prefixIcon: const Icon(Icons.key_outlined),
              suffixIcon: IconButton(
                tooltip: _showKey ? l.avdbKeyHide : l.avdbKeyShow,
                icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showKey = !_showKey),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _errorBox(c, _error!),
          ],
          const SizedBox(height: 28),
          SettingsSaveButton(onPressed: _save, saving: _saving),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text.toUpperCase(), style: AppText.eyebrow(context)),
  );

  Widget _field(TextEditingController controller, {required String hint}) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.url,
      textAlignVertical: TextAlignVertical.center,
      decoration: settingsInputDecoration(
        context,
        hintText: hint,
        prefixIcon: const Icon(Icons.link),
      ),
    );
  }

  Widget _switchCard(
    AppColors c, {
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
                  style: TextStyle(color: c.text, fontWeight: FontWeight.w700),
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

  Widget _errorBox(AppColors c, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.danger.withValues(alpha: 0.10),
        border: Border.all(color: c.danger.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: TextStyle(color: c.danger)),
    );
  }
}
