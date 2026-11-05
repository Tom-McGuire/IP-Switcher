import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/models/profile_category_model.dart';
import '../../theme/app_theme.dart';
import '../view_models/ip_setter_view_model.dart';

class AddEditCategoryDialog extends StatefulWidget {
  final ProfileCategoryModel? existingCategory;

  const AddEditCategoryDialog({
    super.key,
    this.existingCategory,
  });

  @override
  State<AddEditCategoryDialog> createState() => _AddEditCategoryDialogState();
}

class _AddEditCategoryDialogState extends State<AddEditCategoryDialog> {
  final _nameCtrl = TextEditingController();
  late int _selectedColorHex;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    if (widget.existingCategory != null) {
      _nameCtrl.text = widget.existingCategory!.name;
      _selectedColorHex = widget.existingCategory!.colorHex;
    } else {
      _selectedColorHex = ProfileCategoryModel.presetColors.first;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim().toUpperCase();
    if (name.isEmpty) {
      setState(() => _errorText = 'Category name is required');
      return;
    }
    if (['ALL', 'FAVORITES', 'STATIC', 'DHCP'].contains(name)) {
      setState(() => _errorText = '"$name" is reserved for built-in mode filters');
      return;
    }

    final vm = context.read<IpSetterViewModel>();
    final category = ProfileCategoryModel(
      id: widget.existingCategory?.id ??
          'cat-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      colorHex: _selectedColorHex,
      isVisible: widget.existingCategory?.isVisible ?? true,
    );

    await vm.addOrUpdateCategory(
      category,
      previousName: widget.existingCategory?.name,
    );

    if (mounted) {
      Navigator.of(context).pop(category);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existingCategory;
    if (existing == null) return;
    final vm = context.read<IpSetterViewModel>();
    await vm.deleteCategory(existing);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingCategory != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(_selectedColorHex),
                    radius: 12,
                    child: const Icon(
                      Icons.label,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEdit ? 'Edit Category' : 'Add Category',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'e.g., LAB, VLAN 20, STAGE, CCTV',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 16),
              const Text(
                'Color Badge:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: ProfileCategoryModel.presetColors.map((hex) {
                  final isSelected = _selectedColorHex == hex;
                  return InkWell(
                    onTap: () => setState(() => _selectedColorHex = hex),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(hex),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 2.5)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Color(hex).withValues(alpha: 0.5),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isEdit) ...[
                    TextButton.icon(
                      onPressed: _delete,
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: Colors.redAccent,
                      ),
                      label: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                    const Spacer(),
                  ],
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _save,
                    child: Text(isEdit ? 'Save Changes' : 'Add Category'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ManageCategoriesDialog extends StatelessWidget {
  const ManageCategoriesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<IpSetterViewModel>();
    final categories = vm.categories;
    final counts = vm.categoryCounts;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.bookmarks_outlined,
                    size: 20,
                    color: AppTheme.primaryAccent,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Manage Filter Categories',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Category'),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const AddEditCategoryDialog(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Assign colors, toggle filter bar visibility, or rename/create preset categories.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const Divider(height: 20),
              Expanded(
                child: categories.isEmpty
                    ? const Center(
                        child: Text(
                          'No categories defined.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        itemCount: categories.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          final count = counts[cat.name.toUpperCase()] ?? 0;
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              backgroundColor: Color(cat.colorHex),
                              radius: 12,
                              child: const Icon(
                                Icons.label,
                                size: 13,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              cat.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                decoration: cat.isVisible
                                    ? null
                                    : TextDecoration.lineThrough,
                                color: cat.isVisible
                                    ? AppTheme.textPrimary
                                    : AppTheme.textMuted,
                              ),
                            ),
                            subtitle: Text(
                              '$count preset${count == 1 ? '' : 's'}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    cat.isVisible
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    size: 18,
                                    color: cat.isVisible
                                        ? Colors.blueAccent
                                        : Colors.grey,
                                  ),
                                  tooltip: cat.isVisible
                                      ? 'Hide from Filter Bar'
                                      : 'Show in Filter Bar',
                                  onPressed: () =>
                                      vm.toggleCategoryVisibility(cat),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  tooltip: 'Edit Name & Color',
                                  onPressed: () => showDialog(
                                    context: context,
                                    builder: (_) => AddEditCategoryDialog(
                                      existingCategory: cat,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: Colors.redAccent,
                                  ),
                                  tooltip: 'Delete Category',
                                  onPressed: () => vm.deleteCategory(cat),
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
    );
  }
}
