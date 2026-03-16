import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/device.dart';
import '../../providers/app_provider.dart';
import 'scan_devices_screen.dart';
import 'esp_device_detail_screen.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final espIds = prov.espIds;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.bgPrimary,
            elevation: 0,
            title: Text('Weighing Devices', style: AppTextStyles.headingLarge),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _GoldBtn(
                  '+ Add',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ScanDevicesScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (espIds.isEmpty) ...[
                  const SizedBox(height: 60),
                  _EmptyBanner(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ScanDevicesScreen(),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  // Global summary
                  _GlobalSummary(prov: prov),
                  const SizedBox(height: 20),
                  // One card per ESP32
                  ...espIds.map(
                    (id) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _EspCard(espId: id),
                    ),
                  ),
                  // Add more
                  _AddMoreTile(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ScanDevicesScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Global summary bar ────────────────────────────────────────────────────────
class _GlobalSummary extends StatelessWidget {
  final AppProvider prov;
  const _GlobalSummary({required this.prov});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.borderSubtle),
    ),
    child: Row(
      children: [
        _Mini('Devices', '${prov.espIds.length}', AppColors.textPrimary),
        _div(),
        _Mini('Sensors', '${prov.devices.length}', AppColors.textPrimary),
        _div(),
        _Mini('Online', '${prov.onlineDevicesCount}', AppColors.success),
        _div(),
        _Mini('Low Stock', '${prov.lowStockCount}', AppColors.warning),
      ],
    ),
  );

  Widget _div() => Container(
    width: 1,
    height: 28,
    color: AppColors.borderSubtle,
    margin: const EdgeInsets.symmetric(horizontal: 10),
  );
}

class _Mini extends StatelessWidget {
  final String l, v;
  final Color c;
  const _Mini(this.l, this.v, this.c);
  @override
  Widget build(BuildContext ctx) => Expanded(
    child: Column(
      children: [
        Text(v, style: AppTextStyles.headingMedium.copyWith(color: c)),
        Text(l, style: AppTextStyles.labelSmall),
      ],
    ),
  );
}

// ── ESP32 card ────────────────────────────────────────────────────────────────
class _EspCard extends StatelessWidget {
  final String espId;
  const _EspCard({required this.espId});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final sensors = prov.devicesForEsp(espId);
    final online = sensors.where((s) => s.isOnline).length;
    final low = sensors.where((s) => s.isLowStock).length;
    final bool anyOnline = true;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EspDeviceDetailScreen(espId: espId)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: low > 0
                ? AppColors.warning.withOpacity(0.4)
                : AppColors.borderSubtle,
          ),
        ),
        child: Column(
          children: [
            // Top row
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // ESP32 icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.goldDim,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.developer_board,
                      color: AppColors.goldPrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          espId,
                          style: AppTextStyles.headingMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: anyOnline
                                    ? AppColors.success
                                    : AppColors.textMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              anyOnline ? 'Active' : 'Offline',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: anyOnline
                                    ? AppColors.success
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Chevron
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ],
              ),
            ),

            // Slot pills
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Slot grid
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: sensors.map((s) => _SlotPill(sensor: s)).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Stats row
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgCardElevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        _StatChip(
                          Icons.sensors,
                          '$online / ${sensors.length} online',
                          anyOnline ? AppColors.success : AppColors.textMuted,
                        ),
                        if (low > 0) ...[
                          const SizedBox(width: 12),
                          _StatChip(
                            Icons.warning_amber_rounded,
                            '$low low stock',
                            AppColors.warning,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A small pill showing slot number + live weight
class _SlotPill extends StatelessWidget {
  final KitchenDevice sensor;
  const _SlotPill({required this.sensor});

  @override
  Widget build(BuildContext context) {
    final isLow = sensor.isLowStock;
    final color = isLow ? AppColors.warning : AppColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            'S${sensor.slot}',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            sensor.weightFormatted,
            style: TextStyle(color: color, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext ctx) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 5),
      Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

// Empty banner
class _EmptyBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyBanner({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1500), Color(0xFF1C1C1F)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderGold),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.goldDim,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_circle_outline,
              color: AppColors.goldPrimary,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text('Add Your First Device', style: AppTextStyles.displaySmall),
          const SizedBox(height: 8),
          Text(
            'Tap here to scan and connect your\nKitchenBDY weighing machines',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Scan for Devices',
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.textOnGold,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// Add more
class _AddMoreTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddMoreTile({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.goldDim.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderGold),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.add_circle_outline,
            color: AppColors.goldPrimary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            'Add Another Device',
            style: AppTextStyles.headingSmall.copyWith(
              color: AppColors.goldPrimary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _GoldBtn extends StatelessWidget {
  final String l;
  final VoidCallback t;
  const _GoldBtn(this.l, this.t);
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: t,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        l,
        style: AppTextStyles.labelMedium.copyWith(color: AppColors.textOnGold),
      ),
    ),
  );
}
