import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../domain/models/network_interface_model.dart';
import '../view_models/ip_setter_view_model.dart';

class TopControlBar extends StatelessWidget {
  final VoidCallback onNewProfile;
  final VoidCallback onImportExport;

  const TopControlBar({
    super.key,
    required this.onNewProfile,
    required this.onImportExport,
  });

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<IpSetterViewModel>();
    final selectedNic = vm.selectedInterface;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // App Icon & Title (matching ArpControlBar / SyslogControlBar)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/app_icon.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.settings_ethernet,
                  color: Color(0xFF007ACC),
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'IP Profile Switcher',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                Text(
                  'NIC Quick-Config • Static IPv4 • Subnet • Gateway • DNS',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(width: 18),

            // Primary Action: New Preset
            FilledButton.icon(
              onPressed: onNewProfile,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              icon: const Icon(Icons.add, size: 17),
              label: const Text(
                'New Preset',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Instant Quick DHCP Button
            FilledButton.tonalIcon(
              onPressed: vm.isApplying ? null : () => vm.applyEmergencyDhcp(),
              icon: const Icon(Icons.bolt, size: 16),
              label: const Text(
                'Quick DHCP',
                style: TextStyle(fontSize: 12),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Dry-Run Mode Toggle (styled like Watch Mode in ArpControlBar)
            Tooltip(
              message:
                  'Dry-Run Mode: Simulate preset switches and preview OS CLI commands without modifying host adapters',
              child: OutlinedButton.icon(
                onPressed: () => vm.toggleDryRunMode(!vm.dryRunMode),
                icon: Icon(
                  vm.dryRunMode ? Icons.science : Icons.science_outlined,
                  size: 15,
                  color:
                      vm.dryRunMode ? const Color(0xFFF59E0B) : Colors.grey,
                ),
                label: Text(
                  vm.dryRunMode ? 'Dry-Run (On)' : 'Dry-Run Mode',
                  style: TextStyle(
                    fontSize: 12,
                    color: vm.dryRunMode
                        ? const Color(0xFFF59E0B)
                        : Colors.white70,
                    fontWeight:
                        vm.dryRunMode ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: vm.dryRunMode
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF3E3E42),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
              ),
            ),

            // Undo Snapshot Button (when available)
            if (vm.previousNicSnapshot != null) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: vm.isApplying ? null : () => vm.undoLastSwitch(),
                icon: const Icon(
                  Icons.undo,
                  size: 15,
                  color: Color(0xFFF59E0B),
                ),
                label: const Text(
                  'Undo Switch',
                  style: TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 16),

            // Network Interface Selector (matching SyslogControlBar & ArpControlBar)
            const Text(
              'Interface:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(width: 6),
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF252526),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF3E3E42)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedNic?.id,
                  isDense: true,
                  icon: const Icon(Icons.arrow_drop_down, size: 18),
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                  dropdownColor: const Color(0xFF252526),
                  onChanged: vm.isApplying
                      ? null
                      : (String? id) {
                          if (id == null) return;
                          final found =
                              vm.interfaces.firstWhere((i) => i.id == id);
                          vm.selectInterface(found);
                        },
                  items: vm.interfaces.map((NetworkInterfaceModel nic) {
                    final lower = nic.displayName.toLowerCase();
                    IconData icon = Icons.lan_outlined;
                    if (lower.contains('wi-fi') ||
                        lower.contains('wlan') ||
                        lower.contains('wl')) {
                      icon = Icons.wifi;
                    }
                    return DropdownMenuItem<String>(
                      value: nic.id,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 14,
                            color: nic.isUp
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text('${nic.displayName} (${nic.formattedIpWithCidr})'),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip:
                  'Copy IP address (${selectedNic?.currentIp ?? "Unassigned"})',
              icon: const Icon(Icons.copy, size: 14),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              onPressed: selectedNic?.currentIp == null
                  ? null
                  : () {
                      Clipboard.setData(
                        ClipboardData(text: selectedNic!.currentIp!),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Copied ${selectedNic.currentIp} to clipboard',
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
            ),
            IconButton(
              tooltip: 'Refresh network interfaces',
              icon: const Icon(Icons.refresh, size: 14),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              onPressed: vm.isApplying
                  ? null
                  : () => vm.refreshInterfaces(checkGatewayPing: true),
            ),
            const SizedBox(width: 14),

            // Demo Presets Button (matching SyslogControlBar 'Demo Logs' & ArpControlBar 'Demo Subnet')
            OutlinedButton.icon(
              onPressed: () async {
                await vm.loadDemoPresets();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Loaded 8 demo IP profile presets (Lab, Field, Office DHCP, VLAN, Art-Net).',
                      ),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.auto_awesome, size: 15),
              label: const Text(
                'Demo Presets',
                style: TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Import JSON Button
            FilledButton.tonalIcon(
              onPressed: onImportExport,
              icon: const Icon(Icons.file_open_outlined, size: 15),
              label: const Text(
                'Open JSON',
                style: TextStyle(fontSize: 12),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Clear Button
            OutlinedButton.icon(
              onPressed: vm.allProfiles.isEmpty
                  ? null
                  : () => _confirmClear(context, vm),
              icon: const Icon(Icons.delete_outline, size: 15),
              label: const Text(
                'Clear',
                style: TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade300,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Export Menu
            PopupMenuButton<String>(
              tooltip: 'Export Presets',
              enabled: vm.allProfiles.isNotEmpty,
              icon: const Icon(Icons.file_download_outlined, size: 20),
              onSelected: (val) async {
                if (val == 'copy_json') {
                  final jsonStr = vm.exportPresetsJson();
                  await Clipboard.setData(ClipboardData(text: jsonStr));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied JSON presets to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } else if (val == 'manage_json') {
                  onImportExport();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'copy_json',
                  child: Row(
                    children: [
                      Icon(Icons.copy, size: 16),
                      SizedBox(width: 8),
                      Text('Copy Presets as JSON'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'manage_json',
                  child: Row(
                    children: [
                      Icon(Icons.code, size: 16),
                      SizedBox(width: 8),
                      Text('Import / Export JSON Bundle...'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClear(BuildContext context, IpSetterViewModel vm) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Saved IP Presets?'),
        content: const Text(
          'This will remove all saved IP presets from the active SQLite database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              vm.clearAllPresets();
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
