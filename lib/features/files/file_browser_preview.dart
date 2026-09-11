part of 'file_browser_page.dart';

// 状态及资源所有权保留在页面；此扩展只组织同一职责的方法。
extension _FileBrowserPreview on _FileBrowserPageState {
  Future<bool?> _showDetails(FileEntry entry) async {
    final l = _l10n;
    return showGlassSheet<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(
              icon: null,
              iconWidget: FileEntryIconAsset(
                assetPath: fileIconAssetWhenPreviewDisabledFor(entry),
              ),
              title: entry.name,
              subtitle: entry.isDirectory
                  ? l.fileDirectoryDetails
                  : l.fileFileDetails,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.filePathLabel(entry.path.value)),
                  if (entry.size != null)
                    Text(l.fileSizeLabel(_formatBytes(entry.size!))),
                  if (entry.mimeType != null)
                    Text(l.fileTypeLabel(entry.mimeType!)),
                  if (entry.modifiedAt != null)
                    Text(
                      l.fileModifiedAtLabel(_formatDateTime(entry.modifiedAt!)),
                    ),
                ],
              ),
            ),
            if (_canOpenAsText(entry))
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  icon: const Icon(Icons.text_snippet_outlined),
                  label: Text(l.fileOpenAsText),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDetailsAndMaybeOpenAsText(FileEntry entry) async {
    final openAsText = await _showDetails(entry);
    if (openAsText == true) await _previewText(entry);
  }

  Future<void> _openFile(FileEntry entry) async {
    await _runFileOpen(() async {
      if (_canPreview(entry)) {
        await _preview(entry);
        return;
      }
      await _showDetailsAndMaybeOpenAsText(entry);
    });
  }

  Future<void> _runFileOpen(Future<void> Function() action) {
    return _fileOpenGate.run(() async {
      if (!mounted || _busy) return;
      _updateViewState(() => _busy = true);
      try {
        await action();
      } finally {
        if (mounted) _updateViewState(() => _busy = false);
      }
    });
  }

  bool _canOpenAsText(FileEntry entry) =>
      !entry.isDirectory &&
      entry.size != null &&
      entry.size! < _maxFallbackTextBytes;

  Future<void> _preview(FileEntry entry) async {
    if (_isVideoEntry(entry)) {
      await _previewVideo(entry);
    } else if (_isAudioEntry(entry)) {
      await _previewAudio(entry);
    } else if (_isImageEntry(entry)) {
      await _previewImage(entry);
    } else if (_isTextEntry(entry)) {
      await _previewText(entry);
    }
  }

  Future<void> _previewVideo(FileEntry entry) async {
    await _previewMedia(
      entry,
      itemType: PlayerQueueItemType.video,
      logLabel: '视频',
      failureMessage: _l10n.fileVideoPreviewFailed,
    );
  }

  Future<void> _previewAudio(FileEntry entry) async {
    await _previewMedia(
      entry,
      itemType: PlayerQueueItemType.audio,
      logLabel: '音频',
      failureMessage: _l10n.fileAudioPreviewFailed,
    );
  }

  Future<void> _previewMedia(
    FileEntry entry, {
    required PlayerQueueItemType itemType,
    required String logLabel,
    required String Function(String) failureMessage,
  }) async {
    PlaybackEngineKind? engineKind;
    final playerSettings = ref.read(playerSettingsProvider);
    if (itemType == PlayerQueueItemType.video && playerSettings.debugMode) {
      final engineKinds = availablePlaybackEngineKinds();
      engineKind = await showPlaybackEnginePicker(
        context,
        engineKinds: engineKinds,
        defaultEngineKind: playerSettings.iosEngine,
      );
      if (!mounted || engineKind == null) return;
    }

    final playbackProxies = <FilePlaybackProxy>[];
    FileAudioMetadataSession? audioMetadataSession;
    Future<void> disposeQueueResources() async {
      // 两类下载必须并行取消：元数据读取不能阻塞播放器代理断开。
      final metadataDispose = audioMetadataSession?.dispose();
      await closeFilePlaybackProxies(playbackProxies);
      if (metadataDispose != null) await metadataDispose;
    }

    var queueOwnershipTransferred = false;
    try {
      final repository = await _repository();
      final sourceKind = repository.source.descriptor.kind;
      final musicCache = itemType == PlayerQueueItemType.audio
          ? ref.read(musicCacheServiceProvider)
          : null;
      // 视频使用原生 HTTP(S) 地址，保留播放器自身的 Range/seek 能力。
      // 音频统一经过回环代理并完整缓存后再交给播放器，避免边下载边播放
      // 时出现解码、歌词加载和关闭资源竞争。
      final useDirect =
          itemType != PlayerQueueItemType.audio &&
          (sourceKind == SourceKind.webDav ||
              sourceKind == SourceKind.openList);
      final selectedEngineKind = filePlaybackEngineKind(
        sourceKind: sourceKind,
        isIOS: Platform.isIOS,
        requested: engineKind,
      );
      appLog(
        '[FileBrowser] 视频来源: kind=${sourceKind.name} '
        'direct=$useDirect '
        'source=${repository.source.descriptor.id.value}',
      );

      final listing = ref.read(fileDirectoryProvider(_request)).value;
      if (itemType == PlayerQueueItemType.audio) {
        final directoryPath = FilePath(sourceId: widget.sourceId, value: _path);
        audioMetadataSession = FileAudioMetadataSession(
          repository: repository,
          directoryEntries: listing?.entries ?? <FileEntry>[entry],
          musicCache: musicCache,
          directoryEntriesLoader: listing == null
              ? () async =>
                    (await repository.listDirectory(directoryPath)).entries
              : null,
        );
      }
      final mediaEntries =
          (listing == null
                  ? <FileEntry>[entry]
                  : _visibleEntries(listing)
                        .where(
                          (item) =>
                              item.isFile &&
                              (itemType == PlayerQueueItemType.audio
                                  ? _isAudioEntry(item)
                                  : _isVideoEntry(item)),
                        )
                        .toList())
              .toList();
      if (!mediaEntries.any((item) => item.stableKey == entry.stableKey)) {
        mediaEntries.insert(0, entry);
      }
      final queue = await buildFilePlaybackQueue(
        repository: repository,
        entries: mediaEntries,
        current: entry,
        itemType: itemType,
        useDirect: useDirect,
        proxies: playbackProxies,
        directUrlMissingMessage: _l10n.fileWebDavDirectUrlMissing,
        musicCache: musicCache,
      );
      if (!mounted) return;
      final queueIndex = queue.indexWhere(
        (item) => item.mediaId == entry.stableKey,
      );
      if (queueIndex < 0) {
        throw StateError(AppErrorCode.responseDataMissing);
      }
      final current = queue[queueIndex];
      appLog(
        '[FileBrowser] 使用文件队列播放: type=$logLabel '
        'engine=${selectedEngineKind?.value ?? 'default'} '
        'count=${queue.length} direct=$useDirect',
      );
      if (itemType == PlayerQueueItemType.audio) {
        await AudioPlayerPage.openDirect(
          context,
          title: current.title,
          directUrl: current.directUrl!,
          directHeaders: current.directHeaders,
          directFormatHint: current.directFormatHint,
          directPlaybackFileName: current.directPlaybackFileName,
          queue: queue,
          queueIndex: queueIndex,
          audioMetadataLoader: audioMetadataSession?.load,
          onQueueDispose: disposeQueueResources,
          useRootNavigator: true,
        );
      } else {
        await VideoPlayerPage.openDirect(
          context,
          title: current.title,
          directUrl: current.directUrl!,
          directHeaders: current.directHeaders,
          directFormatHint: current.directFormatHint,
          engineKind: selectedEngineKind,
          directPlaybackFileName: current.directPlaybackFileName,
          directPreferFfmpegForHls: current.directPreferFfmpegForHls,
          queue: queue,
          queueIndex: queueIndex,
          onQueueDispose: disposeQueueResources,
          useRootNavigator: true,
        );
      }
      queueOwnershipTransferred = true;
    } catch (error, stackTrace) {
      appLog('[FileBrowser] $logLabel预览失败: $error\n$stackTrace');
      if (mounted) {
        _message(
          failureMessage(
            localizedErrorMessage(_l10n, error),
          ),
        );
      }
    } finally {
      if (!queueOwnershipTransferred) {
        await disposeQueueResources();
      }
    }
  }

  Future<void> _previewImage(FileEntry entry) async {
    try {
      final listing = ref.read(fileDirectoryProvider(_request)).value;
      final entries = listing == null
          ? <FileEntry>[entry]
          : _visibleEntries(listing).where(_isImageEntry).toList();
      if (!entries.any((item) => item.stableKey == entry.stableKey)) {
        entries.insert(0, entry);
      }
      final initialIndex = entries.indexWhere(
        (item) => item.stableKey == entry.stableKey,
      );
      if (!mounted) return;
      await showImageLightbox(
        context,
        itemCount: entries.length,
        initialIndex: initialIndex < 0 ? 0 : initialIndex,
        loadBytes: (index) => _readFileBytes(entries[index]),
        useRootNavigator: true,
      );
    } catch (error) {
      if (mounted) _message(_l10n.fileImagePreviewFailed(error.toString()));
    }
  }

  Future<void> _previewText(FileEntry entry) async {
    try {
      final repository = await _repository();
      final bytes = await _readFileBytes(entry, repository: repository);
      if (!mounted) return;
      final text = _decodeTextPreview(entry, bytes);
      final onSave = repository.source.supports(FileCapability.transfer)
          ? (String value) async {
              final encoded = utf8.encode(value);
              await repository.upload(
                FileUploadRequest(
                  destination: entry.path,
                  data: Stream<List<int>>.value(encoded),
                  length: encoded.length,
                  options: const FileTransferOptions(overwrite: true),
                ),
              );
            }
          : null;
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute<void>(
          allowSnapshotting: false,
          builder: (_) =>
              TextEditorPage(title: entry.name, text: text, onSave: onSave),
        ),
      );
    } catch (error) {
      if (mounted) _message(_l10n.fileTextPreviewFailed(error.toString()));
    }
  }

  Future<Uint8List> _readFileBytes(
    FileEntry entry, {
    FileSourceRepository? repository,
  }) async {
    final sourceRepository = repository ?? await _repository();
    final stream = sourceRepository.download(entry.path);
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  bool _canPreview(FileEntry entry) =>
      _isVideoEntry(entry) ||
      _isAudioEntry(entry) ||
      _isImageEntry(entry) ||
      _isTextEntry(entry);

  bool _isVideoEntry(FileEntry entry) =>
      fileTypeIconFor(entry) == FileTypeIcon.video;

  bool _isAudioEntry(FileEntry entry) =>
      fileTypeIconFor(entry) == FileTypeIcon.audio;

  bool _isImageEntry(FileEntry entry) =>
      fileTypeIconFor(entry) == FileTypeIcon.image;

  bool _isTextEntry(FileEntry entry) => isTextEditorEntry(entry);

  String _decodeTextPreview(FileEntry entry, List<int> bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final mime = entry.mimeType?.toLowerCase() ?? '';
    final isJson =
        mime == 'application/json' || fileExtensionFor(entry.name) == 'json';
    if (!isJson) return text;
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(text));
    } catch (_) {
      return text;
    }
  }
}
