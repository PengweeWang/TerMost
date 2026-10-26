import 'dart:io';
import 'package:flutter/services.dart';

class KeepAliveService {
  static final KeepAliveService _instance = KeepAliveService._internal();
  factory KeepAliveService() => _instance;
  KeepAliveService._internal();

  static const _channel = MethodChannel('com.termost.termost/keepalive');
  bool _isServiceRunning = false;

  bool get isRunning => _isServiceRunning;

  Future<void> syncState({
    required int activeSessionsCount,
    required int activeTunnelsCount,
  }) async {
    if (!Platform.isAndroid) return;

    final totalActive = activeSessionsCount + activeTunnelsCount;

    if (totalActive > 0) {
      const title = 'TerMost - 后台连接保持中';
      final details = <String>[];
      if (activeSessionsCount > 0) {
        details.add('$activeSessionsCount 个终端会话');
      }
      if (activeTunnelsCount > 0) {
        details.add('$activeTunnelsCount 条端口转发');
      }
      final content = '正在保持 ${details.join("、")}，切屏后台不断开';

      try {
        if (!_isServiceRunning) {
          await _channel.invokeMethod('start', {
            'title': title,
            'content': content,
          });
          _isServiceRunning = true;
        } else {
          await _channel.invokeMethod('update', {
            'title': title,
            'content': content,
          });
        }
      } catch (_) {}
    } else {
      if (_isServiceRunning) {
        try {
          await _channel.invokeMethod('stop');
        } catch (_) {}
        _isServiceRunning = false;
      }
    }
  }

  Future<void> stop() async {
    if (!Platform.isAndroid) return;
    if (_isServiceRunning) {
      try {
        await _channel.invokeMethod('stop');
      } catch (_) {}
      _isServiceRunning = false;
    }
  }
}
