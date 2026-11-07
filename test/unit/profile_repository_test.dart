import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ip_setter/data/repositories/profile_repository.dart';
import 'package:ip_setter/data/services/database_service.dart';
import 'package:ip_setter/domain/models/command_execution_log.dart';
import 'package:ip_setter/domain/models/ip_profile_model.dart';
import 'package:ip_setter/domain/models/profile_category_model.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('ProfileRepository Tests', () {
    late Directory tempDir;
    late DatabaseService dbService;
    late ProfileRepository repo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('repo_test_');
      final dbPath = p.join(tempDir.path, 'repo_test.db');
      dbService = DatabaseService(overridePath: dbPath);
      repo = ProfileRepository(dbService);
    });

    tearDown(() async {
      await repo.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('CRUD operations on profiles', () async {
      var profiles = await repo.loadProfiles();
      expect(profiles, isEmpty);

      const profile1 = IpProfileModel(
        id: 'p-1',
        name: 'Test Static',
        category: 'LAB',
        isDhcp: false,
        ipAddress: '192.168.1.50',
        subnetMask: '255.255.255.0',
        cidrPrefix: 24,
        defaultGateway: '192.168.1.1',
      );

      await repo.saveProfile(profile1);
      profiles = await repo.loadProfiles();
      expect(profiles.length, equals(1));
      expect(profiles.first.name, equals('Test Static'));

      // Update
      final updated = profile1.copyWith(name: 'Updated Name', isFavorite: true);
      await repo.saveProfile(updated);
      profiles = await repo.loadProfiles();
      expect(profiles.length, equals(1));
      expect(profiles.first.name, equals('Updated Name'));
      expect(profiles.first.isFavorite, isTrue);

      // Delete
      await repo.deleteProfile('p-1');
      profiles = await repo.loadProfiles();
      expect(profiles, isEmpty);
    });

    test('saveProfile throws FormatException on invalid profile data', () async {
      const invalidProfile = IpProfileModel(
        id: 'p-bad',
        name: '',
        category: 'LAB',
        isDhcp: false,
        ipAddress: 'invalid-ip',
      );

      expect(() => repo.saveProfile(invalidProfile), throwsFormatException);
    });

    test('loadDemoProfiles & clearAllProfiles', () async {
      await repo.loadDemoProfiles();
      var profiles = await repo.loadProfiles();
      expect(profiles.length, greaterThanOrEqualTo(5));

      await repo.clearAllProfiles();
      profiles = await repo.loadProfiles();
      expect(profiles, isEmpty);
    });

    test('Category operations and profile category renaming', () async {
      var categories = await repo.loadCategories();
      expect(categories.length, greaterThanOrEqualTo(5));

      // Create a profile in LAB category
      const profile = IpProfileModel(
        id: 'p-rename',
        name: 'Bench Profile',
        category: 'LAB',
        isDhcp: true,
      );
      await repo.saveProfile(profile);

      // Save category with rename from LAB to EXPERIMENTAL
      const renamedCat = ProfileCategoryModel(
        id: 'cat-lab',
        name: 'EXPERIMENTAL',
        colorHex: 0xFF123456,
      );
      await repo.saveCategory(renamedCat, previousName: 'LAB');

      final updatedProfiles = await repo.loadProfiles();
      expect(updatedProfiles.first.category, equals('EXPERIMENTAL'));

      // Delete category
      await repo.deleteCategory('cat-lab');
      categories = await repo.loadCategories();
      expect(categories.any((c) => c.id == 'cat-lab'), isFalse);
    });

    test('Execution logs pruning & retrieval', () async {
      final log1 = CommandExecutionLog(
        id: 'log-1',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        profileName: 'Profile 1',
        interfaceName: 'eth0',
        platformName: 'Linux',
        commands: ['echo 1'],
        exitCode: 0,
        stdout: 'ok',
        stderr: '',
      );
      final log2 = CommandExecutionLog(
        id: 'log-2',
        timestamp: DateTime.now(),
        profileName: 'Profile 2',
        interfaceName: 'eth0',
        platformName: 'Linux',
        commands: ['echo 2'],
        exitCode: 0,
        stdout: 'ok 2',
        stderr: '',
      );

      await repo.addExecutionLog(log1);
      await repo.addExecutionLog(log2);

      var logs = await repo.loadExecutionLogs();
      expect(logs.length, equals(2));
      expect(logs.first.id, equals('log-2')); // Most recent first

      await repo.clearExecutionLogs();
      logs = await repo.loadExecutionLogs();
      expect(logs, isEmpty);
    });

    test('Export profiles to JSON', () async {
      const p1 = IpProfileModel(
        id: 'p1',
        name: 'Export Me',
        category: 'LAB',
        isDhcp: false,
        ipAddress: '10.0.0.10',
      );
      final jsonStr = repo.exportProfilesToJson([p1]);
      expect(jsonStr, contains('"app": "ip-setter"'));
      expect(jsonStr, contains('"name": "Export Me"'));
      expect(jsonStr, contains('"ip_address": "10.0.0.10"'));
    });

    test('Import profiles from valid JSON bundle', () async {
      const jsonBundle = '''
      {
        "app": "ip-setter",
        "version": 1,
        "profiles": [
          {
            "id": "imp-1",
            "name": "Imported Profile",
            "category": "OFFICE",
            "is_dhcp": 1
          },
          {
            "id": "imp-2",
            "name": "Static Import",
            "category": "FIELD",
            "is_dhcp": 0,
            "ip_address": "172.16.0.15",
            "subnet_mask": "255.255.0.0",
            "cidr_prefix": 16,
            "default_gateway": "172.16.0.1"
          }
        ]
      }
      ''';

      final count = await repo.importProfilesFromJson(jsonBundle);
      expect(count, equals(2));

      final loaded = await repo.loadProfiles();
      expect(loaded.length, equals(2));
      expect(loaded.any((p) => p.name == 'Imported Profile'), isTrue);
      expect(loaded.any((p) => p.name == 'Static Import'), isTrue);
    });

    test('Import profiles avoids silent overwrite on unrelated ID collision', () async {
      const existing = IpProfileModel(
        id: 'same-id',
        name: 'Original Existing Profile',
        category: 'LAB',
        isDhcp: true,
      );
      await repo.saveProfile(existing);

      const jsonBundle = '''
      {
        "profiles": [
          {
            "id": "same-id",
            "name": "Completely Different New Profile",
            "category": "FIELD",
            "is_dhcp": true
          }
        ]
      }
      ''';

      final count = await repo.importProfilesFromJson(jsonBundle);
      expect(count, equals(1));

      final all = await repo.loadProfiles();
      expect(all.length, equals(2)); // Both preserved
      expect(all.any((p) => p.name == 'Original Existing Profile'), isTrue);
      expect(all.any((p) => p.name == 'Completely Different New Profile'), isTrue);
    });

    test('Import profiles rejects invalid bundle format', () async {
      expect(
        () => repo.importProfilesFromJson('{"something_else": 123}'),
        throwsFormatException,
      );

      const invalidIpBundle = '''
      {
        "profiles": [
          {
            "id": "bad-ip",
            "name": "Bad Static",
            "category": "LAB",
            "is_dhcp": 0,
            "ip_address": "999.999.999.999"
          }
        ]
      }
      ''';
      expect(
        () => repo.importProfilesFromJson(invalidIpBundle),
        throwsFormatException,
      );
    });
  });
}
