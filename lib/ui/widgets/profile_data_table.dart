import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/models/ip_profile_model.dart';
import '../../theme/app_theme.dart';
import '../view_models/ip_setter_view_model.dart';
import 'status_badge.dart';

class TableColumnSpec {
  final String id;
  final String label;
  final ProfileSortColumn? sortColumn;
  final double defaultWidth;
  final double minWidth;

  const TableColumnSpec({
    required this.id,
    required this.label,
    this.sortColumn,
    required this.defaultWidth,
    required this.minWidth,
  });
}

class ProfileDataTable extends StatefulWidget {
  final void Function(IpProfileModel profile) onEditProfile;
  final VoidCallback onNewProfile;
  final VoidCallback onSnapshotActiveNic;

  const ProfileDataTable({
    super.key,
    required this.onEditProfile,
    required this.onNewProfile,
    required this.onSnapshotActiveNic,
  });

  @override
  State<ProfileDataTable> createState() => _ProfileDataTableState();
}

class _ProfileDataTableState extends State<ProfileDataTable> {
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  static const List<TableColumnSpec> _columnSpecs = [
    TableColumnSpec(
      id: 'status',
      label: 'STATE',
      sortColumn: ProfileSortColumn.status,
      defaultWidth: 105,
      minWidth: 85,
    ),
    TableColumnSpec(
      id: 'name',
      label: 'PROFILE PRESET',
      sortColumn: ProfileSortColumn.name,
      defaultWidth: 215,
      minWidth: 150,
    ),
    TableColumnSpec(
      id: 'mode',
      label: 'MODE',
      sortColumn: ProfileSortColumn.mode,
      defaultWidth: 95,
      minWidth: 80,
    ),
    TableColumnSpec(
      id: 'ip',
      label: 'IPv4 / CIDR',
      sortColumn: ProfileSortColumn.ipAddress,
      defaultWidth: 150,
      minWidth: 120,
    ),
    TableColumnSpec(
      id: 'mask',
      label: 'SUBNET MASK',
      sortColumn: ProfileSortColumn.subnetMask,
      defaultWidth: 135,
      minWidth: 110,
    ),
    TableColumnSpec(
      id: 'gateway',
      label: 'GATEWAY',
      sortColumn: ProfileSortColumn.gateway,
      defaultWidth: 130,
      minWidth: 105,
    ),
    TableColumnSpec(
      id: 'dns',
      label: 'DNS SERVERS',
      sortColumn: ProfileSortColumn.dns,
      defaultWidth: 155,
      minWidth: 115,
    ),
  ];

  late final Map<String, double> _columnWidths = {
    for (final spec in _columnSpecs) spec.id: spec.defaultWidth,
  };

