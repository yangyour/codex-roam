import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../easytier_service.dart';
import '../models.dart';
import '../theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.settings, required this.onSave});

  final AppSettings settings;
  final Future<void> Function(AppSettings settings) onSave;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _serverController;
  late final TextEditingController _fallbackController;
  late final TextEditingController _tokenController;
  late final TextEditingController _networkNameController;
  late final TextEditingController _networkSecretController;
  late final TextEditingController _peerController;
  late final TextEditingController _cidrController;
  late bool _easyTierEnabled;
  bool _showToken = false;
  bool _showNetworkSecret = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final settings = widget.settings;
    _serverController = TextEditingController(text: settings.serverUrl);
    _fallbackController = TextEditingController(text: settings.fallbackUrl);
    _tokenController = TextEditingController(text: settings.token);
    _networkNameController = TextEditingController(
      text: settings.easyTier.networkName,
    );
    _networkSecretController = TextEditingController(
      text: settings.easyTier.networkSecret,
    );
    _peerController = TextEditingController(text: settings.easyTier.peer);
    _cidrController = TextEditingController(
      text: settings.easyTier.networkCidr,
    );
    _easyTierEnabled = settings.easyTier.enabled;
    EasyTierService.instance.addListener(_onEasyTierChanged);
  }

  void _onEasyTierChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    EasyTierService.instance.removeListener(_onEasyTierChanged);
    for (final controller in [
      _serverController,
      _fallbackController,
      _tokenController,
      _networkNameController,
      _networkSecretController,
      _peerController,
      _cidrController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;
    final connection = ConnectionDetails.parse(
      _serverController.text,
      _tokenController.text,
    );
    if (connection == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final settings = AppSettings(
      serverUrl: connection.baseUrl,
      fallbackUrl: _normalizeOptionalUrl(_fallbackController.text),
      token: connection.token,
      easyTier: EasyTierSettings(
        enabled: _easyTierEnabled,
        networkName: _networkNameController.text.trim(),
        networkSecret: _networkSecretController.text,
        peer: _peerController.text.trim(),
        networkCidr: _cidrController.text.trim(),
      ),
    );
    try {
      await widget.onSave(settings);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String? _requiredConnection(String? value) {
    final parsed = ConnectionDetails.parse(
      value ?? '',
      _tokenController.text.isEmpty
          ? 'validation-token'
          : _tokenController.text,
    );
    return parsed == null ? '请输入有效的电脑地址' : null;
  }

  String? _requiredToken(String? value) =>
      value?.trim().isEmpty == true ? '请输入访问令牌' : null;

  String? _optionalUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return ConnectionDetails.parse(value, 'validation-token') == null
        ? '请输入有效的回退地址'
        : null;
  }

  String? _requiredEasyTier(String? value) {
    if (!_easyTierEnabled) return null;
    return value?.trim().isEmpty == true ? '启用 EasyTier 时不能为空' : null;
  }

  String? _peerValidator(String? value) {
    final required = _requiredEasyTier(value);
    if (required != null || !_easyTierEnabled) return required;
    final uri = Uri.tryParse(value!.trim());
    return uri == null || uri.scheme.isEmpty || uri.host.isEmpty
        ? '请输入有效的节点 URI'
        : null;
  }

  String? _cidrValidator(String? value) {
    final required = _requiredEasyTier(value);
    if (required != null || !_easyTierEnabled) return required;
    final parts = value!.trim().split('/');
    if (parts.length != 2) return '请输入有效的 IPv4 CIDR';
    final octets = parts.first.split('.').map(int.tryParse).toList();
    final prefix = int.tryParse(parts.last);
    final valid =
        octets.length == 4 &&
        octets.every((item) => item != null && item >= 0 && item <= 255) &&
        prefix != null &&
        prefix >= 0 &&
        prefix <= 32;
    return valid ? null : '请输入有效的 IPv4 CIDR';
  }

  String _normalizeOptionalUrl(String value) {
    if (value.trim().isEmpty) return '';
    return ConnectionDetails.parse(value, 'validation-token')!.baseUrl;
  }

  @override
  Widget build(BuildContext context) {
    final network = EasyTierService.instance;
    return Scaffold(
      appBar: AppBar(
        shape: const Border(bottom: BorderSide(color: line)),
        title: const Text(
          '连接设置',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionLabel(icon: Icons.computer_rounded, title: '电脑连接'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _serverController,
                      validator: _requiredConnection,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'EasyTier 电脑地址',
                        hintText: 'http://10.0.0.1:4174',
                        prefixIcon: Icon(Icons.dns_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fallbackController,
                      validator: _optionalUrl,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Wi-Fi 回退地址（可选）',
                        hintText: 'http://192.168.1.10:4174',
                        prefixIcon: Icon(Icons.wifi_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _tokenController,
                      validator: _requiredToken,
                      obscureText: !_showToken,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: '访问令牌',
                        prefixIcon: const Icon(Icons.key_rounded),
                        suffixIcon: IconButton(
                          tooltip: _showToken ? '隐藏令牌' : '显示令牌',
                          onPressed: () =>
                              setState(() => _showToken = !_showToken),
                          icon: Icon(
                            _showToken
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _SectionLabel(
                      icon: Icons.shield_rounded,
                      title: 'EasyTier 私有网络',
                      trailing: _NetworkState(
                        phase: network.phase,
                        message: network.message,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        '启用内置 EasyTier',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      value: _easyTierEnabled,
                      onChanged: (value) {
                        setState(() => _easyTierEnabled = value);
                        _formKey.currentState?.validate();
                      },
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _networkNameController,
                      validator: _requiredEasyTier,
                      enabled: _easyTierEnabled,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: '网络名称',
                        prefixIcon: Icon(Icons.hub_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _networkSecretController,
                      validator: _requiredEasyTier,
                      enabled: _easyTierEnabled,
                      obscureText: !_showNetworkSecret,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: '网络密钥',
                        prefixIcon: const Icon(Icons.password_rounded),
                        suffixIcon: IconButton(
                          tooltip: _showNetworkSecret ? '隐藏密钥' : '显示密钥',
                          onPressed: () => setState(
                            () => _showNetworkSecret = !_showNetworkSecret,
                          ),
                          icon: Icon(
                            _showNetworkSecret
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _peerController,
                      validator: _peerValidator,
                      enabled: _easyTierEnabled,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: '公共节点',
                        hintText: 'tcp://example.com:11010',
                        prefixIcon: Icon(Icons.public_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cidrController,
                      validator: _cidrValidator,
                      enabled: _easyTierEnabled,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: '虚拟网段',
                        hintText: '10.126.126.0/24',
                        prefixIcon: Icon(Icons.route_rounded),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: danger, fontSize: 12.5),
                      ),
                    ],
                    const SizedBox(height: 26),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(_saving ? '正在应用' : '保存并应用'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.title, this.trailing});

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: ink),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        if (trailing != null) ...[const Spacer(), Flexible(child: trailing!)],
      ],
    );
  }
}

class _NetworkState extends StatelessWidget {
  const _NetworkState({required this.phase, required this.message});

  final String phase;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = phase == 'connected'
        ? mint
        : phase == 'error'
        ? danger
        : muted;
    return Tooltip(
      message: message,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            phase == 'connected'
                ? '已连接'
                : phase == 'error'
                ? '异常'
                : '未连接',
            style: TextStyle(color: color, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
