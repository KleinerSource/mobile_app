import 'package:flutter/material.dart';

import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';

/// 3×3 本地手势密码输入控件。
class SecurityPatternPad extends StatefulWidget {
  const SecurityPatternPad({
    super.key,
    required this.onCompleted,
    this.onPointAdded,
    this.enabled = true,
    this.size = 260,
  });

  final ValueChanged<List<int>> onCompleted;
  final ValueChanged<int>? onPointAdded;
  final bool enabled;
  final double size;

  @override
  State<SecurityPatternPad> createState() => _SecurityPatternPadState();
}

class _SecurityPatternPadState extends State<SecurityPatternPad> {
  final List<int> _selected = <int>[];
  Offset? _pointer;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: widget.enabled ? _start : null,
        onPanUpdate: widget.enabled ? _update : null,
        onPanEnd: widget.enabled ? (_) => _finish() : null,
        child: CustomPaint(
          painter: _PatternPainter(
            selected: _selected,
            pointer: _pointer,
            color: appColors(context).accent,
            mutedColor: appColors(context).muted2,
            borderColor: appColors(context).cardBorder,
          ),
        ),
      ),
    );
  }

  void _start(DragStartDetails details) {
    _selected.clear();
    _pointer = details.localPosition;
    _addPoint(details.localPosition);
    setState(() {});
  }

  void _update(DragUpdateDetails details) {
    _pointer = details.localPosition;
    _addPoint(details.localPosition);
    setState(() {});
  }

  void _finish() {
    if (_selected.isNotEmpty) {
      widget.onCompleted(List<int>.unmodifiable(_selected));
    }
    _pointer = null;
    setState(() {});
  }

  void _addPoint(Offset point) {
    final index = _hitTest(point);
    if (index == null || _selected.contains(index)) return;
    _selected.add(index);
    AppHaptics.selection();
    widget.onPointAdded?.call(index);
  }

  int? _hitTest(Offset point) {
    final cell = widget.size / 3;
    final radius = cell * 0.38;
    for (var index = 0; index < 9; index++) {
      final center = Offset(
        (index % 3 + 0.5) * cell,
        (index ~/ 3 + 0.5) * cell,
      );
      if ((point - center).distance <= radius) return index;
    }
    return null;
  }
}

class _PatternPainter extends CustomPainter {
  const _PatternPainter({
    required this.selected,
    required this.pointer,
    required this.color,
    required this.mutedColor,
    required this.borderColor,
  });

  final List<int> selected;
  final Offset? pointer;
  final Color color;
  final Color mutedColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 3;
    final centers = [
      for (var index = 0; index < 9; index++)
        Offset((index % 3 + 0.5) * cell, (index ~/ 3 + 0.5) * cell),
    ];

    if (selected.length > 1 || (selected.isNotEmpty && pointer != null)) {
      final linePaint = Paint()
        ..color = color.withValues(alpha: 0.62)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(centers[selected.first].dx, centers[selected.first].dy);
      for (final index in selected.skip(1)) {
        path.lineTo(centers[index].dx, centers[index].dy);
      }
      if (pointer != null && selected.isNotEmpty) {
        path.lineTo(pointer!.dx, pointer!.dy);
      }
      canvas.drawPath(path, linePaint);
    }

    for (var index = 0; index < centers.length; index++) {
      final selectedPoint = selected.contains(index);
      final center = centers[index];
      final outer = Paint()
        ..color = selectedPoint
            ? color.withValues(alpha: 0.20)
            : Colors.transparent
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, cell * 0.21, outer);

      final ring = Paint()
        ..color = selectedPoint ? color : borderColor.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, cell * 0.13, ring);

      final dot = Paint()
        ..color = selectedPoint ? color : mutedColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        center,
        selectedPoint ? cell * 0.075 : cell * 0.045,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) {
    return oldDelegate.selected != selected ||
        oldDelegate.pointer != pointer ||
        oldDelegate.color != color ||
        oldDelegate.mutedColor != mutedColor ||
        oldDelegate.borderColor != borderColor;
  }
}
