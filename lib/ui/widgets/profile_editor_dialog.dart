import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/models/ip_profile_model.dart';
import '../../domain/models/ipv4_utils.dart';
import '../../domain/models/profile_category_model.dart';
import '../../theme/app_theme.dart';
import '../view_models/ip_setter_view_model.dart';
import 'category_dialogs.dart';

class ProfileEditorDialog extends StatefulWidget {
  final IpProfileModel? initialProfile;
  final IpProfileModel Function() onSnapshotActiveNic;

  const ProfileEditorDialog({
    super.key,
    this.initialProfile,
    required this.onSnapshotActiveNic,
  });

  @override
  State<ProfileEditorDialog> createState() => _ProfileEditorDialogState();
}

class _ProfileEditorDialogState extends State<ProfileEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late String _category;
  late bool _isDhcp;
  late bool _isFavorite;
  late TextEditingController _ipCtrl;
  late TextEditingController _maskCtrl;
  late TextEditingController _cidrCtrl;
  late TextEditingController _gwCtrl;
  late TextEditingController _dns1Ctrl;
  late TextEditingController _dns2Ctrl;
  late TextEditingController _aliasesCtrl;
  late TextEditingController _vlanCtrl;
  late TextEditingController _mtuCtrl;
  late TextEditingController _notesCtrl;

  bool _syncingMaskCidr = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _category = p?.category.toUpperCase() ?? 'LAB';
    _isDhcp = p?.isDhcp ?? false;
    _isFavorite = p?.isFavorite ?? false;

    _ipCtrl = TextEditingController(text: p?.ipAddress ?? '192.168.1.50');
    final initCidr = p?.cidrPrefix ?? Ipv4Utils.maskToCidr(p?.subnetMask) ?? 24;
    _cidrCtrl = TextEditingController(text: initCidr.toString());
    _maskCtrl = TextEditingController(
      text: p?.subnetMask ?? Ipv4Utils.cidrToMask(initCidr),
    );
    _gwCtrl = TextEditingController(text: p?.defaultGateway ?? '192.168.1.1');
    _dns1Ctrl = TextEditingController(text: p?.primaryDns ?? '1.1.1.1');
    _dns2Ctrl = TextEditingController(text: p?.secondaryDns ?? '8.8.8.8');
    _aliasesCtrl = TextEditingController(
      text: p?.secondaryIps.join(', ') ?? '',
    );
    _vlanCtrl = TextEditingController(
      text: p?.vlanId?.toString() ?? '',
    );
    _mtuCtrl = TextEditingController(
      text: p?.mtu?.toString() ?? '',
    );
    _notesCtrl = TextEditingController(text: p?.notes ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ipCtrl.dispose();
    _maskCtrl.dispose();
    _cidrCtrl.dispose();
    _gwCtrl.dispose();
    _dns1Ctrl.dispose();
    _dns2Ctrl.dispose();
    _aliasesCtrl.dispose();
    _vlanCtrl.dispose();
    _mtuCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onCidrChanged(String val) {
    if (_syncingMaskCidr) return;
    final parsed = int.tryParse(val.trim());
    if (parsed != null && parsed >= 0 && parsed <= 32) {
      _syncingMaskCidr = true;
      _maskCtrl.text = Ipv4Utils.cidrToMask(parsed);
      _syncingMaskCidr = false;
      setState(() {});
    }
  }

  void _onMaskChanged(String val) {
    if (_syncingMaskCidr) return;
    final cidr = Ipv4Utils.maskToCidr(val.trim());
    if (cidr != null) {
      _syncingMaskCidr = true;
      _cidrCtrl.text = cidr.toString();
      _syncingMaskCidr = false;
      setState(() {});
    }
  }

  void _populateFromActiveNic() {
    final snap = widget.onSnapshotActiveNic();
    setState(() {
      if (_nameCtrl.text.trim().isEmpty) {
        _nameCtrl.text = snap.name;
      }
      _isDhcp = snap.isDhcp;
      _ipCtrl.text = snap.ipAddress ?? '';
      _maskCtrl.text = snap.subnetMask ?? '255.255.255.0';
      _cidrCtrl.text = (snap.cidrPrefix ?? 24).toString();
      _gwCtrl.text = snap.defaultGateway ?? '';
      _dns1Ctrl.text = snap.primaryDns ?? '';
      _dns2Ctrl.text = snap.secondaryDns ?? '';
      _aliasesCtrl.text = snap.secondaryIps.join(', ');
      if (_notesCtrl.text.trim().isEmpty) {
        _notesCtrl.text = snap.notes;
      }
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final aliases = _aliasesCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final cidr = int.tryParse(_cidrCtrl.text.trim()) ??
        Ipv4Utils.maskToCidr(_maskCtrl.text.trim()) ??
        24;

    final result = IpProfileModel(
      id: widget.initialProfile?.id ??
          'profile-${DateTime.now().microsecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      category: _category,
      isDhcp: _isDhcp,
      ipAddress: _isDhcp ? null : _ipCtrl.text.trim(),
      subnetMask: _isDhcp ? null : _maskCtrl.text.trim(),
      cidrPrefix: _isDhcp ? null : cidr,
      defaultGateway: _isDhcp ? null : _gwCtrl.text.trim(),
      primaryDns: _dns1Ctrl.text.trim().isEmpty ? null : _dns1Ctrl.text.trim(),
      secondaryDns:
          _dns2Ctrl.text.trim().isEmpty ? null : _dns2Ctrl.text.trim(),
      secondaryIps: _isDhcp ? const [] : aliases,
      vlanId: int.tryParse(_vlanCtrl.text.trim()),
      mtu: int.tryParse(_mtuCtrl.text.trim()),
      notes: _notesCtrl.text.trim(),
      isFavorite: _isFavorite,
      lastAppliedAt: widget.initialProfile?.lastAppliedAt,
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<IpSetterViewModel>();
    final categoryModels = vm.categories.isNotEmpty
        ? vm.categories
        : ProfileCategoryModel.defaultCategories;
    final categoryNames =
        categoryModels.map((c) => c.name.toUpperCase()).toList();
    if (!categoryNames.contains(_category)) {
      categoryNames.add(_category);
    }

    final currentCidr = int.tryParse(_cidrCtrl.text.trim());
    final subnetPreview = _isDhcp
        ? 'DHCP Mode: IP, Subnet Mask & Default Gateway will be requested automatically.'
        : Ipv4Utils.describeSubnetRange(_ipCtrl.text.trim(), currentCidr);

    return Dialog(
      child: Container(
        width: 620,
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dialog Header
                Row(
                  children: [
                    const Icon(
                      Icons.tune,
                      size: 18,
                      color: AppTheme.secondaryCyan,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.initialProfile == null
                          ? 'Create IP Profile Preset'
                          : 'Edit IP Profile Preset',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _populateFromActiveNic,
                      icon: const Icon(Icons.download_outlined, size: 14),
                      label: const Text(
                        'Populate from Active NIC',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),

                // Name, Category, Favorite Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _nameCtrl,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          labelText: 'Preset Name *',
                          hintText: 'e.g., Lab Static, VLAN 20 Test',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Preset name is required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(_category),
                        initialValue: _category,
                        dropdownColor: AppTheme.surfaceHigh,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Category Tag',
                        ),
                        items: categoryNames
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 5,
                                      backgroundColor: vm.getCategoryColor(c),
                                    ),
                                    const SizedBox(width: 7),
                                    Text(c),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _category = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Create a new category with a custom color',
                      child: InkWell(
                        onTap: () async {
                          final created =
                              await showDialog<ProfileCategoryModel>(
                            context: context,
                            builder: (_) => const AddEditCategoryDialog(),
                          );
                          if (created != null && mounted) {
                            setState(() => _category = created.name);
                          }
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          height: 36,
                          width: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.inputFill,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.inputBorder),
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 16,
                            color: AppTheme.secondaryCyan,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () => setState(() => _isFavorite = !_isFavorite),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.inputFill,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _isFavorite
                                ? AppTheme.warning
                                : AppTheme.inputBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isFavorite ? Icons.star : Icons.star_border,
                              size: 16,
                              color: _isFavorite
                                  ? AppTheme.warning
                                  : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'Pin',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Static vs DHCP Segmented Toggle
                Row(
                  children: [
                    const Text(
                      'IPv4 Mode:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text(
                        'STATIC IPv4',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      selected: !_isDhcp,
                      onSelected: (_) => setState(() => _isDhcp = false),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text(
                        'AUTOMATIC (DHCP)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      selected: _isDhcp,
                      onSelected: (_) => setState(() => _isDhcp = true),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Static IPv4 Fields
                if (!_isDhcp) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _ipCtrl,
                          onChanged: (_) => setState(() {}),
                          style: AppTheme.monoStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            labelText: 'IPv4 Address *',
                            hintText: '192.168.1.50',
                          ),
                          validator: (v) => Ipv4Utils.isValidIpv4(v)
                              ? null
                              : 'Invalid IPv4 address',
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 85,
                        child: TextFormField(
                          controller: _cidrCtrl,
                          onChanged: _onCidrChanged,
                          style: AppTheme.monoStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            labelText: 'CIDR *',
                            prefixText: '/',
                          ),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n < 1 || n > 32) return '1-32';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _maskCtrl,
                          onChanged: _onMaskChanged,
                          style: AppTheme.monoStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            labelText: 'Subnet Mask *',
                            hintText: '255.255.255.0',
                          ),
                          validator: (v) => Ipv4Utils.isValidSubnetMask(v)
                              ? null
                              : 'Invalid subnet mask',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Live Calculated Subnet Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.cliCardBackground,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: AppTheme.cliCardBorder),
                    ),
                    child: Text(
                      subnetPreview,
                      style: AppTheme.monoStyle(
                        fontSize: 11,
                        color: AppTheme.secondaryCyan,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _gwCtrl,
                          style: AppTheme.monoStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            labelText: 'Default Gateway (Optional)',
                            hintText: '192.168.1.1 (or leave blank for isolated link)',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            return Ipv4Utils.isValidIpv4(v)
                                ? null
                                : 'Invalid Gateway IPv4';
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _aliasesCtrl,
                          style: AppTheme.monoStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            labelText: 'Secondary Alias IPs (Optional)',
                            hintText: 'e.g. 192.168.10.50/24',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final items = v
                                .split(',')
                                .map((s) => s.trim())
                                .where((s) => s.isNotEmpty);
                            for (final alias in items) {
                              final parts = alias.split('/');
                              if (!Ipv4Utils.isValidIpv4(parts.first)) {
                                return 'Invalid alias IPv4: $alias';
                              }
                              if (parts.length > 1) {
                                final pfx = int.tryParse(parts[1]);
                                if (pfx == null || pfx < 1 || pfx > 32) {
                                  return 'Invalid alias CIDR: $alias';
                                }
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // DNS Servers & VLAN/MTU Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dns1Ctrl,
                        style: AppTheme.monoStyle(fontSize: 12),
                        decoration: InputDecoration(
                          labelText: _isDhcp
                              ? 'Override Primary DNS (Optional)'
                              : 'Primary DNS',
                          hintText: '1.1.1.1',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          return Ipv4Utils.isValidIpv4(v)
                              ? null
                              : 'Invalid DNS IPv4';
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _dns2Ctrl,
                        style: AppTheme.monoStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          labelText: 'Secondary DNS',
                          hintText: '8.8.8.8',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          return Ipv4Utils.isValidIpv4(v)
                              ? null
                              : 'Invalid DNS IPv4';
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 110,
                      child: Tooltip(
                        message: 'Informational VLAN reference tag (1–4094)',
                        child: TextFormField(
                          controller: _vlanCtrl,
                          style: AppTheme.monoStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            labelText: 'VLAN Tag (Info)',
                            hintText: '20',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final n = int.tryParse(v.trim());
                            if (n == null || n < 1 || n > 4094) {
                              return '1–4094';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 90,
                      child: TextFormField(
                        controller: _mtuCtrl,
                        style: AppTheme.monoStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          labelText: 'MTU',
                          hintText: '1500',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final n = int.tryParse(v.trim());
                          if (n == null || n < 576 || n > 9216) {
                            return '576–9216';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Notes Field
                TextFormField(
                  controller: _notesCtrl,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Equipment / Rack / Location Notes',
                    hintText:
                        'e.g. Rack B Allen-Bradley PLC or Art-Net lighting dimmer trunk',
                  ),
                ),
                const SizedBox(height: 16),

                // Dialog Footer Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_outlined, size: 15),
                      label: const Text('Save Preset'),
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
      ),
    );
  }
}
