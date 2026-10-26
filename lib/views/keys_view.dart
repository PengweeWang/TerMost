import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/ssh_key_entry.dart';
import '../services/storage_service.dart';
import '../widgets/key_generate_dialog.dart';
import '../widgets/key_import_dialog.dart';
import '../widgets/key_detail_sheet.dart';

class KeysView extends StatelessWidget {
  const KeysView({super.key});

  void _openGenerateDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => const KeyGenerateDialog(),
    );
  }

  void _openImportDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => const KeyImportDialog(),
    );
  }

  void _openKeyDetail(BuildContext context, SshKeyEntry key) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => KeyDetailSheet(keyEntry: key),
    );
  }

  void _copyPublicKey(BuildContext context, SshKeyEntry key) {
    Clipboard.setData(ClipboardData(text: key.publicKeyOpenSsh));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已复制 "${key.name}" 的公钥，可追加到远程服务器 authorized_keys 中'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final storage = StorageService();

    return ListenableBuilder(
      listenable: storage,
      builder: (context, _) {
        final keys = storage.keys;

        return Scaffold(
          appBar: AppBar(
            title: const Text('密钥管理'),
            actions: keys.isEmpty
                ? null
                : [
                    IconButton(
                      icon: const Icon(Icons.file_download_outlined),
                      tooltip: '导入私钥',
                      onPressed: () => _openImportDialog(context),
                    ),
                  ],
          ),
          body: keys.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.vpn_key_outlined,
                        size: 72,
                        color: colorScheme.outlineVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '尚未生成或导入任何 SSH 密钥',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FilledButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('生成密钥对'),
                            onPressed: () => _openGenerateDialog(context),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.file_download_outlined),
                            label: const Text('导入已有私钥'),
                            onPressed: () => _openImportDialog(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: keys.length,
                  itemBuilder: (context, index) {
                    final k = keys[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _openKeyDetail(context, k),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor:
                                        colorScheme.tertiaryContainer,
                                    child: Icon(
                                      Icons.key,
                                      color: colorScheme.onTertiaryContainer,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          k.name,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: colorScheme
                                                    .secondaryContainer,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                k.algorithm,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: colorScheme
                                                      .onSecondaryContainer,
                                                ),
                                              ),
                                            ),
                                            if (k.isEncrypted) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: colorScheme
                                                      .surfaceContainerHighest,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  '密码加密',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Quick copy public key
                                  IconButton.filledTonal(
                                    icon: const Icon(Icons.copy, size: 18),
                                    tooltip: '复制公钥',
                                    onPressed: () =>
                                        _copyPublicKey(context, k),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Fingerprint
                              Text(
                                k.fingerprintSha256,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
          floatingActionButton: keys.isEmpty
              ? null
              : FloatingActionButton.extended(
                  heroTag: 'fab_generate',
                  onPressed: () => _openGenerateDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('生成密钥'),
                ),
        );
      },
    );
  }
}
