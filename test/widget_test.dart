import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ip_setter/data/repositories/nic_repository.dart';
import 'package:ip_setter/data/repositories/profile_repository.dart';
import 'package:ip_setter/data/services/database_service.dart';
import 'package:ip_setter/data/services/gateway_ping_service.dart';
import 'package:ip_setter/data/services/nic_backend_service.dart';
import 'package:ip_setter/domain/models/ip_profile_model.dart';
import 'package:ip_setter/domain/models/ipv4_utils.dart';
import 'package:ip_setter/domain/models/network_interface_model.dart';
import 'package:ip_setter/theme/app_theme.dart';
import 'package:ip_setter/ui/view_models/ip_setter_view_model.dart';
import 'package:ip_setter/ui/views/main_screen.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('Ipv4Utils Tests', () {
    test('validates IPv4 addresses and converts CIDR <-> Subnet Mask', () {
      expect(Ipv4Utils.isValidIpv4('192.168.1.50'), isTrue);
      expect(Ipv4Utils.isValidIpv4('10.0.0.100'), isTrue);
      expect(Ipv4Utils.isValidIpv4('999.1.1.1'), isFalse);

      expect(Ipv4Utils.cidrToMask(24), equals('255.255.255.0'));
      expect(Ipv4Utils.cidrToMask(8), equals('255.0.0.0'));
      expect(Ipv4Utils.maskToCidr('255.255.255.0'), equals(24));
      expect(Ipv4Utils.maskToCidr('255.0.0.0'), equals(8));
      expect(Ipv4Utils.maskToCidr('255.0.255.0'), isNull);
    });

    test('computes usable subnet host range', () {
      final desc = Ipv4Utils.describeSubnetRange('192.168.1.50', 24);
      expect(desc, contains('192.168.1.0/24'));
      expect(desc, contains('192.168.1.1 – 192.168.1.254'));
    });
  });

  group('IpProfileModel & Validation Tests', () {
    test('copyWith clears nullable fields when clear flags are set', () {
      final original = IpProfileModel(
        id: 'p1',
        name: 'Lab Static',
        category: 'LAB',
        isDhcp: false,
        ipAddress: '192.168.1.50',
        defaultGateway: '192.168.1.1',
        primaryDns: '1.1.1.1',
        lastAppliedAt: DateTime(2026, 11, 5),
      );

      final cleared = original.copyWith(
        clearDefaultGateway: true,
        clearPrimaryDns: true,
        clearLastAppliedAt: true,
      );

      expect(cleared.defaultGateway, isNull);
      expect(cleared.primaryDns, isNull);
      expect(cleared.lastAppliedAt, isNull);
      expect(cleared.ipAddress, equals('192.168.1.50'));
    });

    test('validate rejects invalid static IP, alias IP, and MTU', () {
      const missingIp = IpProfileModel(
        id: 'p2',
        name: 'Broken Static',
        category: 'LAB',
        isDhcp: false,
      );
      expect(missingIp.validate(), isNotNull);

      const badAlias = IpProfileModel(
        id: 'p3',
        name: 'Bad Alias',
        category: 'LAB',
        isDhcp: false,
        ipAddress: '192.168.1.50',
        secondaryIps: ['999.999.1.1/24'],
      );
      expect(badAlias.validate(), contains('secondary alias'));

      const badMtu = IpProfileModel(
        id: 'p4',
        name: 'Bad MTU',
        category: 'LAB',
        isDhcp: true,
        mtu: 100,
      );
      expect(badMtu.validate(), contains('MTU'));
    });
  });

  group('NicBackendService Command Generation & Discovery Parser Tests', () {
    final backend = NicBackendService();
    const testNic = NetworkInterfaceModel(
      id: 'eth0',
      displayName: 'eth0 (Wired connection 1)',
      connectionName: 'Wired connection 1',
      macAddress: '00:1A:2B:3C:4D:5E',
      isUp: true,
      isDhcpEnabled: true,
      currentIp: '192.168.1.120',
      currentCidr: 24,
      currentSubnet: '255.255.255.0',
      currentGateway: '192.168.1.1',
    );

    const staticProfile = IpProfileModel(
      id: 'test-static',
      name: 'Lab Static',
      category: 'LAB',
      isDhcp: false,
      ipAddress: '192.168.1.50',
      subnetMask: '255.255.255.0',
      cidrPrefix: 24,
      defaultGateway: '192.168.1.1',
      primaryDns: '1.1.1.1',
      secondaryDns: '8.8.8.8',
    );

    test('generates Windows netsh commands', () {
      final cmds = backend.generateCommandsForPlatform(
        platform: TargetOsPlatform.windows,
        nic: testNic,
        profile: staticProfile,
      );
      expect(
        cmds.first,
        contains(
          'netsh interface ipv4 set address name="Wired connection 1" static 192.168.1.50 255.255.255.0 192.168.1.1',
        ),
      );
      expect(cmds.length, greaterThanOrEqualTo(2));
    });

    test('generates macOS networksetup commands', () {
      final cmds = backend.generateCommandsForPlatform(
        platform: TargetOsPlatform.macos,
        nic: testNic,
        profile: staticProfile,
      );
      expect(
        cmds.first,
        equals(
          'networksetup -setmanual "Wired connection 1" 192.168.1.50 255.255.255.0 192.168.1.1',
        ),
      );
    });

    test('generates Linux nmcli commands and preserves non-ASCII connection names', () {
      const unicodeNic = NetworkInterfaceModel(
        id: 'wlan0',
        displayName: 'wlan0 (Conexión Wi-Fi)',
        connectionName: 'Conexión Wi-Fi',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        isUp: true,
        isDhcpEnabled: true,
      );
      final cmds = backend.generateCommandsForPlatform(
        platform: TargetOsPlatform.linux,
        nic: unicodeNic,
        profile: staticProfile.copyWith(mtu: 1480),
      );
      expect(cmds.first, contains('nmcli connection modify "Conexión Wi-Fi"'));
      expect(cmds.first, contains('192.168.1.50/24'));
      expect(cmds[1], contains('802-11-wireless.mtu 1480'));
    });

    test('throws ArgumentError when static profile has null IPv4', () {
      const invalidStatic = IpProfileModel(
        id: 'missing-ip',
        name: 'No IP',
        category: 'LAB',
        isDhcp: false,
      );
      expect(
        () => backend.generateCommandsForPlatform(
          platform: TargetOsPlatform.linux,
          nic: testNic,
          profile: invalidStatic,
        ),
        throwsArgumentError,
      );
    });

    test('parses Linux ip -j addr show JSON with per-device DHCP and DNS', () {
      const sampleJson = '''
      [
        {
          "ifname": "eth0",
          "flags": ["BROADCAST", "MULTICAST", "UP", "LOWER_UP"],
          "operstate": "UP",
          "address": "00:11:22:33:44:55",
          "mtu": 1500,
          "addr_info": [
            {"family": "inet", "local": "192.168.1.50", "prefixlen": 24, "dynamic": false}
          ]
        },
        {
          "ifname": "wlan0",
          "flags": ["BROADCAST", "MULTICAST", "UP", "LOWER_UP"],
          "operstate": "UP",
          "address": "aa:bb:cc:dd:ee:ff",
          "mtu": 1500,
          "addr_info": [
            {"family": "inet", "local": "10.0.0.42", "prefixlen": 24, "dynamic": true}
          ]
        }
      ]
      ''';

      final parsed = NicBackendService.parseLinuxIpAddrJson(
        sampleJson,
        routeMap: {'eth0': '192.168.1.1', 'wlan0': '10.0.0.1'},
        dhcpRouteDevs: {'wlan0'},
        nmConnMap: {'eth0': 'Lab Wired', 'wlan0': 'Office Wi-Fi'},
        perIfaceDns: {
          'eth0': ['1.1.1.1'],
          'wlan0': ['10.0.0.1'],
        },
      );

      expect(parsed.length, equals(2));
      expect(parsed[0].id, equals('eth0'));
      expect(parsed[0].isDhcpEnabled, isFalse);
      expect(parsed[0].currentDns, equals(['1.1.1.1']));
      expect(parsed[1].id, equals('wlan0'));
      expect(parsed[1].isDhcpEnabled, isTrue);
      expect(parsed[1].currentDns, equals(['10.0.0.1']));
    });

    test('parses macOS networksetup -getinfo and Windows Get-NetIPConfiguration JSON', () {
      const macInfo = '''
DHCP Configuration
IP address: 192.168.10.22
Subnet mask: 255.255.255.0
Router: 192.168.10.1
''';
      final macParsed = NicBackendService.parseMacOsNetworksetupInfo(macInfo);
      expect(macParsed.isDhcp, isTrue);
      expect(macParsed.ip, equals('192.168.10.22'));
      expect(macParsed.gw, equals('192.168.10.1'));

      const winJson = '''
      {
        "InterfaceAlias": "Ethernet 2",
        "IPv4": ["172.16.20.50"],
        "Prefix": [24],
        "Gateway": ["172.16.20.1"],
        "DNS": ["1.1.1.1", "8.8.8.8"],
        "Status": "Up",
        "Mac": "00-1A-2B-3C-4D-5E",
        "Dhcp": "Disabled"
      }
      ''';
      final winParsed = NicBackendService.parseWindowsNetIpJson(winJson);
      expect(winParsed.single.id, equals('Ethernet 2'));
      expect(winParsed.single.isDhcpEnabled, isFalse);
      expect(winParsed.single.currentIp, equals('172.16.20.50'));
    });
  });

  group('Database Migration, Snapshot & Sorting Tests', () {
    test('DB v1 -> v3 migration deletes only the 8 seeded IDs and preserves user presets', () async {
      final tempDir = await Directory.systemTemp.createTemp('ip_setter_mig_test_');
      final dbPath = p.join(tempDir.path, 'mig_test.db');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      // Create a v1 database with one legacy seeded ID and one user-created preset-<timestamp> ID
      final v1Db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute('''
              CREATE TABLE profiles (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                category TEXT NOT NULL,
                is_dhcp INTEGER NOT NULL,
                ip_address TEXT,
                subnet_mask TEXT,
                cidr_prefix INTEGER,
                default_gateway TEXT,
                primary_dns TEXT,
                secondary_dns TEXT,
                secondary_ips TEXT,
                preferred_interface TEXT,
                vlan_id INTEGER,
                mtu INTEGER,
                notes TEXT,
                is_favorite INTEGER NOT NULL DEFAULT 0,
                last_applied_at TEXT
              )
            ''');
            await db.insert('profiles', const IpProfileModel(
              id: 'preset-lab-static',
              name: 'Lab Static',
              category: 'LAB',
              isDhcp: false,
              ipAddress: '192.168.1.50',
            ).toMap());
            await db.insert('profiles', const IpProfileModel(
              id: 'preset-1730000000123',
              name: 'My Custom User Preset',
              category: 'CUSTOM',
              isDhcp: false,
              ipAddress: '10.20.30.40',
            ).toMap());
          },
        ),
      );
      await v1Db.close();

      // Open with DatabaseService (version 3) and verify migration
      final dbService = DatabaseService(overridePath: dbPath);
      final profiles = await dbService.getAllProfiles();
      final categories = await dbService.getAllCategories();
      await dbService.close();

      expect(profiles.map((p) => p.id), contains('preset-1730000000123'));
      expect(profiles.map((p) => p.id), isNot(contains('preset-lab-static')));
      expect(categories.length, greaterThanOrEqualTo(5));
    });

    test('createSnapshotProfileFromNic leaves DNS null for DHCP adapters', () {
      final nicRepo = NicRepository(NicBackendService(), GatewayPingService());
      const dhcpNic = NetworkInterfaceModel(
        id: 'eth0',
        displayName: 'eth0',
        macAddress: '00:11:22:33:44:55',
        isUp: true,
        isDhcpEnabled: true,
        currentIp: '192.168.1.120',
        currentDns: ['192.168.1.1', '8.8.8.8'],
      );
      final snap = nicRepo.createSnapshotProfileFromNic(dhcpNic);
      expect(snap.isDhcp, isTrue);
      expect(snap.primaryDns, isNull);
      expect(snap.secondaryDns, isNull);
    });

    test('numeric IPv4 sorting orders 10.0.0.2 before 10.0.0.10', () async {
      final tempDir = await Directory.systemTemp.createTemp('ip_setter_sort_test_');
      final dbPath = p.join(tempDir.path, 'sort_test.db');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final repo = ProfileRepository(DatabaseService(overridePath: dbPath));
      await repo.saveProfile(const IpProfileModel(
        id: 'p-10',
        name: 'Host 10',
        category: 'LAB',
        isDhcp: false,
        ipAddress: '10.0.0.10',
      ));
      await repo.saveProfile(const IpProfileModel(
        id: 'p-2',
        name: 'Host 2',
        category: 'LAB',
        isDhcp: false,
        ipAddress: '10.0.0.2',
      ));

      final vm = IpSetterViewModel(
        profileRepository: repo,
        nicRepository: NicRepository(NicBackendService(), GatewayPingService()),
      );
      await vm.initialize();
      vm.setSortColumn(ProfileSortColumn.ipAddress);

      final sortedIps = vm.filteredProfiles.map((p) => p.ipAddress).toList();
      expect(sortedIps, equals(['10.0.0.2', '10.0.0.10']));
      await vm.stopAllServices();
    });
  });

  testWidgets('Renders 5-Tier IP Profile Switcher Desktop UI', (tester) async {
    tester.view.physicalSize = const Size(1400, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final vm = IpSetterViewModel(
      profileRepository: ProfileRepository(DatabaseService()),
      nicRepository: NicRepository(NicBackendService(), GatewayPingService()),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<IpSetterViewModel>.value(
        value: vm,
        child: MaterialApp(
          theme: AppTheme.darkTheme(),
          home: const MainScreen(),
        ),
      ),
    );

    expect(find.text('IP Profile Switcher'), findsOneWidget);
    expect(find.text('New Preset'), findsOneWidget);
    expect(find.text('Quick DHCP'), findsOneWidget);
    expect(find.text('Demo Presets'), findsOneWidget);
    expect(find.text('Dry-Run Mode'), findsOneWidget);
  });
}
