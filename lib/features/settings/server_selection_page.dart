import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/dio_factory.dart';
import '../../core/api/server_compatibility.dart';
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

  static const avatarSize = 93.0;
  static const addIconSize = 40.0;
  static const itemWidth = 108.0;
  static const gap = 13.0;
  static const hoverRadius = 18.0;
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

  @override
  Widget build(BuildContext context) {
    ref.listen<ServerSwitchState>(serverSwitchTransitionProvider, (
      previous,
      next,
    ) {
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

    return PopScope<void>(
      canPop: false,
      child: Scaffold(
        backgroundColor: colors.bg,
        body: GlowBackground(
          child: SafeArea(
            child: Center(
              child: SizedBox(
                width: double.infinity,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _BrandHeader(colors: colors),
                                const SizedBox(height: 42),
                                Text(
                                  servers.isEmpty ? '添加服务器' : '选择服务器',
                                  textAlign: TextAlign.center,
                                  style: AppText.pageTitle(
                                    context,
                                  ).copyWith(fontSize: 30),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  servers.isEmpty
                                      ? '还没有配置服务器，点击头像添加。'
                                      : '选择要连接的服务器',
                                  textAlign: TextAlign.center,
                                  style: AppText.body(
                                    context,
                                  ).copyWith(color: colors.muted, fontSize: 15),
                                ),
                                const SizedBox(height: 34),
                                if (servers.isEmpty)
                                  _AddServerCard(onTap: _openCreateServer),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (servers.isNotEmpty)
                        _ServerStrip(
                          servers: servers,
                          transition: transition,
                          profileFor: _profileFor,
                          cachedProfileFor: _cachedProfileFor,
                          onSelect: (server) =>
                              unawaited(_selectServer(server)),
                          onAdd: _openCreateServer,
                          onLongPress: (server) =>
                              unawaited(_showServerActions(server)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
    await ref
        .read(serverSwitchTransitionProvider.notifier)
        .switchTo(
          server.id,
          allowActiveTarget: true,
          returnToSelectionOnCancel: true,
        );
    if (!mounted) return;
    await _completeSelectionIfReady(server.id);
  }

  Future<void> _completeSelectionIfReady(String serverId) async {
    if (!mounted ||
        ref.read(serverSelectionRequestedProvider) == false ||
        ref.read(serverSwitchTransitionProvider).isActive ||
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

  ServerProfileData? _cachedProfileFor(ServerProfile server) {
    return ref.read(serverProfileCacheRepoProvider).load(server.id);
  }

  Future<ServerProfileData?> _loadProfile(ServerProfile server) async {
    final cached = _cachedProfileFor(server);
    if (server.project != ServerProject.ohMyMedia) {
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
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colors.text.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/branding/oh_my_media_logo.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              semanticLabel: 'Oh-My-Media',
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Oh-My-Media',
          style: AppText.cardTitle(
            context,
          ).copyWith(fontSize: 18, letterSpacing: 0.3),
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
    final colors = appColors(context);
    return Semantics(
      button: true,
      label: '添加服务器',
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(
              _ServerSelectionMetrics.hoverRadius,
            ),
            splashColor: colors.accent.withValues(alpha: 0.12),
            highlightColor: colors.accent.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Column(
                children: [
                  Container(
                    width: _ServerSelectionMetrics.avatarSize,
                    height: _ServerSelectionMetrics.avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colors.accent.withValues(alpha: 0.95),
                          colors.accent.withValues(alpha: 0.52),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.94),
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.accent.withValues(alpha: 0.2),
                          blurRadius: 26,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: _ServerSelectionMetrics.addIconSize,
                    ),
                  ),
                  const SizedBox(height: 14),
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
    required this.transition,
    required this.profileFor,
    required this.cachedProfileFor,
    required this.onSelect,
    required this.onAdd,
    required this.onLongPress,
  });

  final List<ServerProfile> servers;
  final ServerSwitchState transition;
  final Future<ServerProfileData?> Function(ServerProfile server) profileFor;
  final ServerProfileData? Function(ServerProfile server) cachedProfileFor;
  final ValueChanged<ServerProfile> onSelect;
  final VoidCallback onAdd;
  final ValueChanged<ServerProfile> onLongPress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const itemWidth = _ServerSelectionMetrics.itemWidth;
        const gap = _ServerSelectionMetrics.gap;
        final itemCount = servers.length + 1;
        final gaps = itemCount - 1;
        final contentWidth = itemCount * itemWidth + gaps * gap;
        final horizontalPadding = contentWidth < constraints.maxWidth
            ? (constraints.maxWidth - contentWidth) / 2
            : 0.0;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < servers.length; index++) ...[
                if (index > 0) const SizedBox(width: gap),
                SizedBox(
                  width: itemWidth,
                  child: _ServerAvatarCard(
                    server: servers[index],
                    profileFuture: profileFor(servers[index]),
                    cachedProfile: cachedProfileFor(servers[index]),
                    busy: transition.targetServerId == servers[index].id,
                    onTap: () => onSelect(servers[index]),
                    onLongPress: () => onLongPress(servers[index]),
                  ),
                ),
              ],
              const SizedBox(width: gap),
              SizedBox(
                width: itemWidth,
                child: _AddServerAvatarCard(onTap: onAdd),
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _ServerAction { edit, delete }

class _AddServerAvatarCard extends StatelessWidget {
  const _AddServerAvatarCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Semantics(
      button: true,
      label: '添加服务器',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(
            _ServerSelectionMetrics.hoverRadius,
          ),
          splashColor: colors.accent.withValues(alpha: 0.12),
          highlightColor: colors.accent.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Column(
              children: [
                Container(
                  width: _ServerSelectionMetrics.avatarSize,
                  height: _ServerSelectionMetrics.avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.accent.withValues(alpha: 0.95),
                        colors.accent.withValues(alpha: 0.52),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.94),
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.accent.withValues(alpha: 0.2),
                        blurRadius: 26,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    size: _ServerSelectionMetrics.addIconSize,
                  ),
                ),
                const SizedBox(height: 14),
                Text('添加服务器', style: AppText.cardTitle(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServerAvatarCard extends StatelessWidget {
  const _ServerAvatarCard({
    required this.server,
    required this.profileFuture,
    required this.cachedProfile,
    required this.busy,
    required this.onTap,
    required this.onLongPress,
  });

  final ServerProfile server;
  final Future<ServerProfileData?> profileFuture;
  final ServerProfileData? cachedProfile;
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
        final displayName = profile?.name.trim().isNotEmpty == true
            ? profile!.name.trim()
            : server.name;
        final avatarUrl = profile?.avatarUrl ?? server.avatarUrl;
        return Semantics(
          button: true,
          label: '选择$displayName',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: busy ? null : onTap,
              onLongPress: busy ? null : onLongPress,
              borderRadius: BorderRadius.circular(
                _ServerSelectionMetrics.hoverRadius,
              ),
              splashColor: colors.accent.withValues(alpha: 0.12),
              highlightColor: colors.accent.withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),
                child: Column(
                  children: [
                    ServerAvatar(
                      displayName: displayName,
                      avatarUrl: avatarUrl,
                      size: _ServerSelectionMetrics.avatarSize,
                      busy: busy,
                      colors: colors,
                      project: server.project,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppText.cardTitle(context).copyWith(fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