  static const double _actionsColWidth = 172;

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  Future<void> _confirmDeleteProfile(
    BuildContext context,
    IpSetterViewModel vm,
    IpProfileModel profile,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Delete Preset?',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${profile.name}" (${profile.formattedIpWithCidr})?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await vm.deleteProfile(profile.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<IpSetterViewModel>();
    final profiles = vm.filteredProfiles;
    final applyBlockedByPlaceholder =
        (vm.selectedInterface?.isPlaceholder ?? false) && !vm.dryRunMode;

    return Container(
      decoration: BoxDecoration(
        border: vm.dryRunMode
            ? Border.all(
                color: AppTheme.warning.withValues(alpha: 0.75),
                width: 1.5,
              )
            : null,
      ),
      child: profiles.isEmpty
          ? _buildEmptyState(context, vm)
          : LayoutBuilder(
              builder: (context, constraints) {
                final fixedTotal =
                    _columnWidths.values.fold(0.0, (a, b) => a + b) +
                        _actionsColWidth;
                final summaryWidth =
                    (constraints.maxWidth - fixedTotal).clamp(180.0, 2000.0);
                final totalTableWidth = fixedTotal + summaryWidth;

                return Scrollbar(
                  controller: _horizontalScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: totalTableWidth,
                      height: constraints.maxHeight,
                      child: Column(
                        children: [
                          _buildHeaderRow(vm, summaryWidth),
                          Expanded(
                            child: Scrollbar(
                              controller: _verticalScrollController,
                              thumbVisibility: true,
                              child: ListView.separated(
                                controller: _verticalScrollController,
                                itemCount: profiles.length,
                                separatorBuilder: (_, _) => const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: AppTheme.border,
                                ),
                                itemBuilder: (context, index) {
                                  final profile = profiles[index];
                                  final isSelected =
                                      vm.selectedProfile?.id == profile.id;
                                  final isActive = vm
                                      .isProfileActiveOnSelectedNic(profile);
                                  return _ProfileRowWidget(
                                    profile: profile,
                                    categoryColor:
                                        vm.getCategoryColor(profile.category),
                                    isSelected: isSelected,
                                    isActive: isActive,
                                    columnWidths: _columnWidths,
                                    summaryWidth: summaryWidth,
                                    actionsWidth: _actionsColWidth,
                                    isApplying: vm.isApplying ||
                                        applyBlockedByPlaceholder,
                                    onSelect: () => vm.selectProfile(profile),
                                    onApply: () => vm.applyProfile(profile),
                                    onToggleFavorite: () =>
                                        vm.toggleFavorite(profile),
                                    onEdit: () =>
                                        widget.onEditProfile(profile),
                                    onDuplicate: () =>
                                        vm.duplicateProfile(profile),
                                    onDelete: () => _confirmDeleteProfile(
                                      context,
                                      vm,
                                      profile,
                                    ),
                                  );
                                },
                              ),
                            ),
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

  Widget _buildHeaderRow(IpSetterViewModel vm, double summaryWidth) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: AppTheme.surfaceHighest,
        border: Border(
          bottom: BorderSide(
            color: vm.dryRunMode
                ? AppTheme.warning.withValues(alpha: 0.65)
                : AppTheme.border,
          ),
        ),
      ),
      child: Row(
        children: [
          for (final spec in _columnSpecs)
            _buildResizableHeaderCell(
              spec: spec,
              width: _columnWidths[spec.id]!,
              isSorted: vm.sortColumn == spec.sortColumn,
              ascending: vm.sortAscending,
              onSort: spec.sortColumn != null
                  ? () => vm.setSortColumn(spec.sortColumn!)
                  : null,
              onResize: (delta) {
                setState(() {
                  _columnWidths[spec.id] = (_columnWidths[spec.id]! + delta)
                      .clamp(spec.minWidth, 480.0);
                });
              },
            ),
          // Auto-fill Notes / Equipment Summary Column
          Container(
            width: summaryWidth,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.centerLeft,
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'EQUIPMENT / SUBNET NOTES',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (vm.dryRunMode)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppTheme.warning.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Text(
                      'DRY-RUN TABLE BORDER',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.warning,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Actions Column
          Container(
            width: _actionsColWidth,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            child: const Text(
              'QUICK ACTIONS',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResizableHeaderCell({
    required TableColumnSpec spec,
    required double width,
    required bool isSorted,
    required bool ascending,
    required VoidCallback? onSort,
    required void Function(double delta) onResize,
  }) {
    return SizedBox(
      width: width,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onSort,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        spec.label,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isSorted
                              ? AppTheme.secondaryCyan
                              : AppTheme.textSecondary,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSorted)
                      Icon(
                        ascending ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 12,
                        color: AppTheme.secondaryCyan,
                      ),
                  ],
                ),
              ),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (details) => onResize(details.delta.dx),
              child: Container(
                width: 6,
                height: 32,
                alignment: Alignment.centerRight,
                child: Container(
                  width: 1,
                  height: 32,
                  color: AppTheme.border,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, IpSetterViewModel vm) {
    final hasActiveFilter = vm.hasActiveFilters;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasActiveFilter
                ? Icons.filter_alt_off_outlined
                : Icons.lan_outlined,
            size: 54,
            color: Colors.grey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            hasActiveFilter
                ? 'No presets match your active search filters'
                : 'No IP Profile Presets Loaded',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            hasActiveFilter
                ? 'Try clearing your search query or category filter chips'
                : 'Create a custom preset above, snapshot your active network interface, or load the demo presets.',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          if (hasActiveFilter)
            FilledButton.tonalIcon(
              icon: const Icon(Icons.filter_alt_off, size: 16),
              label: const Text('Reset All Filters'),
              onPressed: vm.clearAllFilters,
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Preset'),
                  onPressed: widget.onNewProfile,
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                  label: const Text('Snapshot Active NIC'),
                  onPressed: widget.onSnapshotActiveNic,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Load Demo Presets'),
                  onPressed: () => vm.loadDemoPresets(),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ProfileRowWidget extends StatefulWidget {
  final IpProfileModel profile;
  final Color categoryColor;
  final bool isSelected;
  final bool isActive;
  final Map<String, double> columnWidths;
  final double summaryWidth;
  final double actionsWidth;
  final bool isApplying;
  final VoidCallback onSelect;
  final VoidCallback onApply;
  final VoidCallback onToggleFavorite;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _ProfileRowWidget({
    required this.profile,
    required this.categoryColor,
    required this.isSelected,
    required this.isActive,
    required this.columnWidths,
    required this.summaryWidth,
    required this.actionsWidth,
    required this.isApplying,
    required this.onSelect,
    required this.onApply,
    required this.onToggleFavorite,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  State<_ProfileRowWidget> createState() => _ProfileRowWidgetState();
}

class _ProfileRowWidgetState extends State<_ProfileRowWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final catColor = widget.categoryColor;
    final rowBg = widget.isSelected
        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
        : (_isHovered ? AppTheme.surfaceHigh : Colors.transparent);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onSelect,
        onDoubleTap: widget.onEdit,
        child: Container(
          height: 38,
          color: rowBg,
          child: Row(
            children: [
              // 1. State Column
              SizedBox(
                width: widget.columnWidths['status']!,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: StatusBadge(
                      label: widget.isActive ? 'ACTIVE' : 'READY',
                      color: widget.isActive
                          ? AppTheme.success
                          : AppTheme.textSecondary,
                      icon: widget.isActive
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                    ),
                  ),
                ),
              ),

              // 2. Profile Name + Favorite + Category Tag
              SizedBox(
                width: widget.columnWidths['name']!,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: widget.onToggleFavorite,
                        child: Icon(
                          p.isFavorite ? Icons.star : Icons.star_border,
                          size: 15,
                          color: p.isFavorite
                              ? AppTheme.warning
                              : AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: catColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          p.category.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: catColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Mode Column
              SizedBox(
                width: widget.columnWidths['mode']!,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: StatusBadge(
                      label: p.isDhcp ? 'DHCP' : 'STATIC',
                      color: p.isDhcp
                          ? AppTheme.success
                          : AppTheme.primaryAccent,
                    ),
                  ),
                ),
              ),

              // 4. IPv4 / CIDR (Monospace)
              SizedBox(
                width: widget.columnWidths['ip']!,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    p.formattedIpWithCidr,
                    style: AppTheme.monoStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: p.isDhcp
                          ? AppTheme.success
                          : AppTheme.secondaryCyan,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // 5. Subnet Mask (Monospace)
              SizedBox(
                width: widget.columnWidths['mask']!,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    p.formattedSubnetMask,
                    style: AppTheme.monoStyle(
                      fontSize: 11.5,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // 6. Default Gateway (Monospace)
              SizedBox(
                width: widget.columnWidths['gateway']!,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    p.formattedGateway,
                    style: AppTheme.monoStyle(
                      fontSize: 11.5,
                      color: p.formattedGateway == '—'
                          ? AppTheme.textMuted
                          : AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // 7. DNS Servers (Monospace)
              SizedBox(
                width: widget.columnWidths['dns']!,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    p.formattedDns,
                    style: AppTheme.monoStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // 8. Notes / Summary Column (Auto-fill)
              SizedBox(
                width: widget.summaryWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      if (p.vlanId != null) ...[
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceHighest,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.inputBorder),
                          ),
                          child: Text(
                            'VLAN ${p.vlanId}',
                            style: AppTheme.monoStyle(
                              fontSize: 10,
                              color: AppTheme.secondaryCyan,
                            ),
                          ),
                        ),
                      ],
                      if (p.secondaryIps.isNotEmpty) ...[
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '+${p.secondaryIps.length} Alias',
                            style: AppTheme.monoStyle(
                              fontSize: 10,
                              color: AppTheme.warning,
                            ),
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          p.notes.isNotEmpty ? p.notes : '—',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 9. Quick Actions Column
              SizedBox(
                width: widget.actionsWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 25,
                        child: FilledButton(
                          onPressed: widget.isApplying ? null : widget.onApply,
                          style: FilledButton.styleFrom(
                            backgroundColor: widget.isActive
                                ? AppTheme.success.withValues(alpha: 0.25)
                                : AppTheme.primaryAccent,
                            foregroundColor: widget.isActive
                                ? AppTheme.success
                                : Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                              side: widget.isActive
                                  ? BorderSide(
                                      color: AppTheme.success
                                          .withValues(alpha: 0.5),
                                    )
                                  : BorderSide.none,
                            ),
                          ),
                          child: Text(
                            widget.isActive ? 'Re-Apply' : 'Apply',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Edit Preset',
                        icon: const Icon(Icons.edit_outlined, size: 15),
                        onPressed: widget.onEdit,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 26,
                          minHeight: 26,
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'More Actions',
                        icon: const Icon(Icons.more_vert, size: 15),
                        padding: EdgeInsets.zero,
                        color: AppTheme.surfaceHigh,
                        onSelected: (val) {
                          if (val == 'duplicate') widget.onDuplicate();
                          if (val == 'delete') widget.onDelete();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'duplicate',
                            height: 32,
                            child: Row(
                              children: [
                                Icon(Icons.copy, size: 14),
                                SizedBox(width: 8),
                                Text(
                                  'Duplicate Preset',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            height: 32,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 14,
                                  color: AppTheme.error,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Delete Preset',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.error,
                                  ),
                                ),
                              ],
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
        ),
      ),
    );
  }
}
