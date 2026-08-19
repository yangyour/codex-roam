import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';
import 'codex_api.dart';
import 'easytier_service.dart';
import 'models.dart';
import 'screens/connection_page.dart';
import 'screens/home_page.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final settings = AppSettings.load(preferences);
  runApp(CodexMobileApp(preferences: preferences, initialSettings: settings));
}

class CodexMobileApp extends StatefulWidget {
  const CodexMobileApp({
    super.key,
    required this.preferences,
    required this.initialSettings,
  });

  final SharedPreferences preferences;
  final AppSettings initialSettings;

  @override
  State<CodexMobileApp> createState() => _CodexMobileAppState();
}

class _CodexMobileAppState extends State<CodexMobileApp> {
  late AppSettings _settings;
  ConnectionDetails? _connection;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    _connection = _settings.connection;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startEmbeddedNetwork());
    });
  }

  Future<void> _startEmbeddedNetwork() async {
    await EasyTierService.instance.initialize();
    await EasyTierService.instance.applySettings(_settings.easyTier);
  }

  Future<String?> _connect(ConnectionDetails connection) async {
    final nextSettings = _settings.copyWith(
      serverUrl: connection.baseUrl,
      token: connection.token,
    );
    final api = CodexApi(
      connection.baseUrl,
      connection.token,
      fallbackBaseUrls: nextSettings.fallbackBaseUrls,
    );
    try {
      await api.listThreads();
      await nextSettings.save(widget.preferences);
      if (mounted) {
        setState(() {
          _settings = nextSettings;
          _connection = connection;
        });
      }
      return null;
    } catch (error) {
      return error.toString().replaceFirst('Exception: ', '');
    } finally {
      api.close();
    }
  }

  Future<void> _disconnect() async {
    final nextSettings = _settings.copyWith(serverUrl: '', token: '');
    await nextSettings.save(widget.preferences);
    if (mounted) {
      setState(() {
        _settings = nextSettings;
        _connection = null;
      });
    }
  }

  Future<void> _saveSettings(AppSettings settings) async {
    await settings.save(widget.preferences);
    await EasyTierService.instance.applySettings(
      settings.easyTier,
      restart: true,
    );
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _connection = settings.connection;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CodexRoam',
      debugShowCheckedModeBanner: false,
      theme: codexTheme,
      home: _connection == null
          ? ConnectionPage(
              initialConnection: ConnectionDetails(
                _settings.serverUrl,
                _settings.token,
              ),
              onConnect: _connect,
            )
          : HomePage(
              key: ValueKey(
                Object.hash(
                  _connection!.baseUrl,
                  _connection!.token,
                  _settings.fallbackUrl,
                ),
              ),
              connection: _connection!,
              fallbackBaseUrls: _settings.fallbackBaseUrls,
              settings: _settings,
              onSaveSettings: _saveSettings,
              onDisconnect: _disconnect,
            ),
    );
  }
}
