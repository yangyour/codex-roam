import 'package:flutter/material.dart';

import '../models.dart';
import '../easytier_service.dart';
import '../theme.dart';

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({
    super.key,
    required this.onConnect,
    this.initialConnection,
  });

  final Future<String?> Function(ConnectionDetails details) onConnect;
  final ConnectionDetails? initialConnection;

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final connection = widget.initialConnection;
    if (connection != null) {
      _urlController.text = connection.baseUrl;
      _tokenController.text = connection.token;
    }
    EasyTierService.instance.addListener(_onNetworkChanged);
  }

  void _onNetworkChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    EasyTierService.instance.removeListener(_onNetworkChanged);
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final details = ConnectionDetails.parse(
      _urlController.text,
      _tokenController.text,
    );
    if (details == null) {
      setState(() => _error = '请输入电脑地址和访问令牌，或直接粘贴完整连接地址。');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await widget.onConnect(details);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BrandMark(),
                  const SizedBox(height: 34),
                  Text(
                    '连接这台电脑',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '通过 EasyTier 加密虚拟网络连接，无需处于同一个 Wi-Fi。连接信息只保存在这部手机上。',
                    style: TextStyle(color: muted, fontSize: 14, height: 1.55),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _urlController,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '电脑地址或完整连接地址',
                      hintText: 'http://10.0.0.1:4174',
                      prefixIcon: Icon(Icons.lan_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _tokenController,
                    autocorrect: false,
                    obscureText: true,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: '访问令牌（完整地址已包含时可不填）',
                      prefixIcon: Icon(Icons.key_outlined),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: dangerSoft,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: danger.withValues(alpha: .25),
                        ),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: danger, fontSize: 13),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward_rounded),
                    label: Text(_submitting ? '正在连接' : '连接'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Icon(
                        EasyTierService.instance.connected
                            ? Icons.shield_rounded
                            : Icons.shield_outlined,
                        size: 17,
                        color: EasyTierService.instance.connected
                            ? mint
                            : muted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          EasyTierService.instance.phase == 'connected'
                              ? 'EasyTier 已连接，优先使用私有地址；Wi-Fi 地址自动回退。'
                              : EasyTierService.instance.phase == 'error'
                              ? EasyTierService.instance.message
                              : '优先使用 EasyTier 私有地址，当前 Wi-Fi 地址作为自动回退。',
                          style: TextStyle(
                            color: EasyTierService.instance.phase == 'error'
                                ? danger
                                : muted,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.terminal_rounded,
            color: Colors.white,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CodexRoam',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            Text(
              'ANDROID CLIENT',
              style: TextStyle(color: muted, fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }
}
