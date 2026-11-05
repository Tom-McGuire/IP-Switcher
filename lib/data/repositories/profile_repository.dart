import 'dart:convert';
import '../../domain/models/command_execution_log.dart';
import '../../domain/models/ip_profile_model.dart';
import '../../domain/models/profile_category_model.dart';
import '../services/database_service.dart';

class ProfileRepository {
  final DatabaseService _databaseService;

  ProfileRepository(this._databaseService);

  Future<List<IpProfileModel>> loadProfiles() async {
    return _databaseService.getAllProfiles();
  }

  Future<void> saveProfile(IpProfileModel profile) async {
    final validationError = profile.validate();
    if (validationError != null) {
      throw FormatException(validationError);
    }
    await _databaseService.upsertProfile(profile);
  }

  Future<void> deleteProfile(String id) async {
    await _databaseService.deleteProfile(id);
  }

  Future<void> clearAllProfiles() async {
    await _databaseService.clearAllProfiles();
  }

  Future<void> loadDemoProfiles() async {
    await _databaseService.loadDemoProfiles();
  }

  Future<void> resetDefaults() async {
    await _databaseService.loadDemoProfiles();
  }

  Future<List<ProfileCategoryModel>> loadCategories() async {
    return _databaseService.getAllCategories();
  }

  Future<void> saveCategory(
    ProfileCategoryModel category, {
    String? previousName,
  }) async {
    await _databaseService.upsertCategory(category);
    if (previousName != null &&
        previousName.trim().isNotEmpty &&
        previousName.toUpperCase() != category.name.toUpperCase()) {
      await _databaseService.renameCategoryInProfiles(
        previousName,
        category.name,
      );
    }
  }

  Future<void> deleteCategory(String id) async {
    await _databaseService.deleteCategory(id);
  }

  Future<List<CommandExecutionLog>> loadExecutionLogs() async {
    return _databaseService.getExecutionLogs();
  }

  Future<void> addExecutionLog(CommandExecutionLog log) async {
    await _databaseService.insertExecutionLog(log);
  }

  Future<void> clearExecutionLogs() async {
    await _databaseService.clearExecutionLogs();
  }

  String exportProfilesToJson(List<IpProfileModel> profiles) {
    final list = profiles.map((p) => p.toMap()).toList();
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'ip-setter',
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'profiles': list,
    });
  }

  Future<int> importProfilesFromJson(String jsonString) async {
    final decoded = jsonDecode(jsonString);
    List<dynamic> rawList;
    if (decoded is Map && decoded['profiles'] is List) {
      rawList = decoded['profiles'] as List<dynamic>;
    } else if (decoded is List) {
      rawList = decoded;
    } else {
      throw const FormatException('Invalid preset bundle JSON structure.');
    }

    final existing = await _databaseService.getAllProfiles();
    final existingById = {for (final p in existing) p.id: p};

    final validatedProfiles = <IpProfileModel>[];
    for (int i = 0; i < rawList.length; i++) {
      final item = rawList[i];
      if (item is! Map) {
        throw FormatException('Entry #${i + 1} in JSON bundle is not an object.');
      }
      var profile = IpProfileModel.fromMap(Map<String, dynamic>.from(item));
      final validationError = profile.validate();
      if (validationError != null) {
        throw FormatException('Entry #${i + 1}: $validationError');
      }
      // Avoid silently overwriting an unrelated preset that happens to share an ID
      final collision = existingById[profile.id];
      if (collision != null &&
          collision.name.toLowerCase() != profile.name.toLowerCase()) {
        profile = profile.copyWith(
          id: 'profile-${DateTime.now().microsecondsSinceEpoch}-$i',
        );
      }
      validatedProfiles.add(profile);
    }

    for (final profile in validatedProfiles) {
      await _databaseService.upsertProfile(profile);
    }
    return validatedProfiles.length;
  }

  Future<void> close() async {
    await _databaseService.close();
  }
}
