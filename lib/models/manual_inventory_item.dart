class ManualInventoryItem {
  final int id;
  final String itemName;
  final String category;
  final String unit;

  final double? packSizeGrams;

  final double totalPurchased;
  final double packsRemaining;

  final double? threshold;
  final double? pricePerUnit;
  final double? totalSpent;

  final String? linkedSensorId;
  final bool hasSensor;

  final DateTime? lastReconciled;
  final DateTime createdAt;

  const ManualInventoryItem({
    required this.id,
    required this.itemName,
    required this.category,
    required this.unit,
    this.packSizeGrams,
    required this.totalPurchased,
    required this.packsRemaining,
    this.threshold,
    this.pricePerUnit,
    this.totalSpent,
    this.linkedSensorId,
    required this.hasSensor,
    this.lastReconciled,
    required this.createdAt,
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
      threshold: (j['threshold'] as num?)?.toDouble(),
      pricePerUnit: (j['pricePerUnit'] as num?)?.toDouble(),
      totalSpent: (j['totalSpent'] as num?)?.toDouble(),
      linkedSensorId: j['linkedSensorId'] as String?,
      hasSensor: (j['hasSensor'] as bool?) ?? false,
      lastReconciled: j['lastReconciled'] != null
          ? DateTime.tryParse(j['lastReconciled'])
          : null,
      createdAt: DateTime.parse(j['createdAt']),
    );
  }

  /// Days since user confirmed stock
  int? get daysSinceReconciled {
    if (lastReconciled == null) return null;
    return DateTime.now().difference(lastReconciled!).inDays;
  }

  /// True if user hasn't confirmed stock in >7 days
  bool get needsReconciliation =>
      lastReconciled == null ||
          DateTime.now().difference(lastReconciled!).inDays > 7;

  /// Out of stock
  bool get isOutOfStock => packsRemaining <= 0;

  /// Low stock based on threshold
  bool get isLowStock {
    if (threshold == null) return false;
    return packsRemaining <= threshold!;
  }

  /// Remaining stock formatted
  String get remainingFormatted {
    if (packsRemaining <= 0) return 'Out of stock';
    final n = packsRemaining % 1 == 0
        ? packsRemaining.toInt().toString()
        : packsRemaining.toStringAsFixed(1);
    return '$n $unit';
  }

  /// Price label (₹120/kg)
  String? get priceLabel {
    if (pricePerUnit == null) return null;
    return '₹${pricePerUnit!.toStringAsFixed(0)}/$unit';
  }

  /// Total spent label
  String? get totalSpentLabel {
    if (totalSpent == null) return null;
    return '₹${totalSpent!.toStringAsFixed(0)} spent';
  }

  /// Threshold label
  String? get thresholdLabel {
    if (threshold == null) return null;
    return 'Alert <$threshold $unit';
  }

  ManualInventoryItem copyWith({
    double? packsRemaining,
    double? threshold,
    String? linkedSensorId,
    bool? hasSensor,
    DateTime? lastReconciled,
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
      pricePerUnit: pricePerUnit,
      totalSpent: totalSpent,
      linkedSensorId: linkedSensorId ?? this.linkedSensorId,
      hasSensor: hasSensor ?? this.hasSensor,
      lastReconciled: lastReconciled ?? this.lastReconciled,
      createdAt: createdAt,
    );
  }
}