import 'dart:io';
import 'package:app/main.dart';
import 'package:app/models/alert.dart';
import 'package:app/screens/receipt_history_screen.dart';
import 'package:app/services/receipt_session_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/app_constants.dart';
import '../../models/grocery_item.dart';
import '../../providers/app_provider.dart';
import '../../services/ocr_service.dart';
import '../../services/manual_inventory.dart';

enum _Mode { landing, photoSession, submitting, manual }

class GroceryScreen extends StatefulWidget {
  const GroceryScreen({super.key});
  @override
  State<GroceryScreen> createState() => _GroceryScreenState();
}

class _GroceryScreenState extends State<GroceryScreen> {
  _Mode _mode = _Mode.landing;

  final List<File> _sessionPhotos = [];

  /// Progress tracking during OCR + submission
  int _submitProgress = 0;
  String _submitStatusMsg = '';

  final _imagePickerInstance = ImagePicker();

  // Image picking
  Future<void> _pickImage(ImageSource source) async {
    final picked = await _imagePickerInstance.pickImage(
      source: source,
      imageQuality: 90,
    );
    if (picked == null) return;

    setState(() {
      _sessionPhotos.add(File(picked.path));
      _mode = _Mode.photoSession;
    });
  }

  void _removePhoto(int index) {
    setState(() {
      _sessionPhotos.removeAt(index);
      if (_sessionPhotos.isEmpty) _mode = _Mode.landing;
    });
  }

  // Session submission
  Future<void> _submitSession() async {
    if (_sessionPhotos.isEmpty) return;

    // Phase 1: OCR (on-device, fast)
    setState(() {
      _mode = _Mode.submitting;
      _submitProgress = 0;
      _submitStatusMsg = 'Reading receipt…';
    });

    List<String> ocrTexts;
    try {
      ocrTexts = [];
      for (int i = 0; i < _sessionPhotos.length; i++) {
        if (!mounted) return;
        setState(() {
          _submitProgress = i;
          _submitStatusMsg =
              'Reading photo ${i + 1} of ${_sessionPhotos.length}…';
        });
        final text = await OcrService.extractText(_sessionPhotos[i]);
        ocrTexts.add(text);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _mode = _Mode.photoSession);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not read photo: $e')));
      return;
    }

    if (ocrTexts.every((t) => t.trim().isEmpty)) {
      if (!mounted) return;
      setState(() => _mode = _Mode.photoSession);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No text found — try a clearer photo')),
      );
      return;
    }

    _sessionPhotos.clear();
    if (!mounted) return;
    setState(() {
      _mode = _Mode.landing;
      _submitProgress = 0;
      _submitStatusMsg = '';
    });

    // Capture provider reference now
    final provider = context.read<AppProvider>();

