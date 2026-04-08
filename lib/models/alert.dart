enum AlertType {
  lowStock,
  outOfStock,
  deviceOffline,
  deviceOnline,
  deviceLowBattery,
  sensorPlacement,
  refillReminder,
  receiptPending,
  receiptProcessed,
  mealReminder,
  info,
}

class AppAlert {
  final String id;
  final AlertType type;
  final String title;
  final String message;
  final DateTime timestamp;
  bool isRead;
  final String? deviceId;
  final String? itemName;
  final Map<String, String>? data;

  AppAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.deviceId,
    this.itemName,
    this.data,
  });

  String get typeLabel {
    switch (type) {
      case AlertType.lowStock:
        return 'LOW STOCK';
      case AlertType.outOfStock:
        return 'OUT OF STOCK';
      case AlertType.deviceOffline:
        return 'OFFLINE';
      case AlertType.deviceOnline:
        return 'BACK ONLINE';
      case AlertType.deviceLowBattery:
        return 'LOW BATTERY';
      case AlertType.sensorPlacement:
        return 'SCALE EVENT';
      case AlertType.refillReminder:
        return 'REMINDER';
      case AlertType.receiptPending:
        return 'RECEIPT';
      case AlertType.receiptProcessed:
        return 'RECEIPT';
      case AlertType.mealReminder:
        return 'MEAL REMINDER';
      case AlertType.info:
        return 'INFO';
    }
  }
}
