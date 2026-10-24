import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ssh_host.dart';
import '../models/ssh_key_entry.dart';
import '../models/port_forward_rule.dart';

class StorageService extends ChangeNotifier {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _keyHosts = 'termost_hosts';
  static const String _keyKeys = 'termost_keys';
  static const String _keyRules = 'termost_forward_rules';
  static const String _keyFontSize = 'termost_font_size';
  static const String _keyThemeMode = 'termost_theme_mode';

  late SharedPreferences _prefs;
  bool _initialized = false;

  final List<SshHost> _hosts = [];
  final List<SshKeyEntry> _keys = [];
  final List<PortForwardRule> _rules = [];

  double _fontSize = 13.0;
  String _themeMode = 'system'; // 'system', 'light', 'dark'

  List<SshHost> get hosts => List.unmodifiable(_hosts);
  List<SshKeyEntry> get keys => List.unmodifiable(_keys);
  List<PortForwardRule> get rules => List.unmodifiable(_rules);
  double get fontSize => _fontSize;
  String get themeMode => _themeMode;

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();

    // Load Hosts
    final hostsJson = _prefs.getString(_keyHosts);
    if (hostsJson != null) {
      try {
        final List<dynamic> list = jsonDecode(hostsJson) as List<dynamic>;
        _hosts.clear();
        for (final item in list) {
          _hosts.add(SshHost.fromJson(item as Map<String, dynamic>));
        }
      } catch (e) {
        debugPrint('Error loading hosts: $e');
      }
    }

    // Load Keys
    final keysJson = _prefs.getString(_keyKeys);
    if (keysJson != null) {
      try {
        final List<dynamic> list = jsonDecode(keysJson) as List<dynamic>;
        _keys.clear();
        for (final item in list) {
          _keys.add(SshKeyEntry.fromJson(item as Map<String, dynamic>));
        }
      } catch (e) {
        debugPrint('Error loading keys: $e');
      }
    }

    // Load Rules
    final rulesJson = _prefs.getString(_keyRules);
    if (rulesJson != null) {
      try {
        final List<dynamic> list = jsonDecode(rulesJson) as List<dynamic>;
        _rules.clear();
        for (final item in list) {
          _rules.add(PortForwardRule.fromJson(item as Map<String, dynamic>));
        }
      } catch (e) {
        debugPrint('Error loading rules: $e');
      }
    }

    _fontSize = _prefs.getDouble(_keyFontSize) ?? 13.0;
    _themeMode = _prefs.getString(_keyThemeMode) ?? 'system';
    _initialized = true;
    notifyListeners();
  }

  // ---- Hosts Management ----
  Future<void> saveHost(SshHost host) async {
    final idx = _hosts.indexWhere((h) => h.id == host.id);
    if (idx >= 0) {
      _hosts[idx] = host;
    } else {
      _hosts.add(host);
    }
    await _persistHosts();
    notifyListeners();
  }

  Future<void> deleteHost(String id) async {
    _hosts.removeWhere((h) => h.id == id);
    await _persistHosts();
    notifyListeners();
  }

  SshHost? getHostById(String id) {
    try {
      return _hosts.firstWhere((h) => h.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistHosts() async {
    final jsonList = _hosts.map((h) => h.toJson()).toList();
    await _prefs.setString(_keyHosts, jsonEncode(jsonList));
  }

  // ---- Keys Management ----
  Future<void> saveKey(SshKeyEntry key) async {
    final idx = _keys.indexWhere((k) => k.id == key.id);
    if (idx >= 0) {
      _keys[idx] = key;
    } else {
      _keys.add(key);
    }
    await _persistKeys();
    notifyListeners();
  }

  Future<void> deleteKey(String id) async {
    _keys.removeWhere((k) => k.id == id);
    await _persistKeys();
    notifyListeners();
  }

  SshKeyEntry? getKeyById(String id) {
    try {
      return _keys.firstWhere((k) => k.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistKeys() async {
    final jsonList = _keys.map((k) => k.toJson()).toList();
    await _prefs.setString(_keyKeys, jsonEncode(jsonList));
  }

  // ---- Rules Management ----
  Future<void> saveRule(PortForwardRule rule) async {
    final idx = _rules.indexWhere((r) => r.id == rule.id);
    if (idx >= 0) {
      _rules[idx] = rule;
    } else {
      _rules.add(rule);
    }
    await _persistRules();
    notifyListeners();
  }

  Future<void> deleteRule(String id) async {
    _rules.removeWhere((r) => r.id == id);
    await _persistRules();
    notifyListeners();
  }

  Future<void> _persistRules() async {
    final jsonList = _rules.map((r) => r.toJson()).toList();
    await _prefs.setString(_keyRules, jsonEncode(jsonList));
  }

  // ---- Settings ----
  Future<void> setFontSize(double size) async {
    _fontSize = size.clamp(9.0, 24.0);
    await _prefs.setDouble(_keyFontSize, _fontSize);
    notifyListeners();
  }

  Future<void> setThemeMode(String mode) async {
    _themeMode = mode;
    await _prefs.setString(_keyThemeMode, mode);
    notifyListeners();
  }
}
