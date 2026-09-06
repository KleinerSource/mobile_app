import 'package:omm/shared/server_presentation.dart';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/api/api_client.dart';
import '../../core/api/dio_factory.dart';
import '../../core/api/server_compatibility.dart';
import '../../core/auth/auth_session_provider.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/config/server_profile_runtime_loader.dart';
import '../../core/config/server_line_probe.dart';
import '../../core/models/system.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../features/cache/image_cache_manager.dart';
import '../../shared/glass.dart';
import '../../shared/glow_background.dart';
import '../../shared/server_avatar.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import '../home/server_switch_transition.dart';
import 'package:omm/core/sources/media/media_browser/media_browser_config.dart';
import 'server_selection_display_settings.dart';
import 'server_setup_page.dart';

part 'server_selection_cards.dart';

part 'server_selection_operations.dart';

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
  void _updateViewState(VoidCallback update) => setState(update);

  final _profileFutures = <String, Future<ServerProfileData?>>{};
  final _statusFutures = <String, Future<_ServerStatus>>{};
  final _avatarKeys = <String, GlobalKey>{};
  final _listScrollController = ScrollController();
  var _refreshInFlight = false;
  var _searchQuery = '';

  @override
  void dispose() {
    _listScrollController.dispose();
    super.dispose();
  }

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
    final l = AppL10n.of(context);
    final config = ref.watch(serverSelectionConfigProvider);
    final servers = config?.servers ?? const <ServerProfile>[];
    final transition = ref.watch(serverSwitchTransitionProvider);
    final showUsername = ref.watch(serverSelectionShowUsernameProvider);
    final showAvatar = ref.watch(serverSelectionShowAvatarProvider);
    final searchEnabled = servers.length > 20;
    final visibleServers = searchEnabled ? _filterServers(servers, l) : servers;
    // 列表底部穿透安全区滚动；安全区高度并入列表内边距，停靠时保持
    // 与原先 48+12 相同的呼吸空间。
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return PopScope<void>(
      canPop: false,
      child: Scaffold(
        backgroundColor: colors.bg,
        body: GlowBackground(
          child: SafeArea(
            bottom: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: ConstrainedBox(
                  // 768 = 720 内容宽 + 两侧各 24 留白：ListView 按自身视口
                  // 裁切，横向留白必须放进列表 padding，否则卡片阴影会在
                  // 左右两侧被视口边缘切掉。顶部 12 与头部下方 10 合计保持
                  // 原 22 的间距，同时给首行阴影留出绘制空间。
                  constraints: const BoxConstraints(maxWidth: 768),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _ConnectionHeader(
                          onChanged: _updateSearchQuery,
                          showSearch: searchEnabled,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: RefreshIndicator(
                          color: colors.accent,
                          onRefresh: _refreshServers,
                          child: ListView(
                            controller: _listScrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              24,
                              12,
                              24,
                              60 + safeBottom,
                            ),
                            children: [
                              if (servers.isEmpty)
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final cardWidth =
                                        (constraints.maxWidth -
                                            _ServerSelectionMetrics.cardGap) /
                                        2;
                                    return Align(
                                      alignment: Alignment.centerLeft,
                                      child: SizedBox(
                                        width: cardWidth,
                                        child: _AddServerCard(
                                          onTap: _openCreateServer,
                                        ),
                                      ),
                                    );
                                  },
                                )
                              else if (visibleServers.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                  child: Text(
                                    l.serverSelectionNoMatch,
                                    textAlign: TextAlign.center,
                                    style: AppText.meta(context),
                                  ),
                                )
                              else
                                _ServerStrip(
                                  servers: visibleServers,
                                  transition: transition,
                                  profileFor: _profileFor,
                                  cachedProfileFor: _cachedProfileFor,
                                  showUsername: showUsername,
                                  showAvatar: showAvatar,
                                  statusFor: _statusFor,
                                  avatarKeyFor: _avatarKeyFor,
                                  scrollController: _listScrollController,
                                  reorderEnabled:
                                      (!searchEnabled ||
                                          _searchQuery.isEmpty) &&
                                      !transition.isActive &&
                                      servers.length >= 2,
                                  onSelect: (server) =>
                                      unawaited(_selectServer(server)),
                                  onAdd: _openCreateServer,
                                  onEdit: _editServer,
                                  onDelete: (server) =>
                                      unawaited(_deleteServer(server)),
                                  onReorder: (oldIndex, newIndex) => ref
                                      .read(serverConfigProvider.notifier)
                                      .reorderServers(oldIndex, newIndex),
                                ),
                            ],
                          ),
                        ),
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

  void _updateSearchQuery(String value) {
    final query = value.trim();
    if (_searchQuery == query) return;
    setState(() => _searchQuery = query);
  }

  List<ServerProfile> _filterServers(List<ServerProfile> servers, AppL10n l) {
    final query = _searchQuery.toLowerCase();
    if (query.isEmpty) return servers;
    return servers
        .where((server) {
          final line = server.activeLine;
          final searchable = [
            server.name,
            serverProjectLabel(l, server.project),
            line?.name,
            line?.baseUrl,
          ].whereType<String>().join(' ').toLowerCase();
          return searchable.contains(query);
        })
        .toList(growable: false);
  }

  ServerProfileData? _cachedProfileFor(ServerProfile server) {
    if (server.project == ServerProject.ohMyMedia) return null;
    return ref.read(serverProfileCacheRepoProvider).load(server.id);
  }

  ServerProfileData _fallbackProfile(ServerProfile server) {
    return ServerProfileData(name: server.name, avatarUrl: server.avatarUrl);
  }
}
