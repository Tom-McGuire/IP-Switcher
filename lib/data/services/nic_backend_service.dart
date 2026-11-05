import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../domain/models/ip_profile_model.dart';
import '../../domain/models/ipv4_utils.dart';
import '../../domain/models/network_interface_model.dart';

enum TargetOsPlatform {
  linux,
  macos,
  windows;

  static TargetOsPlatform get current {
    if (Platform.isWindows) return TargetOsPlatform.windows;
    if (Platform.isMacOS) return TargetOsPlatform.macos;
    return TargetOsPlatform.linux;
  }

  String get label {
    switch (this) {
      case TargetOsPlatform.linux:
        return 'Linux (nmcli / iproute2)';
      case TargetOsPlatform.macos:
        return 'macOS (networksetup)';
      case TargetOsPlatform.windows:
        return 'Windows (netsh)';
    }
  }

  String get shortLabel {
    switch (this) {
      case TargetOsPlatform.linux:
        return 'Linux';
      case TargetOsPlatform.macos:
        return 'macOS';
      case TargetOsPlatform.windows:
        return 'Windows';
    }
  }
}

class CommandRunResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  final List<String> executedCommands;

  const CommandRunResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.executedCommands,
  });
}

class NicBackendService {
  final Set<Process> _activeProcesses = {};

  /// Terminates any in-flight subprocesses cleanly on application exit.
  Future<void> terminateActiveProcesses() async {
    for (final proc in _activeProcesses.toList()) {
      try {
        proc.kill(ProcessSignal.sigterm);
      } catch (_) {}
    }
    _activeProcesses.clear();
  }

  /// Checks whether the application process is already running as root / Administrator.
  Future<bool> checkIsElevated() async {
    try {
      if (Platform.isWindows) {
        final res = await Process.run('net', ['session'], runInShell: true);
        return res.exitCode == 0;
      } else {
        final res = await Process.run('id', ['-u']);
        return res.stdout.toString().trim() == '0';
      }
    } catch (_) {
      return false;
    }
  }

  /// Sanitizes identifiers (interface names, connection names) by stripping shell metacharacters
  /// while preserving Unicode letters (e.g. "Conexión de área local") and apostrophes.
  static String sanitizeIdentifier(String input) {
    return input.replaceAll(RegExp(r'["`$;&|<>\r\n\x00\\]'), '').trim();
  }

  /// Sanitize IPv4 or CIDR strings.
  static String sanitizeIpOrCidr(String input) {
    return input.replaceAll(RegExp(r'[^0-9\./]'), '');
  }

  /// Normalizes and validates a `IP` or `IP/CIDR` secondary alias, returning `(ip, cidr)` or null.
  static (String ip, int cidr)? _parseValidAlias(String rawAlias) {
    final parts = rawAlias.trim().split('/');
    final aliasIp = sanitizeIpOrCidr(parts.first);
    if (!Ipv4Utils.isValidIpv4(aliasIp)) return null;
    final aliasCidr = parts.length > 1 ? int.tryParse(parts[1]) ?? 24 : 24;
    if (aliasCidr < 1 || aliasCidr > 32) return null;
    return (aliasIp, aliasCidr);
  }

