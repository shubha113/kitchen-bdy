class KitchenDevice {
  final String id;
  final String espId;
  final int slot;
  final String name;
  final String location;
  final String category;
  final String macAddress;
  final String unit;
  final double currentWeight;
  final double threshold;
  final double capacity;
  final bool isOnline;
  final DateTime lastUpdated;
  final double tareWeight;
  final int? linkedInventoryId;
  final String? linkedInventoryName;

  int get battery => 100;

  KitchenDevice({
    required this.id,
    this.espId = '',
    this.slot = 0,
    required this.name,
    this.location = '',
    this.category = 'Other',
    this.macAddress = '',
    this.unit = 'g',
    required this.currentWeight,
    this.threshold = 200.0,
    this.capacity = 5000.0,
    required this.isOnline,
    DateTime? lastUpdated,
    this.tareWeight = 0.0,
    this.linkedInventoryId,
    this.linkedInventoryName,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  // Net weight after subtracting container/jar weight
  double get netWeight =>
      (currentWeight - tareWeight).clamp(0.0, double.infinity);

  String get weightFormatted {
    if (currentWeight >= 1000)
      return '${(currentWeight / 1000).toStringAsFixed(2)} kg';
    return '${currentWeight.toStringAsFixed(1)} $unit';
  }

  String get netWeightFormatted {
    if (netWeight >= 1000) return '${(netWeight / 1000).toStringAsFixed(2)} kg';
    return '${netWeight.toStringAsFixed(1)} $unit';
  }

  bool get isLowStock => isOnline && currentWeight < threshold;
  bool get isCritical => isOnline && currentWeight < (threshold * 0.25);

  double get stockPercentage {
    if (capacity <= 0) return 0.0;
    return (currentWeight / capacity).clamp(0.0, 1.0);
  }

  String get stockLevel {
    if (!isOnline) return 'Offline';
    if (isCritical) return 'Critical';
    if (isLowStock) return 'Low';
    if (stockPercentage > 0.75) return 'Full';
    return 'Good';
  }

  KitchenDevice copyWith({
    String? id,
    String? espId,
    int? slot,
    String? name,
    String? location,
    String? category,
    String? macAddress,
    String? unit,
    double? currentWeight,
    double? threshold,
    double? capacity,
    bool? isOnline,
    DateTime? lastUpdated,
    double? tareWeight,
    int? linkedInventoryId,
    String? linkedInventoryName,
  }) => KitchenDevice(
    id: id ?? this.id,
    espId: espId ?? this.espId,
    slot: slot ?? this.slot,
    name: name ?? this.name,
    location: location ?? this.location,
    category: category ?? this.category,
    macAddress: macAddress ?? this.macAddress,
    unit: unit ?? this.unit,
    currentWeight: currentWeight ?? this.currentWeight,
    threshold: threshold ?? this.threshold,
    capacity: capacity ?? this.capacity,
    isOnline: isOnline ?? this.isOnline,
    lastUpdated: lastUpdated ?? this.lastUpdated,
    tareWeight: tareWeight ?? this.tareWeight,
    linkedInventoryId: linkedInventoryId ?? this.linkedInventoryId,
    linkedInventoryName: linkedInventoryName ?? this.linkedInventoryName,
  );

  factory KitchenDevice.fromJson(Map<String, dynamic> j) => KitchenDevice(
    id: j['id'] as String,
    espId: j['espId'] as String? ?? '',
    slot: j['slot'] as int? ?? 0,
    name: j['name'] as String,
    location: j['location'] as String? ?? '',
    category: j['category'] as String? ?? 'Other',
    macAddress: j['macAddress'] as String? ?? '',
    unit: j['unit'] as String? ?? 'g',
    currentWeight: (j['currentWeight'] as num?)?.toDouble() ?? 0.0,
    threshold: (j['threshold'] as num?)?.toDouble() ?? 200.0,
    capacity: (j['capacity'] as num?)?.toDouble() ?? 5000.0,
    isOnline: j['isOnline'] as bool? ?? false,
    tareWeight: (j['tareWeight'] as num?)?.toDouble() ?? 0.0,
    linkedInventoryId: j['linkedInventoryId'] as int?,
    linkedInventoryName: j['linkedInventoryName'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'espId': espId,
    'slot': slot,
    'name': name,
    'location': location,
    'category': category,
    'macAddress': macAddress,
    'unit': unit,
    'currentWeight': currentWeight,
    'threshold': threshold,
    'capacity': capacity,
    'isOnline': isOnline,
    'lastUpdated': lastUpdated.toIso8601String(),
    'tareWeight': tareWeight,
    'linkedInventoryId': linkedInventoryId,
    'linkedInventoryName': linkedInventoryName,
  };
}
