import 'package:flutter_test/flutter_test.dart';
import 'package:ip_setter/domain/models/ipv4_utils.dart';

void main() {
  group('Ipv4Utils Comprehensive Tests', () {
    test('isValidIpv4 rejects empty, null, and malformed strings', () {
      expect(Ipv4Utils.isValidIpv4(null), isFalse);
      expect(Ipv4Utils.isValidIpv4(''), isFalse);
      expect(Ipv4Utils.isValidIpv4('   '), isFalse);
      expect(Ipv4Utils.isValidIpv4('192.168.1'), isFalse);
      expect(Ipv4Utils.isValidIpv4('192.168.1.1.1'), isFalse);
      expect(Ipv4Utils.isValidIpv4('192.168.1.256'), isFalse);
      expect(Ipv4Utils.isValidIpv4('192.168.1.-1'), isFalse);
      expect(Ipv4Utils.isValidIpv4('192.168.1.abc'), isFalse);
      expect(Ipv4Utils.isValidIpv4('192.168.1.1'), isTrue);
    });

    test('isValidSubnetMask and maskToCidr handle valid and non-contiguous masks', () {
      expect(Ipv4Utils.isValidSubnetMask(null), isFalse);
      expect(Ipv4Utils.isValidSubnetMask('255.255.255.0'), isTrue);
      expect(Ipv4Utils.isValidSubnetMask('255.255.255.128'), isTrue);
      // Non-contiguous subnet mask
      expect(Ipv4Utils.isValidSubnetMask('255.255.0.255'), isFalse);
      expect(Ipv4Utils.maskToCidr('255.255.0.255'), isNull);
      expect(Ipv4Utils.maskToCidr('255.255.255.255'), equals(32));
      expect(Ipv4Utils.maskToCidr('0.0.0.0'), equals(0));
    });

    test('cidrToMask clamps values properly', () {
      expect(Ipv4Utils.cidrToMask(0), equals('0.0.0.0'));
      expect(Ipv4Utils.cidrToMask(24), equals('255.255.255.0'));
      expect(Ipv4Utils.cidrToMask(32), equals('255.255.255.255'));
      expect(Ipv4Utils.cidrToMask(-5), equals('0.0.0.0'));
      expect(Ipv4Utils.cidrToMask(40), equals('255.255.255.255'));
    });

    test('ipToInt and intToIp conversions', () {
      expect(Ipv4Utils.ipToInt('invalid'), isNull);
      final intVal = Ipv4Utils.ipToInt('192.168.1.1');
      expect(intVal, isNotNull);
      expect(Ipv4Utils.intToIp(intVal!), equals('192.168.1.1'));
    });

    test('isInSameSubnet computes subnet membership', () {
      expect(Ipv4Utils.isInSameSubnet('192.168.1.10', '192.168.1.25', 24), isTrue);
      expect(Ipv4Utils.isInSameSubnet('192.168.1.10', '192.168.2.25', 24), isFalse);
      expect(Ipv4Utils.isInSameSubnet('192.168.1.10', '192.168.2.25', null), isFalse);
      expect(Ipv4Utils.isInSameSubnet('192.168.1.10', '192.168.2.25', -1), isFalse);
      expect(Ipv4Utils.isInSameSubnet('192.168.1.10', '192.168.2.25', 33), isFalse);
      expect(Ipv4Utils.isInSameSubnet('invalid', '192.168.1.1', 24), isFalse);
    });

    test('describeSubnetRange formats /32, /31, /24 and invalid prefixes', () {
      expect(
        Ipv4Utils.describeSubnetRange(null, 24),
        equals('Enter a valid IPv4 & CIDR to preview host range'),
      );
      expect(
        Ipv4Utils.describeSubnetRange('10.0.0.1', 32),
        equals('Single Host Route (10.0.0.1/32)'),
      );
      expect(
        Ipv4Utils.describeSubnetRange('10.0.0.0', 31),
        equals('Point-to-Point (10.0.0.0 - 10.0.0.1)'),
      );
      final range24 = Ipv4Utils.describeSubnetRange('192.168.1.50', 24);
      expect(range24, contains('Net: 192.168.1.0/24'));
      expect(range24, contains('192.168.1.1 – 192.168.1.254 (254 hosts)'));
    });
  });
}
