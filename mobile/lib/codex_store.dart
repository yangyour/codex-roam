import 'dart:async';

import 'package:flutter/foundation.dart';

import 'codex_api.dart';
import 'models.dart';

class CodexStore extends ChangeNotifier {
  CodexStore(this.api);

  final CodexApi api;
  List<CodexThread> threads = [];
  CodexDetail? detail;
  String? selectedId;
  ApprovalRequest? approval;
  String connectionState = 'connecting';
  String? error;
  bool loading = true;
  Timer? _pollTimer;
  Timer? _refreshDebounce;
  StreamSubscription<Map<String, dynamic>>? _events;
  bool _refreshing = false;
  int _streamVersion = 0;
  int _lastStreamEventMs = 0;

  CodexThread? get selected =>
      threads.where((thread) => thread.id == selectedId).firstOrNull ??
      detail?.thread;
  bool get active =>
      selected?.active == true ||
      detail?.turns.any((turn) => turn.inProgress) == true;

  Future<void> start() async {
    await refresh();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final sinceStream =
          DateTime.now().millisecondsSinceEpoch - _lastStreamEventMs;
      if (sinceStream > 5000) refresh(silent: true);
    });
    _events = api.events().listen(ingestEvent);
  }

  Future<void> refresh({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    final streamVersion = _streamVersion;
    if (!silent) loading = true;
    try {
      threads = await api.listThreads();
      selectedId ??= threads.firstOrNull?.id;
      if (selectedId != null) {
        final fetched = await api.readThread(selectedId!);
        if (streamVersion == _streamVersion) detail = fetched;
      }
      connectionState = 'online';
      error = null;
    } catch (exception) {
      connectionState = 'offline';
      error = _message(exception);
    } finally {
      _refreshing = false;
      loading = false;
      notifyListeners();
    }
  }

  Future<void> select(String id) async {
    selectedId = id;
    detail = null;
    notifyListeners();
    try {
      detail = await api.readThread(id);
    } catch (exception) {
      error = _message(exception);
    }
    notifyListeners();
  }

  Future<void> send(String text) async {
    final id = selectedId;
    if (id == null || text.trim().isEmpty) return;
    try {
      await api.send(id, text.trim());
      await refresh(silent: true);
    } catch (exception) {
      error = _message(exception);
      notifyListeners();
    }
  }

  Future<void> interrupt() async {
    final turn = detail?.turns.reversed
        .where((item) => item.inProgress)
        .firstOrNull;
    if (selectedId == null || turn == null) return;
    try {
      await api.interrupt(selectedId!, turn.id);
      await refresh(silent: true);
    } catch (exception) {
      error = _message(exception);
      notifyListeners();
    }
  }

  Future<void> approve(String decision) async {
    final request = approval;
    if (request == null) return;
    try {
      await api.approve(request.id, decision);
      approval = null;
    } catch (exception) {
      error = _message(exception);
    }
    notifyListeners();
  }

  Future<CodexThread?> create(String cwd) async {
    try {
      final thread = await api.createThread(cwd);
      await refresh();
      await select(thread.id);
      return thread;
    } catch (exception) {
      error = _message(exception);
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  void ingestEvent(Map<String, dynamic> event) {
    if (event['type'] == 'connection' || event['type'] == 'server') {
      connectionState = event['status']?.toString() ?? 'offline';
      notifyListeners();
      return;
    }
    if (event['type'] == 'approval') {
      approval = ApprovalRequest(
        id: event['id'].toString(),
        method: event['method']?.toString() ?? '',
        params: (event['params'] as Map?)?.cast<String, dynamic>() ?? {},
      );
      notifyListeners();
      return;
    }
    if (event['type'] == 'rollout') {
      if (event['threadId']?.toString() == selectedId) {
        _scheduleRefresh(const Duration(milliseconds: 80));
      }
      return;
    }
    if (event['type'] == 'notification') {
      final method = event['method']?.toString() ?? '';
      final params =
          (event['params'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
      if (_applyLiveNotification(method, params)) {
        _lastStreamEventMs = DateTime.now().millisecondsSinceEpoch;
        _streamVersion++;
        notifyListeners();
        if (method == 'item/completed' || method == 'turn/completed') {
          _scheduleRefresh(const Duration(milliseconds: 500));
        }
        return;
      }
      _scheduleRefresh(const Duration(milliseconds: 180));
    }
  }

  void _scheduleRefresh(Duration delay) {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(delay, () => refresh(silent: true));
  }

  bool _applyLiveNotification(String method, Map<String, dynamic> params) {
    final threadId = params['threadId']?.toString();
    if (threadId == null || threadId != selectedId) return false;
    final turnId =
        params['turnId']?.toString() ??
        (params['turn'] as Map?)?['id']?.toString();

    if (method == 'turn/started' || method == 'turn/completed') {
      final turnJson = (params['turn'] as Map?)?.cast<String, dynamic>();
      if (turnJson == null) return false;
      _upsertTurn(CodexTurn.fromJson(turnJson));
      return true;
    }

    if (turnId == null) return false;
    if (method == 'item/started' || method == 'item/completed') {
      final itemJson = (params['item'] as Map?)?.cast<String, dynamic>();
      if (itemJson == null) return false;
      _upsertItem(turnId, CodexItem.fromJson(itemJson));
      return true;
    }

    final itemId = params['itemId']?.toString();
    if (itemId == null) return false;
    final delta = params['delta']?.toString() ?? '';
    switch (method) {
      case 'item/agentMessage/delta':
        _appendText(turnId, itemId, 'agentMessage', delta);
      case 'item/plan/delta':
        _appendText(turnId, itemId, 'plan', delta);
      case 'item/reasoning/summaryTextDelta':
        _appendText(turnId, itemId, 'reasoning', delta);
      case 'item/commandExecution/outputDelta':
        _appendOutput(turnId, itemId, 'commandExecution', delta);
      case 'item/fileChange/outputDelta':
        _appendText(turnId, itemId, 'fileChange', delta);
      default:
        return false;
    }
    return true;
  }

  CodexTurn? _ensureTurn(String turnId) {
    if (detail == null) {
      final thread = selected;
      if (thread == null) return null;
      detail = CodexDetail(thread, []);
    }
    final turns = detail!.turns;
    final existing = turns.where((turn) => turn.id == turnId).firstOrNull;
    if (existing != null) return existing;
    final turn = CodexTurn(
      id: turnId,
      status: 'inProgress',
      startedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      items: [],
    );
    turns.add(turn);
    return turn;
  }

  void _upsertTurn(CodexTurn turn) {
    if (detail == null) {
      final thread = selected;
      if (thread != null) detail = CodexDetail(thread, [turn]);
      return;
    }
    final turns = detail!.turns;
    final index = turns.indexWhere((item) => item.id == turn.id);
    if (index == -1) {
      turns.add(turn);
    } else {
      turns[index] = turn;
    }
  }

  void _upsertItem(String turnId, CodexItem item) {
    final turn = _ensureTurn(turnId);
    if (turn == null) return;
    final index = turn.items.indexWhere((entry) => entry.id == item.id);
    if (index == -1) {
      turn.items.add(item);
    } else {
      turn.items[index] = item;
    }
  }

  void _appendText(String turnId, String itemId, String type, String delta) {
    final turn = _ensureTurn(turnId);
    if (turn == null) return;
    final index = turn.items.indexWhere((item) => item.id == itemId);
    if (index == -1) {
      turn.items.add(CodexItem(type: type, id: itemId, text: delta));
    } else {
      final item = turn.items[index];
      turn.items[index] = item.copyWith(text: '${item.text}$delta');
    }
  }

  void _appendOutput(String turnId, String itemId, String type, String delta) {
    final turn = _ensureTurn(turnId);
    if (turn == null) return;
    final index = turn.items.indexWhere((item) => item.id == itemId);
    if (index == -1) {
      turn.items.add(
        CodexItem(type: type, id: itemId, text: '', output: delta),
      );
    } else {
      final item = turn.items[index];
      turn.items[index] = item.copyWith(output: '${item.output ?? ''}$delta');
    }
  }

  String _message(Object exception) =>
      exception.toString().replaceFirst('Exception: ', '');

  Future<void> disposeAsync() async {
    _pollTimer?.cancel();
    _refreshDebounce?.cancel();
    await _events?.cancel();
    api.close();
  }

  @override
  void dispose() {
    unawaited(disposeAsync());
    super.dispose();
  }
}
