import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/api/api_client.dart';
import '../../core/api/dio_factory.dart';
import '../../core/api/server_compatibility.dart';
import '../../core/auth/auth_session_provider.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/models/system.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glass.dart';
import '../../shared/sheet_controls.dart';
import '../../shared/glow_background.dart';
import '../../shared/server_avatar.dart';
import '../home/server_switch_transition.dart';
import 'server_setup_page.dart';

/// 启动和鉴权前的服务器选择页。
///
/// 页面只负责选择服务器和打开创建页。鉴权、线路探测和登录统一交给
/// [ServerSwitchTransitionController]，与首页服务器切换使用同一条路径。
class _ServerSelectionMetrics {
  const _ServerSelectionMetrics._();

  static const cardHeight = 124.0;
  static const cardGap = 12.0;
  static const cardRadius = 23.0;
  static const logoMaskSize = 44.0;
  static const logoSize = 31.0;
  static const addIconSize = 27.0;
}

class ServerSelectionPage extends ConsumerStatefulWidget {
  const ServerSelectionPage({super.key, this.returnAfterSelection = false});

  /// 在已登录页面中打开服务器选择器；选择成功后返回原页面。
  static void requestReturn(BuildContext context) {
    // 应用服务器页和目录子页都由 Material 路由承载，直接让页面栈
    // 完成 pop；onDidRemovePage 会在转场完成、页面真正移除后释放运行态。
    // 独立嵌入的页面没有父选择器，只能保留兼容的普通打开入口。
    if (ServerNavigationScope.of(context)) {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) unawaited(navigator.maybePop());
      return;
    }
    unawaited(openForReturn(context));
  }

  /// 兼容不在应用服务器导航栈中的独立调用方。
  ///
  /// 应用内页面应使用 [requestReturn]，由页面栈完成真实返回；这个入口
  /// 仍保留普通路由打开能力，避免独立设置/测试页面失去选择器入口。
  static Future<void> openForReturn(BuildContext context) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final routeActive = container.read(serverSelectionRouteActiveProvider);
    if (routeActive) return;
    container.read(serverSelectionRouteActiveProvider.notifier).state = true;
    final navigator = Navigator.of(context);
    final route = PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) =>
          const ServerSelectionPage(returnAfterSelection: true),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
    var released = false;
    void releaseResources() {
      if (released) return;
      released = true;
      container.read(serverConfigProvider.notifier).showServerSelection();
    }

    void releaseWhenSettled(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        route.animation?.removeStatusListener(releaseWhenSettled);
        releaseResources();
      }
    }

    try {
      final result = navigator.push<void>(route);
      final animation = route.animation;
      if (animation == null || animation.status == AnimationStatus.completed) {
        releaseResources();
      } else {
        animation.addStatusListener(releaseWhenSettled);
      }
      await result;
    } finally {
      route.animation?.removeStatusListener(releaseWhenSettled);
      releaseResources();
      container.read(serverSelectionRouteActiveProvider.notifier).state = false;
    }
  }

  /// 作为已登录页面上的选择器打开时，成功选择后返回原页面。
  final bool returnAfterSelection;

  @override
  ConsumerState<ServerSelectionPage> createState() =>
      _ServerSelectionPageState();
}

/// 标记应用内真实服务器页面栈。
///
/// 文件浏览器可能被单独嵌入测试页或设置页；只有应用主导航栈内的页面
/// 才应该使用 Material 路由提供的真实交互式 pop，独立嵌入时才启用
/// 兼容返回手势。
class ServerNavigationScope extends InheritedWidget {
  const ServerNavigationScope({super.key, required super.child});

  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<ServerNavigationScope>() !=
        null;
  }

  @override
  bool updateShouldNotify(ServerNavigationScope oldWidget) => false;
}

class _ServerSelectionPageState extends ConsumerState<ServerSelectionPage> {
  final _profileFutures = <String, Future<ServerProfileData?>>{};
  final _statusFutures = <String, Future<_ServerStatus>>{};
  final _avatarKeys = <String, GlobalKey>{};
  var _searchQuery = '';

