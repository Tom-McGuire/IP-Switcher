import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ip_setter/data/repositories/nic_repository.dart';
import 'package:ip_setter/data/repositories/profile_repository.dart';
import 'package:ip_setter/data/services/database_service.dart';
import 'package:ip_setter/data/services/gateway_ping_service.dart';
import 'package:ip_setter/data/services/nic_backend_service.dart';
import 'package:ip_setter/domain/models/ip_profile_model.dart';
import 'package:ip_setter/domain/models/profile_category_model.dart';
import 'package:ip_setter/theme/app_theme.dart';
import 'package:ip_setter/ui/view_models/ip_setter_view_model.dart';
import 'package:ip_setter/ui/widgets/category_dialogs.dart';
import 'package:ip_setter/ui/widgets/import_export_dialog.dart';
import 'package:ip_setter/ui/widgets/profile_editor_dialog.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class InMemoryProfileRepository extends ProfileRepository {
  final List<ProfileCategoryModel> _cats = List.from(ProfileCategoryModel.defaultCategories);
  final List<IpProfileModel> _profs = [];

  InMemoryProfileRepository() : super(DatabaseService(overridePath: inMemoryDatabasePath));

  @override
  Future<List<ProfileCategoryModel>> loadCategories() async => List.from(_cats);

  @override
  Future<void> saveCategory(ProfileCategoryModel cat, {String? previousName}) async {
    final idx = _cats.indexWhere((c) => c.id == cat.id || c.name.toUpperCase() == (previousName ?? cat.name).toUpperCase());
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
    _profs.removeWhere((x) => x.id == p.id);
    _profs.add(p);
  }

  @override
  Future<void> close() async {}
}

void main() {
  sqfliteFfiInit();

  group('Widget Dialog Tests', () {
    late InMemoryProfileRepository profileRepo;
    late NicRepository nicRepo;
    late IpSetterViewModel viewModel;

    setUp(() async {
      profileRepo = InMemoryProfileRepository();
      nicRepo = NicRepository(NicBackendService(), GatewayPingService());
      viewModel = IpSetterViewModel(
        profileRepository: profileRepo,
        nicRepository: nicRepo,
      );
      await viewModel.initialize();
      // Cancel background periodic network polling timer during widget testing
      await viewModel.stopAllServices();
    });

    Widget createTestApp(Widget child) {
      return ChangeNotifierProvider<IpSetterViewModel>.value(
        value: viewModel,
        child: MaterialApp(
          theme: AppTheme.darkTheme(),
          home: Scaffold(body: Center(child: child)),
        ),
      );
    }

    testWidgets('ProfileEditorDialog validates required fields and calculates CIDR', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      IpProfileModel? savedResult;

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                savedResult = await showDialog<IpProfileModel>(
                  context: context,
                  builder: (_) => ProfileEditorDialog(
                    onSnapshotActiveNic: viewModel.createTemplateFromActiveNic,
                  ),
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Create IP Profile Preset'), findsOneWidget);

      // Try saving without preset name
      await tester.tap(find.text('Save Preset'));
      await tester.pumpAndSettle();
      expect(find.text('Preset name is required'), findsOneWidget);

      // Enter name
      await tester.enterText(find.widgetWithText(TextFormField, 'Preset Name'), 'Bench Unit 5');

      // Change CIDR to 16 and verify Subnet Mask changes to 255.255.0.0
      final cidrFinder = find.widgetWithText(TextFormField, 'CIDR');
      await tester.enterText(cidrFinder, '16');
      await tester.pumpAndSettle();

      expect(find.text('255.255.0.0'), findsOneWidget);

      // Save valid profile
      await tester.tap(find.text('Save Preset'));
      await tester.pumpAndSettle();

      expect(savedResult, isNotNull);
      expect(savedResult!.name, equals('Bench Unit 5'));
      expect(savedResult!.cidrPrefix, equals(16));
      expect(savedResult!.subnetMask, equals('255.255.0.0'));
    });

    testWidgets('AddEditCategoryDialog allows color picking and saving', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ProfileCategoryModel? savedCategory;

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                savedCategory = await showDialog<ProfileCategoryModel>(
                  context: context,
                  builder: (_) => const AddEditCategoryDialog(),
                );
              },
              child: const Text('Open Category Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Category Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(AddEditCategoryDialog), findsOneWidget);

      // Try saving empty name
      await tester.tap(find.widgetWithText(FilledButton, 'Add Category'));
      await tester.pumpAndSettle();
      expect(find.text('Category name is required'), findsOneWidget);

      // Enter category name
      await tester.enterText(find.byType(TextField), 'ROBOTICS');
      await tester.pump();

      // Save category
      await tester.tap(find.widgetWithText(FilledButton, 'Add Category'));
      await tester.pumpAndSettle();

      expect(savedCategory, isNotNull);
      expect(savedCategory!.name, equals('ROBOTICS'));
      await viewModel.addOrUpdateCategory(savedCategory!);
      expect(viewModel.categories.any((c) => c.name == 'ROBOTICS'), isTrue);
    });

    testWidgets('ManageCategoriesDialog lists categories and toggles visibility', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          const ManageCategoriesDialog(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Manage Filter Categories'), findsOneWidget);
      expect(find.text('LAB'), findsOneWidget);
      expect(find.text('FIELD'), findsOneWidget);

      final labCategory = viewModel.categories.firstWhere((c) => c.name == 'LAB');
      expect(labCategory.isVisible, isTrue);

      // Tap the visibility toggle icon for the first item
      await tester.tap(find.byIcon(Icons.visibility).first);
      await tester.pumpAndSettle();

      expect(viewModel.categories.firstWhere((c) => c.name == 'LAB').isVisible, isFalse);
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('ImportExportDialog displays JSON and handles close & restore', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool resetCalled = false;

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ImportExportDialog(
                  exportedJson: '{\n  "test": 123\n}',
                  onImportJson: (json) async => 2,
                  onResetDefaults: () async {
                    resetCalled = true;
                  },
                ),
              ),
              child: const Text('Open Modal'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Import / Export Presets (JSON)'), findsOneWidget);
      expect(find.text('Copy JSON'), findsOneWidget);

      // Trigger Restore Factory Presets
      await tester.tap(find.text('Restore Factory Presets'));
      await tester.pumpAndSettle();
      expect(resetCalled, isTrue);
    });
  });
}
