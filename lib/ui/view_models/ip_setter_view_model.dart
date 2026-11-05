import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/repositories/nic_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/services/gateway_ping_service.dart';
import '../../data/services/nic_backend_service.dart';
import '../../domain/models/command_execution_log.dart';
import '../../domain/models/ip_profile_model.dart';
import '../../domain/models/ipv4_utils.dart';
import '../../domain/models/network_interface_model.dart';
import '../../domain/models/profile_category_model.dart';
import '../../domain/models/profile_diff_model.dart';

enum ProfileSortColumn {
  status,
  name,
  mode,
  ipAddress,
  subnetMask,
  gateway,
  dns,
}

enum ProfileModeFilter {
  all('ALL'),
  favorites('FAVORITES'),
  staticMode('STATIC'),
  dhcp('DHCP');

  final String label;
  const ProfileModeFilter(this.label);

  static ProfileModeFilter fromString(String value) {
    switch (value.trim().toUpperCase()) {
      case 'FAVORITES':
        return ProfileModeFilter.favorites;
      case 'STATIC':
        return ProfileModeFilter.staticMode;
      case 'DHCP':
        return ProfileModeFilter.dhcp;
      default:
        return ProfileModeFilter.all;
    }
  }
}

class IpSetterViewModel extends ChangeNotifier {
  final ProfileRepository profileRepository;
  final NicRepository nicRepository;

  IpSetterViewModel({
    required this.profileRepository,
    required this.nicRepository,
  });

  ProfileRepository get _profileRepository => profileRepository;
  NicRepository get _nicRepository => nicRepository;

  List<NetworkInterfaceModel> _interfaces = [];
  NetworkInterfaceModel? _selectedInterface;
  IpProfileModel? _previousNicSnapshot;

  List<IpProfileModel> _allProfiles = [];
  List<IpProfileModel>? _cachedFilteredProfiles;
  IpProfileModel? _selectedProfile;
  List<CommandExecutionLog> _executionLogs = [];
  List<ProfileCategoryModel> _categories = List<ProfileCategoryModel>.from(
    ProfileCategoryModel.defaultCategories,
  );

  bool _isLoading = true;
  bool _isApplying = false;
  bool _isElevated = false;
  bool _dryRunMode = false;

  String _searchQuery = '';
  ProfileModeFilter _modeFilter = ProfileModeFilter.all;
  final Set<String> _selectedCategories = {};
  ProfileSortColumn _sortColumn = ProfileSortColumn.name;
  bool _sortAscending = true;

  TargetOsPlatform _previewPlatform = TargetOsPlatform.current;
  int _inspectorTabIndex = 0; // 0: Diff & Summary, 1: CLI Preview, 2: Execution Log
  bool _isInspectorVisible = true;

  String? _bannerMessage;
  bool _bannerIsError = false;
  GatewayPingResult? _lastGatewayPing;
  Timer? _pollTimer;

  // Getters
  List<NetworkInterfaceModel> get interfaces => _interfaces;
  NetworkInterfaceModel? get selectedInterface => _selectedInterface;
  IpProfileModel? get previousNicSnapshot => _previousNicSnapshot;
  List<IpProfileModel> get allProfiles => _allProfiles;
  IpProfileModel? get selectedProfile => _selectedProfile;
  List<CommandExecutionLog> get executionLogs => _executionLogs;
  List<ProfileCategoryModel> get categories => _categories;
  List<ProfileCategoryModel> get visibleCategories =>
      _categories.where((c) => c.isVisible).toList();

  bool get isLoading => _isLoading;
  bool get isApplying => _isApplying;
  bool get isElevated => _isElevated;
  bool get dryRunMode => _dryRunMode;

  String get searchQuery => _searchQuery;
  ProfileModeFilter get modeFilter => _modeFilter;
  String get selectedModeFilter => _modeFilter.label;
  String get selectedCategoryFilter => _selectedCategories.isNotEmpty
      ? _selectedCategories.first
      : _modeFilter.label;
  Set<String> get selectedCategories => _selectedCategories;
  ProfileSortColumn get sortColumn => _sortColumn;
  bool get sortAscending => _sortAscending;

  TargetOsPlatform get previewPlatform => _previewPlatform;
  int get inspectorTabIndex => _inspectorTabIndex;
  bool get isInspectorVisible => _isInspectorVisible && _selectedProfile != null;

  String? get bannerMessage => _bannerMessage;
  bool get bannerIsError => _bannerIsError;
  GatewayPingResult? get lastGatewayPing => _lastGatewayPing;

