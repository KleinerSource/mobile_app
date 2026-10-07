import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'configs_providers.dart';
import 'omm_admin_repository.dart';
import 'omm_admin_widgets.dart';

class FfmpegToolsPage extends StatelessWidget {
  const FfmpegToolsPage({super.key});
  @override
  Widget build(BuildContext context) =>
      OmmAdminScope(builder: (repository) => _FfmpegToolsView(repository));
}

class _FfmpegToolsView extends ConsumerStatefulWidget {
  const _FfmpegToolsView(this.repository);
  final OmmAdminRepository repository;
  @override
  ConsumerState<_FfmpegToolsView> createState() => _FfmpegToolsViewState();
}

class _FfmpegToolsViewState extends ConsumerState<_FfmpegToolsView> {
  Map<String, dynamic>? _status;
  Map<String, dynamic>? _environment;
  Map<String, dynamic>? _gpu;
  Map<String, dynamic>? _install;
  String? _error;
  bool _busy = false;
  Timer? _poll;
  int _requestGeneration = 0;
  bool get _active => mounted && widget.repository.isActive;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy || !_active) return;
    _poll?.cancel();
    final generation = ++_requestGeneration;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.repository.ffmpegStatus(),
        widget.repository.ffmpegEnvironment(),
        widget.repository.ffmpegGpuDetect(),
        widget.repository.ffmpegInstallStatus(),
      ]);
      if (!_active || generation != _requestGeneration) return;
      setState(() {
        _status = results[0];
        _environment = results[1];
        _gpu = results[2];
        _install = results[3];
      });
      _schedulePoll();
    } catch (error) {
      if (_active && generation == _requestGeneration) {
        setState(
          () => _error = localizedErrorMessage(AppL10n.of(context), error),
        );
      }
    } finally {
      if (_active && generation == _requestGeneration) {
        setState(() => _busy = false);
      }
    }
  }

  void _schedulePoll() {
    _poll?.cancel();
    if (_active && _install?['running'] == true) {
      _poll = Timer(const Duration(seconds: 2), _pollStatus);
    }
  }

  Future<void> _pollStatus() async {
    if (!_active || _busy) return;
    final generation = ++_requestGeneration;
    try {
      final status = await widget.repository.ffmpegInstallStatus();
      if (!_active || generation != _requestGeneration) return;
      setState(() => _install = status);
      if (status['done'] == true &&
          (status['error']?.toString() ?? '').isEmpty) {
        ref.invalidate(ffmpegConfigProvider);
        final runtime = await widget.repository.ffmpegStatus();
        if (!_active || generation != _requestGeneration) return;
        setState(() => _status = runtime);
      }
      _schedulePoll();
    } catch (error) {
      if (_active && generation == _requestGeneration) {
        setState(
          () => _error = localizedErrorMessage(AppL10n.of(context), error),
        );
      }
    }
  }

  Future<void> _startInstall() async {
    if (_busy ||
        !_active ||
        _install?['running'] == true ||
        _environment?['supported'] != true) {
      return;
    }
    final l = AppL10n.of(context);
    setState(() => _busy = true);
    try {
      if (!await confirmOmmAction(
            context,
            l.ommInstallFfmpeg,
            l.ommInstallFfmpegConfirm,
          ) ||
          !_active) {
        return;
      }
      final status = await widget.repository.installFfmpeg();
      if (!_active) return;
      setState(() {
        _install = status;
        _error = null;
      });
    } catch (error) {
      if (_active) setState(() => _error = localizedErrorMessage(l, error));
    } finally {
      if (_active) {
        setState(() => _busy = false);
        _schedulePoll();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    String ready(Object? value) =>
        value == true ? l.ommReady : l.ommUnavailable;
    final stage = switch (_install?['stage']) {
      'preparing' => l.ommInstallPreparing,
      'downloading' => l.ommInstallDownloading,
      'extracting' => l.ommInstallExtracting,
      'deploying' => l.ommInstallDeploying,
      'done' => l.ommInstallDone,
      'failed' => l.ommInstallFailed,
      _ => l.ommInstallIdle,
    };
    return OmmAdminScaffold(
      title: l.ommFfmpegTools,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 40),
        children: [
          if (_busy || _install?['running'] == true)
            const LinearProgressIndicator(),
          if (_status != null) ...[
            OmmInfoRow(
              'FFmpeg',
              '${ready(_status!['ffmpeg_ok'])}\n${_status!['ffmpeg_path'] ?? ''}',
            ),
            OmmInfoRow(
              'FFprobe',
              '${ready(_status!['ffprobe_ok'])}\n${_status!['ffprobe_path'] ?? ''}',
            ),
          ],
          if (_gpu != null)
            OmmInfoRow(
              l.ommGpu,
              '${_gpu!['gpu'] ?? ''}\n${_gpu!['effective_hwaccel'] ?? ''}',
            ),
          if (_environment != null) ...[
            OmmInfoRow(
              l.ommEnvironment,
              '${_environment!['os'] ?? ''} / ${_environment!['arch'] ?? ''}',
            ),
            OmmInfoRow(
              l.ommInstallDirectory,
              _environment!['target_dir']?.toString() ?? '',
            ),
            if (_environment!['supported'] != true)
              Text(_environment!['reason']?.toString() ?? l.ommUnavailable),
          ],
          if (_install != null) OmmInfoRow(l.ommInstallStatus, stage),
          if ((_install?['error']?.toString() ?? '').isNotEmpty)
            Text(
              _install!['error'].toString(),
              style: TextStyle(color: appColors(context).danger),
            ),
          if (_error != null)
            Text(_error!, style: TextStyle(color: appColors(context).danger)),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _busy ? null : _load,
            child: Text(l.ommRefreshStatus),
          ),
          FilledButton(
            onPressed:
                _busy ||
                    _install?['running'] == true ||
                    _environment?['supported'] != true
                ? null
                : _startInstall,
            child: Text(l.ommInstallFfmpeg),
          ),
        ],
      ),
    );
  }
}
