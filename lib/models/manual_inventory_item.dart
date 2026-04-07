class ManualInventoryItem {
  final int id;
  final String itemName;
  final String category;
  final String unit;

  final double? packSizeGrams;

  final double totalPurchased;
  final double packsRemaining;

  final double? threshold;
  final String thresholdUnit;
  final double? pricePerUnit;
  final double? totalSpent;

  final String? linkedSensorId;
  final bool hasSensor;

  final DateTime? lastReconciled;
  final DateTime createdAt;

  final bool isFilledByUser;

  // REMINDER
  final DateTime? reminderDate;
  final bool reminderRecurring;
  final String? reminderRepeatType;
  final bool reminderFired;

  const ManualInventoryItem({
    required this.id,
    required this.itemName,
    required this.category,
    required this.unit,
    this.packSizeGrams,
    required this.totalPurchased,
    required this.packsRemaining,
    this.thresholdUnit = 'kg',
    this.threshold,
    this.pricePerUnit,
    this.totalSpent,
    this.linkedSensorId,
    required this.hasSensor,
    this.lastReconciled,
    required this.createdAt,
    this.isFilledByUser = false,
    this.reminderDate,
    this.reminderRecurring = false,
    this.reminderRepeatType,
    this.reminderFired = false,
  });

  factory ManualInventoryItem.fromJson(Map<String, dynamic> j) {
    return ManualInventoryItem(
      id: j['id'] as int,
      itemName: j['itemName'] as String,
      category: (j['category'] as String?) ?? 'Other',
      unit: (j['unit'] as String?) ?? 'kg',
      packSizeGrams: (j['packSizeGrams'] as num?)?.toDouble(),
      totalPurchased: (j['totalPurchased'] as num?)?.toDouble() ?? 0,
      packsRemaining: (j['packsRemaining'] as num?)?.toDouble() ?? 0,
      thresholdUnit: (j['thresholdUnit'] as String?) ?? 'kg',
      threshold: (j['threshold'] as num?)?.toDouble(),
      pricePerUnit: (j['pricePerUnit'] as num?)?.toDouble(),
      totalSpent: (j['totalSpent'] as num?)?.toDouble(),
      linkedSensorId: j['linkedSensorId'] as String?,
      hasSensor: (j['hasSensor'] as bool?) ?? false,
      lastReconciled: j['lastReconciled'] != null
          ? DateTime.tryParse(j['lastReconciled'])
          : null,
      createdAt: DateTime.parse(j['createdAt']),
      isFilledByUser: (j['isFilledByUser'] as bool?) ?? false,
      reminderDate: j['reminderDate'] != null
          ? DateTime.tryParse(j['reminderDate'] as String)
          : null,
      reminderRecurring: (j['reminderRecurring'] as bool?) ?? false,
      reminderRepeatType: (j['reminderRepeatType'] as String?),
      reminderFired: (j['reminderFired'] as bool?) ?? false,
    );
  }

  // Computed

  int? get daysSinceReconciled {
    if (lastReconciled == null) return null;
    return DateTime.now().difference(lastReconciled!).inDays;
  }

  bool get needsReconciliation =>
      lastReconciled == null ||
      DateTime.now().difference(lastReconciled!).inDays > 7;

  bool get isOutOfStock => packsRemaining <= 0;

  double get thresholdInItemUnit {
    if (threshold == null) return 0;
    final tUnit = thresholdUnit;
    final iUnit = unit;
    if (tUnit == iUnit) return threshold!;
    if (tUnit == 'g' && iUnit == 'kg') return threshold! / 1000;
    if (tUnit == 'kg' && iUnit == 'g') return threshold! * 1000;
    if (tUnit == 'ml' && iUnit == 'L') return threshold! / 1000;
    if (tUnit == 'L' && iUnit == 'ml') return threshold! * 1000;
    return threshold!;
  }

  bool get isLowStock {
    if (threshold == null) return false;
    if (isFilledByUser) return false;
    return packsRemaining <= thresholdInItemUnit;
  }

  /// True when a reminder is set AND it hasn't fired yet.
  bool get hasActiveReminder => reminderDate != null && !reminderFired;

  /// True when reminderDate is in the past and not yet fired — i.e. due now.
  bool get isReminderDue =>
      reminderDate != null &&
      !reminderFired &&
      reminderDate!.isBefore(DateTime.now());

  /// Human-readable label for the reminder date, e.g. "Remind: Mar 28"
  String? get reminderLabel {
    if (reminderDate == null) return null;
    final d = reminderDate!;
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
    final dateStr = '${months[d.month - 1]} ${d.day}';
    if (reminderRecurring && reminderRepeatType == 'weekly')
      return 'Every week';
    if (reminderRecurring && reminderRepeatType == 'monthly')
      return 'Every ${d.day}th';
    return 'Remind: $dateStr';
  }

  // Formatting

  String get remainingFormatted {
    if (packsRemaining <= 0) return 'Out of stock';
    final n = packsRemaining % 1 == 0
        ? packsRemaining.toInt().toString()
        : packsRemaining.toStringAsFixed(1);
    return '$n $unit';
  }

  String? get priceLabel {
    if (pricePerUnit == null) return null;
    return '₹${pricePerUnit!.toStringAsFixed(0)}/$unit';
  }

  String? get totalSpentLabel {
    if (totalSpent == null) return null;
    return '₹${totalSpent!.toStringAsFixed(0)} spent';
  }

  String? get thresholdLabel {
    if (threshold == null) return null;
    return 'Alert <$threshold $thresholdUnit';
  }

  // CopyWith

  ManualInventoryItem copyWith({
    double? packsRemaining,
    double? threshold,
    String? linkedSensorId,
    bool? hasSensor,
    DateTime? lastReconciled,
    bool? isFilledByUser,
    String? thresholdUnit,
    DateTime? reminderDate,
    bool? reminderRecurring,
    String? reminderRepeatType,
    bool? reminderFired,
    bool clearReminder = false,
  }) {
    return ManualInventoryItem(
      id: id,
      itemName: itemName,
      category: category,
      unit: unit,
      packSizeGrams: packSizeGrams,
      totalPurchased: totalPurchased,
      packsRemaining: packsRemaining ?? this.packsRemaining,
      threshold: threshold ?? this.threshold,
      thresholdUnit: thresholdUnit ?? this.thresholdUnit,
      pricePerUnit: pricePerUnit,
      totalSpent: totalSpent,
      linkedSensorId: linkedSensorId ?? this.linkedSensorId,
      hasSensor: hasSensor ?? this.hasSensor,
      lastReconciled: lastReconciled ?? this.lastReconciled,
      createdAt: createdAt,
      isFilledByUser: isFilledByUser ?? this.isFilledByUser,
      reminderDate: clearReminder ? null : (reminderDate ?? this.reminderDate),
      reminderRecurring: reminderRecurring ?? this.reminderRecurring,
      reminderRepeatType: reminderRepeatType ?? this.reminderRepeatType,
      reminderFired: reminderFired ?? this.reminderFired,
    );
  }
}
