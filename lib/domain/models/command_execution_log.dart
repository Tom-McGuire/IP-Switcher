import 'dart:convert';

class CommandExecutionLog {
  final String id;
  final DateTime timestamp;
  final String profileName;
  final String interfaceName;
  final String platformName;
  final List<String> commands;
  final int exitCode;
  final String stdout;
  final String stderr;
  final bool? gatewayReachable;
  final double? gatewayLatencyMs;
  final bool isDryRun;

  const CommandExecutionLog({
    required this.id,
    required this.timestamp,
    required this.profileName,
    required this.interfaceName,
    required this.platformName,
    required this.commands,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    this.gatewayReachable,
    this.gatewayLatencyMs,
    this.isDryRun = false,
  });

  bool get isSuccess => exitCode == 0;

  String get formattedTimestamp {
    final y = timestamp.year.toString().padLeft(4, '0');
    final m = timestamp.month.toString().padLeft(2, '0');
    final d = timestamp.day.toString().padLeft(2, '0');
    final hh = timestamp.hour.toString().padLeft(2, '0');
    final mm = timestamp.minute.toString().padLeft(2, '0');
    final ss = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$y-$m-$d $hh:$mm:$ss.$ms';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'profile_name': profileName,
      'interface_name': interfaceName,
      'platform_name': platformName,
      'commands': jsonEncode(commands),
      'exit_code': exitCode,
      'stdout': stdout,
      'stderr': stderr,
      'gateway_reachable':
          gatewayReachable == null ? null : (gatewayReachable! ? 1 : 0),
      'gateway_latency_ms': gatewayLatencyMs,
      'is_dry_run': isDryRun ? 1 : 0,
    };
  }

  factory CommandExecutionLog.fromMap(Map<String, dynamic> map) {
    List<String> parsedCommands = [];
    final rawCmds = map['commands'];
    if (rawCmds is String && rawCmds.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawCmds);
        if (decoded is List) {
          parsedCommands = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    return CommandExecutionLog(
      id: map['id'] as String,
      timestamp:
          DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
      profileName: (map['profile_name'] as String?) ?? '',
      interfaceName: (map['interface_name'] as String?) ?? '',
      platformName: (map['platform_name'] as String?) ?? '',
      commands: parsedCommands,
      exitCode: (map['exit_code'] as int?) ?? 0,
      stdout: (map['stdout'] as String?) ?? '',
      stderr: (map['stderr'] as String?) ?? '',
      gatewayReachable: map['gateway_reachable'] == null
          ? null
          : (map['gateway_reachable'] == 1),
      gatewayLatencyMs: (map['gateway_latency_ms'] as num?)?.toDouble(),
      isDryRun: map['is_dry_run'] == 1,
    );
  }
}
