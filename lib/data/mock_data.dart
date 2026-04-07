import '../models/device.dart';
import '../models/alert.dart';

// Alerts — built from real device state
List<AppAlert> buildMockAlerts(List<KitchenDevice> devices) {
  final List<AppAlert> alerts = [];
  int i = 0;
  for (final d in devices) {
    if (!d.isOnline) {
      alerts.add(AppAlert(
        id: 'ALT_${i++}', type: AlertType.deviceOffline,
        title: '${d.name} is offline',
        message: 'Lost connection to "${d.name}". Last seen ${_timeAgo(d.lastUpdated)}.',
        timestamp: d.lastUpdated, deviceId: d.id, itemName: d.name,
      ));
    }
    if (d.isLowStock) {
      alerts.add(AppAlert(
        id: 'ALT_${i++}', type: AlertType.lowStock,
        title: '${d.name} running low',
        message: 'Current stock: ${d.weightFormatted}. Threshold: ${d.threshold.toStringAsFixed(0)} ${d.unit}.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        deviceId: d.id, itemName: d.name,
      ));
    }
  }
  alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return alerts;
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inHours > 24) return '${diff.inDays}d ago';
  if (diff.inMinutes > 60) return '${diff.inHours}h ago';
  return '${diff.inMinutes}m ago';
}

// Parsed Bill Sample
final Map<String, dynamic> kSampleParsedBill = {
  "bill_date": "2025-03-08", "store": "Organic Market", "total": 45.63,
  "items": [
    {"name": "Basmati Rice",      "category": "Grains",    "quantity": 5000, "unit": "g",  "price": 8.99},
    {"name": "Green Tea",         "category": "Beverages", "quantity": 100,  "unit": "g",  "price": 6.49},
    {"name": "Whole Milk",        "category": "Dairy",     "quantity": 2000, "unit": "ml", "price": 4.38},
    {"name": "All-Purpose Flour", "category": "Grains",    "quantity": 2000, "unit": "g",  "price": 3.49},
    {"name": "Sea Salt",          "category": "Spices",    "quantity": 500,  "unit": "g",  "price": 2.49},
  ],
};