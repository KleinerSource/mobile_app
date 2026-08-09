import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';
import '../settings/settings_common.dart';
import 'configs_providers.dart';

class VideoExtensionsPage extends ConsumerStatefulWidget {
  const VideoExtensionsPage({super.key});

  @override
  ConsumerState<VideoExtensionsPage> createState() =>
      _VideoExtensionsPageState();
}

class _VideoExtensionsPageState extends ConsumerState<VideoExtensionsPage> {
  final _input = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  String _normalize(String raw) {
    var s = raw.trim().toLowerCase();
    if (s.isEmpty) return '';
    if (!s.startsWith('.')) s = '.$s';
    return s;
  }

  Future<void> _add(List<String> current) async {
    final ext = _normalize(_input.text);
    if (ext.isEmpty) return;
    if (current.contains(ext)) {
      _input.clear();
      return;
    }
    final next = [...current, ext]..sort();
    await _persist(next);
    _input.clear();
  }

  Future<void> _remove(String ext, List<String> current) async {
    final next = current.where((e) => e != ext).toList();
    await _persist(next);
  }

  Future<void> _persist(List<String> next) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(configsRepositoryProvider).updateVideoExtensions(next);
      // ignore: unused_result
      ref.refresh(videoExtensionsProvider);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('保存失败: ${toApiException(e).message}')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final async = ref.watch(videoExtensionsProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SettingsSubPageHeader(
                eyebrow: '工具',
                title: '视频扩展名',
                subtitle: '配置媒体库扫描时识别的视频文件后缀',
              ),
              Expanded(
                child: async.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('加载失败: $e', style: AppText.body(context)),
                    ),
                  ),
                  data: (extensions) => _buildBody(c, extensions),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppColors c, List<String> extensions) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
      children: [
        // 添加输入
        Text('ADD', style: AppText.eyebrow(context)),
        const SizedBox(height: 8),
        Container(
          decoration: settingsCardDecoration(context),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _add(extensions),
                  decoration: settingsInputDecoration(
                    context,
                    hintText: 'mp4',
                    borderless: true,
                  ),
                  style: TextStyle(
                    color: c.text,
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilledButton(
                  onPressed: _busy ? null : () => _add(extensions),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.text,
                    foregroundColor: c.bg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(48, 44),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  child: const Icon(Icons.add, size: 18),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text('支持带点号或不带点号', style: AppText.meta(context)),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'CURRENT · ${extensions.length}',
                style: AppText.eyebrow(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (extensions.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: settingsCardDecoration(context),
            child: Center(
              child: Text('还没有配置扩展名', style: AppText.meta(context)),
            ),
          )
        else
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: extensions.map((ext) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: c.chipBg,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        ext,
                        style: TextStyle(
                          color: c.text,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 14, color: c.muted),
                      onPressed: _busy ? null : () => _remove(ext, extensions),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints.tightFor(width: 44, height: 44),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
