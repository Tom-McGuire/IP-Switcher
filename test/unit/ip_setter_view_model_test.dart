import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ip_setter/data/repositories/nic_repository.dart';
import 'package:ip_setter/data/repositories/profile_repository.dart';
import 'package:ip_setter/data/services/database_service.dart';
import 'package:ip_setter/data/services/gateway_ping_service.dart';
import 'package:ip_setter/data/services/nic_backend_service.dart';
import 'package:ip_setter/domain/models/ip_profile_model.dart';
import 'package:ip_setter/domain/models/network_interface_model.dart';
import 'package:ip_setter/domain/models/profile_category_model.dart';
import 'package:ip_setter/ui/view_models/ip_setter_view_model.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeNicBackendService extends NicBackendService {
  bool isElevated = true;
  List<NetworkInterfaceModel> fakeNics = [];
  int executeExitCode = 0;
  String executeStdout = 'Success';
  String executeStderr = '';
  List<List<String>> executedCommandHistory = [];

  @override
  Future<bool> checkIsElevated() async => isElevated;

  @override
  Future<List<NetworkInterfaceModel>> discoverInterfaces() async => fakeNics;

  @override
  Future<CommandRunResult> executeCommands({
    required List<String> commands,
    required bool isAlreadyElevated,
    required bool dryRun,
  }) async {
    executedCommandHistory.add(commands);
    if (dryRun) {
      return CommandRunResult(
        exitCode: 0,
        stdout: '[SIMULATION / DRY-RUN MODE]',
        stderr: '',
        executedCommands: commands,
      );
    }
    return CommandRunResult(
      exitCode: executeExitCode,
      stdout: executeStdout,
      stderr: executeStderr,
      executedCommands: commands,
    );
  }
}

class FakeGatewayPingService extends GatewayPingService {
  bool reachable = true;
  double latency = 4.2;

  @override
  Future<GatewayPingResult> pingGateway(String gatewayIp) async {
    return GatewayPingResult(
      gatewayIp: gatewayIp,
      isReachable: reachable,
      latencyMs: latency,
      rawOutput: '64 bytes from $gatewayIp: icmp_seq=1 ttl=64 time=${latency}ms',
    );
  }
}

