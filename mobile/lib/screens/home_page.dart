import 'dart:async';

import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../codex_api.dart';
import '../codex_store.dart';
import '../easytier_service.dart';
import '../models.dart';
import '../notification_service.dart';
import '../theme.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.connection,
    required this.onDisconnect,
    required this.settings,
    required this.onSaveSettings,
    this.fallbackBaseUrls = const [],
    this.initialStore,
  });

  final ConnectionDetails connection;
  final Future<void> Function() onDisconnect;
  final AppSettings settings;
  final Future<void> Function(AppSettings settings) onSaveSettings;
  final List<String> fallbackBaseUrls;
  final CodexStore? initialStore;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final CodexStore store;
  final _composerController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  late final bool _ownsStore;

  @override
  void initState() {
    super.initState();
    _ownsStore = widget.initialStore == null;
    store =
        widget.initialStore ??
        CodexStore(
          CodexApi(
            widget.connection.baseUrl,
            widget.connection.token,
            fallbackBaseUrls: widget.fallbackBaseUrls,
          ),
          notificationSink: CodexNotificationService.instance,
        );
    store.addListener(_onStoreChanged);
    CodexNotificationService.instance.onThreadSelected = (threadId) {
      if (mounted) unawaited(store.select(threadId));
    };
    EasyTierService.instance.addListener(_onEasyTierChanged);
    if (_ownsStore) unawaited(store.start());
  }

  void _onEasyTierChanged() {
    if (!mounted) return;
    setState(() {});
    if (EasyTierService.instance.connected &&
        store.connectionState != 'online') {
      unawaited(store.refresh(silent: true));
    }
  }

  void _onStoreChanged() {
    if (!mounted) return;
    setState(() {});
    if (store.active || _sending) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (target <= 0) return;
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    store.removeListener(_onStoreChanged);
    if (CodexNotificationService.instance.onThreadSelected != null) {
      CodexNotificationService.instance.onThreadSelected = null;
    }
    EasyTierService.instance.removeListener(_onEasyTierChanged);
    if (_ownsStore) store.dispose();
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _composerController.text.trim();
    if (text.isEmpty || _sending || store.selectedId == null) return;
    setState(() => _sending = true);
    await store.send(text);
    if (!mounted) return;
    _composerController.clear();
    setState(() => _sending = false);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    _scrollToBottom();
  }

  Future<void> _newThread() async {
    final controller = TextEditingController(text: store.selected?.cwd ?? '');
    final cwd = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建任务'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '电脑上的工作目录',
            hintText: r'E:\work\my-project',
            prefixIcon: Icon(Icons.folder_outlined),
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (cwd == null || cwd.isEmpty) return;
    await store.create(cwd);
    if (mounted) Navigator.maybePop(context);
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          settings: widget.settings,
          onSave: widget.onSaveSettings,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = store.selected;
    return Scaffold(
      drawer: _ThreadDrawer(
        store: store,
        onSelect: (id) {
          Navigator.pop(context);
          unawaited(store.select(id));
        },
        onNew: _newThread,
        onSettings: () {
          Navigator.pop(context);
          unawaited(_openSettings());
        },
        onDisconnect: widget.onDisconnect,
      ),
      appBar: AppBar(
        shape: const Border(bottom: BorderSide(color: line)),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selected?.title ?? 'CodexRoam',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            _LiveStatus(store: store),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: () => store.refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (value) {
              if (value == 'new') _newThread();
              if (value == 'settings') _openSettings();
              if (value == 'disconnect') widget.onDisconnect();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'new',
                child: ListTile(
                  leading: Icon(Icons.add_rounded),
                  title: Text('新建任务'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('连接设置'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'disconnect',
                child: ListTile(
                  leading: Icon(Icons.link_off_rounded),
                  title: Text('更换电脑'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (store.error != null) _ErrorBar(store: store),
          if (store.approval != null) _ApprovalBar(store: store),
          Expanded(
            child: _Conversation(store: store, controller: _scrollController),
          ),
          _Composer(
            controller: _composerController,
            enabled:
                store.selectedId != null && store.connectionState == 'online',
            active: store.active,
            sending: _sending,
            onSend: _send,
            onStop: store.interrupt,
          ),
        ],
      ),
    );
  }
}

class _LiveStatus extends StatelessWidget {
  const _LiveStatus({required this.store});

  final CodexStore store;

  @override
  Widget build(BuildContext context) {
    final offline = store.connectionState != 'online';
    final active = store.active;
    final color = offline
        ? danger
        : active
        ? mint
        : muted;
    final label = offline
        ? EasyTierService.instance.phase == 'starting'
              ? 'EasyTier 正在连接'
              : '连接中断'
        : active
        ? 'Codex 正在工作'
        : '已连接 · 空闲';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 10.5)),
      ],
    );
  }
}

