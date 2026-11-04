import '../../domain/models/ip_profile_model.dart';
import '../../domain/models/ipv4_utils.dart';
import '../../domain/models/network_interface_model.dart';
import '../services/gateway_ping_service.dart';
import '../services/nic_backend_service.dart';

class NicRepository {
  final NicBackendService _backendService;
  final GatewayPingService _pingService;

  NicRepository(this._backendService, this._pingService);

  NicBackendService get backendService => _backendService;
  GatewayPingService get pingService => _pingService;

  Future<bool> checkIsElevated() => _backendService.checkIsElevated();

  Future<List<NetworkInterfaceModel>> fetchInterfaces() async {
    final list = await _backendService.discoverInterfaces();
    if (list.isNotEmpty) return list;
    // Provide a fallback adapter entry if running in an environment with no physical NICs
    return const [
      NetworkInterfaceModel(
        id: 'eth0',
        displayName: 'eth0 (Wired Ethernet)',
        connectionName: 'Wired connection 1',
        macAddress: '00:E0:4C:68:01:A2',
        isUp: true,
        isDhcpEnabled: true,
        currentIp: '192.168.1.120',
        currentSubnet: '255.255.255.0',
        currentCidr: 24,
        currentGateway: '192.168.1.1',
        currentDns: ['1.1.1.1', '8.8.8.8'],
      ),
    ];
  }

  List<String> previewCommands({
    required TargetOsPlatform platform,
    required NetworkInterfaceModel nic,
    required IpProfileModel profile,
  }) {
    return _backendService.generateCommandsForPlatform(
      platform: platform,
      nic: nic,
      profile: profile,
    );
  }

  Future<CommandRunResult> applyProfileToNic({
    required NetworkInterfaceModel nic,
    required IpProfileModel profile,
    required bool isElevated,
    required bool dryRun,
  }) {
    final cmds = _backendService.generateCommandsForPlatform(
      platform: TargetOsPlatform.current,
      nic: nic,
      profile: profile,
    );
    return _backendService.executeCommands(
      commands: cmds,
      isAlreadyElevated: isElevated,
      dryRun: dryRun,
    );
  }

  /// Creates an in-memory updated [NetworkInterfaceModel] reflecting the target [profile]
  /// (used immediately after apply or during Simulation/Dry-Run mode).
  NetworkInterfaceModel simulateAppliedState(
    NetworkInterfaceModel nic,
    IpProfileModel profile,
  ) {
    if (profile.isDhcp) {
      return nic.copyWith(
        isDhcpEnabled: true,
        currentIp: nic.currentIp ?? '192.168.1.124',
        currentCidr: 24,
        currentSubnet: '255.255.255.0',
        currentGateway: '192.168.1.1',
        currentDns: profile.dnsServersList.isNotEmpty
            ? profile.dnsServersList
            : const ['1.1.1.1', '8.8.8.8'],
        secondaryIps: const [],
      );
    }

    final cidr =
        profile.cidrPrefix ?? Ipv4Utils.maskToCidr(profile.subnetMask) ?? 24;
    final mask = profile.subnetMask ?? Ipv4Utils.cidrToMask(cidr);
    return nic.copyWith(
      isDhcpEnabled: false,
      currentIp: profile.ipAddress,
      currentCidr: cidr,
      currentSubnet: mask,
      currentGateway: profile.defaultGateway ?? '',
      currentDns: profile.dnsServersList,
      secondaryIps: profile.secondaryIps,
      mtu: profile.mtu ?? nic.mtu,
    );
  }

  /// Converts a live [NetworkInterfaceModel]'s current configuration into a snapshot [IpProfileModel]
  /// so the user can Undo a switch or populate a new preset from the active NIC.
  IpProfileModel createSnapshotProfileFromNic(
    NetworkInterfaceModel nic, {
    String name = 'Previous NIC Snapshot',
  }) {
    return IpProfileModel(
      id: 'snapshot-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      category: 'CUSTOM',
      isDhcp: nic.isDhcpEnabled,
      ipAddress: nic.currentIp,
      subnetMask: nic.currentSubnet ??
          (nic.currentCidr != null
              ? Ipv4Utils.cidrToMask(nic.currentCidr!)
              : '255.255.255.0'),
      cidrPrefix:
          nic.currentCidr ?? Ipv4Utils.maskToCidr(nic.currentSubnet) ?? 24,
      defaultGateway: nic.currentGateway,
      primaryDns: nic.currentDns.isNotEmpty ? nic.currentDns.first : null,
      secondaryDns: nic.currentDns.length > 1 ? nic.currentDns[1] : null,
      secondaryIps: nic.secondaryIps,
      preferredInterface: nic.id,
      mtu: nic.mtu,
      notes: 'Captured from ${nic.displayName} (${nic.macAddress})',
    );
  }

  Future<GatewayPingResult> verifyGateway(String? gatewayIp) async {
    if (gatewayIp == null || gatewayIp.trim().isEmpty) {
      return const GatewayPingResult(
        gatewayIp: '',
        isReachable: false,
        rawOutput: 'No default gateway specified for this profile.',
      );
    }
    return _pingService.pingGateway(gatewayIp);
  }

  Future<void> stopAll() async {
    await _pingService.stopAll();
    await _backendService.terminateActiveProcesses();
  }
}
