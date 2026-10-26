import 'package:flutter/material.dart';
import '../models/port_forward_rule.dart';
import '../services/storage_service.dart';

class TunnelFormDialog extends StatefulWidget {
  final PortForwardRule? rule;

  const TunnelFormDialog({super.key, this.rule});

  @override
  State<TunnelFormDialog> createState() => _TunnelFormDialogState();
}

class _TunnelFormDialogState extends State<TunnelFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _localHostController;
  late TextEditingController _localPortController;
  late TextEditingController _remoteHostController;
  late TextEditingController _remotePortController;

  String _forwardType = 'local';
  String? _selectedHostId;

  @override
  void initState() {
    super.initState();
    final r = widget.rule;
    _nameController = TextEditingController(text: r?.name ?? '');
    _localHostController =
        TextEditingController(text: r?.localHost ?? '127.0.0.1');
    _localPortController =
        TextEditingController(text: (r?.localPort ?? 8080).toString());
    _remoteHostController =
        TextEditingController(text: r?.remoteHost ?? '127.0.0.1');
    _remotePortController =
        TextEditingController(text: (r?.remotePort ?? 80).toString());
    _forwardType = r?.forwardType ?? 'local';
    _selectedHostId = r?.hostId;

    final hosts = StorageService().hosts;
    if (_selectedHostId == null && hosts.isNotEmpty) {
      _selectedHostId = hosts.first.id;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _localHostController.dispose();
    _localPortController.dispose();
    _remoteHostController.dispose();
    _remotePortController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedHostId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择要绑定的 SSH 主机')),
      );
      return;
    }

    final localPort = int.tryParse(_localPortController.text.trim()) ?? 8080;
    final remotePort = int.tryParse(_remotePortController.text.trim()) ?? 80;

    String defaultName = '';
    if (_forwardType == 'local') {
      defaultName = '本地转发 L$localPort -> ${_remoteHostController.text}:$remotePort';
    } else if (_forwardType == 'remote') {
      defaultName = '远程转发 R$remotePort -> ${_localHostController.text}:$localPort';
    } else {
      defaultName = 'SOCKS5 动态代理 :$localPort';
    }

    final name = _nameController.text.trim().isEmpty
        ? defaultName
        : _nameController.text.trim();

    final rule = PortForwardRule(
      id: widget.rule?.id ?? 'rule_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      forwardType: _forwardType,
      hostId: _selectedHostId!,
      localHost: _localHostController.text.trim(),
      localPort: localPort,
      remoteHost: _remoteHostController.text.trim(),
      remotePort: remotePort,
      isEnabled: widget.rule?.isEnabled ?? false,
    );

    Navigator.of(context).pop(rule);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hosts = StorageService().hosts;

    return AlertDialog(
      title: Text(widget.rule == null ? '新建端口转发' : '编辑端口转发'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Forward Type Vertical Selection Cards
                _buildTypeOption(
                  type: 'local',
                  title: '本地端口转发',
                  tag: '-L',
                  desc: '将远程内网服务（如数据库/Web）映射到本机端口访问',
                  colorScheme: colorScheme,
                ),
                _buildTypeOption(
                  type: 'dynamic',
                  title: 'SOCKS5 动态代理',
                  tag: '-D',
                  desc: '在手机本地开启 SOCKS5 代理，流量通过 SSH 中继',
                  colorScheme: colorScheme,
                ),
                _buildTypeOption(
                  type: 'remote',
                  title: '远程反向转发',
                  tag: '-R',
                  desc: '将手机或局域网服务穿透反向暴露到远程服务器端口',
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: 12),
                // Rule Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '规则备注名称 (可选)',
                    hintText: '如: 访问远程 MySQL',
                    prefixIcon: Icon(Icons.bookmark_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                // SSH Server Picker
                if (hosts.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '请先在主机列表中添加至少一个 SSH 主机以建立隧道',
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),
                ] else ...[
                  DropdownButtonFormField<String>(
                    value: _selectedHostId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '关联 SSH 服务器 *',
                      prefixIcon: Icon(Icons.dns_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: hosts.map((h) {
                      return DropdownMenuItem(
                        value: h.id,
                        child: Text(
                          '${h.name} (${h.username}@${h.host}:${h.port})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedHostId = val);
                    },
                    validator: (v) => v == null ? '请选择绑定的 SSH 服务器' : null,
                  ),
                ],
                const SizedBox(height: 16),
                // Ports Config
                if (_forwardType == 'dynamic') ...[
                  // Dynamic SOCKS5 only needs local port
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _localHostController,
                          decoration: const InputDecoration(
                            labelText: '本地监听地址',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: _localPortController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'SOCKS5 端口 *',
                            hintText: '1080',
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
                ] else ...[
                  // Local or Remote
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _localPortController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: _forwardType == 'local'
                                ? '本地监听端口 *'
                                : '本地目标端口 *',
                            hintText: '8080',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final p = int.tryParse(v ?? '');
                            if (p == null || p <= 0 || p > 65535) return '错误';
                            return null;
                          },
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Icon(Icons.arrow_forward),
                      ),
                      Expanded(
                        child: TextFormField(
                          controller: _remotePortController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: _forwardType == 'local'
                                ? '目标服务端口 *'
                                : '远程监听端口 *',
                            hintText: '80',
                            border: const OutlineInputBorder(),
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
                  TextFormField(
                    controller: _remoteHostController,
                    decoration: InputDecoration(
                      labelText: _forwardType == 'local'
                          ? '目标主机地址 (从 SSH 服务器视角) *'
                          : '本地转发地址 (一般为 127.0.0.1) *',
                      hintText: '127.0.0.1 或内网 IP',
                      prefixIcon: const Icon(Icons.computer),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? '请输入地址' : null,
                  ),
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
          child: const Text('保存规则'),
        ),
      ],
    );
  }

  Widget _buildTypeOption({
    required String type,
    required String title,
    required String tag,
    required String desc,
    required ColorScheme colorScheme,
  }) {
    final isSelected = _forwardType == type;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () => setState(() => _forwardType = type),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer.withOpacity(0.4)
                : colorScheme.surfaceContainerHighest.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isSelected ? colorScheme.primary : colorScheme.outlineVariant,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected ? colorScheme.primary : colorScheme.outline,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: isSelected
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? colorScheme.onPrimary
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? colorScheme.onPrimaryContainer.withOpacity(0.8)
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
