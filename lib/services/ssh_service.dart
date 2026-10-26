import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';
import '../models/ssh_host.dart';
import '../src/rust/api/simple.dart' as rust_api;
import '../src/rust/session.dart';
import 'keepalive_service.dart';
import 'storage_service.dart';
import 'tunnel_service.dart';

enum SshSessionStatus { connecting, connected, disconnected, error }

class SshTerminalSession {
  final String id;
  final SshHost host;
  final Terminal terminal;
  SshSessionStatus status;
  String? errorMessage;
  StreamSubscription<SessionEvent>? subscription;

  SshTerminalSession({
    required this.id,
    required this.host,
    required this.terminal,
    this.status = SshSessionStatus.connecting,
    this.errorMessage,
  });
}

class SshService extends ChangeNotifier {
  static final SshService _instance = SshService._internal();
  factory SshService() => _instance;
  SshService._internal();

  final Map<String, SshTerminalSession> _sessions = {};
  String? _activeSessionId;

  List<SshTerminalSession> get sessions => _sessions.values.toList();
  String? get activeSessionId => _activeSessionId;
  SshTerminalSession? get activeSession =>
      _activeSessionId != null ? _sessions[_activeSessionId] : null;

  int get activeCount => _sessions.values.where((s) =>
      s.status == SshSessionStatus.connected ||
      s.status == SshSessionStatus.connecting).length;

  void setActiveSession(String? sessionId) {
    _activeSessionId = sessionId;
    notifyListeners();
  }

  void _syncKeepAlive() {
    final activeSessions = activeCount;
    final activeTunnels = TunnelService().activeCount;
    KeepAliveService().syncState(
      activeSessionsCount: activeSessions,
      activeTunnelsCount: activeTunnels,
    );
  }

  Future<String> connect(SshHost host) async {
    final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}_${host.id}';
    final terminal = Terminal(maxLines: 5000);

    final session = SshTerminalSession(
      id: sessionId,
      host: host,
      terminal: terminal,
      status: SshSessionStatus.connecting,
    );

    _sessions[sessionId] = session;
    _activeSessionId = sessionId;
    notifyListeners();
    _syncKeepAlive();

    terminal.write('\x1b[1;36m[TerMost]\x1b[0m 正在连接到 ${host.username}@${host.host}:${host.port}...\r\n');

