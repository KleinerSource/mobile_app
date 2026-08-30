import 'package:flutter/material.dart';

import '../common/player_haptics.dart';

/// 播放器统一退出按钮 · 固定在左上角。
///
/// 加载中 / 报错等无控制栏状态必须复用本组件,
/// 保证退出入口在全流程中位置、样式与触感一致
/// (几何参数对齐 [VideoPlayerControls] 顶栏第一个按钮)。
class PlayerExitButton extends StatelessWidget {
  const PlayerExitButton({super.key, required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 36,
      left: 12,
      width: 46,
      height: 46,
      child: IconButton(
        tooltip: '退出播放',
        enableFeedback: false,
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.close, color: Colors.white, size: 25),
        onPressed: () {
          PlayerHaptics.light();
          onExit();
        },
      ),
    );
  }
}
