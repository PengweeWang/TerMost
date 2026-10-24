class PortForwardRule {
  final String id;
  String name;
  String forwardType; // "local", "remote", "dynamic"
  String hostId; // Associated SSH Host id
  String localHost; // usually "127.0.0.1"
  int localPort;
  String remoteHost; // destination host
  int remotePort; // destination port
  bool isEnabled; // user configured on/off
  bool isRunning; // active tunnel state in runtime
  int bytesUp;
  int bytesDown;

  PortForwardRule({
    required this.id,
    required this.name,
    required this.forwardType,
    required this.hostId,
    this.localHost = '127.0.0.1',
    required this.localPort,
    this.remoteHost = '127.0.0.1',
    this.remotePort = 80,
    this.isEnabled = false,
    this.isRunning = false,
    this.bytesUp = 0,
    this.bytesDown = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'forwardType': forwardType,
        'hostId': hostId,
        'localHost': localHost,
        'localPort': localPort,
        'remoteHost': remoteHost,
        'remotePort': remotePort,
        'isEnabled': isEnabled,
      };

  factory PortForwardRule.fromJson(Map<String, dynamic> json) => PortForwardRule(
        id: json['id'] as String,
        name: json['name'] as String,
        forwardType: (json['forwardType'] as String?) ?? 'local',
        hostId: (json['hostId'] as String?) ?? '',
        localHost: (json['localHost'] as String?) ?? '127.0.0.1',
        localPort: (json['localPort'] as num?)?.toInt() ?? 8080,
        remoteHost: (json['remoteHost'] as String?) ?? '127.0.0.1',
        remotePort: (json['remotePort'] as num?)?.toInt() ?? 80,
        isEnabled: (json['isEnabled'] as bool?) ?? false,
      );

  PortForwardRule copyWith({
    String? name,
    String? forwardType,
    String? hostId,
    String? localHost,
    int? localPort,
    String? remoteHost,
    int? remotePort,
    bool? isEnabled,
    bool? isRunning,
    int? bytesUp,
    int? bytesDown,
  }) {
    return PortForwardRule(
      id: id,
      name: name ?? this.name,
      forwardType: forwardType ?? this.forwardType,
      hostId: hostId ?? this.hostId,
      localHost: localHost ?? this.localHost,
      localPort: localPort ?? this.localPort,
      remoteHost: remoteHost ?? this.remoteHost,
      remotePort: remotePort ?? this.remotePort,
      isEnabled: isEnabled ?? this.isEnabled,
      isRunning: isRunning ?? this.isRunning,
      bytesUp: bytesUp ?? this.bytesUp,
      bytesDown: bytesDown ?? this.bytesDown,
    );
  }
}
