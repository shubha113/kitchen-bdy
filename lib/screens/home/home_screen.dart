import 'package:app/screens/alerts/alerts_screen.dart';
import 'package:app/screens/cook/cook_screen.dart';
import 'package:app/screens/inventory/inventory_screen.dart';
import 'package:app/screens/waitlist/waitlist_screen.dart';
import 'package:app/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../providers/app_provider.dart';
import '../../providers/theme_provider.dart';
import '../grocery/grocery_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final t = AppTheme.of(context);
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';

    return Scaffold(
      backgroundColor: t.bgPrimary,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 130,
            floating: false,
            pinned: true,
            backgroundColor: t.bgPrimary,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text('Kitchen BDY', style: AppTextStyles.goldHeading),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: t.isDark
                        ? [const Color(0xFF1A1500), AppColors.bgPrimary]
                        : [const Color(0xFFFDF6E3), AppColors.lightBgPrimary],
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
                      style: AppTextStyles.bodySmallOf(context),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              // Theme Toggle
              Consumer<ThemeProvider>(
                builder: (context, themeProv, _) {
                  final isDark = themeProv.isDark;
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: GestureDetector(
                      onTap: () => themeProv.toggle(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: t.bgCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: t.borderGold),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isDark
                                  ? Icons.dark_mode_rounded
                                  : Icons.light_mode_rounded,
                              color: AppColors.goldPrimary,
                              size: 15,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isDark ? 'Dark' : 'Light',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.goldPrimary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Grocery
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GroceryScreen()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: t.bgCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: t.borderGold),
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      color: AppColors.goldPrimary,
                      size: 20,
                    ),
                  ),
                ),
              ),
              // Sign out
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: t.bgCard,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Text(
                          'Sign Out',
                          style: AppTextStyles.headingSmallOf(context),
                        ),
                        content: Text(
                          'Are you sure you want to sign out?',
                          style: AppTextStyles.bodySmallOf(context),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: t.textSecondary),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.goldPrimary,
                              foregroundColor: AppColors.textOnGold,
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
                      await ApiService.googleSignOut();
                      await ApiService.clearToken();

                      context.read<AppProvider>().clearDevices();

                      if (context.mounted) {
                        Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/login', (_) => false);
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: t.bgCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: t.borderGold),
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: AppColors.goldPrimary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _PantryHealthCard(score: prov.pantryHealthScore),
                const SizedBox(height: 20),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                ),
                const SizedBox(height: 24),
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
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WaitlistScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _QuickAction(
                        icon: Icons.inventory_2_outlined,
                        label: 'Pantry\nStock',
                        color: AppColors.info,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const InventoryScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _QuickAction(
                        icon: Icons.restaurant_menu_outlined,
                        label: 'Cook\nNow',
                        color: AppColors.success,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CookScreen()),
                        ),
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
                _SectionHeader(
                  title: 'Live Inventory',
                  trailing: 'See All',
                  onTrailingTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const InventoryScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                ...prov.devices
                    .take(3)
                    .map(
                      (d) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DeviceSummaryTile(device: d),
                      ),
                    ),
                const SizedBox(height: 24),
                if (prov.alerts.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Recent Alerts',
                    trailing: 'See All',
                    onTrailingTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AlertsScreen()),
                      );
                    },
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
}

class _PantryHealthCard extends StatelessWidget {
  final double score;
  const _PantryHealthCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
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
        color: t.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.borderGold, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: t.goldDim,
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
                    style: AppTextStyles.headingSmallOf(
                      context,
                    ).copyWith(color: color),
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
              backgroundColor: t.bgSurface,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(score * 100).round()}% of your pantry items are well-stocked',
            style: AppTextStyles.bodySmallOf(context),
          ),
        ],
      ),
    );
  }
}

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
    final t = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.weightSmallOf(context)),
          Text(
            label,
            style: AppTextStyles.labelSmallOf(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            suffix,
            style: AppTextStyles.bodySmallOf(
              context,
            ).copyWith(color: color, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

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
        Text(title, style: AppTextStyles.headingMediumOf(context)),
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

class _DeviceSummaryTile extends StatelessWidget {
  final dynamic device;
  const _DeviceSummaryTile({required this.device});

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final color = AppColors.categoryColor(device.category as String);
    final isLow = device.isLowStock as bool;
    final isOnline = device.isOnline as bool;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: t.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLow ? AppColors.warningDim : t.borderSubtle,
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
                  : t.textMuted,
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
                  style: AppTextStyles.headingSmallOf(context),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  device.category as String,
                  style: AppTextStyles.bodySmallOf(context),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                device.weightFormatted as String,
                style: AppTextStyles.weightSmallOf(context),
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
                  style: AppTextStyles.labelSmall.copyWith(color: t.textMuted),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final dynamic alert;
  final VoidCallback onTap;
  const _AlertTile({required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final isRead = alert.isRead as bool;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? t.bgCard : t.warningDim,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRead
                ? t.borderSubtle
                : AppColors.warning.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: isRead ? t.textMuted : AppColors.warning,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title as String,
                    style: AppTextStyles.bodyMediumOf(context).copyWith(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                    ),
                  ),
                  Text(
                    alert.message as String,
                    style: AppTextStyles.bodySmallOf(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!isRead)
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
