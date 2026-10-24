import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import '../services/ssh_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/virtual_keyboard_bar.dart';

class TerminalScreenView extends StatefulWidget {
  final Function(int tabIndex) onNavigateToTab;

  const TerminalScreenView({super.key, required this.onNavigateToTab});

  @override
  State<TerminalScreenView> createState() => _TerminalScreenViewState();
}

class _TerminalScreenViewState extends State<TerminalScreenView> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _pasteToTerminal(SshTerminalSession session) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      SshService().sendText(session.id, data.text!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ssh = SshService();
    final storage = StorageService();

    return ListenableBuilder(
      listenable: Listenable.merge([ssh, storage]),
      builder: (context, _) {
        final sessions = ssh.sessions;
        final activeSession = ssh.activeSession;

        if (sessions.isEmpty || activeSession == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('终端'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.terminal,
                    size: 80,
                    color: colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '当前没有活动的 SSH 终端会话',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.dns),
                    label: const Text('前往主机列表连接'),
                    onPressed: () => widget.onNavigateToTab(0),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E293B),
            titleSpacing: 0,
            title: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  // Tabs for all open sessions
                  ...sessions.map((s) {
                    final isSelected = s.id == activeSession.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ChoiceChip(
                        selected: isSelected,
                        avatar: _buildStatusDot(s.status),
                        label: Text(
                          s.host.name,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        onSelected: (_) {
                          ssh.setActiveSession(s.id);
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              // Paste button
              IconButton(
                icon: const Icon(Icons.paste, size: 20),
                tooltip: '粘贴至终端',
                onPressed: () => _pasteToTerminal(activeSession),
              ),
              // Font size adjuster
              IconButton(
                icon: const Icon(Icons.text_decrease, size: 18),
                tooltip: '减小字号',
                onPressed: () {
                  storage.setFontSize(storage.fontSize - 1.0);
                },
              ),
              IconButton(
                icon: const Icon(Icons.text_increase, size: 18),
                tooltip: '增大字号',
                onPressed: () {
                  storage.setFontSize(storage.fontSize + 1.0);
                },
              ),
              // Disconnect session
              IconButton(
                icon: const Icon(Icons.close, color: Colors.redAccent),
                tooltip: '关闭当前会话',
                onPressed: () => ssh.closeAndRemoveSession(activeSession.id),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Session Info Sub-banner
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  color: const Color(0xFF141E33),
                  child: Row(
                    children: [
                      Text(
                        '${activeSession.host.username}@${activeSession.host.host}:${activeSession.host.port}',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const Spacer(),
                      Text(
                        activeSession.status == SshSessionStatus.connected
                            ? '已连接'
                            : activeSession.status == SshSessionStatus.connecting
                                ? '连接中...'
                                : '已断开',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: activeSession.status ==
                                  SshSessionStatus.connected
                              ? const Color(0xFF22C55E)
                              : activeSession.status ==
                                      SshSessionStatus.connecting
                                  ? const Color(0xFFEAB308)
                                  : const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ),
                // Terminal View
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: TerminalView(
                      activeSession.terminal,
                      theme: AppTheme.terminalDarkTheme,
                      textStyle: TerminalStyle(
                        fontSize: storage.fontSize,
                        fontFamily: 'monospace',
                      ),
                      autofocus: true,
                    ),
                  ),
                ),
                // Mobile Accessory Keyboard Bar
                VirtualKeyboardBar(
                  onSendBytes: (bytes) {
                    ssh.sendData(activeSession.id, bytes);
                  },
                  onSendString: (str) {
                    ssh.sendText(activeSession.id, str);
                  },
                  onDismissKeyboard: () {
                    FocusScope.of(context).unfocus();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusDot(SshSessionStatus status) {
    Color color;
    switch (status) {
      case SshSessionStatus.connected:
        color = const Color(0xFF22C55E);
        break;
      case SshSessionStatus.connecting:
        color = const Color(0xFFEAB308);
        break;
      case SshSessionStatus.disconnected:
      case SshSessionStatus.error:
        color = const Color(0xFFEF4444);
        break;
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