class _ErrorBar extends StatelessWidget {
  const _ErrorBar({required this.store});

  final CodexStore store;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: dangerSoft,
      child: InkWell(
        onTap: store.clearError,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: danger, size: 18),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  store.error!,
                  style: const TextStyle(color: danger, fontSize: 12),
                ),
              ),
              const Icon(Icons.close, color: danger, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApprovalBar extends StatelessWidget {
  const _ApprovalBar({required this.store});

  final CodexStore store;

  @override
  Widget build(BuildContext context) {
    final approval = store.approval!;
    return Container(
      color: const Color(0xFFFFF7E5),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.lock_outline_rounded,
              size: 19,
              color: Color(0xFF9A6814),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '等待你的确认',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 3),
                Text(
                  approval.command,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => store.approve('decline'),
            child: const Text('拒绝'),
          ),
          FilledButton(
            onPressed: () => store.approve('accept'),
            child: const Text('允许'),
          ),
        ],
      ),
    );
  }
}

class _Conversation extends StatelessWidget {
  const _Conversation({required this.store, required this.controller});

  final CodexStore store;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    if (store.loading && store.detail == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    final turns = store.detail?.turns ?? const <CodexTurn>[];
    if (store.selectedId == null) {
      return const _EmptyState(
        icon: Icons.forum_outlined,
        title: '选择一个任务',
        subtitle: '从左侧会话列表打开任务，或新建一个任务。',
      );
    }
    if (turns.isEmpty) {
      return const _EmptyState(
        icon: Icons.terminal_rounded,
        title: '开始一项工作',
        subtitle: '在下方发送指令，Codex 会在这台电脑上执行。',
      );
    }
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
      itemCount: turns.length,
      itemBuilder: (context, index) => _TurnView(turn: turns[index]),
    );
  }
}

class _TurnView extends StatelessWidget {
  const _TurnView({required this.turn});

  final CodexTurn turn;

