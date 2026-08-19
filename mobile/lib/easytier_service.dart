import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_settings.dart';

class EasyTierService extends ChangeNotifier {
  EasyTierService._();

  static final instance = EasyTierService._();
  static const _methods = MethodChannel('app.codexroam/easytier');
  static const _events = EventChannel('app.codexroam/easytier_events');

  StreamSubscription<dynamic>? _subscription;
  String phase = 'idle';
  String message = '正在准备内置网络';
  String? ipv4;
  int peers = 0;

  bool get connected => phase == 'connected';

  Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _subscription ??= _events.receiveBroadcastStream().listen(
      _apply,
      onError: (Object error) => _setError('EasyTier 状态通道不可用：$error'),
    );
    try {
      _apply(await _methods.invokeMapMethod<String, dynamic>('status'));
    } on MissingPluginException {
      _setError('当前安装包不包含 EasyTier 原生模块');
    }
  }

  Future<void> applySettings(
    EasyTierSettings settings, {
    bool restart = false,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (restart) {
      try {
        _apply(await _methods.invokeMapMethod<String, dynamic>('stop'));
      } on MissingPluginException {
        _setError('当前安装包不包含 EasyTier 原生模块');
        return;
      }
    }
    if (!settings.configured) {
      phase = 'idle';
      message = settings.enabled ? 'EasyTier 配置不完整' : 'EasyTier 已关闭，可使用局域网地址连接';
      notifyListeners();
      return;
    }
    try {
      final granted = await _methods.invokeMethod<bool>('prepare') ?? false;
      if (!granted) {
        _setError('需要允许 VPN 连接才能使用远程网络');
        return;
      }
      _apply(
        await _methods.invokeMapMethod<String, dynamic>('start', {
          ...settings.toPlatformArguments(),
        }),
      );
    } on PlatformException catch (error) {
      _setError('EasyTier 启动失败：${error.message ?? error.code}');
    } on MissingPluginException {
      _setError('当前安装包不包含 EasyTier 原生模块');
    }
  }

  void _apply(dynamic value) {
    if (value is! Map) return;
    phase = value['phase']?.toString() ?? phase;
    message = value['message']?.toString() ?? message;
    ipv4 = value['ipv4']?.toString();
    peers = int.tryParse(value['peers']?.toString() ?? '') ?? 0;
    notifyListeners();
  }

  void _setError(String value) {
    phase = 'error';
    message = value;
    notifyListeners();
  }
}
