import 'dart:convert';
import '../../domain/models/command_execution_log.dart';
import '../../domain/models/ip_profile_model.dart';
import '../services/database_service.dart';

class ProfileRepository {
  final DatabaseService _databaseService;

  ProfileRepository(this._databaseService);

  Future<List<IpProfileModel>> loadProfiles() async {
    return _databaseService.getAllProfiles();
  }

  Future<void> saveProfile(IpProfileModel profile) async {
    await _databaseService.upsertProfile(profile);
  }

  Future<void> deleteProfile(String id) async {
    await _databaseService.deleteProfile(id);
  }

  Future<void> resetDefaults() async {
    await _databaseService.resetToDefaultProfiles();
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

    int count = 0;
    for (final item in rawList) {
      if (item is Map<String, dynamic>) {
        final profile = IpProfileModel.fromMap(item);
        await _databaseService.upsertProfile(profile);
        count++;
      } else if (item is Map) {
        final profile =
            IpProfileModel.fromMap(Map<String, dynamic>.from(item));
        await _databaseService.upsertProfile(profile);
        count++;
      }
    }
    return count;
  }

  Future<void> close() async {
    await _databaseService.close();
  }
}