  @override
  Widget build(BuildContext context) {
    final visible = turn.items.where((item) => item.visible).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: turn.inProgress ? mint : line,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                turn.inProgress ? '实时活动' : '已完成',
                style: TextStyle(
                  color: turn.inProgress ? mint : muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Expanded(child: Divider(indent: 10)),
            ],
          ),
          const SizedBox(height: 12),
          ...visible.map((item) => _MessageView(item: item)),
          if (turn.inProgress)
            const Padding(
              padding: EdgeInsets.only(top: 8, left: 12),
              child: _WorkingIndicator(),
            ),
        ],
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.item});

  final CodexItem item;

  @override
  Widget build(BuildContext context) {
    if (item.type == 'userMessage') {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          margin: const EdgeInsets.only(bottom: 12, left: 38),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: panelRaised,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            item.text,
            style: const TextStyle(fontSize: 14, height: 1.55),
          ),
        ),
      );
    }
    if (item.type == 'commandExecution') {
      return _CommandMessage(item: item);
    }
    final reasoning = item.type == 'reasoning';
    final label = switch (item.type) {
      'reasoning' => '思考摘要',
      'plan' => '计划',
      'fileChange' => '文件变更',
      'mcpToolCall' => '工具调用',
      _ => 'Codex',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                reasoning
                    ? Icons.psychology_outlined
                    : Icons.auto_awesome_outlined,
                size: 15,
                color: reasoning ? muted : mint,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: reasoning ? muted : ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          SelectableText(
            item.text,
            style: TextStyle(
              color: reasoning ? muted : ink,
              fontSize: reasoning ? 12.5 : 14,
              height: 1.62,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommandMessage extends StatelessWidget {
  const _CommandMessage({required this.item});

  final CodexItem item;

  @override
  Widget build(BuildContext context) {
    final content = [
      if (item.command?.isNotEmpty == true) r'$ ' + item.command!,
      if (item.output?.trim().isNotEmpty == true) item.output!.trimRight(),
    ].join('\n');
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: commandSurface,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.terminal_rounded,
                  color: Color(0xFF8DA0AE),
                  size: 15,
                ),
                const SizedBox(width: 7),
                const Text(
                  '命令',
                  style: TextStyle(color: Color(0xFFBBC6CE), fontSize: 11),
                ),
                const Spacer(),
                Text(
                  item.status ?? '',
                  style: const TextStyle(
                    color: Color(0xFF7D929F),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF2A3540)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              content,
              style: const TextStyle(
                color: commandText,
                fontFamily: 'monospace',
                fontSize: 11.5,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkingIndicator extends StatelessWidget {
  const _WorkingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox.square(
          dimension: 13,
          child: CircularProgressIndicator(strokeWidth: 1.6),
        ),
        SizedBox(width: 9),
        Text('等待下一条实时事件…', style: TextStyle(color: muted, fontSize: 11)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: mint, size: 28),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.active,
    required this.sending,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool active;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          color: panel,
          border: Border(top: BorderSide(color: line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: enabled ? '给 Codex 发送指令' : '等待电脑连接',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            if (active)
              IconButton.filledTonal(
                tooltip: '停止当前任务',
                onPressed: onStop,
                icon: const Icon(Icons.stop_rounded),
              )
            else
              IconButton.filled(
                tooltip: '发送',
                onPressed: enabled && !sending ? onSend : null,
                icon: sending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_upward_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

class _ThreadDrawer extends StatelessWidget {
  const _ThreadDrawer({
    required this.store,
    required this.onSelect,
    required this.onNew,
    required this.onSettings,
    required this.onDisconnect,
  });

  final CodexStore store;
  final ValueChanged<String> onSelect;
  final VoidCallback onNew;
  final VoidCallback onSettings;
  final Future<void> Function() onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.sizeOf(context).width.clamp(280, 340).toDouble(),
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: ink,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(
                      Icons.terminal_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '本机任务',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '新建任务',
                    onPressed: onNew,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: store.threads.isEmpty
                  ? const Center(
                      child: Text('暂无任务', style: TextStyle(color: muted)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: store.threads.length,
                      itemBuilder: (context, index) {
                        final thread = store.threads[index];
                        final selected = thread.id == store.selectedId;
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: ListTile(
                            selected: selected,
                            selectedTileColor: panelRaised,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                            title: Text(
                              thread.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: thread.active
                                          ? mint
                                          : muted.withValues(alpha: .55),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${thread.stateLabel} · ${_shortPath(thread.cwd)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: muted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            onTap: () => onSelect(thread.id),
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('连接设置', style: TextStyle(fontSize: 13)),
              onTap: onSettings,
            ),
            ListTile(
              leading: const Icon(Icons.link_off_rounded),
              title: const Text('更换电脑', style: TextStyle(fontSize: 13)),
              onTap: onDisconnect,
            ),
          ],
        ),
      ),
    );
  }

  String _shortPath(String value) {
    final parts = value
        .replaceAll('\\', '/')
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.isEmpty ? '未知目录' : parts.last;
  }
}
