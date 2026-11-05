import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/models/ip_profile_model.dart';
import '../../theme/app_theme.dart';
import '../view_models/ip_setter_view_model.dart';
import '../widgets/bottom_detail_inspector.dart';
import '../widgets/filter_triage_toolbar.dart';
import '../widgets/import_export_dialog.dart';
import '../widgets/profile_data_table.dart';
import '../widgets/profile_editor_dialog.dart';
import '../widgets/status_alert_banner.dart';
import '../widgets/top_control_bar.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    final vm = Provider.of<IpSetterViewModel>(context, listen: false);
    await vm.stopAllServices();
    return AppExitResponse.exit;
  }

  Future<void> _openProfileEditor(
    BuildContext context, {
    IpProfileModel? initialProfile,
  }) async {
    final vm = context.read<IpSetterViewModel>();
    final saved = await showDialog<IpProfileModel>(
      context: context,
      builder: (_) => ProfileEditorDialog(
        initialProfile: initialProfile,
        onSnapshotActiveNic: vm.createTemplateFromActiveNic,
      ),
    );
    if (saved != null) {
      await vm.saveProfile(saved);
    }
  }

  Future<void> _openSnapshotDialog(BuildContext context) async {
    final vm = context.read<IpSetterViewModel>();
    final template = vm.createTemplateFromActiveNic();
    await _openProfileEditor(context, initialProfile: template);
  }

  Future<void> _openImportExportDialog(BuildContext context) async {
    final vm = context.read<IpSetterViewModel>();
    await showDialog<void>(
      context: context,
      builder: (_) => ImportExportDialog(
        exportedJson: vm.exportPresetsJson(),
        onImportJson: vm.importPresetsJson,
        onResetDefaults: vm.resetToDefaultPresets,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<IpSetterViewModel, bool>((vm) => vm.isLoading);

    return Scaffold(
      backgroundColor: AppTheme.windowBackground,
      body: Column(
        children: [
          // 1. TOP CONTROL BAR
          TopControlBar(
            onNewProfile: () => _openProfileEditor(context),
            onImportExport: () => _openImportExportDialog(context),
          ),

          // 2. GLOBAL ALERT / STATUS BANNER (Conditional)
          const StatusAlertBanner(),

          // 3. FILTER & TRIAGE TOOLBAR (+ Live NIC Telemetry Strip)
          FilterTriageToolbar(
            onSnapshotActiveNic: () => _openSnapshotDialog(context),
          ),

          // 4. PRIMARY DATA WORKSPACE (Expanded Virtualized Data Table)
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryAccent,
                    ),
                  )
                : ProfileDataTable(
                    onEditProfile: (profile) =>
                        _openProfileEditor(context, initialProfile: profile),
                    onNewProfile: () => _openProfileEditor(context),
                    onSnapshotActiveNic: () => _openSnapshotDialog(context),
                  ),
          ),

          // 5. COLLAPSIBLE DETAIL INSPECTOR & PERSISTENT STATUS BAR
          const BottomDetailInspector(),
        ],
      ),
    );
  }
}
