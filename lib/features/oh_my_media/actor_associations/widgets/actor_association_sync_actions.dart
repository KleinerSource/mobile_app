part of 'actor_association_sync_sheet.dart';

// 状态及资源所有权保留在页面；此扩展只组织同一职责的方法。
extension _ActorAssociationSyncActions on _ActorAssociationSyncSheetState {
  Future<void> _apply() async {
    final preview = _preview;
    if (preview == null || _applying) return;
    if (!_hasSyncChanges(preview)) return;

    final biographyChanged = _biographyNeedsSync(preview);
    final avatarChanged = _canSyncAvatars(preview);
    final selectedAliases = preview.newAliases
        .where(_selectedAliases.contains)
        .toList(growable: false);
    // 按候选顺序提交所选头像,后端依次下载保存为多张可轮播封面
    final avatarUrls = avatarChanged
        ? [
            for (final (_, choice) in _selectedChoicesFor(preview))
              choice.downloadUrl,
          ]
        : const <String>[];
    _updateViewState(() => _applying = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final merged = ActorAssociationsRepository.mergeAliases(
        widget.actor.originalValues,
        selectedAliases,
        preview.mappedValue.isNotEmpty
            ? preview.mappedValue
            : widget.actor.mappedValue ?? '',
      );
      final message = await ref
          .read(actorAssociationsRepositoryProvider)
          .applySource(
            mappedValue: preview.mappedValue.isNotEmpty
                ? preview.mappedValue
                : widget.actor.mappedValue ?? '',
            originalValues: merged,
            source: _source,
            biography: biographyChanged ? preview.biography : null,
            avatarUrls: avatarUrls,
            avatarOverwrite: avatarChanged && preview.avatarExists,
            avatarSources: avatarChanged ? _avatarSourcesFor(preview) : null,
            externalIds:
                _source == ActorDataSource.mixed &&
                    preview.externalIds.isNotEmpty
                ? preview.externalIds
                : null,
          );
      if (!mounted) return;
      // 成功只提示结果，详细情况仅在失败时展示；回调仍需驱动外部状态刷新
      if (biographyChanged) {
        widget.onBiographyApplied?.call(preview.biography.trim());
      }
      if (avatarChanged) {
        widget.onAvatarApplied?.call();
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(message ?? AppL10n.of(context).actorAssocSyncDone),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppL10n.of(context).actorAssocSyncApplyFailed(
              localizedErrorMessage(AppL10n.of(context), e),
            ),
          ),
        ),
      );
      _updateViewState(() => _applying = false);
    }
  }

  Future<void> _openAvatarPicker() async {
    final preview = _preview;
    if (_applying || preview == null) return;
    final choices = _avatarChoicesFor(preview);
    if (choices.length <= 1) return;

    final result = await showGlassSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AvatarChoicePicker(
        mappedValue: preview.mappedValue,
        choices: choices,
        selectedIndices: _selectedAvatarChoices,
        avatarBytes: _avatarChoiceBytes,
        avatarLoading: _avatarChoiceLoading,
        avatarLoadFailed: _avatarChoiceFailed,
        revision: _avatarPickerRevision,
        onRetry: (url) => unawaited(_loadAvatarPreview(preview, _source, url)),
      ),
    );
    if (!mounted || result == null) return;
    if (_applying) return;
    _updateViewState(() {
      _selectedAvatarChoices = result;
      _avatarManuallySelected = true;
    });
  }
}
