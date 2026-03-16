import 'package:flutter/material.dart';
import 'package:kitchen_bdy/main.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/app_constants.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    _loadManual();
  }

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
    if (mounted)
      setState(() {
        _manualItems = items;
        _loadingManual = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();

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

    final linkedSensorIds = _manualItems
        .where((m) => m.linkedSensorId != null)
        .map((m) => m.linkedSensorId!)
        .toSet();
    final unlinkedSensors = sensorItems
        .where((d) => !linkedSensorIds.contains(d.id))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Pantry Inventory', style: AppTextStyles.headingLarge),
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
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                tabs: [
                  Tab(
                    text:
                        'All (${unlinkedSensors.length + manualFiltered.length})',
                  ),
                  Tab(text: 'Live Scale (${sensorItems.length})'),
                  Tab(text: 'My Stock (${manualFiltered.length})'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllTab(unlinkedSensors, manualFiltered),
          _buildSensorTab(sensorItems),
          _buildManualTab(manualFiltered),
        ],
      ),
    );
  }

  Widget _buildAllTab(
    List<KitchenDevice> sensors,
    List<ManualInventoryItem> manual,
  ) {
    if (sensors.isEmpty && manual.isEmpty)
      return _EmptyState(category: _selectedCategory, lowOnly: _showLowOnly);
    return RefreshIndicator(
      color: AppColors.goldPrimary,
      onRefresh: _loadManual,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _SortFilterBar(
            sortBy: _sortBy,
            showLowOnly: _showLowOnly,
            onSort: () => _showSortMenu(context),
            onToggleLow: () => setState(() => _showLowOnly = !_showLowOnly),
            count: sensors.length + manual.length,
          ),
          const SizedBox(height: 12),
          if (sensors.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.sensors,
              label: 'Live Scale',
              color: AppColors.success,
            ),
            const SizedBox(height: 8),
            ...sensors.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SensorCard(device: d),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (manual.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.inventory_2_outlined,
              label: 'My Stock',
              color: AppColors.goldPrimary,
            ),
            const SizedBox(height: 8),
            ...manual.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ManualCard(
                  item: m,
                  onUpdated: _loadManual,
                  onDeleted: _loadManual,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

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

  Widget _buildManualTab(List<ManualInventoryItem> items) {
    if (_loadingManual)
      return const Center(
        child: CircularProgressIndicator(color: AppColors.goldPrimary),
      );
    if (items.isEmpty)
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.textMuted,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'No manual items yet',
              style: AppTextStyles.headingMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + Add Item to start tracking',
              style: AppTextStyles.bodySmall,
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

  void _showAddItemSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddItemSheet(onSaved: _loadManual),
    );
  }

  void _showSortMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sort By', style: AppTextStyles.headingMedium),
            const SizedBox(height: 16),
            ...['Name', 'Weight', 'Status'].map(
              (s) => ListTile(
                title: Text(s, style: AppTextStyles.bodyMedium),
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
      pricePerUnit: double.tryParse(_priceCtrl.text),
      threshold: double.tryParse(_thresholdCtrl.text),
    );

    if (mounted) {
      Navigator.pop(context);
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
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
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  color: const Color(0xFF3A3A3A),
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
                      color: AppColors.goldDim,
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
                    style: AppTextStyles.headingMedium,
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
                            dropdownColor: const Color(0xFF252525),
                            isExpanded: true,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: _dec('Unit', Icons.straighten),
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
                      'Price per $_unit (optional, ₹)',
                      'e.g. 120',
                      Icons.currency_rupee,
                      numeric: true,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Leave blank if you don't want to track spending",
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Threshold
                    _SheetField(
                      _thresholdCtrl,
                      'Low stock alert below (optional, $_unit)',
                      'e.g. 0.5',
                      Icons.warning_amber_outlined,
                      numeric: true,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'We\'ll warn you when stock drops below this amount',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
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
                      dropdownColor: const Color(0xFF252525),
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: _dec('Category', Icons.category_outlined),
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

  static InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Color(0xFF888888), fontSize: 12),
    prefixIcon: Icon(icon, color: const Color(0xFF888888), size: 18),
    filled: true,
    fillColor: const Color(0xFF111111),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
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
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF555555), fontSize: 13),
      labelStyle: const TextStyle(color: Color(0xFF888888), fontSize: 12),
      prefixIcon: Icon(icon, color: const Color(0xFF888888), size: 18),
      filled: true,
      fillColor: const Color(0xFF111111),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.goldPrimary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ),
  );
}

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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  color: const Color(0xFF3A3A3A),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Update Stock — ${widget.item.itemName}',
              style: AppTextStyles.headingMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'How much ${widget.item.unit} do you currently have?',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                labelText: 'Remaining (${widget.item.unit})',
                labelStyle: const TextStyle(color: Color(0xFF888888)),
                suffixText: widget.item.unit,
                suffixStyle: const TextStyle(color: AppColors.goldPrimary),
                filled: true,
                fillColor: const Color(0xFF111111),
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
    _unit = widget.item.unit;
    final t = widget.item.threshold;
    _ctrl = TextEditingController(
      text: t == null
          ? ''
          : (t % 1 == 0 ? t.toInt().toString() : t.toStringAsFixed(1)),
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
    await ManualInventoryService.updateThreshold(widget.item.id, val);
    if (mounted) {
      Navigator.pop(context);
      widget.onUpdated();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  color: const Color(0xFF3A3A3A),
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
                    color: AppColors.warningDim,
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
                        style: AppTextStyles.headingMedium,
                      ),
                      Text(
                        '${widget.item.itemName}',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Warn me when stock drops below this amount. Leave blank to remove the alert.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Alert below',
                      labelStyle: const TextStyle(color: Color(0xFF888888)),
                      hintText: 'e.g. 0.5',
                      hintStyle: const TextStyle(color: Color(0xFF555555)),
                      filled: true,
                      fillColor: const Color(0xFF111111),
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
                // Unit dropdown
                SizedBox(
                  width: 110,
                  child: DropdownButtonFormField<String>(
                    value: _unit,
                    dropdownColor: const Color(0xFF252525),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Unit',
                      labelStyle: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 12,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF111111),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
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
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOut
              ? AppColors.error.withValues(alpha: 0.5)
              : isLow
              ? AppColors.warning.withValues(alpha: 0.4)
              : needsRecon
              ? AppColors.goldPrimary.withValues(alpha: 0.25)
              : AppColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.goldDim,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.goldPrimary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.edit_note,
                      size: 10,
                      color: AppColors.goldPrimary,
                    ),
                    const SizedBox(width: 3),
                    const Text(
                      'Manual',
                      style: TextStyle(
                        color: AppColors.goldPrimary,
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
                  item.itemName,
                  style: AppTextStyles.headingSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOut
                      ? AppColors.errorDim
                      : isLow
                      ? AppColors.warningDim
                      : AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.remainingFormatted,
                  style: TextStyle(
                    color: isOut
                        ? AppColors.error
                        : isLow
                        ? AppColors.warning
                        : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
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
              backgroundColor: AppColors.bgSurface,
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

          Row(
            children: [
              Text(
                item.category,
                style: AppTextStyles.bodySmall.copyWith(color: catColor),
              ),
              const SizedBox(width: 6),
              Text('·', style: AppTextStyles.bodySmall),
              const SizedBox(width: 6),
              Text(
                '${item.totalPurchased.toStringAsFixed(1)} ${item.unit} bought',
                style: AppTextStyles.bodySmall,
              ),
              const Spacer(),
              if (item.priceLabel != null)
                Text(
                  item.priceLabel!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.goldPrimary,
                  ),
                ),
            ],
          ),

          // Threshold badge + total spent
          const SizedBox(height: 4),
          Row(
            children: [
              // Threshold badge — shows what user set
              if (item.threshold != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warningDim,
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
              const Spacer(),
              if (item.totalSpentLabel != null)
                Text(
                  item.totalSpentLabel!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              if (needsRecon) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.goldDim,
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
            ],
          ),

          const SizedBox(height: 10),

          // Action chips row
          Row(
            children: [
              _Chip(
                Icons.edit_outlined,
                'Update Stock',
                null,
                () => _openUpdateSheet(context),
              ),
              const SizedBox(width: 8),
              _Chip(
                Icons.warning_amber_outlined,
                'Set Alert',
                item.threshold != null ? AppColors.warning : null,
                () => _openThresholdSheet(context),
              ),
              const SizedBox(width: 8),
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

  void _openUpdateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UpdateStockSheet(item: item, onUpdated: onUpdated),
    );
  }

  void _openThresholdSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SetThresholdSheet(item: item, onUpdated: onUpdated),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove Item',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Remove "${item.itemName}" from inventory?',
          style: const TextStyle(color: Color(0xFF888888), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF888888)),
            ),
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
    final catColor = AppColors.categoryColor(device.category);
    final isLow = device.isLowStock;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLow
              ? AppColors.warning.withValues(alpha: 0.4)
              : AppColors.borderSubtle,
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
                  color: device.isOnline
                      ? AppColors.success
                      : AppColors.textMuted,
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
                  style: AppTextStyles.headingSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(device.weightFormatted, style: AppTextStyles.weightSmall),
              if (isLow) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warningDim,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
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
              backgroundColor: AppColors.bgSurface,
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
                style: AppTextStyles.bodySmall.copyWith(color: catColor),
              ),
              const SizedBox(width: 6),
              Text('·', style: AppTextStyles.bodySmall),
              const SizedBox(width: 6),
              Text(device.location, style: AppTextStyles.bodySmall),
              const Spacer(),
              Text(
                'Min: ${device.threshold.toStringAsFixed(0)} ${device.unit}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.goldPrimary,
                ),
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
  Widget build(BuildContext context) => Row(
    children: [
      GestureDetector(
        onTap: onSort,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              const Icon(Icons.sort, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text('Sort: $sortBy', style: AppTextStyles.labelMedium),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 14,
                color: AppColors.textSecondary,
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
            color: showLowOnly ? AppColors.warningDim : AppColors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: showLowOnly ? AppColors.warning : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: showLowOnly
                    ? AppColors.warning
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Low Stock',
                style: AppTextStyles.labelMedium.copyWith(
                  color: showLowOnly
                      ? AppColors.warning
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
      const Spacer(),
      Text('$count items', style: AppTextStyles.bodySmall),
    ],
  );
}

class _Chip extends StatelessWidget {
  final IconData i;
  final String l;
  final Color? c;
  final VoidCallback t;
  const _Chip(this.i, this.l, this.c, this.t);
  @override
  Widget build(BuildContext context) {
    final col = c ?? AppColors.textSecondary;
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

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Container(height: 1, color: color.withValues(alpha: 0.2)),
      ),
    ],
  );
}

class _CategoryFilter extends StatelessWidget {
  final String selected;
  final void Function(String) onChanged;
  const _CategoryFilter({required this.selected, required this.onChanged});
  @override
  Widget build(BuildContext context) => SizedBox(
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.goldPrimary : AppColors.bgCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.goldPrimary
                      : AppColors.borderSubtle,
                ),
              ),
              child: Text(
                cat,
                style: AppTextStyles.labelMedium.copyWith(
                  color: isSelected
                      ? AppColors.textOnGold
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final String category;
  final bool lowOnly;
  const _EmptyState({required this.category, required this.lowOnly});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            color: AppColors.textMuted,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            lowOnly ? 'No low-stock items!' : 'No items in $category',
            style: AppTextStyles.headingMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            lowOnly
                ? 'Your pantry is well stocked 🎉'
                : 'Add devices or tap + Add Item',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    ),
  );
}
