import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/dbo_config.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';
import '../settings/settings_common.dart';
import 'configs_providers.dart';

class DboSettingsPage extends ConsumerStatefulWidget {
  const DboSettingsPage({super.key});

  @override
  ConsumerState<DboSettingsPage> createState() => _DboSettingsPageState();
}

class _DboSettingsPageState extends ConsumerState<DboSettingsPage> {
  static const _presets = [
    (0, '不过滤'),
    (12, '近 1 年'),
    (24, '近 2 年'),
    (60, '近 5 年'),
    (120, '近 10 年'),
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
    _maxAge = cfg.maxAgeMonths;
    _minResourceMonth.text = cfg.minResourceMonth;
    _hasKey = cfg.hasApiKey;
  }

  Future<void> _save() async {
    final rawMonth = _minResourceMonth.text.trim();
    final minResourceMonth = _normalizeResourceMonth(rawMonth);
    if (rawMonth.isNotEmpty && minResourceMonth == null) {
      setState(() => _error = '起始年月必须使用 YYYY-MM 格式');
      return;
    }
    if (_maxAge > 0 && minResourceMonth != null) {
      setState(() => _error = '最近资源时间和起始年月只能二选一');
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
      await ref
          .read(configsRepositoryProvider)
          .saveDbo(cfg, keepApiKey: keep);
      AppHaptics.medium();
      messenger.showSnackBar(const SnackBar(
        content: Text('已保存'),
        duration: Duration(seconds: 1),
      ));
      _apiKey.clear();
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
                child: Text('加载失败: $e', style: AppText.body(context)),
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
    return Column(
      children: [
        const SettingsSubPageHeader(
          eyebrow: '工具',
          title: 'DB Online 数据源',
          subtitle: 'Base URL + API Key,用于影片信息、资源和演员关联同步',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
            children: [
              _label('启用', _enabled ? '已启用 · 所有 DBO 功能可用' : '已停用 · 所有 DBO 功能将被屏蔽'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: settingsCardDecoration(context),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '启用 DB Online',
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
              _label('Base URL', '例: http://10.0.0.50:9090'),
              _input(_baseUrl, hint: 'http://...'),
              const SizedBox(height: 18),
              _label('API Key', _hasKey ? '已配置 · 留空则保留' : '请输入'),
              _passwordInput(c),
              const SizedBox(height: 18),
              _label('资源过滤器', '按发布日期过滤 · 0 = 不过滤'),
              Container(
                decoration: settingsCardDecoration(context),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: TextEditingController(text: '$_maxAge')
                          ..selection = TextSelection.collapsed(
                              offset: '$_maxAge'.length),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
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
                    Text('个月',
                        style: TextStyle(
                            color: c.muted,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Text(
                        _maxAge == 0
                            ? '不过滤'
                            : '约 ${(_maxAge / 12).toStringAsFixed(1)} 年',
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
                children: _presets.map((p) {
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
                          horizontal: 12, vertical: 7),
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
              _label('起始年月', '按发布日期保留该月份及之后的资源 · 格式 YYYY-MM'),
              Container(
                decoration: settingsCardDecoration(context),
                child: TextField(
                  controller: _minResourceMonth,
                  keyboardType: TextInputType.datetime,
                  autocorrect: false,
                  onChanged: (value) {
                    if (value.trim().isNotEmpty && _maxAge != 0) {
                      setState(() => _maxAge = 0);
                    }
                  },
                  decoration: settingsInputDecoration(
                    context,
                    hintText: '例如 2024-01',
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
              SettingsSaveButton(
                onPressed: _save,
                saving: _saving,
              ),
            ],
          ),
        ),
      ],
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
            Text(help, style: AppText.meta(context)),
          ],
        ],
      ),
    );
  }

  Widget _input(TextEditingController controller, {String? hint}) {
    final c = appColors(context);
    return Container(
      decoration: settingsCardDecoration(context),
      child: TextField(
        controller: controller,
        decoration: settingsInputDecoration(
          context,
          hintText: hint,
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
              decoration: settingsInputDecoration(
                context,
                hintText: _hasKey ? '已配置 · 留空则保留' : '请输入',
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
            icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility,
                size: 18, color: c.muted),
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
