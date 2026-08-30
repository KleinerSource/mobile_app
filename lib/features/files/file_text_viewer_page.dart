import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glow_background.dart';
import '../settings/settings_common.dart';

/// 文件管理器文本预览页。
class FileTextViewerPage extends StatefulWidget {
  const FileTextViewerPage({
    super.key,
    required this.title,
    required this.text,
    this.onSave,
  });

  final String title;
  final String text;

  /// 保存编辑器内容。未提供时保持只读查看器兼容行为。
  final Future<void> Function(String text)? onSave;

  @override
  State<FileTextViewerPage> createState() => _FileTextViewerPageState();
}

class _FileTextViewerPageState extends State<FileTextViewerPage> {
  late final TextEditingController _controller;
  late final FocusNode _editorFocusNode;
  late final ScrollController _editorScrollController;
  late final ScrollController _lineNumberScrollController;
  late String _savedText;
  bool _editing = false;
  bool _dirty = false;
  bool _saving = false;
  bool _confirmingLeave = false;

  AppL10n get _l10n => AppL10n.of(context);

  @override
  void initState() {
    super.initState();
    _savedText = widget.text;
    _controller = TextEditingController(text: widget.text)
      ..addListener(_handleTextChanged);
    _editorFocusNode = FocusNode();
    _editorScrollController = ScrollController()..addListener(_syncLineNumbers);
    _lineNumberScrollController = ScrollController();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleTextChanged)
      ..dispose();
    _editorFocusNode.dispose();
    _editorScrollController
      ..removeListener(_syncLineNumbers)
      ..dispose();
    _lineNumberScrollController.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final dirty = _controller.text != _savedText;
    if (dirty == _dirty || !mounted) return;
    setState(() => _dirty = dirty);
  }

  void _syncLineNumbers() {
    if (!_lineNumberScrollController.hasClients ||
        !_editorScrollController.hasClients) {
      return;
    }
    final target = _editorScrollController.offset
        .clamp(0.0, _lineNumberScrollController.position.maxScrollExtent)
        .toDouble();
    if ((_lineNumberScrollController.offset - target).abs() > 0.5) {
      _lineNumberScrollController.jumpTo(target);
    }
  }

  void _startEditing() {
    if (widget.onSave == null || _editing) return;
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _editorFocusNode.requestFocus();
    });
  }

  Future<void> _save({bool leaveAfterSave = false}) async {
    final onSave = widget.onSave;
    if (onSave == null || _saving) return;

    setState(() => _saving = true);
    final text = _controller.text;
    try {
      await onSave(text);
      if (!mounted) return;
      setState(() {
        _savedText = text;
        _dirty = false;
        _saving = false;
      });
      if (leaveAfterSave) {
        Navigator.of(context).pop();
      } else {
        _showMessage(_l10n.fileTextSaveSuccess);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(_l10n.fileTextSaveFailed(error.toString()));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmLeave() async {
    if (!_dirty || _confirmingLeave || _saving || !mounted) return;
    _confirmingLeave = true;
    final action = await showDialog<_LeaveAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_l10n.fileTextUnsavedTitle),
        content: Text(_l10n.fileTextUnsavedMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(_l10n.cancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_LeaveAction.discard),
            child: Text(_l10n.fileTextDiscard),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_LeaveAction.saveAndLeave),
            child: Text(_l10n.fileTextSaveAndLeave),
          ),
        ],
      ),
    );
    _confirmingLeave = false;
    if (!mounted) return;
    switch (action) {
      case _LeaveAction.discard:
        setState(() => _dirty = false);
        Navigator.of(context).pop();
      case _LeaveAction.saveAndLeave:
        await _save(leaveAfterSave: true);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final canEdit = widget.onSave != null;
    return PopScope<void>(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmLeave());
      },
      child: Scaffold(
        backgroundColor: c.bg,
        body: GlowBackground(
          child: SafeArea(
            child: SettingsFixedHeaderLayout(
              header: _buildHeader(context, canEdit),
              body: _editing ? _buildEditor(context) : _buildReadOnly(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool canEdit) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: SizedBox(
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _handleBackPressed,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: 56, right: canEdit ? 96 : 56),
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppText.pageTitle(context),
                ),
              ),
              if (canEdit)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _saving
                        ? null
                        : (_editing ? _save : _startEditing),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _editing
                                ? Icons.save_outlined
                                : Icons.edit_outlined,
                          ),
                    label: Text(
                      _saving
                          ? _l10n.fileTextSaving
                          : _editing
                          ? _l10n.fileTextSave
                          : _l10n.fileTextEdit,
                    ),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleBackPressed() {
    if (_dirty) {
      unawaited(_confirmLeave());
      return;
    }
    unawaited(Navigator.of(context).maybePop());
  }

  Widget _buildReadOnly(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Scrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
          child: SelectableText(
            widget.text,
            textAlign: TextAlign.left,
            style: _editorTextStyle,
          ),
        ),
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    final c = appColors(context);
    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.cardBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 48,
                  color: c.surface.withValues(alpha: 0.72),
                  alignment: Alignment.topCenter,
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, _) => SingleChildScrollView(
                      controller: _lineNumberScrollController,
                      physics: const NeverScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6, 14, 8, 14),
                        child: Text(
                          _lineNumbers(value.text),
                          textAlign: TextAlign.right,
                          style: _editorTextStyle.copyWith(color: c.muted),
                        ),
                      ),
                    ),
                  ),
                ),
                VerticalDivider(width: 1, thickness: 1, color: c.divider),
                Expanded(
                  child: Scrollbar(
                    controller: _editorScrollController,
                    child: TextField(
                      controller: _controller,
                      focusNode: _editorFocusNode,
                      scrollController: _editorScrollController,
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      readOnly: _saving,
                      autocorrect: false,
                      enableSuggestions: false,
                      keyboardType: TextInputType.multiline,
                      textAlignVertical: TextAlignVertical.top,
                      style: _editorTextStyle,
                      cursorColor: c.accent,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.fromLTRB(14, 14, 16, 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _lineNumbers(String text) {
    final lineCount = text.split('\n').length;
    return List<String>.generate(
      lineCount == 0 ? 1 : lineCount,
      (index) => '${index + 1}',
    ).join('\n');
  }

  static const TextStyle _editorTextStyle = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13,
    height: 1.45,
  );
}

enum _LeaveAction { discard, saveAndLeave }
