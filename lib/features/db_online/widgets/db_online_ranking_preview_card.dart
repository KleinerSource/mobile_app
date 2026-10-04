import 'package:flutter/material.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/shared/poster.dart';

/// 榜单列表模式的预览条目：左侧竖版封面，右侧预览图横向滑动切换，
/// 角标叠加在预览图左下角，底部显示标题（可带前缀指示器）与元信息。
///
/// 图片地址与角标由 [DbOnlineMovieCard] 解析后传入，这里只负责布局与
/// 翻页交互；无预览图时右侧回退为大封面。
class DbOnlineRankingPreviewCard extends StatefulWidget {
  const DbOnlineRankingPreviewCard({
    super.key,
    required this.title,
    required this.coverUrl,
    required this.previewUrls,
    this.code,
    this.fallbackPreviewUrl,
    required this.meta,
    this.badges = const <Widget>[],
    this.titleLeading,
    this.privacyId,
    this.onTap,
  });

  final String title;

  /// 竖版封面（thumb 优先，与竖版网格卡片一致）。
  final String? coverUrl;

  /// 预览图大图地址，按顺序横向翻页展示。
  final List<String> previewUrls;
  final String? code;

  /// 无预览图时右侧展示的回退图（大封面）。
  final String? fallbackPreviewUrl;
  final String meta;

  /// 叠加在预览图左下角的角标组。
  final List<Widget> badges;

  /// 标题前的小指示器（订阅已完成绿点等）。
  final Widget? titleLeading;

  final Object? privacyId;
  final VoidCallback? onTap;

  @override
  State<DbOnlineRankingPreviewCard> createState() =>
      _DbOnlineRankingPreviewCardState();
}

class _DbOnlineRankingPreviewCardState extends State<DbOnlineRankingPreviewCard> {
  /// 封面固定宽度，2:3 比例推算高度；右侧预览区与封面等高。
  static const _coverWidth = 92.0;
  static const _coverHeight = _coverWidth * 1.5;
  static const _gap = 10.0;
  static const _radius = 10.0;

  late final PageController _pageController = PageController();
  int _pageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(_radius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: _coverHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: _coverWidth,
                    child: _mask(
                      child: Poster(
                        url: widget.coverUrl,
                        title: widget.title,
                        radius: _radius,
                      ),
                    ),
                  ),
                  const SizedBox(width: _gap),
                  Expanded(child: _buildPreviewArea()),
                ],
              ),
            ),
            const SizedBox(height: 9),
            _buildTitle(context, colors),
            const SizedBox(height: 3),
            _privacyText(
              value: widget.meta,
              style: AppText.meta(context).copyWith(color: colors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mask({required Widget child}) {
    final privacyId = widget.privacyId;
    if (privacyId == null) return child;
    return PrivacyMask(movieId: privacyId, radius: _radius, child: child);
  }

  Widget _buildPreviewArea() {
    final urls = widget.previewUrls;
    final preview = urls.isEmpty
        ? Poster(
            url: widget.fallbackPreviewUrl,
            title: widget.title,
            radius: _radius,
          )
        : PageView.builder(
            controller: _pageController,
            itemCount: urls.length,
            onPageChanged: (index) => setState(() => _pageIndex = index),
            itemBuilder: (context, index) => Poster(
              url: urls[index],
              title: widget.title,
              radius: 0,
            ),
          );
    return _mask(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            preview,
            // 角标叠加在预览图左下角，右侧预留页码指示器的空间。
            if (widget.badges.isNotEmpty)
              Positioned(
                left: 6,
                right: 6,
                bottom: 6,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: urls.length > 1 ? 46 : 0,
                    ),
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: widget.badges,
                    ),
                  ),
                ),
              ),
            if (urls.length > 1)
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_pageIndex + 1}/${urls.length}',
                    strutStyle: const StrutStyle(
                      fontSize: 10,
                      height: 1.1,
                      forceStrutHeight: true,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context, AppColors colors) {
    final code = widget.code?.trim();
    final displayTitle = widget.title.trim();
    final text = code?.isNotEmpty == true
        ? '[${code!}] $displayTitle'
        : displayTitle;
    final titleText = _privacyText(
      value: text,
      style: TextStyle(
        color: colors.text,
        fontFamily: 'Inter',
        fontWeight: FontWeight.w700,
        fontSize: 14,
        height: 1.2,
      ),
      maxLines: 2,
    );
    final leading = widget.titleLeading;
    if (leading == null) return titleText;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 与 14/1.2 行高的首行文本光学居中对齐。
        Padding(padding: const EdgeInsets.only(top: 2.5, right: 5), child: leading),
        Expanded(child: titleText),
      ],
    );
  }

  Widget _privacyText({
    required String value,
    required TextStyle style,
    int maxLines = 1,
  }) {
    final privacyId = widget.privacyId;
    if (privacyId == null) {
      return Text(
        value,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return PrivacyText(
      movieId: privacyId,
      text: value,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}
