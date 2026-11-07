import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ip_setter/data/repositories/nic_repository.dart';
import 'package:ip_setter/data/repositories/profile_repository.dart';
import 'package:ip_setter/data/services/database_service.dart';
import 'package:ip_setter/data/services/gateway_ping_service.dart';
import 'package:ip_setter/data/services/nic_backend_service.dart';
import 'package:ip_setter/domain/models/ip_profile_model.dart';
import 'package:ip_setter/domain/models/network_interface_model.dart';
import 'package:ip_setter/domain/models/profile_category_model.dart';
import 'package:ip_setter/theme/app_theme.dart';
import 'package:ip_setter/ui/view_models/ip_setter_view_model.dart';
import 'package:ip_setter/ui/widgets/bottom_detail_inspector.dart';
import 'package:ip_setter/ui/widgets/profile_data_table.dart';
import 'package:ip_setter/ui/widgets/status_alert_banner.dart';
import 'package:ip_setter/ui/widgets/status_badge.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class TableTestProfileRepository extends ProfileRepository {
  final List<ProfileCategoryModel> _cats = List.from(ProfileCategoryModel.defaultCategories);
  final List<IpProfileModel> _profs = [];

  TableTestProfileRepository() : super(DatabaseService(overridePath: inMemoryDatabasePath));

  @override
  Future<List<ProfileCategoryModel>> loadCategories() async => List.from(_cats);

  @override
  Future<void> saveCategory(ProfileCategoryModel cat, {String? previousName}) async {
    final idx = _cats.indexWhere((c) => c.id == cat.id);
    if (idx != -1) {
      _cats[idx] = cat;
    } else {
      _cats.add(cat);
    }
  }

  @override
  Future<List<IpProfileModel>> loadProfiles() async => List.from(_profs);

  @override
  Future<void> saveProfile(IpProfileModel p) async {
    final idx = _profs.indexWhere((x) => x.id == p.id);
    if (idx != -1) {
      _profs[idx] = p;
    } else {
      _profs.add(p);
    }
  }

  @override
  Future<void> close() async {}
}

class FakeBackendForTable extends NicBackendService {
  @override
  Future<List<NetworkInterfaceModel>> discoverInterfaces() async {
    return [
      const NetworkInterfaceModel(
        id: 'eth0',
        displayName: 'Ethernet Adapter',
        macAddress: 'AA:BB:CC:DD:EE:01',
        isUp: true,
        isDhcpEnabled: false,
        currentIp: '192.168.1.100',
        currentSubnet: '255.255.255.0',
        currentCidr: 24,
        currentGateway: '192.168.1.1',
        currentDns: ['1.1.1.1'],
      ),
    ];
  }
}

void main() {
  sqfliteFfiInit();

  group('StatusBadge & StatusAlertBanner Tests', () {
    testWidgets('StatusBadge renders text and optional icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(
              label: 'Active',
              color: Colors.green,
              icon: Icons.check,
            ),
          ),
        ),
      );
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });

  group('ProfileDataTable & BottomDetailInspector Tests', () {
    late TableTestProfileRepository profileRepo;
    late NicRepository nicRepo;
    late IpSetterViewModel viewModel;

    final testProfile1 = const IpProfileModel(
      id: 'prof-1',
      name: 'PLC Station 01',
      category: 'FIELD',
      isDhcp: false,
      ipAddress: '192.168.1.50',
      subnetMask: '255.255.255.0',
      cidrPrefix: 24,
      defaultGateway: '192.168.1.1',
      primaryDns: '8.8.8.8',
      isFavorite: false,
    );

    final testProfile2 = const IpProfileModel(
      id: 'prof-2',
      name: 'Office Auto DHCP',
      category: 'OFFICE',
      isDhcp: true,
      isFavorite: true,
    );

    setUp(() async {
      profileRepo = TableTestProfileRepository();
      await profileRepo.saveProfile(testProfile1);
      await profileRepo.saveProfile(testProfile2);

      nicRepo = NicRepository(FakeBackendForTable(), GatewayPingService());
      viewModel = IpSetterViewModel(
        profileRepository: profileRepo,
        nicRepository: nicRepo,
      );
      await viewModel.initialize();
      await viewModel.stopAllServices();
    });

    Widget createTestApp(Widget child) {
      return ChangeNotifierProvider<IpSetterViewModel>.value(
        value: viewModel,
        child: MaterialApp(
          theme: AppTheme.darkTheme(),
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('ProfileDataTable renders rows, selects profile, and sorts', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          ProfileDataTable(
            onEditProfile: (p) {},
            onNewProfile: () {},
            onSnapshotActiveNic: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check profiles are visible
      expect(find.text('PLC Station 01'), findsOneWidget);
      expect(find.text('Office Auto DHCP'), findsOneWidget);

      // Tap on row 1 to select
      await tester.tap(find.text('PLC Station 01'));
      await tester.pumpAndSettle();
      expect(viewModel.selectedProfile?.id, equals('prof-1'));

      // Sort by clicking Header Column
      await tester.tap(find.text('PROFILE PRESET'));
      await tester.pumpAndSettle();
      // Should have toggled sort order
      expect(viewModel.sortColumn, equals(ProfileSortColumn.name));

      // Toggle favorite on row
      final starIcons = find.byIcon(Icons.star_border);
      if (starIcons.evaluate().isNotEmpty) {
        await tester.tap(starIcons.first);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('BottomDetailInspector displays tabs and switches between them', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Select profile 1
      viewModel.selectProfile(testProfile1);

      await tester.pumpWidget(
        createTestApp(
          const Column(
            children: [
              Expanded(child: SizedBox()),
              BottomDetailInspector(),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header should display profile name and CIDR
      expect(find.text('PLC Station 01'), findsOneWidget);
      expect(find.text('[192.168.1.50/24]'), findsOneWidget);

      // Tab 0: Summary & NIC Diff is open by default
      expect(find.text('Summary & NIC Diff'), findsOneWidget);

      // Switch to Tab 1: CLI Command Preview
      await tester.tap(find.text('CLI Command Preview'));
      await tester.pumpAndSettle();
      expect(viewModel.inspectorTabIndex, equals(1));

      // Switch to Tab 2: Execution Logs
      final logTabFinder = find.byWidgetPredicate(
        (w) => w is InkWell && find.descendant(of: find.byWidget(w), matching: find.byIcon(Icons.history)).evaluate().isNotEmpty,
      );
      if (logTabFinder.evaluate().isNotEmpty) {
        await tester.tap(logTabFinder.first);
        await tester.pumpAndSettle();
        expect(viewModel.inspectorTabIndex, equals(2));
      }

      // Minimize inspector
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(viewModel.isInspectorVisible, isFalse);
    });

    testWidgets('StatusAlertBanner renders messages and dismisses', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const invalidProfile = IpProfileModel(
        id: 'bad-prof',
        name: 'Bad Profile',
        category: 'CUSTOM',
        isDhcp: false,
        ipAddress: '999.999.999.999', // Invalid IP triggers validation error banner
      );
      await viewModel.applyProfile(invalidProfile);

      await tester.pumpWidget(
        createTestApp(
          const StatusAlertBanner(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StatusAlertBanner), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      // Dismiss banner
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(viewModel.bannerMessage, isNull);
    });
  });
}
