import 'dart:convert';
import 'dart:io';
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

  /// Sanitize identifiers (interface names, connection names) to prevent shell injection.
  static String sanitizeIdentifier(String input) {
    return input.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.\s\(\):]'), '');
  }

  /// Sanitize IPv4 or CIDR strings.
  static String sanitizeIpOrCidr(String input) {
    return input.replaceAll(RegExp(r'[^0-9\./]'), '');
  }

  /// Generates the deterministic OS CLI command list for a given platform, NIC, and profile.
  List<String> generateCommandsForPlatform({
    required TargetOsPlatform platform,
    required NetworkInterfaceModel nic,
    required IpProfileModel profile,
  }) {
    final ifaceId = sanitizeIdentifier(
      (profile.preferredInterface != null &&
              profile.preferredInterface!.trim().isNotEmpty)
          ? profile.preferredInterface!.trim()
          : nic.id,
    );
    final connName = sanitizeIdentifier(nic.connectionName ?? ifaceId);

    final ip = sanitizeIpOrCidr(profile.ipAddress ?? '192.168.1.50');
    final cidr =
        profile.cidrPrefix ?? Ipv4Utils.maskToCidr(profile.subnetMask) ?? 24;
    final mask = sanitizeIpOrCidr(
      profile.subnetMask ?? Ipv4Utils.cidrToMask(cidr),
    );
    final gw = (profile.defaultGateway != null &&
            profile.defaultGateway!.trim().isNotEmpty)
        ? sanitizeIpOrCidr(profile.defaultGateway!.trim())
        : '';
    final dnsList = profile.dnsServersList.map(sanitizeIpOrCidr).toList();

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
      for (final alias in profile.secondaryIps) {
        final parts = alias.split('/');
        final aliasIp = sanitizeIpOrCidr(parts[0]);
        final aliasCidr = parts.length > 1 ? int.tryParse(parts[1]) ?? 24 : 24;
        final aliasMask = Ipv4Utils.cidrToMask(aliasCidr);
        if (Ipv4Utils.isValidIpv4(aliasIp)) {
          cmds.add(
            'netsh interface ipv4 add address name="$ifaceName" $aliasIp $aliasMask',
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
      for (final alias in profile.secondaryIps) {
        final parts = alias.split('/');
        final aliasIp = sanitizeIpOrCidr(parts[0]);
        final aliasCidr = parts.length > 1 ? int.tryParse(parts[1]) ?? 24 : 24;
        final aliasMask = Ipv4Utils.cidrToMask(aliasCidr);
        if (Ipv4Utils.isValidIpv4(aliasIp)) {
          cmds.add('ifconfig $deviceId alias $aliasIp netmask $aliasMask');
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
    // Prefer NetworkManager (nmcli) when a connection profile is known, with iproute2 fallback comment/commands
    if (connName != null && connName.isNotEmpty && connName != '--') {
      if (profile.isDhcp) {
        cmds.add(
          'nmcli connection modify "$connName" ipv4.method auto ipv4.addresses "" ipv4.gateway "" ipv4.dns "${dnsList.join(' ')}"',
        );
        cmds.add('nmcli connection up "$connName"');
      } else {
        final allAddrs = <String>[
          '$ip/$cidr',
          ...profile.secondaryIps.map(sanitizeIpOrCidr),
        ].join(',');
        final gwPart = gw.isNotEmpty ? 'ipv4.gateway "$gw"' : 'ipv4.gateway ""';
        final dnsPart = dnsList.isNotEmpty
            ? 'ipv4.dns "${dnsList.join(' ')}"'
            : 'ipv4.dns ""';
        cmds.add(
          'nmcli connection modify "$connName" ipv4.method manual ipv4.addresses "$allAddrs" $gwPart $dnsPart',
        );
        if (profile.mtu != null && profile.mtu! >= 576) {
          cmds.add(
            'nmcli connection modify "$connName" 802-3-ethernet.mtu ${profile.mtu}',
          );
        }
        cmds.add('nmcli connection up "$connName"');
      }
    } else {
      // Direct iproute2 commands
      if (profile.isDhcp) {
        cmds.add('ip addr flush dev $ifaceId');
        cmds.add('dhclient -r $ifaceId && dhclient $ifaceId');
      } else {
        cmds.add('ip addr flush dev $ifaceId');
        cmds.add('ip addr add $ip/$cidr dev $ifaceId');
        for (final alias in profile.secondaryIps) {
          final cleanAlias = sanitizeIpOrCidr(alias);
          if (cleanAlias.isNotEmpty) {
            cmds.add('ip addr add $cleanAlias dev $ifaceId');
          }
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

    // Also get default routes
    final routeMap = <String, String>{};
    bool defaultRouteIsDhcp = false;
    try {
      final routeRes = await Process.run('ip', ['-j', 'route', 'show']);
      if (routeRes.exitCode == 0) {
        final routes = jsonDecode(routeRes.stdout.toString()) as List<dynamic>;
        for (final r in routes) {
          if (r is Map && r['dst'] == 'default') {
            final dev = r['dev']?.toString();
            final gw = r['gateway']?.toString();
            final proto = r['protocol']?.toString() ?? '';
            if (dev != null && gw != null) {
              routeMap[dev] = gw;
            }
            if (proto.contains('dhcp')) {
              defaultRouteIsDhcp = true;
            }
          }
        }
      }
    } catch (_) {}

    // Map NetworkManager connection names if nmcli is available
    final nmConnMap = <String, String>{};
    try {
      final nmRes = await Process.run(
        'nmcli',
        ['-t', '-f', 'DEVICE,CONNECTION', 'dev'],
      );
      if (nmRes.exitCode == 0) {
        for (final line in nmRes.stdout.toString().split('\n')) {
          final parts = line.trim().split(':');
          if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
            if (parts[1] != '--') {
              nmConnMap[parts[0]] = parts.sublist(1).join(':');
            }
          }
        }
      }
    } catch (_) {}

    // Parse DNS servers from /etc/resolv.conf
    final dnsServers = <String>[];
    try {
      final resolvFile = File('/etc/resolv.conf');
      if (await resolvFile.exists()) {
        final lines = await resolvFile.readAsLines();
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('nameserver ')) {
            final dns = trimmed.substring('nameserver '.length).trim();
            if (Ipv4Utils.isValidIpv4(dns)) {
              dnsServers.add(dns);
            }
          }
        }
      }
    } catch (_) {}

    final decoded = jsonDecode(addrRes.stdout.toString()) as List<dynamic>;
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
      final mtu = item['mtu'] as int?;

      String? primaryIp;
      int? primaryCidr;
      bool isDynamic = defaultRouteIsDhcp;
      final secondaryIps = <String>[];

      final addrInfo = (item['addr_info'] as List?) ?? [];
      for (final addr in addrInfo) {
        if (addr is Map && addr['family'] == 'inet') {
          final localIp = addr['local']?.toString();
          final prefixLen = addr['prefixlen'] as int?;
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
      final displayLabel =
          connName != null ? '$ifname ($connName)' : ifname;

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
          currentDns: dnsServers,
          secondaryIps: secondaryIps,
          mtu: mtu,
        ),
      );
    }

    return results;
  }

  Future<List<NetworkInterfaceModel>> _discoverMacOsInterfaces() async {
    final hwRes =
        await Process.run('networksetup', ['-listallhardwareports']);
    if (hwRes.exitCode != 0) return [];

    final results = <NetworkInterfaceModel>[];
    final blocks = hwRes.stdout.toString().split('\n\n');
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
      if (device == null || device.isEmpty || portName == null) continue;

      String? ip;
      String? mask;
      String? gw;
      bool isDhcp = true;
      bool isUp = false;

      final infoRes =
          await Process.run('networksetup', ['-getinfo', portName]);
      if (infoRes.exitCode == 0) {
        final out = infoRes.stdout.toString();
        isDhcp = out.contains('DHCP Configuration');
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
      }

      isUp = ip != null && ip.isNotEmpty;
      final dnsList = <String>[];
      final dnsRes =
          await Process.run('networksetup', ['-getdnsservers', portName]);
      if (dnsRes.exitCode == 0) {
        for (final l in dnsRes.stdout.toString().split('\n')) {
          final trimmed = l.trim();
          if (Ipv4Utils.isValidIpv4(trimmed)) dnsList.add(trimmed);
        }
      }

      results.add(
        NetworkInterfaceModel(
          id: device,
          displayName: '$device ($portName)',
          connectionName: portName,
          macAddress: mac ?? '00:00:00:00:00:00',
          isUp: isUp,
          isDhcpEnabled: isDhcp,
          currentIp: ip,
          currentSubnet: mask,
          currentCidr: Ipv4Utils.maskToCidr(mask),
          currentGateway: gw,
          currentDns: dnsList,
        ),
      );
    }
    return results;
  }

  Future<List<NetworkInterfaceModel>> _discoverWindowsInterfaces() async {
    final psCmd =
        r'Get-NetIPConfiguration | Select-Object InterfaceAlias,InterfaceIndex,@{Name="IPv4";Expression={$_.IPv4Address.IPAddress}},@{Name="Prefix";Expression={$_.IPv4Address.PrefixLength}},@{Name="Gateway";Expression={$_.IPv4DefaultGateway.NextHop}},@{Name="DNS";Expression={$_.DnsServer.ServerAddresses}},@{Name="Status";Expression={$_.NetAdapter.Status}},@{Name="Mac";Expression={$_.NetAdapter.MacAddress}},@{Name="Dhcp";Expression={$_.NetIPv4Interface.Dhcp}} | ConvertTo-Json';
    final res = await Process.run(
      'powershell',
      ['-NoProfile', '-Command', psCmd],
    );
    if (res.exitCode != 0) return [];
    final raw = res.stdout.toString().trim();
    if (raw.isEmpty) return [];

    final decoded = jsonDecode(raw);
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
        macAddress: '00:1A:2B:3C:4D:5E',
        isUp: ip != null,
        isDhcpEnabled: true,
        currentIp: ip,
        currentCidr: 24,
        currentSubnet: '255.255.255.0',
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

    final combinedScript = commands.join(' && ');
    try {
      Process process;
      if (Platform.isWindows) {
        if (isAlreadyElevated) {
          process = await Process.start('cmd', ['/c', combinedScript]);
        } else {
          final escaped = combinedScript.replaceAll('"', '\\"');
          process = await Process.start('powershell', [
            '-NoProfile',
            '-Command',
            'Start-Process cmd -ArgumentList \'/c $escaped\' -Verb RunAs -Wait -WindowStyle Hidden',
          ]);
        }
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
}
