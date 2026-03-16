import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';

enum _Step { scan, select, wifi, provision, slots, done }

class ScanDevicesScreen extends StatefulWidget {
  const ScanDevicesScreen({super.key});
  @override
  State<ScanDevicesScreen> createState() => _ScanDevicesScreenState();
}

class _ScanDevicesScreenState extends State<ScanDevicesScreen>
    with TickerProviderStateMixin {
  _Step _step = _Step.scan;
  Map<String, String>? _selectedDevice;
  String _provisioningStatus = '';
  bool _provisioningFailed = false;
  bool _obscurePass = true;
  bool _registering = false;

  final _ssidCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  // Per-slot controllers — populated once discoveredSlots arrives
  final Map<int, TextEditingController> _slotName = {};
  final Map<int, TextEditingController> _slotLocation = {};
  final Map<int, String> _slotCategory = {};

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _checkPermissionsAndScan();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _ssidCtrl.dispose();
    _passCtrl.dispose();
    for (final c in _slotName.values) c.dispose();
    for (final c in _slotLocation.values) c.dispose();
    super.dispose();
  }

  // ── Permissions + scan ────────────────────────────────────────────────────
  Future<void> _checkPermissionsAndScan() async {
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    if (!statuses.values.every((s) => s.isGranted)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth permissions required.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    _startScan();
  }

  void _startScan() {
    setState(() => _step = _Step.scan);
    context.read<AppProvider>().startScan().then((_) {
      if (mounted) setState(() => _step = _Step.select);
    });
  }

  // ── Connect to BLE device ─────────────────────────────────────────────────
  Future<void> _connectToDevice(Map<String, String> device) async {
    setState(() {
      _selectedDevice = device;
      _step = _Step.provision;
      _provisioningStatus = 'Connecting via Bluetooth…';
      _provisioningFailed = false;
    });

    final prov = context.read<AppProvider>();
    final success = await prov.connectToDevice(device['id']!);
    if (!mounted) return;

    if (success) {
      setState(() => _step = _Step.wifi);
    } else {
      setState(() {
        _provisioningFailed = true;
        _provisioningStatus =
            'Could not connect. Make sure the device is nearby and powered on.';
      });
    }
  }

  // ── Send WiFi → wait for SENSORS notification ─────────────────────────────
  Future<void> _sendWifi() async {
    final ssid = _ssidCtrl.text.trim();
    if (ssid.isEmpty) return;

    setState(() {
      _step = _Step.provision;
      _provisioningStatus = 'Sending Wi-Fi credentials…';
      _provisioningFailed = false;
    });

    final prov = context.read<AppProvider>();
    final success = await prov.sendWifiCredentials(ssid, _passCtrl.text);
    if (!mounted) return;

    if (!success) {
      setState(() {
        _provisioningFailed = true;
        _provisioningStatus = 'Failed to send credentials. Try again.';
      });
      return;
    }

    setState(
      () => _provisioningStatus =
          'Credentials sent — waiting for sensor discovery…',
    );

    // Poll discoveredSlots for up to 20s
    for (int i = 0; i < 40; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      if (prov.discoveredSlots.isNotEmpty) break;
    }

    if (!mounted) return;
    _initSlotControllers(prov.discoveredSlots);
    setState(() => _step = _Step.slots);
  }

  // ── Build per-slot controllers ────────────────────────────────────────────
  void _initSlotControllers(List<int> slots) {
    for (final s in slots) {
      _slotName[s] ??= TextEditingController(text: 'Sensor $s');
      _slotLocation[s] ??= TextEditingController(text: 'Pantry');
      _slotCategory[s] ??= 'Other';
    }
  }

  // ── Register all slots to backend ─────────────────────────────────────────
  Future<void> _registerSlots() async {
    final prov = context.read<AppProvider>();
    final espId = prov.connectedEspId.isNotEmpty
        ? prov.connectedEspId
        : 'ESP32_SCALE_1';

    final sensors = prov.discoveredSlots
        .map(
          (slot) => {
            'espId': espId,
            'slot': slot,
            'name': _slotName[slot]?.text.trim().isNotEmpty == true
                ? _slotName[slot]!.text.trim()
                : 'Sensor $slot',
            'location': _slotLocation[slot]?.text.trim().isNotEmpty == true
                ? _slotLocation[slot]!.text.trim()
                : 'Pantry',
            'category': _slotCategory[slot] ?? 'Other',
          },
        )
        .toList();

    if (sensors.isEmpty) return;

    setState(() => _registering = true);
    debugPrint(
      '[Register] espId=$espId slots=${prov.discoveredSlots} payload=$sensors',
    );

    final ok = await prov.registerDiscoveredSensors(sensors);
    if (!mounted) return;

    setState(() => _registering = false);

    if (ok) {
      setState(() => _step = _Step.done);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Registration failed. Check your connection and try again.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgPrimary,
    appBar: AppBar(
      backgroundColor: AppColors.bgPrimary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios,
          color: AppColors.textSecondary,
          size: 18,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text('Add Device', style: AppTextStyles.headingLarge),
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _buildStep(context),
      ),
    ),
  );

  Widget _buildStep(BuildContext ctx) {
    switch (_step) {
      case _Step.scan:
        return _buildScanStep();
      case _Step.select:
        return _buildSelectStep(ctx);
      case _Step.wifi:
        return _buildWifiStep();
      case _Step.provision:
        return _buildProvisionStep();
      case _Step.slots:
        return _buildSlotsStep(ctx);
      case _Step.done:
        return _buildDoneStep();
    }
  }

  // ─── SCAN ─────────────────────────────────────────────────────────────────
  Widget _buildScanStep() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ScaleTransition(
          scale: _pulseAnim,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.goldPrimary, width: 2),
              gradient: const RadialGradient(
                colors: [AppColors.goldDim, AppColors.bgCard],
              ),
            ),
            child: const Icon(
              Icons.bluetooth_searching,
              color: AppColors.goldPrimary,
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Scanning for Devices',
          style: AppTextStyles.displaySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Make sure your KitchenBDY device\nis powered on and nearby.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            color: AppColors.goldPrimary,
            strokeWidth: 2,
          ),
        ),
      ],
    ),
  );

  // ─── SELECT ───────────────────────────────────────────────────────────────
  Widget _buildSelectStep(BuildContext ctx) {
    final devices = ctx.watch<AppProvider>().scannedDevices;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepIndicator(current: 1),
        const SizedBox(height: 24),
        Text('Devices Found', style: AppTextStyles.displaySmall),
        const SizedBox(height: 8),
        Text(
          '${devices.length} device${devices.length == 1 ? '' : 's'} nearby.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: devices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.bluetooth_disabled,
                        color: AppColors.textMuted,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No devices found',
                        style: AppTextStyles.headingMedium,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: devices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final d = devices[i];
                    final rssi = int.tryParse(d['rssi'] ?? '-70') ?? -70;
                    final sigColor = rssi > -60
                        ? AppColors.success
                        : rssi > -70
                        ? AppColors.warning
                        : AppColors.error;
                    return GestureDetector(
                      onTap: () => _connectToDevice(d),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bgCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.goldDim,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.scale,
                                color: AppColors.goldPrimary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d['name'] ?? '',
                                    style: AppTextStyles.headingMedium,
                                  ),
                                  Text(
                                    'MAC: ${d['mac']}',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.signal_wifi_4_bar,
                              color: sigColor,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _checkPermissionsAndScan,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.refresh, color: AppColors.goldPrimary, size: 16),
              const SizedBox(width: 8),
              Text(
                'Scan Again',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.goldPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── WIFI ─────────────────────────────────────────────────────────────────
  Widget _buildWifiStep() => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepIndicator(current: 2),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.successDim,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.success.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Connected to ${_selectedDevice?['name'] ?? ''} via Bluetooth',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Enter Wi-Fi Details', style: AppTextStyles.displaySmall),
        const SizedBox(height: 8),
        Text(
          'These credentials will be sent to the device\nover Bluetooth.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 28),
        Text('NETWORK NAME', style: AppTextStyles.goldLabel),
        const SizedBox(height: 8),
        _InputField(
          controller: _ssidCtrl,
          label: 'Wi-Fi Name',
          icon: Icons.wifi_rounded,
        ),
        const SizedBox(height: 16),
        Text('PASSWORD', style: AppTextStyles.goldLabel),
        const SizedBox(height: 8),
        TextField(
          controller: _passCtrl,
          obscureText: _obscurePass,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: AppColors.textSecondary,
              size: 18,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textSecondary,
                size: 18,
              ),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
            labelText: 'Password',
            labelStyle: AppTextStyles.bodySmall,
            filled: true,
            fillColor: AppColors.bgCard,
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
        const SizedBox(height: 32),
        GestureDetector(
          onTap: _ssidCtrl.text.trim().isEmpty ? null : _sendWifi,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Send to Device',
              textAlign: TextAlign.center,
              style: AppTextStyles.headingMedium.copyWith(
                color: AppColors.textOnGold,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  // ─── PROVISION (spinner) ──────────────────────────────────────────────────
  Widget _buildProvisionStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      _StepIndicator(current: 2),
      const SizedBox(height: 40),
      Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          shape: BoxShape.circle,
          border: Border.all(
            color: _provisioningFailed
                ? AppColors.error
                : AppColors.goldPrimary,
            width: 1.5,
          ),
        ),
        child: Icon(
          _provisioningFailed ? Icons.error_outline : Icons.wifi,
          color: _provisioningFailed ? AppColors.error : AppColors.goldPrimary,
          size: 36,
        ),
      ),
      const SizedBox(height: 32),
      Text('Provisioning Device', style: AppTextStyles.displaySmall),
      const SizedBox(height: 8),
      Text(
        _selectedDevice?['name'] ?? '',
        style: AppTextStyles.headingMedium.copyWith(
          color: AppColors.goldPrimary,
        ),
      ),
      const SizedBox(height: 24),
      Text(
        _provisioningStatus,
        style: AppTextStyles.bodyMedium.copyWith(
          color: _provisioningFailed
              ? AppColors.error
              : AppColors.textSecondary,
        ),
        textAlign: TextAlign.center,
      ),
      if (!_provisioningFailed) ...[
        const SizedBox(height: 24),
        const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            color: AppColors.goldPrimary,
            strokeWidth: 2,
          ),
        ),
      ],
      if (_provisioningFailed) ...[
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => setState(() => _step = _Step.wifi),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.goldPrimary),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Try Again',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.goldPrimary,
              ),
            ),
          ),
        ),
      ],
    ],
  );

  // ─── SLOTS — name each sensor individually ────────────────────────────────
  Widget _buildSlotsStep(BuildContext ctx) {
    final slots = ctx.watch<AppProvider>().discoveredSlots;

    if (slots.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: AppColors.goldPrimary,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Waiting for sensor discovery…',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepIndicator(current: 3),
          const SizedBox(height: 24),
          Text('Name Your Sensors', style: AppTextStyles.displaySmall),
          const SizedBox(height: 8),
          Text(
            '${slots.length} sensor${slots.length == 1 ? '' : 's'} detected on this ESP32.\nGive each one a name so you can identify it.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // One card per slot
          ...slots.map((slot) {
            _slotName[slot] ??= TextEditingController(text: 'Sensor $slot');
            _slotLocation[slot] ??= TextEditingController(text: 'Pantry');
            _slotCategory[slot] ??= 'Other';

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Slot header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.goldDim,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Slot $slot',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.goldPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Name
                  _InputField(
                    controller: _slotName[slot]!,
                    label: 'Sensor name (e.g. Rice, Sugar)',
                    icon: Icons.label_outline,
                  ),
                  const SizedBox(height: 10),

                  // Location
                  _InputField(
                    controller: _slotLocation[slot]!,
                    label: 'Location (e.g. Shelf 1)',
                    icon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 10),

                  // Category chips
                  Text('CATEGORY', style: AppTextStyles.goldLabel),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: AppConstants.categories.skip(1).map((cat) {
                      final sel = _slotCategory[slot] == cat;
                      return GestureDetector(
                        onTap: () => setState(() => _slotCategory[slot] = cat),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.goldDim
                                : AppColors.bgCardElevated,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: sel
                                  ? AppColors.goldPrimary
                                  : AppColors.borderSubtle,
                            ),
                          ),
                          child: Text(
                            cat,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: sel
                                  ? AppColors.goldPrimary
                                  : AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 8),
          GestureDetector(
            onTap: _registering ? null : _registerSlots,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: _registering
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : Text(
                      'Register ${slots.length} Sensor${slots.length == 1 ? '' : 's'}',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headingMedium.copyWith(
                        color: AppColors.textOnGold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── DONE ─────────────────────────────────────────────────────────────────
  Widget _buildDoneStep() {
    final slots = context.read<AppProvider>().discoveredSlots;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: const BoxDecoration(
            color: AppColors.successDim,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle,
            color: AppColors.success,
            size: 50,
          ),
        ),
        const SizedBox(height: 24),
        Text('Device Registered!', style: AppTextStyles.displaySmall),
        const SizedBox(height: 8),
        Text(
          '${slots.length} sensor${slots.length == 1 ? '' : 's'} saved to your account.\nLive weight data will appear shortly.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        GestureDetector(
          onTap: () {
            _slotName.forEach((_, c) => c.clear());
            _slotLocation.forEach((_, c) => c.clear());
            _slotCategory.clear();
            _startScan();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderGold),
            ),
            child: Text(
              'Add Another Device',
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.goldPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Back to Devices',
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.textOnGold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});
  @override
  Widget build(BuildContext ctx) {
    const steps = ['Scan', 'Provision', 'Name'];
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(
            child: Container(
              height: 1,
              color: i ~/ 2 < current - 1
                  ? AppColors.goldPrimary
                  : AppColors.borderSubtle,
            ),
          );
        }
        final idx = i ~/ 2 + 1;
        final done = idx < current;
        final active = idx == current;
        return Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? AppColors.goldPrimary
                    : active
                    ? AppColors.goldDim
                    : AppColors.bgCard,
                border: Border.all(
                  color: active || done
                      ? AppColors.goldPrimary
                      : AppColors.borderSubtle,
                ),
              ),
              child: done
                  ? const Icon(
                      Icons.check,
                      color: AppColors.textOnGold,
                      size: 14,
                    )
                  : Center(
                      child: Text(
                        '$idx',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: active
                              ? AppColors.goldPrimary
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              steps[i ~/ 2],
              style: AppTextStyles.labelSmall.copyWith(
                color: active ? AppColors.goldPrimary : AppColors.textMuted,
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
  });
  @override
  Widget build(BuildContext ctx) => TextField(
    controller: controller,
    style: AppTextStyles.bodyMedium,
    decoration: InputDecoration(
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 18),
      labelText: label,
      labelStyle: AppTextStyles.bodySmall,
      filled: true,
      fillColor: AppColors.bgCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.goldPrimary, width: 1.5),
      ),
    ),
  );
}
