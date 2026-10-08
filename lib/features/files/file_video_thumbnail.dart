import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sources/files/file_entry.dart';
import 'file_entry_icons.dart';
import 'file_thumbnail_image.dart';
import 'file_video_thumbnail_providers.dart';
import 'file_video_thumbnail_service.dart';

class FileVideoThumbnail extends ConsumerStatefulWidget {
  const FileVideoThumbnail({
    super.key,
    required this.entry,
    required this.failures,
    required this.scrollController,
    this.enabled = true,
    this.refreshGeneration = 0,
  });
  final FileEntry entry;
  final Set<String> failures;
  final ScrollController scrollController;
  final bool enabled;
  final int refreshGeneration;

  @override
  ConsumerState<FileVideoThumbnail> createState() => _FileVideoThumbnailState();
}

class _FileVideoThumbnailState extends ConsumerState<FileVideoThumbnail>
    with WidgetsBindingObserver {
  Timer? _timer;
  FileVideoThumbnailRequest? _request;
  FileVideoThumbnailSource? _source;
  ImageProvider? _image;
  String? _key;
  int _generation = 0;
  bool _eligible = false;
  bool _foreground = true;
  bool _scheduled = false;
  late final ValueListenable<int> _cacheEpoch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    widget.scrollController.addListener(_onScroll);
    _cacheEpoch = ref.read(fileVideoThumbnailServiceProvider).cache.epoch;
    _cacheEpoch.addListener(_onCacheCleared);
  }

  void _onCacheCleared() {
    _cancel();
    _evict();
    widget.failures.remove(_key);
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant FileVideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshGeneration != widget.refreshGeneration) {
      // 刷新只重试未取得预览的条目，已显示的图片由文件版本变化来失效。
      _cancel();
    }
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
  }

  void _onScroll() {
    // 持续滚动时不开始昂贵的解码，停稳 250ms 后再检查。
    _timer?.cancel();
    _timer = null;
    _scheduleCheck();
  }

  void _scheduleCheck() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _check();
    });
  }

  bool get _visible {
    if (!_eligible || !_foreground || _source?.lease.isActive != true) {
      return false;
    }
    final box = context.findRenderObject();
    final scrollable = Scrollable.maybeOf(context);
    if (box is! RenderBox || !box.hasSize || scrollable == null) return false;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null || !scrollable.position.hasContentDimensions) {
      return false;
    }
    final top = viewport.getOffsetToReveal(box, 0).offset;
    final position = scrollable.position;
    return top + box.size.height > position.pixels &&
        top < position.pixels + position.viewportDimension;
  }

  void _check() {
    if (!_visible) {
      _cancel();
      return;
    }
    if (_image != null || _request != null || widget.failures.contains(_key)) {
      return;
    }
    _timer ??= Timer(const Duration(milliseconds: 250), () {
      _timer = null;
      if (mounted && _visible) _load();
    });
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
    _generation++;
    _request?.release();
    _request = null;
  }

  void _evict() {
    final image = _image;
    _image = null;
    if (image != null) unawaited(image.evict());
  }

  Future<void> _load() async {
    final source = _source!;
    final key = _key!;
    final generation = ++_generation;
    final request = ref
        .read(fileVideoThumbnailServiceProvider)
        .load(
          key: key,
          repository: source.repository,
          entry: widget.entry,
          lease: source.lease,
        );
    _request = request;
    final bytes = await request.bytes;
    if (!mounted || generation != _generation || !_visible) return;
    if (bytes == null || bytes.isEmpty) {
      widget.failures.add(key);
    } else {
      setState(
        () => _image = ResizeImage(
          MemoryImage(bytes),
          width:
              (fileEntryPreviewIconWidth *
                      MediaQuery.devicePixelRatioOf(context))
                  .ceil(),
          height:
              (fileEntryPreviewIconHeight *
                      MediaQuery.devicePixelRatioOf(context))
                  .ceil(),
          policy: ResizeImagePolicy.fit,
        ),
      );
    }
    request.release();
    _request = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _cancel();
    } else {
      _scheduleCheck();
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = ref
        .watch(
          fileVideoThumbnailSourceProvider(widget.entry.path.sourceId.value),
        )
        .asData
        ?.value;
    final source = available?.lease.isActive == true ? available : null;
    final key = source == null
        ? null
        : fileVideoThumbnailKey(source.identity, widget.entry);
    if (_key != key || !identical(_source, source)) {
      _cancel();
      _evict();
      _key = key;
      _source = source;
    }
    _eligible =
        widget.enabled &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    if (!_eligible) _cancel();
    _scheduleCheck();
    final placeholder = FileEntryIconAsset(
      assetPath: fileIconPlaceholderAssetFor(widget.entry),
      fit: BoxFit.cover,
    );
    return FileEntryMediaPreviewFrame(
      child: FileThumbnailImage(image: _image, placeholder: placeholder),
    );
  }

  @override
  void dispose() {
    _cacheEpoch.removeListener(_onCacheCleared);
    widget.scrollController.removeListener(_onScroll);
    WidgetsBinding.instance.removeObserver(this);
    _cancel();
    _evict();
    super.dispose();
  }
}
