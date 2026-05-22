import 'package:flutter/material.dart';

import '../../../../core/models/movie.dart';
import '../../../../core/ui/tokens.dart';

class PlotSection extends StatefulWidget {
  const PlotSection({super.key, required this.movie});
  final MovieDetail movie;

  @override
  State<PlotSection> createState() => _PlotSectionState();
}

class _PlotSectionState extends State<PlotSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = (widget.movie.plot != null && widget.movie.plot!.isNotEmpty)
        ? widget.movie.plot!
        : widget.movie.outline;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    final c = Theme.of(context).extension<AppColors>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.l, AppSpacing.s, AppSpacing.l, AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Heading('剧情简介', c),
          const SizedBox(height: AppSpacing.s),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topLeft,
            child: Text(
              text,
              maxLines: _expanded ? null : 4,
              overflow:
                  _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: c.text, height: 1.55),
            ),
          ),
          if (_shouldShowToggle(text))
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _expanded ? '收起' : '展开',
                style: TextStyle(color: c.brand, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  bool _shouldShowToggle(String text) {
    // Approximate: any text long enough to plausibly exceed 4 lines.
    // 50 chars/line × 4 lines is a rough threshold.
    return text.length > 200;
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, this.c);
  final String text;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w700, color: c.text),
    );
  }
}
