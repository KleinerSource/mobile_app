import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/shake_error_text.dart' show shakeErrorDuration;
import 'security_policy.dart';

/// 应用内 6 位数字密码宫格键盘，不唤起系统输入法，输满后自动提交。
class SecurityPinPad extends StatefulWidget {
  const SecurityPinPad({
    super.key,
    required this.onCompleted,
    this.busy = false,
    this.showError = false,
  });

  final Future<void> Function(String) onCompleted;
  final bool busy;
  final bool showError;

  @override
  State<SecurityPinPad> createState() => _SecurityPinPadState();
}

class _SecurityPinPadState extends State<SecurityPinPad>
    with SingleTickerProviderStateMixin {
  String _value = '';
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: shakeErrorDuration,
    );
    if (widget.showError) _shakeController.forward();
  }

  @override
  void didUpdateWidget(covariant SecurityPinPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showError && !oldWidget.showError) {
      _shakeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final progress = _shakeController.value;
        final offset = math.sin(progress * math.pi * 12) * (1 - progress) * 10;
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PinDots(value: _value),
          const SizedBox(height: 16),
          for (final row in _pinRows)
            Row(
              children: [for (final digit in row) _digitButton(context, digit)],
            ),
          Row(
            children: [
              SizedBox(
                width: 72,
                height: 54,
                child: IconButton(
                  onPressed: widget.busy || _value.isEmpty ? null : _clear,
                  tooltip: AppL10n.of(context).commonClearInput,
                  icon: const Icon(Icons.clear),
                ),
              ),
              _digitButton(context, '0'),
              SizedBox(
                width: 72,
                height: 54,
                child: IconButton(
                  onPressed: widget.busy || _value.isEmpty ? null : _delete,
                  tooltip: AppL10n.of(context).delete,
                  icon: const Icon(Icons.backspace_outlined),
                ),
              ),
            ],
          ),
        ],
      ),
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
    final nextValue = '$_value$digit';
    setState(() => _value = nextValue);
    if (nextValue.length == securityPinMaxLength) {
      unawaited(_submit(nextValue));
    }
  }

  Future<void> _submit(String pin) async {
    AppHaptics.medium();
    try {
      await widget.onCompleted(pin);
    } finally {
      if (mounted) setState(() => _value = '');
    }
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
