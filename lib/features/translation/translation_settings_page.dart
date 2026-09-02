import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/translation_config.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glass.dart';
import '../../shared/glow_background.dart';
import '../../shared/sheet_controls.dart';
import '../settings/settings_common.dart';
import 'translation_providers.dart';

class TranslationSettingsPage extends ConsumerStatefulWidget {
  const TranslationSettingsPage({super.key});

  @override
  ConsumerState<TranslationSettingsPage> createState() =>
      _TranslationSettingsPageState();
}

class _TranslationSettingsPageState
    extends ConsumerState<TranslationSettingsPage> {
  /// 语言下拉的稳定取值（原样存进 TranslationConfig 并提交给后端提示词）。
  /// 显示文案在 _langLabel 里本地化，存储值保持历史兼容不做迁移。
  static const _sourceLangs = [
    '自动检测',
    '中文',
    '英文',
    '日文',
    '韩文',
    '法文',
    '德文',
    '西班牙文',
    '俄文',
  ];
  static const _targetLangs = [
    '中文',
    '英文',
    '日文',
    '韩文',
    '法文',
    '德文',
    '西班牙文',
    '俄文',
  ];

  /// 下拉显示文案 · 按稳定取值映射到本地化标签。
  String _langLabel(AppL10n l, String value) {
    return switch (value) {
      '自动检测' => l.translationLangAutoDetect,
      '中文' => l.translationLangChinese,
      '英文' => l.translationLangEnglish,
      '日文' => l.translationLangJapanese,
      '韩文' => l.translationLangKorean,
      '法文' => l.translationLangFrench,
      '德文' => l.translationLangGerman,
      '西班牙文' => l.translationLangSpanish,
      '俄文' => l.translationLangRussian,
      _ => value,
    };
  }

  late final TextEditingController _apiUrl = TextEditingController();
  late final TextEditingController _apiKey = TextEditingController();
  late final TextEditingController _model = TextEditingController();
  late final TextEditingController _prompt = TextEditingController();

  bool _enabled = false;
  String _source = '自动检测';
  String _target = '中文';
  bool _hasSavedKey = false;
  bool _showKey = false;
  bool _saving = false;
  bool _testing = false;
  bool _loadingModels = false;
  String? _testResult;
  String? _error;
  bool _loaded = false;

  @override
  void dispose() {
    _apiUrl.dispose();
    _apiKey.dispose();
    _model.dispose();
    _prompt.dispose();
    super.dispose();
  }

  void _hydrate(TranslationConfig cfg) {
    if (_loaded) return;
    _loaded = true;
    _apiUrl.text = cfg.apiUrl;
    _model.text = cfg.modelName;
    _prompt.text = cfg.promptTemplate;
    _enabled = cfg.enabled;
    _source = cfg.sourceLanguage.isEmpty ? '自动检测' : cfg.sourceLanguage;
    _target = cfg.targetLanguage.isEmpty ? '中文' : cfg.targetLanguage;
    _hasSavedKey = cfg.hasApiKey;
  }

  Future<void> _loadModels() async {
    final l = AppL10n.of(context);
    final url = _apiUrl.text.trim();
    final key = _apiKey.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.translationNeedApiUrl)));
      return;
    }
    if (key.isEmpty && !_hasSavedKey) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.translationNeedApiKey)));
      return;
    }
    setState(() => _loadingModels = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // 如果用户没新填 key,把空字符串传后端 (后端会用已保存的 key)
      final models = await ref
          .read(translationRepositoryProvider)
          .fetchModels(url, key);
      if (!mounted) return;
      if (models.isEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text(AppL10n.of(context).translationNoModels)),
        );
        return;
      }
      final picked = await showGlassSheet<String>(
        context: context,
        builder: (ctx) {
          final c = appColors(ctx);
          final mediaQuery = MediaQuery.of(ctx);
          final maxHeight =
              (mediaQuery.size.height -
                      mediaQuery.viewPadding.top -
                      mediaQuery.viewPadding.bottom -
                      24)
                  .clamp(0.0, mediaQuery.size.height)
                  .toDouble();
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SheetHeader(
                  icon: Icons.model_training_outlined,
                  title: AppL10n.of(
                    ctx,
                  ).translationSelectModel(models.length),
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
                ),
                Flexible(
                  fit: FlexFit.loose,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: models.length,
                    itemBuilder: (_, i) {
                      final m = models[i];
                      return ListTile(
                        title: Text(
                          m.id,
                          style: TextStyle(
                            color: c.text,
                            fontFamily: 'monospace',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: m.id == _model.text.trim()
                            ? Icon(Icons.check, color: c.accent)
                            : null,
                        onTap: () => Navigator.pop(ctx, m.id),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          );
        },
      );
      if (picked != null && mounted) {
        setState(() => _model.text = picked);
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l.translationLoadModelsFailed(toApiException(e).message),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  Future<void> _save() async {
    final l = AppL10n.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final cfg = TranslationConfig(
        enabled: _enabled,
        apiUrl: _apiUrl.text.trim(),
        apiKey: _apiKey.text.trim(),
        modelName: _model.text.trim(),
        sourceLanguage: _source,
        targetLanguage: _target,
        promptTemplate: _prompt.text,
      );
      final keepKey = _apiKey.text.trim().isEmpty && _hasSavedKey;
      await ref
          .read(translationRepositoryProvider)
          .saveConfig(cfg, keepApiKey: keepKey);
      AppHaptics.medium();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.translationSaved),
          duration: const Duration(seconds: 1),
        ),
      );
      _apiKey.clear();
      // ignore: unused_result
      ref.refresh(translationConfigProvider);
    } catch (e) {
      setState(() => _error = toApiException(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    final l = AppL10n.of(context);
    setState(() {
      _testing = true;
      _testResult = null;
      _error = null;
    });
    try {
      final res = await ref.read(translationRepositoryProvider).test();
      setState(() => _testResult = res.isEmpty ? l.translationTestPassed : res);
    } catch (e) {
      setState(
        () => _error = l.translationTestFailed(toApiException(e).message),
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final async = ref.watch(translationConfigProvider);

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
        eyebrow: l.settingsGroupSystem,
        title: l.translationTitle,
        subtitle: l.translationSubtitle,
      ),
      body: ListView(
        primary: true,
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              decoration: settingsCardDecoration(context),
              child: SettingsTile(
                title: l.translationEnable,
                subtitle: _enabled
                    ? l.translationEnabledSubtitle
                    : l.translationDisabledSubtitle,
                leadingIcon: Icons.translate_outlined,
                trailing: SettingsSwitch(
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
              ),
            ),
          ),
          _label('API URL', l.translationApiUrlHelp),
          _input(_apiUrl, hint: 'https://api.openai.com/v1', icon: Icons.link),
          const SizedBox(height: 18),
          _label(
            'API Key',
            _hasSavedKey ? l.translationConfiguredKeepHint : 'sk-...',
          ),
          _passwordInput(),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _label(
                  l.translationModelNameLabel,
                  l.translationModelNameHelp,
                ),
              ),
              TextButton.icon(
                icon: _loadingModels
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 16),
                label: Text(
                  l.translationLoadModels,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                onPressed: _loadingModels ? null : _loadModels,
              ),
            ],
          ),
          _input(_model, hint: 'gpt-3.5-turbo', icon: Icons.smart_toy_outlined),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _label(l.translationSourceLanguage, '')),
              const SizedBox(width: 10),
              Expanded(child: _label(l.translationTargetLanguage, '')),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _langDropdown(
                  value: _source,
                  options: _sourceLangs,
                  onChanged: (v) => setState(() => _source = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _langDropdown(
                  value: _target,
                  options: _targetLangs,
                  onChanged: (v) => setState(() => _target = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _label(
            l.translationPromptTemplateLabel,
            l.translationPromptTemplateHelp('{text} {target_language}'),
          ),
          _input(
            _prompt,
            maxLines: 6,
            hint: 'You are ...',
            icon: Icons.edit_note,
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _errorBox(_error!),
          ],
          if (_testResult != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppHues.top(AppHues.mint).withValues(alpha: 0.12),
                border: Border.all(
                  color: AppHues.top(AppHues.mint).withValues(alpha: 0.4),
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: AppHues.top(AppHues.mint),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l.translationTestResult,
                        style: TextStyle(
                          color: AppHues.top(AppHues.mint),
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(_testResult!, style: AppText.body(context)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          SettingsSaveButton(onPressed: _save, saving: _saving),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _testing ? null : _test,
              style: OutlinedButton.styleFrom(
                foregroundColor: c.text,
                side: BorderSide(color: c.cardBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _testing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.translate_outlined, size: 18),
              label: Text(
                l.translationTestButton,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
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
    int maxLines = 1,
    IconData? icon,
  }) {
    final c = appColors(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        textAlignVertical: maxLines == 1
            ? TextAlignVertical.center
            : null,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: icon == null ? null : Icon(icon),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
        style: TextStyle(
          color: c.text,
          fontFamily: maxLines > 1 ? 'monospace' : 'Inter',
          fontSize: maxLines > 1 ? 12.5 : 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _passwordInput() {
    final c = appColors(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _apiKey,
              obscureText: !_showKey,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: _hasSavedKey
                    ? AppL10n.of(context).translationNewApiKeyHint
                    : 'sk-...',
                prefixIcon: const Icon(Icons.key_outlined),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
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

  Widget _langDropdown({
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    final c = appColors(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButton<String>(
        value: options.contains(value) ? value : options.first,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        items: options
            .map(
              (v) => DropdownMenuItem(
                value: v,
                child: Text(_langLabel(AppL10n.of(context), v)),
              ),
            )
            .toList(),
        style: TextStyle(
          color: c.text,
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
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
        borderRadius: BorderRadius.circular(10),
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
}
