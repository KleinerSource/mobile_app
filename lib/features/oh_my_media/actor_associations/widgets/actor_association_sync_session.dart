part of 'actor_association_sync_sheet.dart';

// 状态及资源所有权保留在页面；此扩展只组织同一职责的方法。
extension _ActorAssociationSyncSession on _ActorAssociationSyncSheetState {
  Future<void> _load({ActorDataSource? source}) async {
    final requestId = ++_loadRequestId;
    final selectedSource = source ?? _source;
    _updateViewState(() {
      _loading = true;
      _error = null;
      _pendingSources = const [];
      _avatarChoiceBytes.clear();
      _avatarChoiceLoading.clear();
      _avatarChoiceFailed.clear();
      _selectedAvatarChoices = <int>{};
      _avatarManuallySelected = false;
    });
    try {
      if (!_sourcesLoaded) {
        final available = await _loadAvailableSources();
        if (!mounted || requestId != _loadRequestId) return;
        if (available.isEmpty) {
          throw StateError(AppL10n.of(context).actorAssocSyncSourcesRequired);
        }
        _updateViewState(() {
          _availableSources = available;
          _sourcesLoaded = true;
          if (!_availableSources.contains(_source)) {
            _source = _availableSources.first;
          }
        });
        // 先让数据源选择器完成一帧渲染，再开始预览请求，避免加载状态与选择器状态竞态。
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || requestId != _loadRequestId) return;
      }
      final actualSource = _availableSources.contains(selectedSource)
          ? selectedSource
          : _source;
      if (actualSource == ActorDataSource.mixed) {
        await _loadMixedPreview(requestId, actualSource);
        return;
      }
      final repo = ref.read(actorAssociationsRepositoryProvider);
      final p = await repo.previewSource(_actorName, source: actualSource);
      if (!mounted || requestId != _loadRequestId || actualSource != _source) {
        return;
      }
      _updateViewState(() {
        _preview = p;
        _selectedAliases = p.newAliases.toSet();
        _syncDefaultAvatarSelection(p);
        _loading = false;
      });
      unawaited(_loadAvatarPreviews(p, actualSource));
    } catch (e) {
      if (!mounted || requestId != _loadRequestId) return;
      _updateViewState(() {
        _error = toApiException(e).message;
        _loading = false;
      });
    }
  }

  Future<void> _loadMixedPreview(int requestId, ActorDataSource source) async {
    final l = AppL10n.of(context);
    final repo = ref.read(actorAssociationsRepositoryProvider);
    final taskId = await repo.startMixedPreviewSession(_actorName);
    if (!mounted || requestId != _loadRequestId || source != _source) return;

    var rendered = false;
    var lastChoiceCount = -1;
    final startedAt = DateTime.now();
    while (mounted && requestId == _loadRequestId && source == _source) {
      final session = await repo.getMixedPreviewSession(taskId);
      if (!mounted || requestId != _loadRequestId || source != _source) return;

      final p = session.preview;
      if (p != null && p.found) {
        final choiceCount = _avatarChoicesFor(p).length;
        _updateViewState(() {
          _preview = p;
          _selectedAliases = p.newAliases.toSet();
          _syncDefaultAvatarSelection(p);
          _pendingSources = session.pendingSources;
          if (!rendered) {
            rendered = true;
            _loading = false;
          }
        });
        // 仅在新候选出现时补拉头像，避免每次轮询重复入队
        if (choiceCount != lastChoiceCount) {
          lastChoiceCount = choiceCount;
          unawaited(_loadAvatarPreviews(p, source));
        }
      }
      if (session.complete) {
        _updateViewState(() {
          _preview = session.preview;
          _selectedAliases = session.preview?.newAliases.toSet() ?? <String>{};
          final finalPreview = session.preview;
          if (finalPreview != null && finalPreview.found) {
            _syncDefaultAvatarSelection(finalPreview);
          }
          _pendingSources = const [];
          _loading = false;
        });
        final finalPreview = session.preview;
        if (finalPreview != null && finalPreview.found) {
          final choiceCount = _avatarChoicesFor(finalPreview).length;
          if (choiceCount != lastChoiceCount) {
            unawaited(_loadAvatarPreviews(finalPreview, source));
          }
        }
        return;
      }
      if (session.failed) {
        throw StateError(
          session.error.isEmpty ? l.actorAssocSyncMixedFailed : session.error,
        );
      }
      if (DateTime.now().difference(startedAt) > const Duration(seconds: 90)) {
        throw StateError(l.actorAssocSyncPreviewTimedOut);
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }

  Future<void> _loadAvatarPreviews(
    ActorAssocPreview preview,
    ActorDataSource source,
  ) async {
    final urls = [
      for (final choice in _avatarChoicesFor(preview)) choice.downloadUrl,
    ];
    if (urls.isEmpty) return;
    var cursor = 0;
    Future<void> worker() async {
      while (cursor < urls.length) {
        final url = urls.elementAt(cursor++);
        await _loadAvatarPreview(preview, source, url);
      }
    }

    final workerCount = urls.length < 4 ? urls.length : 4;
    await Future.wait(List.generate(workerCount, (_) => worker()));
  }

  Future<void> _loadAvatarPreview(
    ActorAssocPreview preview,
    ActorDataSource source,
    String avatarUrl,
  ) async {
    final url = avatarUrl.trim();
    // 不比较 _preview 对象身份：渐进补齐会替换 preview 对象，但按 URL 缓存的
    // 头像字节仍然有效；仅以数据源切换/组件销毁判定过期。
    if (url.isEmpty || !mounted || _source != source) {
      return;
    }
    if (_avatarChoiceBytes.containsKey(url) ||
        _avatarChoiceLoading.contains(url)) {
      return;
    }
    _updateViewState(() {
      _avatarChoiceLoading.add(url);
      _avatarChoiceFailed.remove(url);
    });
    _avatarPickerRevision.value++;
    try {
      final bytes = await ref
          .read(actorAssociationsRepositoryProvider)
          .previewAvatar(url, source: _avatarDownloadSource(url));
      if (!mounted || _source != source) return;
      if (bytes.isEmpty) throw StateError('头像内容为空');
      _updateViewState(() {
        _avatarChoiceBytes[url] = Uint8List.fromList(bytes);
        _avatarChoiceLoading.remove(url);
        _avatarChoiceFailed.remove(url);
      });
      _avatarPickerRevision.value++;
    } catch (_) {
      if (!mounted || _source != source) return;
      _updateViewState(() {
        _avatarChoiceLoading.remove(url);
        _avatarChoiceFailed.add(url);
      });
      _avatarPickerRevision.value++;
    }
  }

  Future<List<ActorDataSource>> _loadAvailableSources() async {
    Future<DboConfig?> loadDbo() async {
      try {
        return await ref.read(dboConfigProvider.future);
      } catch (_) {
        return null;
      }
    }

    Future<AvdbConfig?> loadAvdb() async {
      try {
        return await ref.read(avdbConfigProvider.future);
      } catch (_) {
        return null;
      }
    }

    final configs = await Future.wait<Object?>([loadDbo(), loadAvdb()]);
    return configuredActorDataSources(
      dbonline: configs[0] as DboConfig?,
      avdb: configs[1] as AvdbConfig?,
    );
  }

  void _selectSource(ActorDataSource source) {
    if (_applying || source == _source) return;
    _updateViewState(() {
      _source = source;
      _preview = null;
      _selectedAliases = <String>{};
      _pendingSources = const [];
      _avatarChoiceBytes.clear();
      _avatarChoiceLoading.clear();
      _avatarChoiceFailed.clear();
      _selectedAvatarChoices = <int>{};
      _avatarManuallySelected = false;
    });
    unawaited(
      ActorAssociationsRepository.rememberSource(
        ref.read(sharedPrefsProvider),
        source,
      ),
    );
    unawaited(_load(source: source));
  }
}
