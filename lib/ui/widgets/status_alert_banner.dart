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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: AppTheme.primaryAccent.withValues(alpha: 0.18),
        child: Row(
          children: [
            const SizedBox(
              width: 13,
              height: 13,
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
                  fontSize: 12,
                  color: AppTheme.secondaryCyan,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    if (vm.bannerMessage != null) {
      final Color accent =
          vm.bannerIsError ? AppTheme.error : AppTheme.success;
      final IconData icon = vm.bannerIsError
          ? Icons.error_outline
          : Icons.check_circle_outline;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.16),
          border: Border(
            bottom: BorderSide(color: accent.withValues(alpha: 0.4)),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                vm.bannerMessage!,
                style: const TextStyle(
                  fontSize: 12,
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
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
