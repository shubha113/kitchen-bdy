import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/app_constants.dart';
import '../../models/grocery_item.dart';
import '../../providers/app_provider.dart';
import '../../data/mock_data.dart';
import '../../services/ocr_service.dart';
import '../../services/receipt_parser.dart';
import '../../services/manual_inventory.dart';

enum _Mode { landing, scanning, review, manual }

class GroceryScreen extends StatefulWidget {
  const GroceryScreen({super.key});
  @override
  State<GroceryScreen> createState() => _GroceryScreenState();
}

class _GroceryScreenState extends State<GroceryScreen> {
  _Mode _mode = _Mode.landing;
  bool _isAnalyzing = false;
  List<Map<String, dynamic>> _parsedItems = [];
  String _rawOcrText = '';
  final _imagePickerInstance = ImagePicker();

  double _calculateItemsTotal() {
    double total = 0;
    for (final item in _parsedItems) {
      final price = item['price'];
      if (price != null) {
        total += (price as num).toDouble();
      }
    }
    return total;
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _imagePickerInstance.pickImage(
      source: source,
      imageQuality: 90,
    );
    if (picked == null) return;

    setState(() {
      _mode = _Mode.scanning;
      _isAnalyzing = true;
    });

    try {
      // Step 1: ML Kit extracts text — this is fast (local, on-device)
      final rawText = await OcrService.extractText(File(picked.path));

      if (!mounted) return;

      if (rawText.trim().isEmpty) {
        setState(() {
          _isAnalyzing = false;
          _mode = _Mode.landing;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No text found — try a clearer photo')),
        );
        return;
      }

      // Step 2: Fire and forget — don't await Gemini
      ManualInventoryService.parseReceipt(rawText);

      // Step 3: Go back to landing immediately
      setState(() {
        _isAnalyzing = false;
        _mode = _Mode.landing;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.successDim,
          duration: const Duration(seconds: 4),
          content: Text(
            'Receipt uploaded! Items will appear in inventory shortly.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.success),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _mode = _Mode.landing;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.bgCard,
          content: Text(
            'Could not read receipt: $e',
            style: AppTextStyles.bodyMedium,
          ),
        ),
      );
    }
  }

  void _addAllToInventory() {
    final items = _parsedItems
        .map(
          (json) => GroceryItem(
            id: 'G_${DateTime.now().millisecondsSinceEpoch}_${json['name']}',
            name: json['name'],
            category: json['category'],
            quantity: (json['quantity'] as num).toDouble(),
            unit: json['unit'],
            threshold: AppConstants.defaultThresholdGrams,
            price: (json['price'] as num?)?.toDouble(),
          ),
        )
        .toList();
    context.read<AppProvider>().addGroceryItems(items);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.successDim,
        content: Text(
          '${items.length} items added to inventory',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.success),
        ),
      ),
    );
    Navigator.pop(context);
  }

  void _showRawOcrText() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RawOcrSheet(rawText: _rawOcrText),
    );
  }

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
        onPressed: () => _mode == _Mode.landing
            ? Navigator.pop(context)
            : setState(() => _mode = _Mode.landing),
      ),
      title: Text('Grocery Bills', style: AppTextStyles.headingLarge),
      actions: [
        if (_mode == _Mode.review && _rawOcrText.isNotEmpty)
          TextButton.icon(
            onPressed: _showRawOcrText,
            icon: const Icon(
              Icons.bug_report_outlined,
              color: AppColors.info,
              size: 16,
            ),
            label: Text(
              'Raw OCR',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.info),
            ),
          ),
      ],
    ),
    body: SafeArea(child: _buildBody()),
  );

  Widget _buildBody() {
    switch (_mode) {
      case _Mode.landing:
        return _buildLanding();
      case _Mode.scanning:
        return _buildScanning();
      case _Mode.review:
        return _buildReview();
      case _Mode.manual:
        return _buildManual();
    }
  }

  // Landing

  Widget _buildLanding() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(24),
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
              const Icon(
                Icons.receipt_long,
                color: AppColors.goldPrimary,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Smart Bill Scanner',
                style: AppTextStyles.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Take a photo of your grocery bill or upload\none from your gallery. ML Kit will extract\ntext automatically.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _LargeActionTile(
          icon: Icons.camera_alt_outlined,
          title: 'Take a Photo',
          subtitle: 'Capture your receipt with the camera',
          onTap: () => _pickImage(ImageSource.camera),
        ),
        const SizedBox(height: 14),
        _LargeActionTile(
          icon: Icons.photo_library_outlined,
          title: 'Upload from Gallery',
          subtitle: 'Select an existing photo of your bill',
          onTap: () => _pickImage(ImageSource.gallery),
        ),
        const SizedBox(height: 14),
        _LargeActionTile(
          icon: Icons.edit_note_outlined,
          title: 'Manual Entry',
          subtitle: 'Type in your grocery items manually',
          color: AppColors.info,
          onTap: () => setState(() => _mode = _Mode.manual),
        ),
        const Spacer(),
        if (context.watch<AppProvider>().groceryItems.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text('RECENT PURCHASES', style: AppTextStyles.goldLabel),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: context
                  .watch<AppProvider>()
                  .groceryItems
                  .take(5)
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _GroceryChip(item: item),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ],
    ),
  );

  // Scanning

  Widget _buildScanning() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.document_scanner_outlined,
            color: AppColors.goldPrimary,
            size: 48,
          ),
        ),
        const SizedBox(height: 32),
        Text('Reading Receipt…', style: AppTextStyles.displaySmall),
        const SizedBox(height: 8),
        Text(
          'ML Kit is extracting text from\nyour grocery bill',
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
        const SizedBox(height: 24),
        Text('This may take a few seconds…', style: AppTextStyles.bodySmall),
      ],
    ),
  );

  // Review

  Widget _buildReview() {
    final bill = kSampleParsedBill;
    final total = _calculateItemsTotal();
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderGold),
          ),
          child: Row(
            children: [
              const Icon(Icons.store_outlined, color: AppColors.goldPrimary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill['store'] as String,
                      style: AppTextStyles.headingSmall,
                    ),
                    Text(
                      bill['bill_date'] as String,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Total', style: AppTextStyles.bodySmall),
                  Text(
                    '₹${total.toStringAsFixed(2)}',
                    style: AppTextStyles.weightSmall.copyWith(
                      color: AppColors.goldPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text('EXTRACTED ITEMS', style: AppTextStyles.goldLabel),
              const Spacer(),
              Text(
                '${_parsedItems.length} items',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _parsedItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _ParsedItemTile(
              item: _parsedItems[i],
              onEdit: (updated) => setState(() => _parsedItems[i] = updated),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              GestureDetector(
                onTap: _addAllToInventory,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Add All to Inventory',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.headingMedium.copyWith(
                      color: AppColors.textOnGold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => setState(() => _mode = _Mode.landing),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Text(
                    'Scan Another',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.headingSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManual() => const _ManualEntryForm();
}

// Raw OCR Debug Bottom Sheet

class _RawOcrSheet extends StatelessWidget {
  final String rawText;
  const _RawOcrSheet({required this.rawText});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(
                    Icons.bug_report_outlined,
                    color: AppColors.info,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Raw OCR Output',
                    style: AppTextStyles.headingSmall.copyWith(
                      color: AppColors.info,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'DEBUG',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.info,
                        fontSize: 10,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'This is the exact text ML Kit extracted from your receipt image. Use this to verify OCR quality before wiring up AI parsing.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: AppColors.borderSubtle, height: 1),
            const SizedBox(height: 12),
            Expanded(
              child: rawText.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.text_fields_outlined,
                            color: AppColors.textSecondary,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No text was extracted.\nTry a clearer image.',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.bgPrimary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${rawText.split('\n').length} lines  ·  ${rawText.length} chars',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.bgPrimary,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: SelectableText(
                            rawText,
                            style: AppTextStyles.bodySmall.copyWith(
                              fontFamily: 'monospace',
                              height: 1.6,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.info.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.tips_and_updates_outlined,
                                color: AppColors.info,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This text is stored in _rawOcrText and is ready to send to your AI service. Replace ReceiptParser.parse() in grocery_screen.dart with your AI call.',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.info,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Shared Widgets

class _LargeActionTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final Color? color;

  const _LargeActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.goldPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: c, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.headingSmall.copyWith(color: c),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: c.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParsedItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final void Function(Map<String, dynamic>) onEdit;

  const _ParsedItemTile({required this.item, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.categoryColor(item['category'] as String);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'] as String, style: AppTextStyles.bodyMedium),
                Text(
                  '${item['category']}  ·  ${item['quantity']} ${item['unit']}',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          if (item['price'] != null)
            Text(
              '₹${item['price']}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.goldPrimary,
              ),
            ),
          const SizedBox(width: 8),
          const Icon(Icons.check_circle, color: AppColors.success, size: 18),
        ],
      ),
    );
  }
}

class _GroceryChip extends StatelessWidget {
  final GroceryItem item;
  const _GroceryChip({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.categoryColor(item.category);
    return Container(
      width: 90,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(height: 8),
          Text(
            item.name,
            style: AppTextStyles.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${item.quantity.toStringAsFixed(0)} ${item.unit}',
            style: AppTextStyles.labelSmall.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

// Manual Entry
class _ManualEntryForm extends StatefulWidget {
  const _ManualEntryForm();
  @override
  State<_ManualEntryForm> createState() => _ManualEntryFormState();
}

class _ManualEntryFormState extends State<_ManualEntryForm> {
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  String _unit = 'g';
  String _category = 'Grains';
  final List<GroceryItem> _items = [];
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _addItem() {
    if (_nameCtrl.text.trim().isEmpty || _qtyCtrl.text.trim().isEmpty) return;
    setState(() {
      _items.add(
        GroceryItem(
          id: 'M_${DateTime.now().millisecondsSinceEpoch}',
          name: _nameCtrl.text.trim(),
          category: _category,
          quantity: double.tryParse(_qtyCtrl.text) ?? 0,
          unit: _unit,
          threshold: AppConstants.defaultThresholdGrams,
          price: double.tryParse(_priceCtrl.text), // ← NEW
        ),
      );
      _nameCtrl.clear();
      _qtyCtrl.clear();
      _priceCtrl.clear();
    });
  }

  Future<void> _saveToInventory() async {
    if (_items.isEmpty || _saving) return;
    setState(() => _saving = true);

    int saved = 0;
    int failed = 0;

    for (final item in _items) {
      final result = await ManualInventoryService.addPurchase(
        itemName: item.name,
        category: item.category,
        quantity: item.quantity,
        unit: item.unit,
        pricePerUnit: item.price,
      );
      if (result != null) {
        saved++;
      } else {
        failed++;
        debugPrint('[GroceryManual] Backend save failed for: ${item.name}');
      }
    }

    if (mounted) {
      context.read<AppProvider>().addGroceryItems(_items);
    }

    if (!mounted) return;
    setState(() => _saving = false);

    final msg = failed == 0
        ? '$saved item${saved == 1 ? '' : 's'} saved to inventory'
        : '$saved saved, $failed failed — check your connection';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: failed == 0
            ? AppColors.successDim
            : AppColors.warningDim,
        content: Text(
          msg,
          style: AppTextStyles.bodyMedium.copyWith(
            color: failed == 0 ? AppColors.success : AppColors.warning,
          ),
        ),
      ),
    );

    if (failed == 0 && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ADD ITEMS MANUALLY', style: AppTextStyles.goldLabel),
                  const SizedBox(height: 16),

                  // Item name
                  _Field(
                    ctrl: _nameCtrl,
                    label: 'Item Name',
                    icon: Icons.label_outline,
                  ),
                  const SizedBox(height: 12),

                  // Quantity + Unit
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _Field(
                          ctrl: _qtyCtrl,
                          label: 'Quantity',
                          icon: Icons.scale,
                          keyboard: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _unit,
                          dropdownColor: AppColors.bgCard,
                          isExpanded: true,
                          style: AppTextStyles.bodyMedium,
                          decoration: InputDecoration(
                            labelText: 'Unit',
                            labelStyle: AppTextStyles.bodySmall,
                            filled: true,
                            fillColor: AppColors.bgCard,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: AppConstants.units
                              .map(
                                (u) =>
                                    DropdownMenuItem(value: u, child: Text(u)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _unit = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _Field(
                    ctrl: _priceCtrl,
                    label: 'Price per $_unit (optional, ₹)',
                    icon: Icons.currency_rupee,
                    keyboard: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      'Leave blank if you don\'t want to track spending',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _category,
                    dropdownColor: AppColors.bgCard,
                    isExpanded: true,
                    style: AppTextStyles.bodyMedium,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      labelStyle: AppTextStyles.bodySmall,
                      filled: true,
                      fillColor: AppColors.bgCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: AppConstants.categories
                        .skip(1)
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                  const SizedBox(height: 16),

                  // Stage item button
                  GestureDetector(
                    onTap: _addItem,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderGold),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.add,
                            color: AppColors.goldPrimary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Add Item',
                            style: AppTextStyles.headingSmall.copyWith(
                              color: AppColors.goldPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Staged items list
                  if (_items.isNotEmpty) ...[
                    Text(
                      'ITEMS TO ADD (${_items.length})',
                      style: AppTextStyles.goldLabel,
                    ),
                    const SizedBox(height: 10),
                    ..._items.asMap().entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.bgCard,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: AppColors.categoryColor(
                                    e.value.category,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.value.name,
                                      style: AppTextStyles.bodyMedium,
                                    ),
                                    // ── NEW: show category + price if set ──
                                    Text(
                                      e.value.price != null
                                          ? '${e.value.category}  ·  ₹${e.value.price!.toStringAsFixed(0)}/${e.value.unit}'
                                          : e.value.category,
                                      style: AppTextStyles.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${e.value.quantity.toStringAsFixed(0)} ${e.value.unit}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.goldPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _items.removeAt(e.key)),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        if (_items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldPrimary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: _saving ? null : _saveToInventory,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        'Save ${_items.length} Item${_items.length == 1 ? '' : 's'} to Inventory',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType? keyboard;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.keyboard,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    keyboardType: keyboard,
    style: AppTextStyles.bodyMedium,
    decoration: InputDecoration(
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 18),
      labelText: label,
      labelStyle: AppTextStyles.bodySmall,
      filled: true,
      fillColor: AppColors.bgCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.goldPrimary, width: 1.5),
      ),
    ),
  );
}
