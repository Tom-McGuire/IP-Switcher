import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
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

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          // App Icon & Title
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              'assets/icons/app_icon.png',
              width: 30,
              height: 30,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.settings_ethernet,
                color: AppTheme.primaryAccent,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'IP Profile Switcher',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          letterSpacing: 0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppTheme.primaryAccent.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Text(
                        'NIC QUICK-CONFIG',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryCyan,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      AppConstants.appVersion,
                      style: AppTheme.monoStyle(
                        fontSize: 10,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const Text(
                  'One-click Static IPv4, Subnet, Gateway, DNS & DHCP Adapter Presets',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Target Interface Selector
          const Text(
            'TARGET NIC:',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppTheme.inputFill,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.inputBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: vm.selectedInterface?.id,
                dropdownColor: AppTheme.surfaceHigh,
                icon: const Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textPrimary,
                ),
                items: vm.interfaces.map((NetworkInterfaceModel nic) {
                  return DropdownMenuItem<String>(
                    value: nic.id,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: nic.isUp ? AppTheme.success : AppTheme.error,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          nic.displayName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '[${nic.formattedIpWithCidr}]',
                          style: AppTheme.monoStyle(
                            fontSize: 11,
                            color: AppTheme.secondaryCyan,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (String? id) {
                  if (id == null) return;
                  final found = vm.interfaces.firstWhere((i) => i.id == id);
                  vm.selectInterface(found);
                },
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Refresh Live OS Network Interfaces',
            onPressed: vm.isApplying
                ? null
                : () => vm.refreshInterfaces(checkGatewayPing: true),
            icon: const Icon(Icons.refresh, size: 17),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 6),

          // Dry-Run / Simulation Toggle
          Tooltip(
            message:
                'Simulation / Dry-Run Mode: Preview & test preset switches without mutating host OS adapters',
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => vm.toggleDryRunMode(!vm.dryRunMode),
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  color: vm.dryRunMode
                      ? AppTheme.warning.withValues(alpha: 0.16)
                      : AppTheme.inputFill,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: vm.dryRunMode
                        ? AppTheme.warning.withValues(alpha: 0.6)
                        : AppTheme.inputBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      vm.dryRunMode
                          ? Icons.science
                          : Icons.science_outlined,
                      size: 14,
                      color: vm.dryRunMode
                          ? AppTheme.warning
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      vm.dryRunMode ? 'DRY-RUN: ON' : 'DRY-RUN: OFF',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: vm.dryRunMode
                            ? AppTheme.warning
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Undo Previous Switch Button
          if (vm.previousNicSnapshot != null) ...[
            SizedBox(
              height: 30,
              child: OutlinedButton.icon(
                onPressed: vm.isApplying ? null : () => vm.undoLastSwitch(),
                icon: const Icon(Icons.undo, size: 14),
                label: const Text(
                  'Undo',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.warning,
                  side: BorderSide(
                    color: AppTheme.warning.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Quick DHCP Button
          SizedBox(
            height: 30,
            child: OutlinedButton.icon(
              onPressed: vm.isApplying ? null : () => vm.applyEmergencyDhcp(),
              icon: const Icon(Icons.autorenew, size: 14),
              label: const Text(
                'Quick DHCP',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.success,
                side: BorderSide(
                  color: AppTheme.success.withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Import / Export Presets Button
          IconButton(
            tooltip: 'Import / Export JSON Preset Bundle',
            onPressed: onImportExport,
            icon: const Icon(Icons.import_export, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 6),

          // New Profile Button
          SizedBox(
            height: 30,
            child: FilledButton.icon(
              onPressed: onNewProfile,
              icon: const Icon(Icons.add, size: 15),
              label: const Text(
                'New Preset',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
