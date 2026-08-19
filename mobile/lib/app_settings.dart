import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

const _compiledServerUrl = String.fromEnvironment('CODEX_SERVER_URL');
// Explicit EasyTier address takes precedence over the legacy server URL.
const _compiledEasyTierAddress = String.fromEnvironment('EASYTIER_ADDRESS');
const _compiledFallbackUrl = String.fromEnvironment('CODEX_FALLBACK_URL');
const _compiledToken = String.fromEnvironment('CODEX_CONSOLE_TOKEN');
const _compiledNetworkName = String.fromEnvironment('EASYTIER_NETWORK_NAME');
const _compiledNetworkSecret = String.fromEnvironment(
  'EASYTIER_NETWORK_SECRET',
);
const _compiledPeer = String.fromEnvironment('EASYTIER_PEER');
const _compiledNetworkCidr = String.fromEnvironment(
  'EASYTIER_NETWORK_CIDR',
  defaultValue: '10.126.126.0/24',
);

class EasyTierSettings {
  const EasyTierSettings({
    required this.enabled,
    required this.networkName,
    required this.networkSecret,
    required this.peer,
    required this.networkCidr,
  });

  final bool enabled;
  final String networkName;
  final String networkSecret;
  final String peer;
  final String networkCidr;

  bool get configured =>
      enabled &&
      networkName.trim().isNotEmpty &&
      networkSecret.isNotEmpty &&
      peer.trim().isNotEmpty &&
      networkCidr.trim().isNotEmpty;

  Map<String, String> toPlatformArguments() => {
    'networkName': networkName.trim(),
    'networkSecret': networkSecret,
    'peer': peer.trim(),
    'networkCidr': networkCidr.trim(),
  };

  @override
  bool operator ==(Object other) =>
      other is EasyTierSettings &&
      enabled == other.enabled &&
      networkName == other.networkName &&
      networkSecret == other.networkSecret &&
      peer == other.peer &&
      networkCidr == other.networkCidr;

  @override
  int get hashCode =>
      Object.hash(enabled, networkName, networkSecret, peer, networkCidr);
}

class AppSettings {
  const AppSettings({
    required this.serverUrl,
    required this.fallbackUrl,
    required this.token,
    required this.easyTier,
  });

  static const _prefix = 'settings.';

  final String serverUrl;
  final String fallbackUrl;
  final String token;
  final EasyTierSettings easyTier;

  static AppSettings load(SharedPreferences preferences) {
    final networkName =
        preferences.getString('${_prefix}easyTierNetworkName') ??
        _compiledNetworkName;
    final peer =
        preferences.getString('${_prefix}easyTierPeer') ?? _compiledPeer;
    return AppSettings(
      serverUrl:
          preferences.getString('${_prefix}serverUrl') ??
          preferences.getString('baseUrl') ??
          (_compiledEasyTierAddress.trim().isNotEmpty
              ? _compiledEasyTierAddress
              : _compiledServerUrl),
      fallbackUrl:
          preferences.getString('${_prefix}fallbackUrl') ??
          _compiledFallbackUrl,
      token:
          preferences.getString('${_prefix}token') ??
          preferences.getString('token') ??
          _compiledToken,
      easyTier: EasyTierSettings(
        enabled:
            preferences.getBool('${_prefix}easyTierEnabled') ??
            (networkName.isNotEmpty && peer.isNotEmpty),
        networkName: networkName,
        networkSecret:
            preferences.getString('${_prefix}easyTierNetworkSecret') ??
            _compiledNetworkSecret,
        peer: peer,
        networkCidr:
            preferences.getString('${_prefix}easyTierNetworkCidr') ??
            _compiledNetworkCidr,
      ),
    );
  }

  ConnectionDetails? get connection {
    if (serverUrl.trim().isEmpty || token.trim().isEmpty) return null;
    return ConnectionDetails(serverUrl.trim(), token.trim());
  }

  List<String> get fallbackBaseUrls =>
      fallbackUrl.trim().isEmpty ? const [] : [fallbackUrl.trim()];

  AppSettings copyWith({
    String? serverUrl,
    String? fallbackUrl,
    String? token,
    EasyTierSettings? easyTier,
  }) => AppSettings(
    serverUrl: serverUrl ?? this.serverUrl,
    fallbackUrl: fallbackUrl ?? this.fallbackUrl,
    token: token ?? this.token,
    easyTier: easyTier ?? this.easyTier,
  );

  Future<void> save(SharedPreferences preferences) async {
    await Future.wait([
      preferences.setString('${_prefix}serverUrl', serverUrl.trim()),
      preferences.setString('${_prefix}fallbackUrl', fallbackUrl.trim()),
      preferences.setString('${_prefix}token', token.trim()),
      preferences.setBool('${_prefix}easyTierEnabled', easyTier.enabled),
      preferences.setString(
        '${_prefix}easyTierNetworkName',
        easyTier.networkName.trim(),
      ),
      preferences.setString(
        '${_prefix}easyTierNetworkSecret',
        easyTier.networkSecret,
      ),
      preferences.setString('${_prefix}easyTierPeer', easyTier.peer.trim()),
      preferences.setString(
        '${_prefix}easyTierNetworkCidr',
        easyTier.networkCidr.trim(),
      ),
    ]);
    await preferences.remove('baseUrl');
    await preferences.remove('token');
  }
}
