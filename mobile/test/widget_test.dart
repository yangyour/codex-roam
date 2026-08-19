import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:codex_roam/codex_api.dart';
import 'package:codex_roam/codex_store.dart';
import 'package:codex_roam/models.dart';
import 'package:codex_roam/notification_service.dart';

class _FakeNotificationSink implements CodexNotificationSink {
  final notifications = <CodexTaskNotification>[];

  @override
  Future<void> show(CodexTaskNotification notification) async {
    notifications.add(notification);
  }
}

void main() {
  test('connection URL parser accepts the terminal URL', () {
    final parsed = ConnectionDetails.parse(
      'http://192.168.1.20:4174/?token=abc123',
      '',
    );
    expect(parsed?.baseUrl, 'http://192.168.1.20:4174');
    expect(parsed?.token, 'abc123');
  });

  test('connection URL parser accepts a host and separate token', () {
    final parsed = ConnectionDetails.parse('192.168.1.20:4174', 'secret');
    expect(parsed?.baseUrl, 'http://192.168.1.20:4174');
    expect(parsed?.token, 'secret');
  });

  test('store merges Codex streaming deltas into the active turn', () {
    final thread = CodexThread(
      id: 'thread-1',
      preview: 'stream test',
      name: null,
      cwd: r'E:\work',
      updatedAt: 0,
      status: 'active',
      desktopOpen: false,
    );
    final store = CodexStore(CodexApi('http://127.0.0.1', 'test'))
      ..threads = [thread]
      ..selectedId = thread.id
      ..detail = CodexDetail(thread, []);
    addTearDown(store.dispose);

    void event(String method, Map<String, dynamic> params) {
      store.ingestEvent({
        'type': 'notification',
        'method': method,
        'params': params,
      });
    }

    event('turn/started', {
      'threadId': thread.id,
      'turn': {
        'id': 'turn-1',
        'status': 'inProgress',
        'startedAt': 1,
        'items': <dynamic>[],
      },
    });
    event('item/started', {
      'threadId': thread.id,
      'turnId': 'turn-1',
      'item': {'type': 'agentMessage', 'id': 'item-1', 'text': ''},
    });
    event('item/agentMessage/delta', {
      'threadId': thread.id,
      'turnId': 'turn-1',
      'itemId': 'item-1',
      'delta': '逐段',
    });
    event('item/agentMessage/delta', {
      'threadId': thread.id,
      'turnId': 'turn-1',
      'itemId': 'item-1',
      'delta': '输出',
    });
    event('item/started', {
      'threadId': thread.id,
      'turnId': 'turn-1',
      'item': {
        'type': 'commandExecution',
        'id': 'command-1',
        'command': 'flutter test',
        'status': 'inProgress',
      },
    });
    event('item/commandExecution/outputDelta', {
      'threadId': thread.id,
      'turnId': 'turn-1',
      'itemId': 'command-1',
      'delta': 'All tests passed',
    });

    final items = store.detail!.turns.single.items;
    expect(items.first.text, '逐段输出');
    expect(items.last.command, 'flutter test');
    expect(items.last.output, 'All tests passed');
  });

  test(
    'store notifies once when a turn completes and again on a new turn',
    () async {
      final thread = CodexThread(
        id: 'thread-notify',
        preview: 'notification test',
        name: 'Notification test',
        cwd: r'E:\work',
        updatedAt: 0,
        status: 'active',
        desktopOpen: false,
      );
      final sink = _FakeNotificationSink();
      final store =
          CodexStore(
              CodexApi('http://127.0.0.1', 'test'),
              notificationSink: sink,
            )
            ..threads = [thread]
            ..selectedId = thread.id
            ..detail = CodexDetail(thread, []);
      addTearDown(store.dispose);

      void event(String method, Map<String, dynamic> params) {
        store.ingestEvent({
          'type': 'notification',
          'method': method,
          'params': params,
        });
      }

      event('turn/completed', {
        'threadId': thread.id,
        'turnId': 'turn-1',
        'turn': {'id': 'turn-1', 'status': 'completed'},
      });
      await Future<void>.delayed(Duration.zero);
      event('turn/completed', {
        'threadId': thread.id,
        'turnId': 'turn-1',
        'turn': {'id': 'turn-1', 'status': 'completed'},
      });
      await Future<void>.delayed(Duration.zero);
      expect(sink.notifications, hasLength(1));
      expect(
        sink.notifications.single.state,
        CodexTaskNotificationState.completed,
      );

      event('turn/started', {'threadId': thread.id, 'turnId': 'turn-2'});
      event('turn/completed', {
        'threadId': thread.id,
        'turnId': 'turn-2',
        'turn': {'id': 'turn-2', 'status': 'completed'},
      });
      await Future<void>.delayed(Duration.zero);
      expect(sink.notifications, hasLength(2));
    },
  );

  test('store notifies when a task is blocked by approval', () async {
    final thread = CodexThread(
      id: 'thread-blocked',
      preview: 'approval test',
      name: null,
      cwd: r'E:\work',
      updatedAt: 0,
      status: 'active',
      desktopOpen: false,
    );
    final sink = _FakeNotificationSink();
    final store =
        CodexStore(CodexApi('http://127.0.0.1', 'test'), notificationSink: sink)
          ..threads = [thread]
          ..selectedId = thread.id;
    addTearDown(store.dispose);

    store.ingestEvent({
      'type': 'approval',
      'id': 'approval-1',
      'method': 'item/commandExecution/requestApproval',
      'params': {'threadId': thread.id, 'command': 'flutter test'},
    });
    await Future<void>.delayed(Duration.zero);

    expect(sink.notifications, hasLength(1));
    expect(sink.notifications.single.state, CodexTaskNotificationState.blocked);
    expect(sink.notifications.single.body, contains('flutter test'));
  });

  test('API falls back from EasyTier to the Wi-Fi endpoint', () async {
    final requestedHosts = <String>[];
    final api = CodexApi(
      'http://10.10.0.2:4174',
      'test',
      fallbackBaseUrls: const ['http://192.168.1.20:4174'],
      client: MockClient((request) async {
        requestedHosts.add(request.url.host);
        if (request.url.host == '10.10.0.2') {
          throw Exception('EasyTier unavailable');
        }
        return http.Response('{"data":[]}', 200);
      }),
    );
    addTearDown(api.close);

    expect(await api.listThreads(), isEmpty);
    expect(requestedHosts, ['10.10.0.2', '192.168.1.20']);
    expect(api.baseUrl, 'http://192.168.1.20:4174');
  });
}
