import 'ip_profile_model.dart';
import 'ipv4_utils.dart';

class NetworkInterfaceModel {
  final String id; // OS device name e.g. 'eth0', 'en0', 'Ethernet'
  final String displayName; // Friendly label e.g. 'en0 (Wi-Fi)' or 'eth0'
  final String? connectionName; // NetworkManager connection profile name or macOS Service name
  final String macAddress;
  final bool isUp;
  final bool isDhcpEnabled;
  final String? currentIp;
  final String? currentSubnet;
  final int? currentCidr;
  final String? currentGateway;
  final List<String> currentDns;
  final List<String> secondaryIps;
  final int? mtu;
  final bool isLoopback;
  final bool isPlaceholder;

  const NetworkInterfaceModel({
    required this.id,
    required this.displayName,
    this.connectionName,
    required this.macAddress,
    required this.isUp,
    required this.isDhcpEnabled,
    this.currentIp,
    this.currentSubnet,
    this.currentCidr,
    this.currentGateway,
    this.currentDns = const [],
    this.secondaryIps = const [],
    this.mtu,
    this.isLoopback = false,
    this.isPlaceholder = false,
  });

  String get formattedIpWithCidr {
    if (currentIp == null || currentIp!.isEmpty) return 'Unassigned';
    final prefix = currentCidr ?? Ipv4Utils.maskToCidr(currentSubnet) ?? 24;
    return '$currentIp/$prefix';
  }

  String get formattedSubnet {
    if (currentSubnet != null && currentSubnet!.isNotEmpty) {
      return currentSubnet!;
    }
    if (currentCidr != null) {
      return Ipv4Utils.cidrToMask(currentCidr!);
    }
    return '—';
  }

  String get formattedGateway =>
      (currentGateway != null && currentGateway!.isNotEmpty)
          ? currentGateway!
          : '—';

  String get formattedDns =>
      currentDns.isNotEmpty ? currentDns.join(', ') : '—';

  /// Determines if this live adapter currently matches a saved [IpProfileModel].
  bool matchesProfile(IpProfileModel profile) {
    if (profile.isDhcp) {
      // Only match pure DHCP preset if adapter is in DHCP mode and has no custom static override
      if (!isDhcpEnabled) return false;
      if (profile.primaryDns != null &&
          profile.primaryDns!.trim().isNotEmpty &&
          !currentDns.contains(profile.primaryDns!.trim())) {
        return false;
      }
      return true;
    }

    // Static profile match
    if (currentIp == null || profile.ipAddress == null) return false;
    if (currentIp!.trim() != profile.ipAddress!.trim()) return false;

    final targetCidr =
        profile.cidrPrefix ?? Ipv4Utils.maskToCidr(profile.subnetMask) ?? 24;
    final liveCidr =
        currentCidr ?? Ipv4Utils.maskToCidr(currentSubnet) ?? 24;
    if (targetCidr != liveCidr) return false;

    final targetGw = (profile.defaultGateway ?? '').trim();
    final liveGw = (currentGateway ?? '').trim();
    if (targetGw.isNotEmpty && targetGw != liveGw) return false;

    return true;
  }

  NetworkInterfaceModel copyWith({
    String? id,
    String? displayName,
    String? connectionName,
    String? macAddress,
    bool? isUp,
    bool? isDhcpEnabled,
    String? currentIp,
    String? currentSubnet,
    int? currentCidr,
    String? currentGateway,
    List<String>? currentDns,
    List<String>? secondaryIps,
    int? mtu,
    bool? isLoopback,
    bool? isPlaceholder,
  }) {
    return NetworkInterfaceModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      connectionName: connectionName ?? this.connectionName,
      macAddress: macAddress ?? this.macAddress,
      isUp: isUp ?? this.isUp,
      isDhcpEnabled: isDhcpEnabled ?? this.isDhcpEnabled,
      currentIp: currentIp ?? this.currentIp,
      currentSubnet: currentSubnet ?? this.currentSubnet,
      currentCidr: currentCidr ?? this.currentCidr,
      currentGateway: currentGateway ?? this.currentGateway,
      currentDns: currentDns ?? this.currentDns,
      secondaryIps: secondaryIps ?? this.secondaryIps,
      mtu: mtu ?? this.mtu,
      isLoopback: isLoopback ?? this.isLoopback,
      isPlaceholder: isPlaceholder ?? this.isPlaceholder,
    );
  }
}
