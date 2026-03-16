import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/alert.dart';
import '../../providers/app_provider.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        title: Row(
          children: [
            Text('Alerts', style: AppTextStyles.headingLarge),
            const SizedBox(width: 8),
            if (prov.unreadAlertCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${prov.unreadAlertCount}',
                  style: AppTextStyles.labelSmall.copyWith(color: Colors.white),
                ),
              ),
          ],
        ),
        actions: [
          if (prov.unreadAlertCount > 0)
            TextButton(
              onPressed: () => context.read<AppProvider>().markAllAlertsRead(),
              child: Text(
                'Mark all read',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.goldPrimary,
                ),
              ),
            ),
        ],
      ),
      body: prov.alerts.isEmpty
          ? _EmptyAlerts()
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: prov.alerts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => _AlertCard(
                alert: prov.alerts[i],
                onTap: () =>
                    ctx.read<AppProvider>().markAlertRead(prov.alerts[i].id),
              ),
            ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final AppAlert alert;
  final VoidCallback onTap;
  const _AlertCard({required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg) = _alertStyle(alert.type);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: alert.isRead ? AppColors.bgCard : bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: alert.isRead
                ? AppColors.borderSubtle
                : color.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          alert.title,
                          style: AppTextStyles.headingSmall.copyWith(
                            fontWeight: alert.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!alert.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.message,
                    style: AppTextStyles.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          alert.typeLabel,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: color,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatTime(alert.timestamp),
                        style: AppTextStyles.labelSmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color, Color) _alertStyle(AlertType type) {
    switch (type) {
      case AlertType.lowStock:
        return (
          Icons.inventory_2_outlined,
          AppColors.warning,
          AppColors.warningDim,
        );
      case AlertType.deviceOffline:
        return (Icons.wifi_off, AppColors.error, AppColors.errorDim);
      case AlertType.deviceLowBattery:
        return (Icons.battery_alert, AppColors.error, AppColors.errorDim);
      case AlertType.refillReminder:
        return (Icons.refresh, AppColors.info, AppColors.infoDim);
      case AlertType.info:
        return (Icons.info_outline, AppColors.info, AppColors.infoDim);
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d').format(dt);
  }
}

class _EmptyAlerts extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.successDim,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.notifications_none,
            color: AppColors.success,
            size: 40,
          ),
        ),
        const SizedBox(height: 20),
        Text('All Clear', style: AppTextStyles.displaySmall),
        const SizedBox(height: 8),
        Text(
          'No alerts at the moment.\nYour pantry is running smoothly.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
