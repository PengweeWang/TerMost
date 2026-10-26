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

  Future<void> _confirmAndDisconnect(
    BuildContext context,
    SshTerminalSession session,
  ) async {
    final theme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.power_settings_new,
          color: Colors.amber,
          size: 40,
        ),
        title: const Text('断开连接确认'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '确定要断开与主机 "${session.host.name}" 的 SSH 连接吗？',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '主机地址: ${session.host.username}@${session.host.host}:${session.host.port}',
              style: TextStyle(
                fontSize: 12.5,
                color: theme.colorScheme.outline,
                fontFamily: 'JetBrainsMonoNerdFont',
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '断开后终端屏幕和历史输出将完整保留，您可随时在控制台中点击“重新连接”。',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认断开'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SshService().disconnect(session.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已断开与 "${session.host.name}" 的连接，终端历史已保留'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmAndCloseSession(
    BuildContext context,
    SshTerminalSession session,
  ) async {
    final theme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.delete_outline,
          color: Colors.redAccent,
          size: 40,
        ),
        title: const Text('关闭会话确认'),
        content: Text(
          '确定要完全关闭并移除 "${session.host.name}" 的终端会话吗？未保存的屏幕历史将被清除。',
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('关闭并移除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SshService().closeAndRemoveSession(session.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已关闭 "${session.host.name}" 会话'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openTopConsoleDialog(
    BuildContext context,
    SshTerminalSession activeSession,
    List<SshTerminalSession> sessions,
    SshService ssh,
    StorageService storage,
  ) {
    HapticFeedback.lightImpact();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'ConsoleDialog',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      transitionBuilder: (dialogCtx, anim, secondaryAnim, child) {
        final slideAnim = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(slideAnim),
          child: FadeTransition(
            opacity: anim,
            child: child,
          ),
        );
      },
      pageBuilder: (dialogCtx, anim1, anim2) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final topPadding = MediaQuery.of(dialogCtx).padding.top;

            return Align(
              alignment: Alignment.topCenter,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(
                    top: topPadding + 10,
                    left: 12,
                    right: 12,
                    bottom: 24,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF334155),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.55),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header: Active host info & Close dialog
                        Row(
                          children: [
                            _buildStatusDot(activeSession.status),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          activeSession.host.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildStatusBadge(activeSession.status),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${activeSession.host.username}@${activeSession.host.host}:${activeSession.host.port}',
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 12,
                                      fontFamily: 'JetBrainsMonoNerdFont',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white70),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              onPressed: () => Navigator.of(dialogCtx).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Sessions Tab Switcher
                        const Text(
                          '终端会话切换',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ...sessions.map((s) {
                                final isSel = s.id == activeSession.id;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: ChoiceChip(
                                    selected: isSel,
                                    avatar: _buildStatusDot(s.status),
                                    label: Text(
                                      s.host.name,
                                      style: TextStyle(
                                        fontWeight: isSel
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    onSelected: (_) {
                                      ssh.setActiveSession(s.id);
                                      Navigator.of(dialogCtx).pop();
                                    },
                                  ),
                                );
                              }),
                              // Add New Connection
                              ActionChip(
                                avatar: const Icon(Icons.add, size: 16),
                                label: const Text('新连接'),
                                onPressed: () {
                                  Navigator.of(dialogCtx).pop();
                                  widget.onNavigateToTab(0);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Quick Actions
                        const Text(
                          '快捷工具',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // Paste Button
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Color(0xFF334155)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.paste, size: 17),
                                label: const Text('粘贴'),
                                onPressed: () {
                                  Navigator.of(dialogCtx).pop();
                                  _pasteToTerminal(activeSession);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Clear Screen (Ctrl+L)
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Color(0xFF334155)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.cleaning_services_outlined, size: 17),
                                label: const Text('清屏'),
                                onPressed: () {
                                  Navigator.of(dialogCtx).pop();
                                  ssh.sendData(activeSession.id, [12]); // FF / Ctrl+L
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Font Size Controller Row
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.format_size, size: 18, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 10),
                              const Text(
                                '终端字号',
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              const Spacer(),
                              IconButton.filledTonal(
                                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.remove, size: 16),
                                onPressed: () {
                                  storage.setFontSize(storage.fontSize - 1.0);
                                  setDialogState(() {});
                                },
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  '${storage.fontSize.toStringAsFixed(0)} pt',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              IconButton.filledTonal(
                                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.add, size: 16),
                                onPressed: () {
                                  storage.setFontSize(storage.fontSize + 1.0);
                                  setDialogState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Session State-specific Action Buttons
                        _buildSessionActionButtons(
                          context,
                          dialogCtx,
                          activeSession,
                          ssh,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSessionActionButtons(
    BuildContext context,
    BuildContext dialogCtx,
    SshTerminalSession session,
    SshService ssh,
  ) {
    switch (session.status) {
      case SshSessionStatus.connected:
        return FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444).withOpacity(0.18),
            foregroundColor: const Color(0xFFFCA5A5),
            side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
            padding: const EdgeInsets.symmetric(vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.power_settings_new, color: Color(0xFFEF4444), size: 18),
          label: const Text(
            '断开当前网络连接',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: () async {
            Navigator.of(dialogCtx).pop();
            await _confirmAndDisconnect(context, session);
          },
        );

      case SshSessionStatus.disconnected:
      case SshSessionStatus.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFFF87171)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      session.status == SshSessionStatus.error
                          ? (session.errorMessage ?? '连接发生异常中断')
                          : '当前网络连接已断开，屏幕历史已保留',
                      style: const TextStyle(
                        color: Color(0xFFFCA5A5),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text(
                      '重新连接',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.of(dialogCtx).pop();
                      ssh.reconnect(session.id);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF87171),
                      side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('关闭会话'),
                    onPressed: () async {
                      Navigator.of(dialogCtx).pop();
                      await _confirmAndCloseSession(context, session);
                    },
                  ),
                ),
              ],
            ),
          ],
        );

      case SshSessionStatus.connecting:
        return Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFEAB308),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '正在连接中...',
                style: TextStyle(color: Color(0xFFFDE047), fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                ssh.closeAndRemoveSession(session.id);
              },
              child: const Text('取消连接', style: TextStyle(color: Color(0xFFF87171))),
            ),
          ],
        );
    }
  }

  Widget _buildStatusBadge(SshSessionStatus status) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case SshSessionStatus.connected:
        bg = const Color(0xFF22C55E).withOpacity(0.18);
        fg = const Color(0xFF4ADE80);
        label = '已连接';
        break;
      case SshSessionStatus.connecting:
        bg = const Color(0xFFEAB308).withOpacity(0.18);
        fg = const Color(0xFFFDE047);
        label = '连接中';
        break;
      case SshSessionStatus.disconnected:
        bg = const Color(0xFFEF4444).withOpacity(0.18);
        fg = const Color(0xFFFCA5A5);
        label = '已断开';
        break;
      case SshSessionStatus.error:
        bg = const Color(0xFFEF4444).withOpacity(0.18);
        fg = const Color(0xFFFCA5A5);
        label = '异常';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
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

        // 沉浸式终端界面：不占用顶栏空间，由键盘辅助栏左侧的“控制台”按钮从屏幕顶部滑下呼出
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_focusNode.hasFocus) {
              _focusNode.unfocus();
            } else {
              widget.onNavigateToTab(0);
            }
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: SafeArea(
              child: Column(
                children: [
                  // Terminal View (铺满上方空间)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (!_focusNode.hasFocus) {
                          _focusNode.requestFocus();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: TerminalView(
                          activeSession.terminal,
                          focusNode: _focusNode,
                          theme: AppTheme.terminalDarkTheme,
                          textStyle: TerminalStyle(
                            fontSize: storage.fontSize,
                            fontFamily: 'JetBrainsMonoNerdFont',
                          ),
                          autofocus: true,
                          keyboardType: TextInputType.text,
                          onKeyEvent: (focusNode, event) {
                            if (event is KeyDownEvent) {
                              if (event.logicalKey == LogicalKeyboardKey.enter ||
                                  event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                                activeSession.terminal.keyInput(TerminalKey.enter);
                                return KeyEventResult.handled;
                              }
                            }
                            return KeyEventResult.ignored;
                          },
                        ),
                      ),
                    ),
                  ),
                  // Mobile Accessory Keyboard Bar (集成控制台呼出与状态指示)
                  VirtualKeyboardBar(
                    sessionCount: sessions.length,
                    sessionStatus: activeSession.status,
                    onOpenConsole: () => _openTopConsoleDialog(
                      context,
                      activeSession,
                      sessions,
                      ssh,
                      storage,
                    ),
                    onSendBytes: (bytes) {
                      ssh.sendData(activeSession.id, bytes);
                    },
                    onSendString: (str) {
                      ssh.sendText(activeSession.id, str);
                    },
                    onDismissKeyboard: () {
                      _focusNode.unfocus();
                      FocusScope.of(context).unfocus();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
