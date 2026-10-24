class SshKeyEntry {
  final String id;
  String name;
  final String algorithm; // ED25519, RSA, ECDSA-P256
  String comment;
  final String publicKeyOpenSsh;
  final String privateKeyOpenSsh;
  final String fingerprintSha256;
  final bool isEncrypted;
  final DateTime createdAt;

  SshKeyEntry({
    required this.id,
    required this.name,
    required this.algorithm,
    required this.comment,
    required this.publicKeyOpenSsh,
    required this.privateKeyOpenSsh,
    required this.fingerprintSha256,
    this.isEncrypted = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'algorithm': algorithm,
        'comment': comment,
        'publicKeyOpenSsh': publicKeyOpenSsh,
        'privateKeyOpenSsh': privateKeyOpenSsh,
        'fingerprintSha256': fingerprintSha256,
        'isEncrypted': isEncrypted,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SshKeyEntry.fromJson(Map<String, dynamic> json) => SshKeyEntry(
        id: json['id'] as String,
        name: json['name'] as String,
        algorithm: json['algorithm'] as String,
        comment: (json['comment'] as String?) ?? '',
        publicKeyOpenSsh: json['publicKeyOpenSsh'] as String,
        privateKeyOpenSsh: json['privateKeyOpenSsh'] as String,
        fingerprintSha256: json['fingerprintSha256'] as String,
        isEncrypted: (json['isEncrypted'] as bool?) ?? false,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );
}
