import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/translation_config.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';
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
    final url = _apiUrl.text.trim();
    final key = _apiKey.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先填 API URL')),
      );
      return;
    }
    if (key.isEmpty && !_hasSavedKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先填 API Key')),
      );
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
          const SnackBar(content: Text('未拿到任何模型')),
        );
        return;
      }
      final picked = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: appColors(context).bg,
        showDragHandle: true,
        builder: (ctx) {
          final c = appColors(ctx);
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
                  child: Row(children: [
                    Text('选择模型 (${models.length})',
                        style: AppText.sectionTitle(ctx)),
                  ]),
                ),
                Flexible(
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
        SnackBar(content: Text('加载模型失败: ${toApiException(e).message}')),
      );
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  Future<void> _save() async {
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
      messenger.showSnackBar(const SnackBar(
        content: Text('已保存'),
        duration: Duration(seconds: 1),
      ));
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
    setState(() {
      _testing = true;
      _testResult = null;
      _error = null;
    });
    try {
      final res = await ref.read(translationRepositoryProvider).test();
      setState(() => _testResult = res.isEmpty ? '测试通过' : res);
    } catch (e) {
      setState(() => _error = '测试失败: ${toApiException(e).message}');
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
          eyebrow: '系统配置',
          title: '翻译配置',
          subtitle: '配置 ChatGPT API 翻译功能',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
          child: Container(
            decoration: settingsCardDecoration(context),
            child: SettingsTile(
              title: '启用翻译',
              subtitle: _enabled
                  ? '已启用 · 翻译功能可用'
                  : '已禁用 · 保存后不调用翻译服务',
              leadingIcon: Icons.translate_outlined,
              trailing: SettingsSwitch(
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
            children: [
              _label('API URL', '支持 OpenAI / OpenRouter 等兼容服务'),
              _input(_apiUrl, hint: 'https://api.openai.com/v1'),
              const SizedBox(height: 18),
              _label('API Key', _hasSavedKey ? '已配置 · 留空则保留' : 'sk-...'),
              _passwordInput(),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: _label('模型名称', '例: gpt-3.5-turbo / gpt-4')),
                  TextButton.icon(
                    icon: _loadingModels
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 16),
                    label: const Text('加载模型',
                        style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                    onPressed: _loadingModels ? null : _loadModels,
                  ),
                ],
              ),
              _input(_model, hint: 'gpt-3.5-turbo'),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: _label('源语言', '')),
                  const SizedBox(width: 10),
                  Expanded(child: _label('目标语言', '')),
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
              _label('提示词模板', '需包含 {text} {target_language}'),
              _input(_prompt, maxLines: 6, hint: 'You are ...'),
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
                        color: AppHues.top(AppHues.mint).withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.check_circle_outline,
                            size: 16,
                            color: AppHues.top(AppHues.mint)),
                        const SizedBox(width: 6),
                        Text('测试结果',
                            style: TextStyle(
                              color: AppHues.top(AppHues.mint),
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                            )),
                      ]),
                      const SizedBox(height: 6),
                      Text(_testResult!, style: AppText.body(context)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              SettingsSaveButton(
                onPressed: _save,
                saving: _saving,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _testing ? null : _test,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.text,
                    side: BorderSide(color: c.cardBorder),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _testing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          '测试翻译',
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              fontSize: 14),
                        ),
                ),
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

  Widget _input(
    TextEditingController controller, {
    String? hint,
    int maxLines = 1,
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
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              decoration: InputDecoration(
                hintText: _hasSavedKey ? '已配置 · 留空则保留' : 'sk-...',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
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
            .map((v) => DropdownMenuItem(value: v, child: Text(v)))
            .toList(),
        style: TextStyle(
            color: c.text,
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600),
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
