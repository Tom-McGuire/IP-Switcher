import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../view_models/ip_setter_view_model.dart';

class StatusAlertBanner extends StatelessWidget {
  const StatusAlertBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<IpSetterViewModel>();

    if (vm.isApplying) {
      return Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppTheme.primaryAccent.withValues(alpha: 0.18),
          border: const Border(bottom: BorderSide(color: AppTheme.border)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.secondaryCyan,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                vm.bannerMessage ?? 'Reconfiguring network adapter...',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    if (vm.bannerMessage != null) {
      final Color accent = vm.bannerIsError
          ? AppTheme.error
          : (vm.dryRunMode ? AppTheme.warning : AppTheme.success);
      final IconData icon = vm.bannerIsError
          ? Icons.error_outline
          : (vm.dryRunMode ? Icons.science_outlined : Icons.check_circle_outline);

      return Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.14),
          border: Border(
            bottom: BorderSide(color: accent.withValues(alpha: 0.35)),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                vm.bannerMessage!,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (vm.bannerIsError)
              TextButton(
                onPressed: () => vm.setInspectorTab(2),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 22),
                ),
                child: const Text(
                  'View Error Log',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.close, size: 14),
              onPressed: vm.dismissBanner,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
          ],
        ),
      );
    }

    // Subtle elevation guidance notice if running unprivileged and not in dry-run mode
    if (!vm.isElevated && !vm.dryRunMode) {
      return Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppTheme.warning.withValues(alpha: 0.10),
          border: const Border(bottom: BorderSide(color: AppTheme.border)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.shield_outlined,
              size: 13,
              color: AppTheme.warning,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Standard User Session: Clicking Apply will request OS administrator elevation (pkexec / osascript / UAC), or enable DRY-RUN to simulate safely.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => vm.toggleDryRunMode(true),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 22),
              ),
              child: const Text(
                'Enable Dry-Run',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.warning,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
