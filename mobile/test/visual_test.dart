import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codex_roam/app_settings.dart';
import 'package:codex_roam/codex_api.dart';
import 'package:codex_roam/codex_store.dart';
import 'package:codex_roam/models.dart';
import 'package:codex_roam/screens/connection_page.dart';
import 'package:codex_roam/screens/home_page.dart';
import 'package:codex_roam/theme.dart';

void main() {
  testWidgets('connection screen is top aligned and prefilled', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: codexTheme,
        debugShowCheckedModeBanner: false,
        home: ConnectionPage(
          initialConnection: const ConnectionDetails(
            'http://10.10.0.2:4174',
            'private-token',
          ),
          onConnect: (_) async => null,
        ),
      ),
    );
    await tester.pump();

    expect(tester.getTopLeft(find.text('CodexRoam')).dy, lessThan(140));
    final addressField = tester.widget<TextField>(find.byType(TextField).first);
    expect(addressField.controller?.text, 'http://10.10.0.2:4174');
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/connection.png'),
    );
  }, tags: ['golden']);

  testWidgets('home screen visual regression', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final thread = CodexThread(
      id: 'thread-1',
      preview: '检查项目并修复登录页问题',
      name: '修复登录页问题',
      cwd: r'E:\work\demo-app',
      updatedAt: 0,
      status: 'active',
      desktopOpen: true,
    );
    final store = CodexStore(CodexApi('http://127.0.0.1:4174', 'test'))
      ..threads = [thread]
      ..selectedId = thread.id
      ..connectionState = 'online'
      ..loading = false
      ..detail = CodexDetail(thread, [
        CodexTurn(
          id: 'turn-1',
          status: 'inProgress',
          startedAt: 0,
          items: [
            CodexItem(
              type: 'userMessage',
              id: 'user-1',
              text: '检查项目并修复登录页在小屏幕上的布局问题。',
            ),
            CodexItem(
              type: 'reasoning',
              id: 'reasoning-1',
              text: '我先检查页面结构和现有响应式规则，再定位产生横向溢出的组件。',
            ),
            CodexItem(
              type: 'commandExecution',
              id: 'command-1',
              text: '',
              command: 'flutter analyze',
              output: 'Analyzing demo-app...\nNo issues found!',
              status: 'completed',
            ),
            CodexItem(
              type: 'agentMessage',
              id: 'agent-1',
              text: '已经找到问题：表单容器使用了固定宽度。我正在改为响应式约束并补充测试。',
            ),
          ],
        ),
      ])
      ..approval = ApprovalRequest(
        id: 'approval-1',
        method: 'item/commandExecution/requestApproval',
        params: {'command': 'flutter test'},
      );

    await tester.pumpWidget(
      MaterialApp(
        theme: codexTheme,
        debugShowCheckedModeBanner: false,
        home: HomePage(
          connection: const ConnectionDetails('http://127.0.0.1:4174', 'test'),
          settings: const AppSettings(
            serverUrl: 'http://127.0.0.1:4174',
            fallbackUrl: '',
            token: 'test',
            easyTier: EasyTierSettings(
              enabled: false,
              networkName: '',
              networkSecret: '',
              peer: '',
              networkCidr: '10.126.126.0/24',
            ),
          ),
          onSaveSettings: (_) async {},
          initialStore: store,
          onDisconnect: () async {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/home.png'),
    );
    store.dispose();
  }, tags: ['golden']);
}