  /// Generates the deterministic OS CLI command list for a given platform, NIC, and profile.
  /// Always targets [nic] consistently (never mixing `preferredInterface` with `nic.connectionName`).
  List<String> generateCommandsForPlatform({
    required TargetOsPlatform platform,
    required NetworkInterfaceModel nic,
    required IpProfileModel profile,
  }) {
    final ifaceId = sanitizeIdentifier(nic.id);
    final connName = sanitizeIdentifier(nic.connectionName ?? ifaceId);

    String ip = '';
    if (!profile.isDhcp) {
      final rawIp = profile.ipAddress?.trim() ?? '';
      if (!Ipv4Utils.isValidIpv4(rawIp)) {
        throw ArgumentError(
          'Static profile "${profile.name}" requires a valid IPv4 address.',
        );
      }
      ip = sanitizeIpOrCidr(rawIp);
    }

    final cidr =
        profile.cidrPrefix ?? Ipv4Utils.maskToCidr(profile.subnetMask) ?? 24;
    final mask = sanitizeIpOrCidr(
      profile.subnetMask ?? Ipv4Utils.cidrToMask(cidr),
    );
    final gw = (profile.defaultGateway != null &&
            profile.defaultGateway!.trim().isNotEmpty &&
            Ipv4Utils.isValidIpv4(profile.defaultGateway!.trim()))
        ? sanitizeIpOrCidr(profile.defaultGateway!.trim())
        : '';
    final dnsList = profile.dnsServersList
        .where(Ipv4Utils.isValidIpv4)
        .map(sanitizeIpOrCidr)
        .toList();

    switch (platform) {
      case TargetOsPlatform.windows:
        return _generateWindowsCommands(
          ifaceName: connName,
          profile: profile,
          ip: ip,
          mask: mask,
          gw: gw,
          dnsList: dnsList,
        );
      case TargetOsPlatform.macos:
        return _generateMacOsCommands(
          serviceName: connName,
          deviceId: ifaceId,
          profile: profile,
          ip: ip,
          mask: mask,
          gw: gw,
          dnsList: dnsList,
        );
      case TargetOsPlatform.linux:
        return _generateLinuxCommands(
          ifaceId: ifaceId,
          connName: nic.connectionName != null ? connName : null,
          profile: profile,
          ip: ip,
          cidr: cidr,
          gw: gw,
          dnsList: dnsList,
        );
    }
  }

  List<String> _generateWindowsCommands({
    required String ifaceName,
    required IpProfileModel profile,
    required String ip,
    required String mask,
    required String gw,
    required List<String> dnsList,
  }) {
    final cmds = <String>[];
    if (profile.isDhcp) {
      cmds.add(
        'netsh interface ipv4 set address name="$ifaceName" source=dhcp',
      );
      if (dnsList.isEmpty) {
        cmds.add(
          'netsh interface ipv4 set dnsservers name="$ifaceName" source=dhcp',
        );
      } else {
        cmds.add(
          'netsh interface ipv4 set dnsservers name="$ifaceName" static ${dnsList.first} primary',
        );
        for (int i = 1; i < dnsList.length; i++) {
          cmds.add(
            'netsh interface ipv4 add dnsservers name="$ifaceName" ${dnsList[i]} index=${i + 1}',
          );
        }
      }
    } else {
      final gwArg = gw.isNotEmpty ? ' $gw 1' : ' none';
      cmds.add(
        'netsh interface ipv4 set address name="$ifaceName" static $ip $mask$gwArg',
      );
      for (final rawAlias in profile.secondaryIps) {
        final parsed = _parseValidAlias(rawAlias);
        if (parsed != null) {
          final aliasMask = Ipv4Utils.cidrToMask(parsed.$2);
          cmds.add(
            'netsh interface ipv4 add address name="$ifaceName" ${parsed.$1} $aliasMask',
          );
        }
      }
      if (dnsList.isEmpty) {
        cmds.add(
          'netsh interface ipv4 set dnsservers name="$ifaceName" source=dhcp',
        );
      } else {
        cmds.add(
          'netsh interface ipv4 set dnsservers name="$ifaceName" static ${dnsList.first} primary',
        );
        for (int i = 1; i < dnsList.length; i++) {
          cmds.add(
            'netsh interface ipv4 add dnsservers name="$ifaceName" ${dnsList[i]} index=${i + 1}',
          );
        }
      }
    }
    if (profile.mtu != null && profile.mtu! >= 576) {
      cmds.add(
        'netsh interface ipv4 set subinterface "$ifaceName" mtu=${profile.mtu} store=persistent',
      );
    }
    return cmds;
  }