    ReceiptSessionService.createSession(ocrTexts)
        .then((session) {
          if (!mounted) return;

          if (session != null && session.items.isNotEmpty) {
            // Success alert in Alerts screen
            provider.addAlert(
              AppAlert(
                id: 'receipt_${session.id}_${DateTime.now().millisecondsSinceEpoch}',
                type: AlertType.info,
                title: 'Receipt Ready to Review',
                message:
                    '${session.items.length} item${session.items.length == 1 ? '' : 's'} '
                    'extracted from your receipt. Open Receipt History to confirm.',
                timestamp: DateTime.now(),
              ),
            );

            final messenger = messengerKey.currentState!;

            messenger.clearSnackBars();

            messenger.showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.successDim,
                elevation: 0,
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: AppColors.success.withValues(alpha: 0.4),
                  ),
                ),
                content: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${session.items.length} item${session.items.length == 1 ? '' : 's'} ready in Receipt History.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            // Failure alert in Alerts screen
            provider.addAlert(
              AppAlert(
                id: 'receipt_fail_${DateTime.now().millisecondsSinceEpoch}',
                type: AlertType.info,
                title: 'Receipt Scan Failed',
                message: session == null
                    ? 'Could not upload receipt — check your connection and try again.'
                    : 'No items were found in this receipt. Try a clearer photo.',
                timestamp: DateTime.now(),
              ),
            );

            final messenger = messengerKey.currentState!;

            messenger.clearSnackBars();

            messenger.showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.warningDim,
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                content: Text(
                  session == null
                      ? 'Upload failed — check your connection and try again.'
                      : 'No items found. Try a clearer photo.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ),
            );
          }
        })
        .catchError((e) {
          if (!mounted) return;

          provider.addAlert(
            AppAlert(
              id: 'receipt_err_${DateTime.now().millisecondsSinceEpoch}',
              type: AlertType.info,
              title: 'Receipt Scan Error',
              message:
                  'An error occurred while processing your receipt. Please try again.',
              timestamp: DateTime.now(),
            ),
          );

          final messenger = messengerKey.currentState!;

          messenger.clearSnackBars();

          messenger.showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.warningDim,
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              content: Text(
                'Error processing receipt — try again.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.warning,
                ),
              ),
            ),
          );
        });
  }

  // Scaffold
  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: t.bgPrimary,
      appBar: AppBar(
        backgroundColor: t.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: t.textSecondary, size: 18),
          onPressed: _handleBack,
        ),
        title: Text(
          'Grocery Bills',
          style: AppTextStyles.headingLargeOf(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.history,
              color: AppColors.goldPrimary,
              size: 22,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReceiptHistoryScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Future<void> _handleBack() async {
    switch (_mode) {
      case _Mode.manual:
        final canLeave = await Navigator.maybePop(context);
        if (canLeave) return;
        break;
      case _Mode.photoSession:
        // Confirm discard if photos exist
        if (_sessionPhotos.isNotEmpty) {
          final discard = await _confirmDiscard();
          if (!discard) return;
          _sessionPhotos.clear();
        }
        setState(() => _mode = _Mode.landing);
        break;
      case _Mode.submitting:
        // Don't allow back while submitting
        break;
      case _Mode.landing:
        Navigator.pop(context);
        break;
    }
  }

  Future<bool> _confirmDiscard() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) {
            final t = AppTheme.of(ctx);
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: t.bgCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: t.borderGold),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.warningDim,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.warning,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Discard Photos?',
                      style: AppTextStyles.headingMediumOf(ctx),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_sessionPhotos.length} photo${_sessionPhotos.length == 1 ? '' : 's'} will be discarded.',
                      style: AppTextStyles.bodyMediumOf(
                        ctx,
                      ).copyWith(color: t.textSecondary, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(ctx, false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: t.bgCardElevated,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: t.borderSubtle),
                              ),
                              child: Text(
                                'Keep',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.headingSmallOf(
                                  ctx,
                                ).copyWith(color: t.textPrimary),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(ctx, true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                gradient: AppColors.goldGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Discard',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.headingSmallOf(
                                  ctx,
                                ).copyWith(color: AppColors.textOnGold),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ) ??
        false;
  }

  Widget _buildBody() {
    switch (_mode) {
      case _Mode.landing:
        return _buildLanding();
      case _Mode.photoSession:
        return _buildPhotoSession();
      case _Mode.submitting:
        return _buildSubmitting();
      case _Mode.manual:
        return _buildManual();
    }
  }

  // Landing

  Widget _buildLanding() {
    final t = AppTheme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: t.bgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: t.borderGold),
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
                  style: AppTextStyles.displaySmallOf(context),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Capture one or more photos of your receipt.\nWe handle long receipts automatically — just\nadd all the parts then hit Submit.',
                  style: AppTextStyles.bodyMediumOf(
                    context,
                  ).copyWith(color: t.textSecondary),
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
        ],
      ),
    );
  }

  // Photo Session

  Widget _buildPhotoSession() {
    final t = AppTheme.of(context);
    final photoCount = _sessionPhotos.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header info banner
        Container(
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.goldPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.goldPrimary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: AppColors.goldPrimary,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'All photos here belong to ONE receipt. '
                  'For a new receipt, submit this one first.',
                  style: AppTextStyles.bodySmallOf(
                    context,
                  ).copyWith(color: AppColors.goldPrimary, height: 1.4),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text('RECEIPT PHOTOS', style: AppTextStyles.goldLabel),
              const Spacer(),
              Text(
                '$photoCount photo${photoCount == 1 ? '' : 's'}',
                style: AppTextStyles.bodySmallOf(context),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Photo grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: photoCount,
            itemBuilder: (ctx, i) => _PhotoThumbnail(
              file: _sessionPhotos[i],
              index: i,
              total: photoCount,
              onRemove: () => _removePhoto(i),
            ),
          ),
        ),

        // Bottom action bar
        Container(
          decoration: BoxDecoration(
            color: t.bgPrimary,
            border: Border(top: BorderSide(color: t.borderSubtle, width: 0.5)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Add more photos row
              Row(
                children: [
                  Expanded(
                    child: _OutlineButton(
                      icon: Icons.camera_alt_outlined,
                      label: 'Camera',
                      onTap: () => _pickImage(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _OutlineButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Gallery',
                      onTap: () => _pickImage(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Submit button
              GestureDetector(
                onTap: _submitSession,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.cloud_upload_outlined,
                        color: AppColors.textOnGold,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Submit Receipt ($photoCount photo${photoCount == 1 ? '' : 's'})',
                        style: AppTextStyles.headingMediumOf(
                          context,
                        ).copyWith(color: AppColors.textOnGold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Submitting (OCR + API)

  Widget _buildSubmitting() {
    final t = AppTheme.of(context);
    final total = _sessionPhotos.length;
    final progress = total > 0 ? _submitProgress / total : 0.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: t.bgCard,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.document_scanner_outlined,
                color: AppColors.goldPrimary,
                size: 48,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Processing Receipt…',
              style: AppTextStyles.displaySmallOf(context),
            ),
            const SizedBox(height: 8),
            Text(
              _submitStatusMsg,
              style: AppTextStyles.bodyMediumOf(
                context,
              ).copyWith(color: t.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _submitProgress == 0 ? null : progress,
                minHeight: 6,
                backgroundColor: t.bgCard,
                valueColor: const AlwaysStoppedAnimation(AppColors.goldPrimary),
              ),
            ),
            const SizedBox(height: 12),

            if (total > 1)
              Text(
                '$_submitProgress / $total photos read',
                style: AppTextStyles.bodySmallOf(context),
              ),
          ],
        ),
      ),
    );
  }

  // Manual entry

  Widget _buildManual() => const _ManualEntryForm();
}

// Photo Thumbnail

class _PhotoThumbnail extends StatelessWidget {
  final File file;
  final int index;
  final int total;
  final VoidCallback onRemove;

  const _PhotoThumbnail({
    required this.file,
    required this.index,
    required this.total,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Photo
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: t.bgCard,
              child: const Icon(
                Icons.broken_image_outlined,
                color: AppColors.goldPrimary,
              ),
            ),
          ),
        ),

        // Dark overlay gradient at top
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 56,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Page badge (e.g. "1 of 3")
        Positioned(
          top: 10,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Page ${index + 1} of $total',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        // Remove (×) button
        Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}

// Outline Add-Photo Button

class _OutlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OutlineButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: t.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.borderGold),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.goldPrimary, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.bodyMediumOf(
                context,
              ).copyWith(color: AppColors.goldPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

// Large Action Tile

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
    final t = AppTheme.of(context);
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
                    style: AppTextStyles.headingSmallOf(
                      context,
                    ).copyWith(color: c),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.bodySmallOf(context)),
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

// Manual Entry Form

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

  static const double _saveBarHeight = 92.0;

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
          price: double.tryParse(_priceCtrl.text),
        ),
      );
      _nameCtrl.clear();
      _qtyCtrl.clear();
      _priceCtrl.clear();
    });
  }

  Future<bool> _onWillPop() async {
    if (_items.isEmpty) return true;
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) {
        final t = AppTheme.of(context);
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: t.bgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: t.borderGold),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.warningDim,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Unsaved Items',
                  style: AppTextStyles.headingMediumOf(context),
                ),
                const SizedBox(height: 8),
                Text(
                  "You added ${_items.length} item${_items.length == 1 ? '' : 's'} but haven't saved yet.\n\nIf you leave now, they will be lost.",
                  style: AppTextStyles.bodyMediumOf(
                    context,
                  ).copyWith(color: t.textSecondary, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: t.bgCardElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: t.borderSubtle),
                          ),
                          child: Text(
                            'Stay',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.headingSmallOf(
                              context,
                            ).copyWith(color: t.textPrimary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: AppColors.goldGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Leave',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.headingSmallOf(
                              context,
                            ).copyWith(color: AppColors.textOnGold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return shouldLeave ?? false;
  }

  Future<void> _saveToInventory() async {
    if (_items.isEmpty || _saving) return;
    setState(() => _saving = true);
    int saved = 0, failed = 0;
    for (final item in _items) {
      final result = await ManualInventoryService.addPurchase(
        itemName: item.name,
        category: item.category,
        quantity: item.quantity,
        unit: item.unit,
        totalPrice: item.price,
      );
      result != null ? saved++ : failed++;
    }
    if (mounted) context.read<AppProvider>().addGroceryItems(_items);
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
    final t = AppTheme.of(context);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              _items.isNotEmpty ? _saveBarHeight + 12 : 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ADD ITEMS MANUALLY', style: AppTextStyles.goldLabel),
                const SizedBox(height: 16),
                _Field(
                  ctrl: _nameCtrl,
                  label: 'Item Name',
                  icon: Icons.label_outline,
                ),
                const SizedBox(height: 12),
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
                        dropdownColor: t.bgCardElevated,
                        isExpanded: true,
                        style: TextStyle(color: t.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Unit',
                          labelStyle: AppTextStyles.bodySmallOf(context),
                          filled: true,
                          fillColor: t.bgCard,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: AppConstants.units
                            .map(
                              (u) => DropdownMenuItem(value: u, child: Text(u)),
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
                  label: 'Total price paid (optional, ₹)',
                  icon: Icons.currency_rupee,
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    "Leave blank if you don't want to track spending",
                    style: AppTextStyles.bodySmallOf(
                      context,
                    ).copyWith(color: t.textMuted, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _category,
                  dropdownColor: t.bgCardElevated,
                  isExpanded: true,
                  style: TextStyle(color: t.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Category',
                    labelStyle: AppTextStyles.bodySmallOf(context),
                    filled: true,
                    fillColor: t.bgCard,
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
                GestureDetector(
                  onTap: _addItem,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: t.bgCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: t.borderGold),
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
                          style: AppTextStyles.headingSmallOf(
                            context,
                          ).copyWith(color: AppColors.goldPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_items.isNotEmpty) ...[
                  const SizedBox(height: 20),
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
                          color: t.bgCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: t.borderSubtle),
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
                                    style: AppTextStyles.bodyMediumOf(context),
                                  ),
                                  Text(
                                    e.value.price != null
                                        ? '${e.value.category}  ·  ₹${e.value.price!.toStringAsFixed(0)}/${e.value.unit}'
                                        : e.value.category,
                                    style: AppTextStyles.bodySmallOf(context),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${e.value.quantity.toStringAsFixed(0)} ${e.value.unit}',
                              style: AppTextStyles.bodySmallOf(
                                context,
                              ).copyWith(color: AppColors.goldPrimary),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _items.removeAt(e.key)),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: t.textMuted,
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
          if (_items.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: t.bgPrimary,
                  border: Border(
                    top: BorderSide(color: t.borderSubtle, width: 0.5),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.goldPrimary,
                      foregroundColor: AppColors.textOnGold,
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
            ),
        ],
      ),
    );
  }
}

// Field

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
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      style: AppTextStyles.bodyMediumOf(context),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: t.textSecondary, size: 18),
        labelText: label,
        labelStyle: AppTextStyles.bodySmallOf(context),
        filled: true,
        fillColor: t.bgCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.goldPrimary,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
