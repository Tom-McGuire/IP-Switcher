import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../domain/models/network_interface_model.dart';
import '../../theme/app_theme.dart';
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
      height: 52,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left Cluster: Zone 1 (Branding), Zone 2 (Interface & Target), Zone 3 (Primary Actions)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ==================== ZONE 1: BRANDING ====================
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.asset(
                              'assets/app_icon.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Icon(
                                Icons.settings_ethernet,
                                color: AppTheme.primaryAccent,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'IP PROFILE SWITCHER',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'NIC Quick-Config • Static IPv4 • Subnet • Gateway • DNS',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),

                        // ==================== ZONE 2: INTERFACE & TARGET ====================
                        Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.inputFill,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.inputBorder),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedNic?.id,
                              isDense: true,
                              icon: Icon(
                                Icons.arrow_drop_down,
                                size: 18,
                                color: AppTheme.textSecondary,
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textPrimary,
                              ),
                              dropdownColor: AppTheme.surfaceElevated,
                              onChanged: vm.isApplying
                                  ? null
                                  : (String? id) {
                                      if (id == null) return;
                                      final found = vm.interfaces
                                          .firstWhere((i) => i.id == id);
                                      vm.selectInterface(found);
                                    },
                              items: vm.interfaces
                                  .map((NetworkInterfaceModel nic) {
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
                                            ? AppTheme.primaryAccent
                                            : AppTheme.textMuted,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${nic.displayName} (${nic.formattedIpWithCidr})',
                                      ),
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
                          constraints: const BoxConstraints(
                            minWidth: 26,
                            minHeight: 26,
                          ),
                          onPressed: selectedNic?.currentIp == null
                              ? null
                              : () {
                                  Clipboard.setData(
                                    ClipboardData(
                                      text: selectedNic!.currentIp!,
                                    ),
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
                          tooltip: 'Refresh Interfaces',
                          icon: const Icon(Icons.refresh, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 26,
                            minHeight: 26,
                          ),
                          onPressed: vm.isApplying
                              ? null
                              : () =>
                                  vm.refreshInterfaces(checkGatewayPing: true),
                        ),
                        const SizedBox(width: 12),

                        // ==================== ZONE 3: PRIMARY ACTIONS ====================
                        FilledButton.icon(
                          onPressed: vm.isApplying ? null : onNewProfile,
                          style: FilledButton.styleFrom(
                            backgroundColor: vm.isApplying
                                ? AppTheme.error
                                : AppTheme.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          icon: Icon(
                            vm.isApplying ? Icons.hourglass_top : Icons.add,
                            size: 17,
                          ),
                          label: Text(
                            vm.isApplying ? 'Applying...' : 'New Preset',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        FilledButton.tonalIcon(
                          onPressed: vm.isApplying
                              ? null
                              : () => vm.applyEmergencyDhcp(),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        Tooltip(
                          message:
                              'Dry-Run Mode: Simulate preset switches and preview OS CLI commands without modifying host adapters',
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                vm.toggleDryRunMode(!vm.dryRunMode),
                            icon: Icon(
                              vm.dryRunMode
                                  ? Icons.science
                                  : Icons.science_outlined,
                              size: 15,
                              color: vm.dryRunMode
                                  ? AppTheme.warning
                                  : AppTheme.textMuted,
                            ),
                            label: Text(
                              vm.dryRunMode ? 'Dry-Run (On)' : 'Dry-Run Mode',
                              style: TextStyle(
                                fontSize: 11,
                                color: vm.dryRunMode
                                    ? AppTheme.warning
                                    : AppTheme.textSecondary,
                                fontWeight: vm.dryRunMode
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: vm.dryRunMode
                                    ? AppTheme.warning
                                    : AppTheme.inputBorder,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),

                        if (vm.previousNicSnapshot != null) ...[
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: vm.isApplying
                                ? null
                                : () => vm.undoLastSwitch(),
                            icon: Icon(
                              Icons.undo,
                              size: 15,
                              color: AppTheme.warning,
                            ),
                            label: const Text(
                              'Undo Switch',
                              style: TextStyle(fontSize: 11),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Right Cluster: Zone 4 (Ecosystem & Demo), Zone 5 (Clear & Export)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ==================== ZONE 4: ECOSYSTEM & DEMO ====================
                        FilledButton.tonalIcon(
                          onPressed: onImportExport,
                          icon: const Icon(Icons.file_open_outlined, size: 15),
                          label: const Text(
                            'Open JSON',
                            style: TextStyle(fontSize: 11),
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        OutlinedButton.icon(
                          onPressed: vm.isApplying
                              ? null
                              : () async {
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
                          icon: const Icon(Icons.play_circle_outline, size: 15),
                          label: const Text(
                            'Load Demo',
                            style: TextStyle(fontSize: 11),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // ==================== ZONE 5: CLEAR & EXPORT ====================
                        OutlinedButton.icon(
                          onPressed: vm.allProfiles.isEmpty || vm.isApplying
                              ? null
                              : () => _confirmClear(context, vm),
                          icon: const Icon(Icons.delete_sweep_outlined, size: 15),
                          label: const Text(
                            'Clear',
                            style: TextStyle(fontSize: 11),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.error,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        PopupMenuButton<String>(
                          tooltip: 'Export',
                          enabled: vm.allProfiles.isNotEmpty,
                          onSelected: (val) async {
                            if (val == 'copy_json') {
                              final jsonStr = vm.exportPresetsJson();
                              await Clipboard.setData(
                                ClipboardData(text: jsonStr),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Copied JSON presets to clipboard'),
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
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppTheme.border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.download,
                                  size: 15,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Export',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  size: 14,
                                  color: AppTheme.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
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
