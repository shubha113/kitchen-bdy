import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/device.dart';
import '../../models/manual_inventory_item.dart';
import '../../providers/app_provider.dart';
import '../../services/manual_inventory.dart';
import '../../services/weighing_machine.dart';

const _kCats = [
  'Grains',
  'Spices',
  'Dairy',
  'Oils',
  'Pulses',
  'Beverages',
  'Flour',
  'Sugar',
  'Snacks',
  'Other',
];

class EspDeviceDetailScreen extends StatelessWidget {
  final String espId;
  const EspDeviceDetailScreen({super.key, required this.espId});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final t = AppTheme.of(context);
    final sensors = prov.devicesForEsp(espId);
    final low = sensors.where((s) => s.isLowStock).length;

    return Scaffold(
      backgroundColor: t.bgPrimary,
      appBar: AppBar(
        backgroundColor: t.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: t.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              espId,
              style: AppTextStyles.headingMediumOf(context),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${sensors.length} slot${sensors.length == 1 ? '' : 's'}',
              style: AppTextStyles.bodySmallOf(context),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Summary bar
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: t.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.borderSubtle),
            ),
            child: Row(
              children: [
                _S('Total', '${sensors.length}', t.textPrimary),
                _vd(t),
                _S('Online', '${sensors.length}', AppColors.success),
                _vd(t),
                _S('Low Stock', '$low', AppColors.warning),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: sensors.isEmpty
                ? Center(
                    child: Text(
                      'No sensors found.',
                      style: AppTextStyles.bodyMediumOf(
                        context,
                      ).copyWith(color: t.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: sensors.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) => _Card(device: sensors[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _vd(AppTheme t) => Container(
    width: 1,
    height: 28,
    color: t.borderSubtle,
    margin: const EdgeInsets.symmetric(horizontal: 8),
  );
}

class _S extends StatelessWidget {
  final String l, v;
  final Color c;
  const _S(this.l, this.v, this.c);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          v,
          style: AppTextStyles.headingMediumOf(context).copyWith(color: c),
        ),
        Text(l, style: AppTextStyles.bodySmallOf(context)),
      ],
    ),
  );
}

// ── Sensor Card ───────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final KitchenDevice device;
  const _Card({required this.device});

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final isLow = device.isLowStock;
    final isCrit = device.isCritical;
    final cat = AppColors.categoryColor(device.category);

    final tare = device.tareWeight;
    final netWeight = (device.currentWeight - tare).clamp(0.0, double.infinity);
    final netLabel = netWeight >= 1000
        ? '${(netWeight / 1000).toStringAsFixed(2)} kg'
        : '${netWeight.toStringAsFixed(1)} ${device.unit}';

    return Container(
      decoration: BoxDecoration(
        color: t.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCrit
              ? AppColors.error.withValues(alpha: 0.5)
              : isLow
              ? AppColors.warning.withValues(alpha: 0.4)
              : t.borderSubtle,
          width: isCrit ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.goldPrimary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.goldPrimary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'S${device.slot}',
                      style: const TextStyle(
                        color: AppColors.goldPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: AppTextStyles.headingSmallOf(context),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          if (device.location.isNotEmpty) ...[
                            Icon(
                              Icons.location_on_outlined,
                              size: 11,
                              color: t.textMuted,
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                device.location,
                                style: AppTextStyles.bodySmallOf(context),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (device.linkedInventoryName != null) ...[
                            const Icon(
                              Icons.link,
                              size: 11,
                              color: AppColors.goldPrimary,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                device.linkedInventoryName!,
                                style: AppTextStyles.bodySmallOf(
                                  context,
                                ).copyWith(color: AppColors.goldPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: cat.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    device.category,
                    style: TextStyle(
                      color: cat,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Weight display
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: t.bgSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      device.weightFormatted,
                      style: AppTextStyles.weightDisplay,
                    ),
                    if (isLow) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isCrit ? t.errorDim : t.warningDim,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isCrit ? 'CRITICAL' : 'LOW',
                          style: TextStyle(
                            color: isCrit ? AppColors.error : AppColors.warning,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (tare > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Net: $netLabel  (tare: ${tare.toStringAsFixed(0)}g)',
                    style: AppTextStyles.bodySmallOf(context),
                  ),
                ],
              ],
            ),
          ),

          // Stock bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Stock Level',
                      style: AppTextStyles.bodySmallOf(context),
                    ),
                    const Spacer(),
                    Text(
                      'Threshold: ${device.threshold.toStringAsFixed(0)} ${device.unit}',
                      style: AppTextStyles.bodySmallOf(
                        context,
                      ).copyWith(color: AppColors.goldPrimary, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: device.stockPercentage,
                    backgroundColor: t.borderSubtle,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCrit
                          ? AppColors.error
                          : isLow
                          ? AppColors.warning
                          : cat,
                    ),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                _Chip(Icons.edit_outlined, 'Edit', null, () => _edit(context)),
                const SizedBox(width: 8),
                _Chip(
                  Icons.delete_outline,
                  'Remove',
                  AppColors.error,
                  () => _remove(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _edit(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSheet(device: device),
    );
  }

  void _remove(BuildContext ctx) {
    final prov = ctx.read<AppProvider>();
    final t = AppTheme.of(ctx);
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        backgroundColor: t.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove Sensor', style: AppTextStyles.headingSmallOf(ctx)),
        content: Text(
          'Remove "${device.name}" (Slot ${device.slot})?\nYou can re-add it anytime.',
          style: AppTextStyles.bodySmallOf(ctx),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: Text('Cancel', style: TextStyle(color: t.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              prov.removeDevice(device.id);
              Navigator.pop(dCtx);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Edit Sheet ────────────────────────────────────────────────────────────────
class _EditSheet extends StatefulWidget {
  final KitchenDevice device;
  const _EditSheet({required this.device});
  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final TextEditingController _locCtrl;
  late final TextEditingController _thrCtrl;
  late String _cat;

  List<ManualInventoryItem> _inventoryItems = [];
  bool _loadingInventory = true;
  int? _selectedInventoryId;
  String? _selectedInventoryName;

  bool _saving = false;
  bool _settingTare = false;

  @override
  void initState() {
    super.initState();
    _locCtrl = TextEditingController(text: widget.device.location);
    _thrCtrl = TextEditingController(
      text: widget.device.threshold.toStringAsFixed(0),
    );
    _cat = _kCats.contains(widget.device.category)
        ? widget.device.category
        : 'Other';
    _selectedInventoryId = widget.device.linkedInventoryId;
    _selectedInventoryName = widget.device.linkedInventoryName;
    _loadInventory();
  }

  @override
  void dispose() {
    _locCtrl.dispose();
    _thrCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInventory() async {
    final items = await ManualInventoryService.getUserInventory();
    if (mounted)
      setState(() {
        _inventoryItems = items;
        _loadingInventory = false;
      });
  }

  Future<void> _setTare() async {
    setState(() => _settingTare = true);
    final prov = context.read<AppProvider>();
    final liveDevice = prov.devices.firstWhere(
      (d) => d.id == widget.device.id,
      orElse: () => widget.device,
    );
    final currentWeight = liveDevice.currentWeight;
    final ok = await WeighingMachineService.setTare(
      widget.device.id,
      currentWeight,
    );
    if (!mounted) return;
    setState(() => _settingTare = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Tare set to ${currentWeight.toStringAsFixed(0)}g'
              : 'Failed to set tare',
        ),
        backgroundColor: ok ? AppColors.successDim : AppColors.errorDim,
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final prov = context.read<AppProvider>();
    final newName = _selectedInventoryName ?? widget.device.name;
    await prov.updateDeviceMeta(
      widget.device.id,
      name: newName,
      location: _locCtrl.text.trim(),
      category: _cat,
      threshold: double.tryParse(_thrCtrl.text),
    );
    if (_selectedInventoryId != widget.device.linkedInventoryId) {
      await WeighingMachineService.linkInventory(
        widget.device.id,
        _selectedInventoryId,
      );
      await prov.reloadDevices();
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);

    final uniqueItems = _inventoryItems
        .fold<Map<int, ManualInventoryItem>>({}, (map, item) {
          map[item.id] = item;
          return map;
        })
        .values
        .toList();
    final validSelectedId = uniqueItems.any((i) => i.id == _selectedInventoryId)
        ? _selectedInventoryId
        : null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        decoration: BoxDecoration(
          color: t.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.goldPrimary.withValues(
                              alpha: 0.12,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.goldPrimary.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'S${widget.device.slot}',
                              style: const TextStyle(
                                color: AppColors.goldPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Edit Sensor',
                          style: AppTextStyles.headingMediumOf(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Inventory dropdown
                    Text(
                      'LINK TO INVENTORY ITEM',
                      style: AppTextStyles.goldLabel,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select what this sensor is tracking. The sensor name will update automatically.',
                      style: AppTextStyles.bodySmallOf(context),
                    ),
                    const SizedBox(height: 8),

                    _loadingInventory
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                color: AppColors.goldPrimary,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : _inventoryItems.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: t.bgSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: t.borderSubtle),
                            ),
                            child: Text(
                              'No inventory items yet. Add items via Inventory → + Add Item first.',
                              style: AppTextStyles.bodySmallOf(context),
                            ),
                          )
                        : DropdownButtonFormField<int?>(
                            value: validSelectedId,
                            dropdownColor: t.bgCardElevated,
                            isExpanded: true,
                            style: TextStyle(
                              color: t.textPrimary,
                              fontSize: 14,
                            ),
                            decoration: _dec(
                              context,
                              t,
                              'Select item (or leave blank)',
                              Icons.link,
                            ),
                            items: [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text(
                                  '— No link (standalone sensor) —',
                                  style: TextStyle(
                                    color: t.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              ...uniqueItems.map(
                                (item) => DropdownMenuItem<int?>(
                                  value: item.id,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.itemName,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${item.packsRemaining.toStringAsFixed(1)} ${item.unit}',
                                        style: TextStyle(
                                          color: t.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() {
                              _selectedInventoryId = v;
                              _selectedInventoryName = v == null
                                  ? null
                                  : _inventoryItems
                                        .firstWhere((i) => i.id == v)
                                        .itemName;
                            }),
                          ),

                    if (_selectedInventoryName != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.goldPrimary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.goldPrimary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.link,
                              size: 14,
                              color: AppColors.goldPrimary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Sensor will track "$_selectedInventoryName" — stock auto-updates from scale',
                                style: AppTextStyles.bodySmallOf(
                                  context,
                                ).copyWith(color: AppColors.goldPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Tare
                    Text(
                      'CONTAINER / JAR WEIGHT (TARE)',
                      style: AppTextStyles.goldLabel,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Place your empty container on the scale, then tap Set Tare. '
                      'The app will subtract its weight automatically.',
                      style: AppTextStyles.bodySmallOf(context),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: t.bgSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: t.borderSubtle),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.scale,
                                  size: 16,
                                  color: t.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.device.tareWeight > 0
                                      ? 'Current tare: ${widget.device.tareWeight.toStringAsFixed(0)}g'
                                      : 'No tare set',
                                  style: TextStyle(
                                    color: widget.device.tareWeight > 0
                                        ? t.textPrimary
                                        : t.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Live: ${widget.device.currentWeight.toStringAsFixed(0)}g',
                                  style: TextStyle(
                                    color: t.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _settingTare ? null : _setTare,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.goldPrimary.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.goldPrimary.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                            child: _settingTare
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.goldPrimary,
                                    ),
                                  )
                                : const Text(
                                    'Set Tare',
                                    style: TextStyle(
                                      color: AppColors.goldPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Location
                    _inp(
                      context,
                      t,
                      _locCtrl,
                      'Location',
                      'e.g. Shelf 1, Counter…',
                      Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 14),

                    // Category
                    DropdownButtonFormField<String>(
                      value: _cat,
                      dropdownColor: t.bgCardElevated,
                      style: TextStyle(color: t.textPrimary, fontSize: 14),
                      decoration: _dec(
                        context,
                        t,
                        'Category',
                        Icons.category_outlined,
                      ),
                      items: _kCats
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _cat = v!),
                    ),
                    const SizedBox(height: 14),

                    // Threshold
                    _inp(
                      context,
                      t,
                      _thrCtrl,
                      'Low-stock threshold (${widget.device.unit})',
                      'e.g. 200',
                      Icons.tune,
                      numeric: true,
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),

            // Save button
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
                    elevation: 0,
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
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
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

  static Widget _inp(
    BuildContext context,
    AppTheme t,
    TextEditingController c,
    String label,
    String hint,
    IconData icon, {
    bool numeric = false,
  }) => TextField(
    controller: c,
    keyboardType: numeric ? TextInputType.number : TextInputType.text,
    style: TextStyle(color: t.textPrimary, fontSize: 14),
    decoration: _dec(context, t, label, icon).copyWith(
      hintText: hint,
      hintStyle: TextStyle(color: t.textMuted, fontSize: 13),
    ),
  );

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

// ── Chip ──────────────────────────────────────────────────────────────────────
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: col.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: col.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(i, size: 13, color: col),
            const SizedBox(width: 5),
            Text(
              l,
              style: TextStyle(
                color: col,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
