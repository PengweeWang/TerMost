import 'package:flutter/material.dart';
import '../models/port_forward_rule.dart';
import '../services/storage_service.dart';
import '../services/tunnel_service.dart';
import '../widgets/tunnel_form_dialog.dart';

class TunnelsView extends StatefulWidget {
  const TunnelsView({super.key});

  @override
  State<TunnelsView> createState() => _TunnelsViewState();
}

class _TunnelsViewState extends State<TunnelsView> {
  void _openAddTunnelDialog() async {
    final newRule = await showDialog<PortForwardRule>(
      context: context,
      builder: (_) => const TunnelFormDialog(),
    );

    if (newRule != null) {
      await StorageService().saveRule(newRule);
    }
  }

  void _openEditTunnelDialog(PortForwardRule rule) async {
    if (rule.isRunning) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先停止该隧道再进行编辑')),
      );
      return;
    }

    final updated = await showDialog<PortForwardRule>(
      context: context,
      builder: (_) => TunnelFormDialog(rule: rule),
    );

    if (updated != null) {
      await StorageService().saveRule(updated);
    }
  }

  Future<void> _toggleTunnel(PortForwardRule rule, bool enable) async {
    final tunnelService = TunnelService();
    try {
      if (enable) {
        await tunnelService.startTunnel(rule);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('隧道 "${rule.name}" 已启动'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        await tunnelService.stopTunnel(rule);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('隧道 "${rule.name}" 已停止'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteTunnel(PortForwardRule rule) async {
    if (rule.isRunning) {
      await TunnelService().stopTunnel(rule);
    }
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除端口转发规则'),
        content: Text('确定要删除规则 "${rule.name}" 吗？'),
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
      await StorageService().deleteRule(rule.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final storage = StorageService();
    final tunnelService = TunnelService();

    return ListenableBuilder(
      listenable: Listenable.merge([storage, tunnelService]),
      builder: (context, _) {
        final rules = storage.rules;

        return Scaffold(
          appBar: AppBar(
            title: const Text('端口转发'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: '新建端口转发',
                onPressed: _openAddTunnelDialog,
              ),
            ],
          ),
          body: rules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.swap_calls_outlined,
                        size: 72,
                        color: colorScheme.outlineVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '尚未配置任何端口转发规则',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '支持本地端口转发 (-L)、SOCKS5 动态代理 (-D) 及远程穿透 (-R)',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('添加端口转发规则'),
                        onPressed: _openAddTunnelDialog,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: rules.length,
                  itemBuilder: (context, index) {
                    final rule = rules[index];
                    final isRunning = tunnelService.isTunnelRunning(rule.id);
                    final host = storage.getHostById(rule.hostId);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row: Type badge, Name, Switch, Menu
                            Row(
                              children: [
                                _buildTypeBadge(rule.forwardType, colorScheme),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    rule.name,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: isRunning,
                                  onChanged: (val) =>
                                      _toggleTunnel(rule, val),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (val) {
                                    if (val == 'edit') {
                                      _openEditTunnelDialog(rule);
                                    } else if (val == 'delete') {
                                      _deleteTunnel(rule);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 18),
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
                                                  color: colorScheme.error)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Routing representation
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    rule.forwardType == 'dynamic'
                                        ? Icons.hub
                                        : Icons.alt_route,
                                    size: 18,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _formatRouting(rule),
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Bound SSH server info & live stats
                            Row(
                              children: [
                                Icon(Icons.dns,
                                    size: 14, color: colorScheme.outline),
                                const SizedBox(width: 4),
                                Text(
                                  host != null
                                      ? '${host.name} (${host.host}:${host.port})'
                                      : '未指定主机',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const Spacer(),
                                if (isRunning) ...[
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF22C55E),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '↑ ${TunnelService.formatBytes(rule.bytesUp)}  ↓ ${TunnelService.formatBytes(rule.bytesDown)}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontFamily: 'monospace',
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ] else ...[
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: colorScheme.outlineVariant,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '未启动',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.outline,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openAddTunnelDialog,
            icon: const Icon(Icons.add),
            label: const Text('新建转发'),
          ),
        );
      },
    );
  }

  Widget _buildTypeBadge(String type, ColorScheme colorScheme) {
    String label;
    Color bg;
    Color fg;

    switch (type.toLowerCase()) {
      case 'dynamic':
        label = 'SOCKS5 -D';
        bg = colorScheme.tertiaryContainer;
        fg = colorScheme.onTertiaryContainer;
        break;
      case 'remote':
        label = '远程 -R';
        bg = colorScheme.errorContainer.withOpacity(0.7);
        fg = colorScheme.onErrorContainer;
        break;
      case 'local':
      default:
        label = '本地 -L';
        bg = colorScheme.primaryContainer;
        fg = colorScheme.onPrimaryContainer;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  String _formatRouting(PortForwardRule r) {
    if (r.forwardType == 'dynamic') {
      return '${r.localHost}:${r.localPort} (SOCKS5 代理)';
    } else if (r.forwardType == 'remote') {
      return '远程 :${r.remotePort} ──> 本地 ${r.localHost}:${r.localPort}';
    } else {
      return '本地 :${r.localPort} ──> 远程 ${r.remoteHost}:${r.remotePort}';
    }
  }
}
