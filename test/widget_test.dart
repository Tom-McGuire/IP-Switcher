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
import 'package:provider/provider.dart';

void main() {
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

  group('NicBackendService Command Generation Tests', () {
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

    test('generates Linux nmcli commands', () {
      final cmds = backend.generateCommandsForPlatform(
        platform: TargetOsPlatform.linux,
        nic: testNic,
        profile: staticProfile,
      );
      expect(cmds.first, contains('nmcli connection modify'));
      expect(cmds.first, contains('192.168.1.50/24'));
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
    expect(find.text('NIC QUICK-CONFIG'), findsOneWidget);
    expect(find.text('Quick DHCP'), findsOneWidget);
  });
}
