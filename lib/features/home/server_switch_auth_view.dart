part of 'server_switch_transition.dart';

// 状态及资源所有权保留在页面；此扩展只组织同一职责的方法。
extension _ServerSwitchAuthView on _ServerSwitchTransitionOverlayState {
  Widget _buildChecking(
    BuildContext context,
    AppColors colors,
    ServerProfile server,
  ) {
    final l = AppL10n.of(context);
    final profile = _cachedProfileFor(server);
    final name = _displayNameFor(server, profile);
    return Column(
      key: const ValueKey('server-switch-checking'),
      children: [
        Text(
          l.homeSwitchConnecting(name),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.pageTitle(context).copyWith(fontSize: 25),
        ),
        const SizedBox(height: 16),
        Text(
          l.homeSwitchCheckingAuth,
          textAlign: TextAlign.center,
          style: AppText.body(
            context,
          ).copyWith(color: colors.muted, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildLogin(
    BuildContext context,
    AppColors colors,
    ServerProfile server,
    bool requiresTotp,
    String? message,
  ) {
    final l = AppL10n.of(context);
    final profile = _cachedProfileFor(server);
    final name = _displayNameFor(server, profile);
    final rawError =
        (_localError?.trim().isNotEmpty == true ? _localError : message)
            ?.trim();
    final error = rawError == null
        ? null
        : localizedErrorMessage(l, rawError, translateEmbeddedErrorCodes: true);
    // 头像由外层转场统一绘制在屏幕中心，表单从头像下方淡入，避免
    // 飞行头像交接到另一套纵向布局时发生跳变。
    return Column(
      key: const ValueKey('server-switch-login'),
      children: [
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.pageTitle(context).copyWith(fontSize: 25),
        ),
        const SizedBox(height: 16),
        Text(
          requiresTotp
              ? l.homeSwitchTotpHint
              : server.project == ServerProject.emby ||
                    server.project == ServerProject.jellyfin ||
                    server.project == ServerProject.feiniu
              ? l.homeSwitchUsernamePasswordHint
              : l.homeSwitchPasswordHint,
          textAlign: TextAlign.center,
          style: AppText.body(
            context,
          ).copyWith(color: colors.muted, fontSize: 15),
        ),
        const SizedBox(height: 24),
        if (requiresTotp) ...[
          TotpInputField(
            controller: _totpController,
            enabled: !_loginBusy,
            autofocus: true,
            onCompleted: (_) => _submitTotp(),
          ),
        ] else ...[
          // Emby/Jellyfin/飞牛影视以用户名 + 密码登录；OMM/DBO 只有密码。
          if (server.project == ServerProject.emby ||
              server.project == ServerProject.jellyfin ||
              server.project == ServerProject.feiniu) ...[
            _input(
              context,
              controller: _usernameController,
              label: l.homeSwitchUsernameLabel,
              icon: Icons.person_outline,
              enabled: !_loginBusy,
              onSubmitted: (_) => _submitLogin(),
            ),
            const SizedBox(height: 12),
          ],
          _input(
            context,
            controller: _passwordController,
            label: l.homeSwitchPasswordLabel,
            obscureText: true,
            icon: Icons.key_outlined,
            enabled: !_loginBusy,
            onSubmitted: (_) => _submitLogin(),
          ),
        ],
        if (error != null && error.isNotEmpty) ...[
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerLeft, child: ShakeErrorText(error)),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _loginBusy
                ? null
                : requiresTotp
                ? _submitTotp
                : _submitLogin,
            icon: _loginBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    requiresTotp
                        ? Icons.verified_user_outlined
                        : Icons.login_rounded,
                  ),
            label: Text(
              _loginBusy
                  ? l.homeSwitchVerifying
                  : requiresTotp
                  ? l.homeSwitchVerifyAndSwitch
                  : l.homeSwitchSignInAndSwitch,
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _loginBusy
              ? null
              : requiresTotp
              ? _backToPassword
              : _cancel,
          icon: Icon(
            requiresTotp ? Icons.arrow_back_rounded : Icons.close_rounded,
            size: 18,
          ),
          label: Text(
            requiresTotp ? l.homeSwitchBackToPassword : l.homeSwitchCancel,
          ),
        ),
      ],
    );
  }

  Widget _buildApiKeyRequired(
    BuildContext context,
    AppColors colors,
    ServerProfile server,
    String? message,
  ) {
    final l = AppL10n.of(context);
    final profile = _cachedProfileFor(server);
    final name = _displayNameFor(server, profile);
    final rawError =
        (_localError?.trim().isNotEmpty == true ? _localError : message)
            ?.trim();
    final error = rawError == null
        ? null
        : localizedErrorMessage(l, rawError, translateEmbeddedErrorCodes: true);
    return Column(
      key: const ValueKey('server-switch-api-key'),
      children: [
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.pageTitle(context).copyWith(fontSize: 25),
        ),
        const SizedBox(height: 16),
        Text(
          l.homeSwitchStashApiKeyHint,
          textAlign: TextAlign.center,
          style: AppText.body(
            context,
          ).copyWith(color: colors.muted, fontSize: 15),
        ),
        const SizedBox(height: 24),
        _input(
          context,
          controller: _apiKeyController,
          label: l.serverSetupStashApiKeyLabel,
          obscureText: true,
          icon: Icons.key_outlined,
          enabled: !_loginBusy,
          onSubmitted: (_) => _submitApiKey(),
        ),
        if (error != null && error.isNotEmpty) ...[
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerLeft, child: ShakeErrorText(error)),
        ],
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _loginBusy ? null : _submitApiKey,
            icon: _loginBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_user_outlined),
            label: Text(
              _loginBusy ? l.homeSwitchVerifying : l.homeSwitchVerifyAndSwitch,
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _loginBusy ? null : _cancel,
          icon: const Icon(Icons.close_rounded, size: 18),
          label: Text(l.homeSwitchCancel),
        ),
      ],
    );
  }

