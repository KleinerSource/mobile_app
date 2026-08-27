import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/server_compatibility.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/models/system.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';
import '../../shared/server_avatar.dart';
import '../home/server_switch_transition.dart';
import 'server_setup_page.dart';

/// 启动和鉴权前的服务器选择页。
///
/// 页面只负责选择服务器和打开创建页。鉴权、线路探测和登录统一交给
/// [ServerSwitchTransitionController]，与首页服务器切换使用同一条路径。
class ServerSelectionPage extends ConsumerStatefulWidget {
  const ServerSelectionPage({super.key});

  @override
  ConsumerState<ServerSelectionPage> createState() =>
      _ServerSelectionPageState();
}

class _ServerSelectionPageState extends ConsumerState<ServerSelectionPage> {
  final _profileFutures = <String, Future<ServerProfileData?>>{};

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final config = ref.watch(serverConfigProvider);
    final servers = config?.servers ?? const <ServerProfile>[];
    final transition = ref.watch(serverSwitchTransitionProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: GlowBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 48),
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
                      style: AppText.pageTitle(context).copyWith(fontSize: 30),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      servers.isEmpty ? '还没有配置服务器，点击头像添加。' : '选择要连接的服务器',
                      textAlign: TextAlign.center,
                      style: AppText.body(
                        context,
                      ).copyWith(color: colors.muted, fontSize: 15),
                    ),
                    const SizedBox(height: 34),
                    if (servers.isEmpty)
                      _AddServerCard(onTap: _openCreateServer)
                    else
                      _ServerStrip(
                        servers: servers,
                        transition: transition,
                        profileFor: _profileFor,
                        cachedProfileFor: _cachedProfileFor,
                        onSelect: (server) => unawaited(_selectServer(server)),
                      ),
                    if (servers.length == 1) ...[
                      const SizedBox(height: 20),
                      TextButton.icon(
                        onPressed: transition.isActive ? null : _openEditServer,
                        icon: const Icon(Icons.edit_outlined, size: 17),
                        label: const Text('编辑服务器地址'),
                        style: TextButton.styleFrom(
                          foregroundColor: colors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openCreateServer() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ServerSetupPage()));
  }

  void _openEditServer() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ServerSetupPage()));
  }

  Future<void> _selectServer(ServerProfile server) async {
    if (ref.read(serverSwitchTransitionProvider).isActive) return;
    await ref
        .read(serverSwitchTransitionProvider.notifier)
        .switchTo(server.id, allowActiveTarget: true);
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
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Column(
              children: [
                Container(
                  width: 116,
                  height: 116,
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
                  child: const Icon(Icons.add_rounded, size: 50),
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

class _ServerStrip extends StatelessWidget {
  const _ServerStrip({
    required this.servers,
    required this.transition,
    required this.profileFor,
    required this.cachedProfileFor,
    required this.onSelect,
  });

  final List<ServerProfile> servers;
  final ServerSwitchState transition;
  final Future<ServerProfileData?> Function(ServerProfile server) profileFor;
  final ServerProfileData? Function(ServerProfile server) cachedProfileFor;
  final ValueChanged<ServerProfile> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const itemWidth = 140.0;
        const gap = 22.0;
        final gaps = servers.length > 1 ? servers.length - 1 : 0;
        final contentWidth = servers.length * itemWidth + gaps * gap;
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
                  ),
                ),
              ],
            ],
          ),
        );
      },
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
  });

  final ServerProfile server;
  final Future<ServerProfileData?> profileFuture;
  final ServerProfileData? cachedProfile;
  final bool busy;
  final VoidCallback onTap;

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
              borderRadius: BorderRadius.circular(22),
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
                      size: 116,
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
