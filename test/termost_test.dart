import 'package:flutter_test/flutter_test.dart';
import 'package:termost/models/ssh_host.dart';
import 'package:termost/models/ssh_key_entry.dart';
import 'package:termost/models/port_forward_rule.dart';

void main() {
  group('TerMost Models Tests', () {
    test('SshHost serialization and deserialization', () {
      final host = SshHost(
        id: 'host_1',
        name: 'Production Server',
        host: '192.168.1.100',
        port: 2222,
        username: 'ubuntu',
        authType: 'key',
        keyId: 'key_123',
        passphrase: 'secret-passphrase',
      );

      final json = host.toJson();
      final restored = SshHost.fromJson(json);

      expect(restored.id, 'host_1');
      expect(restored.name, 'Production Server');
      expect(restored.host, '192.168.1.100');
      expect(restored.port, 2222);
      expect(restored.username, 'ubuntu');
      expect(restored.authType, 'key');
      expect(restored.keyId, 'key_123');
      expect(restored.passphrase, 'secret-passphrase');
    });

    test('SshKeyEntry serialization and deserialization', () {
      final key = SshKeyEntry(
        id: 'key_1',
        name: 'Work Key',
        algorithm: 'ED25519',
        comment: 'user@termost',
        publicKeyOpenSsh: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...',
        privateKeyOpenSsh: '-----BEGIN OPENSSH PRIVATE KEY-----\n...',
        fingerprintSha256: 'SHA256:abc123xyz',
        isEncrypted: false,
      );

      final json = key.toJson();
      final restored = SshKeyEntry.fromJson(json);

      expect(restored.id, 'key_1');
      expect(restored.name, 'Work Key');
      expect(restored.algorithm, 'ED25519');
      expect(restored.fingerprintSha256, 'SHA256:abc123xyz');
      expect(restored.isEncrypted, false);
    });

    test('PortForwardRule serialization and deserialization', () {
      final rule = PortForwardRule(
        id: 'rule_1',
        name: 'Remote MySQL',
        forwardType: 'local',
        hostId: 'host_1',
        localHost: '127.0.0.1',
        localPort: 3307,
        remoteHost: '127.0.0.1',
        remotePort: 3306,
        isEnabled: true,
      );

      final json = rule.toJson();
      final restored = PortForwardRule.fromJson(json);

      expect(restored.id, 'rule_1');
      expect(restored.name, 'Remote MySQL');
      expect(restored.forwardType, 'local');
      expect(restored.localPort, 3307);
      expect(restored.remotePort, 3306);
      expect(restored.isEnabled, true);
    });
  });
}
