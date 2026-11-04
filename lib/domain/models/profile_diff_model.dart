import 'ip_profile_model.dart';
import 'network_interface_model.dart';

class ProfileDiffField {
  final String label;
  final String currentValue;
  final String targetValue;
  final bool isChanged;
  final bool isMonospace;

  const ProfileDiffField({
    required this.label,
    required this.currentValue,
    required this.targetValue,
    required this.isChanged,
    this.isMonospace = true,
  });

  static List<ProfileDiffField> computeDiff({
    required NetworkInterfaceModel? nic,
    required IpProfileModel profile,
  }) {
    if (nic == null) {
      return [
        ProfileDiffField(
          label: 'Target Adapter',
          currentValue: 'None Selected',
          targetValue: profile.preferredInterface ?? 'Any Adapter',
          isChanged: true,
        ),
      ];
    }

    final currentMode = nic.isDhcpEnabled ? 'DHCP (Automatic)' : 'Static IPv4';
    final targetMode = profile.isDhcp ? 'DHCP (Automatic)' : 'Static IPv4';

    final curIp = nic.formattedIpWithCidr;
    final tgtIp = profile.formattedIpWithCidr;

    final curMask = nic.formattedSubnet;
    final tgtMask = profile.formattedSubnetMask;

    final curGw = nic.formattedGateway;
    final tgtGw = profile.formattedGateway;

    final curDns = nic.formattedDns;
    final tgtDns = profile.formattedDns;

    final curAliases =
        nic.secondaryIps.isEmpty ? 'None' : nic.secondaryIps.join(', ');
    final tgtAliases =
        profile.secondaryIps.isEmpty ? 'None' : profile.secondaryIps.join(', ');

    return [
      ProfileDiffField(
        label: 'Interface',
        currentValue: '${nic.displayName} (${nic.macAddress})',
        targetValue: profile.preferredInterface != null &&
                profile.preferredInterface!.isNotEmpty
            ? '${profile.preferredInterface} (Bound)'
            : '${nic.displayName} (Selected)',
        isChanged: profile.preferredInterface != null &&
            profile.preferredInterface!.isNotEmpty &&
            profile.preferredInterface != nic.id,
      ),
      ProfileDiffField(
        label: 'Config Mode',
        currentValue: currentMode,
        targetValue: targetMode,
        isChanged: nic.isDhcpEnabled != profile.isDhcp,
        isMonospace: false,
      ),
      ProfileDiffField(
        label: 'IPv4 / CIDR',
        currentValue: curIp,
        targetValue: tgtIp,
        isChanged: profile.isDhcp ? !nic.isDhcpEnabled : (curIp != tgtIp),
      ),
      ProfileDiffField(
        label: 'Subnet Mask',
        currentValue: curMask,
        targetValue: tgtMask,
        isChanged: profile.isDhcp ? !nic.isDhcpEnabled : (curMask != tgtMask),
      ),
      ProfileDiffField(
        label: 'Default Gateway',
        currentValue: curGw,
        targetValue: tgtGw,
        isChanged: profile.isDhcp ? !nic.isDhcpEnabled : (curGw != tgtGw),
      ),
      ProfileDiffField(
        label: 'DNS Servers',
        currentValue: curDns,
        targetValue: tgtDns,
        isChanged: curDns != tgtDns && !(profile.isDhcp && tgtDns == 'Auto (DHCP)' && nic.isDhcpEnabled),
      ),
      if (nic.secondaryIps.isNotEmpty || profile.secondaryIps.isNotEmpty)
        ProfileDiffField(
          label: 'Secondary Alias IPs',
          currentValue: curAliases,
          targetValue: tgtAliases,
          isChanged: curAliases != tgtAliases,
        ),
    ];
  }
}
