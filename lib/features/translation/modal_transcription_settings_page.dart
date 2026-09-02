import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/modal_transcription_config.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glass.dart';
import '../../shared/glow_background.dart';
import '../../shared/sheet_controls.dart';
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
  /// 令牌策略的稳定取值；显示文案在 _strategyLabel 里本地化。
  String _strategyLabel(AppL10n l, String value) {
    return switch (value) {
      'round_robin' => l.transcriptionStrategyRoundRobin,
      'fill_first' => l.transcriptionStrategyFillFirst,
      _ => value,
    };
  }

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

    final result = await showGlassSheet<ModalTranscriptionToken>(
      context: context,
      isScrollControlled: true,
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
    final l = AppL10n.of(context);
    if (_enabled && _tokens.isEmpty) {
      setState(() => _error = l.transcriptionNeedToken);
      return;
    }
    final incomplete = _tokens.any(
      (token) =>
          !token.isExisting &&
          (token.tokenId.trim().isEmpty || token.tokenSecret.trim().isEmpty),
    );
    if (incomplete) {
      setState(() => _error = l.transcriptionTokenIncomplete);
      return;
    }
    final draftIds = [
      for (final token in _tokens)
        if (token.tokenId.trim().isNotEmpty) token.tokenId.trim(),
    ];
    if (draftIds.length != draftIds.toSet().length) {
      setState(() => _error = l.transcriptionDuplicateTokenId);
      return;
    }
    if (_workers < 1 || _workers > 10) {
      setState(() => _error = l.transcriptionWorkersRange);
      return;
    }
    if (_perTokenWorkers < 0 || _perTokenWorkers > 10) {
      setState(() => _error = l.transcriptionPerTokenWorkersRange);
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
      messenger.showSnackBar(
        SnackBar(content: Text(l.transcriptionSaved)),
      );
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
                child: Text(
                  '${AppL10n.of(context).loadFailed}: $error',
                  style: AppText.body(context),
                ),
              ),
            ),
            data: (config) {
              _hydrate(config);
              return SettingsFixedHeaderLayout(
                scrollController: _scrollController,
                header: SettingsSubPageHeader(
                  eyebrow: AppL10n.of(context).settingsGroupSystem,
                  title: AppL10n.of(context).transcriptionTitle,
                  subtitle: AppL10n.of(context).transcriptionSubtitle,
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
    final l = AppL10n.of(context);
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
      children: [
        Container(
          decoration: settingsCardDecoration(context),
          child: SettingsTile(
            title: l.transcriptionEnable,
            subtitle: _enabled
                ? l.transcriptionEnabledSubtitle
                : l.transcriptionDisabledSubtitle,
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
          l.transcriptionTokensLabel,
          _tokens.isEmpty
              ? l.transcriptionTokensEmptyHint
              : l.transcriptionTokensCount(
                  _tokens.length,
                  ModalTranscriptionConfig.maxTokenCount,
                ),
        ),
        _buildTokenList(colors),
        const SizedBox(height: 10),
        _buildAddTokenButton(colors),
        const SizedBox(height: 18),
        _fieldLabel(
          'HF_TOKEN',
          _hasHfToken ? l.transcriptionConfiguredKeepHint : l.transcriptionHfTokenOptional,
        ),
        _secretField(
          _hfToken,
          hint: _hasHfToken
              ? l.transcriptionNewHfTokenHint
              : l.transcriptionHfTokenHint,
          visible: _showHfToken,
          onToggle: () => setState(() => _showHfToken = !_showHfToken),
        ),
        const SizedBox(height: 18),
        _fieldLabel(
          l.transcriptionTokenStrategyLabel,
          l.transcriptionTokenStrategyHelp,
        ),
        _dropdown(
          value: _tokenStrategy,
          values: ModalTranscriptionConfig.tokenStrategies,
          icon: Icons.shuffle_outlined,
          onChanged: (value) => setState(() => _tokenStrategy = value),
          labelBuilder: (value) => _strategyLabel(l, value),
        ),
        const SizedBox(height: 14),
        _fieldLabel(l.transcriptionGpuLabel, l.transcriptionGpuHelp),
        _dropdown(
          value: _gpu,
          values: _gpus,
          icon: Icons.memory_outlined,
          onChanged: (value) => setState(() => _gpu = value),
        ),
        const SizedBox(height: 14),
        _fieldLabel(
          l.transcriptionModelBranchLabel,
          l.transcriptionModelBranchHelp,
        ),
        _dropdown(
          value: _branch,
          values: _branches,
          icon: Icons.model_training_outlined,
          onChanged: (value) => setState(() => _branch = value),
          labelBuilder: (value) => 'ChickenRice $value',
        ),
        const SizedBox(height: 14),
        _fieldLabel(
          l.transcriptionMaxWorkersLabel,
          l.transcriptionMaxWorkersHelp,
        ),
        _buildWorkersSlider(colors),
        const SizedBox(height: 14),
        _fieldLabel(
          l.transcriptionPerTokenWorkersLabel,
          l.transcriptionPerTokenWorkersHelp,
        ),
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
                  l.transcriptionTokenListHint,
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
          label: l.transcriptionSaveButton,
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
          AppL10n.of(context).transcriptionNoTokensHint,
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
    final l = AppL10n.of(context);
    final token = _tokens[index];
    final display = token.isExisting
        ? (token.tokenIdMasked.isEmpty
              ? l.transcriptionTokenConfigured
              : token.tokenIdMasked)
        : l.transcriptionTokenDraft;
    return SwipeActionCell(
      group: _openSwipe,
      cellKey: index,
      enabled: true,
      actions: [
        SwipeActionData(
          icon: Icons.edit_outlined,
          label: l.edit,
          color: colors.accent,
          onPressed: () => _editToken(index: index),
        ),
        SwipeActionData(
          icon: Icons.delete_outline,
          label: l.delete,
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
                    token.name.isEmpty
                        ? AppL10n.of(
                            context,
                          ).transcriptionTokenNumber(index + 1)
                        : token.name,
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
          reached
              ? AppL10n.of(
                  context,
                ).transcriptionTokenLimit(ModalTranscriptionConfig.maxTokenCount)
              : AppL10n.of(context).transcriptionAddToken,
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
                  AppL10n.of(context).transcriptionWorkersSliderLabel,
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
                  AppL10n.of(context).transcriptionPerTokenSliderLabel,
                  style: TextStyle(
                    color: colors.text,
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _perTokenWorkers == 0
                    ? AppL10n.of(context).transcriptionFollowMaxWorkers
                    : '$_perTokenWorkers',
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
              textAlignVertical: TextAlignVertical.center,
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
    final l = AppL10n.of(context);
    final isEdit = widget.initial.isExisting;
    final tokenId = _tokenId.text.trim();
    final tokenSecret = _tokenSecret.text.trim();
    if (!isEdit && (tokenId.isEmpty || tokenSecret.isEmpty)) {
      setState(() => _error = l.transcriptionTokenIncomplete);
      return;
    }
    if (tokenId.isNotEmpty && widget.otherTokenIds.contains(tokenId)) {
      setState(() => _error = l.transcriptionTokenIdExists);
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
    final l = AppL10n.of(context);
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
            SheetHeader(
              icon: isEdit ? Icons.edit_outlined : Icons.key_outlined,
              title: isEdit
                  ? l.transcriptionEditTokenTitle
                  : l.transcriptionAddToken,
              subtitle: isEdit
                  ? l.transcriptionEditTokenSubtitle
                  : l.transcriptionAddTokenSubtitle,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              maxLength: 32,
              textAlignVertical: TextAlignVertical.center,
              decoration: settingsInputDecoration(
                context,
                labelText: l.transcriptionTokenNameLabel,
                hintText: l.transcriptionTokenNameHint,
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 10),
            _credentialField(
              controller: _tokenId,
              label: l.transcriptionTokenIdLabel,
              hint: isEdit
                  ? l.transcriptionCredentialKeepHint
                  : l.transcriptionTokenIdHint,
              visible: _showTokenId,
              onToggle: () => setState(() => _showTokenId = !_showTokenId),
            ),
            const SizedBox(height: 10),
            _credentialField(
              controller: _tokenSecret,
              label: l.transcriptionTokenSecretLabel,
              hint: isEdit
                  ? l.transcriptionCredentialKeepHint
                  : l.transcriptionTokenSecretHint,
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
                    style: sheetSecondaryButtonStyle(context),
                    child: Text(l.cancel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _submit,
                    style: sheetPrimaryButtonStyle(context),
                    child: Text(l.confirm),
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
      textAlignVertical: TextAlignVertical.center,
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
