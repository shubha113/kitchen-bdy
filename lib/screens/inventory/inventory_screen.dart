import 'package:app/main.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/app_constants.dart';
import '../../models/alert.dart';
import '../../models/device.dart';
import '../../models/manual_inventory_item.dart';
import '../../providers/app_provider.dart';
import '../../services/manual_inventory.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  String _selectedCategory = 'All';
  String _sortBy = 'Name';
  bool _showLowOnly = false;
  List<ManualInventoryItem> _manualItems = [];
  bool _loadingManual = true;
  late TabController _tabController;
  final Set<int> _checkedLowStockIds = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() => _loadManual();

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadManual();
  }

  Future<void> _loadManual() async {
    setState(() => _loadingManual = true);
    final items = await ManualInventoryService.getUserInventory();
    if (!mounted) return;
    setState(() {
      _manualItems = items;
      _loadingManual = false;

      final validIds = items.map((e) => e.id).toSet();
      _checkedLowStockIds.removeWhere((id) => !validIds.contains(id));
    });
    // After loading, surface any due reminders as alerts
    _checkAndInjectReminderAlerts(items);
  }

  Future<void> _checkAndInjectReminderAlerts(
    List<ManualInventoryItem> items,
  ) async {
    final dueItems = await ManualInventoryService.getDueReminders();
    if (!mounted || dueItems.isEmpty) return;

    final prov = context.read<AppProvider>();
    for (final item in dueItems) {
      final alert = AppAlert(
        id: 'reminder_${item.id}_${item.reminderDate!.millisecondsSinceEpoch}',
        type: AlertType.refillReminder,
        title: '${item.itemName} — Refill Reminder',
        message:
            'You set a reminder to check your ${item.itemName} stock. '
            'Currently ${item.remainingFormatted} remaining.',
        timestamp: item.reminderDate!,
        itemName: item.itemName,
      );
      prov.addAlert(alert);
      // Mark fired so it doesn't resurface on next load
      ManualInventoryService.markReminderFired(item.id);
    }
  }

  List<ManualInventoryItem> get _lowStockItems =>
      _manualItems
          .where((m) => m.isLowStock && !(m.isFilledByUser ?? false))
          .toList()
        ..sort((a, b) => a.itemName.compareTo(b.itemName));

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final t = AppTheme.of(context);

    var sensorItems = prov.devices.toList();
    if (_showLowOnly)
      sensorItems = sensorItems.where((d) => d.isLowStock).toList();
    if (_selectedCategory != 'All')
      sensorItems = sensorItems
          .where((d) => d.category == _selectedCategory)
          .toList();
    if (_sortBy == 'Name') sensorItems.sort((a, b) => a.name.compareTo(b.name));
    if (_sortBy == 'Weight')
      sensorItems.sort((a, b) => a.currentWeight.compareTo(b.currentWeight));
    if (_sortBy == 'Status')
      sensorItems.sort(
        (a, b) => (a.isLowStock ? 0 : 1).compareTo(b.isLowStock ? 0 : 1),
      );

    var manualFiltered = _manualItems.toList();
    if (_selectedCategory != 'All')
      manualFiltered = manualFiltered
          .where((m) => m.category == _selectedCategory)
          .toList();
    if (_showLowOnly)
      manualFiltered = manualFiltered.where((m) => m.isLowStock).toList();
    if (_sortBy == 'Name')
      manualFiltered.sort((a, b) => a.itemName.compareTo(b.itemName));

    final lowItems = _lowStockItems;

    return Scaffold(
      backgroundColor: t.bgPrimary,
      appBar: AppBar(
        backgroundColor: t.bgPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: t.textSecondary,
                  size: 18,
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          'Pantry Inventory',
          style: AppTextStyles.headingLargeOf(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh,
              color: AppColors.goldPrimary,
              size: 20,
            ),
            onPressed: _loadManual,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              _CategoryFilter(
                selected: _selectedCategory,
                onChanged: (v) => setState(() => _selectedCategory = v),
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.goldPrimary,
                labelColor: AppColors.goldPrimary,
                unselectedLabelColor: t.textSecondary,
                labelStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                tabs: [
                  Tab(text: 'Live Scale (${sensorItems.length})'),
                  Tab(text: 'My Stock (${manualFiltered.length})'),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Low Stock',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: lowItems.isEmpty
                                ? t.textSecondary
                                : AppColors.warning,
                          ),
                        ),
                        if (lowItems.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${lowItems.length}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSensorTab(sensorItems),
          _buildManualTab(manualFiltered),
          _buildLowStockTab(lowItems),
        ],
      ),
    );
  }

  // Low Stock Tab
  Widget _buildLowStockTab(List<ManualInventoryItem> items) {
    final t = AppTheme.of(context);
    if (_loadingManual)
      return const Center(
        child: CircularProgressIndicator(color: AppColors.goldPrimary),
      );

    if (items.isEmpty)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                'All stocked up!',
                style: AppTextStyles.headingMediumOf(
                  context,
                ).copyWith(color: AppColors.success),
              ),
              const SizedBox(height: 8),
              Text(
                'No items are below their threshold.',
                style: AppTextStyles.bodySmallOf(context),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

    final checkedCount = _checkedLowStockIds.length;

    return Stack(
      children: [
        RefreshIndicator(
          color: AppColors.goldPrimary,
          onRefresh: _loadManual,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              checkedCount > 0 ? 120 : 100,
            ),
            children: [
              GestureDetector(
                onTap: () => _shareAll(items),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: t.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.goldPrimary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.share_outlined,
                        color: AppColors.goldPrimary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Share Shopping List (${items.length} items)',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.goldPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ...items.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LowStockCard(
                    item: m,
                    isChecked: _checkedLowStockIds.contains(m.id),
                    onCheckChanged: (checked) {
                      setState(() {
                        if (checked) {
                          _checkedLowStockIds.add(m.id);
                        } else {
                          _checkedLowStockIds.remove(m.id);
                        }
                      });
                    },
                    onShare: () => _shareOne(m),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (checkedCount > 0)
          Positioned(
            bottom: 24,
            right: 16,
            child: GestureDetector(
              onTap: _deleteCheckedItems,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Mark $checkedCount item${checkedCount > 1 ? 's' : ''} restocked',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Share helpers
  void _shareAll(List<ManualInventoryItem> items) {
    final buf = StringBuffer();
    buf.writeln('🛒 Shopping List — ${items.length} item(s) needed:\n');
    for (final m in items) {
      final thr = m.threshold != null;
      buf.writeln('• ${m.itemName} — ${m.remainingFormatted} left');
    }
    buf.writeln('\nSent from KitchenBDY 🍽️');
    Share.share(buf.toString(), subject: 'Shopping List');
  }

  void _shareOne(ManualInventoryItem m) {
    final thr = m.threshold != null;
    Share.share(
      '🛒 ${m.itemName} — only ${m.remainingFormatted} left. $thr\n\nSent from KitchenBDY 🍽️',
      subject: '${m.itemName} — Low Stock',
    );
  }

  Future<void> _deleteCheckedItems() async {
    if (_checkedLowStockIds.isEmpty) return;
    final ids = Set<int>.from(_checkedLowStockIds);
    final count = ids.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppTheme.of(context).bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Mark $count item${count > 1 ? 's' : ''} as restocked?',
          style: AppTextStyles.headingSmallOf(context),
        ),
        content: Text(
          'This will remove $count item${count > 1 ? 's' : ''} from Low Stock. '
          'They\'ll stay in My Stock tab.',
          style: AppTextStyles.bodySmallOf(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.of(context).textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Just mark as filled
    await Future.wait(
      ids.map((id) => ManualInventoryService.markFilled(id, true)),
    );
    setState(() => _checkedLowStockIds.clear());
    _loadManual();
  }

  // Sensor Tab
  Widget _buildSensorTab(List<KitchenDevice> items) {
    if (items.isEmpty)
      return _EmptyState(category: _selectedCategory, lowOnly: _showLowOnly);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SortFilterBar(
          sortBy: _sortBy,
          showLowOnly: _showLowOnly,
          onSort: () => _showSortMenu(context),
          onToggleLow: () => setState(() => _showLowOnly = !_showLowOnly),
          count: items.length,
        ),
        const SizedBox(height: 12),
        ...items.map(
          (d) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SensorCard(device: d),
          ),
        ),
      ],
    );
  }

  // Manual Tab
  Widget _buildManualTab(List<ManualInventoryItem> items) {
    final t = AppTheme.of(context);
    if (_loadingManual)
      return const Center(
        child: CircularProgressIndicator(color: AppColors.goldPrimary),
      );
    if (items.isEmpty)
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, color: t.textMuted, size: 48),
            const SizedBox(height: 16),
            Text(
              'No manual items yet',
              style: AppTextStyles.headingMediumOf(
                context,
              ).copyWith(color: t.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + Add Item to start tracking',
              style: AppTextStyles.bodySmallOf(context),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    return RefreshIndicator(
      color: AppColors.goldPrimary,
      onRefresh: _loadManual,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: items
            .map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ManualCard(
                  item: m,
                  onUpdated: _loadManual,
                  onDeleted: _loadManual,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  void _showSortMenu(BuildContext context) {
    final t = AppTheme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: t.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sort By', style: AppTextStyles.headingMediumOf(context)),
            const SizedBox(height: 16),
            ...['Name', 'Weight', 'Status'].map(
              (s) => ListTile(
                title: Text(s, style: AppTextStyles.bodyMediumOf(context)),
                trailing: _sortBy == s
                    ? const Icon(Icons.check, color: AppColors.goldPrimary)
                    : null,
                onTap: () {
                  setState(() => _sortBy = s);
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// LOW STOCK CARD
class _LowStockCard extends StatelessWidget {
  final ManualInventoryItem item;
  final bool isChecked;
  final void Function(bool) onCheckChanged;
  final VoidCallback onShare;

  const _LowStockCard({
    required this.item,
    required this.isChecked,
    required this.onCheckChanged,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final catColor = AppColors.categoryColor(item.category);
    final isOut = item.isOutOfStock;
    final pct = item.totalPurchased > 0
        ? (item.packsRemaining / item.totalPurchased).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isChecked
              ? AppColors.success.withValues(alpha: 0.5)
              : isOut
              ? AppColors.error.withValues(alpha: 0.5)
              : AppColors.warning.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => onCheckChanged(!isChecked),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isChecked ? AppColors.success : Colors.transparent,
                    border: Border.all(
                      color: isChecked ? AppColors.success : AppColors.warning,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: isChecked
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName,
                      style: AppTextStyles.headingSmallOf(context).copyWith(
                        decoration: isChecked
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: t.textSecondary,
                        color: isChecked ? t.textSecondary : t.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      item.category,
                      style: AppTextStyles.bodySmallOf(
                        context,
                      ).copyWith(color: catColor),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isChecked
                      ? AppColors.success.withValues(alpha: 0.1)
                      : isOut
                      ? t.errorDim
                      : t.warningDim,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.remainingFormatted,
                  style: TextStyle(
                    color: isChecked
                        ? AppColors.success
                        : isOut
                        ? AppColors.error
                        : AppColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onShare,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: t.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.share_outlined,
                    size: 15,
                    color: t.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: t.bgSurface,
              valueColor: AlwaysStoppedAnimation<Color>(
                isChecked
                    ? AppColors.success
                    : isOut
                    ? AppColors.error
                    : AppColors.warning,
              ),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (item.threshold != null) ...[
                Icon(
                  Icons.warning_amber_outlined,
                  size: 12,
                  color: isChecked ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 4),
                Text(
                  isChecked
                      ? 'Marked as restocked'
                      : 'Below ${item.threshold!.toStringAsFixed(item.threshold! % 1 == 0 ? 0 : 1)} ${item.unit}',
                  style: AppTextStyles.bodySmallOf(context).copyWith(
                    color: isChecked ? AppColors.success : AppColors.warning,
                  ),
                ),
              ],
              const Spacer(),
              if (isChecked)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 10,
                        color: AppColors.success,
                      ),
                      SizedBox(width: 3),
                      Text(
                        'Restocked',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ADD ITEM SHEET
class _AddItemSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const _AddItemSheet({required this.onSaved});
  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  final _nameCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _packsCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _thresholdCtrl = TextEditingController();
  String _unit = 'kg';
  String _category = 'Grains';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _quantityCtrl.dispose();
    _packsCtrl.dispose();
    _priceCtrl.dispose();
    _thresholdCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _quantityCtrl.text.trim().isEmpty)
      return;
    setState(() => _saving = true);
    await ManualInventoryService.addPurchase(
      itemName: _nameCtrl.text.trim(),
      category: _category,
      quantity: double.tryParse(_quantityCtrl.text) ?? 0,
      unit: _unit,
      packsCount: double.tryParse(_packsCtrl.text),
      totalPrice: double.tryParse(_priceCtrl.text),
      threshold: double.tryParse(_thresholdCtrl.text),
    );
    if (mounted) {
      Navigator.pop(context);
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.88,
          minHeight: 200,
        ),
        decoration: BoxDecoration(
          color: t.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: t.borderMedium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: t.goldDim,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.add_shopping_cart,
                      color: AppColors.goldPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Add Inventory Item',
                    style: AppTextStyles.headingMediumOf(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SheetField(
                      _nameCtrl,
                      'Item Name',
                      'e.g. Basmati Rice',
                      Icons.label_outline,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _SheetField(
                            _quantityCtrl,
                            'Quantity',
                            '4',
                            Icons.scale_outlined,
                            numeric: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 110,
                          child: DropdownButtonFormField<String>(
                            value: _unit,
                            dropdownColor: t.bgCardElevated,
                            isExpanded: true,
                            style: TextStyle(
                              color: t.textPrimary,
                              fontSize: 14,
                            ),
                            decoration: _dec(
                              context,
                              t,
                              'Unit',
                              Icons.straighten,
                            ),
                            items: AppConstants.units
                                .map(
                                  (u) => DropdownMenuItem(
                                    value: u,
                                    child: Text(u),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _unit = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SheetField(
                      _priceCtrl,
                      'Total price paid (optional, ₹)',
                      'e.g. 240 for 2kg bag',
                      Icons.currency_rupee,
                      numeric: true,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Total amount paid — we'll calculate price per $_unit automatically",
                      style: TextStyle(color: t.textMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    _SheetField(
                      _thresholdCtrl,
                      'Low stock alert below (optional, $_unit)',
                      'e.g. 0.5',
                      Icons.warning_amber_outlined,
                      numeric: true,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "We'll warn you when stock drops below this amount",
                      style: TextStyle(color: t.textMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    _SheetField(
                      _packsCtrl,
                      'No. of Packs (optional)',
                      'e.g. 4 packs of 1 kg',
                      Icons.inventory_2_outlined,
                      numeric: true,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _category,
                      dropdownColor: t.bgCardElevated,
                      isExpanded: true,
                      style: TextStyle(color: t.textPrimary, fontSize: 14),
                      decoration: _dec(
                        context,
                        t,
                        'Category',
                        Icons.category_outlined,
                      ),
                      items: AppConstants.categories
                          .where((c) => c != 'All')
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _category = v!),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.goldPrimary,
                    foregroundColor: AppColors.textOnGold,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Save to Inventory',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static InputDecoration _dec(
    BuildContext context,
    AppTheme t,
    String label,
    IconData icon,
  ) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: t.textSecondary, fontSize: 12),
    prefixIcon: Icon(icon, color: t.textSecondary, size: 18),
    filled: true,
    fillColor: t.bgSurface,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: t.borderSubtle),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.goldPrimary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  );
}

// SHEET TEXT FIELD
class _SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final bool numeric;
  const _SheetField(
    this.ctrl,
    this.label,
    this.hint,
    this.icon, {
    this.numeric = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return TextField(
      controller: ctrl,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: TextStyle(color: t.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: t.textMuted, fontSize: 13),
        labelStyle: TextStyle(color: t.textSecondary, fontSize: 12),
        prefixIcon: Icon(icon, color: t.textSecondary, size: 18),
        filled: true,
        fillColor: t.bgSurface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: t.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.goldPrimary,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );
  }
}

// UPDATE STOCK SHEET
class _UpdateStockSheet extends StatefulWidget {
  final ManualInventoryItem item;
  final VoidCallback onUpdated;
  const _UpdateStockSheet({required this.item, required this.onUpdated});
  @override
  State<_UpdateStockSheet> createState() => _UpdateStockSheetState();
}

class _UpdateStockSheetState extends State<_UpdateStockSheet> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.item.packsRemaining;
    _ctrl = TextEditingController(
      text: r % 1 == 0 ? r.toInt().toString() : r.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final val = double.tryParse(_ctrl.text) ?? widget.item.packsRemaining;
    setState(() => _saving = true);
    await ManualInventoryService.updateRemaining(widget.item.id, val);
    if (mounted) {
      Navigator.pop(context);
      widget.onUpdated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: t.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: t.borderMedium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Update Stock — ${widget.item.itemName}',
              style: AppTextStyles.headingMediumOf(context),
            ),
            const SizedBox(height: 6),
            Text(
              'How much ${widget.item.unit} do you currently have?',
              style: AppTextStyles.bodySmallOf(context),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                labelText: 'Remaining (${widget.item.unit})',
                labelStyle: TextStyle(color: t.textSecondary),
                suffixText: widget.item.unit,
                suffixStyle: const TextStyle(color: AppColors.goldPrimary),
                filled: true,
                fillColor: t.bgSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.goldPrimary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldPrimary,
                  foregroundColor: AppColors.textOnGold,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// SET THRESHOLD SHEET
class _SetThresholdSheet extends StatefulWidget {
  final ManualInventoryItem item;
  final VoidCallback onUpdated;
  const _SetThresholdSheet({required this.item, required this.onUpdated});
  @override
  State<_SetThresholdSheet> createState() => _SetThresholdSheetState();
}

class _SetThresholdSheetState extends State<_SetThresholdSheet> {
  late final TextEditingController _ctrl;
  late String _unit;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final th = widget.item.threshold;
    _unit = widget.item.thresholdUnit;
    _ctrl = TextEditingController(
      text: th == null
          ? ''
          : (th % 1 == 0 ? th.toInt().toString() : th.toStringAsFixed(1)),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final val = double.tryParse(_ctrl.text);
    setState(() => _saving = true);
    await ManualInventoryService.updateThreshold(
      widget.item.id,
      val,
      thresholdUnit: _unit,
    );
    if (mounted) {
      Navigator.pop(context);
      widget.onUpdated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final unit = widget.item.unit;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: t.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: t.borderMedium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: t.warningDim,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.warning_amber_outlined,
                    color: AppColors.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Low Stock Alert',
                        style: AppTextStyles.headingMediumOf(context),
                      ),
                      Text(
                        widget.item.itemName,
                        style: AppTextStyles.bodySmallOf(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Warn me when stock drops below this amount in $unit. Leave blank to remove the alert.',
              style: AppTextStyles.bodySmallOf(
                context,
              ).copyWith(color: t.textSecondary),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Alert below',
                      labelStyle: TextStyle(color: t.textSecondary),
                      hintText: 'e.g. 200',
                      hintStyle: TextStyle(color: t.textMuted),
                      filled: true,
                      fillColor: t.bgSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.warning,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 100,
                  child: DropdownButtonFormField<String>(
                    value: _unit,
                    dropdownColor: t.bgCardElevated,
                    style: TextStyle(color: t.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Unit',
                      labelStyle: TextStyle(
                        color: t.textSecondary,
                        fontSize: 12,
                      ),
                      filled: true,
                      fillColor: t.bgSurface,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: t.borderSubtle),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.warning,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    items: AppConstants.units
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) => setState(() => _unit = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        'Save Alert',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// SET REMINDER SHEET
class _SetReminderSheet extends StatefulWidget {
  final ManualInventoryItem item;
  final VoidCallback onUpdated;
  const _SetReminderSheet({required this.item, required this.onUpdated});
  @override
  State<_SetReminderSheet> createState() => _SetReminderSheetState();
}

class _SetReminderSheetState extends State<_SetReminderSheet> {
  DateTime? _selectedDate;
  bool _isRecurring = false;
  String? _repeatType;
  bool _saving = false;

  // Preset options: label → days from now (null = open date picker)
  static const _presets = <String, int?>{
    'Tomorrow': 1,
    'In 3 days': 3,
    'In 1 week': 7,
    'In 2 weeks': 14,
    'In 1 month': 30,
    'Custom date': null,
  };

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.item.reminderDate;
  }

  /// Returns a Date at noon on the given day offset so the reminder fires
  /// during waking hours regardless of timezone.
  DateTime _daysFromNow(int days) {
    final base = DateTime.now().add(Duration(days: days));
    return DateTime(base.year, base.month, base.day, 12, 0);
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),

      // 👇 ADD HERE
      builder: (ctx, child) {
        final t = AppTheme.of(ctx);

        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(ctx).colorScheme.copyWith(
              primary: AppColors.goldPrimary,
              surface: t.bgCard,
              onSurface: t.textPrimary,
            ),
            dialogBackgroundColor: t.bgCard,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day, 12, 0);
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    await ManualInventoryService.setReminder(
      widget.item.id,
      _selectedDate,
      reminderRecurring: _isRecurring,
      reminderRepeatType: _repeatType,
    );

    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
      widget.onUpdated();
    }
  }

  Future<void> _clearReminder() async {
    setState(() => _saving = true);
    await ManualInventoryService.setReminder(widget.item.id, null);
    if (mounted) {
      Navigator.pop(context);
      widget.onUpdated();
    }
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final hasExisting = widget.item.reminderDate != null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom:
              MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: t.bgCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.borderMedium,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.alarm_outlined,
                      color: AppColors.info,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set Reminder',
                          style: AppTextStyles.headingMediumOf(context),
                        ),
                        Text(
                          widget.item.itemName,
                          style: AppTextStyles.bodySmallOf(context),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Clear button if reminder already set
                  if (hasExisting && !_saving)
                    GestureDetector(
                      onTap: _clearReminder,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          'Clear',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                "We'll remind you to check or refill this item on the selected day.",
                style: AppTextStyles.bodySmallOf(
                  context,
                ).copyWith(color: t.textSecondary),
              ),

              // Current reminder info
              if (hasExisting) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.alarm_on,
                        size: 14,
                        color: AppColors.info,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.item.reminderFired
                            ? 'Last reminder: ${_formatDate(widget.item.reminderDate!)}'
                            : 'Current reminder: ${_formatDate(widget.item.reminderDate!)}',
                        style: TextStyle(color: AppColors.info, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Preset chips — using Wrap so they never overflow
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presets.entries.map((entry) {
                  final label = entry.key;
                  final days = entry.value;

                  // Determine if this preset is currently selected
                  final bool isSelected = () {
                    if (_selectedDate == null) return false;
                    if (days == null) {
                      // "Custom date" is selected when no preset matches
                      final anyPresetMatch = _presets.values
                          .whereType<int>()
                          .any(
                            (d) => _isSameDay(_selectedDate!, _daysFromNow(d)),
                          );
                      return !anyPresetMatch;
                    }
                    return _isSameDay(_selectedDate!, _daysFromNow(days));
                  }();

                  return GestureDetector(
                    onTap: () async {
                      if (days == null) {
                        await _pickCustomDate();
                      } else {
                        setState(() => _selectedDate = _daysFromNow(days));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.info.withValues(alpha: 0.15)
                            : t.bgSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.info : t.borderSubtle,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (days == null)
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 12,
                              color: isSelected
                                  ? AppColors.info
                                  : t.textSecondary,
                            ),
                          if (days == null) const SizedBox(width: 4),
                          Text(
                            label,
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.info
                                  : t.textSecondary,
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              // After the preset chips Wrap, add:
              const SizedBox(height: 16),
              Text(
                'Repeat?',
                style: AppTextStyles.bodySmallOf(
                  context,
                ).copyWith(color: t.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // No repeat
                  _RepeatChip(
                    label: 'Once',
                    icon: Icons.looks_one_outlined,
                    selected: !_isRecurring,
                    onTap: () => setState(() {
                      _isRecurring = false;
                      _repeatType = null;
                    }),
                  ),
                  const SizedBox(width: 8),
                  // Weekly
                  _RepeatChip(
                    label: 'Every week',
                    icon: Icons.repeat,
                    selected: _isRecurring && _repeatType == 'weekly',
                    onTap: () => setState(() {
                      _isRecurring = true;
                      _repeatType = 'weekly';
                    }),
                  ),
                  const SizedBox(width: 8),
                  // Monthly
                  _RepeatChip(
                    label: 'Every month',
                    icon: Icons.calendar_month_outlined,
                    selected: _isRecurring && _repeatType == 'monthly',
                    onTap: () => setState(() {
                      _isRecurring = true;
                      _repeatType = 'monthly';
                    }),
                  ),
                ],
              ),

              // Show selected date
              if (_selectedDate != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event_available,
                        size: 16,
                        color: AppColors.info,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Reminder set for: ${_formatDate(_selectedDate!)}',
                        style: const TextStyle(
                          color: AppColors.info,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedDate != null
                        ? AppColors.info
                        : t.bgSurface,
                    foregroundColor: _selectedDate != null
                        ? Colors.white
                        : t.textMuted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: (_saving || _selectedDate == null) ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _selectedDate == null
                              ? 'Select a date above'
                              : 'Save Reminder',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// MANUAL CARD
class _ManualCard extends StatelessWidget {
  final ManualInventoryItem item;
  final VoidCallback onUpdated, onDeleted;
  const _ManualCard({
    required this.item,
    required this.onUpdated,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final catColor = AppColors.categoryColor(item.category);
    final isLow = item.isLowStock;
    final isOut = item.isOutOfStock;
    final needsRecon = item.needsReconciliation;
    final pct = item.totalPurchased > 0
        ? (item.packsRemaining / item.totalPurchased).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOut
              ? AppColors.error.withValues(alpha: 0.5)
              : isLow
              ? AppColors.warning.withValues(alpha: 0.4)
              : needsRecon
              ? AppColors.goldPrimary.withValues(alpha: 0.25)
              : t.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Expanded(
                child: Text(
                  item.itemName,
                  style: AppTextStyles.headingSmallOf(context),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Reminder badge — shows when an active reminder is set
              if (item.hasActiveReminder) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.alarm, size: 10, color: AppColors.info),
                      const SizedBox(width: 3),
                      Text(
                        item.reminderLabel ?? '',
                        style: const TextStyle(
                          color: AppColors.info,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOut
                      ? t.errorDim
                      : isLow
                      ? t.warningDim
                      : t.bgSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.remainingFormatted,
                  style: TextStyle(
                    color: isOut
                        ? AppColors.error
                        : isLow
                        ? AppColors.warning
                        : t.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: t.bgSurface,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOut
                    ? AppColors.error
                    : isLow
                    ? AppColors.warning
                    : catColor,
              ),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),

          // Meta row
          Row(
            children: [
              Text(
                item.category,
                style: AppTextStyles.bodySmallOf(
                  context,
                ).copyWith(color: catColor),
              ),
              const SizedBox(width: 6),
              Text('·', style: AppTextStyles.bodySmallOf(context)),
              const SizedBox(width: 6),
              Text(
                '${item.totalPurchased.toStringAsFixed(1)} ${item.unit} bought',
                style: AppTextStyles.bodySmallOf(context),
              ),

              const Spacer(),

              if (needsRecon)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: t.goldDim,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.lastReconciled == null
                        ? 'Never updated'
                        : 'Update count',
                    style: const TextStyle(
                      color: AppColors.goldPrimary,
                      fontSize: 9,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),

          Row(
            children: [
              if (item.threshold != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: t.warningDim,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.thresholdLabel ?? '',
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Chip(
                Icons.edit_outlined,
                'Update Stock',
                null,
                () => _openUpdateSheet(context),
              ),
              _Chip(
                Icons.warning_amber_outlined,
                'Set Alert',
                item.threshold != null ? AppColors.warning : null,
                () => _openThresholdSheet(context),
              ),
              // REMINDER CHIP
              _Chip(
                item.hasActiveReminder
                    ? Icons.alarm_on
                    : Icons.alarm_add_outlined,
                item.hasActiveReminder ? 'Edit Reminder' : 'Set Reminder',
                item.hasActiveReminder ? AppColors.info : null,
                () => _openReminderSheet(context),
              ),
              _Chip(
                Icons.delete_outline,
                'Remove',
                AppColors.error,
                () => _confirmDelete(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openUpdateSheet(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _UpdateStockSheet(item: item, onUpdated: onUpdated),
  );

  void _openThresholdSheet(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SetThresholdSheet(item: item, onUpdated: onUpdated),
  );

  /// Opens the reminder bottom sheet — new
  void _openReminderSheet(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SetReminderSheet(item: item, onUpdated: onUpdated),
  );

  void _confirmDelete(BuildContext context) {
    final t = AppTheme.of(context);
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: t.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Item',
          style: AppTextStyles.headingSmallOf(context),
        ),
        content: Text(
          'Remove "${item.itemName}" from inventory?',
          style: AppTextStyles.bodySmallOf(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: Text('Cancel', style: TextStyle(color: t.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await ManualInventoryService.delete(item.id);
              if (dCtx.mounted) Navigator.pop(dCtx);
              onDeleted();
            },
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// SENSOR CARD
class _SensorCard extends StatelessWidget {
  final KitchenDevice device;
  const _SensorCard({required this.device});

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final catColor = AppColors.categoryColor(device.category);
    final isLow = device.isLowStock;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLow
              ? AppColors.warning.withValues(alpha: 0.4)
              : t.borderSubtle,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: device.isOnline ? AppColors.success : t.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.sensors,
                      size: 10,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'S${device.slot}',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  device.name,
                  style: AppTextStyles.headingSmallOf(context),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                device.weightFormatted,
                style: AppTextStyles.weightSmallOf(context),
              ),
              if (isLow) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: t.warningDim,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'LOW',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: device.stockPercentage,
              backgroundColor: t.bgSurface,
              valueColor: AlwaysStoppedAnimation<Color>(
                isLow ? AppColors.warning : catColor,
              ),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                device.category,
                style: AppTextStyles.bodySmallOf(
                  context,
                ).copyWith(color: catColor),
              ),
              const SizedBox(width: 6),
              Text('·', style: AppTextStyles.bodySmallOf(context)),
              const SizedBox(width: 6),
              Text(device.location, style: AppTextStyles.bodySmallOf(context)),
              const Spacer(),
              Text(
                'Min: ${device.threshold.toStringAsFixed(0)} ${device.unit}',
                style: AppTextStyles.bodySmallOf(
                  context,
                ).copyWith(color: AppColors.goldPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// HELPERS
class _SortFilterBar extends StatelessWidget {
  final String sortBy;
  final bool showLowOnly;
  final VoidCallback onSort, onToggleLow;
  final int count;
  const _SortFilterBar({
    required this.sortBy,
    required this.showLowOnly,
    required this.onSort,
    required this.onToggleLow,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Row(
      children: [
        GestureDetector(
          onTap: onSort,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: t.bgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: t.borderSubtle),
            ),
            child: Row(
              children: [
                Icon(Icons.sort, size: 14, color: t.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Sort: $sortBy',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: t.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 14,
                  color: t.textSecondary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onToggleLow,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: showLowOnly ? t.warningDim : t.bgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: showLowOnly ? AppColors.warning : t.borderSubtle,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: showLowOnly ? AppColors.warning : t.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Low Stock',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: showLowOnly ? AppColors.warning : t.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        Text('$count items', style: AppTextStyles.bodySmallOf(context)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData i;
  final String l;
  final Color? c;
  final VoidCallback t;
  const _Chip(this.i, this.l, this.c, this.t);

  @override
  Widget build(BuildContext context) {
    final th = AppTheme.of(context);
    final col = c ?? th.textSecondary;
    return GestureDetector(
      onTap: t,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: col.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: col.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(i, size: 12, color: col),
            const SizedBox(width: 4),
            Text(
              l,
              style: TextStyle(
                color: col,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepeatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _RepeatChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.info.withValues(alpha: 0.15)
              : t.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.info : t.borderSubtle,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? AppColors.info : t.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.info : t.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  final String selected;
  final void Function(String) onChanged;
  const _CategoryFilter({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: AppConstants.categories.map((cat) {
          final isSelected = cat == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(cat),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.goldPrimary : t.bgCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.goldPrimary : t.borderSubtle,
                  ),
                ),
                child: Text(
                  cat,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: isSelected ? AppColors.textOnGold : t.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String category;
  final bool lowOnly;
  const _EmptyState({required this.category, required this.lowOnly});

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, color: t.textMuted, size: 48),
            const SizedBox(height: 16),
            Text(
              lowOnly ? 'No low-stock items!' : 'No items in $category',
              style: AppTextStyles.headingMediumOf(
                context,
              ).copyWith(color: t.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              lowOnly
                  ? 'Your pantry is well stocked 🎉'
                  : 'Add devices or tap + Add Item',
              style: AppTextStyles.bodySmallOf(context),
            ),
          ],
        ),
      ),
    );
  }
}
