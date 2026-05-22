import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class FanartGallery extends StatefulWidget {
  const FanartGallery({super.key, required this.urls, this.initialIndex = 0});
  final List<String> urls;
  final int initialIndex;

  @override
  State<FanartGallery> createState() => _FanartGalleryState();
}

class _FanartGalleryState extends State<FanartGallery> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.urls[i],
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '${_index + 1} / ${widget.urls.length}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
