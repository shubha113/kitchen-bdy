import 'package:app/constants/app_colors.dart';
import 'package:app/constants/app_constants.dart';
import 'package:app/constants/app_text_styles.dart';
import 'package:app/models/receipt_session.dart';
import 'package:app/services/receipt_session_service.dart';
import 'package:flutter/material.dart';

class ReceiptHistoryScreen extends StatefulWidget {
  const ReceiptHistoryScreen({super.key});

  @override
  State<ReceiptHistoryScreen> createState() => _ReceiptHistoryScreenState();
}

class _ReceiptHistoryScreenState extends State<ReceiptHistoryScreen> {
  List<ReceiptSession> _sessions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final sessions = await ReceiptSessionService.getSessions();
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _loading = false;
    });
  }

  // Confirm session

  Future<void> _confirm(ReceiptSession session) async {
    final ok = await ReceiptSessionService.confirmSession(session.id);
    if (!mounted) return;

    if (ok) {
      setState(() {
        final idx = _sessions.indexWhere((s) => s.id == session.id);
        if (idx != -1) _sessions[idx] = session.asConfirmed();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        _snack(
          '${session.items.length} items added to inventory',
          AppColors.successDim,
          AppColors.success,
          Icons.check_circle,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        _snack(
          'Failed to confirm. Try again.',
          AppColors.warningDim,
          AppColors.warning,
          Icons.warning_amber,
        ),
      );
    }
  }

  // Delete item

  Future<void> _deleteItem(
    ReceiptSession session,
    ReceiptSessionItem item,
  ) async {
    // Optimistic update
    setState(() {
      final idx = _sessions.indexWhere((s) => s.id == session.id);
      if (idx != -1) _sessions[idx] = session.withoutItem(item.id);
    });

    final ok = await ReceiptSessionService.deleteItem(
      sessionId: session.id,
      itemId: item.id,
    );

    if (!ok && mounted) {
      // Roll back
      setState(() {
        final idx = _sessions.indexWhere((s) => s.id == session.id);
        if (idx != -1) _sessions[idx] = session;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        _snack(
          'Failed to delete item.',
          AppColors.warningDim,
          AppColors.warning,
          Icons.warning_amber,
        ),
      );
    }
  }

  // Edit item sheet

  Future<void> _editItem(
    ReceiptSession session,
    ReceiptSessionItem item,
  ) async {
    final updated = await showModalBottomSheet<ReceiptSessionItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditItemSheet(sessionId: session.id, item: item),
    );
    if (updated == null || !mounted) return;

    setState(() {
      final idx = _sessions.indexWhere((s) => s.id == session.id);
      if (idx != -1) _sessions[idx] = session.withUpdatedItem(updated);
    });
  }

  // Build

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);

    return Scaffold(
      backgroundColor: t.bgPrimary,
      appBar: AppBar(
        backgroundColor: t.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: t.textSecondary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Receipt History',
          style: AppTextStyles.headingLargeOf(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.goldPrimary),
            onPressed: _load,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.goldPrimary),
            )
          : _error != null
          ? _errorState()
          : _sessions.isEmpty
          ? _emptyState()
          : RefreshIndicator(
              color: AppColors.goldPrimary,
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: _sessions.length,
                itemBuilder: (_, i) => _SessionCard(
                  session: _sessions[i],
                  onConfirm: () => _confirm(_sessions[i]),
                  onDeleteItem: (item) => _deleteItem(_sessions[i], item),
                  onEditItem: (item) => _editItem(_sessions[i], item),
                ),
              ),
            ),
    );
  }

  Widget _emptyState() {
    final t = AppTheme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 56, color: t.textMuted),
          const SizedBox(height: 16),
          Text(
            'No receipts yet',
            style: AppTextStyles.headingMediumOf(
              context,
            ).copyWith(color: t.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload a receipt to see it here',
            style: AppTextStyles.bodySmallOf(context),
          ),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.error)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  SnackBar _snack(String msg, Color bg, Color textColor, IconData icon) {
    return SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: bg,
      elevation: 0,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: textColor.withValues(alpha: 0.4)),
      ),
      content: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: AppTextStyles.bodyMedium.copyWith(color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Session Card ──────────────────────────────────────────────────────────────

class _SessionCard extends StatefulWidget {
  final ReceiptSession session;
  final Future<void> Function() onConfirm;
  final void Function(ReceiptSessionItem) onDeleteItem;
  final void Function(ReceiptSessionItem) onEditItem;

  const _SessionCard({
    required this.session,
    required this.onConfirm,
    required this.onDeleteItem,
    required this.onEditItem,
  });

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  bool _confirming = false;
  bool _expanded = false; // ← collapsed by default

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final s = widget.session;
    final isPending = s.isPending;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: t.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPending
              ? AppColors.goldPrimary.withValues(alpha: 0.35)
              : AppColors.success.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Tappable Header ──
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: _CardHeader(session: s, expanded: _expanded),
          ),

          // ── Collapsable body ──
          if (_expanded) ...[
            Divider(height: 1, color: t.borderSubtle),

            // ── Items ──
            if (s.items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No items in this receipt',
                  style: AppTextStyles.bodySmallOf(
                    context,
                  ).copyWith(color: t.textMuted),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Column(
                  children: s.items
                      .map(
                        (item) => _ItemRow(
                          item: item,
                          isPending: isPending,
                          onEdit: () => widget.onEditItem(item),
                          onDelete: () => widget.onDeleteItem(item),
                        ),
                      )
                      .toList(),
                ),
              ),

            // ── Confirm button (only for pending) ──
            if (isPending) ...[
              Divider(height: 1, color: t.borderSubtle),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.goldPrimary,
                      foregroundColor: AppColors.textOnGold,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    onPressed: s.items.isEmpty || _confirming
                        ? null
                        : () async {
                            setState(() => _confirming = true);
                            await widget.onConfirm();
                            if (mounted) setState(() => _confirming = false);
                          },
                    child: _confirming
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            'Confirm & Add to Inventory',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ── Card Header ───────────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  final ReceiptSession session;
  final bool expanded;

  const _CardHeader({required this.session, required this.expanded});

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final isPending = session.isPending;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isPending
                  ? AppColors.goldPrimary.withValues(alpha: 0.12)
                  : AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.receipt_long,
              size: 18,
              color: isPending ? AppColors.goldPrimary : AppColors.success,
            ),
          ),
          const SizedBox(width: 12),

          // Title + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${session.items.length} item${session.items.length == 1 ? '' : 's'}',
                  style: AppTextStyles.headingSmallOf(context),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(session.createdAt),
                  style: AppTextStyles.bodySmallOf(context),
                ),
              ],
            ),
          ),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isPending
                  ? AppColors.goldPrimary.withValues(alpha: 0.12)
                  : AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isPending ? 'Pending' : 'Added',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isPending ? AppColors.goldPrimary : AppColors.success,
              ),
            ),
          ),

          // Photo count badge
          if (session.photoCount > 1) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: t.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: t.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 11,
                    color: t.textMuted,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${session.photoCount}',
                    style: TextStyle(
                      fontSize: 11,
                      color: t.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Chevron
          const SizedBox(width: 6),
          Icon(
            expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            size: 18,
            color: t.textSecondary,
          ),
        ],
      ),
    );
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
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '${d.day} ${months[d.month - 1]} ${d.year}  ·  $time';
  }
}

