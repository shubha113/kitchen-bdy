import 'package:flutter/material.dart';
import 'package:kitchen_bdy/providers/app_provider.dart';
import 'package:provider/provider.dart';

// Categories
const _categories = [
  'Grains',
  'Spices',
  'Pulses',
  'Flour',
  'Sugar',
  'Oil',
  'Other',
];
const _locations = [
  'Shelf 1',
  'Shelf 2',
  'Shelf 3',
  'Counter',
  'Pantry',
  'Fridge',
  'Cabinet',
];

class SensorDiscoveryScreen extends StatefulWidget {
  final String espId;
  final List<int> slots;

  const SensorDiscoveryScreen({
    super.key,
    required this.espId,
    required this.slots,
  });

  @override
  State<SensorDiscoveryScreen> createState() => _SensorDiscoveryScreenState();
}

class _SensorDiscoveryScreenState extends State<SensorDiscoveryScreen> {
  static const _bg = Color(0xFF0F0F0F);
  static const _surface = Color(0xFF1A1A1A);
  static const _gold = Color(0xFFD4A843);
  static const _grey = Color(0xFF888888);
  static const _border = Color(0xFF2A2A2A);
  static const _white = Colors.white;

  // For each slot, store name + location + category controllers
  late final List<TextEditingController> _nameCtrl;
  late final List<String> _location;
  late final List<String> _category;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = List.generate(
      widget.slots.length,
      (i) => TextEditingController(text: 'Sensor ${widget.slots[i]}'),
    );
    _location = List.filled(widget.slots.length, _locations[0]);
    _category = List.filled(widget.slots.length, _categories[0]);
  }

  @override
  void dispose() {
    for (final c in _nameCtrl) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveAll() async {
    // Validate — every sensor needs a name
    for (int i = 0; i < widget.slots.length; i++) {
      if (_nameCtrl[i].text.trim().isEmpty) {
        setState(() => _error = 'Give a name to slot ${widget.slots[i]}');
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final sensors = List.generate(
      widget.slots.length,
      (i) => {
        'espId': widget.espId,
        'slot': widget.slots[i],
        'name': _nameCtrl[i].text.trim(),
        'location': _location[i],
        'category': _category[i],
      },
    );

    final provider = context.read<AppProvider>();
    final ok = await provider.registerDiscoveredSensors(sensors);

    if (!mounted) return;

    if (ok) {
      // Done — go back to home
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.slots.length} sensor(s) added successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _error = 'Failed to save. Check your connection and try again.';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: _white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Name Your Sensors',
          style: TextStyle(color: _white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: widget.slots.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _buildSensorCard(i),
            ),
          ),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
    color: _surface,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _gold.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: _gold, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.slots.length} sensor(s) found',
                    style: const TextStyle(
                      color: _gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'ESP32: ${widget.espId}',
          style: const TextStyle(
            color: _grey,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Give each sensor a name and location. You can rename them anytime.',
          style: TextStyle(color: _grey, fontSize: 13),
        ),
      ],
    ),
  );

  Widget _buildSensorCard(int index) {
    final slot = widget.slots[index];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Slot badge
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
                    '$slot',
                    style: const TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Slot $slot',
                    style: const TextStyle(
                      color: _white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'HX711 sensor active',
                    style: TextStyle(
                      color: Colors.green.shade400,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Name field
          TextField(
            controller: _nameCtrl[index],
            style: const TextStyle(color: _white, fontSize: 14),
            decoration: _inputDec('Name', 'e.g. Basmati Rice, Sugar, Flour'),
          ),

          const SizedBox(height: 12),

          // Location + Category row
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: 'Location',
                  value: _location[index],
                  items: _locations,
                  onChanged: (v) => setState(() => _location[index] = v!),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDropdown(
                  label: 'Category',
                  value: _category[index],
                  items: _categories,
                  onChanged: (v) => setState(() => _category[index] = v!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) => DropdownButtonFormField<String>(
    value: value,
    dropdownColor: const Color(0xFF252525),
    style: const TextStyle(color: _white, fontSize: 13),
    decoration: _inputDec(label, ''),
    items: items
        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
        .toList(),
    onChanged: onChanged,
  );

  Widget _buildSaveButton() => Container(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
    child: Column(
      children: [
        if (_error != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _saving ? null : _saveAll,
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: Colors.black,
              disabledBackgroundColor: _gold.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.black,
                    ),
                  )
                : Text(
                    'Save ${widget.slots.length} Sensor(s)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    ),
  );

  InputDecoration _inputDec(String label, String hint) => InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(color: _grey, fontSize: 12),
    hintStyle: const TextStyle(color: _grey, fontSize: 13),
    filled: true,
    fillColor: const Color(0xFF111111),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _gold, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}
