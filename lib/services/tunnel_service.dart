import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/port_forward_rule.dart';
import '../src/rust/api/simple.dart' as rust_api;
import '../src/rust/forwarding.dart';
import '../src/rust/session.dart';
import 'storage_service.dart';

class TunnelService extends ChangeNotifier {
  static final TunnelService _instance = TunnelService._internal();
  factory TunnelService() => _instance;
  TunnelService._internal();

  final Map<String, StreamSubscription<TunnelEvent>> _subscriptions = {};
  Timer? _statsTimer;

  bool isTunnelRunning(String ruleId) => _subscriptions.containsKey(ruleId);

  Future<void> startTunnel(PortForwardRule rule) async {
    final host = StorageService().getHostById(rule.hostId);
    if (host == null) {
      throw Exception('关联的 SSH 主机不存在');
    }

    // Resolve private key if key-based auth
    String? privKeyStr;
    if (host.authType == 'key' && host.keyId != null) {
      final keyEntry = StorageService().getKeyById(host.keyId!);
      if (keyEntry != null) {
        privKeyStr = keyEntry.privateKeyOpenSsh;
      }
    }

    final sshConfig = SshConnectConfig(
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

    final config = PortForwardConfig(
      tunnelId: rule.id,
      name: rule.name,
      forwardType: rule.forwardType,
      localHost: rule.localHost,
      localPort: rule.localPort,
      remoteHost: rule.remoteHost,
      remotePort: rule.remotePort,
      sshConfig: sshConfig,
    );

    try {
      final stream = rust_api.startPortForwarding(config: config);

      rule.isRunning = true;
      rule.isEnabled = true;
      StorageService().saveRule(rule);
      notifyListeners();

      _subscriptions[rule.id] = stream.listen(
        (event) {
          switch (event.eventType) {
            case 'started':
              rule.isRunning = true;
              notifyListeners();
              break;
            case 'stopped':
              rule.isRunning = false;
              _subscriptions[rule.id]?.cancel();
              _subscriptions.remove(rule.id);
              notifyListeners();
              break;
            case 'error':
              rule.isRunning = false;
              _subscriptions[rule.id]?.cancel();
              _subscriptions.remove(rule.id);
              notifyListeners();
              break;
          }
        },
        onError: (err) {
          rule.isRunning = false;
          _subscriptions[rule.id]?.cancel();
          _subscriptions.remove(rule.id);
          notifyListeners();
        },
        onDone: () {
          rule.isRunning = false;
          _subscriptions.remove(rule.id);
          notifyListeners();
        },
      );

      _ensureStatsTimer();
    } catch (e) {
      rule.isRunning = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stopTunnel(PortForwardRule rule) async {
    try {
      await rust_api.stopPortForwarding(tunnelId: rule.id);
    } catch (_) {}

    await _subscriptions[rule.id]?.cancel();
    _subscriptions.remove(rule.id);
    rule.isRunning = false;
    rule.isEnabled = false;
    StorageService().saveRule(rule);
    notifyListeners();

    if (_subscriptions.isEmpty) {
      _statsTimer?.cancel();
      _statsTimer = null;
    }
  }

  void _ensureStatsTimer() {
    if (_statsTimer != null) return;
    _statsTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final rules = StorageService().rules;
      bool hasActive = false;
      for (final rule in rules) {
        if (_subscriptions.containsKey(rule.id)) {
          hasActive = true;
          try {
            final stats = await rust_api.getForwardingStats(tunnelId: rule.id);
            rule.bytesUp = stats.bytesUp.toInt();
            rule.bytesDown = stats.bytesDown.toInt();
            rule.isRunning = stats.isRunning;
          } catch (_) {}
        }
      }
      if (hasActive) {
        notifyListeners();
      } else {
        _statsTimer?.cancel();
        _statsTimer = null;
      }
    });
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