// ── Item Row ──────────────────────────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  final ReceiptSessionItem item;
  final bool isPending;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ItemRow({
    required this.item,
    required this.isPending,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.bgSurface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: t.borderSubtle.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          // Category dot
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: AppColors.categoryColor(item.category),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),

          // Name + category
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: AppTextStyles.bodyMediumOf(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.category,
                  style: AppTextStyles.bodySmallOf(
                    context,
                  ).copyWith(fontSize: 11),
                ),
              ],
            ),
          ),

          // Quantity
          Text(
            item.remainingFormatted,
            style: const TextStyle(
              color: AppColors.goldPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),

          // Price
          if (item.totalPrice != null) ...[
            const SizedBox(width: 8),
            Text(
              '₹${item.totalPrice!.toStringAsFixed(0)}',
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          // Edit / Delete (only for pending)
          if (isPending) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onEdit,
              child: Icon(
                Icons.edit_outlined,
                size: 17,
                color: t.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(
                Icons.delete_outline,
                size: 17,
                color: AppColors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Edit Item Bottom Sheet ────────────────────────────────────────────────────

class _EditItemSheet extends StatefulWidget {
  final int sessionId;
  final ReceiptSessionItem item;

  const _EditItemSheet({required this.sessionId, required this.item});

  @override
  State<_EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends State<_EditItemSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;
  late String _unit;
  late String _category;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.itemName);
    _qtyCtrl = TextEditingController(
      text: widget.item.quantity.toStringAsFixed(
        widget.item.quantity % 1 == 0 ? 0 : 1,
      ),
    );
    _priceCtrl = TextEditingController(
      text: widget.item.totalPrice?.toStringAsFixed(0) ?? '',
    );
    _unit = widget.item.unit;
    _category = widget.item.category;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);

    final updated = await ReceiptSessionService.updateItem(
      sessionId: widget.sessionId,
      itemId: widget.item.id,
      itemName: _nameCtrl.text.trim(),
      category: _category,
      unit: _unit,
      quantity: double.tryParse(_qtyCtrl.text) ?? widget.item.quantity,
      totalPrice: double.tryParse(_priceCtrl.text),
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (updated != null) {
      Navigator.pop(context, updated);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPad),
      decoration: BoxDecoration(
        color: t.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: t.borderGold, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: t.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Text('Edit Item', style: AppTextStyles.headingMediumOf(context)),
          const SizedBox(height: 16),

          // Name
          _SheetField(
            ctrl: _nameCtrl,
            label: 'Item Name',
            icon: Icons.label_outline,
          ),
          const SizedBox(height: 12),

          // Qty + Unit
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _SheetField(
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
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) => setState(() => _unit = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Price
          _SheetField(
            ctrl: _priceCtrl,
            label: 'Total Price (₹, optional)',
            icon: Icons.currency_rupee,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),

          // Category
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
          const SizedBox(height: 20),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.goldPrimary,
                foregroundColor: AppColors.textOnGold,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
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
                      'Save Changes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType? keyboard;

  const _SheetField({
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
        fillColor: t.bgSurface,
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
