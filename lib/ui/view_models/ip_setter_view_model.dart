import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/repositories/nic_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/services/gateway_ping_service.dart';
import '../../data/services/nic_backend_service.dart';
import '../../domain/models/command_execution_log.dart';
import '../../domain/models/ip_profile_model.dart';
import '../../domain/models/network_interface_model.dart';
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
  IpProfileModel? _selectedProfile;
  List<CommandExecutionLog> _executionLogs = [];

  bool _isLoading = true;
  bool _isApplying = false;
  bool _isElevated = false;
  bool _dryRunMode = false;

  String _searchQuery = '';
  String _selectedCategoryFilter = 'ALL'; // ALL, FAVORITES, STATIC, DHCP, LAB, FIELD, OFFICE, VLAN, CUSTOM
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

  bool get isLoading => _isLoading;
  bool get isApplying => _isApplying;
  bool get isElevated => _isElevated;
  bool get dryRunMode => _dryRunMode;

  String get searchQuery => _searchQuery;
  String get selectedCategoryFilter => _selectedCategoryFilter;
  ProfileSortColumn get sortColumn => _sortColumn;
  bool get sortAscending => _sortAscending;

  TargetOsPlatform get previewPlatform => _previewPlatform;
  int get inspectorTabIndex => _inspectorTabIndex;
  bool get isInspectorVisible => _isInspectorVisible && _selectedProfile != null;

  String? get bannerMessage => _bannerMessage;
  bool get bannerIsError => _bannerIsError;
  GatewayPingResult? get lastGatewayPing => _lastGatewayPing;

  bool get hasActiveFilters =>
      _searchQuery.trim().isNotEmpty || _selectedCategoryFilter != 'ALL';

  /// Filtered and sorted list of profiles for the Tier 4 Virtualized Data Table.
  List<IpProfileModel> get filteredProfiles {
    final q = _searchQuery.trim().toLowerCase();
    final filtered = _allProfiles.where((p) {
      if (_selectedCategoryFilter == 'FAVORITES' && !p.isFavorite) return false;
      if (_selectedCategoryFilter == 'STATIC' && p.isDhcp) return false;
      if (_selectedCategoryFilter == 'DHCP' && !p.isDhcp) return false;
      if (!['ALL', 'FAVORITES', 'STATIC', 'DHCP']
              .contains(_selectedCategoryFilter) &&
          p.category.toUpperCase() != _selectedCategoryFilter) {
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
          cmp = a.formattedIpWithCidr.compareTo(b.formattedIpWithCidr);
          break;
        case ProfileSortColumn.subnetMask:
          cmp = a.formattedSubnetMask.compareTo(b.formattedSubnetMask);
          break;
        case ProfileSortColumn.gateway:
          cmp = a.formattedGateway.compareTo(b.formattedGateway);
          break;
        case ProfileSortColumn.dns:
          cmp = a.formattedDns.compareTo(b.formattedDns);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });

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
    _allProfiles = await _profileRepository.loadProfiles();
    _executionLogs = await _profileRepository.loadExecutionLogs();
    await refreshInterfaces(checkGatewayPing: true);

    if (_allProfiles.isNotEmpty) {
      // Select the currently active profile if one matches, else first profile
      _selectedProfile = _allProfiles.firstWhere(
        isProfileActiveOnSelectedNic,
        orElse: () => _allProfiles.first,
      );
    }

    _isLoading = false;
    notifyListeners();
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
        // Prefer an UP interface with an IP address
        _selectedInterface = _interfaces.firstWhere(
          (i) => i.isUp && i.currentIp != null,
          orElse: () => _interfaces.first,
        );
      }
    }

    if (checkGatewayPing &&
        _selectedInterface?.currentGateway != null &&
        _selectedInterface!.currentGateway!.isNotEmpty) {
      _lastGatewayPing = await _nicRepository
          .verifyGateway(_selectedInterface!.currentGateway);
    }
    notifyListeners();
  }

  void selectInterface(NetworkInterfaceModel? nic) {
    if (nic == null) return;
    _selectedInterface = nic;
    _lastGatewayPing = null;
    notifyListeners();
    if (nic.currentGateway != null && nic.currentGateway!.isNotEmpty) {
      _nicRepository.verifyGateway(nic.currentGateway).then((res) {
        _lastGatewayPing = res;
        notifyListeners();
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
    _bannerMessage = value
        ? 'Dry-Run / Simulation Mode Active: Applying presets will simulate NIC state and log commands without modifying host OS adapters.'
        : null;
    _bannerIsError = false;
    notifyListeners();
    if (!value) {
      refreshInterfaces(checkGatewayPing: true);
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategoryFilter(String category) {
    _selectedCategoryFilter = category;
    notifyListeners();
  }

  void clearAllFilters() {
    _searchQuery = '';
    _selectedCategoryFilter = 'ALL';
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
  Future<bool> applyProfile(IpProfileModel profile) async {
    final nic = _selectedInterface;
    if (nic == null || _isApplying) return false;

    _selectedProfile = profile;
    _isInspectorVisible = true;
    _isApplying = true;
    _bannerIsError = false;
    _bannerMessage =
        'Applying "${profile.name}" (${profile.formattedIpWithCidr}) to ${nic.displayName}...';
    notifyListeners();

    // Save pre-mutation snapshot for 1-click Undo
    _previousNicSnapshot = _nicRepository.createSnapshotProfileFromNic(
      nic,
      name: 'Undo Snapshot (${nic.formattedIpWithCidr})',
    );

    final runResult = await _nicRepository.applyProfileToNic(
      nic: nic,
      profile: profile,
      isElevated: _isElevated,
      dryRun: _dryRunMode,
    );

    GatewayPingResult? pingRes;
    if (runResult.exitCode == 0) {
      final updatedProfile = profile.copyWith(lastAppliedAt: DateTime.now());
      await _profileRepository.saveProfile(updatedProfile);
      _allProfiles = await _profileRepository.loadProfiles();
      _selectedProfile = _allProfiles.firstWhere(
        (p) => p.id == profile.id,
        orElse: () => updatedProfile,
      );

      if (_dryRunMode) {
        final simulatedNic = _nicRepository.simulateAppliedState(nic, profile);
        _interfaces = _interfaces
            .map((i) => i.id == nic.id ? simulatedNic : i)
            .toList();
        _selectedInterface = simulatedNic;
      } else {
        await refreshInterfaces(checkGatewayPing: false);
      }

      final targetGw = _selectedInterface?.currentGateway ?? profile.defaultGateway;
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
      _bannerIsError = true;
      _inspectorTabIndex = 2; // Jump to Execution Log tab on failure
      _bannerMessage =
          'Failed to apply "${profile.name}" on ${nic.displayName} (Exit code ${runResult.exitCode}). Check Execution Log.';
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

    _isApplying = false;
    notifyListeners();
    return runResult.exitCode == 0;
  }

  /// Emergency 1-click DHCP reset on the selected interface.
  Future<bool> applyEmergencyDhcp() async {
    final dhcpProfile = _allProfiles.firstWhere(
      (p) => p.isDhcp,
      orElse: () => const IpProfileModel(
        id: 'emergency-dhcp',
        name: 'Emergency DHCP Reset',
        category: 'OFFICE',
        isDhcp: true,
        notes: 'Automatic IPv4 & DNS via DHCP',
      ),
    );
    return applyProfile(dhcpProfile);
  }

  /// Reverts the selected NIC to the snapshot captured immediately before the last profile switch.
  Future<bool> undoLastSwitch() async {
    final snap = _previousNicSnapshot;
    if (snap == null) return false;
    return applyProfile(snap);
  }

  /// Creates or updates a preset in SQLite.
  Future<void> saveProfile(IpProfileModel profile) async {
    await _profileRepository.saveProfile(profile);
    _allProfiles = await _profileRepository.loadProfiles();
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
      id: 'profile-${DateTime.now().millisecondsSinceEpoch}',
      name: '${profile.name} (Copy)',
      lastAppliedAt: null,
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

  Future<void> resetToDefaultPresets() async {
    await _profileRepository.resetDefaults();
    _allProfiles = await _profileRepository.loadProfiles();
    _selectedProfile = _allProfiles.isNotEmpty ? _allProfiles.first : null;
    _bannerIsError = false;
    _bannerMessage = 'Restored default factory IP presets.';
    notifyListeners();
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
    _bannerIsError = false;
    _bannerMessage = 'Imported $count preset(s) from JSON bundle.';
    notifyListeners();
    return count;
  }

  /// Creates an unsaved [IpProfileModel] populated from the currently active NIC.
  IpProfileModel createTemplateFromActiveNic() {
    final nic = _selectedInterface;
    if (nic == null) {
      return IpProfileModel(
        id: 'profile-${DateTime.now().millisecondsSinceEpoch}',
        name: 'New Static Profile',
        category: 'LAB',
        isDhcp: false,
        ipAddress: '192.168.1.50',
        subnetMask: '255.255.255.0',
        cidrPrefix: 24,
        defaultGateway: '192.168.1.1',
        primaryDns: '1.1.1.1',
        secondaryDns: '8.8.8.8',
      );
    }
    return _nicRepository.createSnapshotProfileFromNic(
      nic,
      name: '${nic.id} Snapshot',
    );
  }

  /// Cleanly stops any active child processes, pings, and timers on window exit.
  Future<void> stopAllServices() async {
    _pollTimer?.cancel();
    await _nicRepository.stopAll();
    await _profileRepository.close();
  }
}
