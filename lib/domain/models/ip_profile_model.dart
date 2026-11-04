import 'dart:convert';
import 'ipv4_utils.dart';

class IpProfileModel {
  final String id;
  final String name;
  final String category; // e.g. 'LAB', 'FIELD', 'OFFICE', 'VLAN', 'CUSTOM'
  final bool isDhcp;
  final String? ipAddress;
  final String? subnetMask;
  final int? cidrPrefix;
  final String? defaultGateway;
  final String? primaryDns;
  final String? secondaryDns;
  final List<String> secondaryIps; // Optional alias IPs in IP/CIDR format
  final String? preferredInterface; // Optional bound NIC name/ID
  final int? vlanId;
  final int? mtu;
  final String notes;
  final bool isFavorite;
  final DateTime? lastAppliedAt;

  const IpProfileModel({
    required this.id,
    required this.name,
    required this.category,
    required this.isDhcp,
    this.ipAddress,
    this.subnetMask,
    this.cidrPrefix,
    this.defaultGateway,
    this.primaryDns,
    this.secondaryDns,
    this.secondaryIps = const [],
    this.preferredInterface,
    this.vlanId,
    this.mtu,
    this.notes = '',
    this.isFavorite = false,
    this.lastAppliedAt,
  });

  String get formattedIpWithCidr {
    if (isDhcp) return 'Dynamic (DHCP)';
    if (ipAddress == null || ipAddress!.isEmpty) return '—';
    final prefix = cidrPrefix ?? Ipv4Utils.maskToCidr(subnetMask) ?? 24;
    return '$ipAddress/$prefix';
  }

  String get formattedSubnetMask {
    if (isDhcp) return 'Dynamic';
    if (subnetMask != null && subnetMask!.isNotEmpty) return subnetMask!;
    if (cidrPrefix != null) return Ipv4Utils.cidrToMask(cidrPrefix!);
    return '255.255.255.0';
  }

  String get formattedGateway {
    if (isDhcp) return 'Auto (DHCP)';
    if (defaultGateway == null || defaultGateway!.trim().isEmpty) return '—';
    return defaultGateway!;
  }

  String get formattedDns {
    final dnsList = <String>[
      if (primaryDns != null && primaryDns!.trim().isNotEmpty) primaryDns!.trim(),
      if (secondaryDns != null && secondaryDns!.trim().isNotEmpty)
        secondaryDns!.trim(),
    ];
    if (dnsList.isEmpty) {
      return isDhcp ? 'Auto (DHCP)' : '—';
    }
    return dnsList.join(', ');
  }

  List<String> get dnsServersList {
    return <String>[
      if (primaryDns != null && primaryDns!.trim().isNotEmpty) primaryDns!.trim(),
      if (secondaryDns != null && secondaryDns!.trim().isNotEmpty)
        secondaryDns!.trim(),
    ];
  }

  IpProfileModel copyWith({
    String? id,
    String? name,
    String? category,
    bool? isDhcp,
    String? ipAddress,
    String? subnetMask,
    int? cidrPrefix,
    String? defaultGateway,
    String? primaryDns,
    String? secondaryDns,
    List<String>? secondaryIps,
    String? preferredInterface,
    bool clearPreferredInterface = false,
    int? vlanId,
    bool clearVlanId = false,
    int? mtu,
    bool clearMtu = false,
    String? notes,
    bool? isFavorite,
    DateTime? lastAppliedAt,
  }) {
    return IpProfileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      isDhcp: isDhcp ?? this.isDhcp,
      ipAddress: ipAddress ?? this.ipAddress,
      subnetMask: subnetMask ?? this.subnetMask,
      cidrPrefix: cidrPrefix ?? this.cidrPrefix,
      defaultGateway: defaultGateway ?? this.defaultGateway,
      primaryDns: primaryDns ?? this.primaryDns,
      secondaryDns: secondaryDns ?? this.secondaryDns,
      secondaryIps: secondaryIps ?? this.secondaryIps,
      preferredInterface: clearPreferredInterface
          ? null
          : (preferredInterface ?? this.preferredInterface),
      vlanId: clearVlanId ? null : (vlanId ?? this.vlanId),
      mtu: clearMtu ? null : (mtu ?? this.mtu),
      notes: notes ?? this.notes,
      isFavorite: isFavorite ?? this.isFavorite,
      lastAppliedAt: lastAppliedAt ?? this.lastAppliedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'is_dhcp': isDhcp ? 1 : 0,
      'ip_address': ipAddress,
      'subnet_mask': subnetMask,
      'cidr_prefix': cidrPrefix,
      'default_gateway': defaultGateway,
      'primary_dns': primaryDns,
      'secondary_dns': secondaryDns,
      'secondary_ips': jsonEncode(secondaryIps),
      'preferred_interface': preferredInterface,
      'vlan_id': vlanId,
      'mtu': mtu,
      'notes': notes,
      'is_favorite': isFavorite ? 1 : 0,
      'last_applied_at': lastAppliedAt?.toIso8601String(),
    };
  }

  factory IpProfileModel.fromMap(Map<String, dynamic> map) {
    List<String> parsedSecondaryIps = [];
    final rawSec = map['secondary_ips'];
    if (rawSec is String && rawSec.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawSec);
        if (decoded is List) {
          parsedSecondaryIps = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    } else if (rawSec is List) {
      parsedSecondaryIps = rawSec.map((e) => e.toString()).toList();
    }

    return IpProfileModel(
      id: map['id'] as String,
      name: map['name'] as String,
      category: (map['category'] as String?) ?? 'CUSTOM',
      isDhcp: (map['is_dhcp'] == 1 || map['is_dhcp'] == true),
      ipAddress: map['ip_address'] as String?,
      subnetMask: map['subnet_mask'] as String?,
      cidrPrefix: map['cidr_prefix'] as int?,
      defaultGateway: map['default_gateway'] as String?,
      primaryDns: map['primary_dns'] as String?,
      secondaryDns: map['secondary_dns'] as String?,
      secondaryIps: parsedSecondaryIps,
      preferredInterface: map['preferred_interface'] as String?,
      vlanId: map['vlan_id'] as int?,
      mtu: map['mtu'] as int?,
      notes: (map['notes'] as String?) ?? '',
      isFavorite: (map['is_favorite'] == 1 || map['is_favorite'] == true),
      lastAppliedAt: map['last_applied_at'] != null
          ? DateTime.tryParse(map['last_applied_at'] as String)
          : null,
    );
  }
}
