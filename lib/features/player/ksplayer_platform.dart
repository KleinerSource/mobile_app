import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class KsPlayerPlatformController {
  KsPlayerPlatformController(this._channel);

  final MethodChannel _channel;

  Future<void> play() => _channel.invokeMethod<void>('play');

  Future<void> pause() => _channel.invokeMethod<void>('pause');

  Future<void> seek(Duration position) {
    return _channel.invokeMethod<void>('seek', {
      'position_ms': position.inMilliseconds,
    });
  }

  Future<void> setRate(double rate) {
    return _channel.invokeMethod<void>('setRate', {'rate': rate});
  }

  Future<void> stop() => _channel.invokeMethod<void>('stop');

  Future<void> dispose() => _channel.invokeMethod<void>('dispose');
}

class KsPlayerPlatformView extends StatefulWidget {
  const KsPlayerPlatformView({
    super.key,
    required this.creationParams,
    required this.onCreated,
    required this.onEvent,
  });

  final Map<String, Object?> creationParams;
  final ValueChanged<KsPlayerPlatformController> onCreated;
  final Future<void> Function(String method, dynamic arguments) onEvent;

  @override
  State<KsPlayerPlatformView> createState() => _KsPlayerPlatformViewState();
}

class _KsPlayerPlatformViewState extends State<KsPlayerPlatformView> {
  MethodChannel? _channel;

  @override
  Widget build(BuildContext context) {
    return UiKitView(
      viewType: 'md_center/ksplayer_view',
      creationParams: widget.creationParams,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onPlatformViewCreated,
    );
  }

  void _onPlatformViewCreated(int viewId) {
    final channel = MethodChannel('md_center/ksplayer/$viewId');
    _channel = channel;
    channel.setMethodCallHandler(_handleMethodCall);
    widget.onCreated(KsPlayerPlatformController(channel));
  }

  Future<void> _handleMethodCall(MethodCall call) {
    return widget.onEvent(call.method, call.arguments);
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }
}
