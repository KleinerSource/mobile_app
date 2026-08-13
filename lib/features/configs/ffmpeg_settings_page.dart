import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/ffmpeg_config.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';
import '../settings/settings_common.dart';
import 'configs_providers.dart';

class FfmpegSettingsPage extends ConsumerStatefulWidget {
  const FfmpegSettingsPage({super.key});

  @override
  ConsumerState<FfmpegSettingsPage> createState() => _FfmpegSettingsPageState();
}

class _FfmpegSettingsPageState extends ConsumerState<FfmpegSettingsPage> {
  final _ffmpegPath = TextEditingController();
  final _ffprobePath = TextEditingController();
  bool _enabled = true;
  bool _fallback = true;
  String _hwAccel = 'amf';
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _ffmpegPath.dispose();
    _ffprobePath.dispose();
    super.dispose();
  }

  void _hydrate(FfmpegConfig cfg) {
    if (_loaded) return;
    _loaded = true;
    _ffmpegPath.text = cfg.ffmpegPath;
    _ffprobePath.text = cfg.ffprobePath;
    _hwAccel = cfg.hwAccel;
    _enabled = cfg.enabled;
    _fallback = cfg.hwFallback;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(configsRepositoryProvider).saveFfmpeg(
            FfmpegConfig(
              ffmpegPath: _ffmpegPath.text.trim(),
              ffprobePath: _ffprobePath.text.trim(),
              hwAccel: _hwAccel,
              enabled: _enabled,
              hwFallback: _fallback,
            ),
          );
      if (!mounted) return;
      ref.invalidate(ffmpegConfigProvider);
      AppHaptics.medium();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('FFmpeg 与硬解配置已保存')),
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
    final async = ref.watch(ffmpegConfigProvider);
    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text('加载失败: ${toApiException(error).message}'),
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
    return SettingsFixedHeaderLayout(
      header: const SettingsSubPageHeader(
        eyebrow: '工具',
        title: 'FFmpeg 与硬解',
        subtitle: '配置服务端转码、硬件解码和硬解失败回退策略。',
      ),
      body: ListView(
        primary: true,
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
        children: [
          _sectionLabel('硬件解码'),
              _switchCard(
                c,
                title: '启用硬件解码',
                subtitle: _enabled ? '转码时优先使用 GPU' : '当前强制使用 CPU 软解',
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: settingsInputDecoration(
                  context,
                  labelText: '硬件后端',
                  prefixIcon: const Icon(Icons.memory_outlined),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _hwAccel,
                    isExpanded: true,
                    items: [
                      for (final value in FfmpegConfig.supportedHardwareAccels)
                        DropdownMenuItem(
                          value: value,
                          child: Text(_hardwareLabel(value)),
                        ),
                    ],
                    onChanged: _enabled
                        ? (value) {
                            if (value != null && value != _hwAccel) {
                              AppHaptics.selection();
                              setState(() => _hwAccel = value);
                            }
                          }
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _switchCard(
                c,
                title: '硬解失败自动回退',
                subtitle: _fallback ? '失败时自动重启为 CPU 软解' : '失败时直接报告转码错误',
                value: _fallback,
                onChanged: _enabled
                    ? (value) => setState(() => _fallback = value)
                    : null,
              ),
              const SizedBox(height: 22),
              _sectionLabel('FFmpeg 路径'),
              _pathField(_ffmpegPath, 'ffmpeg 路径，留空使用系统 PATH'),
              const SizedBox(height: 12),
              _pathField(_ffprobePath, 'ffprobe 路径，留空使用系统 PATH'),
              if (_error != null) ...[
                const SizedBox(height: 14),
                _errorBox(c, _error!),
              ],
              const SizedBox(height: 28),
              SettingsSaveButton(
                onPressed: _save,
                saving: _saving,
              ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text.toUpperCase(), style: AppText.eyebrow(context)),
      );

  Widget _pathField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      decoration: settingsInputDecoration(
        context,
        hintText: hint,
        prefixIcon: const Icon(Icons.folder_open_outlined),
      ),
    );
  }

  Widget _switchCard(
    AppColors c, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
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
                Text(title,
                    style: TextStyle(
                        color: c.text, fontWeight: FontWeight.w700)),
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

  String _hardwareLabel(String value) => switch (value) {
        'none' => 'CPU 软解 / 不使用硬解',
        'amf' => 'AMD AMF',
        'nvenc' => 'NVIDIA NVENC',
        'qsv' => 'Intel Quick Sync',
        _ => value,
      };
}
