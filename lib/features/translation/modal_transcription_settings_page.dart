import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/modal_transcription_config.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';
import '../../shared/swipe_actions.dart';
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
  static const _strategyLabels = {
    'round_robin': '轮询（均匀分配）',
    'fill_first': '填充优先（集中靠前令牌）',
  };

  late final TextEditingController _hfToken = TextEditingController();

  /// 当前左滑展开的令牌行，同一时刻只展开一个。
  final SwipeActionGroup _openSwipe = SwipeActionGroup(null);
  final _scrollController = ScrollController();

  bool _enabled = false;
  bool _hasHfToken = false;
  bool _showHfToken = false;
  List<ModalTranscriptionToken> _tokens = const [];
  String _tokenStrategy = 'round_robin';
  int _perTokenWorkers = 0;
  String _gpu = 'T4';
  String _branch = 'v1.10';
  int _workers = 1;
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_closeSwipeOnScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_closeSwipeOnScroll);
    _openSwipe.dispose();
    _scrollController.dispose();
    _hfToken.dispose();
    super.dispose();
  }

  /// 列表开始滚动时收起已展开的左滑操作。
  void _closeSwipeOnScroll() {
    if (_openSwipe.value != null) _openSwipe.value = null;
  }

  void _hydrate(ModalTranscriptionConfig config) {
    if (_loaded) return;
    _loaded = true;
    _applyConfig(config);
  }

  /// 以服务端返回的脱敏配置重建本地草稿，清空所有明文输入。
  void _applyConfig(ModalTranscriptionConfig config) {
    _enabled = config.enabled;
    _tokens = config.tokens;
    _tokenStrategy =
        ModalTranscriptionConfig.tokenStrategies.contains(config.tokenStrategy)
        ? config.tokenStrategy
        : 'round_robin';
    _perTokenWorkers = config.perTokenWorkers.clamp(0, 10);
    _hasHfToken = config.hasHfToken;
    _gpu = _gpus.contains(config.defaultGpu) ? config.defaultGpu : 'T4';
    _branch = _branches.contains(config.repoBranch)
        ? config.repoBranch
        : 'v1.10';
    _workers = config.maxWorkers.clamp(1, 10).toInt();
  }

  Future<void> _editToken({int? index}) async {
    final initial = index == null
        ? const ModalTranscriptionToken()
        : _tokens[index];
    final otherTokenIds = [
      for (var i = 0; i < _tokens.length; i++)
        if (i != index) _tokens[i].tokenId.trim(),
    ].where((value) => value.isNotEmpty).toList();

    final result = await showModalBottomSheet<ModalTranscriptionToken>(
      context: context,
      backgroundColor: appColors(context).bg,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) =>
          _TokenEditorSheet(initial: initial, otherTokenIds: otherTokenIds),
    );
    if (result == null || !mounted) return;
    AppHaptics.selection();
    setState(() {
      if (index == null) {
        _tokens = [..._tokens, result];
      } else {
        _tokens = [
          for (var i = 0; i < _tokens.length; i++)
            i == index ? result : _tokens[i],
        ];
      }
      _error = null;
    });
  }

  void _removeToken(int index) {
    AppHaptics.selection();
    setState(() {
      _tokens = [
        for (var i = 0; i < _tokens.length; i++)
          if (i != index) _tokens[i],
      ];
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_enabled && _tokens.isEmpty) {
      setState(() => _error = '启用云端字幕转译时至少需要添加一个 Modal 令牌');
      return;
    }
    final incomplete = _tokens.any(
      (token) =>
          !token.isExisting &&
          (token.tokenId.trim().isEmpty || token.tokenSecret.trim().isEmpty),
    );
    if (incomplete) {
      setState(() => _error = '新增令牌必须同时填写 Token ID 和 Token Secret');
      return;
    }
    final draftIds = [
      for (final token in _tokens)
        if (token.tokenId.trim().isNotEmpty) token.tokenId.trim(),
    ];
    if (draftIds.length != draftIds.toSet().length) {
      setState(() => _error = '存在重复的 Modal Token ID');
      return;
    }
    if (_workers < 1 || _workers > 10) {
      setState(() => _error = '并行数必须在 1-10 之间');
      return;
    }
    if (_perTokenWorkers < 0 || _perTokenWorkers > 10) {
      setState(() => _error = '单令牌并发上限必须在 0-10 之间');
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
              tokens: _tokens,
              tokenStrategy: _tokenStrategy,
              perTokenWorkers: _perTokenWorkers,
              hfToken: _hfToken.text,
              hasHfToken: _hasHfToken,
              defaultGpu: _gpu,
              defaultModel: 'chickenrice',
              repoBranch: _branch,
              defaultFormats: const ['srt'],
              maxWorkers: _workers,
            ),
          );
      setState(() => _applyConfig(value));
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
                scrollController: _scrollController,
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
      controller: _scrollController,
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
        _fieldLabel(
          'MODAL 令牌',
          _tokens.isEmpty
              ? '启用时至少配置一个 Modal 账号令牌'
              : '已配置 ${_tokens.length} 个 · 上限 ${ModalTranscriptionConfig.maxTokenCount} 个',
        ),
        _buildTokenList(colors),
        const SizedBox(height: 10),
        _buildAddTokenButton(colors),
        const SizedBox(height: 18),
        _fieldLabel('HF_TOKEN', _hasHfToken ? '已配置 · 留空则保留' : '可选'),
        _secretField(
          _hfToken,
          hint: _hasHfToken ? '输入新的 HF Token' : '可选 Hugging Face Token',
          visible: _showHfToken,
          onToggle: () => setState(() => _showHfToken = !_showHfToken),
        ),
        const SizedBox(height: 18),
        _fieldLabel('令牌策略', '多个令牌同时可用时的任务分配方式'),
        _dropdown(
          value: _tokenStrategy,
          values: ModalTranscriptionConfig.tokenStrategies,
          icon: Icons.shuffle_outlined,
          onChanged: (value) => setState(() => _tokenStrategy = value),
          labelBuilder: (value) => _strategyLabels[value] ?? value,
        ),
        const SizedBox(height: 14),
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
        _buildWorkersSlider(colors),
        const SizedBox(height: 14),
        _fieldLabel('单令牌并发上限', '范围 0-10，0 表示跟随最大并行数'),
        _buildPerTokenWorkersSlider(colors),
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
                  '令牌列表按完整目标列表提交：删除后保存即移除对应账号。新增令牌必须同时填写 Token ID 与 Secret，编辑已有令牌时留空凭据保持原值。仅支持 SRT 字幕格式。',
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

  Widget _buildTokenList(AppColors colors) {
    if (_tokens.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: colors.cardBorder),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          '暂无令牌，点击下方“添加令牌”配置第一个 Modal 账号。',
          style: TextStyle(color: colors.muted, fontSize: 12, height: 1.5),
        ),
      );
    }
    return Container(
      decoration: settingsCardDecoration(context),
      child: ClipRRect(
        // 外层统一裁剪：左滑操作磁贴为直角，靠分组卡圆角收边。
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            for (var i = 0; i < _tokens.length; i++) ...[
              if (i > 0) Divider(height: 1, color: colors.divider),
              _buildTokenRow(colors, i),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTokenRow(AppColors colors, int index) {
    final token = _tokens[index];
    final display = token.isExisting
        ? (token.tokenIdMasked.isEmpty ? '已配置' : token.tokenIdMasked)
        : '新令牌 · 保存后生效';
    return SwipeActionCell(
      group: _openSwipe,
      cellKey: index,
      enabled: true,
      actions: [
        SwipeActionData(
          icon: Icons.edit_outlined,
          label: '编辑',
          color: colors.accent,
          onPressed: () => _editToken(index: index),
        ),
        SwipeActionData(
          icon: Icons.delete_outline,
          label: '删除',
          color: colors.danger,
          onPressed: () => _removeToken(index),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.vpn_key_outlined,
                color: colors.accent,
                size: 17,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    token.name.isEmpty ? '令牌 ${index + 1}' : token.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.text,
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    display,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.mono(context, size: 11, color: colors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddTokenButton(AppColors colors) {
    final reached = _tokens.length >= ModalTranscriptionConfig.maxTokenCount;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: reached ? null : () => _editToken(),
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.text,
          side: BorderSide(color: colors.cardBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        icon: Icon(Icons.add_circle_outline, size: 18, color: colors.muted),
        label: Text(
          reached ? '最多 ${ModalTranscriptionConfig.maxTokenCount} 个令牌' : '添加令牌',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildWorkersSlider(AppColors colors) {
    return Container(
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
    );
  }

  Widget _buildPerTokenWorkersSlider(AppColors colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      decoration: settingsCardDecoration(context),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '每令牌同时任务数',
                  style: TextStyle(
                    color: colors.text,
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _perTokenWorkers == 0 ? '跟随最大并行数' : '$_perTokenWorkers',
                style: AppText.mono(context, size: 14, color: colors.text),
              ),
            ],
          ),
          HapticSlider(
            value: _perTokenWorkers.toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            label: '$_perTokenWorkers',
            onChanged: (value) {
              setState(() {
                _perTokenWorkers = value.round();
                _error = null;
              });
            },
          ),
        ],
      ),
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
                prefixIcon: const Icon(Icons.key_outlined),
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

/// 令牌编辑底部弹窗：新增时强制填写凭据，编辑时留空保持原值。
class _TokenEditorSheet extends StatefulWidget {
  const _TokenEditorSheet({required this.initial, required this.otherTokenIds});

  final ModalTranscriptionToken initial;
  final List<String> otherTokenIds;

  @override
  State<_TokenEditorSheet> createState() => _TokenEditorSheetState();
}

class _TokenEditorSheetState extends State<_TokenEditorSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial.name,
  );
  late final TextEditingController _tokenId = TextEditingController(
    text: widget.initial.tokenId,
  );
  late final TextEditingController _tokenSecret = TextEditingController(
    text: widget.initial.tokenSecret,
  );

  bool _showTokenId = false;
  bool _showTokenSecret = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _tokenId.dispose();
    _tokenSecret.dispose();
    super.dispose();
  }

  void _submit() {
    final isEdit = widget.initial.isExisting;
    final tokenId = _tokenId.text.trim();
    final tokenSecret = _tokenSecret.text.trim();
    if (!isEdit && (tokenId.isEmpty || tokenSecret.isEmpty)) {
      setState(() => _error = '新增令牌必须同时填写 Token ID 和 Token Secret');
      return;
    }
    if (tokenId.isNotEmpty && widget.otherTokenIds.contains(tokenId)) {
      setState(() => _error = '已存在相同 Token ID 的令牌');
      return;
    }
    Navigator.of(context).pop(
      ModalTranscriptionToken(
        id: widget.initial.id,
        name: _name.text.trim(),
        tokenIdMasked: widget.initial.tokenIdMasked,
        tokenId: tokenId,
        tokenSecret: tokenSecret,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final isEdit = widget.initial.isExisting;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        4,
        22,
        MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEdit ? '编辑令牌' : '添加令牌',
              style: AppText.sectionTitle(context),
            ),
            const SizedBox(height: 4),
            Text(
              isEdit
                  ? '留空的凭据保持服务端原值不变。'
                  : '填写 Modal 账号的 Token ID 与 Token Secret。',
              style: AppText.meta(context),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              maxLength: 32,
              decoration: settingsInputDecoration(
                context,
                labelText: '备注（可选）',
                hintText: '如：主账号',
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 10),
            _credentialField(
              controller: _tokenId,
              label: 'Token ID',
              hint: isEdit ? '已配置，留空则不修改' : '输入 Modal Token ID',
              visible: _showTokenId,
              onToggle: () => setState(() => _showTokenId = !_showTokenId),
            ),
            const SizedBox(height: 10),
            _credentialField(
              controller: _tokenSecret,
              label: 'Token Secret',
              hint: isEdit ? '已配置，留空则不修改' : '输入 Modal Token Secret',
              visible: _showTokenSecret,
              onToggle: () =>
                  setState(() => _showTokenSecret = !_showTokenSecret),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: colors.danger, fontSize: 12),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.muted,
                      side: BorderSide(color: colors.cardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.text,
                      foregroundColor: colors.bg,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('确定'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _credentialField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool visible,
    required VoidCallback onToggle,
  }) {
    final colors = appColors(context);
    return TextField(
      controller: controller,
      obscureText: !visible,
      autocorrect: false,
      enableSuggestions: false,
      decoration: settingsInputDecoration(
        context,
        labelText: label,
        hintText: hint,
        prefixIcon: const Icon(Icons.key_outlined),
        suffixIcon: IconButton(
          icon: Icon(
            visible ? Icons.visibility_off : Icons.visibility,
            size: 18,
            color: colors.muted,
          ),
          onPressed: onToggle,
        ),
      ),
      style: TextStyle(
        color: colors.text,
        fontFamily: 'monospace',
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
