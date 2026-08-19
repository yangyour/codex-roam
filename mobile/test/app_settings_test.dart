import 'package:codex_roam/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads and migrates legacy connection preferences', () async {
    SharedPreferences.setMockInitialValues({
      'baseUrl': 'http://192.168.1.20:4174',
      'token': 'legacy-token',
    });
    final preferences = await SharedPreferences.getInstance();

    final settings = AppSettings.load(preferences);

    expect(settings.serverUrl, 'http://192.168.1.20:4174');
    expect(settings.token, 'legacy-token');
    expect(settings.easyTier.enabled, isFalse);

    await settings.save(preferences);
    expect(preferences.getString('settings.serverUrl'), settings.serverUrl);
    expect(preferences.getString('settings.token'), settings.token);
    expect(preferences.containsKey('baseUrl'), isFalse);
    expect(preferences.containsKey('token'), isFalse);
  });

  test('persists editable connection and EasyTier settings', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    const settings = AppSettings(
      serverUrl: ' http://10.126.126.10:4174 ',
      fallbackUrl: ' http://192.168.1.10:4174 ',
      token: ' bridge-token ',
      easyTier: EasyTierSettings(
        enabled: true,
        networkName: ' private-network ',
        networkSecret: 'long-private-secret',
        peer: ' tcp://example.com:11010 ',
        networkCidr: ' 10.126.126.0/24 ',
      ),
    );

    await settings.save(preferences);
    final loaded = AppSettings.load(preferences);

    expect(loaded.serverUrl, 'http://10.126.126.10:4174');
    expect(loaded.fallbackUrl, 'http://192.168.1.10:4174');
    expect(loaded.token, 'bridge-token');
    expect(loaded.easyTier.enabled, isTrue);
    expect(loaded.easyTier.networkName, 'private-network');
    expect(loaded.easyTier.networkSecret, 'long-private-secret');
    expect(loaded.easyTier.peer, 'tcp://example.com:11010');
    expect(loaded.easyTier.networkCidr, '10.126.126.0/24');
    expect(loaded.easyTier.configured, isTrue);
  });

  test('EasyTier requires a non-empty secret when enabled', () {
    const settings = EasyTierSettings(
      enabled: true,
      networkName: 'private-network',
      networkSecret: '',
      peer: 'tcp://example.com:11010',
      networkCidr: '10.126.126.0/24',
    );

    expect(settings.configured, isFalse);
  });
}
