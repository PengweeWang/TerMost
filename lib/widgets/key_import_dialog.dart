import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/ssh_key_entry.dart';
import '../services/storage_service.dart';
import '../src/rust/api/simple.dart' as rust_api;

class KeyImportDialog extends StatefulWidget {
  const KeyImportDialog({super.key});

  @override
  State<KeyImportDialog> createState() => _KeyImportDialogState();
}

class _KeyImportDialogState extends State<KeyImportDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController(text: 'imported_key');
  final _privateKeyController = TextEditingController();
  final _passphraseController = TextEditingController();

  bool _obscurePassphrase = true;
  bool _isImporting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _privateKeyController.dispose();
    _passphraseController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        _privateKeyController.text = data.text!;
      });
    }
  }

  Future<void> _import() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isImporting = true;
      _errorMessage = null;
    });

    try {
      final keyText = _privateKeyController.text.trim();
      final pass = _passphraseController.text.trim();

      final res = rust_api.parseKeyPair(
        privateKeyOpenssh: keyText,
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
            content: Text('成功导入密钥 "${entry.name}" [${entry.algorithm}]'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
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
          Icon(Icons.file_download_outlined),
          SizedBox(width: 8),
          Text('导入 SSH 私钥'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 460,
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
                    labelText: '密钥备注名称 *',
                    hintText: '如: github_key',
                    prefixIcon: Icon(Icons.label_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? '请输入密钥备注名称' : null,
                ),
                const SizedBox(height: 16),
                // Private Key Text Area
                TextFormField(
                  controller: _privateKeyController,
                  maxLines: 6,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                  ),
                  decoration: InputDecoration(
                    labelText: '私钥文本 (OpenSSH / PEM 格式) *',
                    hintText: '-----BEGIN OPENSSH PRIVATE KEY-----\n...',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.paste),
                      tooltip: '从剪贴板粘贴',
                      onPressed: _pasteFromClipboard,
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? '请粘贴私钥内容' : null,
                ),
                const SizedBox(height: 16),
                // Passphrase
                TextFormField(
                  controller: _passphraseController,
                  obscureText: _obscurePassphrase,
                  decoration: InputDecoration(
                    labelText: '密钥口令 Passphrase (若私钥已加密)',
                    hintText: '输入以解密私钥',
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
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _isImporting ? null : _import,
          icon: _isImporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download),
          label: Text(_isImporting ? '导入中...' : '导入'),
        ),
      ],
    );
  }
}
