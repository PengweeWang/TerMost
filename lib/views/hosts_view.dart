import 'package:flutter/material.dart';
import '../models/ssh_host.dart';
import '../services/storage_service.dart';
import '../services/ssh_service.dart';
import '../widgets/host_form_dialog.dart';

class HostsView extends StatefulWidget {
  final Function(int tabIndex) onNavigateToTab;

  const HostsView({super.key, required this.onNavigateToTab});

  @override
  State<HostsView> createState() => _HostsViewState();
}

class _HostsViewState extends State<HostsView> {
  final _searchController = TextEditingController();
  String _filterQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddHostDialog() async {
    final newHost = await showDialog<SshHost>(
      context: context,
      builder: (_) => const HostFormDialog(),
    );

    if (newHost != null) {
      await StorageService().saveHost(newHost);
    }
  }

  void _openEditHostDialog(SshHost host) async {
    final updated = await showDialog<SshHost>(
      context: context,
      builder: (_) => HostFormDialog(host: host),
    );

    if (updated != null) {
      await StorageService().saveHost(updated);
    }
  }

  Future<void> _connectHost(SshHost host) async {
    await SshService().connect(host);
    // Switch to Terminal Tab (index 1)
    widget.onNavigateToTab(1);
  }

  Future<void> _deleteHost(SshHost host) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除主机'),
        content: Text('确定要删除主机 "${host.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StorageService().deleteHost(host.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final storage = StorageService();

    return ListenableBuilder(
      listenable: storage,
      builder: (context, _) {
        final hosts = storage.hosts.where((h) {
          if (_filterQuery.isEmpty) return true;
          final q = _filterQuery.toLowerCase();
          return h.name.toLowerCase().contains(q) ||
              h.host.toLowerCase().contains(q) ||
              h.username.toLowerCase().contains(q);
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Row(
              children: [
                Icon(Icons.terminal, size: 28),
                SizedBox(width: 10),
                Text(
                  'TerMost',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: '添加主机',
                onPressed: _openAddHostDialog,
              ),
            ],
          ),
          body: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SearchBar(
                  controller: _searchController,
                  hintText: '搜索主机名称、IP 或用户名...',
                  leading: const Icon(Icons.search),
                  trailing: _searchController.text.isNotEmpty
                      ? [
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _filterQuery = '');
                            },
                          ),
                        ]
                      : null,
                  onChanged: (val) {
                    setState(() => _filterQuery = val.trim());
                  },
                ),
              ),
              // Hosts List
              Expanded(
                child: hosts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.dns_outlined,
                              size: 72,
                              color: colorScheme.outlineVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              storage.hosts.isEmpty
                                  ? '尚未添加任何 SSH 主机'
                                  : '未找到匹配的主机',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (storage.hosts.isEmpty)
                              FilledButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('添加第一个 SSH 主机'),
                                onPressed: _openAddHostDialog,
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        itemCount: hosts.length,
                        itemBuilder: (context, index) {
                          final host = hosts[index];
                          final key = host.keyId != null
                              ? storage.getKeyById(host.keyId!)
                              : null;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _connectHost(host),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    // Leading Icon
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor:
                                          colorScheme.primaryContainer,
                                      child: Icon(
                                        Icons.computer,
                                        color: colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    // Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            host.name,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${host.username}@${host.host}:${host.port}',
                                            style: TextStyle(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                              fontSize: 13,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              // Auth badge
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: host.authType == 'key'
                                                      ? colorScheme
                                                          .tertiaryContainer
                                                      : colorScheme
                                                          .surfaceContainerHighest,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      host.authType == 'key'
                                                          ? Icons.key
                                                          : Icons.password,
                                                      size: 12,
                                                      color: host.authType ==
                                                              'key'
                                                          ? colorScheme
                                                              .onTertiaryContainer
                                                          : colorScheme
                                                              .onSurfaceVariant,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      host.authType == 'key'
                                                          ? '密钥 [${key?.algorithm ?? "未选"}]'
                                                          : '密码认证',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: host.authType ==
                                                                'key'
                                                            ? colorScheme
                                                                .onTertiaryContainer
                                                            : colorScheme
                                                                .onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (host.lastConnected !=
                                                  null) ...[
                                                const SizedBox(width: 8),
                                                Text(
                                                  '上次连接: ${_formatDate(host.lastConnected!)}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: colorScheme.outline,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Connect & More Actions
                                    IconButton.filledTonal(
                                      icon: const Icon(Icons.play_arrow),
                                      tooltip: '连接',
                                      onPressed: () => _connectHost(host),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert),
                                      onSelected: (val) {
                                        if (val == 'edit') {
                                          _openEditHostDialog(host);
                                        } else if (val == 'delete') {
                                          _deleteHost(host);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit_outlined,
                                                  size: 18),
                                              SizedBox(width: 8),
                                              Text('编辑'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_outline,
                                                  color: colorScheme.error,
                                                  size: 18),
                                              const SizedBox(width: 8),
                                              Text('删除',
                                                  style: TextStyle(
                                                      color:
                                                          colorScheme.error)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openAddHostDialog,
            icon: const Icon(Icons.add),
            label: const Text('添加主机'),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${dt.month}月${dt.day}日';
  }
}
