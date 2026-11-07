import 'package:flutter_test/flutter_test.dart';
import 'package:ip_setter/domain/models/ip_profile_model.dart';
import 'package:ip_setter/domain/models/network_interface_model.dart';
import 'package:ip_setter/domain/models/profile_diff_model.dart';

void main() {
  group('NetworkInterfaceModel & ProfileDiffField Tests', () {
    const liveDhcpNic = NetworkInterfaceModel(
      id: 'eth0',
      displayName: 'eth0 (Wired)',
      macAddress: '00:11:22:33:44:55',
      isUp: true,
      isDhcpEnabled: true,
      currentIp: '192.168.1.150',
      currentSubnet: '255.255.255.0',
      currentCidr: 24,
      currentGateway: '192.168.1.1',
      currentDns: ['1.1.1.1', '8.8.8.8'],
      secondaryIps: ['10.0.0.5/24'],
      mtu: 1500,
    );

    const liveStaticNic = NetworkInterfaceModel(
      id: 'eth0',
      displayName: 'eth0 (Wired)',
      macAddress: '00:11:22:33:44:55',
      isUp: true,
      isDhcpEnabled: false,
      currentIp: '192.168.1.50',
      currentSubnet: '255.255.255.0',
      currentCidr: 24,
      currentGateway: '192.168.1.1',
      currentDns: ['1.1.1.1'],
    );

    test('matchesProfile returns true for matching DHCP profile', () {
      const dhcpProfile = IpProfileModel(
        id: 'p-dhcp',
        name: 'Office DHCP',
        category: 'OFFICE',
        isDhcp: true,
      );
      expect(liveDhcpNic.matchesProfile(dhcpProfile), isTrue);
      expect(liveStaticNic.matchesProfile(dhcpProfile), isFalse);
    });

    test('matchesProfile returns true for matching static profile', () {
      const staticProfile = IpProfileModel(
        id: 'p-static',
        name: 'Lab Static',
        category: 'LAB',
        isDhcp: false,
        ipAddress: '192.168.1.50',
        subnetMask: '255.255.255.0',
        cidrPrefix: 24,
        defaultGateway: '192.168.1.1',
      );
      expect(liveStaticNic.matchesProfile(staticProfile), isTrue);

      final differentIpProfile = staticProfile.copyWith(ipAddress: '192.168.1.99');
      expect(liveStaticNic.matchesProfile(differentIpProfile), isFalse);

      final differentGwProfile = staticProfile.copyWith(defaultGateway: '10.0.0.1');
      expect(liveStaticNic.matchesProfile(differentGwProfile), isFalse);
    });

    test('ProfileDiffField.computeDiff handles null NIC gracefully', () {
      const targetProfile = IpProfileModel(
        id: 'p1',
        name: 'Test Profile',
        category: 'LAB',
        isDhcp: false,
        ipAddress: '192.168.1.20',
        subnetMask: '255.255.255.0',
        defaultGateway: '192.168.1.1',
      );

      final diffs = ProfileDiffField.computeDiff(
        nic: null,
        profile: targetProfile,
      );

      expect(diffs, isNotEmpty);
      expect(diffs.any((d) => d.label == 'Target Adapter' && d.isChanged), isTrue);
      expect(diffs.firstWhere((d) => d.label == 'Target Adapter').currentValue, equals('None Selected'));
    });

    test('ProfileDiffField.computeDiff detects differences between DHCP and Static', () {
      const targetStatic = IpProfileModel(
        id: 'p1',
        name: 'Target Static',
        category: 'LAB',
        isDhcp: false,
        ipAddress: '10.0.0.50',
        subnetMask: '255.255.0.0',
        cidrPrefix: 16,
        defaultGateway: '10.0.0.1',
        primaryDns: '9.9.9.9',
        secondaryIps: ['192.168.20.1/24'],
        mtu: 1400,
      );

      final diffs = ProfileDiffField.computeDiff(
        nic: liveDhcpNic,
        profile: targetStatic,
      );

      final modeDiff = diffs.firstWhere((d) => d.label == 'Config Mode');
      expect(modeDiff.isChanged, isTrue);
      expect(modeDiff.currentValue, contains('DHCP'));
      expect(modeDiff.targetValue, contains('Static'));

      final ipDiff = diffs.firstWhere((d) => d.label == 'IPv4 / CIDR');
      expect(ipDiff.isChanged, isTrue);
      expect(ipDiff.currentValue, contains('192.168.1.150'));
      expect(ipDiff.targetValue, contains('10.0.0.50'));
    });

    test('ProfileDiffField.computeDiff shows unchanged when matching', () {
      const matchingStatic = IpProfileModel(
        id: 'p1',
        name: 'Matching Static',
        category: 'LAB',
        isDhcp: false,
        ipAddress: '192.168.1.50',
        subnetMask: '255.255.255.0',
        cidrPrefix: 24,
        defaultGateway: '192.168.1.1',
        primaryDns: '1.1.1.1',
      );

      final diffs = ProfileDiffField.computeDiff(
        nic: liveStaticNic,
        profile: matchingStatic,
      );

      expect(diffs.firstWhere((d) => d.label == 'Config Mode').isChanged, isFalse);
      expect(diffs.firstWhere((d) => d.label == 'IPv4 / CIDR').isChanged, isFalse);
      expect(diffs.firstWhere((d) => d.label == 'Default Gateway').isChanged, isFalse);
    });
  });
}
