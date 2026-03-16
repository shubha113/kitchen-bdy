enum AlertType {
  lowStock,
  deviceOffline,
  deviceLowBattery,
  refillReminder,
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

  AppAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.deviceId,
    this.itemName,
  });

  String get typeLabel {
    switch (type) {
      case AlertType.lowStock:
        return 'LOW STOCK';
      case AlertType.deviceOffline:
        return 'DEVICE OFFLINE';
      case AlertType.deviceLowBattery:
        return 'LOW BATTERY';
      case AlertType.refillReminder:
        return 'REFILL';
      case AlertType.info:
        return 'INFO';
    }
  }
}
