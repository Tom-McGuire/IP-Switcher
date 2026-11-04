import 'dart:io';

class Ipv4Utils {
  /// Validates a standard dotted-quad IPv4 address (e.g., 192.168.1.50).
  static bool isValidIpv4(String? input) {
    if (input == null || input.trim().isEmpty) return false;
    final parts = input.trim().split('.');
    if (parts.length != 4) return false;
    for (final part in parts) {
      final value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) return false;
      if (part.length > 1 && part.startsWith('0')) return false;
    }
    return InternetAddress.tryParse(input.trim())?.type ==
        InternetAddressType.IPv4;
  }

  /// Validates a contiguous IPv4 subnet mask (e.g., 255.255.255.0).
  static bool isValidSubnetMask(String? mask) {
    return maskToCidr(mask) != null;
  }

  /// Converts a CIDR prefix length (0-32) to a dotted-decimal subnet mask.
  static String cidrToMask(int cidr) {
    final clamped = cidr.clamp(0, 32);
    final int maskBits =
        clamped == 0 ? 0 : (0xFFFFFFFF << (32 - clamped)) & 0xFFFFFFFF;
    return [
      (maskBits >> 24) & 0xFF,
      (maskBits >> 16) & 0xFF,
      (maskBits >> 8) & 0xFF,
      maskBits & 0xFF,
    ].join('.');
  }

  /// Converts a dotted-decimal subnet mask to its CIDR prefix length, or null if invalid.
  static int? maskToCidr(String? mask) {
    if (mask == null || !isValidIpv4(mask)) return null;
    final parts = mask.trim().split('.').map(int.parse).toList();
    final int bits =
        (parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3];

    // Check that the binary representation consists of contiguous 1s followed by 0s.
    bool seenZero = false;
    int countOnes = 0;
    for (int i = 31; i >= 0; i--) {
      final bit = (bits >> i) & 1;
      if (bit == 1) {
        if (seenZero) return null; // Non-contiguous mask
        countOnes++;
      } else {
        seenZero = true;
      }
    }
    return countOnes;
  }

  /// Converts an IPv4 string to a 32-bit unsigned integer.
  static int? ipToInt(String? ip) {
    if (!isValidIpv4(ip)) return null;
    final p = ip!.trim().split('.').map(int.parse).toList();
    return ((p[0] << 24) | (p[1] << 16) | (p[2] << 8) | p[3]) & 0xFFFFFFFF;
  }

  /// Converts a 32-bit unsigned integer to dotted-decimal IPv4 string.
  static String intToIp(int value) {
    final v = value & 0xFFFFFFFF;
    return [
      (v >> 24) & 0xFF,
      (v >> 16) & 0xFF,
      (v >> 8) & 0xFF,
      v & 0xFF,
    ].join('.');
  }

  /// Checks if two IPv4 addresses are in the same subnet given a CIDR prefix.
  static bool isInSameSubnet(String? ip1, String? ip2, int? cidr) {
    if (cidr == null || cidr < 0 || cidr > 32) return false;
    final i1 = ipToInt(ip1);
    final i2 = ipToInt(ip2);
    if (i1 == null || i2 == null) return false;
    final mask = cidr == 0 ? 0 : (0xFFFFFFFF << (32 - cidr)) & 0xFFFFFFFF;
    return (i1 & mask) == (i2 & mask);
  }

  /// Computes a human-readable network summary (Network ID and Usable Host Range).
  static String describeSubnetRange(String? ip, int? cidr) {
    final ipInt = ipToInt(ip);
    if (ipInt == null || cidr == null || cidr < 0 || cidr > 32) {
      return 'Enter a valid IPv4 & CIDR to preview host range';
    }
    if (cidr == 32) {
      return 'Single Host Route ($ip/32)';
    }
    if (cidr == 31) {
      final mask = 0xFFFFFFFE;
      final net = ipInt & mask;
      return 'Point-to-Point (${intToIp(net)} - ${intToIp(net + 1)})';
    }
    final mask = cidr == 0 ? 0 : (0xFFFFFFFF << (32 - cidr)) & 0xFFFFFFFF;
    final network = ipInt & mask;
    final broadcast = (network | (~mask & 0xFFFFFFFF)) & 0xFFFFFFFF;
    final firstHost = intToIp(network + 1);
    final lastHost = intToIp(broadcast - 1);
    final netAddr = intToIp(network);
    final totalHosts = (1 << (32 - cidr)) - 2;
    return 'Net: $netAddr/$cidr  •  Range: $firstHost – $lastHost ($totalHosts hosts)';
  }
}