  GlobalKey _avatarKeyFor(String serverId) {
    return _avatarKeys.putIfAbsent(serverId, GlobalKey.new);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ServerSwitchState>(serverSwitchTransitionProvider, (
      previous,
      next,
    ) {
      if (next.phase == ServerSwitchPhase.finishing &&
          previous?.phase != ServerSwitchPhase.finishing &&
          next.targetServerId != null) {
        unawaited(_completeSelectionIfReady(next.targetServerId!));
      }
      if (previous?.isActive == true && !next.isActive) {
        final serverId = previous?.targetServerId;
        if (serverId != null) {
          unawaited(_completeSelectionIfReady(serverId));
        }
      }
    });
    final colors = appColors(context);
    final config = ref.watch(serverSelectionConfigProvider);
    final servers = config?.servers ?? const <ServerProfile>[];
    final transition = ref.watch(serverSwitchTransitionProvider);
    final activeServerId =
        config?.activeServerId ?? (servers.isEmpty ? null : servers.first.id);
    final visibleServers = _filterServers(servers);

    return PopScope<void>(
      canPop: false,
      child: Scaffold(
        backgroundColor: colors.bg,
        body: GlowBackground(
          child: SafeArea(
            child: Center(
              child: RefreshIndicator(
                color: colors.accent,
                onRefresh: _refreshServers,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 48, 24, 48),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _LibraryHeader(onChanged: _updateSearchQuery),
                          const SizedBox(height: 22),
                          if (servers.isEmpty)
                            Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 360,
                                ),
                                child: _AddServerCard(onTap: _openCreateServer),
                              ),
                            )
                          else ...[
                            if (visibleServers.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                child: Text(
                                  '没有找到匹配的资源库',
                                  textAlign: TextAlign.center,
                                  style: AppText.meta(context),
                                ),
                              ),
                            _ServerStrip(
                              servers: visibleServers,
                              activeServerId: activeServerId,
                              transition: transition,
                              profileFor: _profileFor,
                              cachedProfileFor: _cachedProfileFor,
                              statusFor: _statusFor,
                              avatarKeyFor: _avatarKeyFor,
                              onSelect: (server) =>
                                  unawaited(_selectServer(server)),
                              onAdd: _openCreateServer,
                              onLongPress: (server) =>
                                  unawaited(_showServerActions(server)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _updateSearchQuery(String value) {
    final query = value.trim();
    if (_searchQuery == query) return;
    setState(() => _searchQuery = query);
  }

  Future<void> _refreshServers() async {
    _profileFutures.clear();
    _statusFutures.clear();
    if (!mounted) return;
    setState(() {});

    final config = ref.read(serverSelectionConfigProvider);
    final servers = _filterServers(config?.servers ?? const <ServerProfile>[]);
    try {
      await Future.wait<void>([
        for (final server in servers) _profileFor(server).then<void>((_) {}),
        for (final server in servers) _statusFor(server).then<void>((_) {}),
      ]);
    } catch (_) {
      // 单台服务器探测失败不应让下拉刷新一直处于加载状态；卡片自身会
      // 根据 FutureBuilder 的结果显示对应状态。
    }
  }

  List<ServerProfile> _filterServers(List<ServerProfile> servers) {
    final query = _searchQuery.toLowerCase();
    if (query.isEmpty) return servers;
    return servers
        .where((server) {
          final line = server.activeLine;
          final searchable = [
            server.name,
            _serverProjectLabel(server.project),
            line?.name,
            line?.baseUrl,
          ].whereType<String>().join(' ').toLowerCase();
          return searchable.contains(query);
        })
        .toList(growable: false);
  }

  void _openCreateServer() {
    AppHaptics.selection();
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ServerSetupPage()));
  }

  Future<void> _showServerActions(ServerProfile server) async {
    if (ref.read(serverSwitchTransitionProvider).isActive) return;
    final action = await showGlassSheet<_ServerAction>(
      context: context,
      builder: (context) {
        final c = appColors(context);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHeader(
                icon: Icons.dns_outlined,
                title: '服务器操作',
                subtitle: server.name,
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('编辑服务器'),
                onTap: () => Navigator.of(context).pop(_ServerAction.edit),
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: c.danger),
                title: Text('删除服务器', style: TextStyle(color: c.danger)),
                onTap: () => Navigator.of(context).pop(_ServerAction.delete),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _ServerAction.edit:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ServerSetupPage(serverId: server.id),
          ),
        );
      case _ServerAction.delete:
        await _deleteServer(server);
    }
  }

  Future<void> _deleteServer(ServerProfile server) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除服务器'),
        content: Text('确定删除“${server.name}”及其线路吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(serverConfigProvider.notifier).deleteServer(server.id);
      AppHaptics.medium();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败：${toApiException(error).message}')),
        );
      }
    }
  }

