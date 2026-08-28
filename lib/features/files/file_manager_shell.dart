import 'package:flutter/material.dart';

import 'file_sources_page.dart';

/// 文件管理器 Shell。
///
/// SMB、WebDAV 以及未来接入的 OpenList/NFS/FTP 等文件来源统一从这里
/// 进入。文件管理器不使用媒体管理器的底部导航；具体来源和目录页面由
/// [FileSourcesPage] 继续负责解析与展示。
class FileManagerShell extends StatelessWidget {
  const FileManagerShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const FileSourcesPage();
  }
}
