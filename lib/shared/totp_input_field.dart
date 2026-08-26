import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/platform/app_haptics.dart';
import '../core/platform/app_theme.dart';

/// TOTP 验证码长度（标准 6 位）。
const totpCodeLength = 6;

/// 6 位分段 TOTP 验证码输入框。
///
/// 用一个隐藏的 TextField 承载焦点与系统数字键盘（自带长按粘贴），6 个
/// 分格只做展示；[onChanged] 回调每次变化，输满 [totpCodeLength] 位时
/// 触发 [onCompleted]。
class TotpInputField extends StatefulWidget {
  const TotpInputField({
    super.key,
    required this.controller,
    required this.onCompleted,
    this.enabled = true,
    this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool autofocus;

  @override
  State<TotpInputField> createState() => _TotpInputFieldState();
}

class _TotpInputFieldState extends State<TotpInputField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleChanged);
  }

  @override
  void didUpdateWidget(covariant TotpInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_handleChanged);
      widget.controller.addListener(_handleChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleChanged);
    super.dispose();
  }

  void _handleChanged() {
    // 只保留数字，超长截断（粘贴完整验证码时常见）。
    final digits = widget.controller.text.replaceAll(RegExp(r'\D'), '');
    final value = digits.length > totpCodeLength
        ? digits.substring(0, totpCodeLength)
        : digits;
    if (value != widget.controller.text) {
      widget.controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
      return;
    }
    widget.onChanged?.call(value);
    if (value.length == totpCodeLength) {
      AppHaptics.medium();
      widget.onCompleted(value);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final digits = data?.text?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (!mounted || digits.isEmpty) return;
    final value = digits.length > totpCodeLength
        ? digits.substring(0, totpCodeLength)
        : digits;
    widget.controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    AppHaptics.selection();
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final value = widget.controller.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: widget.enabled
              ? () {
                  AppHaptics.selection();
                  _pasteFromClipboard();
                }
              : null,
          onLongPress: widget.enabled ? _pasteFromClipboard : null,
          child: Row(
            children: [
              for (var index = 0; index < totpCodeLength; index++) ...[
                if (index > 0) const SizedBox(width: 8),
                Expanded(
                  child: _TotpDigitBox(
                    character: index < value.length ? value[index] : null,
                    active: widget.enabled &&
                        index == value.length.clamp(0, totpCodeLength - 1),
                    colors: colors,
                  ),
                ),
              ],
            ],
          ),
        ),
        // 隐藏的真实输入框：承载焦点、系统数字键盘与系统粘贴菜单。
        SizedBox(
          height: 0,
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: widget.controller,
              enabled: widget.enabled,
              autofocus: widget.autofocus,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(totpCodeLength),
              ],
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 0.1, color: Colors.transparent),
            ),
          ),
        ),
      ],
    );
  }
}

class _TotpDigitBox extends StatelessWidget {
  const _TotpDigitBox({
    required this.character,
    required this.active,
    required this.colors,
  });

  final String? character;
  final bool active;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final hasValue = character != null;
    return AspectRatio(
      aspectRatio: 0.82,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: active
                ? colors.accent
                : hasValue
                ? colors.cardBorder
                : colors.cardBorder.withValues(alpha: 0.7),
            width: active ? 1.6 : 1,
          ),
        ),
        child: Text(
          character ?? '',
          style: AppText.pageTitle(context).copyWith(
            fontSize: 24,
            color: colors.text,
          ),
        ),
      ),
    );
  }
}
