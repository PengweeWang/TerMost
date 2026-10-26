import 'package:flutter/material.dart';
import '../models/ssh_key_entry.dart';
import '../services/storage_service.dart';
import '../src/rust/api/simple.dart' as rust_api;

class KeyGenerateDialog extends StatefulWidget {
  const KeyGenerateDialog({super.key});

  @override
  State<KeyGenerateDialog> createState() => _KeyGenerateDialogState();
}

class _KeyGenerateDialogState extends State<KeyGenerateDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController(text: 'id_ed25519');
  final _commentController = TextEditingController(text: 'termost@android');
  final _passphraseController = TextEditingController();

  String _algorithm = 'ed25519';
  bool _obscurePassphrase = true;
  bool _isGenerating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _commentController.dispose();
    _passphraseController.dispose();
    super.dispose();
  }

  void _onAlgoChanged(String algo) {
    setState(() {
      _algorithm = algo;
      if (_nameController.text.startsWith('id_')) {
        _nameController.text = 'id_${algo.toLowerCase().replaceAll("-", "")}';
      }
    });
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final pass = _passphraseController.text.trim();
      final res = rust_api.generateKeyPair(
        algorithm: _algorithm,
        comment: _commentController.text.trim(),
        passphrase: pass.isNotEmpty ? pass : null,
      );

      final entry = SshKeyEntry(
        id: 'key_${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text.trim(),
        algorithm: res.algorithm,
        comment: res.comment,
        publicKeyOpenSsh: res.publicKeyOpenssh,
        privateKeyOpenSsh: res.privateKeyOpenssh,
        fingerprintSha256: res.fingerprintSha256,
        isEncrypted: res.isEncrypted,
      );

      await StorageService().saveKey(entry);

      if (mounted) {
        Navigator.of(context).pop(entry);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('密钥 "${entry.name}" 生成成功！'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.vpn_key),
          SizedBox(width: 8),
          Text('生成 SSH 密钥对'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),
                ],
                // Key Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '密钥名称 *',
                    hintText: '如: id_ed25519',
                    prefixIcon: Icon(Icons.label_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? '请输入密钥名称' : null,
                ),
                const SizedBox(height: 16),
                // Algorithm
                DropdownButtonFormField<String>(
                  value: _algorithm,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '密钥算法类型 *',
                    prefixIcon: Icon(Icons.security),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'ed25519',
                      child: Text(
                        'Ed25519 (推荐·轻量高效)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'rsa2048',
                      child: Text(
                        'RSA 2048 (传统兼顾)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'rsa4096',
                      child: Text(
                        'RSA 4096 (高安全性)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'ecdsa',
                      child: Text(
                        'ECDSA P-256 (椭圆曲线)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) _onAlgoChanged(val);
                  },
                ),
                const SizedBox(height: 16),
                // Comment
                TextFormField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                    labelText: '公钥注释 Comment',
                    hintText: '如: user@device',
                    prefixIcon: Icon(Icons.comment_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                // Passphrase
                TextFormField(
                  controller: _passphraseController,
                  obscureText: _obscurePassphrase,
                  decoration: InputDecoration(
                    labelText: '口令加密 Passphrase (可选)',
                    hintText: '设置密码以保护私钥',
                    prefixIcon: const Icon(Icons.lock_outline),
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
                const SizedBox(height: 8),
                Text(
                  '提示: 生成后可直接将 OpenSSH 公钥复制到远程服务器的 ~/.ssh/authorized_keys 中。',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isGenerating ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _isGenerating ? null : _generate,
          icon: _isGenerating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(_isGenerating ? '生成中...' : '生成密钥'),
        ),
      ],
    );
  }
}
