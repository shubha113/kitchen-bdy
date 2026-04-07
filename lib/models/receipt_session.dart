class ReceiptSessionItem {
  final int id;
  final int sessionId;
  final String itemName;
  final String category;
  final String unit;
  final double quantity;
  final double? totalPrice;
  final double? pricePerUnit;
  final int? inventoryItemId;
  final DateTime createdAt;

  ReceiptSessionItem({
    required this.id,
    required this.sessionId,
    required this.itemName,
    required this.category,
    required this.unit,
    required this.quantity,
    this.totalPrice,
    this.pricePerUnit,
    this.inventoryItemId,
    required this.createdAt,
  });

  factory ReceiptSessionItem.fromJson(Map<String, dynamic> j) {
    return ReceiptSessionItem(
      id: j['id'] as int,
      sessionId: j['sessionId'] as int,
      itemName: j['itemName'] as String,
      category: j['category'] as String? ?? 'Other',
      unit: j['unit'] as String? ?? 'pcs',
      quantity: (j['quantity'] as num?)?.toDouble() ?? 0,
      totalPrice: (j['totalPrice'] as num?)?.toDouble(),
      pricePerUnit: (j['pricePerUnit'] as num?)?.toDouble(),
      inventoryItemId: j['inventoryItemId'] as int?,
      createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
    );
  }

  ReceiptSessionItem copyWith({
    String? itemName,
    String? category,
    String? unit,
    double? quantity,
    double? totalPrice,
  }) {
    return ReceiptSessionItem(
      id: id,
      sessionId: sessionId,
      itemName: itemName ?? this.itemName,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      totalPrice: totalPrice ?? this.totalPrice,
      pricePerUnit: pricePerUnit,
      inventoryItemId: inventoryItemId,
      createdAt: createdAt,
    );
  }

  String get remainingFormatted {
    final q = quantity % 1 == 0
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(1);
    return '$q $unit';
  }
}

class ReceiptSession {
  final int id;
  final String status;
  final int photoCount;
  final DateTime? confirmedAt;
  final DateTime createdAt;
  final List<ReceiptSessionItem> items;

  ReceiptSession({
    required this.id,
    required this.status,
    required this.photoCount,
    this.confirmedAt,
    required this.createdAt,
    required this.items,
  });

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';

  factory ReceiptSession.fromJson(Map<String, dynamic> j) {
    final rawItems = j['items'] as List<dynamic>? ?? [];
    return ReceiptSession(
      id: j['id'] as int,
      status: j['status'] as String? ?? 'pending',
      photoCount: j['photoCount'] as int? ?? 1,
      confirmedAt: j['confirmedAt'] != null
          ? DateTime.parse(j['confirmedAt'] as String).toLocal()
          : null,

      createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
      items: rawItems
          .map((e) => ReceiptSessionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Returns a copy with the given item replaced (for optimistic UI updates).
  ReceiptSession withUpdatedItem(ReceiptSessionItem updated) {
    return ReceiptSession(
      id: id,
      status: status,
      photoCount: photoCount,
      confirmedAt: confirmedAt,
      createdAt: createdAt,
      items: items.map((i) => i.id == updated.id ? updated : i).toList(),
    );
  }

  /// Returns a copy with an item removed.
  ReceiptSession withoutItem(int itemId) {
    return ReceiptSession(
      id: id,
      status: status,
      photoCount: photoCount,
      confirmedAt: confirmedAt,
      createdAt: createdAt,
      items: items.where((i) => i.id != itemId).toList(),
    );
  }

  /// Returns a confirmed copy.
  ReceiptSession asConfirmed() {
    return ReceiptSession(
      id: id,
      status: 'confirmed',
      photoCount: photoCount,
      confirmedAt: DateTime.now(),
      createdAt: createdAt,
      items: items,
    );
  }
}
