import 'package:codex_roam/app_settings.dart';
import 'package:codex_roam/screens/settings_page.dart';
import 'package:codex_roam/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _initialSettings = AppSettings(
  serverUrl: 'http://10.126.126.10:4174',
  fallbackUrl: 'http://192.168.1.10:4174',
  token: 'bridge-token',
  easyTier: EasyTierSettings(
    enabled: true,
    networkName: 'private-network',
    networkSecret: 'private-secret',
    peer: 'tcp://example.com:11010',
    networkCidr: '10.126.126.0/24',
  ),
);

void main() {
  testWidgets('prefills, validates, and saves editable settings', (
    tester,
  ) async {
    AppSettings? saved;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: codexTheme,
        home: SettingsPage(
          settings: _initialSettings,
          onSave: (settings) async => saved = settings,
        ),
      ),
    );

    expect(find.text('http://10.126.126.10:4174'), findsOneWidget);
    expect(find.text('private-network'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, '网络密钥'), '');
    await tester.ensureVisible(find.text('保存并应用'));
    await tester.tap(find.text('保存并应用'));
    await tester.pump();

    expect(find.text('启用 EasyTier 时不能为空'), findsOneWidget);
    expect(saved, isNull);

    await tester.enterText(
      find.widgetWithText(TextFormField, '网络密钥'),
      'new-private-secret',
    );
    await tester.tap(find.text('保存并应用'));
    await tester.pumpAndSettle();

    expect(saved?.easyTier.networkSecret, 'new-private-secret');
    expect(saved?.serverUrl, 'http://10.126.126.10:4174');
  });
}