    await _startSessionInternal(session);
    return sessionId;
  }

  Future<void> reconnect(String sessionId) async {
    final session = _sessions[sessionId];
    if (session == null) return;

    // 清理旧的订阅与底层连接
    try {
      await session.subscription?.cancel();
    } catch (_) {}
    try {
      await rust_api.closeSessionById(sessionId: session.id);
    } catch (_) {}

    session.status = SshSessionStatus.connecting;
    session.errorMessage = null;
    notifyListeners();
    _syncKeepAlive();

    session.terminal.write('\r\n\x1b[1;36m[TerMost]\x1b[0m 正在重新连接到 ${session.host.username}@${session.host.host}:${session.host.port}...\r\n');

    await _startSessionInternal(session);
  }

  Future<void> _startSessionInternal(SshTerminalSession session) async {
    final sessionId = session.id;
    final host = session.host;
    final terminal = session.terminal;

    // 终端用户键盘输入监听
    terminal.onOutput = (String text) {
      if (session.status == SshSessionStatus.connected) {
        // 部分 Android 软键盘按回车时可能发送 \n，在 SSH 交互终端下统一规整为 \r 触发行命令提交
        final normalized = (text == '\n') ? '\r' : text;
        rust_api.writeSessionStdin(
          sessionId: sessionId,
          data: utf8.encode(normalized),
        ).catchError((_) {});
      }
    };

    // 终端窗口尺寸变更监听
    terminal.onResize = (int width, int height, int pixelWidth, int pixelHeight) {
      if (session.status == SshSessionStatus.connected) {
        rust_api.resizeSessionPty(
          sessionId: sessionId,
          cols: width,
          rows: height,
        ).catchError((_) {});
      }
    };

    // 解析私钥凭证
    String? privKeyStr;
    if (host.authType == 'key' && host.keyId != null) {
      final keyEntry = StorageService().getKeyById(host.keyId!);
      if (keyEntry != null) {
        privKeyStr = keyEntry.privateKeyOpenSsh;
      }
    }

    final cols = terminal.viewWidth > 0 ? terminal.viewWidth : 80;
    final rows = terminal.viewHeight > 0 ? terminal.viewHeight : 24;

    final config = SshConnectConfig(
      host: host.host,
      port: host.port,
      username: host.username,
      authType: host.authType,
      password: host.password,
      privateKey: privKeyStr,
      passphrase: host.passphrase,
      cols: cols,
      rows: rows,
    );

    try {
      final stream = rust_api.startSession(
        sessionId: sessionId,
        config: config,
      );

      session.subscription = stream.listen(
        (event) {
          switch (event.eventType) {
            case 'connected':
              session.status = SshSessionStatus.connected;
              session.errorMessage = null;
              terminal.write('\x1b[1;32m[TerMost]\x1b[0m ${event.message ?? "连接成功"}\r\n\r\n');
              notifyListeners();
              _syncKeepAlive();
              // 主动向远程 PTY 同步当前终端真实行列数，确保服务端 zsh 获取精确宽度，避免行末 % EOL 标记
              if (terminal.viewWidth > 0 && terminal.viewHeight > 0) {
                rust_api.resizeSessionPty(
                  sessionId: sessionId,
                  cols: terminal.viewWidth,
                  rows: terminal.viewHeight,
                );
              }
              break;
            case 'data':
              terminal.write(utf8.decode(event.data, allowMalformed: true));
              break;
            case 'error':
              session.status = SshSessionStatus.error;
              session.errorMessage = event.message;
              terminal.write('\r\n\x1b[1;31m[TerMost 错误]\x1b[0m ${event.message}\r\n');
              notifyListeners();
              _syncKeepAlive();
              break;
            case 'closed':
              session.status = SshSessionStatus.disconnected;
              terminal.write('\r\n\x1b[1;33m[TerMost]\x1b[0m 会话已断开。\r\n');
              notifyListeners();
              _syncKeepAlive();
              break;
          }
        },
        onError: (err) {
          session.status = SshSessionStatus.error;
          session.errorMessage = err.toString();
          terminal.write('\r\n\x1b[1;31m[TerMost 连接失败]\x1b[0m $err\r\n');
          notifyListeners();
          _syncKeepAlive();
        },
        onDone: () {
          if (session.status != SshSessionStatus.error) {
            session.status = SshSessionStatus.disconnected;
          }
          notifyListeners();
          _syncKeepAlive();
        },
      );

      // 更新最后连接时间
      host.lastConnected = DateTime.now();
      StorageService().saveHost(host);
    } catch (e) {
      session.status = SshSessionStatus.error;
      session.errorMessage = e.toString();
      terminal.write('\r\n\x1b[1;31m[TerMost 异常]\x1b[0m $e\r\n');
      notifyListeners();
      _syncKeepAlive();
    }
  }

  Future<void> sendData(String sessionId, List<int> data) async {
    final session = _sessions[sessionId];
    if (session != null && session.status == SshSessionStatus.connected) {
      await rust_api.writeSessionStdin(
        sessionId: sessionId,
        data: data,
      );
    }
  }

  Future<void> sendText(String sessionId, String text) async {
    await sendData(sessionId, utf8.encode(text));
  }

  Future<void> disconnect(String sessionId) async {
    final session = _sessions[sessionId];
    if (session != null) {
      await session.subscription?.cancel();
      try {
        await rust_api.closeSessionById(sessionId: sessionId);
      } catch (_) {}
      session.status = SshSessionStatus.disconnected;
      session.terminal.write('\r\n\x1b[1;33m[TerMost]\x1b[0m 用户主动断开连接。\r\n');
      notifyListeners();
      _syncKeepAlive();
    }
  }

  Future<void> closeAndRemoveSession(String sessionId) async {
    // 立即从会话映射中移除，并重置活跃会话状态，第一时间通知 UI 重新渲染以消除界面滞后
    final session = _sessions.remove(sessionId);
    if (_activeSessionId == sessionId) {
      _activeSessionId = _sessions.keys.isNotEmpty ? _sessions.keys.last : null;
    }
    notifyListeners();
    _syncKeepAlive();

    // 异步清理底层网络连接与流监听
    if (session != null) {
      try {
        await session.subscription?.cancel();
      } catch (_) {}
      try {
        await rust_api.closeSessionById(sessionId: sessionId);
      } catch (_) {}
      session.status = SshSessionStatus.disconnected;
    }
  }
}