  bool get hasActiveFilters =>
      _searchQuery.trim().isNotEmpty ||
      _modeFilter != ProfileModeFilter.all ||
      _selectedCategories.isNotEmpty;

  void _invalidateFilteredCache() {
    _cachedFilteredProfiles = null;
  }

  @override
  void notifyListeners() {
    _invalidateFilteredCache();
    super.notifyListeners();
  }

  /// Returns preset counts for each category (case-insensitive key = uppercase category name).
  Map<String, int> get categoryCounts {
    final counts = <String, int>{};
    for (final c in _categories) {
      counts[c.name.toUpperCase()] = 0;
    }
    for (final p in _allProfiles) {
      final key = p.category.toUpperCase();
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  /// Resolves the user-assigned badge color for [categoryName].
  Color getCategoryColor(String categoryName) {
    final upper = categoryName.trim().toUpperCase();
    for (final cat in _categories) {
      if (cat.name.trim().toUpperCase() == upper) {
        return Color(cat.colorHex);
      }
    }
    return const Color(0xFF607D8B);
  }

  bool isCategorySelected(String categoryName) {
    return _selectedCategories.contains(categoryName.trim().toUpperCase());
  }

  static int _compareNullableIpv4(String? a, String? b) {
    final aInt = Ipv4Utils.ipToInt(a);
    final bInt = Ipv4Utils.ipToInt(b);
    if (aInt != null && bInt != null) {
      return aInt.compareTo(bInt);
    }
    if (aInt != null) return -1;
    if (bInt != null) return 1;
    return (a ?? '').compareTo(b ?? '');
  }

  /// Filtered and sorted list of profiles for the Tier 4 Virtualized Data Table.
  List<IpProfileModel> get filteredProfiles {
    if (_cachedFilteredProfiles != null) {
      return _cachedFilteredProfiles!;
    }

    final q = _searchQuery.trim().toLowerCase();
    final filtered = _allProfiles.where((p) {
      if (_modeFilter == ProfileModeFilter.favorites && !p.isFavorite) {
        return false;
      }
      if (_modeFilter == ProfileModeFilter.staticMode && p.isDhcp) {
        return false;
      }
      if (_modeFilter == ProfileModeFilter.dhcp && !p.isDhcp) {
        return false;
      }

      if (_selectedCategories.isNotEmpty &&
          !_selectedCategories.contains(p.category.trim().toUpperCase())) {
        return false;
      }

      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          (p.ipAddress?.toLowerCase().contains(q) ?? false) ||
          p.formattedSubnetMask.toLowerCase().contains(q) ||
          p.formattedGateway.toLowerCase().contains(q) ||
          p.formattedDns.toLowerCase().contains(q) ||
          p.notes.toLowerCase().contains(q) ||
          (p.preferredInterface?.toLowerCase().contains(q) ?? false);
    }).toList();

    filtered.sort((a, b) {
      int cmp = 0;
      switch (_sortColumn) {
        case ProfileSortColumn.status:
          final aActive = isProfileActiveOnSelectedNic(a) ? 0 : 1;
          final bActive = isProfileActiveOnSelectedNic(b) ? 0 : 1;
          cmp = aActive.compareTo(bActive);
          if (cmp == 0) {
            cmp = (b.isFavorite ? 1 : 0).compareTo(a.isFavorite ? 1 : 0);
          }
          break;
        case ProfileSortColumn.name:
          cmp = (b.isFavorite ? 1 : 0).compareTo(a.isFavorite ? 1 : 0);
          if (cmp == 0) {
            cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          }
          break;
        case ProfileSortColumn.mode:
          cmp = (a.isDhcp ? 'DHCP' : 'STATIC')
              .compareTo(b.isDhcp ? 'DHCP' : 'STATIC');
          break;
        case ProfileSortColumn.ipAddress:
          cmp = _compareNullableIpv4(a.ipAddress, b.ipAddress);
          break;
        case ProfileSortColumn.subnetMask:
          cmp = a.formattedSubnetMask.compareTo(b.formattedSubnetMask);
          break;
        case ProfileSortColumn.gateway:
          cmp = _compareNullableIpv4(a.defaultGateway, b.defaultGateway);
          break;
        case ProfileSortColumn.dns:
          cmp = a.formattedDns.compareTo(b.formattedDns);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    _cachedFilteredProfiles = filtered;
    return filtered;
  }

  /// Checks if [profile] matches the currently selected live NIC state.
  bool isProfileActiveOnSelectedNic(IpProfileModel profile) {
    final nic = _selectedInterface;
    if (nic == null) return false;
    return nic.matchesProfile(profile);
  }

  /// Returns the diff fields comparing [selectedInterface] vs [selectedProfile].
  List<ProfileDiffField> get currentDiffFields {
    final prof = _selectedProfile;
    if (prof == null) return const [];
    return ProfileDiffField.computeDiff(
      nic: _selectedInterface,
      profile: prof,
    );
  }

  /// Returns the generated OS CLI commands for the selected profile and preview platform.
  List<String> get previewCliCommands {
    final prof = _selectedProfile;
    final nic = _selectedInterface;
    if (prof == null || nic == null) return const [];
    return _nicRepository.previewCommands(
      platform: _previewPlatform,
      nic: nic,
      profile: prof,
    );
  }

  /// Initializes the ViewModel on startup.
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    _isElevated = await _nicRepository.checkIsElevated();
    _categories = await _profileRepository.loadCategories();
    _allProfiles = await _profileRepository.loadProfiles();
    await _ensureProfileCategoriesExist();
    _executionLogs = await _profileRepository.loadExecutionLogs();
    await refreshInterfaces(checkGatewayPing: true);

    if (_allProfiles.isNotEmpty) {
      // Select the currently active profile if one matches, else first profile
      _selectedProfile = _allProfiles.firstWhere(
        isProfileActiveOnSelectedNic,
        orElse: () => _allProfiles.first,
      );
    }

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_isApplying && !_dryRunMode) {
        refreshInterfaces(checkGatewayPing: false);
      }
    });

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _ensureProfileCategoriesExist() async {
    final existingNames =
        _categories.map((c) => c.name.trim().toUpperCase()).toSet();
    bool addedAny = false;
    for (final p in _allProfiles) {
      final catName = p.category.trim().toUpperCase();
      if (catName.isNotEmpty && !existingNames.contains(catName)) {
        final colorHex = ProfileCategoryModel.presetColors[
            existingNames.length % ProfileCategoryModel.presetColors.length];
        final newCat = ProfileCategoryModel(
          id: 'cat-${DateTime.now().microsecondsSinceEpoch}-${existingNames.length}',
          name: catName,
          colorHex: colorHex,
        );
        await _profileRepository.saveCategory(newCat);
        existingNames.add(catName);
        addedAny = true;
      }
    }
    if (addedAny) {
      _categories = await _profileRepository.loadCategories();
    }
  }

  /// Polls live network interfaces from the host OS.
  Future<void> refreshInterfaces({bool checkGatewayPing = false}) async {
    if (_dryRunMode && _interfaces.isNotEmpty) {
      // Preserve simulated adapter state while in Dry-Run mode unless explicitly reset
      notifyListeners();
      return;
    }

    final discovered = await _nicRepository.fetchInterfaces();
    _interfaces = discovered;
    if (_interfaces.isNotEmpty) {
      if (_selectedInterface != null) {
        _selectedInterface = _interfaces.firstWhere(
          (i) => i.id == _selectedInterface!.id,
          orElse: () => _interfaces.first,
        );
      } else {
        // Prefer an UP non-placeholder interface with an IP address
        _selectedInterface = _interfaces.firstWhere(
          (i) => !i.isPlaceholder && i.isUp && i.currentIp != null,
          orElse: () => _interfaces.first,
        );
      }
    }

    if (checkGatewayPing &&
        _selectedInterface != null &&
        !_selectedInterface!.isPlaceholder &&
        _selectedInterface!.currentGateway != null &&
        _selectedInterface!.currentGateway!.isNotEmpty) {
      final selectedId = _selectedInterface!.id;
      final pingRes = await _nicRepository
          .verifyGateway(_selectedInterface!.currentGateway);
      if (_selectedInterface?.id == selectedId) {
        _lastGatewayPing = pingRes;
      }
    }
    notifyListeners();
  }

  void selectInterface(NetworkInterfaceModel? nic) {
    if (nic == null) return;
    _selectedInterface = nic;
    _lastGatewayPing = null;
    notifyListeners();
    if (!nic.isPlaceholder &&
        nic.currentGateway != null &&
        nic.currentGateway!.isNotEmpty) {
      final selectedId = nic.id;
      _nicRepository.verifyGateway(nic.currentGateway).then((res) {
        if (_selectedInterface?.id == selectedId) {
          _lastGatewayPing = res;
          notifyListeners();
        }
      });
    }
  }

  void selectProfile(IpProfileModel? profile) {
    _selectedProfile = profile;
    if (profile != null) {
      _isInspectorVisible = true;
    }
    notifyListeners();
  }

  void closeInspector() {
    _isInspectorVisible = false;
    notifyListeners();
  }

  void setInspectorTab(int index) {
    _inspectorTabIndex = index;
    notifyListeners();
  }

  void setPreviewPlatform(TargetOsPlatform platform) {
    _previewPlatform = platform;
    notifyListeners();
  }

  void toggleDryRunMode(bool value) {
    _dryRunMode = value;
    notifyListeners();
    if (!value) {
      refreshInterfaces(checkGatewayPing: true);
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setModeFilter(String mode) {
    final parsed = ProfileModeFilter.fromString(mode);
    if (parsed == ProfileModeFilter.all) {
      _modeFilter = ProfileModeFilter.all;
    } else if (_modeFilter == parsed) {
      _modeFilter = ProfileModeFilter.all;
    } else {
      _modeFilter = parsed;
    }
    notifyListeners();
  }

  void toggleCategoryPill(String categoryName) {
    final key = categoryName.trim().toUpperCase();
    if (_selectedCategories.contains(key)) {
      _selectedCategories.remove(key);
    } else {
      _selectedCategories.add(key);
    }
    notifyListeners();
  }

  void setCategoryFilter(String category) {
    final upper = category.trim().toUpperCase();
    if (['ALL', 'FAVORITES', 'STATIC', 'DHCP'].contains(upper)) {
      _modeFilter = ProfileModeFilter.fromString(upper);
      if (upper == 'ALL') {
        _selectedCategories.clear();
      }
    } else {
      toggleCategoryPill(upper);
    }
    notifyListeners();
  }

  void clearAllFilters() {
    _searchQuery = '';
    _modeFilter = ProfileModeFilter.all;
    _selectedCategories.clear();
    notifyListeners();
  }

  Future<void> addOrUpdateCategory(
    ProfileCategoryModel category, {
    String? previousName,
  }) async {
    final normalized = category.copyWith(
      name: category.name.trim().toUpperCase(),
    );
    await _profileRepository.saveCategory(
      normalized,
      previousName: previousName,
    );
    if (previousName != null &&
        _selectedCategories.contains(previousName.trim().toUpperCase())) {
      _selectedCategories.remove(previousName.trim().toUpperCase());
      _selectedCategories.add(normalized.name);
    }
    _categories = await _profileRepository.loadCategories();
    _allProfiles = await _profileRepository.loadProfiles();
    notifyListeners();
  }

  Future<void> toggleCategoryVisibility(ProfileCategoryModel category) async {
    final updated = category.copyWith(isVisible: !category.isVisible);
    await _profileRepository.saveCategory(updated);
    if (!updated.isVisible) {
      _selectedCategories.remove(updated.name.trim().toUpperCase());
    }
    _categories = await _profileRepository.loadCategories();
    notifyListeners();
  }

  Future<void> deleteCategory(ProfileCategoryModel category) async {
    await _profileRepository.deleteCategory(category.id);
    _selectedCategories.remove(category.name.trim().toUpperCase());
    _categories = await _profileRepository.loadCategories();
    notifyListeners();
  }

  void setSortColumn(ProfileSortColumn col) {
    if (_sortColumn == col) {
      _sortAscending = !_sortAscending;
    } else {
      _sortColumn = col;
      _sortAscending = true;
    }
    notifyListeners();
  }

  void dismissBanner() {
    _bannerMessage = null;
    notifyListeners();
  }

  /// Applies [profile] to the currently selected [NetworkInterfaceModel].
  Future<bool> applyProfile(
    IpProfileModel profile, {
    bool isRollback = false,
  }) async {
    final nic = _selectedInterface;
    if (nic == null || _isApplying) return false;

    if (nic.isPlaceholder && !_dryRunMode) {
      _bannerIsError = true;
      _bannerMessage =
          'Cannot apply "${profile.name}" to placeholder adapter "${nic.displayName}". Connect a physical network adapter or enable Dry-Run Mode.';
      notifyListeners();
      return false;
    }

    final validationError = profile.validate();
    if (validationError != null) {
      _bannerIsError = true;
      _bannerMessage = validationError;
      notifyListeners();
      return false;
    }

    // Capture pre-mutation candidate snapshot (committed to _previousNicSnapshot only if apply succeeds)
    final candidateSnapshot = _nicRepository.createSnapshotProfileFromNic(
      nic,
      name: 'Undo Snapshot (${nic.formattedIpWithCidr})',
    );

    _selectedProfile = profile;
    _isInspectorVisible = true;
    _isApplying = true;
    _bannerIsError = false;
    _bannerMessage =
        'Applying "${profile.name}" (${profile.formattedIpWithCidr}) to ${nic.displayName}...';
    notifyListeners();

    try {
      final runResult = await _nicRepository.applyProfileToNic(
        nic: nic,
        profile: profile,
        isElevated: _isElevated,
        dryRun: _dryRunMode,
      );

      GatewayPingResult? pingRes;
      if (runResult.exitCode == 0) {
        if (!isRollback) {
          _previousNicSnapshot = candidateSnapshot;
        }
        if (!profile.id.startsWith('snapshot-') &&
            !profile.id.startsWith('emergency-')) {
          final updatedProfile = profile.copyWith(lastAppliedAt: DateTime.now());
          await _profileRepository.saveProfile(updatedProfile);
          _allProfiles = await _profileRepository.loadProfiles();
          _selectedProfile = _allProfiles.firstWhere(
            (p) => p.id == profile.id,
            orElse: () => updatedProfile,
          );
        }

        if (_dryRunMode) {
          final simulatedNic = _nicRepository.simulateAppliedState(nic, profile);
          _interfaces = _interfaces
              .map((i) => i.id == nic.id ? simulatedNic : i)
              .toList();
          _selectedInterface = simulatedNic;
        } else {
          await refreshInterfaces(checkGatewayPing: false);
        }

        final targetGw =
            _selectedInterface?.currentGateway ?? profile.defaultGateway;
        if (targetGw != null && targetGw.trim().isNotEmpty) {
          pingRes = await _nicRepository.verifyGateway(targetGw);
          _lastGatewayPing = pingRes;
        } else {
          _lastGatewayPing = null;
        }

        _bannerIsError = false;
        final modeSuffix = _dryRunMode ? ' [Simulated]' : '';
        final gwSuffix = pingRes != null
            ? (pingRes.isReachable
                ? ' • Gateway ${pingRes.gatewayIp} reachable (${pingRes.latencyMs?.toStringAsFixed(1) ?? "<1"} ms)'
                : ' • Gateway ${pingRes.gatewayIp} unreachable')
            : '';
        _bannerMessage =
            'Applied "${profile.name}" (${profile.formattedIpWithCidr}) on ${nic.displayName}$modeSuffix$gwSuffix';
      } else {
        // Attempt automatic rollback to candidateSnapshot on partial failure
        String rollbackNote = '';
        if (!_dryRunMode && !isRollback) {
          final rollbackRes = await _nicRepository.applyProfileToNic(
            nic: nic,
            profile: candidateSnapshot,
            isElevated: _isElevated,
            dryRun: false,
          );
          await refreshInterfaces(checkGatewayPing: false);
          rollbackNote = rollbackRes.exitCode == 0
              ? ' Automatically rolled back adapter to previous settings.'
              : ' Automatic rollback also failed.';
        }

        _bannerIsError = true;
        _inspectorTabIndex = 2; // Jump to Execution Log tab on failure
        _bannerMessage =
            'Failed to apply "${profile.name}" on ${nic.displayName} (Exit code ${runResult.exitCode}).$rollbackNote Check Execution Log.';
      }

      final logEntry = CommandExecutionLog(
        id: 'log-${DateTime.now().microsecondsSinceEpoch}',
        timestamp: DateTime.now(),
        profileName: profile.name,
        interfaceName: nic.displayName,
        platformName: TargetOsPlatform.current.shortLabel,
        commands: runResult.executedCommands,
        exitCode: runResult.exitCode,
        stdout: runResult.stdout,
        stderr: runResult.stderr,
        gatewayReachable: pingRes?.isReachable,
        gatewayLatencyMs: pingRes?.latencyMs,
        isDryRun: _dryRunMode,
      );

      await _profileRepository.addExecutionLog(logEntry);
      _executionLogs = await _profileRepository.loadExecutionLogs();

      return runResult.exitCode == 0;
    } catch (e) {
      _bannerIsError = true;
      _bannerMessage = 'Unexpected error while applying "${profile.name}": $e';
      return false;
    } finally {
      _isApplying = false;
      notifyListeners();
    }
  }

  /// Emergency 1-click DHCP reset on the selected interface (always pure DHCP + automatic DNS).
  Future<bool> applyEmergencyDhcp() async {
    const pureDhcpProfile = IpProfileModel(
      id: 'emergency-dhcp',
      name: 'Emergency DHCP Reset',
      category: 'OFFICE',
      isDhcp: true,
      notes: 'Automatic IPv4 & DNS via DHCP',
    );
    return applyProfile(pureDhcpProfile);
  }

  /// Reverts the selected NIC to the snapshot captured immediately before the last successful profile switch.
  Future<bool> undoLastSwitch() async {
    final snap = _previousNicSnapshot;
    if (snap == null) return false;
    return applyProfile(snap, isRollback: true);
  }

  /// Creates or updates a preset in SQLite.
  Future<void> saveProfile(IpProfileModel profile) async {
    await _profileRepository.saveProfile(profile);
    _allProfiles = await _profileRepository.loadProfiles();
    await _ensureProfileCategoriesExist();
    _selectedProfile = _allProfiles.firstWhere(
      (p) => p.id == profile.id,
      orElse: () => profile,
    );
    notifyListeners();
  }

  Future<void> toggleFavorite(IpProfileModel profile) async {
    final updated = profile.copyWith(isFavorite: !profile.isFavorite);
    await saveProfile(updated);
  }

  Future<void> duplicateProfile(IpProfileModel profile) async {
    final copy = profile.copyWith(
      id: 'profile-${DateTime.now().microsecondsSinceEpoch}',
      name: '${profile.name} (Copy)',
      clearLastAppliedAt: true,
    );
    await saveProfile(copy);
  }

  Future<void> deleteProfile(String id) async {
    await _profileRepository.deleteProfile(id);
    _allProfiles = await _profileRepository.loadProfiles();
    if (_selectedProfile?.id == id) {
      _selectedProfile = _allProfiles.isNotEmpty ? _allProfiles.first : null;
    }
    notifyListeners();
  }

  Future<void> loadDemoPresets() async {
    await _profileRepository.loadDemoProfiles();
    _allProfiles = await _profileRepository.loadProfiles();
    await _ensureProfileCategoriesExist();
    if (_selectedProfile == null && _allProfiles.isNotEmpty) {
      _selectedProfile = _allProfiles.firstWhere(
        isProfileActiveOnSelectedNic,
        orElse: () => _allProfiles.first,
      );
    }
    notifyListeners();
  }

  Future<void> clearAllPresets() async {
    await _profileRepository.clearAllProfiles();
    _allProfiles = [];
    _selectedProfile = null;
    notifyListeners();
  }

  Future<void> resetToDefaultPresets() async {
    await loadDemoPresets();
  }

  Future<void> clearExecutionHistory() async {
    await _profileRepository.clearExecutionLogs();
    _executionLogs = [];
    notifyListeners();
  }

  String exportPresetsJson() {
    return _profileRepository.exportProfilesToJson(_allProfiles);
  }

  Future<int> importPresetsJson(String jsonContent) async {
    final count = await _profileRepository.importProfilesFromJson(jsonContent);
    _allProfiles = await _profileRepository.loadProfiles();
    await _ensureProfileCategoriesExist();
    _bannerIsError = false;
    _bannerMessage = 'Imported $count preset(s) from JSON bundle.';
    notifyListeners();
    return count;
  }

  /// Creates an unsaved [IpProfileModel] populated from the currently active NIC.
  IpProfileModel createTemplateFromActiveNic() {
    final nic = _selectedInterface;
    if (nic == null || nic.isPlaceholder) {
      return IpProfileModel(
        id: 'profile-${DateTime.now().microsecondsSinceEpoch}',
        name: 'New Static Profile',
        category: _categories.isNotEmpty ? _categories.first.name : 'LAB',
        isDhcp: false,
        ipAddress: '192.168.1.50',
        subnetMask: '255.255.255.0',
        cidrPrefix: 24,
        defaultGateway: '192.168.1.1',
        primaryDns: '1.1.1.1',
        secondaryDns: '8.8.8.8',
      );
    }
    return _nicRepository
        .createSnapshotProfileFromNic(
          nic,
          name: '${nic.id} Snapshot',
        )
        .copyWith(
          id: 'profile-${DateTime.now().microsecondsSinceEpoch}',
        );
  }

  /// Cleanly stops any active child processes, pings, and timers on window exit.
  Future<void> stopAllServices() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    await _nicRepository.stopAll();
    await _profileRepository.close();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
