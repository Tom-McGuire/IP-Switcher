import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../view_models/ip_setter_view_model.dart';
import 'category_dialogs.dart';
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

  static const List<String> _modeChips = [
    'ALL',
    'FAVORITES',
    'STATIC',
    'DHCP',
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
    final counts = vm.categoryCounts;
    final visibleCategories = vm.visibleCategories;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Live NIC Telemetry Strip
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

          // 2. Search & Mode Filter Row + Packet-Inspector Style Categories Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top sub-row: Search Input + Mode Chips + Manage Categories Button
                Row(
                  children: [
                    SizedBox(
                      width: 300,
                      height: 32,
                      child: TextField(
                        controller: _searchController,
                        onChanged: vm.setSearchQuery,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Filter presets by name, IP, subnet, GW, notes...',
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
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final mode in _modeChips)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: FilterChip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: mode == 'FAVORITES'
                                      ? Icon(
                                          Icons.star,
                                          size: 13,
                                          color: vm.selectedModeFilter == mode
                                              ? AppTheme.warning
                                              : AppTheme.textSecondary,
                                        )
                                      : null,
                                  label: Text(
                                    mode,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  selected: vm.selectedModeFilter == mode &&
                                      (mode != 'ALL' ||
                                          vm.selectedCategories.isEmpty),
                                  onSelected: (_) {
                                    if (mode == 'ALL') {
                                      vm.clearAllFilters();
                                    } else {
                                      vm.setModeFilter(mode);
                                    }
                                  },
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
                                    color:
                                        AppTheme.error.withValues(alpha: 0.4),
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
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.bookmarks_outlined, size: 15),
                      label: const Text(
                        'Categories',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => const ManageCategoriesDialog(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Bottom sub-row: Packet-Inspector style Categories Filter Row
                Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.label_outline,
                            size: 14,
                            color: Colors.blueAccent,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Categories',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ...visibleCategories.map((cat) {
                              final count =
                                  counts[cat.name.toUpperCase()] ?? 0;
                              final isSelected =
                                  vm.isCategorySelected(cat.name);
                              final catColor = Color(cat.colorHex);
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Tooltip(
                                  message:
                                      'Click to filter by ${cat.name} • Right-click to edit name & color',
                                  child: GestureDetector(
                                    onSecondaryTap: () => showDialog(
                                      context: context,
                                      builder: (_) => AddEditCategoryDialog(
                                        existingCategory: cat,
                                      ),
                                    ),
                                    child: FilterChip(
                                      visualDensity: VisualDensity.compact,
                                      avatar: CircleAvatar(
                                        radius: 5,
                                        backgroundColor: catColor,
                                      ),
                                      label: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${cat.name} ($count)',
                                            style:
                                                const TextStyle(fontSize: 11),
                                          ),
                                          const SizedBox(width: 4),
                                          InkWell(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            onTap: () => showDialog(
                                              context: context,
                                              builder: (_) =>
                                                  AddEditCategoryDialog(
                                                existingCategory: cat,
                                              ),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(1.5),
                                              child: Icon(
                                                Icons.edit_outlined,
                                                size: 11,
                                                color: AppTheme.textSecondary
                                                    .withValues(alpha: 0.75),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      selected: isSelected,
                                      selectedColor:
                                          catColor.withValues(alpha: 0.22),
                                      side: BorderSide(
                                        color: isSelected
                                            ? catColor
                                            : AppTheme.border,
                                      ),
                                      onSelected: (_) =>
                                          vm.toggleCategoryPill(cat.name),
                                    ),
                                  ),
                                ),
                              );
                            }),
                            ActionChip(
                              visualDensity: VisualDensity.compact,
                              avatar: const Icon(Icons.add, size: 14),
                              label: const Text(
                                'Add Category',
                                style: TextStyle(fontSize: 11),
                              ),
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) => const AddEditCategoryDialog(),
                              ),
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
}
