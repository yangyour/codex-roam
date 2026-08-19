class ConnectionDetails {
  const ConnectionDetails(this.baseUrl, this.token);

  final String baseUrl;
  final String token;

  static ConnectionDetails? parse(String rawUrl, String rawToken) {
    var source = rawUrl.trim();
    if (source.isEmpty) return null;
    if (!source.startsWith('http://') && !source.startsWith('https://')) {
      source = 'http://$source';
    }
    final uri = Uri.tryParse(source);
    if (uri == null || uri.host.isEmpty) return null;
    final token = rawToken.trim().isNotEmpty
        ? rawToken.trim()
        : (uri.queryParameters['token'] ?? '');
    if (token.isEmpty) return null;
    final base = uri.origin;
    return ConnectionDetails(base, token);
  }
}

class CodexThread {
  CodexThread({
    required this.id,
    required this.preview,
    required this.name,
    required this.cwd,
    required this.updatedAt,
    required this.status,
    required this.desktopOpen,
  });

  final String id;
  final String preview;
  final String? name;
  final String cwd;
  final int updatedAt;
  final String status;
  final bool desktopOpen;

  bool get active => status == 'active';
  String get title => name?.isNotEmpty == true
      ? name!
      : preview.isNotEmpty
      ? preview
      : '未命名会话';
  String get stateLabel => active
      ? '运行中'
      : desktopOpen
      ? '桌面已打开'
      : '空闲';

  factory CodexThread.fromJson(Map<String, dynamic> json) => CodexThread(
    id: json['id']?.toString() ?? '',
    preview: json['preview']?.toString() ?? '',
    name: json['name']?.toString(),
    cwd: json['cwd']?.toString() ?? '',
    updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
    status: (json['status'] as Map?)?['type']?.toString() ?? 'idle',
    desktopOpen: json['desktopOpen'] == true,
  );
}

class CodexDetail {
  CodexDetail(this.thread, this.turns);

  final CodexThread thread;
  final List<CodexTurn> turns;

  factory CodexDetail.fromJson(Map<String, dynamic> json) {
    final threadJson = (json['thread'] as Map).cast<String, dynamic>();
    return CodexDetail(
      CodexThread.fromJson(threadJson),
      (threadJson['turns'] as List? ?? [])
          .map(
            (item) => CodexTurn.fromJson((item as Map).cast<String, dynamic>()),
          )
          .toList(),
    );
  }
}

class CodexTurn {
  CodexTurn({
    required this.id,
    required this.status,
    required this.startedAt,
    required this.items,
  });

  final String id;
  final String status;
  final int? startedAt;
  final List<CodexItem> items;

  bool get inProgress => status == 'inProgress';

  factory CodexTurn.fromJson(Map<String, dynamic> json) => CodexTurn(
    id: json['id']?.toString() ?? '',
    status: json['status']?.toString() ?? 'completed',
    startedAt: (json['startedAt'] as num?)?.toInt(),
    items: (json['items'] as List? ?? [])
        .map(
          (item) => CodexItem.fromJson((item as Map).cast<String, dynamic>()),
        )
        .toList(),
  );
}

class CodexItem {
  CodexItem({
    required this.type,
    required this.id,
    required this.text,
    this.command,
    this.output,
    this.status,
  });

  final String type;
  final String id;
  final String text;
  final String? command;
  final String? output;
  final String? status;

  bool get visible =>
      text.isNotEmpty ||
      command?.isNotEmpty == true ||
      output?.isNotEmpty == true;

  CodexItem copyWith({String? text, String? output, String? status}) =>
      CodexItem(
        type: type,
        id: id,
        text: text ?? this.text,
        command: command,
        output: output ?? this.output,
        status: status ?? this.status,
      );

  factory CodexItem.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? '';
    String contentText = '';
    for (final entry in json['content'] as List? ?? const []) {
      if (entry is Map && entry['type'] == 'text') {
        contentText = entry['text']?.toString() ?? '';
        break;
      }
    }
    final summary = (json['summary'] as List? ?? const [])
        .map((entry) => entry.toString())
        .where((entry) => entry.isNotEmpty)
        .join('\n');
    final changes = (json['changes'] as List? ?? const [])
        .whereType<Map>()
        .map((change) {
          final path = change['path']?.toString() ?? '';
          final kind = change['kind']?.toString() ?? '修改';
          return path.isEmpty ? kind : '$kind  $path';
        })
        .join('\n');
    final directText = json['text']?.toString() ?? '';
    return CodexItem(
      type: type,
      id: json['id']?.toString() ?? '',
      text: switch (type) {
        'userMessage' => contentText,
        'reasoning' => summary.isNotEmpty ? summary : directText,
        'fileChange' => changes,
        'mcpToolCall' => [
          json['server']?.toString(),
          json['tool']?.toString(),
        ].whereType<String>().where((value) => value.isNotEmpty).join(' / '),
        _ => directText,
      },
      command: json['command']?.toString(),
      output: json['aggregatedOutput']?.toString(),
      status: json['status']?.toString(),
    );
  }
}

class ApprovalRequest {
  ApprovalRequest({
    required this.id,
    required this.method,
    required this.params,
  });

  final String id;
  final String method;
  final Map<String, dynamic> params;

  String get command =>
      params['command']?.toString() ??
      params['reason']?.toString() ??
      'Codex 需要你的确认才能继续';
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