  List<String> _generateMacOsCommands({
    required String serviceName,
    required String deviceId,
    required IpProfileModel profile,
    required String ip,
    required String mask,
    required String gw,
    required List<String> dnsList,
  }) {
    final cmds = <String>[];
    if (profile.isDhcp) {
      cmds.add('networksetup -setdhcp "$serviceName"');
      if (dnsList.isEmpty) {
        cmds.add('networksetup -setdnsservers "$serviceName" "Empty"');
      } else {
        cmds.add(
          'networksetup -setdnsservers "$serviceName" ${dnsList.join(' ')}',
        );
      }
    } else {
      if (gw.isNotEmpty) {
        cmds.add('networksetup -setmanual "$serviceName" $ip $mask $gw');
      } else {
        cmds.add(
          'networksetup -setmanualwithdhcprouter "$serviceName" $ip',
        );
        cmds.add('ifconfig $deviceId inet $ip netmask $mask');
      }
      for (final rawAlias in profile.secondaryIps) {
        final parsed = _parseValidAlias(rawAlias);
        if (parsed != null) {
          final aliasMask = Ipv4Utils.cidrToMask(parsed.$2);
          cmds.add('ifconfig $deviceId alias ${parsed.$1} netmask $aliasMask');
        }
      }
      if (dnsList.isEmpty) {
        cmds.add('networksetup -setdnsservers "$serviceName" "Empty"');
      } else {
        cmds.add(
          'networksetup -setdnsservers "$serviceName" ${dnsList.join(' ')}',
        );
      }
    }
    if (profile.mtu != null && profile.mtu! >= 576) {
      cmds.add('networksetup -setMTU "$serviceName" ${profile.mtu}');
    }
    return cmds;
  }

  List<String> _generateLinuxCommands({
    required String ifaceId,
    required String? connName,
    required IpProfileModel profile,
    required String ip,
    required int cidr,
    required String gw,
    required List<String> dnsList,
  }) {
    final cmds = <String>[];
    final validAliases = <String>[];
    for (final rawAlias in profile.secondaryIps) {
      final parsed = _parseValidAlias(rawAlias);
      if (parsed != null) {
        validAliases.add('${parsed.$1}/${parsed.$2}');
      }
    }

    if (connName != null && connName.isNotEmpty && connName != '--') {
      final mtuProp = ifaceId.startsWith('wl')
          ? '802-11-wireless.mtu'
          : '802-3-ethernet.mtu';
      if (profile.isDhcp) {
        cmds.add(
          'nmcli connection modify "$connName" ipv4.method auto ipv4.addresses "" ipv4.gateway "" ipv4.dns "${dnsList.join(' ')}"',
        );
      } else {
        final allAddrs = <String>[
          '$ip/$cidr',
          ...validAliases,
        ].join(',');
        final gwPart = gw.isNotEmpty ? 'ipv4.gateway "$gw"' : 'ipv4.gateway ""';
        final dnsPart = dnsList.isNotEmpty
            ? 'ipv4.dns "${dnsList.join(' ')}"'
            : 'ipv4.dns ""';
        cmds.add(
          'nmcli connection modify "$connName" ipv4.method manual ipv4.addresses "$allAddrs" $gwPart $dnsPart',
        );
      }
      if (profile.mtu != null && profile.mtu! >= 576) {
        cmds.add(
          'nmcli connection modify "$connName" $mtuProp ${profile.mtu}',
        );
      }
      cmds.add('nmcli connection up "$connName"');
    } else {
      // Direct iproute2 commands
      if (profile.isDhcp) {
        cmds.add(
          '(command -v dhclient >/dev/null 2>&1 && ip addr flush dev $ifaceId && dhclient -r $ifaceId && dhclient $ifaceId) || (command -v dhcpcd >/dev/null 2>&1 && dhcpcd -n $ifaceId) || networkctl reconfigure $ifaceId',
        );
      } else {
        cmds.add('ip addr flush dev $ifaceId');
        cmds.add('ip addr add $ip/$cidr dev $ifaceId');
        for (final alias in validAliases) {
          cmds.add('ip addr add $alias dev $ifaceId');
        }
        cmds.add('ip link set dev $ifaceId up');
        if (gw.isNotEmpty) {
          cmds.add('ip route replace default via $gw dev $ifaceId');
        }
        if (dnsList.isNotEmpty) {
          cmds.add('resolvectl dns $ifaceId ${dnsList.join(' ')}');
        }
        if (profile.mtu != null && profile.mtu! >= 576) {
          cmds.add('ip link set dev $ifaceId mtu ${profile.mtu}');
        }
      }
    }
    return cmds;
  }

