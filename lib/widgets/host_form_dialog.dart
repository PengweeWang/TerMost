import 'package:flutter/material.dart';
import '../models/ssh_host.dart';
import '../services/storage_service.dart';
import 'key_generate_dialog.dart';

class HostFormDialog extends StatefulWidget {
  final SshHost? host;

  const HostFormDialog({super.key, this.host});

  @override
  State<HostFormDialog> createState() => _HostFormDialogState();
}

class _HostFormDialogState extends State<HostFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _passphraseController;

  String _authType = 'password';
  String? _selectedKeyId;
  bool _obscurePassword = true;
  bool _obscurePassphrase = true;

  @override
  void initState() {
    super.initState();
    final h = widget.host;
    _nameController = TextEditingController(text: h?.name ?? '');
    _hostController = TextEditingController(text: h?.host ?? '');
    _portController = TextEditingController(text: (h?.port ?? 22).toString());
    _usernameController = TextEditingController(text: h?.username ?? 'root');
    _passwordController = TextEditingController(text: h?.password ?? '');
    _passphraseController = TextEditingController(text: h?.passphrase ?? '');
    _authType = h?.authType ?? 'password';
    _selectedKeyId = h?.keyId;

    final keys = StorageService().keys;
    if (_selectedKeyId == null && keys.isNotEmpty) {
      _selectedKeyId = keys.first.id;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _passphraseController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final port = int.tryParse(_portController.text.trim()) ?? 22;
    final name = _nameController.text.trim().isEmpty
        ? '${_usernameController.text.trim()}@${_hostController.text.trim()}'
        : _nameController.text.trim();

    final host = SshHost(
      id: widget.host?.id ?? 'host_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      host: _hostController.text.trim(),
      port: port,
      username: _usernameController.text.trim(),
      authType: _authType,
      password: _authType == 'password' ? _passwordController.text : null,
      keyId: _authType == 'key' ? _selectedKeyId : null,
      passphrase: _authType == 'key' && _passphraseController.text.isNotEmpty
          ? _passphraseController.text
          : null,
    );

    Navigator.of(context).pop(host);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final keys = StorageService().keys;

    return AlertDialog(
      title: Text(widget.host == null ? '添加 SSH 主机' : '编辑 SSH 主机'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Host Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '主机备注名称 (可选)',
                    hintText: '如: 我的腾讯云服务器',
                    prefixIcon: Icon(Icons.bookmark_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                // Host Address & Port
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _hostController,
                        decoration: const InputDecoration(
                          labelText: '主机地址 / IP *',
                          hintText: '192.168.1.10 或 domain',
                          prefixIcon: Icon(Icons.dns_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? '请输入主机地址' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _portController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '端口',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final p = int.tryParse(v ?? '');
                          if (p == null || p <= 0 || p > 65535) return '错误';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Username
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: '用户名 *',
                    hintText: 'root / ubuntu / admin',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? '请输入用户名' : null,
                ),
                const SizedBox(height: 20),
                // Auth Type Switch
                const Text(
                  '认证方式',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'password',
                      label: Text('密码登录'),
                      icon: Icon(Icons.password),
                    ),
                    ButtonSegment(
                      value: 'key',
                      label: Text('密钥登录'),
                      icon: Icon(Icons.key),
                    ),
                  ],
                  selected: {_authType},
                  onSelectionChanged: (set) {
                    setState(() => _authType = set.first);
                  },
                ),
                const SizedBox(height: 16),
                if (_authType == 'password') ...[
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: '密码',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                ] else ...[
                  // Key Selection
                  if (keys.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '当前尚未生成或导入任何密钥',
                            style: TextStyle(
                              color: colorScheme.onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          FilledButton.tonalIcon(
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('立即生成密钥'),
                            onPressed: () async {
                              final newKey = await showDialog(
                                context: context,
                                builder: (_) => const KeyGenerateDialog(),
                              );
                              if (newKey != null) {
                                setState(() {
                                  _selectedKeyId = newKey.id;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    DropdownButtonFormField<String>(
                      value: _selectedKeyId,
                      decoration: const InputDecoration(
                        labelText: '选择 SSH 密钥 *',
                        prefixIcon: Icon(Icons.vpn_key_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: keys.map((k) {
                        return DropdownMenuItem(
                          value: k.id,
                          child: Text('${k.name} [${k.algorithm}]'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedKeyId = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passphraseController,
                      obscureText: _obscurePassphrase,
                      decoration: InputDecoration(
                        labelText: '密钥口令 Passphrase (若有)',
                        prefixIcon: const Icon(Icons.shield_outlined),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassphrase
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(
                              () => _obscurePassphrase = !_obscurePassphrase),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
