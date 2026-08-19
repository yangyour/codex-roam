import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient;

import 'package:http/http.dart' as http;

import 'models.dart';

class CodexApi {
  CodexApi(
    String baseUrl,
    this.token, {
    List<String> fallbackBaseUrls = const [],
    http.Client? client,
  }) : _baseUrls = <String>{baseUrl, ...fallbackBaseUrls}.toList(),
       _activeBaseUrl = baseUrl,
       _client = client ?? http.Client();

  final String token;
  final List<String> _baseUrls;
  String _activeBaseUrl;
  final http.Client _client;

  String get baseUrl => _activeBaseUrl;

  Map<String, String> get _headers => {
    'content-type': 'application/json',
    'x-codex-token': token,
  };

  Future<dynamic> _get(String path) async {
    Object? lastError;
    for (final endpoint in _orderedEndpoints()) {
      try {
        final response = await _client
            .get(Uri.parse('$endpoint$path'), headers: _headers)
            .timeout(const Duration(seconds: 5));
        final value = _decode(response);
        _activeBaseUrl = endpoint;
        return value;
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError ?? Exception('无法连接电脑');
  }

  Future<dynamic> _post(
    String path, [
    Map<String, dynamic> payload = const {},
  ]) async {
    final response = await _client
        .post(
          Uri.parse('$_activeBaseUrl$path'),
          headers: _headers,
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 30));
    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    dynamic value;
    try {
      value = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } catch (_) {
      value = <String, dynamic>{};
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = value is Map ? value['error'] : null;
      throw Exception(message ?? '请求失败 (${response.statusCode})');
    }
    return value;
  }

  Future<List<CodexThread>> listThreads() async {
    final value = await _get('/api/threads') as Map;
    return (value['data'] as List? ?? [])
        .map(
          (item) => CodexThread.fromJson((item as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  Future<CodexDetail> readThread(String id) async => CodexDetail.fromJson(
    (await _get('/api/threads/$id') as Map).cast<String, dynamic>(),
  );

  Future<CodexThread> createThread(String cwd) async {
    final value = await _post('/api/threads', {'cwd': cwd}) as Map;
    return CodexThread.fromJson(
      (value['thread'] as Map).cast<String, dynamic>(),
    );
  }

  Future<void> send(String id, String text) async {
    await _post('/api/threads/$id/turns', {'text': text});
  }

  Future<void> interrupt(String threadId, String turnId) async {
    await _post('/api/threads/$threadId/turns/$turnId/interrupt');
  }

  Future<void> approve(String id, String decision) async {
    await _post('/api/approval', {'id': id, 'decision': decision});
  }

  Stream<Map<String, dynamic>> events() async* {
    var failures = 0;
    while (true) {
      HttpClient? rawClient;
      try {
        rawClient = HttpClient()
          ..connectionTimeout = const Duration(seconds: 10);
        final endpoint = _orderedEndpoints().first;
        final uri = Uri.parse(
          '$endpoint/events?token=${Uri.encodeQueryComponent(token)}',
        );
        final request = await rawClient.getUrl(uri);
        request.headers.set('accept', 'text/event-stream');
        final response = await request.close();
        if (response.statusCode != 200) {
          throw Exception('事件连接失败 (${response.statusCode})');
        }
        _activeBaseUrl = endpoint;
        failures = 0;
        await for (final line
            in response
                .transform(utf8.decoder)
                .transform(const LineSplitter())) {
          if (!line.startsWith('data: ')) continue;
          final payload = line.substring(6).trim();
          if (payload.isEmpty) continue;
          final value = jsonDecode(payload);
          if (value is Map<String, dynamic>) yield value;
        }
      } catch (error) {
        failures++;
        if (_baseUrls.length > 1) {
          final current = _baseUrls.indexOf(_activeBaseUrl);
          _activeBaseUrl = _baseUrls[(current + 1) % _baseUrls.length];
        }
        yield {
          'type': 'connection',
          'status': 'offline',
          'error': error.toString(),
        };
      } finally {
        rawClient?.close(force: true);
      }
      await Future<void>.delayed(Duration(seconds: failures > 3 ? 4 : 1));
    }
  }

  List<String> _orderedEndpoints() => [
    _activeBaseUrl,
    ..._baseUrls.where((endpoint) => endpoint != _activeBaseUrl),
  ];

  void close() => _client.close();
}
