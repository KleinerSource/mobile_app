import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/glow_background.dart';
import 'omm_admin_repository.dart';

/// 管理表单始终属于打开时的服务器，切换连接时连同确认弹窗一起关闭。
class OmmAdminScope extends ConsumerStatefulWidget {
  const OmmAdminScope({super.key, required this.builder});
  final Widget Function(OmmAdminRepository repository) builder;
  @override
  ConsumerState<OmmAdminScope> createState() => _OmmAdminScopeState();
}

class _OmmAdminScopeState extends ConsumerState<OmmAdminScope> {
  late final OmmAdminRepository _repository;
  bool _closed = false;
  @override
  void initState() {
    super.initState();
    _repository = ref.read(ommAdminRepositoryProvider);
    ref.listenManual(ommAdminRepositoryProvider, (_, next) {
      if (!identical(next, _repository)) _close();
    }, onError: (_, __) => _close());
  }

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      navigator.popUntil((r) => r == route || r.isFirst);
      if (route?.isCurrent == true && route?.isFirst == false) navigator.pop();
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) =>
      _closed ? const SizedBox.shrink() : widget.builder(_repository);
}

class OmmAdminScaffold extends StatelessWidget {
  const OmmAdminScaffold({super.key, required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: appColors(context).bg,
    body: GlowBackground(
      child: SafeArea(
        bottom: false,
        child: SettingsFixedHeaderLayout(
          header: SettingsSubPageHeader(
            eyebrow: AppL10n.of(context).settingsServerSettings,
            title: title,
          ),
          body: child,
        ),
      ),
    ),
  );
}

class OmmInfoRow extends StatelessWidget {
  const OmmInfoRow(this.label, this.value, {super.key});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.eyebrow(context)),
        const SizedBox(height: 3),
        SelectableText(
          value.isEmpty ? '—' : value,
          style: AppText.body(context),
        ),
      ],
    ),
  );
}

Future<bool> confirmOmmAction(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppL10n.of(ctx).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppL10n.of(ctx).confirm),
          ),
        ],
      ),
    ) ==
    true;