  Future<void> _selectServer(ServerProfile server) async {
    if (ref.read(serverSwitchTransitionProvider).isActive) return;
    final avatarContext = _avatarKeyFor(server.id).currentContext;
    final renderObject = avatarContext?.findRenderObject();
    final avatarOrigin = renderObject is RenderBox && renderObject.hasSize
        ? Rect.fromLTWH(
            renderObject.localToGlobal(Offset.zero).dx,
            renderObject.localToGlobal(Offset.zero).dy,
            renderObject.size.width,
            renderObject.size.height,
          )
        : null;
    await ref
        .read(serverSwitchTransitionProvider.notifier)
        .switchTo(
          server.id,
          allowActiveTarget: true,
          avatarOrigin: avatarOrigin,
          returnToSelectionOnCancel: true,
        );
    if (!mounted) return;
    await _completeSelectionIfReady(server.id);
  }

  Future<void> _completeSelectionIfReady(String serverId) async {
    if (!mounted ||
        ref.read(serverSelectionRequestedProvider) == false ||
        (ref.read(serverSwitchTransitionProvider).isActive &&
            ref.read(serverSwitchTransitionProvider).phase !=
                ServerSwitchPhase.finishing) ||
        ref.read(serverSelectionReadyProvider) == false ||
        ref.read(serverConfigProvider)?.activeServerId != serverId) {
      return;
    }
    ref.read(serverConfigProvider.notifier).completeServerSelection();
    if (widget.returnAfterSelection && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<ServerProfileData?> _profileFor(ServerProfile server) {
    return _profileFutures.putIfAbsent(server.id, () => _loadProfile(server));
  }

  Future<_ServerStatus> _statusFor(ServerProfile server) {
    final line = server.activeLine;
    final key = [server.id, line?.id, line?.baseUrl, line?.enabled].join('|');
    return _statusFutures.putIfAbsent(key, () => _detectStatus(server));
  }

  Future<_ServerStatus> _detectStatus(ServerProfile server) async {
    final line = server.activeLine;
    final project = server.project;
    if (line == null || !line.enabled || project == null) {
      return _ServerStatus.unavailable;
    }
    // 文件来源的连接由文件浏览页在挂载来源时完成验证；选择器这里只反映
    // 线路是否被启用，避免在卡片列表中重复创建 SMB/WebDAV 连接。
    if (project.isFileSource) return _ServerStatus.connected;

    final probe = await ref
        .read(serverLineProbeCoordinatorProvider)
        .probe(line, expectedProjectName: server.projectName);
    if (!probe.success) {
      return probe.requiresAuthentication
          ? _ServerStatus.authenticationRequired
          : _ServerStatus.unavailable;
    }

    return _ServerStatus.connected;
  }

  ServerProfileData? _cachedProfileFor(ServerProfile server) {
    return ref.read(serverProfileCacheRepoProvider).load(server.id);
  }

  Future<ServerProfileData?> _loadProfile(ServerProfile server) async {
    final cached = _cachedProfileFor(server);
    final project = server.project;
    if (project == ServerProject.emby || project == ServerProject.jellyfin) {
      return _loadEmbyOrJellyfinProfile(server, cached, project!);
    }
    if (project != ServerProject.ohMyMedia) {
      final profile = ServerProfileData(
        name: server.name,
        avatarUrl: server.avatarUrl,
      );
      return profile;
    }
    final line = server.activeLine;
    if (line == null) {
      return cached;
    }
    try {
      final profile = await ApiClient.fromConfig(
        ServerConfig(
          baseUrl: line.baseUrl,
          lines: [line],
          servers: [server],
          activeServerId: server.id,
        ),
      ).systemExtended.serverProfile();
      await ref.read(serverProfileCacheRepoProvider).save(server.id, profile);
      return profile;
    } catch (_) {
      return cached;
    }
  }

  Future<ServerProfileData?> _loadEmbyOrJellyfinProfile(
    ServerProfile server,
    ServerProfileData? cached,
    ServerProject project,
  ) async {
    final sessionRepository = ref
        .read(authSessionRepositoryProvider)
        .forServer(server.id, allowLegacyMigration: false);
    final session = await sessionRepository.load();
    if (session == null || !session.hasAccessToken) {
      return cached ?? _fallbackProfile(server);
    }

    final line = server.activeLine;
    if (line == null) return cached ?? _fallbackProfile(server);

    try {
      final client = ApiClient.fromConfig(
        ServerConfig(
          baseUrl: line.baseUrl,
          lines: [line],
          servers: [server],
          activeServerId: server.id,
        ),
        sessionRepository: sessionRepository,
      );
      final userName = project == ServerProject.emby
          ? await _loadEmbyUserName(client, session.userId)
          : (await client.jellyfin.currentUser()).name;
      final normalizedName = userName.trim();
      if (normalizedName.isEmpty) {
        return cached ?? _fallbackProfile(server);
      }
      final profile = ServerProfileData(
        name: normalizedName,
        avatarUrl: server.avatarUrl ?? cached?.avatarUrl,
      );
      await ref.read(serverProfileCacheRepoProvider).save(server.id, profile);
      return profile;
    } catch (_) {
      return cached ?? _fallbackProfile(server);
    }
  }

  Future<String> _loadEmbyUserName(ApiClient client, String? userId) async {
    final normalizedUserId = userId?.trim() ?? '';
    if (normalizedUserId.isEmpty) return '';
    return (await client.emby.user(normalizedUserId)).name;
  }

  ServerProfileData _fallbackProfile(ServerProfile server) {
    return ServerProfileData(name: server.name, avatarUrl: server.avatarUrl);
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('资源库', style: AppText.pageTitle(context).copyWith(fontSize: 24)),
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
                hintText: '搜索资源库',
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
    );
  }
}

class _AddServerCard extends StatelessWidget {
  const _AddServerCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '添加服务器',
      child: SizedBox(
        width: double.infinity,
        height: _ServerSelectionMetrics.cardHeight,
        child: _ServerCardShell(
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
                  Text('添加服务器', style: AppText.cardTitle(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServerStrip extends StatelessWidget {
  const _ServerStrip({
    required this.servers,
    required this.activeServerId,
    required this.transition,
    required this.profileFor,
    required this.cachedProfileFor,
    required this.statusFor,
    required this.avatarKeyFor,
    required this.onSelect,
    required this.onAdd,
    required this.onLongPress,
  });

  final List<ServerProfile> servers;
  final String? activeServerId;
  final ServerSwitchState transition;
  final Future<ServerProfileData?> Function(ServerProfile server) profileFor;
  final ServerProfileData? Function(ServerProfile server) cachedProfileFor;
  final Future<_ServerStatus> Function(ServerProfile server) statusFor;
  final GlobalKey Function(String serverId) avatarKeyFor;
  final ValueChanged<ServerProfile> onSelect;
  final VoidCallback onAdd;
  final ValueChanged<ServerProfile> onLongPress;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: _ServerSelectionMetrics.cardGap,
        mainAxisSpacing: _ServerSelectionMetrics.cardGap,
        mainAxisExtent: _ServerSelectionMetrics.cardHeight,
      ),
      itemCount: servers.length + 1,
      itemBuilder: (context, index) {
        if (index == servers.length) {
          return _AddServerCard(onTap: onAdd);
        }
        final server = servers[index];
        return _ServerAvatarCard(
          server: server,
          profileFuture: profileFor(server),
          cachedProfile: cachedProfileFor(server),
          statusFuture: statusFor(server),
          avatarKey: avatarKeyFor(server.id),
          active: server.id == activeServerId,
          busy: transition.isActive && transition.targetServerId == server.id,
          onTap: () => onSelect(server),
          onLongPress: () => onLongPress(server),
        );
      },
    );
  }
}

enum _ServerAction { edit, delete }

enum _ServerStatus { checking, connected, authenticationRequired, unavailable }

class _ServerAvatarCard extends StatelessWidget {
  const _ServerAvatarCard({
    required this.server,
    required this.profileFuture,
    required this.cachedProfile,
    required this.statusFuture,
    required this.avatarKey,
    required this.active,
    required this.busy,
    required this.onTap,
    required this.onLongPress,
  });

  final ServerProfile server;
  final Future<ServerProfileData?> profileFuture;
  final ServerProfileData? cachedProfile;
  final Future<_ServerStatus> statusFuture;
  final GlobalKey avatarKey;
  final bool active;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return FutureBuilder<ServerProfileData?>(
      future: profileFuture,
      initialData: cachedProfile,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        // OMM、Emby、Jellyfin 可以从服务端取得真实名称；其他类型只显示
        // 用户配置名称。线路名称不参与卡片标题。
        final supportsRemoteName =
            server.project == ServerProject.ohMyMedia ||
            server.project == ServerProject.emby ||
            server.project == ServerProject.jellyfin;
        final profileName = profile?.name.trim() ?? '';
        final displayName = supportsRemoteName && profileName.isNotEmpty
            ? profileName
            : server.name;
        final avatarUrl = profile?.avatarUrl ?? server.avatarUrl;
        final line = server.activeLine;
        final lineName = _serverLineLabel(line);
        final projectLabel = _serverProjectLabel(server.project);
        return Semantics(
          button: true,
          label: '选择$displayName',
          child: _ServerCardShell(
            project: server.project,
            avatarUrl: avatarUrl,
            selected: active,
            busy: busy,
            onTap: busy ? null : onTap,
            onLongPress: busy ? null : onLongPress,
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
                        '${server.lines.length}条线路',
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
                        '延迟',
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
    this.selected = false,
    this.busy = false,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final ServerProject? project;
  final String? avatarUrl;
  final bool selected;
  final bool busy;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

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
        border: selected
            ? Border.all(
                color: colors.text.withValues(alpha: isDark ? 0.24 : 0.18),
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
                    onLongPress: onLongPress,
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
  });

  final String displayName;
  final String? avatarUrl;
  final ServerProject? project;
  final AppColors colors;
  final double size;
  final String? assetPath;

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

    return SizedBox(
      width: size,
      height: size,
      child: source == null || source.isEmpty
          ? assetImage()
          : CachedNetworkImage(
              imageUrl: source,
              fit: BoxFit.contain,
              placeholder: (_, __) => assetImage(),
              errorWidget: (_, __, ___) => assetImage(),
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
      builder: (context, snapshot) => _AnimatedServerStatusDot(
        status: snapshot.data ?? _ServerStatus.checking,
      ),
    );
  }
}

class _AnimatedServerStatusDot extends StatefulWidget {
  const _AnimatedServerStatusDot({required this.status});

  final _ServerStatus status;

  @override
  State<_AnimatedServerStatusDot> createState() =>
      _AnimatedServerStatusDotState();
}

class _AnimatedServerStatusDotState extends State<_AnimatedServerStatusDot> {
  bool _disableAnimations = false;
  Timer? _pulseTimer;
  var _pulseStep = 7;

  // 低频状态反馈不需要跟随屏幕刷新率，200ms 一次约为 5fps。
  static const _pulseInterval = Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _AnimatedServerStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == oldWidget.status) return;
    _syncAnimation();
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    const onlineColor = Color(0xFF65D391);
    const authenticationColor = Color(0xFFFFC857);
    final color = switch (widget.status) {
      _ServerStatus.connected => onlineColor,
      _ServerStatus.authenticationRequired => authenticationColor,
      _ServerStatus.unavailable => colors.danger,
      _ServerStatus.checking => colors.muted2,
    };
    if (widget.status != _ServerStatus.connected || _disableAnimations) {
      return _dot(color, 1, 1);
    }
    final phase = _pulseStep <= 7 ? _pulseStep : 14 - _pulseStep;
    final value = Curves.easeInOut.transform(phase / 7);
    return _dot(onlineColor, 0.78 + (value * 0.22), 0.88 + (value * 0.16));
  }

  void _syncAnimation() {
    if (widget.status == _ServerStatus.connected && !_disableAnimations) {
      if (_pulseTimer != null) return;
      _pulseStep = 0;
      _pulseTimer = Timer.periodic(_pulseInterval, (_) {
        if (!mounted ||
            widget.status != _ServerStatus.connected ||
            _disableAnimations) {
          return;
        }
        setState(() {
          _pulseStep = (_pulseStep + 1) % 14;
        });
      });
      return;
    }
    _pulseTimer?.cancel();
    _pulseTimer = null;
    _pulseStep = 7;
  }

  Widget _dot(Color color, double opacity, double scale) {
    return SizedBox(
      width: 8,
      height: 8,
      child: Center(
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const SizedBox(width: 6, height: 6),
            ),
          ),
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
  final asset = serverProjectAvatarAsset(project);
  if (asset == 'assets/server_avatars/oh_my_media.png') {
    return 'assets/server_avatars/oh_my_media_logo.png';
  }
  return asset;
}

String _serverProjectLabel(ServerProject? project) {
  return switch (project) {
    ServerProject.ohMyMedia => 'Oh My Media',
    ServerProject.dbOnline => 'DB Online',
    ServerProject.emby => 'Emby',
    ServerProject.jellyfin => 'Jellyfin',
    ServerProject.smb => 'SMB',
    ServerProject.webDav => 'WebDAV',
    ServerProject.openList => 'OpenList',
    null => '服务器',
  };
}

String _serverLineLabel(ServerLine? line) {
  final name = line?.name.trim();
  if (name == null || name.isEmpty || name == '服务器线路') return '主线路';
  return name;
}
