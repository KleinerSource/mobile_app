import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/modal_transcription_config.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';
import '../settings/settings_common.dart';
import 'modal_transcription_providers.dart';

class ModalTranscriptionSettingsPage extends ConsumerStatefulWidget {
  const ModalTranscriptionSettingsPage({super.key});

  @override
  ConsumerState<ModalTranscriptionSettingsPage> createState() =>
      _ModalTranscriptionSettingsPageState();
}

class _ModalTranscriptionSettingsPageState
    extends ConsumerState<ModalTranscriptionSettingsPage> {
  static const _gpus = [
    'T4',
    'L4',
    'A10',
    'L40S',
    'A100',
    'A100-40GB',
    'A100-80GB',
    'RTX-PRO-6000',
    'H100',
    'H100!',
    'H200',
    'B200',
    'B200+',
    'B300',
  ];
  static const _branches = [
    'v1.10',
    'v1.9',
    'v1.8',
    'v1.7',
    'v1.6',
    'v1.5',
    'v1.4',
    'v1.3',
    'v1.2',
    'v1.1',
    'v1.0',
  ];

  late final TextEditingController _tokenId = TextEditingController();
  late final TextEditingController _tokenSecret = TextEditingController();
  late final TextEditingController _hfToken = TextEditingController();

  bool _enabled = false;
  bool _hasTokenId = false;
  bool _hasTokenSecret = false;
  bool _hasHfToken = false;
  bool _showTokenId = false;
  bool _showTokenSecret = false;
  bool _showHfToken = false;
  String _gpu = 'T4';
  String _branch = 'v1.10';
  int _workers = 1;
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _tokenId.dispose();
    _tokenSecret.dispose();
    _hfToken.dispose();
    super.dispose();
  }

  void _hydrate(ModalTranscriptionConfig config) {
    if (_loaded) return;
    _loaded = true;
    _enabled = config.enabled;
    _hasTokenId = config.hasModalTokenId;
    _hasTokenSecret = config.hasModalTokenSecret;
    _hasHfToken = config.hasHfToken;
    _gpu = _gpus.contains(config.defaultGpu) ? config.defaultGpu : 'T4';
    _branch = _branches.contains(config.repoBranch)
        ? config.repoBranch
        : 'v1.10';
    _workers = config.maxWorkers.clamp(1, 10).toInt();
  }

  Future<void> _save() async {
    if (_enabled && !_hasTokenId && _tokenId.text.trim().isEmpty) {
      setState(() => _error = '启用云端字幕转译时必须填写 MODAL_TOKEN_ID');
      return;
    }
    if (_enabled && !_hasTokenSecret && _tokenSecret.text.trim().isEmpty) {
      setState(() => _error = '启用云端字幕转译时必须填写 MODAL_TOKEN_SECRET');
      return;
    }
    if (_workers < 1 || _workers > 10) {
      setState(() => _error = '并行数必须在 1-10 之间');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final value = await ref
          .read(modalTranscriptionRepositoryProvider)
          .saveConfig(
            ModalTranscriptionConfig(
              enabled: _enabled,
              modalTokenId: _tokenId.text,
              modalTokenSecret: _tokenSecret.text,
              hfToken: _hfToken.text,
              hasModalTokenId: _hasTokenId,
              hasModalTokenSecret: _hasTokenSecret,
              hasHfToken: _hasHfToken,
              defaultGpu: _gpu,
              defaultModel: 'chickenrice',
              repoBranch: _branch,
              defaultFormats: const ['srt'],
              maxWorkers: _workers,
            ),
          );
      _hasTokenId = value.hasModalTokenId;
      _hasTokenSecret = value.hasModalTokenSecret;
      _hasHfToken = value.hasHfToken;
      _tokenId.clear();
      _tokenSecret.clear();
      _hfToken.clear();
      // ignore: unused_result
      ref.refresh(modalTranscriptionConfigProvider);
      AppHaptics.medium();
      messenger.showSnackBar(const SnackBar(content: Text('云端字幕转译配置已保存')));
    } catch (error) {
      if (mounted) setState(() => _error = toApiException(error).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final async = ref.watch(modalTranscriptionConfigProvider);
    return Scaffold(
      backgroundColor: colors.bg,
      body: GlowBackground(
        child: SafeArea(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('加载失败: $error', style: AppText.body(context)),
              ),
            ),
            data: (config) {
              _hydrate(config);
              return SettingsFixedHeaderLayout(
                header: const SettingsSubPageHeader(
                  eyebrow: '系统配置',
                  title: '云端字幕转译',
                  subtitle: '配置 Modal GPU 云端转译和任务并行参数',
                ),
                body: _buildForm(colors),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildForm(AppColors colors) {
    return ListView(
      primary: true,
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
      children: [
        Container(
          decoration: settingsCardDecoration(context),
          child: SettingsTile(
            title: '启用云端字幕转译',
            subtitle: _enabled ? '已启用 · 可提交字幕转译任务' : '已停用 · 不会调用 Modal 云端服务',
            leadingIcon: Icons.cloud_sync_outlined,
            trailing: SettingsSwitch(
              value: _enabled,
              onChanged: (value) => setState(() {
                _enabled = value;
                _error = null;
              }),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _fieldLabel('MODAL_TOKEN_ID', _hasTokenId ? '已配置 · 留空则保留' : '启用时必填'),
        _secretField(
          _tokenId,
          hint: _hasTokenId ? '输入新的 Token ID' : '输入 Modal Token ID',
          visible: _showTokenId,
          onToggle: () => setState(() => _showTokenId = !_showTokenId),
        ),
        const SizedBox(height: 18),
        _fieldLabel(
          'MODAL_TOKEN_SECRET',
          _hasTokenSecret ? '已配置 · 留空则保留' : '启用时必填',
        ),
        _secretField(
          _tokenSecret,
          hint: _hasTokenSecret ? '输入新的 Token Secret' : '输入 Modal Token Secret',
          visible: _showTokenSecret,
          onToggle: () => setState(() => _showTokenSecret = !_showTokenSecret),
        ),
        const SizedBox(height: 18),
        _fieldLabel('HF_TOKEN', _hasHfToken ? '已配置 · 留空则保留' : '可选'),
        _secretField(
          _hfToken,
          hint: _hasHfToken ? '输入新的 HF Token' : '可选 Hugging Face Token',
          visible: _showHfToken,
          onToggle: () => setState(() => _showHfToken = !_showHfToken),
        ),
        const SizedBox(height: 18),
        _fieldLabel('云端 GPU', 'Modal Sandbox 使用的 GPU 类型'),
        _dropdown(
          value: _gpu,
          values: _gpus,
          icon: Icons.memory_outlined,
          onChanged: (value) => setState(() => _gpu = value),
        ),
        const SizedBox(height: 14),
        _fieldLabel('云端模型版本', 'ChickenRice 模型对应的远端仓库分支'),
        _dropdown(
          value: _branch,
          values: _branches,
          icon: Icons.model_training_outlined,
          onChanged: (value) => setState(() => _branch = value),
          labelBuilder: (value) => 'ChickenRice $value',
        ),
        const SizedBox(height: 14),
        _fieldLabel('最大并行数', '范围 1-10，默认 1'),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          decoration: settingsCardDecoration(context),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '同时处理任务数',
                      style: TextStyle(
                        color: colors.text,
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '$_workers',
                    style: AppText.mono(context, size: 16, color: colors.text),
                  ),
                ],
              ),
              HapticSlider(
                value: _workers.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: '$_workers',
                onChanged: (value) {
                  setState(() {
                    _workers = value.round();
                    _error = null;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.accent.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 17, color: colors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '当前仅支持 SRT 字幕格式。Token 输入框为空时，服务端会保留已经保存的凭据。',
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, style: TextStyle(color: colors.danger, fontSize: 12)),
        ],
        const SizedBox(height: 24),
        SettingsSaveButton(
          onPressed: _save,
          saving: _saving,
          label: '保存云端转译配置',
        ),
      ],
    );
  }

  Widget _fieldLabel(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: AppText.eyebrow(context)),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppText.meta(context).copyWith(fontSize: 10.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _secretField(
    TextEditingController controller, {
    required String hint,
    required bool visible,
    required VoidCallback onToggle,
  }) {
    final colors = appColors(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: !visible,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              style: TextStyle(
                color: colors.text,
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              visible ? Icons.visibility_off : Icons.visibility,
              size: 18,
              color: colors.muted,
            ),
            onPressed: onToggle,
          ),
        ],
      ),
    );
  }

  Widget _dropdown({
    required String value,
    required List<String> values,
    required IconData icon,
    required ValueChanged<String> onChanged,
    String Function(String value)? labelBuilder,
  }) {
    final colors = appColors(context);
    return InputDecorator(
      decoration: settingsInputDecoration(context, prefixIcon: Icon(icon)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          style: TextStyle(
            color: colors.text,
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          items: [
            for (final item in values)
              DropdownMenuItem<String>(
                value: item,
                child: Text(labelBuilder?.call(item) ?? item),
              ),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}
