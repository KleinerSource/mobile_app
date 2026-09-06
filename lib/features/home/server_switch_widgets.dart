part of 'server_switch_transition.dart';

class _CircularRevealPainter extends CustomPainter {
  const _CircularRevealPainter({
    required this.color,
    required this.center,
    required this.radius,
  });

  final Color color;
  final Offset center;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CircularRevealPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.center != center ||
        oldDelegate.radius != radius;
  }
}

class _TransitionContent extends StatelessWidget {
  const _TransitionContent({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Column(
      key: ValueKey(title),
      children: [
        _TransitionIcon(icon: icon, colors: colors),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppText.pageTitle(context).copyWith(fontSize: 24),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppText.body(context).copyWith(color: colors.muted),
        ),
      ],
    );
  }
}

class _TransitionIcon extends StatelessWidget {
  const _TransitionIcon({required this.icon, required this.colors});

  final IconData icon;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.text,
          boxShadow: [
            BoxShadow(
              color: colors.text.withValues(alpha: 0.16),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [Icon(icon, color: colors.bg, size: 36)],
        ),
      ),
    );
  }
}