void main() {
  sqfliteFfiInit();

  group('IpSetterViewModel Tests', () {
    late Directory tempDir;
    late DatabaseService dbService;
    late ProfileRepository profileRepo;
    late FakeNicBackendService fakeBackend;
    late FakeGatewayPingService fakePing;
    late NicRepository nicRepo;
    late IpSetterViewModel viewModel;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('vm_test_');
      final dbPath = p.join(tempDir.path, 'vm_test.db');
      dbService = DatabaseService(overridePath: dbPath);
      profileRepo = ProfileRepository(dbService);
      fakeBackend = FakeNicBackendService();
      fakePing = FakeGatewayPingService();
      nicRepo = NicRepository(fakeBackend, fakePing);

      fakeBackend.fakeNics = [
        const NetworkInterfaceModel(
          id: 'eth0',
          displayName: 'eth0 (Wired)',
          connectionName: 'Wired connection 1',
          macAddress: '00:11:22:33:44:55',
          isUp: true,
          isDhcpEnabled: true,
          currentIp: '192.168.1.100',
          currentSubnet: '255.255.255.0',
          currentCidr: 24,
          currentGateway: '192.168.1.1',
          currentDns: ['1.1.1.1'],
        ),
      ];

      viewModel = IpSetterViewModel(
        profileRepository: profileRepo,
        nicRepository: nicRepo,
      );
      await viewModel.initialize();
    });

    tearDown(() async {
      await viewModel.stopAllServices();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Initializes with default state, interfaces and categories', () {
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.interfaces.length, equals(1));
      expect(viewModel.selectedInterface?.id, equals('eth0'));
      expect(viewModel.categories.length, greaterThanOrEqualTo(5));
      expect(viewModel.dryRunMode, isFalse);
      expect(viewModel.isElevated, isTrue);
    });

    test('Filter logic: mode, category pills, and search query', () async {
      await viewModel.saveProfile(const IpProfileModel(
        id: 'p-dhcp',
        name: 'Office DHCP',
        category: 'OFFICE',
        isDhcp: true,
        notes: 'Corporate DHCP',
      ));
      await viewModel.saveProfile(const IpProfileModel(
        id: 'p-static',
        name: 'Bench Static',
        category: 'LAB',
        isDhcp: false,
        ipAddress: '192.168.1.50',
        subnetMask: '255.255.255.0',
        cidrPrefix: 24,
        isFavorite: true,
        notes: 'Rack 2',
      ));
      await viewModel.saveProfile(const IpProfileModel(
        id: 'p-field',
        name: 'Field Controller',
        category: 'FIELD',
        isDhcp: false,
        ipAddress: '10.0.0.100',
        subnetMask: '255.255.255.0',
        cidrPrefix: 24,
      ));

      expect(viewModel.allProfiles.length, equals(3));
      expect(viewModel.filteredProfiles.length, equals(3));

      // Filter by mode: DHCP
      viewModel.setModeFilter('DHCP');
      expect(viewModel.filteredProfiles.length, equals(1));
      expect(viewModel.filteredProfiles.first.id, equals('p-dhcp'));

      // Filter by mode: FAVORITES
      viewModel.setModeFilter('FAVORITES');
      expect(viewModel.filteredProfiles.length, equals(1));
      expect(viewModel.filteredProfiles.first.id, equals('p-static'));

      // Reset mode
      viewModel.setModeFilter('ALL');
      expect(viewModel.filteredProfiles.length, equals(3));

      // Filter by category pill: LAB
      viewModel.toggleCategoryPill('LAB');
      expect(viewModel.filteredProfiles.length, equals(1));
      expect(viewModel.filteredProfiles.first.id, equals('p-static'));

      // Add category pill: FIELD
      viewModel.toggleCategoryPill('FIELD');
      expect(viewModel.filteredProfiles.length, equals(2));

      // Search query
      viewModel.setSearchQuery('Rack 2');
      expect(viewModel.filteredProfiles.length, equals(1));
      expect(viewModel.filteredProfiles.first.id, equals('p-static'));

      // Clear all filters
      viewModel.clearAllFilters();
      expect(viewModel.filteredProfiles.length, equals(3));
      expect(viewModel.hasActiveFilters, isFalse);
    });

    test('Apply profile success updates state, ping, and logs', () async {
      const targetProfile = IpProfileModel(
        id: 'p-apply',
        name: 'Target Lab Static',
        category: 'LAB',
        isDhcp: false,
        ipAddress: '192.168.1.55',
        subnetMask: '255.255.255.0',
        cidrPrefix: 24,
        defaultGateway: '192.168.1.1',
      );
      await viewModel.saveProfile(targetProfile);

      final success = await viewModel.applyProfile(targetProfile);
      expect(success, isTrue);
      expect(viewModel.bannerIsError, isFalse);
      expect(viewModel.bannerMessage, contains('Applied "Target Lab Static"'));
      expect(viewModel.lastGatewayPing?.isReachable, isTrue);
      expect(viewModel.executionLogs.length, equals(1));
      expect(viewModel.previousNicSnapshot, isNotNull);
      expect(viewModel.previousNicSnapshot?.name, contains('Undo Snapshot'));
    });

    test('Dry run mode does not execute real system commands but simulates state', () async {
      viewModel.toggleDryRunMode(true);
      expect(viewModel.dryRunMode, isTrue);

      const targetProfile = IpProfileModel(
        id: 'p-dry',
        name: 'Simulated Static',
        category: 'FIELD',
        isDhcp: false,
        ipAddress: '10.50.0.10',
        subnetMask: '255.255.255.0',
        cidrPrefix: 24,
      );

      final success = await viewModel.applyProfile(targetProfile);
      expect(success, isTrue);
      expect(viewModel.bannerMessage, contains('[Simulated]'));
      expect(viewModel.selectedInterface?.currentIp, equals('10.50.0.10'));
      // Verified executedCommands in dry run were recorded as simulated in ViewModel log
      expect(viewModel.executionLogs.first.isDryRun, isTrue);
    });

    test('Apply failure triggers automatic rollback attempt and sets error banner', () async {
      fakeBackend.executeExitCode = 1;
      fakeBackend.executeStderr = 'netsh interface failed: Access is denied';

      const targetProfile = IpProfileModel(
        id: 'p-fail',
        name: 'Broken Profile',
        category: 'LAB',
        isDhcp: false,
        ipAddress: '192.168.1.66',
        subnetMask: '255.255.255.0',
        cidrPrefix: 24,
      );

      final success = await viewModel.applyProfile(targetProfile);
      expect(success, isFalse);
      expect(viewModel.bannerIsError, isTrue);
      expect(viewModel.bannerMessage, contains('Failed to apply'));
      expect(viewModel.bannerMessage, contains('rollback'));
      expect(viewModel.inspectorTabIndex, equals(2)); // jumped to logs
    });

    test('Undo last switch re-applies previous snapshot', () async {
      const profileA = IpProfileModel(
        id: 'p-a',
        name: 'Preset A',
        category: 'LAB',
        isDhcp: false,
        ipAddress: '192.168.1.50',
        subnetMask: '255.255.255.0',
        cidrPrefix: 24,
      );
      await viewModel.saveProfile(profileA);
      await viewModel.applyProfile(profileA);

      expect(viewModel.previousNicSnapshot, isNotNull);

      // Trigger undo
      final undoSuccess = await viewModel.undoLastSwitch();
      expect(undoSuccess, isTrue);
    });

    test('Emergency DHCP applies pure DHCP configuration', () async {
      final success = await viewModel.applyEmergencyDhcp();
      expect(success, isTrue);
      expect(viewModel.selectedProfile?.isDhcp, isTrue);
      expect(viewModel.bannerMessage, contains('Applied "Emergency DHCP Reset"'));
    });

    test('Placeholder NIC blocks real execution outside dry-run mode', () async {
      viewModel.selectInterface(const NetworkInterfaceModel(
        id: 'fake-nic',
        displayName: 'Fake Adapter',
        macAddress: '00:00:00:00:00:00',
        isUp: false,
        isDhcpEnabled: true,
        isPlaceholder: true,
      ));

      const profile = IpProfileModel(
        id: 'p1',
        name: 'Some Preset',
        category: 'LAB',
        isDhcp: true,
      );

      final result = await viewModel.applyProfile(profile);
      expect(result, isFalse);
      expect(viewModel.bannerIsError, isTrue);
      expect(viewModel.bannerMessage, contains('Cannot apply'));
    });

    test('Add, update, and delete categories in ViewModel', () async {
      const newCat = ProfileCategoryModel(
        id: 'cat-special',
        name: 'SPECIAL_OPS',
        colorHex: 0xFF990000,
      );

      await viewModel.addOrUpdateCategory(newCat);
      expect(viewModel.categories.any((c) => c.name == 'SPECIAL_OPS'), isTrue);
      expect(viewModel.getCategoryColor('SPECIAL_OPS').toARGB32(), equals(0xFF990000));

      // Toggle visibility
      await viewModel.toggleCategoryVisibility(newCat);
      expect(viewModel.visibleCategories.any((c) => c.id == 'cat-special'), isFalse);

      // Delete
      await viewModel.deleteCategory(newCat);
      expect(viewModel.categories.any((c) => c.id == 'cat-special'), isFalse);
    });

    test('Duplicate and favorite profile operations', () async {
      const original = IpProfileModel(
        id: 'p-orig',
        name: 'Original',
        category: 'LAB',
        isDhcp: true,
      );
      await viewModel.saveProfile(original);
      await viewModel.toggleFavorite(original);

      var p = viewModel.allProfiles.firstWhere((x) => x.id == 'p-orig');
      expect(p.isFavorite, isTrue);

      await viewModel.duplicateProfile(p);
      expect(viewModel.allProfiles.any((x) => x.name == 'Original (Copy)'), isTrue);
    });
  });
}
