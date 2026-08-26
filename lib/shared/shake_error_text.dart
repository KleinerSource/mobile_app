import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/platform/app_theme.dart';

/// 错误抖动的统一时长，文字提示与密码键盘共用。
const shakeErrorDuration = Duration(milliseconds: 500);

/// 红色错误提示文字，出现或内容变化时左右抖动以吸引注意。
/// 传入 [replayToken]（例如失败计数）可在连续相同错误时重复触发抖动。
class ShakeErrorText extends StatefulWidget {
  const ShakeErrorText(
    this.text, {
    super.key,
    this.textAlign,
    this.replayToken,
  });

  final String text;
  final TextAlign? textAlign;
  final Object? replayToken;

  @override
  State<ShakeErrorText> createState() => _ShakeErrorTextState();
}

class _ShakeErrorTextState extends State<ShakeErrorText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: shakeErrorDuration,
    );
    if (widget.text.isNotEmpty) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant ShakeErrorText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final replayed = widget.replayToken != oldWidget.replayToken ||
        (widget.text.isNotEmpty && widget.text != oldWidget.text);
    if (widget.text.isNotEmpty && replayed) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final offset = math.sin(progress * math.pi * 8) * (1 - progress) * 8;
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: Text(
        widget.text,
        textAlign: widget.textAlign,
        style: TextStyle(color: appColors(context).danger),
      ),
    );
  }
}
