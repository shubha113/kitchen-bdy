import 'package:flutter/material.dart';
import 'package:kitchen_bdy/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../providers/app_provider.dart';
import '../grocery/grocery_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 130,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.bgPrimary,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text('Kitchen BDY', style: AppTextStyles.goldHeading),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A1500), AppColors.bgPrimary],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.goldPrimary,
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, MMMM d').format(now),
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GroceryScreen()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderGold),
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      color: AppColors.goldPrimary,
                      size: 20,
                    ),
                  ),
                ),
              ),

              IconButton(
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFD4A843),
                ),
                tooltip: 'Sign Out',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: const Color(0xFF1A1A1A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Text(
                        'Sign Out',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: const Text(
                        'Are you sure you want to sign out?',
                        style: TextStyle(color: Color(0xFF888888)),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Color(0xFF888888)),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4A843),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Sign Out'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await ApiService.clearToken();
                    if (context.mounted) {
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/login', (_) => false);
                    }
                  }
                },
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Pantry Health
                _PantryHealthCard(score: prov.pantryHealthScore),
                const SizedBox(height: 20),

                // Stats Row
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.sensors,
                        label: 'DEVICES',
                        value:
                            '${prov.onlineDevicesCount}/${prov.devices.length}',
                        color: AppColors.info,
                        suffix: 'online',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.warning_amber_rounded,
                        label: 'LOW STOCK',
                        value: '${prov.lowStockCount}',
                        color: prov.lowStockCount > 0
                            ? AppColors.warning
                            : AppColors.success,
                        suffix: 'items',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.restaurant_menu,
                        label: 'RECIPES',
                        value: '${prov.availableRecipeCount}',
                        color: AppColors.success,
                        suffix: 'ready',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Quick Actions
                _SectionHeader(title: 'Quick Actions'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 90,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _QuickAction(
                        icon: Icons.add_circle_outline,
                        label: 'Add\nDevice',
                        color: AppColors.goldPrimary,
                        onTap: () => _goTab(context, 1),
                      ),
                      const SizedBox(width: 12),
                      _QuickAction(
                        icon: Icons.inventory_2_outlined,
                        label: 'Pantry\nStock',
                        color: AppColors.info,
                        onTap: () => _goTab(context, 2),
                      ),
                      const SizedBox(width: 12),
                      _QuickAction(
                        icon: Icons.restaurant_menu_outlined,
                        label: 'Cook\nNow',
                        color: AppColors.success,
                        onTap: () => _goTab(context, 3),
                      ),
                      const SizedBox(width: 12),
                      _QuickAction(
                        icon: Icons.receipt_long_outlined,
                        label: 'Scan\nBill',
                        color: AppColors.warning,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GroceryScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Device Summary
                _SectionHeader(
                  title: 'Live Inventory',
                  trailing: 'See All',
                  onTrailingTap: () => _goTab(context, 1),
                ),
                const SizedBox(height: 12),
                ...prov.devices
                    .take(4)
                    .map(
                      (d) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DeviceSummaryTile(device: d),
                      ),
                    ),
                const SizedBox(height: 24),

                // Recent Alerts
                if (prov.alerts.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Recent Alerts',
                    trailing: 'See All',
                    onTrailingTap: () => _goTab(context, 4),
                  ),
                  const SizedBox(height: 12),
                  ...prov.alerts
                      .take(3)
                      .map(
                        (a) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _AlertTile(
                            alert: a,
                            onTap: () =>
                                context.read<AppProvider>().markAlertRead(a.id),
                          ),
                        ),
                      ),
                ],
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _goTab(BuildContext context, int tab) {
    // Use the MainScreen's IndexedStack via inherited state
    final scaffold = Scaffold.of(context);
    // Simpler: navigate via callback not available in pure widget tree
    // For production, use a GlobalKey or NavigationService
  }
}

// Pantry Health Card
class _PantryHealthCard extends StatelessWidget {
  final double score;
  const _PantryHealthCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final pct = (score * 100).round();
    final color = score > 0.7
        ? AppColors.success
        : score > 0.4
        ? AppColors.warning
        : AppColors.error;
    final label = score > 0.7
        ? 'Excellent'
        : score > 0.4
        ? 'Needs Attention'
        : 'Critical';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C1A12), Color(0xFF1C1C1F)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGold, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.goldDim,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.kitchen,
                  color: AppColors.goldPrimary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PANTRY HEALTH', style: AppTextStyles.goldLabel),
                  Text(
                    label,
                    style: AppTextStyles.headingSmall.copyWith(color: color),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '$pct%',
                style: AppTextStyles.displaySmall.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score,
              backgroundColor: AppColors.bgSurface,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(score * 100).round()}% of your pantry items are well-stocked',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

// Stat Card
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value, suffix;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.weightSmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          Text(label, style: AppTextStyles.labelSmall),
          Text(
            suffix,
            style: AppTextStyles.bodySmall.copyWith(color: color, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// Quick Action
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSmall.copyWith(
                color: color,
                letterSpacing: 0.2,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Section Header
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  const _SectionHeader({
    required this.title,
    this.trailing,
    this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: AppTextStyles.headingMedium),
        const Spacer(),
        if (trailing != null)
          GestureDetector(
            onTap: onTrailingTap,
            child: Text(
              trailing!,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.goldPrimary,
              ),
            ),
          ),
      ],
    );
  }
}

// Device Summary Tile
class _DeviceSummaryTile extends StatelessWidget {
  final dynamic device;
  const _DeviceSummaryTile({required this.device});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.categoryColor(device.category as String);
    final isLow = device.isLowStock as bool;
    final isOnline = device.isOnline as bool;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLow ? AppColors.warningDim : AppColors.borderSubtle,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: isOnline
                  ? (isLow ? AppColors.warning : color)
                  : AppColors.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name as String,
                  style: AppTextStyles.headingSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(device.category as String, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                device.weightFormatted as String,
                style: AppTextStyles.weightSmall,
              ),
              if (isLow)
                Text(
                  'LOW STOCK',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.warning,
                  ),
                )
              else if (!isOnline)
                Text(
                  'OFFLINE',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// Alert Tile
class _AlertTile extends StatelessWidget {
  final dynamic alert;
  final VoidCallback onTap;
  const _AlertTile({required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: (alert.isRead as bool)
              ? AppColors.bgCard
              : AppColors.warningDim,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (alert.isRead as bool)
                ? AppColors.borderSubtle
                : AppColors.warning.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: (alert.isRead as bool)
                  ? AppColors.textMuted
                  : AppColors.warning,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title as String,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: (alert.isRead as bool)
                          ? FontWeight.normal
                          : FontWeight.w600,
                    ),
                  ),
                  Text(
                    alert.message as String,
                    style: AppTextStyles.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!(alert.isRead as bool))
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.warning,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
