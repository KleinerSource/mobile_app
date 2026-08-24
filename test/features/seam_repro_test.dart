import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 高频噪点画板 · 用于让 1px 采样错位可被检测
class _NoisePainter extends CustomPainter {
  const _NoisePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final paint = Paint();
    const cell = 4.0;
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        final v = 40 + rnd.nextInt(200);
        paint.color = Color.fromARGB(255, v, v, v);
        canvas.drawRect(Offset(x, y) & const Size(cell, cell), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Future<void> _render(
  WidgetTester tester,
  GlobalKey key, {
  double heroHeight = 400,
  double dpr = 3.0,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);

  final noise = const CustomPaint(painter: _NoisePainter());

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: key,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ---- 氛围背景: blur50 + scale 1.35 ----
            Positioned.fill(
              child: ClipRect(
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                  child: Transform.scale(scale: 1.35, child: noise),
                ),
              ),
            ),
            // ---- 封面: ShaderMask 底部渐隐 ----
            Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: heroHeight,
                width: double.infinity,
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (b) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Colors.white, Colors.transparent],
                    stops: [0.0, 0.45, 1.0],
                  ).createShader(b),
                  child: noise,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

Future<Map<int, double>> _rows(GlobalKey key) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1.0);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = data!.buffer.asUint32List();
  final w = image.width, h = image.height;
  final rows = <int, double>{};
  for (var y = 0; y < h; y++) {
    var s = 0;
    var n = 0;
    for (var x = 8; x < w - 8; x += 4) {
      final p = bytes[y * w + x];
      s += ((p & 0xFF) + ((p >> 8) & 0xFF) + ((p >> 16) & 0xFF));
      n++;
    }
    rows[y] = s / n / 3;
  }
  return rows;
}

void _report(Map<int, double> rows, int from, int to) {
  // 与左右各2行的邻域差,找异常行
  final diffs = <int, double>{};
  for (var y = from + 2; y < to - 2; y++) {
    final near = (rows[y - 2]! + rows[y - 1]! + rows[y + 1]! + rows[y + 2]!) / 4;
    diffs[y] = (rows[y]! - near).abs();
  }
  final sorted = diffs.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  // ignore: avoid_print
  print('  top anomaly rows: ' +
      sorted.take(5).map((e) => 'y${e.key}=${e.value.toStringAsFixed(1)}').join(' '));
  final sb = StringBuffer();
  for (var y = from; y <= to; y++) {
    sb.write('${rows[y]!.toStringAsFixed(0)} ');
  }
  // ignore: avoid_print
  print('  rows[$from..$to]: $sb');
}

void main() {
  testWidgets('高频内容 · DPR3 · hero 400', (tester) async {
    final key = GlobalKey();
    await _render(tester, key);
    _report(await _rows(key), 300, 400);
  });

  testWidgets('高频内容 · DPR2.625 · hero 400.5', (tester) async {
    final key = GlobalKey();
    await _render(tester, key, heroHeight: 400.5, dpr: 2.625);
    _report(await _rows(key), 300, 400);
  });
}
