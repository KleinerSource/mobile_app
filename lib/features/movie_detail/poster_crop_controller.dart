import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/app_theme.dart';
import '../movies/movies_providers.dart';

/// 封面裁剪控制器 · 对齐 frontend_new PosterCropController.vue
///
/// 视觉:
/// - 横向 fanart 大图铺底
/// - 中央 7:10 (poster ratio) 高亮窗口框,左右两侧灰蒙版
/// - 拖动窗口左右调整 cropOffset 0-1
/// - 释放后调 previewPosterCrop 取后端预览图 (含水印),覆盖窗口内
class PosterCropController extends ConsumerStatefulWidget {
  const PosterCropController({
    super.key,
    required this.movieId,
    required this.fanartUrl,
    required this.cropOffset,
    required this.onChanged,
    this.subtitle = false,
    this.exsub = false,
    this.crack = false,
    this.uhd = false,
    this.enabled = true,
  });

  final int movieId;
  final String fanartUrl;
  final double cropOffset;
  final ValueChanged<double> onChanged;
  final bool subtitle;
  final bool exsub;
  final bool crack;
  final bool uhd;

  /// 未启用时只显示原 fanart,不渲染窗口/蒙版/拖拽。
  final bool enabled;

  @override
  ConsumerState<PosterCropController> createState() =>
      _PosterCropControllerState();
}

class _PosterCropControllerState extends ConsumerState<PosterCropController> {
  static const _posterRatio = 7 / 10;

  Uint8List? _previewBytes;
  bool _previewLoading = false;
  Timer? _debounce;

  // fanart 真实纵横比 (w/h) · 异步加载后填充
  double? _fanartAspect;
  ImageStream? _imgStream;
  late final ImageStreamListener _imgListener = ImageStreamListener(
    (info, _) {
      final ratio = info.image.width / info.image.height;
      if (mounted && _fanartAspect != ratio) {
        setState(() => _fanartAspect = ratio);
      }
    },
    onError: (_, __) {
      // 加载失败保留 fallback
    },
  );

  void _attachImageStream() {
    final url = widget.fanartUrl;
    final imgProvider = CachedNetworkImageProvider(url);
    final newStream = imgProvider.resolve(const ImageConfiguration());
    if (_imgStream?.key == newStream.key) return;
    _imgStream?.removeListener(_imgListener);
    _imgStream = newStream;
    _imgStream!.addListener(_imgListener);
  }

  @override
  void didUpdateWidget(covariant PosterCropController old) {
    super.didUpdateWidget(old);
    if (widget.fanartUrl != old.fanartUrl) {
      _fanartAspect = null;
      _attachImageStream();
    }
    final flagsChanged = widget.subtitle != old.subtitle ||
        widget.exsub != old.exsub ||
        widget.crack != old.crack ||
        widget.uhd != old.uhd ||
        widget.enabled != old.enabled;
    if (widget.cropOffset != old.cropOffset || flagsChanged) {
      if (widget.enabled) {
        _scheduleFetch();
      } else {
        // 禁用 → 清空预览
        setState(() => _previewBytes = null);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _attachImageStream();
    // 初次进入仅在启用时请求一次预览
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.enabled) _scheduleFetch();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _imgStream?.removeListener(_imgListener);
    super.dispose();
  }

  void _scheduleFetch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), _fetchPreview);
  }

  Future<void> _fetchPreview() async {
    if (!mounted) return;
    setState(() => _previewLoading = true);
    try {
      final bytes = await ref
          .read(moviesRepositoryProvider)
          .previewPosterCrop(
            widget.movieId,
            cropOffset: widget.cropOffset,
            subtitle: widget.subtitle,
            exsub: widget.exsub,
            crack: widget.crack,
            uhd: widget.uhd,
          );
      if (!mounted) return;
      setState(() => _previewBytes = Uint8List.fromList(bytes));
    } catch (_) {
      // 静默失败,允许用户继续拖
    } finally {
      if (mounted) setState(() => _previewLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return LayoutBuilder(builder: (ctx, cons) {
      // 用 fanart 真实比例计算 frame · 与 frontend_new 一致 (img width:100% + 真实高度)
      final aspect = _fanartAspect;
      // 未加载完成 → 16:9 占位 loading
      if (aspect == null) {
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: widget.fanartUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => ColoredBox(color: c.surfaceAlt),
                  errorWidget: (_, __, ___) =>
                      ColoredBox(color: c.surfaceAlt),
                ),
              ],
            ),
          ),
        );
      }
      final frameW = cons.maxWidth;
      final frameH = frameW / aspect;
      final winW = frameH * _posterRatio;
      final maxLeft = (frameW - winW).clamp(0, frameW);
      final winLeft = (maxLeft * widget.cropOffset.clamp(0.0, 1.0)).toDouble();

      // 未启用 → 只显示原 fanart + disabled 提示
      if (!widget.enabled) {
        return SizedBox(
          height: frameH,
          width: frameW,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: widget.fanartUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => ColoredBox(color: c.surfaceAlt),
                    errorWidget: (_, __, ___) =>
                        ColoredBox(color: c.surfaceAlt),
                  ),
                ),
                Positioned.fill(
                  child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.25)),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline,
                              color: Colors.white, size: 13),
                          SizedBox(width: 4),
                          Text(
                            '勾选上方快捷操作启用裁剪',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return SizedBox(
        height: frameH,
        width: frameW,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // ---------- fanart 满铺 ----------
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: widget.fanartUrl,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  placeholder: (_, __) => ColoredBox(color: c.surfaceAlt),
                  errorWidget: (_, __, ___) => ColoredBox(color: c.surfaceAlt),
                ),
              ),
              // ---------- 左右蒙版 ----------
              if (winLeft > 0)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  width: winLeft,
                  child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.55)),
                ),
              if (winLeft + winW < frameW)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: winLeft + winW,
                  right: 0,
                  child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.55)),
                ),
              // ---------- 窗口 (预览 + 边框 + 拖手) ----------
              Positioned(
                left: winLeft,
                top: 0,
                bottom: 0,
                width: winW,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (d) {
                    final next = (winLeft + d.delta.dx)
                        .clamp(0.0, maxLeft.toDouble());
                    final ratio = maxLeft == 0 ? 0.0 : next / maxLeft;
                    widget.onChanged(ratio);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: c.accent, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: c.accent.withValues(alpha: 0.4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // preview image 覆盖窗口内
                        if (_previewBytes != null && !_previewLoading)
                          Image.memory(
                            _previewBytes!,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                        // loading overlay
                        if (_previewLoading)
                          Container(
                            color: Colors.black.withValues(alpha: 0.3),
                            alignment: Alignment.center,
                            child: const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        // 左右拖手装饰
                        Positioned(
                          top: 0,
                          bottom: 0,
                          left: 0,
                          width: 4,
                          child: ColoredBox(color: c.accent),
                        ),
                        Positioned(
                          top: 0,
                          bottom: 0,
                          right: 0,
                          width: 4,
                          child: ColoredBox(color: c.accent),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // ---------- 提示 ----------
              Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swap_horiz,
                            color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          '左右拖动框选裁剪范围',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
