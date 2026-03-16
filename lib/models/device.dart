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
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  // Computed getters

  /// "36.2 g"  or  "1.500 kg"
  String get weightFormatted {
    if (currentWeight >= 1000) {
      return '${(currentWeight / 1000).toStringAsFixed(2)} kg';
    }
    return '${currentWeight.toStringAsFixed(1)} $unit';
  }

  /// True when weight is below low-stock threshold
  bool get isLowStock => isOnline && currentWeight < threshold;

  /// True when critically low (< 25 % of threshold)
  bool get isCritical => isOnline && currentWeight < (threshold * 0.25);

  /// 0.0 – 1.0 based on capacity
  double get stockPercentage {
    if (capacity <= 0) return 0.0;
    return (currentWeight / capacity).clamp(0.0, 1.0);
  }

  /// Human-readable label
  String get stockLevel {
    if (!isOnline) return 'Offline';
    if (isCritical) return 'Critical';
    if (isLowStock) return 'Low';
    if (stockPercentage > 0.75) return 'Full';
    return 'Good';
  }

  // copyWith
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
  };
}
