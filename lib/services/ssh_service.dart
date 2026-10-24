import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';
import '../models/ssh_host.dart';
import '../src/rust/api/simple.dart' as rust_api;
import '../src/rust/session.dart';
import 'storage_service.dart';

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

  void setActiveSession(String? sessionId) {
    _activeSessionId = sessionId;
    notifyListeners();
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

    terminal.write('\x1b[1;36m[TerMost]\x1b[0m 正在连接到 ${host.username}@${host.host}:${host.port}...\r\n');

    // Terminal user input listener
    terminal.onOutput = (String text) {
      if (session.status == SshSessionStatus.connected) {
        rust_api.writeSessionStdin(
          sessionId: sessionId,
          data: utf8.encode(text),
        );
      }
    };

    // Terminal resize listener
    terminal.onResize = (int width, int height, int pixelWidth, int pixelHeight) {
      if (session.status == SshSessionStatus.connected) {
        rust_api.resizeSessionPty(
          sessionId: sessionId,
          cols: width,
          rows: height,
        );
      }
    };

    // Resolve private key if key-based auth
    String? privKeyStr;
    if (host.authType == 'key' && host.keyId != null) {
      final keyEntry = StorageService().getKeyById(host.keyId!);
      if (keyEntry != null) {
        privKeyStr = keyEntry.privateKeyOpenSsh;
      }
    }

    final config = SshConnectConfig(
      host: host.host,
      port: host.port,
      username: host.username,
      authType: host.authType,
      password: host.password,
      privateKey: privKeyStr,
      passphrase: host.passphrase,
      cols: 80,
      rows: 24,
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
              terminal.write('\x1b[1;32m[TerMost]\x1b[0m ${event.message ?? "连接成功"}\r\n\r\n');
              notifyListeners();
              break;
            case 'data':
              terminal.write(utf8.decode(event.data, allowMalformed: true));
              break;
            case 'error':
              session.status = SshSessionStatus.error;
              session.errorMessage = event.message;
              terminal.write('\r\n\x1b[1;31m[TerMost 错误]\x1b[0m ${event.message}\r\n');
              notifyListeners();
              break;
            case 'closed':
              session.status = SshSessionStatus.disconnected;
              terminal.write('\r\n\x1b[1;33m[TerMost]\x1b[0m 会话已断开。\r\n');
              notifyListeners();
              break;
          }
        },
        onError: (err) {
          session.status = SshSessionStatus.error;
          session.errorMessage = err.toString();
          terminal.write('\r\n\x1b[1;31m[TerMost 连接失败]\x1b[0m $err\r\n');
          notifyListeners();
        },
        onDone: () {
          if (session.status != SshSessionStatus.error) {
            session.status = SshSessionStatus.disconnected;
          }
          notifyListeners();
        },
      );

      // Update host last connected time
      host.lastConnected = DateTime.now();
      StorageService().saveHost(host);
    } catch (e) {
      session.status = SshSessionStatus.error;
      session.errorMessage = e.toString();
      terminal.write('\r\n\x1b[1;31m[TerMost 异常]\x1b[0m $e\r\n');
      notifyListeners();
    }

    return sessionId;
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
    }
  }

  Future<void> closeAndRemoveSession(String sessionId) async {
    await disconnect(sessionId);
    _sessions.remove(sessionId);
    if (_activeSessionId == sessionId) {
      _activeSessionId = _sessions.keys.isNotEmpty ? _sessions.keys.last : null;
    }
    notifyListeners();
  }
}
