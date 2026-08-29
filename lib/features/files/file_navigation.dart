import 'package:flutter/widgets.dart';

/// 文件管理器根页面路由名。
///
/// 文件浏览页的根目录仍然是文件管理器页面，不应被误判为服务器选择器；
/// 文件管理器内部 Navigator 也使用这个名称承载根页面。
const fileManagerRootRouteName = 'file-manager-root';

/// 连接文件内部 Navigator 与外层服务器页面栈。
///
/// 文件浏览页在文件管理器内部导航时，最近的 Navigator 是目录 Navigator，
/// 不能直接通过 ServerSelectionPage.requestReturn 返回外层服务器选择器。
/// 由此作用域提供外层返回回调；独立嵌入文件页时没有作用域，继续使用原有
/// 兼容逻辑。
class FileManagerNavigationScope extends InheritedWidget {
  const FileManagerNavigationScope({
    super.key,
    required this.onRequestServerSelection,
    required super.child,
  });

  final VoidCallback onRequestServerSelection;

  static bool requestServerSelection(BuildContext context) {
    final scope = context
        .findAncestorWidgetOfExactType<FileManagerNavigationScope>();
    if (scope == null) return false;
    scope.onRequestServerSelection();
    return true;
  }

  @override
  bool updateShouldNotify(FileManagerNavigationScope oldWidget) =>
      onRequestServerSelection != oldWidget.onRequestServerSelection;
}
