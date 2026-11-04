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

  const ProfileDataTable({
    super.key,
    required this.onEditProfile,
    required this.onNewProfile,
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

  static const double _actionsColWidth = 148;

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<IpSetterViewModel>();
    final profiles = vm.filteredProfiles;

    if (profiles.isEmpty) {
      return _buildEmptyState(context, vm);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final fixedTotal = _columnWidths.values.fold(0.0, (a, b) => a + b) +
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
                          final isActive =
                              vm.isProfileActiveOnSelectedNic(profile);
                          return _ProfileRowWidget(
                            profile: profile,
                            isSelected: isSelected,
                            isActive: isActive,
                            columnWidths: _columnWidths,
                            summaryWidth: summaryWidth,
                            actionsWidth: _actionsColWidth,
                            isApplying: vm.isApplying,
                            onSelect: () => vm.selectProfile(profile),
                            onApply: () => vm.applyProfile(profile),
                            onToggleFavorite: () => vm.toggleFavorite(profile),
                            onEdit: () => widget.onEditProfile(profile),
                            onDuplicate: () => vm.duplicateProfile(profile),
                            onDelete: () => vm.deleteProfile(profile.id),
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
    );
  }

  Widget _buildHeaderRow(IpSetterViewModel vm, double summaryWidth) {
    return Container(
      height: 32,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceHighest,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
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
            child: const Text(
              'EQUIPMENT / SUBNET NOTES',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
                letterSpacing: 0.5,
              ),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            vm.hasActiveFilters
                ? Icons.filter_alt_off_outlined
                : Icons.radar,
            size: 56,
            color: AppTheme.primaryAccent.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 14),
          Text(
            vm.hasActiveFilters
                ? 'No Presets Match Active Filter'
                : 'No IP Profiles Configured',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            vm.hasActiveFilters
                ? 'Clear your search query or category filter to view all saved adapter presets.'
                : 'Create a custom static IPv4 preset or restore the built-in field & lab presets.',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: vm.hasActiveFilters
                    ? vm.clearAllFilters
                    : widget.onNewProfile,
                icon: Icon(
                  vm.hasActiveFilters ? Icons.clear_all : Icons.add,
                  size: 16,
                ),
                label: Text(
                  vm.hasActiveFilters ? 'Clear All Filters' : 'Create New Preset',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryAccent,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: vm.resetToDefaultPresets,
                icon: const Icon(Icons.restore, size: 16),
                label: const Text('Load Built-in Demo Presets'),
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

  Color _categoryColor(String category) {
    switch (category.toUpperCase()) {
      case 'LAB':
        return AppTheme.secondaryCyan;
      case 'FIELD':
        return AppTheme.warning;
      case 'OFFICE':
        return AppTheme.success;
      case 'VLAN':
        return const Color(0xFFA855F7);
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
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
                          color: _categoryColor(p.category)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _categoryColor(p.category)
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          p.category.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: _categoryColor(p.category),
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
