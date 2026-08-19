import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

enum CodexTaskNotificationState { completed, blocked }

class CodexTaskNotification {
  const CodexTaskNotification({
    required this.threadId,
    required this.title,
    required this.body,
    required this.state,
  });

  final String threadId;
  final String title;
  final String body;
  final CodexTaskNotificationState state;
}

abstract interface class CodexNotificationSink {
  Future<void> show(CodexTaskNotification notification);
}

class CodexNotificationService implements CodexNotificationSink {
  CodexNotificationService._();

  static final instance = CodexNotificationService._();
  static const _channelId = 'codex_task_updates';
  static const _channelName = 'Codex 任务状态';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  int _nextId = 1000;

  /// Called when a notification is tapped. The value is a Codex thread id.
  void Function(String threadId)? _onThreadSelected;
  String? _pendingThreadId;

  set onThreadSelected(void Function(String threadId)? callback) {
    _onThreadSelected = callback;
    final pending = _pendingThreadId;
    if (callback != null && pending != null) {
      _pendingThreadId = null;
      callback(pending);
    }
  }

  void Function(String threadId)? get onThreadSelected => _onThreadSelected;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android) {
      _initialized = true;
      return;
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (response) {
        final threadId = response.payload;
        if (threadId != null && threadId.isNotEmpty) {
          final callback = _onThreadSelected;
          if (callback == null) {
            _pendingThreadId = threadId;
          } else {
            callback(threadId);
          }
        }
      },
    );
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Codex 任务完成和阻塞提醒',
        importance: Importance.high,
      ),
    );
    await androidPlugin?.requestNotificationsPermission();
    _initialized = true;
  }

  @override
  Future<void> show(CodexTaskNotification notification) async {
    if (!_initialized || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    final id = _nextId++;
    final details = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Codex 任务完成和阻塞提醒',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.status,
      ticker: notification.title,
    );
    await _plugin.show(
      id,
      notification.title,
      notification.body,
      NotificationDetails(android: details),
      payload: notification.threadId,
    );
  }
}