  /// Discovers all live network interfaces on the host OS.
  Future<List<NetworkInterfaceModel>> discoverInterfaces() async {
    try {
      if (Platform.isLinux) {
        final linuxNics = await _discoverLinuxInterfaces();
        if (linuxNics.isNotEmpty) return linuxNics;
      } else if (Platform.isMacOS) {
        final macNics = await _discoverMacOsInterfaces();
        if (macNics.isNotEmpty) return macNics;
      } else if (Platform.isWindows) {
        final winNics = await _discoverWindowsInterfaces();
        if (winNics.isNotEmpty) return winNics;
      }
    } catch (_) {}

    // Fallback using dart:io NetworkInterface.list()
    return _discoverDartIoFallbackInterfaces();
  }

  Future<List<NetworkInterfaceModel>> _discoverLinuxInterfaces() async {
    final addrRes = await Process.run('ip', ['-j', 'addr', 'show']);
    if (addrRes.exitCode != 0) return [];

    // Per-device default routes and DHCP route tracking
    final routeMap = <String, String>{};
    final dhcpRouteDevs = <String>{};
    try {
      final routeRes = await Process.run('ip', ['-j', 'route', 'show']);
      if (routeRes.exitCode == 0) {
        final routes = jsonDecode(routeRes.stdout.toString()) as List<dynamic>;
        for (final r in routes) {
          if (r is Map) {
            final dev = r['dev']?.toString();
            final gw = r['gateway']?.toString();
            final proto = r['protocol']?.toString() ?? '';
            if (r['dst'] == 'default' && dev != null && gw != null) {
              routeMap[dev] = gw;
            }
            if (dev != null && proto.contains('dhcp')) {
              dhcpRouteDevs.add(dev);
            }
          }
        }
      }
    } catch (_) {}

    // Map NetworkManager connection names and per-device DNS if nmcli is available
    final nmConnMap = <String, String>{};
    final perIfaceDns = <String, List<String>>{};
    try {
      final nmRes = await Process.run(
        'nmcli',
        ['-t', '-f', 'GENERAL.DEVICE,GENERAL.CONNECTION,IP4.DNS', 'dev', 'show'],
      );
      if (nmRes.exitCode == 0) {
        String? currentDev;
        for (final rawLine in nmRes.stdout.toString().split('\n')) {
          final line = rawLine.trim();
          if (line.startsWith('GENERAL.DEVICE:')) {
            currentDev = line.substring('GENERAL.DEVICE:'.length).trim();
          } else if (line.startsWith('GENERAL.CONNECTION:') &&
              currentDev != null) {
            final conn = line.substring('GENERAL.CONNECTION:'.length).trim();
            if (conn.isNotEmpty && conn != '--') {
              nmConnMap[currentDev] = conn;
            }
          } else if (line.startsWith('IP4.DNS') && currentDev != null) {
            final idx = line.indexOf(':');
            if (idx != -1) {
              final dns = line.substring(idx + 1).trim();
              if (Ipv4Utils.isValidIpv4(dns)) {
                perIfaceDns.putIfAbsent(currentDev, () => []).add(dns);
              }
            }
          }
        }
      }
    } catch (_) {}

    // Fallback DNS servers from /etc/resolv.conf (excluding 127.0.0.53 stub)
    final fallbackDns = <String>[];
    try {
      final resolvFile = File('/etc/resolv.conf');
      if (await resolvFile.exists()) {
        final lines = await resolvFile.readAsLines();
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('nameserver ')) {
            final dns = trimmed.substring('nameserver '.length).trim();
            if (Ipv4Utils.isValidIpv4(dns) && dns != '127.0.0.53') {
              fallbackDns.add(dns);
            }
          }
        }
      }
    } catch (_) {}

    return parseLinuxIpAddrJson(
      addrRes.stdout.toString(),
      routeMap: routeMap,
      dhcpRouteDevs: dhcpRouteDevs,
      nmConnMap: nmConnMap,
      perIfaceDns: perIfaceDns,
      fallbackDns: fallbackDns,
    );
  }

  /// Pure, unit-testable parser for `ip -j addr show` output on Linux.
  static List<NetworkInterfaceModel> parseLinuxIpAddrJson(
    String addrJson, {
    Map<String, String> routeMap = const {},
    Set<String> dhcpRouteDevs = const {},
    Map<String, String> nmConnMap = const {},
    Map<String, List<String>> perIfaceDns = const {},
    List<String> fallbackDns = const [],
  }) {
    final decoded = jsonDecode(addrJson) as List<dynamic>;
    final results = <NetworkInterfaceModel>[];

    for (final item in decoded) {
      if (item is! Map) continue;
      final ifname = item['ifname']?.toString() ?? '';
      if (ifname.isEmpty || ifname == 'lo') continue;

      final flags =
          (item['flags'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final operstate = item['operstate']?.toString().toUpperCase() ?? '';
      final isUp = flags.contains('UP') || operstate == 'UP';
      final mac = (item['address']?.toString() ?? '00:00:00:00:00:00')
          .toUpperCase();
      final mtu = (item['mtu'] as num?)?.toInt();

      String? primaryIp;
      int? primaryCidr;
      bool isDynamic = dhcpRouteDevs.contains(ifname);
      final secondaryIps = <String>[];

      final addrInfo = (item['addr_info'] as List?) ?? [];
      for (final addr in addrInfo) {
        if (addr is Map && addr['family'] == 'inet') {
          final localIp = addr['local']?.toString();
          final prefixLen = (addr['prefixlen'] as num?)?.toInt();
          final dynamicFlag = addr['dynamic'] == true;
          if (localIp != null) {
            if (primaryIp == null) {
              primaryIp = localIp;
              primaryCidr = prefixLen ?? 24;
              if (dynamicFlag) isDynamic = true;
            } else {
              secondaryIps.add('$localIp/${prefixLen ?? 24}');
            }
          }
        }
      }

      final connName = nmConnMap[ifname];
      final displayLabel = connName != null ? '$ifname ($connName)' : ifname;
      final dnsForNic = perIfaceDns[ifname] ?? fallbackDns;

      results.add(
        NetworkInterfaceModel(
          id: ifname,
          displayName: displayLabel,
          connectionName: connName,
          macAddress: mac,
          isUp: isUp,
          isDhcpEnabled: isDynamic,
          currentIp: primaryIp,
          currentCidr: primaryCidr,
          currentSubnet:
              primaryCidr != null ? Ipv4Utils.cidrToMask(primaryCidr) : null,
          currentGateway: routeMap[ifname],
          currentDns: dnsForNic,
          secondaryIps: secondaryIps,
          mtu: mtu,
        ),
      );
    }

    return results;
  }

  /// Pure, unit-testable parser for `networksetup -getinfo <service>` output on macOS.
  static ({String? ip, String? mask, String? gw, bool isDhcp})
      parseMacOsNetworksetupInfo(String out) {
    String? ip;
    String? mask;
    String? gw;
    final isDhcp = out.contains('DHCP Configuration');
    for (final l in out.split('\n')) {
      if (l.startsWith('IP address:')) {
        final v = l.substring('IP address:'.length).trim();
        if (Ipv4Utils.isValidIpv4(v)) ip = v;
      } else if (l.startsWith('Subnet mask:')) {
        final v = l.substring('Subnet mask:'.length).trim();
        if (Ipv4Utils.isValidIpv4(v)) mask = v;
      } else if (l.startsWith('Router:')) {
        final v = l.substring('Router:'.length).trim();
        if (Ipv4Utils.isValidIpv4(v)) gw = v;
      }
    }
    return (ip: ip, mask: mask, gw: gw, isDhcp: isDhcp);
  }

  Future<List<NetworkInterfaceModel>> _discoverMacOsInterfaces() async {
    final hwRes =
        await Process.run('networksetup', ['-listallhardwareports']);
    if (hwRes.exitCode != 0) return [];

    final blocks = hwRes.stdout.toString().split('\n\n');
    final portSpecs = <({String portName, String device, String? mac})>[];
    for (final block in blocks) {
      String? portName;
      String? device;
      String? mac;
      for (final line in block.split('\n')) {
        if (line.startsWith('Hardware Port:')) {
          portName = line.substring('Hardware Port:'.length).trim();
        } else if (line.startsWith('Device:')) {
          device = line.substring('Device:'.length).trim();
        } else if (line.startsWith('Ethernet Address:')) {
          mac = line.substring('Ethernet Address:'.length).trim().toUpperCase();
        }
      }
      if (device != null && device.isNotEmpty && portName != null) {
        portSpecs.add((portName: portName, device: device, mac: mac));
      }
    }

    // Query all hardware ports in parallel
    final results = await Future.wait(
      portSpecs.map((spec) async {
        final responses = await Future.wait([
          Process.run('networksetup', ['-getinfo', spec.portName]),
          Process.run('networksetup', ['-getdnsservers', spec.portName]),
        ]);
        final infoRes = responses[0];
        final dnsRes = responses[1];

        String? ip;
        String? mask;
        String? gw;
        bool isDhcp = true;
        if (infoRes.exitCode == 0) {
          final parsed =
              parseMacOsNetworksetupInfo(infoRes.stdout.toString());
          ip = parsed.ip;
          mask = parsed.mask;
          gw = parsed.gw;
          isDhcp = parsed.isDhcp;
        }

        final dnsList = <String>[];
        if (dnsRes.exitCode == 0) {
          for (final l in dnsRes.stdout.toString().split('\n')) {
            final trimmed = l.trim();
            if (Ipv4Utils.isValidIpv4(trimmed)) dnsList.add(trimmed);
          }
        }

        return NetworkInterfaceModel(
          id: spec.device,
          displayName: '${spec.device} (${spec.portName})',
          connectionName: spec.portName,
          macAddress: spec.mac ?? '00:00:00:00:00:00',
          isUp: ip != null && ip.isNotEmpty,
          isDhcpEnabled: isDhcp,
          currentIp: ip,
          currentSubnet: mask,
          currentCidr: Ipv4Utils.maskToCidr(mask),
          currentGateway: gw,
          currentDns: dnsList,
        );
      }),
    );

    return results;
  }

  Future<List<NetworkInterfaceModel>> _discoverWindowsInterfaces() async {
    const psCmd =
        r'Get-NetIPConfiguration | Select-Object InterfaceAlias,InterfaceIndex,@{Name="IPv4";Expression={$_.IPv4Address.IPAddress}},@{Name="Prefix";Expression={$_.IPv4Address.PrefixLength}},@{Name="Gateway";Expression={$_.IPv4DefaultGateway.NextHop}},@{Name="DNS";Expression={$_.DnsServer.ServerAddresses}},@{Name="Status";Expression={$_.NetAdapter.Status}},@{Name="Mac";Expression={$_.NetAdapter.MacAddress}},@{Name="Dhcp";Expression={$_.NetIPv4Interface.Dhcp}} | ConvertTo-Json';
    final res = await Process.run(
      'powershell',
      ['-NoProfile', '-Command', psCmd],
    );
    if (res.exitCode != 0) return [];
    final raw = res.stdout.toString().trim();
    if (raw.isEmpty) return [];
    return parseWindowsNetIpJson(raw);
  }

  /// Pure, unit-testable parser for Windows `Get-NetIPConfiguration | ConvertTo-Json` output.
  static List<NetworkInterfaceModel> parseWindowsNetIpJson(String rawJson) {
    final decoded = jsonDecode(rawJson);
    final items = decoded is List ? decoded : [decoded];
    final results = <NetworkInterfaceModel>[];

    for (final item in items) {
      if (item is! Map) continue;
      final alias = item['InterfaceAlias']?.toString() ?? 'Ethernet';
      final mac = (item['Mac']?.toString() ?? '00-00-00-00-00-00')
          .replaceAll('-', ':')
          .toUpperCase();
      final status = item['Status']?.toString() ?? 'Up';
      final dhcpStr = item['Dhcp']?.toString() ?? 'Enabled';

      String? primaryIp;
      final rawIp = item['IPv4'];
      if (rawIp is List && rawIp.isNotEmpty) {
        primaryIp = rawIp.first.toString();
      } else if (rawIp is String) {
        primaryIp = rawIp;
      }

      int? cidr;
      final rawPrefix = item['Prefix'];
      if (rawPrefix is List && rawPrefix.isNotEmpty) {
        cidr = int.tryParse(rawPrefix.first.toString());
      } else if (rawPrefix != null) {
        cidr = int.tryParse(rawPrefix.toString());
      }

      String? gw;
      final rawGw = item['Gateway'];
      if (rawGw is List && rawGw.isNotEmpty) {
        gw = rawGw.first.toString();
      } else if (rawGw is String) {
        gw = rawGw;
      }

      final dns = <String>[];
      final rawDns = item['DNS'];
      if (rawDns is List) {
        for (final d in rawDns) {
          final ds = d.toString();
          if (Ipv4Utils.isValidIpv4(ds)) dns.add(ds);
        }
      }

      results.add(
        NetworkInterfaceModel(
          id: alias,
          displayName: alias,
          connectionName: alias,
          macAddress: mac,
          isUp: status.toLowerCase() == 'up',
          isDhcpEnabled: dhcpStr.toLowerCase().contains('enabled') ||
              dhcpStr == '1',
          currentIp: primaryIp,
          currentCidr: cidr,
          currentSubnet: cidr != null ? Ipv4Utils.cidrToMask(cidr) : null,
          currentGateway: gw,
          currentDns: dns,
        ),
      );
    }
    return results;
  }

  Future<List<NetworkInterfaceModel>> _discoverDartIoFallbackInterfaces() async {
    final ioInterfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    return ioInterfaces.map((nic) {
      final ip = nic.addresses.isNotEmpty ? nic.addresses.first.address : null;
      return NetworkInterfaceModel(
        id: nic.name,
        displayName: nic.name,
        connectionName: nic.name,
        macAddress: '—',
        isUp: ip != null,
        isDhcpEnabled: false,
        currentIp: ip,
      );
    }).toList();
  }

  /// Executes the generated CLI commands on the host OS (with elevation if needed).
  Future<CommandRunResult> executeCommands({
    required List<String> commands,
    required bool isAlreadyElevated,
    required bool dryRun,
  }) async {
    if (commands.isEmpty) {
      return const CommandRunResult(
        exitCode: 0,
        stdout: 'No commands required.',
        stderr: '',
        executedCommands: [],
      );
    }

    if (dryRun) {
      return CommandRunResult(
        exitCode: 0,
        stdout:
            '[SIMULATION / DRY-RUN MODE] Verified ${commands.length} command(s) cleanly without modifying host OS adapter:\n${commands.map((c) => '  \$ $c').join('\n')}',
        stderr: '',
        executedCommands: commands,
      );
    }

    if (Platform.isWindows && !isAlreadyElevated) {
      return _executeWindowsElevatedBatch(commands);
    }

    final combinedScript = commands.join(' && ');
    try {
      Process process;
      if (Platform.isWindows) {
        process = await Process.start('cmd', ['/c', combinedScript]);
      } else if (Platform.isMacOS) {
        if (isAlreadyElevated) {
          process = await Process.start('sh', ['-c', combinedScript]);
        } else {
          final escaped = combinedScript
              .replaceAll('\\', '\\\\')
              .replaceAll('"', '\\"');
          process = await Process.start('osascript', [
            '-e',
            'do shell script "$escaped" with administrator privileges',
          ]);
        }
      } else {
        // Linux
        if (isAlreadyElevated) {
          process = await Process.start('sh', ['-c', combinedScript]);
        } else {
          process = await Process.start('pkexec', ['sh', '-c', combinedScript]);
        }
      }

      _activeProcesses.add(process);
      final stdoutFuture = process.stdout.transform(utf8.decoder).join();
      final stderrFuture = process.stderr.transform(utf8.decoder).join();
      final exitCode = await process.exitCode;
      _activeProcesses.remove(process);

      final outStr = (await stdoutFuture).trim();
      final errStr = (await stderrFuture).trim();

      return CommandRunResult(
        exitCode: exitCode,
        stdout: outStr.isEmpty && exitCode == 0
            ? 'Successfully executed ${commands.length} command(s).'
            : outStr,
        stderr: errStr,
        executedCommands: commands,
      );
    } catch (e) {
      return CommandRunResult(
        exitCode: 1,
        stdout: '',
        stderr: 'Failed to invoke OS network command runner: $e',
        executedCommands: commands,
      );
    }
  }

  /// Writes a temporary `.cmd` script on Windows, launches it elevated via `Start-Process -Verb RunAs -Wait -PassThru`,
  /// captures the real child exit code and redirected output logs, and cleans up temp files.
  Future<CommandRunResult> _executeWindowsElevatedBatch(
    List<String> commands,
  ) async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final tempDir = Directory.systemTemp;
    final cmdFile = File(p.join(tempDir.path, 'ip_setter_$stamp.cmd'));
    final outFile = File(p.join(tempDir.path, 'ip_setter_out_$stamp.log'));
    final errFile = File(p.join(tempDir.path, 'ip_setter_err_$stamp.log'));

    final buffer = StringBuffer('@echo off\r\n');
    for (final c in commands) {
      buffer.writeln(
        '$c >> "${outFile.path}" 2>> "${errFile.path}"',
      );
      buffer.writeln('if %errorlevel% neq 0 exit /b %errorlevel%');
    }
    buffer.writeln('exit /b 0');

    try {
      await cmdFile.writeAsString(buffer.toString(), flush: true);
      final psScript =
          "\$p = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c \"${cmdFile.path}\"' -Verb RunAs -Wait -PassThru -WindowStyle Hidden; if (\$null -eq \$p) { exit 1223 } else { exit \$p.ExitCode }";
      final process = await Process.start('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        psScript,
      ]);
      _activeProcesses.add(process);
      final psErrFuture = process.stderr.transform(utf8.decoder).join();
      final exitCode = await process.exitCode;
      _activeProcesses.remove(process);

      final psErr = (await psErrFuture).trim();
      final outStr =
          await outFile.exists() ? (await outFile.readAsString()).trim() : '';
      final errStr =
          await errFile.exists() ? (await errFile.readAsString()).trim() : '';
      final combinedErr = [
        if (errStr.isNotEmpty) errStr,
        if (psErr.isNotEmpty) psErr,
      ].join('\n');

      return CommandRunResult(
        exitCode: exitCode,
        stdout: outStr.isEmpty && exitCode == 0
            ? 'Successfully executed ${commands.length} command(s).'
            : outStr,
        stderr: combinedErr,
        executedCommands: commands,
      );
    } catch (e) {
      return CommandRunResult(
        exitCode: 1,
        stdout: '',
        stderr: 'Failed to run elevated Windows network script: $e',
        executedCommands: commands,
      );
    } finally {
      for (final f in [cmdFile, outFile, errFile]) {
        try {
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    }
  }
}
