class ProfileCategoryModel {
  final String id;
  final String name;
  final int colorHex;
  final bool isVisible;

  const ProfileCategoryModel({
    required this.id,
    required this.name,
    required this.colorHex,
    this.isVisible = true,
  });

  static const List<int> presetColors = [
    0xFF38BDF8, // Cyan (Lab)
    0xFFF59E0B, // Amber (Field)
    0xFF10B981, // Emerald Green (Office)
    0xFFA855F7, // Purple (VLAN)
    0xFF2196F3, // Blue
    0xFFE91E63, // Pink
    0xFFFF5722, // Deep Orange
    0xFF00BCD4, // Teal / Cyan
    0xFF6366F1, // Indigo
    0xFF607D8B, // Blue Grey (Custom)
  ];

  static const List<ProfileCategoryModel> defaultCategories = [
    ProfileCategoryModel(
      id: 'cat-lab',
      name: 'LAB',
      colorHex: 0xFF38BDF8,
    ),
    ProfileCategoryModel(
      id: 'cat-field',
      name: 'FIELD',
      colorHex: 0xFFF59E0B,
    ),
    ProfileCategoryModel(
      id: 'cat-office',
      name: 'OFFICE',
      colorHex: 0xFF10B981,
    ),
    ProfileCategoryModel(
      id: 'cat-vlan',
      name: 'VLAN',
      colorHex: 0xFFA855F7,
    ),
    ProfileCategoryModel(
      id: 'cat-custom',
      name: 'CUSTOM',
      colorHex: 0xFF607D8B,
    ),
  ];

  ProfileCategoryModel copyWith({
    String? id,
    String? name,
    int? colorHex,
    bool? isVisible,
  }) {
    return ProfileCategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color_hex': colorHex,
      'is_visible': isVisible ? 1 : 0,
    };
  }

  factory ProfileCategoryModel.fromMap(Map<String, dynamic> map) {
    return ProfileCategoryModel(
      id: map['id'] as String,
      name: map['name'] as String,
      colorHex: (map['color_hex'] as num?)?.toInt() ?? 0xFF38BDF8,
      isVisible: (map['is_visible'] as int? ?? 1) == 1,
    );
  }
}
