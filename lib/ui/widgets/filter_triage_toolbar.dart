import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../view_models/ip_setter_view_model.dart';
import 'status_badge.dart';

class FilterTriageToolbar extends StatefulWidget {
  final VoidCallback onSnapshotActiveNic;

  const FilterTriageToolbar({
    super.key,
    required this.onSnapshotActiveNic,
  });

  @override
  State<FilterTriageToolbar> createState() => _FilterTriageToolbarState();
}

class _FilterTriageToolbarState extends State<FilterTriageToolbar> {
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _filterChips = [
    'ALL',
    'FAVORITES',
    'STATIC',
    'DHCP',
    'LAB',
    'FIELD',
    'OFFICE',
    'VLAN',
    'CUSTOM',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<IpSetterViewModel>();
    if (_searchController.text != vm.searchQuery) {
      _searchController.value = TextEditingValue(
        text: vm.searchQuery,
        selection: TextSelection.collapsed(offset: vm.searchQuery.length),
      );
    }

    final nic = vm.selectedInterface;
    final ping = vm.lastGatewayPing;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Live NIC Telemetry Strip
          if (nic != null)
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceLow,
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  StatusBadge(
                    label: nic.isUp ? 'LINK UP' : 'LINK DOWN',
                    color: nic.isUp ? AppTheme.success : AppTheme.error,
                    icon: nic.isUp ? Icons.lan : Icons.link_off,
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(
                    label: nic.isDhcpEnabled ? 'DHCP' : 'STATIC',
                    color: nic.isDhcpEnabled
                        ? AppTheme.secondaryCyan
                        : AppTheme.primaryAccent,
                  ),
                  const SizedBox(width: 12),
                  _buildTelemetryMetric('MAC', nic.macAddress),
                  _buildVerticalSeparator(),
                  _buildTelemetryMetric(
                    'IPv4',
                    nic.formattedIpWithCidr,
                    valueColor: AppTheme.secondaryCyan,
                  ),
                  _buildVerticalSeparator(),
                  _buildTelemetryMetric('MASK', nic.formattedSubnet),
                  _buildVerticalSeparator(),
                  _buildTelemetryMetric('GW', nic.formattedGateway),
                  if (ping != null && ping.gatewayIp.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: (ping.isReachable
                                ? AppTheme.success
                                : AppTheme.warning)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: (ping.isReachable
                                  ? AppTheme.success
                                  : AppTheme.warning)
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        ping.isReachable
                            ? '${ping.latencyMs?.toStringAsFixed(1) ?? "<1"} ms'
                            : 'NO REPLY',
                        style: AppTheme.monoStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: ping.isReachable
                              ? AppTheme.success
                              : AppTheme.warning,
                        ),
                      ),
                    ),
                  ],
                  _buildVerticalSeparator(),
                  Expanded(
                    child: _buildTelemetryMetric('DNS', nic.formattedDns),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message:
                        'Save the current live configuration of ${nic.displayName} as a new preset',
                    child: InkWell(
                      onTap: widget.onSnapshotActiveNic,
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceHigh,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.inputBorder),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.camera_alt_outlined,
                              size: 12,
                              color: AppTheme.secondaryCyan,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Snapshot NIC',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Filter & Search Row
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                // Dense Search Input (height 32px)
                SizedBox(
                  width: 280,
                  height: 32,
                  child: TextField(
                    controller: _searchController,
                    onChanged: vm.setSearchQuery,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Filter presets by name, IP, subnet, GW, notes...',
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 15,
                        color: AppTheme.textSecondary,
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      suffixIcon: vm.searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 14),
                              onPressed: () {
                                _searchController.clear();
                                vm.setSearchQuery('');
                              },
                              padding: EdgeInsets.zero,
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Category & Mode Filter Chips
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final chip in _filterChips)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _buildFilterChip(
                              label: chip,
                              isSelected: vm.selectedCategoryFilter == chip,
                              onTap: () => vm.setCategoryFilter(chip),
                            ),
                          ),
                        if (vm.hasActiveFilters)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: ActionChip(
                              visualDensity: VisualDensity.compact,
                              backgroundColor:
                                  AppTheme.error.withValues(alpha: 0.14),
                              side: BorderSide(
                                color: AppTheme.error.withValues(alpha: 0.4),
                              ),
                              avatar: const Icon(
                                Icons.filter_alt_off_outlined,
                                size: 13,
                                color: AppTheme.error,
                              ),
                              label: const Text(
                                'Clear All Filters',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.error,
                                ),
                              ),
                              onPressed: vm.clearAllFilters,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryMetric(
    String label,
    String value, {
    Color valueColor = AppTheme.textPrimary,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: AppTheme.textMuted,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: AppTheme.monoStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalSeparator() {
    return Container(
      height: 14,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: AppTheme.border,
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.surfaceHighest : AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppTheme.primaryAccent : AppTheme.border,
            width: isSelected ? 1.2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label == 'FAVORITES') ...[
              Icon(
                Icons.star,
                size: 12,
                color: isSelected ? AppTheme.warning : AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color:
                    isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
