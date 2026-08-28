import 'dart:typed_data';

enum Smb2Version { any, any2, any3, v202, v210, v300, v302, v311 }

class Smb2Stat {
  const Smb2Stat({
    required this.isDirectory,
    required this.size,
    required this.modified,
    required this.created,
  });

  final bool isDirectory;
  final int size;
  final DateTime modified;
  final DateTime created;

  bool get isFile => !isDirectory;
}

class Smb2DirEntry {
  const Smb2DirEntry({required this.name, required this.stat});

  final String name;
  final Smb2Stat stat;
}

class Smb2ShareInfo {
  const Smb2ShareInfo({required this.name, required this.type});

  final String name;
  final int type;

  bool get isDisk => type & 0x03 == 0;
}

class Smb2Pool {
  Smb2Pool._();

  static Future<Smb2Pool> connect({
    required String host,
    required String share,
    String? user,
    String? password,
    String? domain,
    int workers = 4,
    int timeoutSeconds = 30,
    bool seal = false,
    bool signing = false,
    Smb2Version version = Smb2Version.any,
  }) => throw UnsupportedError('SMB 在 Web 调试目标中不可用');

  static Future<List<Smb2ShareInfo>> listSharesOn({
    required String host,
    String? user,
    String? password,
    String? domain,
    int timeoutSeconds = 15,
  }) => _unsupported<List<Smb2ShareInfo>>();

  Future<List<Smb2DirEntry>> listDirectory(String path) =>
      _unsupported<List<Smb2DirEntry>>();

  Future<Smb2Stat> stat(String path) => _unsupported<Smb2Stat>();

  Future<bool> exists(String path) => _unsupported<bool>();

  Stream<Uint8List> streamFile(
    String path, {
    void Function(int received, int total)? onProgress,
    bool Function()? isCanceled,
  }) => _unsupportedStream<Uint8List>();

  Future<Uint8List> readFileRange(
    String path, {
    int offset = 0,
    required int length,
  }) =>
      _unsupported<Uint8List>();

  Future<void> streamWrite(String path, Stream<Uint8List> chunks) =>
      _unsupported<void>();

  Future<void> mkdir(String path) => _unsupported<void>();

  Future<void> deleteFile(String path) => _unsupported<void>();

  Future<void> rmdir(String path) => _unsupported<void>();

  Future<void> rename(String source, String destination) =>
      _unsupported<void>();

  Future<void> disconnect() async {}
}

Future<T> _unsupported<T>() =>
    Future<T>.error(UnsupportedError('SMB 在 Web 调试目标中不可用'));

Stream<T> _unsupportedStream<T>() =>
    Stream<T>.error(UnsupportedError('SMB 在 Web 调试目标中不可用'));
