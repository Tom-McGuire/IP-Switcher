import 'dart:convert';
import 'dart:io';

class GatewayPingResult {
  final String gatewayIp;
  final bool isReachable;
  final double? latencyMs;
  final String rawOutput;

  const GatewayPingResult({
    required this.gatewayIp,
    required this.isReachable,
    this.latencyMs,
    required this.rawOutput,
  });
}

class GatewayPingService {
  final Set<Process> _activePings = {};

  Future<void> stopAll() async {
    for (final p in _activePings.toList()) {
      try {
        p.kill(ProcessSignal.sigterm);
      } catch (_) {}
    }
    _activePings.clear();
  }

  Future<GatewayPingResult> pingGateway(String gatewayIp) async {
    final cleanIp = gatewayIp.trim();
    if (cleanIp.isEmpty) {
      return const GatewayPingResult(
        gatewayIp: '',
        isReachable: false,
        rawOutput: 'No gateway configured.',
      );
    }

    try {
      final List<String> args;
      if (Platform.isWindows) {
        args = ['-n', '1', '-w', '1000', cleanIp];
      } else if (Platform.isMacOS) {
        args = ['-c', '1', '-t', '1', cleanIp];
      } else {
        args = ['-c', '1', '-W', '1', cleanIp];
      }

      final proc = await Process.start('ping', args);
      _activePings.add(proc);
      final outFuture = proc.stdout.transform(utf8.decoder).join();
      final errFuture = proc.stderr.transform(utf8.decoder).join();
      final code = await proc.exitCode;
      _activePings.remove(proc);

      final out = (await outFuture).trim();
      final err = (await errFuture).trim();
      final combined = [out, err].where((s) => s.isNotEmpty).join('\n');

      double? latency;
      final match =
          RegExp(r'time[=<](\d+(?:\.\d+)?)\s*ms', caseSensitive: false)
              .firstMatch(combined);
      if (match != null) {
        latency = double.tryParse(match.group(1)!);
      }

      return GatewayPingResult(
        gatewayIp: cleanIp,
        isReachable: code == 0,
        latencyMs: latency,
        rawOutput: combined,
      );
    } catch (e) {
      return GatewayPingResult(
        gatewayIp: cleanIp,
        isReachable: false,
        rawOutput: 'Ping check error: $e',
      );
    }
  }
}