  String? _resolveStateMessage(AppL10n l, ServerSwitchState transition) {
    return switch (transition.messageKind) {
      ServerSwitchMessageKind.restoreFailed =>
        transition.message?.trim().isNotEmpty == true
            ? l.homeSwitchRestoreFailed(
                localizedErrorMessage(
                  l,
                  transition.message!.trim(),
                  translateEmbeddedErrorCodes: true,
                ),
              )
            : l.homeSwitchAuthFailed,
      ServerSwitchMessageKind.connectionFailed => l.homeSwitchConnectionFailed,
      ServerSwitchMessageKind.invalidTarget => l.homeSwitchInvalidTarget,
      ServerSwitchMessageKind.authCheckTimeout => l.homeSwitchAuthTimeout,
      null =>
        transition.message == null
            ? null
            : localizedErrorMessage(
                l,
                transition.message!,
                translateEmbeddedErrorCodes: true,
              ),
    };
  }

  Widget _buildError(
    BuildContext context,
    AppColors colors,
    ServerProfile server,
    ServerSwitchState transition,
  ) {
    final l = AppL10n.of(context);
    final profile = _cachedProfileFor(server);
    final name = _displayNameFor(server, profile);
    final message = _resolveStateMessage(l, transition);
    return Column(
      key: const ValueKey('server-switch-error'),
      children: [
        Text(
          l.homeSwitchCannotConnect(name),
          textAlign: TextAlign.center,
          style: AppText.pageTitle(context).copyWith(fontSize: 23),
        ),
        const SizedBox(height: 10),
        Text(
          message?.trim().isNotEmpty == true
              ? message!
              : l.homeSwitchCheckNetwork,
          textAlign: TextAlign.center,
          style: AppText.body(context).copyWith(color: colors.muted),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _cancel,
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(l.back),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l.fileRetry),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _submitLogin() async {
    final transition = ref.read(serverSwitchTransitionProvider);
    final target = _targetServer(
      ref.read(serverSelectionConfigProvider),
      transition.targetServerId,
    );
    final needsUsername =
        target?.project == ServerProject.emby ||
        target?.project == ServerProject.jellyfin ||
        target?.project == ServerProject.feiniu;
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (needsUsername && username.isEmpty) {
      _updateViewState(
        () => _localError = AppL10n.of(context).homeSwitchNeedUsername,
      );
      return;
    }
    if (password.trim().isEmpty) {
      _updateViewState(
        () => _localError = AppL10n.of(context).homeSwitchNeedPassword,
      );
      return;
    }
    _updateViewState(() {
      _loginBusy = true;
      _localError = null;
    });
    try {
      await ref
          .read(serverSwitchTransitionProvider.notifier)
          .login(username: needsUsername ? username : null, password: password);
      if (!mounted) return;
      // 密码正确但服务器要求 TOTP：切换到验证码界面。
      final phase = ref.read(authControllerProvider).value?.phase;
      if (phase == AuthPhase.totpRequired) {
        _updateViewState(() => _totpRequired = true);
      }
    } finally {
      if (mounted) _updateViewState(() => _loginBusy = false);
    }
  }

  Future<void> _submitTotp() async {
    final totpCode = _totpController.text.trim();
    if (totpCode.length < totpCodeLength) {
      _updateViewState(
        () => _localError = AppL10n.of(
          context,
        ).homeSwitchNeedTotp(totpCodeLength),
      );
      return;
    }
    _updateViewState(() {
      _loginBusy = true;
      _localError = null;
    });
    try {
      await ref
          .read(serverSwitchTransitionProvider.notifier)
          .login(password: _passwordController.text, totpCode: totpCode);
    } finally {
      if (mounted) {
        _updateViewState(() {
          _loginBusy = false;
          _totpController.clear();
        });
      }
    }
  }

  Future<void> _submitApiKey() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      _updateViewState(
        () => _localError = AppL10n.of(context).serverSetupStashApiKeyRequired,
      );
      return;
    }
    _updateViewState(() {
      _loginBusy = true;
      _localError = null;
    });
    try {
      await ref.read(serverSwitchTransitionProvider.notifier).setApiKey(apiKey);
    } finally {
      if (mounted) _updateViewState(() => _loginBusy = false);
    }
  }

  void _backToPassword() {
    _updateViewState(() {
      _totpRequired = false;
      _localError = null;
      _totpController.clear();
    });
  }

  Future<void> _retry() async {
    _updateViewState(() {
      _localError = null;
      _totpRequired = false;
      _totpController.clear();
    });
    await ref.read(serverSwitchTransitionProvider.notifier).retry();
  }

  Future<void> _cancel() async {
    if (_loginBusy) return;
    _updateViewState(() {
      _localError = null;
      _totpRequired = false;
      _totpController.clear();
    });
    await ref.read(serverSwitchTransitionProvider.notifier).cancel();
  }

  Widget _input(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required bool enabled,
    bool obscureText = false,
    TextInputType? keyboardType,
    IconData? icon,
    ValueChanged<String>? onSubmitted,
  }) {
    final colors = appColors(context);
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      textAlignVertical: TextAlignVertical.center,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
        filled: true,
        fillColor: colors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.cardBorder),
        ),
      ),
    );
  }
}
