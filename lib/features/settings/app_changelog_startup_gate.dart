import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/platform/app_theme.dart';
import '../../core/update/build_changelog.dart';
import '../../core/update/update_repository.dart';
import '../../l10n/generated/app_localizations.dart';

/// 内嵌更新日志处理完毕（展示完成或无需展示）后置 true，
/// 在线更新检查（StartupUpdateGate）在此之后才允许启动，避免两个弹窗叠放。
final changelogGateReadyProvider = StateProvider<bool>((ref) => false);

/// 应用更新后首次启动时展示内嵌更新日志。
///
/// 日志内容与版本号在 CI 构建前由 tool/generate_build_changelog.dart 写入
/// [build_changelog.dart]，本地构建保持为空（不弹窗）。展示条件为
/// "已记录的旧版本 ≠ 当前构建版本"；全新安装（无记录）只静默记录当前版本。
class StartupChangelogGate extends ConsumerStatefulWidget {
  const StartupChangelogGate({
    super.key,
    required this.enabled,
    required this.onFinished,
    required this.child,
    this.version = kBuildChangelogVersion,
    this.notes = kBuildChangelogNotes,
    this.startDelay = const Duration(milliseconds: 400),
  });

  final bool enabled;
  final VoidCallback onFinished;
  final Widget child;

  /// 注入点：默认取构建期内嵌常量，测试可覆盖。
  final String version;
  final String notes;
  final Duration startDelay;

  @override
  ConsumerState<StartupChangelogGate> createState() =>
      _StartupChangelogGateState();
}

class _StartupChangelogGateState extends ConsumerState<StartupChangelogGate> {
  Timer? _startTimer;
  bool _consumed = false;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _schedule();
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StartupChangelogGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) _schedule();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _schedule() {
    if (_consumed) return;
    _consumed = true;
    _startTimer?.cancel();
    _startTimer = Timer(widget.startDelay, () {
      _startTimer = null;
      if (mounted && widget.enabled) unawaited(_run());
    });
  }

  Future<void> _run() async {
    final version = widget.version.trim();
    final notes = widget.notes.trim();
    // 本地构建（无内嵌日志）不弹窗，也不阻塞后续启动检查。
    if (version.isEmpty || notes.isEmpty) {
      widget.onFinished();
      return;
    }

    final repository = ref.read(updateSettingsRepositoryProvider);
    final last = repository.loadLastChangelogVersion();
    if (last == version) {
      widget.onFinished();
      return;
    }
    if (last == null) {
      // 全新安装（从未记录过版本）：静默记录，不弹窗。
      await _saveVersion(repository, version);
      widget.onFinished();
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BuildChangelogDialog(version: version, notes: notes),
    );
    await _saveVersion(repository, version);
    widget.onFinished();
  }

  Future<void> _saveVersion(
    UpdateSettingsRepository repository,
    String version,
  ) async {
    try {
      await repository.saveLastChangelogVersion(version);
    } catch (_) {
      // 记录失败时下次更新仍会弹一次，可接受。
    }
  }
}

/// 展示单个构建版本的净化后更新日志。
class BuildChangelogDialog extends StatelessWidget {
  const BuildChangelogDialog({
    super.key,
    required this.version,
    required this.notes,
  });

  final String version;
  final String notes;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final l = AppL10n.of(context);
    final maxContentHeight = MediaQuery.sizeOf(context).height * 0.55;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.new_releases_outlined, color: colors.accent),
          const SizedBox(width: 10),
          Expanded(child: Text(l.changelogDialogTitle)),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxContentHeight),
        child: Scrollbar(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.changelogVersionLabel(version),
                  style: AppText.sectionTitle(context),
                ),
                const SizedBox(height: 14),
                Text(
                  l.settingsUpdateNotesTitle,
                  style: AppText.body(
                    context,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                ..._buildNoteWidgets(context),
              ],
            ),
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.commonGotIt),
        ),
      ],
    );
  }

  List<Widget> _buildNoteWidgets(BuildContext context) {
    final widgets = <Widget>[];
    for (final rawLine in notes.split('\n')) {
      final line = rawLine.trimRight();
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 10));
        continue;
      }
      if (line.trimLeft().startsWith('- ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(line.trimLeft(), style: AppText.meta(context)),
          ),
        );
        continue;
      }
      widgets.add(Text(line, style: AppText.body(context)));
    }
    return widgets;
  }
}
