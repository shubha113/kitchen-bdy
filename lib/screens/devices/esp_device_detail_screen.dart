import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/device.dart';
import '../../providers/app_provider.dart';

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

  static const _bg = Color(0xFF0F0F0F);
  static const _surface = Color(0xFF1A1A1A);
  static const _gold = Color(0xFFD4A843);
  static const _grey = Color(0xFF888888);
  static const _border = Color(0xFF2A2A2A);

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final sensors = prov.devicesForEsp(espId);
    final online = sensors.length;
    final low = sensors.where((s) => s.isLowStock).length;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              espId,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              '${sensors.length} slot${sensors.length == 1 ? '' : 's'}  •  $online online',
              style: const TextStyle(color: _grey, fontSize: 11),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Summary
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                _S('Total', '${sensors.length}', Colors.white),
                _vd(),
                _S('Online', '$online', AppColors.success),
                _vd(),
                _S('Offline', '${sensors.length - online}', _grey),
                _vd(),
                _S('Low Stock', '$low', AppColors.warning),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: sensors.isEmpty
                ? const Center(
                    child: Text(
                      'No sensors found.',
                      style: TextStyle(color: _grey, fontSize: 14),
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

  Widget _vd() => Container(
    width: 1,
    height: 28,
    color: _border,
    margin: const EdgeInsets.symmetric(horizontal: 8),
  );
}

class _S extends StatelessWidget {
  final String l, v;
  final Color c;
  const _S(this.l, this.v, this.c);
  @override
  Widget build(BuildContext ctx) => Expanded(
    child: Column(
      children: [
        Text(
          v,
          style: TextStyle(color: c, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        Text(
          l,
          style: const TextStyle(
            color: EspDeviceDetailScreen._grey,
            fontSize: 11,
          ),
        ),
      ],
    ),
  );
}

// Sensor Card
class _Card extends StatelessWidget {
  final KitchenDevice device;
  const _Card({required this.device});

  static const _gold = Color(0xFFD4A843);
  static const _surface = Color(0xFF1A1A1A);
  static const _dark = Color(0xFF111111);
  static const _border = Color(0xFF2A2A2A);
  static const _grey = Color(0xFF888888);

  @override
  Widget build(BuildContext context) {
    final isLow = device.isLowStock;
    final isCrit = device.isCritical;
    final cat = AppColors.categoryColor(device.category);

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCrit
              ? AppColors.error.withValues(alpha: 0.5)
              : isLow
              ? AppColors.warning.withValues(alpha: 0.4)
              : _border,
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
                    color: _gold.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: _gold.withValues(alpha: 0.4)),
                  ),
                  child: Center(
                    child: Text(
                      'S${device.slot}',
                      style: const TextStyle(
                        color: _gold,
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          if (device.location.isNotEmpty) ...[
                            const Icon(
                              Icons.location_on_outlined,
                              size: 11,
                              color: _grey,
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                device.location,
                                style: const TextStyle(
                                  color: _grey,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Online',
                            style: TextStyle(
                              color: device.isOnline
                                  ? AppColors.success
                                  : _grey,
                              fontSize: 11,
                            ),
                          ),
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

          // Weight
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: _dark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
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
                      color: isCrit ? AppColors.errorDim : AppColors.warningDim,
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
          ),

          // Stock bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'Stock Level',
                      style: TextStyle(color: _grey, fontSize: 12),
                    ),
                    const Spacer(),
                    Text(
                      'Threshold: ${device.threshold.toStringAsFixed(0)} ${device.unit}',
                      style: const TextStyle(color: _gold, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: device.stockPercentage,
                    backgroundColor: _border,
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

  // Edit bottom sheet
  void _edit(BuildContext ctx) {
    final prov = ctx.read<AppProvider>();
    final nameCtrl = TextEditingController(text: device.name);
    final locCtrl = TextEditingController(text: device.location);
    final thrCtrl = TextEditingController(
      text: device.threshold.toStringAsFixed(0),
    );
    String cat = _kCats.contains(device.category) ? device.category : 'Other';

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (_, setSt) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3A3A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: _gold.withValues(alpha: 0.4)),
                      ),
                      child: Center(
                        child: Text(
                          'S${device.slot}',
                          style: const TextStyle(
                            color: _gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Edit Sensor',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Name — text input
                _inp(
                  nameCtrl,
                  'Name',
                  'e.g. Basmati Rice',
                  Icons.label_outline,
                ),
                const SizedBox(height: 14),

                // Location — free text (not dropdown)
                _inp(
                  locCtrl,
                  'Location',
                  'e.g. Shelf 1, Counter, Pantry…',
                  Icons.location_on_outlined,
                ),
                const SizedBox(height: 14),

                // Category — dropdown
                DropdownButtonFormField<String>(
                  value: cat,
                  dropdownColor: const Color(0xFF252525),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _dec('Category', Icons.category_outlined),
                  items: _kCats
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setSt(() => cat = v!),
                ),
                const SizedBox(height: 14),

                // Threshold — number
                _inp(
                  thrCtrl,
                  'Low-stock threshold (${device.unit})',
                  'e.g. 200',
                  Icons.tune,
                  numeric: true,
                ),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      prov.updateDeviceMeta(
                        device.id,
                        name: nameCtrl.text.trim().isNotEmpty
                            ? nameCtrl.text.trim()
                            : null,
                        location: locCtrl.text.trim(),
                        category: cat,
                        threshold: double.tryParse(thrCtrl.text),
                      );
                      Navigator.pop(sheetCtx);
                    },
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      nameCtrl.dispose();
      locCtrl.dispose();
      thrCtrl.dispose();
    });
  }

  void _remove(BuildContext ctx) {
    final prov = ctx.read<AppProvider>();
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove Sensor',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Remove "${device.name}" (Slot ${device.slot})?\nYou can re-add it anytime.',
          style: const TextStyle(color: _grey, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel', style: TextStyle(color: _grey)),
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

  static Widget _inp(
    TextEditingController c,
    String label,
    String hint,
    IconData icon, {
    bool numeric = false,
  }) => TextField(
    controller: c,
    keyboardType: numeric ? TextInputType.number : TextInputType.text,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    decoration: _dec(label, icon).copyWith(
      hintText: hint,
      hintStyle: const TextStyle(color: _grey, fontSize: 13),
    ),
  );

  static InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: _grey, fontSize: 12),
    prefixIcon: Icon(icon, color: _grey, size: 18),
    filled: true,
    fillColor: const Color(0xFF111111),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _gold, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  );
}

class _Chip extends StatelessWidget {
  final IconData i;
  final String l;
  final Color? c;
  final VoidCallback t;
  const _Chip(this.i, this.l, this.c, this.t);
  @override
  Widget build(BuildContext ctx) {
    final col = c ?? const Color(0xFF888888);
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
