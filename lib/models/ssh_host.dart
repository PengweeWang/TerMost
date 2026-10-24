class SshHost {
  final String id;
  String name;
  String host;
  int port;
  String username;
  String authType; // "password" or "key"
  String? password;
  String? keyId; // References SshKeyEntry.id
  String? passphrase;
  String? group;
  DateTime? lastConnected;

  SshHost({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    required this.username,
    this.authType = 'password',
    this.password,
    this.keyId,
    this.passphrase,
    this.group,
    this.lastConnected,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'username': username,
        'authType': authType,
        'password': password,
        'keyId': keyId,
        'passphrase': passphrase,
        'group': group,
        'lastConnected': lastConnected?.toIso8601String(),
      };

  factory SshHost.fromJson(Map<String, dynamic> json) => SshHost(
        id: json['id'] as String,
        name: json['name'] as String,
        host: json['host'] as String,
        port: (json['port'] as num?)?.toInt() ?? 22,
        username: json['username'] as String,
        authType: (json['authType'] as String?) ?? 'password',
        password: json['password'] as String?,
        keyId: json['keyId'] as String?,
        passphrase: json['passphrase'] as String?,
        group: json['group'] as String?,
        lastConnected: json['lastConnected'] != null
            ? DateTime.tryParse(json['lastConnected'] as String)
            : null,
      );

  SshHost copyWith({
    String? name,
    String? host,
    int? port,
    String? username,
    String? authType,
    String? password,
    String? keyId,
    String? passphrase,
    String? group,
    DateTime? lastConnected,
  }) {
    return SshHost(
      id: id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      authType: authType ?? this.authType,
      password: password ?? this.password,
      keyId: keyId ?? this.keyId,
      passphrase: passphrase ?? this.passphrase,
      group: group ?? this.group,
      lastConnected: lastConnected ?? this.lastConnected,
    );
  }
}
