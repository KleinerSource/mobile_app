import 'package:flutter_riverpod/flutter_riverpod.dart';

/// MainShell 底栏 tab 索引（0..4）。
/// 3 是"更多"，永远不会写入这里；写 3 的人请改成调用 onMoreTap。
final mainShellTabIndexProvider = StateProvider<int>((_) => 0);
