import 'package:flutter/material.dart';

import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import 'security_policy.dart';

/// 应用内 6 位数字密码宫格键盘，不唤起系统输入法。
class SecurityPinPad extends StatefulWidget {
  const SecurityPinPad({
    super.key,
    required this.onCompleted,
    this.busy = false,
    this.submitLabel = '确认',
  });

  final ValueChanged<String> onCompleted;
  final bool busy;
  final String submitLabel;

  @override
  State<SecurityPinPad> createState() => _SecurityPinPadState();
}

class _SecurityPinPadState extends State<SecurityPinPad> {
  String _value = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PinDots(value: _value),
        const SizedBox(height: 8),
        Text('请输入 6 位数字', style: AppText.meta(context)),
        const SizedBox(height: 14),
        for (final row in _pinRows)
          Row(
            children: [
              for (final digit in row) _digitButton(context, digit),
            ],
          ),
        Row(
          children: [
            SizedBox(
              width: 72,
              height: 54,
              child: IconButton(
                onPressed: widget.busy || _value.isEmpty ? null : _delete,
                tooltip: '删除',
                icon: const Icon(Icons.backspace_outlined),
              ),
            ),
            _digitButton(context, '0'),
            SizedBox(
              width: 72,
              height: 54,
              child: IconButton(
                onPressed: widget.busy || _value.isEmpty ? null : _clear,
                tooltip: '清空',
                icon: const Icon(Icons.clear),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: widget.busy || !isValidSecurityPin(_value)
                ? null
                : () => widget.onCompleted(_value),
            icon: const Icon(Icons.lock_open_outlined),
            label: Text(widget.busy ? '验证中...' : widget.submitLabel),
          ),
        ),
      ],
    );
  }

  Widget _digitButton(BuildContext context, String digit) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: SizedBox(
          height: 54,
          child: OutlinedButton(
            onPressed: widget.busy ? null : () => _append(digit),
            child: Text(digit, style: AppText.sectionTitle(context)),
          ),
        ),
      ),
    );
  }

  void _append(String digit) {
    if (_value.length >= securityPinMaxLength) return;
    AppHaptics.selection();
    setState(() => _value += digit);
  }

  void _delete() {
    if (_value.isEmpty) return;
    AppHaptics.selection();
    setState(() => _value = _value.substring(0, _value.length - 1));
  }

  void _clear() {
    if (_value.isEmpty) return;
    AppHaptics.light();
    setState(() => _value = '');
  }
}

const _pinRows = <List<String>>[
  ['1', '2', '3'],
  ['4', '5', '6'],
  ['7', '8', '9'],
];

class _PinDots extends StatelessWidget {
  const _PinDots({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < securityPinMaxLength; index++)
          Container(
            width: 13,
            height: 13,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: index < value.length ? colors.accent : colors.surfaceAlt,
              shape: BoxShape.circle,
              border: Border.all(color: colors.cardBorder),
            ),
          ),
      ],
    );
  }
}
