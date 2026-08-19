import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'codex_api.dart';
import 'easytier_service.dart';
import 'models.dart';
import 'screens/connection_page.dart';
import 'screens/home_page.dart';
import 'theme.dart';

const compiledServerUrl = String.fromEnvironment('CODEX_SERVER_URL');
const compiledFallbackUrl = String.fromEnvironment('CODEX_FALLBACK_URL');

const defaultConnection = ConnectionDetails(
  compiledServerUrl,
  String.fromEnvironment('CODEX_CONSOLE_TOKEN'),
);
const fallbackBaseUrls = <String>[
  if (compiledFallbackUrl != '') compiledFallbackUrl,
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final baseUrl = preferences.getString('baseUrl');
  final token = preferences.getString('token');
  final savedConnection = baseUrl != null && token != null
      ? ConnectionDetails(baseUrl, token)
      : null;
  final initialConnection = savedConnection == null
      ? null
      : ConnectionDetails(defaultConnection.baseUrl, savedConnection.token);
  runApp(
    CodexMobileApp(
      preferences: preferences,
      initialConnection: initialConnection,
    ),
  );
}

class CodexMobileApp extends StatefulWidget {
  const CodexMobileApp({
    super.key,
    required this.preferences,
    this.initialConnection,
  });

  final SharedPreferences preferences;
  final ConnectionDetails? initialConnection;

  @override
  State<CodexMobileApp> createState() => _CodexMobileAppState();
}

class _CodexMobileAppState extends State<CodexMobileApp> {
  ConnectionDetails? _connection;

  @override
  void initState() {
    super.initState();
    _connection = widget.initialConnection;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startEmbeddedNetwork());
    });
  }

  Future<void> _startEmbeddedNetwork() async {
    await EasyTierService.instance.initialize();
    await EasyTierService.instance.ensureStarted();
  }

  Future<String?> _connect(ConnectionDetails connection) async {
    final api = CodexApi(
      connection.baseUrl,
      connection.token,
      fallbackBaseUrls: fallbackBaseUrls,
    );
    try {
      await api.listThreads();
      await widget.preferences.setString('baseUrl', connection.baseUrl);
      await widget.preferences.setString('token', connection.token);
      if (mounted) setState(() => _connection = connection);
      return null;
    } catch (error) {
      return error.toString().replaceFirst('Exception: ', '');
    } finally {
      api.close();
    }
  }

  Future<void> _disconnect() async {
    await widget.preferences.remove('baseUrl');
    await widget.preferences.remove('token');
    if (mounted) setState(() => _connection = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CodexRoam',
      debugShowCheckedModeBanner: false,
      theme: codexTheme,
      home: _connection == null
          ? ConnectionPage(
              initialConnection: defaultConnection,
              onConnect: _connect,
            )
          : HomePage(
              key: ValueKey(_connection!.baseUrl),
              connection: _connection!,
              fallbackBaseUrls: fallbackBaseUrls,
              onDisconnect: _disconnect,
            ),
    );
  }
}
