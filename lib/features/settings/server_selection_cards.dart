part of 'server_selection_page.dart';

class _ConnectionHeader extends StatelessWidget {
  const _ConnectionHeader({required this.onChanged, required this.showSearch});

  final ValueChanged<String> onChanged;
  final bool showSearch;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final l = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.serverSelectionTitle,
          style: AppText.pageTitle(context).copyWith(fontSize: 24),
        ),
        if (showSearch) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: GlassPanel(
              borderRadius: BorderRadius.circular(16),
              sigma: 18,
              tint: colors.surface.withValues(alpha: 0.72),
              showBorder: false,
              showHighlight: false,
              child: TextField(
                key: const ValueKey('server-selection-search'),
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                textAlignVertical: TextAlignVertical.center,
                style: AppText.body(context).copyWith(fontSize: 14),
                cursorColor: colors.accent,
                decoration: InputDecoration(
                  hintText: l.serverSelectionSearchHint,
                  hintStyle: TextStyle(
                    color: colors.muted,
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: colors.muted,
                    size: 21,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AddServerCard extends StatelessWidget {
  const _AddServerCard({required this.onTap, this.dropTarget = false});

  final VoidCallback onTap;
  final bool dropTarget;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Semantics(
      button: true,
      label: l.serverSelectionAddServer,
      child: SizedBox(
        width: double.infinity,
        height: _ServerSelectionMetrics.cardHeight,
        child: _ServerCardShell(
          dropTarget: dropTarget,
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.add_rounded,
                    size: _ServerSelectionMetrics.addIconSize,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    l.serverSelectionAddServer,
                    style: AppText.cardTitle(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServerStrip extends StatefulWidget {
  const _ServerStrip({
    required this.servers,
    required this.transition,
    required this.profileFor,
    required this.cachedProfileFor,
    required this.showUsername,
    required this.showAvatar,
    required this.statusFor,
    required this.avatarKeyFor,
    required this.scrollController,
    required this.reorderEnabled,
    required this.onSelect,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onReorder,
  });

  final List<ServerProfile> servers;
  final ServerSwitchState transition;
  final Future<ServerProfileData?> Function(ServerProfile server) profileFor;
  final ServerProfileData? Function(ServerProfile server) cachedProfileFor;
  final bool showUsername;
  final bool showAvatar;
  final Future<_ServerStatus> Function(ServerProfile server) statusFor;
  final GlobalKey Function(String serverId) avatarKeyFor;
  final ScrollController scrollController;
  final bool reorderEnabled;
  final ValueChanged<ServerProfile> onSelect;
  final VoidCallback onAdd;
  final ValueChanged<ServerProfile> onEdit;
  final ValueChanged<ServerProfile> onDelete;
  final Future<void> Function(int oldIndex, int newIndex) onReorder;

  @override
  State<_ServerStrip> createState() => _ServerStripState();
}

class _ServerStripState extends State<_ServerStrip> {
  final _gridKey = GlobalKey();
  final _cardKeys = <String, GlobalKey>{};
  final _addCardKey = GlobalKey();
  String? _actionServerId;
  String? _draggingServerId;
  Offset? _longPressStart;
  Offset? _dragPosition;
  Offset? _dragGrabOffset;
  int? _dragTargetIndex;
  var _actionAlignRight = false;
  var _actionShowAbove = false;
  var _suppressCardTapUntilPointerDown = false;

  GlobalKey _cardKeyFor(String serverId) {
    return _cardKeys.putIfAbsent(serverId, GlobalKey.new);
  }

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_closeInteraction);
  }

  @override
  void didUpdateWidget(covariant _ServerStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_closeInteraction);
      widget.scrollController.addListener(_closeInteraction);
    }
    final actionId = _actionServerId;
    final draggingId = _draggingServerId;
    if ((actionId != null &&
            !widget.servers.any((server) => server.id == actionId)) ||
        (draggingId != null &&
            !widget.servers.any((server) => server.id == draggingId))) {
      _resetInteraction();
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_closeInteraction);
    super.dispose();
  }

  void _closeInteraction() {
    if (!mounted) return;
    if (_actionServerId != null || _draggingServerId != null) {
      _resetInteraction();
    }
  }

  void _resetInteraction() {
    if (!mounted) return;
    setState(() {
      _actionServerId = null;
      _draggingServerId = null;
      _longPressStart = null;
      _dragPosition = null;
      _dragGrabOffset = null;
      _dragTargetIndex = null;
      _actionAlignRight = false;
      _actionShowAbove = false;
    });
  }

  void _dismissActions() {
    if (_actionServerId == null || !mounted) return;
    setState(() => _actionServerId = null);
  }

  void _allowCardTapForNextPointer() {
    _suppressCardTapUntilPointerDown = false;
  }

  void _startLongPress(String serverId, LongPressStartDetails details) {
    if (!mounted || _draggingServerId != null) return;
    _suppressCardTapUntilPointerDown = true;
    final cardRect = _globalRectFor(_cardKeyFor(serverId));
    final mediaQuery = MediaQuery.maybeOf(context);
    final viewportSize = mediaQuery?.size;
    final safeTop = mediaQuery?.padding.top ?? 0;
    final safeBottom = mediaQuery?.padding.bottom ?? 0;
    final alignRight =
        cardRect != null &&
        viewportSize != null &&
        cardRect.center.dx > viewportSize.width / 2;
    final showAbove =
        cardRect != null &&
        viewportSize != null &&
        cardRect.bottom + 8 + _ServerActionList.height >
            viewportSize.height - safeBottom &&
        cardRect.top - 8 - _ServerActionList.height >= safeTop;
    setState(() {
      _actionServerId = serverId;
      _longPressStart = details.globalPosition;
      _dragPosition = details.globalPosition;
      _dragGrabOffset = cardRect == null
          ? null
          : details.globalPosition - cardRect.topLeft;
      _dragTargetIndex = widget.servers.indexWhere(
        (server) => server.id == serverId,
      );
      _actionAlignRight = alignRight;
      _actionShowAbove = showAbove;
    });
    AppHaptics.medium();
  }

  void _updateLongPress(String serverId, LongPressMoveUpdateDetails details) {
    if (!mounted || _longPressStart == null) return;
    if (_actionServerId != serverId && _draggingServerId != serverId) return;
    final position = details.globalPosition;
    if (_draggingServerId == null) {
      if (!widget.reorderEnabled ||
          (position - _longPressStart!).distance <= kTouchSlop) {
        return;
      }
      final cardRect = _globalRectFor(_cardKeyFor(serverId));
      setState(() {
        _actionServerId = null;
        _draggingServerId = serverId;
        _dragPosition = position;
        _dragGrabOffset = cardRect == null
            ? null
            : _longPressStart! - cardRect.topLeft;
        _dragTargetIndex = _targetIndexFor(position);
      });
      AppHaptics.medium();
      return;
    }

    final targetIndex = _targetIndexFor(position);
    if (targetIndex == null) return;
    final targetChanged = targetIndex != _dragTargetIndex;
    setState(() {
      _dragPosition = position;
      _dragTargetIndex = targetIndex;
    });
    if (targetChanged) AppHaptics.selection();
  }

  void _finishLongPress(String serverId, LongPressEndDetails details) {
    if (!mounted) return;
    if (_draggingServerId != serverId) {
      // 没有移动时保留悬浮按钮，供用户点击编辑或删除。
      setState(() {
        _longPressStart = null;
        _dragPosition = null;
        _dragGrabOffset = null;
        _dragTargetIndex = null;
      });
      return;
    }

    final oldIndex = widget.servers.indexWhere(
      (server) => server.id == serverId,
    );
    final targetIndex =
        _targetIndexFor(details.globalPosition) ?? _dragTargetIndex ?? oldIndex;
    final maxIndex = widget.servers.length - 1;
    final newIndex = targetIndex.clamp(0, maxIndex).toInt();
    _resetInteraction();
    if (oldIndex >= 0 && newIndex != oldIndex) {
      AppHaptics.medium();
      unawaited(widget.onReorder(oldIndex, newIndex));
    }
  }

  void _cancelLongPress() {
    _resetInteraction();
  }

  int? _targetIndexFor(Offset globalPosition) {
    if (widget.servers.isEmpty) return null;
    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    for (var index = 0; index < widget.servers.length; index++) {
      final rect = _globalRectFor(_cardKeyFor(widget.servers[index].id));
      if (rect == null) continue;
      if (rect.inflate(8).contains(globalPosition)) return index;
      final dx =
          globalPosition.dx.clamp(rect.left, rect.right) - globalPosition.dx;
      final dy =
          globalPosition.dy.clamp(rect.top, rect.bottom) - globalPosition.dy;
      final distance = dx * dx + dy * dy;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = index;
      }
    }

    final addRect = _globalRectFor(_addCardKey);
    if (addRect != null && addRect.inflate(8).contains(globalPosition)) {
      return widget.servers.length;
    }
    return nearestIndex;
  }

  Rect? _globalRectFor(GlobalKey key) {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    final topLeft = renderObject.localToGlobal(Offset.zero);
    return topLeft & renderObject.size;
  }

  Widget _buildServerCard(ServerProfile server, {bool feedback = false}) {
    final transition = widget.transition;
    final busy = transition.isActive && transition.targetServerId == server.id;
    final isDragging = _draggingServerId == server.id;
    final targetIndex = _dragTargetIndex;
    final serverIndex = widget.servers.indexOf(server);
    final isDropTarget =
        _draggingServerId != null && targetIndex == serverIndex && !isDragging;
    final card = _ServerAvatarCard(
      server: server,
      profileFuture: widget.profileFor(server),
      cachedProfile: widget.cachedProfileFor(server),
      showUsername: widget.showUsername,
      showAvatar: widget.showAvatar,
      statusFuture: widget.statusFor(server),
      avatarKey: feedback ? null : widget.avatarKeyFor(server.id),
      busy: busy,
      dropTarget: isDropTarget,
      onTap: feedback
          ? null
          : () {
              if (_suppressCardTapUntilPointerDown) return;
              _dismissActions();
              widget.onSelect(server);
            },
    );
    if (feedback) return card;
    return SizedBox(
      key: _cardKeyFor(server.id),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: isDragging ? 0.28 : 1,
        child: _ServerCardInteraction(
          onPointerDown: _allowCardTapForNextPointer,
          showActions: _actionServerId == server.id,
          actionAlignRight: _actionAlignRight,
          actionShowAbove: _actionShowAbove,
          enabled: !busy && !transition.isActive,
          onEdit: () {
            _dismissActions();
            widget.onEdit(server);
          },
          onDelete: () {
            _dismissActions();
            widget.onDelete(server);
          },
          onDismissActions: _dismissActions,
          onLongPressStart: (details) => _startLongPress(server.id, details),
          onLongPressMoveUpdate: (details) =>
              _updateLongPress(server.id, details),
          onLongPressEnd: (details) => _finishLongPress(server.id, details),
          onLongPressCancel: _cancelLongPress,
          child: card,
        ),
      ),
    );
  }

  Widget _buildDragFeedback() {
    final draggingId = _draggingServerId;
    final position = _dragPosition;
    final gridBox = _gridKey.currentContext?.findRenderObject();
    if (draggingId == null || position == null || gridBox is! RenderBox) {
      return const SizedBox.shrink();
    }
    final server = widget.servers.firstWhere(
      (item) => item.id == draggingId,
      orElse: () => widget.servers.first,
    );
    final cardRect = _globalRectFor(_cardKeyFor(draggingId));
    if (cardRect == null) return const SizedBox.shrink();
    final localPosition = gridBox.globalToLocal(position);
    final grabOffset =
        _dragGrabOffset ?? Offset(cardRect.width / 2, cardRect.height / 2);
    return Positioned(
      left: localPosition.dx - grabOffset.dx,
      top: localPosition.dy - grabOffset.dy,
      width: cardRect.width,
      height: cardRect.height,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.92,
          child: _buildServerCard(server, feedback: true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: _gridKey,
      clipBehavior: Clip.none,
      children: [
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          clipBehavior: Clip.none,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: _ServerSelectionMetrics.cardGap,
            mainAxisSpacing: _ServerSelectionMetrics.cardGap,
            mainAxisExtent: _ServerSelectionMetrics.cardHeight,
          ),
          itemCount: widget.servers.length + 1,
          itemBuilder: (context, index) {
            if (index == widget.servers.length) {
              return SizedBox(
                key: _addCardKey,
                child: _AddServerCard(
                  onTap: widget.onAdd,
                  dropTarget:
                      _draggingServerId != null &&
                      _dragTargetIndex == widget.servers.length,
                ),
              );
            }
            return _buildServerCard(widget.servers[index]);
          },
        ),
        _buildDragFeedback(),
      ],
    );
  }
}

class _ServerCardInteraction extends StatefulWidget {
  const _ServerCardInteraction({
    required this.child,
    required this.onPointerDown,
    required this.enabled,
    required this.showActions,
    required this.actionAlignRight,
    required this.actionShowAbove,
    required this.onEdit,
    required this.onDelete,
    required this.onDismissActions,
    required this.onLongPressStart,
    required this.onLongPressMoveUpdate,
    required this.onLongPressEnd,
    required this.onLongPressCancel,
  });

  final Widget child;
  final VoidCallback onPointerDown;
  final bool enabled;
  final bool showActions;
  final bool actionAlignRight;
  final bool actionShowAbove;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDismissActions;
  final ValueChanged<LongPressStartDetails> onLongPressStart;
  final ValueChanged<LongPressMoveUpdateDetails> onLongPressMoveUpdate;
  final ValueChanged<LongPressEndDetails> onLongPressEnd;
  final VoidCallback onLongPressCancel;

  @override
  State<_ServerCardInteraction> createState() => _ServerCardInteractionState();
}

class _ServerCardInteractionState extends State<_ServerCardInteraction> {
  final _overlayController = OverlayPortalController();
  final _layerLink = LayerLink();
  final _tapRegionGroup = Object();
  var _overlaySyncVersion = 0;

  void _scheduleOverlaySync() {
    final version = ++_overlaySyncVersion;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || version != _overlaySyncVersion) return;
      if (widget.showActions) {
        _overlayController.show();
      } else {
        _overlayController.hide();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _ServerCardInteraction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showActions != widget.showActions) {
      _scheduleOverlaySync();
    }
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: _buildActionOverlay,
      child: TapRegion(
        groupId: _tapRegionGroup,
        onTapOutside: widget.showActions
            ? (_) => widget.onDismissActions()
            : null,
        child: CompositedTransformTarget(
          link: _layerLink,
          child: Listener(
            onPointerDown: (_) => widget.onPointerDown(),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onLongPressStart: widget.enabled ? widget.onLongPressStart : null,
              onLongPressMoveUpdate: widget.enabled
                  ? widget.onLongPressMoveUpdate
                  : null,
              onLongPressEnd: widget.enabled ? widget.onLongPressEnd : null,
              onLongPressCancel: widget.enabled
                  ? widget.onLongPressCancel
                  : null,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionOverlay(BuildContext context) {
    final targetAnchor = Alignment(
      widget.actionAlignRight ? 1 : -1,
      widget.actionShowAbove ? -1 : 1,
    );
    final followerAnchor = Alignment(
      widget.actionAlignRight ? 1 : -1,
      widget.actionShowAbove ? 1 : -1,
    );
    return Align(
      alignment: Alignment.topLeft,
      child: CompositedTransformFollower(
        link: _layerLink,
        targetAnchor: targetAnchor,
        followerAnchor: followerAnchor,
        offset: Offset(0, widget.actionShowAbove ? -8 : 8),
        child: TapRegion(
          groupId: _tapRegionGroup,
          child: _ServerActionList(
            editKey: const ValueKey('server-selection-edit-action'),
            deleteKey: const ValueKey('server-selection-delete-action'),
            onEdit: widget.onEdit,
            onDelete: widget.onDelete,
          ),
        ),
      ),
    );
  }
}

class _ServerActionList extends StatelessWidget {
  const _ServerActionList({
    required this.editKey,
    required this.deleteKey,
    required this.onEdit,
    required this.onDelete,
  });

  static const width = 196.0;
  static const itemHeight = 50.0;
  static const height = 101.0;

  final Key editKey;
  final Key deleteKey;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final l = AppL10n.of(context);
    final overlayBackground = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1B1A24)
        : Colors.white;
    return Material(
      color: overlayBackground,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.34),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: colors.cardBorder.withValues(alpha: 0.45),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            SizedBox(
              height: itemHeight,
              child: _ServerActionListItem(
                key: editKey,
                icon: Icons.edit_outlined,
                label: l.serverEditAction,
                color: colors.text,
                onTap: onEdit,
              ),
            ),
            SizedBox(height: 1, child: ColoredBox(color: colors.divider)),
            SizedBox(
              height: itemHeight,
              child: _ServerActionListItem(
                key: deleteKey,
                icon: Icons.delete_outline,
                label: l.serverDeleteAction,
                color: colors.danger,
                onTap: onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerActionListItem extends StatelessWidget {
  const _ServerActionListItem({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ServerStatus { checking, connected, authenticationRequired, unavailable }

class _ServerAvatarCard extends StatelessWidget {
  const _ServerAvatarCard({
    required this.server,
    required this.profileFuture,
    required this.cachedProfile,
    required this.showUsername,
    required this.showAvatar,
    required this.statusFuture,
    required this.avatarKey,
    required this.busy,
    this.dropTarget = false,
    required this.onTap,
  });

  final ServerProfile server;
  final Future<ServerProfileData?> profileFuture;
  final ServerProfileData? cachedProfile;
  final bool showUsername;
  final bool showAvatar;
  final Future<_ServerStatus> statusFuture;
  final GlobalKey? avatarKey;
  final bool busy;
  final bool dropTarget;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final l = AppL10n.of(context);
    return FutureBuilder<ServerProfileData?>(
      future: profileFuture,
      initialData: cachedProfile,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        // OMM 使用用户配置名称；Emby、Jellyfin、飞牛可按设置显示服务端身份。
        // 线路名称不参与卡片标题。
        final supportsUserAvatar =
            server.project == ServerProject.emby ||
            server.project == ServerProject.jellyfin;
        final displayName = serverSelectionDisplayName(
          server,
          profile,
          showUsername: showUsername,
        );
        final configuredAvatarUrl = server.project == ServerProject.ohMyMedia
            ? null
            : supportsUserAvatar
            ? server.avatarUrl
            : (profile?.avatarUrl ?? server.avatarUrl);
        final avatarUrl = supportsUserAvatar && showAvatar
            ? profile?.userAvatarUrl ?? configuredAvatarUrl
            : configuredAvatarUrl;
        final line = server.activeLine;
        final lineName = _serverLineLabel(l, line);
        final projectLabel = serverProjectLabel(l, server.project);
        return Semantics(
          button: true,
          label: l.serverSelectionSelectServer(displayName),
          child: _ServerCardShell(
            project: server.project,
            avatarUrl: avatarUrl,
            fallbackAvatarUrl: configuredAvatarUrl,
            busy: busy,
            onTap: busy ? null : onTap,
            dropTarget: dropTarget,
            child: Padding(
              // 上移卡片内容，抵消 Flutter 字体基线与头像占位带来的视觉下沉。
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.cardTitle(
                                      context,
                                    ).copyWith(fontSize: 15, height: 1.2),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _ServerStatusDot(statusFuture: statusFuture),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              projectLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.muted,
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        key: avatarKey,
                        width: _ServerSelectionMetrics.logoMaskSize,
                        height: _ServerSelectionMetrics.logoMaskSize,
                        child: Center(
                          // 只裁切 Logo 四角，不添加背景、边框、阴影或高光；
                          // 保持 Logo 原有尺寸，统一不同素材的显示形状。
                          child: ClipOval(
                            child: _ServerCardLogo(
                              displayName: displayName,
                              avatarUrl: avatarUrl,
                              project: server.project,
                              colors: colors,
                              size: _ServerSelectionMetrics.logoSize,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lineName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.meta(
                            context,
                          ).copyWith(fontSize: 11, color: colors.muted),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l.serverLineCount(server.lines.length),
                        style: AppText.meta(
                          context,
                        ).copyWith(fontSize: 11, color: colors.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        l.serverLatency,
                        style: AppText.meta(
                          context,
                        ).copyWith(fontSize: 11, color: colors.muted),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        line?.latencyMs == null
                            ? '--'
                            : '${line!.latencyMs} ms',
                        style: AppText.meta(
                          context,
                        ).copyWith(fontSize: 11, color: colors.text),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ServerCardShell extends StatelessWidget {
  const _ServerCardShell({
    required this.child,
    this.project,
    this.avatarUrl,
    this.fallbackAvatarUrl,
    this.busy = false,
    this.dropTarget = false,
    this.onTap,
  });

  final Widget child;
  final ServerProject? project;
  final String? avatarUrl;
  final String? fallbackAvatarUrl;
  final bool busy;
  final bool dropTarget;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundLogo = _serverCardLogoSource(project, avatarUrl);
    final cardColor = isDark
        ? const Color(0xFF1B1A22)
        : const Color(0xFFF7F7FA);
    final glassTint = isDark
        ? Colors.black.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.52);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(_ServerSelectionMetrics.cardRadius),
        border: dropTarget
            ? Border.all(
                color: colors.accent.withValues(alpha: 0.76),
                width: 1.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_ServerSelectionMetrics.cardRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (backgroundLogo != null)
              Positioned(
                top: 12,
                right: 12,
                width: 208,
                height: 208,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: isDark ? 0.16 : 0.10,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 13, sigmaY: 13),
                      child: _ServerCardLogo(
                        displayName: '',
                        avatarUrl: backgroundLogo.startsWith('http')
                            ? backgroundLogo
                            : null,
                        fallbackAvatarUrl: fallbackAvatarUrl,
                        assetPath: backgroundLogo.startsWith('http')
                            ? null
                            : backgroundLogo,
                        project: null,
                        colors: colors,
                        size: 208,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: GlassPanel(
                  borderRadius: BorderRadius.circular(
                    _ServerSelectionMetrics.cardRadius,
                  ),
                  sigma: 19,
                  tint: glassTint,
                  showBorder: false,
                  showHighlight: false,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            Positioned.fill(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: busy ? 0.62 : 1,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(
                      _ServerSelectionMetrics.cardRadius,
                    ),
                    splashColor: colors.text.withValues(alpha: 0.08),
                    highlightColor: colors.text.withValues(alpha: 0.04),
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerCardLogo extends StatelessWidget {
  const _ServerCardLogo({
    required this.displayName,
    required this.avatarUrl,
    required this.project,
    required this.colors,
    required this.size,
    this.assetPath,
    this.fallbackAvatarUrl,
  });

  final String displayName;
  final String? avatarUrl;
  final ServerProject? project;
  final AppColors colors;
  final double size;
  final String? assetPath;
  final String? fallbackAvatarUrl;

  @override
  Widget build(BuildContext context) {
    final source = avatarUrl?.trim();
    final asset = assetPath ?? _serverCardAsset(project);
    final fallback = Center(
      child: Text(
        serverInitials(displayName),
        maxLines: 1,
        style: TextStyle(
          color: colors.text2,
          fontFamily: 'Inter',
          fontSize: size * 0.34,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    Widget assetImage() {
      if (asset == null) return fallback;
      if (asset.endsWith('.svg')) {
        return SvgPicture.asset(
          asset,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => fallback,
        );
      }
      return Image.asset(
        asset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    Widget configuredImage() {
      final configured = fallbackAvatarUrl?.trim();
      if (configured == null || configured.isEmpty || configured == source) {
        return assetImage();
      }
      return CachedNetworkImage(
        cacheManager: AppImageCacheManager.instance,
        imageUrl: configured,
        fit: BoxFit.contain,
        placeholder: (_, __) => assetImage(),
        errorWidget: (_, __, ___) => assetImage(),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: source == null || source.isEmpty
          ? assetImage()
          : CachedNetworkImage(
              cacheManager: AppImageCacheManager.instance,
              imageUrl: source,
              fit: BoxFit.contain,
              placeholder: (_, __) => configuredImage(),
              errorWidget: (_, __, ___) => configuredImage(),
            ),
    );
  }
}

class _ServerStatusDot extends StatelessWidget {
  const _ServerStatusDot({required this.statusFuture});

  final Future<_ServerStatus> statusFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ServerStatus>(
      future: statusFuture,
      initialData: _ServerStatus.checking,
      builder: (context, snapshot) {
        final colors = appColors(context);
        const onlineColor = Color(0xFF65D391);
        const authenticationColor = Color(0xFFFFC857);
        final color = switch (snapshot.data ?? _ServerStatus.checking) {
          _ServerStatus.connected => onlineColor,
          _ServerStatus.authenticationRequired => authenticationColor,
          _ServerStatus.unavailable => colors.danger,
          _ServerStatus.checking => colors.muted2,
        };
        return _dot(color);
      },
    );
  }

  Widget _dot(Color color) {
    return SizedBox(
      width: 8,
      height: 8,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const SizedBox(width: 6, height: 6),
        ),
      ),
    );
  }
}

String? _serverCardLogoSource(ServerProject? project, String? avatarUrl) {
  final remote = avatarUrl?.trim();
  if (remote != null && remote.isNotEmpty) return remote;
  return _serverCardAsset(project);
}

String? _serverCardAsset(ServerProject? project) {
  return serverProjectAvatarAsset(project);
}

String _serverLineLabel(AppL10n l, ServerLine? line) {
  final name = line?.name.trim();
  if (name == null ||
      name.isEmpty ||
      name == l.serverLineDefaultName ||
      name == '主线路' ||
      name == 'Primary line') {
    return l.serverLineMain;
  }
  return name;
}
