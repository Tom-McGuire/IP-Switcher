import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../data/services/nic_backend_service.dart';
import '../../domain/models/ipv4_utils.dart';
import '../../theme/app_theme.dart';
import '../view_models/ip_setter_view_model.dart';
import 'status_badge.dart';

class BottomDetailInspector extends StatefulWidget {
  const BottomDetailInspector({super.key});

  @override
  State<BottomDetailInspector> createState() => _BottomDetailInspectorState();
}

class _BottomDetailInspectorState extends State<BottomDetailInspector> {
  bool _copiedConfirmation = false;

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _copiedConfirmation = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _copiedConfirmation = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<IpSetterViewModel>();
    final profile = vm.selectedProfile;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (vm.isInspectorVisible && profile != null)
          Container(
            height: 248,
            decoration: const BoxDecoration(
              color: AppTheme.surfaceHigh,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Column(
              children: [
                // Inspector Header Row
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: const BoxDecoration(
                    color: AppTheme.surface,
                    border: Border(bottom: BorderSide(color: AppTheme.border)),
                  ),
                  child: Row(
                    children: [
                      StatusBadge(
                        label: profile.isDhcp ? 'DHCP' : 'STATIC',
                        color: profile.isDhcp
                            ? AppTheme.success
                            : AppTheme.primaryAccent,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        profile.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '[${profile.formattedIpWithCidr}]',
                        style: AppTheme.monoStyle(
                          fontSize: 11.5,
                          color: AppTheme.secondaryCyan,
                        ),
                      ),
                      if (profile.lastAppliedAt != null) ...[
                        const SizedBox(width: 12),
                        Text(
                          'Last Applied: ${_formatTimestamp(profile.lastAppliedAt!)}',
                          style: AppTheme.monoStyle(
                            fontSize: 10.5,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                      const SizedBox(width: 18),

                      // Multi-mode Inspector Tabs
                      _buildTabButton(
                        index: 0,
                        currentIndex: vm.inspectorTabIndex,
                        icon: Icons.compare_arrows,
                        label: 'Summary & NIC Diff',
                        onTap: () => vm.setInspectorTab(0),
                      ),
                      const SizedBox(width: 6),
                      _buildTabButton(
                        index: 1,
                        currentIndex: vm.inspectorTabIndex,
                        icon: Icons.terminal,
                        label: 'CLI Command Preview',
                        onTap: () => vm.setInspectorTab(1),
                      ),
                      const SizedBox(width: 6),
                      _buildTabButton(
                        index: 2,
                        currentIndex: vm.inspectorTabIndex,
                        icon: Icons.history,
                        label: 'Execution Logs (${vm.executionLogs.length})',
                        onTap: () => vm.setInspectorTab(2),
                      ),

                      const Spacer(),
                      // Copy CLI / Summary button
                      SizedBox(
                        height: 26,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final cmds = vm.previewCliCommands.join('\n');
                            _copyToClipboard(cmds);
                          },
                          icon: Icon(
                            _copiedConfirmation ? Icons.check : Icons.copy,
                            size: 13,
                            color: _copiedConfirmation
                                ? AppTheme.success
                                : AppTheme.textSecondary,
                          ),
                          label: Text(
                            _copiedConfirmation ? 'Copied CLI' : 'Copy CLI',
                            style: TextStyle(
                              fontSize: 11,
                              color: _copiedConfirmation
                                  ? AppTheme.success
                                  : AppTheme.textPrimary,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            side: const BorderSide(color: AppTheme.inputBorder),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'Close Inspector',
                        icon: const Icon(Icons.close, size: 15),
                        onPressed: vm.closeInspector,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 26,
                          minHeight: 26,
                        ),
                      ),
                    ],
                  ),
                ),

                // Inspector Body
                Expanded(
                  child: IndexedStack(
                    index: vm.inspectorTabIndex,
                    children: [
                      _buildDiffAndSummaryTab(vm),
                      _buildCliPreviewCardTab(vm),
                      _buildExecutionLogsTab(vm),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Persistent Status Bar (Always visible at bottom of Tier 5)
        Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceLow,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              Icon(
                vm.selectedInterface?.isUp == true
                    ? Icons.circle
                    : Icons.circle_outlined,
                size: 9,
                color: vm.selectedInterface?.isUp == true
                    ? AppTheme.success
                    : AppTheme.error,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  vm.selectedInterface != null
                      ? 'NIC: ${vm.selectedInterface!.displayName} (${vm.selectedInterface!.formattedIpWithCidr})'
                      : 'No Interface Selected',
                  style: AppTheme.monoStyle(
                    fontSize: 10.5,
                    color: AppTheme.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Showing ${vm.filteredProfiles.length} of ${vm.allProfiles.length} presets',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              if (vm.selectedProfile == null || !vm.isInspectorVisible)
                InkWell(
                  onTap: () {
                    if (vm.selectedProfile != null) {
                      vm.selectProfile(vm.selectedProfile);
                    } else if (vm.filteredProfiles.isNotEmpty) {
                      vm.selectProfile(vm.filteredProfiles.first);
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '▲ Inspector',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppTheme.secondaryCyan,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  '${TargetOsPlatform.current.shortLabel} • ${AppConstants.publisherName}',
                  style: AppTheme.monoStyle(
                    fontSize: 10.5,
                    color: AppTheme.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                vm.dryRunMode
                    ? 'DRY-RUN'
                    : (vm.isElevated ? 'ELEVATED' : 'ON-DEMAND ELEVATION'),
                style: AppTheme.monoStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: vm.dryRunMode
                      ? AppTheme.warning
                      : (vm.isElevated
                          ? AppTheme.success
                          : AppTheme.secondaryCyan),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton({
    required int index,
    required int currentIndex,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isSelected = index == currentIndex;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.surfaceHighest : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isSelected ? AppTheme.primaryAccent : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected
                  ? AppTheme.secondaryCyan
                  : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color:
                    isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiffAndSummaryTab(IpSetterViewModel vm) {
    final profile = vm.selectedProfile!;
    final diffs = vm.currentDiffFields;
    final rangeSummary = profile.isDhcp
        ? 'Dynamic DHCP lease (IP, Subnet Mask, Gateway & DNS assigned by router)'
        : Ipv4Utils.describeSubnetRange(
            profile.ipAddress,
            profile.cidrPrefix ?? Ipv4Utils.maskToCidr(profile.subnetMask) ?? 24,
          );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Side-by-side Live NIC vs Target Preset Diff Table
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  Container(
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: const BoxDecoration(
                      color: AppTheme.surfaceHighest,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(5),
                      ),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 130,
                          child: Text(
                            'PARAMETER',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'CURRENT LIVE NIC',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        SizedBox(width: 24),
                        Expanded(
                          child: Text(
                            'TARGET PRESET STATE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.secondaryCyan,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: diffs.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: AppTheme.border),
                      itemBuilder: (context, i) {
                        final d = diffs[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4.5,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 130,
                                child: Text(
                                  d.label,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  d.currentValue,
                                  style: d.isMonospace
                                      ? AppTheme.monoStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary,
                                        )
                                      : const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary,
                                        ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(
                                width: 24,
                                child: Icon(
                                  d.isChanged
                                      ? Icons.trending_flat
                                      : Icons.check,
                                  size: 13,
                                  color: d.isChanged
                                      ? AppTheme.warning
                                      : AppTheme.success,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  d.targetValue,
                                  style: d.isMonospace
                                      ? AppTheme.monoStyle(
                                          fontSize: 11,
                                          fontWeight: d.isChanged
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: d.isChanged
                                              ? AppTheme.warning
                                              : AppTheme.success,
                                        )
                                      : TextStyle(
                                          fontSize: 11,
                                          fontWeight: d.isChanged
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: d.isChanged
                                              ? AppTheme.warning
                                              : AppTheme.success,
                                        ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Right: Subnet Range Calculator & Equipment Notes Card
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CALCULATED SUBNET & METADATA',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.cliCardBackground,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: AppTheme.cliCardBorder),
                    ),
                    child: Text(
                      rangeSummary,
                      style: AppTheme.monoStyle(
                        fontSize: 11,
                        color: AppTheme.secondaryCyan,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (profile.notes.isNotEmpty) ...[
                    const Text(
                      'Notes:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Expanded(
                      child: Text(
                        profile.notes,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FilledButton.icon(
                        onPressed: vm.isApplying
                            ? null
                            : () => vm.applyProfile(profile),
                        icon: const Icon(Icons.bolt, size: 15),
                        label: Text(
                          'Apply "${profile.name}" Now',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Section 5.5 of UI_AND_DESIGN_PRINCIPLES.md: CLI & Command Preview Card (#0F141C with #30363D border)
  Widget _buildCliPreviewCardTab(IpSetterViewModel vm) {
    final commands = vm.previewCliCommands;
    final joinedCommands = commands.join('\n');

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cliCardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cliCardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppTheme.cliCardBorder),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.terminal,
                    size: 15,
                    color: AppTheme.secondaryCyan,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Generated Command',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Platform Preview Switcher (Windows / macOS / Linux)
                  for (final plat in TargetOsPlatform.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () => vm.setPreviewPlatform(plat),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: vm.previewPlatform == plat
                                ? AppTheme.primaryAccent.withValues(alpha: 0.25)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: vm.previewPlatform == plat
                                  ? AppTheme.primaryAccent
                                  : AppTheme.cliCardBorder,
                            ),
                          ),
                          child: Text(
                            plat.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: vm.previewPlatform == plat
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: vm.previewPlatform == plat
                                  ? AppTheme.secondaryCyan
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _copyToClipboard(joinedCommands),
                    icon: Icon(
                      _copiedConfirmation ? Icons.check : Icons.copy,
                      size: 13,
                      color: _copiedConfirmation
                          ? AppTheme.success
                          : AppTheme.secondaryCyan,
                    ),
                    label: Text(
                      _copiedConfirmation ? 'Copied' : 'Copy',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _copiedConfirmation
                            ? AppTheme.success
                            : AppTheme.secondaryCyan,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Selectable Monospace Command Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  commands.isEmpty
                      ? '# Select an interface and preset to generate commands'
                      : commands.map((c) => '\$ $c').join('\n'),
                  style: AppTheme.monoStyle(
                    fontSize: 12,
                    color: AppTheme.textPrimary,
                    height: 1.55,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutionLogsTab(IpSetterViewModel vm) {
    final logs = vm.executionLogs;
    if (logs.isEmpty) {
      return const Center(
        child: Text(
          'No profile switches executed yet in this session.',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'RECENT ADAPTER CONFIGURATION & PING VERIFICATION LOGS',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: vm.clearExecutionHistory,
                icon: const Icon(Icons.delete_sweep_outlined, size: 14),
                label: const Text(
                  'Clear Logs',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          Expanded(
            child: ListView.separated(
              itemCount: logs.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppTheme.border),
              itemBuilder: (context, index) {
                final log = logs[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusBadge(
                        label: log.isDryRun
                            ? 'DRY-RUN'
                            : (log.isSuccess ? 'OK (0)' : 'ERR (${log.exitCode})'),
                        color: log.isDryRun
                            ? AppTheme.warning
                            : (log.isSuccess ? AppTheme.success : AppTheme.error),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        log.formattedTimestamp,
                        style: AppTheme.monoStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${log.profileName} → ${log.interfaceName}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SelectableText(
                          log.stderr.isNotEmpty ? log.stderr : log.stdout,
                          style: AppTheme.monoStyle(
                            fontSize: 11,
                            color: log.stderr.isNotEmpty
                                ? AppTheme.error
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $hh:$mm:$ss';
  }
}
