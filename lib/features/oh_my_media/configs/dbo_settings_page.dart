import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/models/dbo_config.dart';
import 'package:omm/core/platform/app_haptics.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'configs_providers.dart';

class DboSettingsPage extends ConsumerStatefulWidget {
  const DboSettingsPage({super.key});

  @override
  ConsumerState<DboSettingsPage> createState() => _DboSettingsPageState();
}

class _DboSettingsPageState extends ConsumerState<DboSettingsPage> {
  List<(int, String)> _presets(AppL10n l) => [
    (0, l.dboFilterNoFilter),
    (12, l.dboFilterLastYear),
    (24, l.dboFilterLast2Years),
    (60, l.dboFilterLast5Years),
    (120, l.dboFilterLast10Years),
  ];

  final _baseUrl = TextEditingController();
  final _apiKey = TextEditingController();
  final _minResourceMonth = TextEditingController();
  int _maxAge = 0;
  bool _enabled = false;
  bool _showKey = false;
  bool _saving = false;
  bool _hasKey = false;
  String? _error;
  bool _loaded = false;

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    _minResourceMonth.dispose();
    super.dispose();
  }

  void _hydrate(DboConfig cfg) {
    if (_loaded) return;
    _loaded = true;
    _enabled = cfg.enabled;
    _baseUrl.text = cfg.baseUrl;
    _apiKey.text = cfg.apiKey;
    _maxAge = cfg.maxAgeMonths;
    _minResourceMonth.text = cfg.minResourceMonth;
    _hasKey = cfg.hasApiKey;
  }

  Future<void> _save() async {
    final l = AppL10n.of(context);
    final rawMonth = _minResourceMonth.text.trim();
    final minResourceMonth = _normalizeResourceMonth(rawMonth);
    if (rawMonth.isNotEmpty && minResourceMonth == null) {
      setState(() => _error = l.dboErrMonthFormat);
      return;
    }
    if (_maxAge > 0 && minResourceMonth != null) {
      setState(() => _error = l.dboErrBothSet);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final cfg = DboConfig(
        enabled: _enabled,
        baseUrl: _baseUrl.text.trim(),
        apiKey: _apiKey.text.trim(),
        maxAgeMonths: _maxAge,
        minResourceMonth: minResourceMonth ?? '',
      );
      final keep = _apiKey.text.trim().isEmpty && _hasKey;
      final saved = await ref
          .read(configsRepositoryProvider)
          .saveDbo(cfg, keepApiKey: keep);
      if (!mounted) return;
      if (saved.apiKey.trim().isNotEmpty) {
        _apiKey.text = saved.apiKey;
        _hasKey = true;
      }
      AppHaptics.medium();
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppL10n.of(context).configSavedToast),
          duration: const Duration(seconds: 1),
        ),
      );
      // ignore: unused_result
      ref.refresh(dboConfigProvider);
    } catch (e) {
      setState(() => _error = toApiException(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final async = ref.watch(dboConfigProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${AppL10n.of(context).loadFailed}: $e',
                  style: AppText.body(context),
                ),
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
        title: l.settingsDbo,
        subtitle: l.dboSubtitle,
      ),
      body: ListView(
        primary: true,
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
        children: [
          _label(
            l.dboEnabledLabel.toUpperCase(),
            _enabled ? l.dboEnabledHelpOn : l.dboEnabledHelpOff,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: settingsCardDecoration(context),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.dboEnableSwitchLabel,
                    style: TextStyle(
                      color: c.text,
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SettingsSwitch(
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _label('Base URL', l.dboBaseUrlExampleHint),
          _input(_baseUrl, hint: 'http://...', icon: Icons.link),
          const SizedBox(height: 18),
          _label('API Key', _hasKey ? l.dboApiKeyConfiguredHint : l.configInputPrompt),
          _passwordInput(c),
          const SizedBox(height: 18),
          _label(l.dboResourceFilterLabel, l.dboResourceFilterHelp),
          Container(
            decoration: settingsCardDecoration(context),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: TextEditingController(text: '$_maxAge')
                      ..selection = TextSelection.collapsed(
                        offset: '$_maxAge'.length,
                      ),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    style: TextStyle(
                      color: c.text,
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                    onSubmitted: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n >= 0 && n <= 120) {
                        setState(() {
                          _maxAge = n;
                          _minResourceMonth.clear();
                        });
                      }
                    },
                  ),
                ),
                Text(
                  l.dboMonthsUnit,
                  style: TextStyle(
                    color: c.muted,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Text(
                    _maxAge == 0
                        ? l.dboFilterNoFilter
                        : l.dboAgePreview(
                            (_maxAge / 12).toStringAsFixed(1),
                          ),
                    style: TextStyle(
                      color: c.muted,
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: _presets(l).map((p) {
              final active = _maxAge == p.$1;
              return GestureDetector(
                onTap: () {
                  if (active) return;
                  AppHaptics.selection();
                  setState(() {
                    _maxAge = p.$1;
                    _minResourceMonth.clear();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: active ? c.chipBgActive : c.chipBg,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    p.$2,
                    style: TextStyle(
                      color: active ? c.chipTextActive : c.text2,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          _label(l.dboStartMonthLabel, l.dboStartMonthHelp),
          Container(
            decoration: settingsCardDecoration(context),
            child: TextField(
              controller: _minResourceMonth,
              keyboardType: TextInputType.datetime,
              autocorrect: false,
              textAlignVertical: TextAlignVertical.center,
              onChanged: (value) {
                if (value.trim().isNotEmpty && _maxAge != 0) {
                  setState(() => _maxAge = 0);
                }
              },
              decoration: settingsInputDecoration(
                context,
                hintText: l.dboStartMonthHint,
                prefixIcon: const Icon(Icons.calendar_today_outlined),
                borderless: true,
              ),
              style: TextStyle(
                color: c.text,
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _errorBox(_error!),
          ],
          const SizedBox(height: 28),
          SettingsSaveButton(onPressed: _save, saving: _saving),
        ],
      ),
    );
  }

  Widget _label(String label, String help) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppText.eyebrow(context)),
          if (help.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(help, style: AppText.meta(context).copyWith(fontSize: 10.5)),
          ],
        ],
      ),
    );
  }

  Widget _input(
    TextEditingController controller, {
    String? hint,
    IconData? icon,
  }) {
    final c = appColors(context);
    return Container(
      decoration: settingsCardDecoration(context),
      child: TextField(
        controller: controller,
        textAlignVertical: TextAlignVertical.center,
        decoration: settingsInputDecoration(
          context,
          hintText: hint,
          prefixIcon: icon == null ? null : Icon(icon),
          borderless: true,
        ),
        style: TextStyle(
          color: c.text,
          fontFamily: 'monospace',
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _passwordInput(AppColors c) {
    return Container(
      decoration: settingsCardDecoration(context),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _apiKey,
              obscureText: !_showKey,
              textAlignVertical: TextAlignVertical.center,
              decoration: settingsInputDecoration(
                context,
                hintText: _hasKey
                    ? AppL10n.of(context).dboNewApiKeyHint
                    : AppL10n.of(context).configInputPrompt,
                prefixIcon: const Icon(Icons.key_outlined),
                borderless: true,
              ),
              style: TextStyle(
                color: c.text,
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _showKey ? Icons.visibility_off : Icons.visibility,
              size: 18,
              color: c.muted,
            ),
            onPressed: () => setState(() => _showKey = !_showKey),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(String msg) {
    final c = appColors(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.danger.withValues(alpha: 0.1),
        border: Border.all(color: c.danger.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: c.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(
                color: c.danger,
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _normalizeResourceMonth(String value) {
    final month = value.trim();
    if (month.isEmpty) return '';
    final match = RegExp(r'^(\d{4})-(\d{1,2})$').firstMatch(month);
    if (match == null) return null;
    final monthNumber = int.tryParse(match.group(2)!);
    if (monthNumber == null || monthNumber < 1 || monthNumber > 12) {
      return null;
    }
    return '${match.group(1)}-${monthNumber.toString().padLeft(2, '0')}';
  }
}
