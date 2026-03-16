import '../models/device.dart';
import '../models/alert.dart';

// ── Devices: empty — real devices appear automatically from MQTT ──────────────
final List<Map<String, dynamic>> kMockDevicesJson = [];

// ── Recipes ───────────────────────────────────────────────────────────────────
final List<Map<String, dynamic>> kMockRecipesJson = [
  {
    "id": "R001", "name": "Saffron Basmati Rice",
    "description": "Fragrant basmati rice slow-cooked with whole spices and a touch of saffron.",
    "category": "Main Course", "cook_time_minutes": 30, "servings": 4, "difficulty": "Easy", "emoji": "🍚",
    "ingredients": [
      {"name": "basmati rice", "required_amount": 400.0, "unit": "g"},
      {"name": "sea salt", "required_amount": 10.0, "unit": "g"},
      {"name": "extra virgin olive oil", "required_amount": 30.0, "unit": "ml"},
    ],
    "steps": ["Soak basmati rice for 30 minutes, then drain.", "Heat olive oil in a heavy-bottomed pan over medium heat.", "Add salt and 600ml water. Bring to boil.", "Add rice, reduce heat, cover and cook for 18 minutes.", "Fluff with a fork and serve garnished with fresh herbs."],
  },
  {
    "id": "R002", "name": "Masoor Dal",
    "description": "Velvety red lentil dal with aromatic spices — a comforting classic.",
    "category": "Main Course", "cook_time_minutes": 35, "servings": 4, "difficulty": "Easy", "emoji": "🫕",
    "ingredients": [
      {"name": "red lentils", "required_amount": 300.0, "unit": "g"},
      {"name": "sea salt", "required_amount": 8.0, "unit": "g"},
      {"name": "black pepper", "required_amount": 5.0, "unit": "g"},
      {"name": "extra virgin olive oil", "required_amount": 20.0, "unit": "ml"},
    ],
    "steps": ["Rinse lentils until water runs clear.", "Boil in 700ml water for 20 minutes until soft.", "In a separate pan, heat oil and bloom the spices.", "Add lentils to the spiced oil. Season with salt.", "Simmer for 10 more minutes. Serve with rice or bread."],
  },
  {
    "id": "R003", "name": "Classic Milk Porridge",
    "description": "Creamy, nourishing porridge with warm spices — a morning luxury.",
    "category": "Breakfast", "cook_time_minutes": 15, "servings": 2, "difficulty": "Easy", "emoji": "🥣",
    "ingredients": [
      {"name": "all-purpose flour", "required_amount": 60.0, "unit": "g"},
      {"name": "whole milk", "required_amount": 400.0, "unit": "ml"},
      {"name": "sea salt", "required_amount": 2.0, "unit": "g"},
    ],
    "steps": ["Whisk flour into cold milk until smooth.", "Pour into saucepan over medium heat.", "Stir continuously until thick and creamy, ~10 minutes.", "Season with pinch of salt. Top with honey and berries."],
  },
  {
    "id": "R004", "name": "Herbed Flatbread",
    "description": "Rustic, golden flatbread brushed with olive oil and sea salt.",
    "category": "Bread", "cook_time_minutes": 25, "servings": 6, "difficulty": "Medium", "emoji": "🫓",
    "ingredients": [
      {"name": "all-purpose flour", "required_amount": 300.0, "unit": "g"},
      {"name": "sea salt", "required_amount": 6.0, "unit": "g"},
      {"name": "extra virgin olive oil", "required_amount": 40.0, "unit": "ml"},
    ],
    "steps": ["Mix flour and salt in a large bowl.", "Add 150ml warm water and 2 tbsp olive oil. Knead 8 minutes.", "Rest dough 15 minutes covered.", "Divide into 6 balls, roll thin.", "Cook on hot cast-iron for 2 min each side. Brush with remaining oil."],
  },
  {
    "id": "R005", "name": "Green Tea Latte",
    "description": "Frothy, warming green tea steamed with whole milk and a hint of honey.",
    "category": "Beverage", "cook_time_minutes": 5, "servings": 1, "difficulty": "Easy", "emoji": "🍵",
    "ingredients": [
      {"name": "green tea", "required_amount": 5.0, "unit": "g"},
      {"name": "whole milk", "required_amount": 200.0, "unit": "ml"},
    ],
    "steps": ["Steep green tea in 50ml hot (80°C) water for 2 minutes.", "Steam or froth milk until velvety.", "Pour milk over tea. Sweeten with honey if desired."],
  },
  {
    "id": "R006", "name": "Spiced Black Pepper Soup",
    "description": "Bold, warming broth with cracked black pepper and aromatic herbs.",
    "category": "Soup", "cook_time_minutes": 20, "servings": 2, "difficulty": "Easy", "emoji": "🥣",
    "ingredients": [
      {"name": "black pepper", "required_amount": 10.0, "unit": "g"},
      {"name": "sea salt", "required_amount": 5.0, "unit": "g"},
      {"name": "extra virgin olive oil", "required_amount": 15.0, "unit": "ml"},
    ],
    "steps": ["Heat olive oil in a pot, add coarsely cracked pepper.", "Add 500ml stock or water, bring to a simmer.", "Season with salt. Add vegetables of choice.", "Simmer 15 minutes. Serve with crusty bread."],
  },
];

// ── Grocery Items ─────────────────────────────────────────────────────────────
final List<Map<String, dynamic>> kMockGroceryJson = [
  {"id": "G001", "name": "Basmati Rice",           "category": "Grains",    "quantity": 5000, "unit": "g",  "threshold": 500, "price": 8.99},
  {"id": "G002", "name": "All-Purpose Flour",      "category": "Grains",    "quantity": 2000, "unit": "g",  "threshold": 400, "price": 3.49},
  {"id": "G003", "name": "Extra Virgin Olive Oil", "category": "Oils",      "quantity": 1000, "unit": "ml", "threshold": 200, "price": 12.99},
  {"id": "G004", "name": "Sea Salt",               "category": "Spices",    "quantity": 500,  "unit": "g",  "threshold": 100, "price": 2.49},
  {"id": "G005", "name": "Black Pepper",           "category": "Spices",    "quantity": 250,  "unit": "g",  "threshold": 50,  "price": 4.99},
  {"id": "G006", "name": "Red Lentils",            "category": "Pulses",    "quantity": 2000, "unit": "g",  "threshold": 300, "price": 3.99},
  {"id": "G007", "name": "Whole Milk",             "category": "Dairy",     "quantity": 2000, "unit": "ml", "threshold": 500, "price": 2.19},
  {"id": "G008", "name": "Green Tea",              "category": "Beverages", "quantity": 100,  "unit": "g",  "threshold": 80,  "price": 6.49},
];

// ── Alerts — built from real device state ─────────────────────────────────────
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
    // ESP32 scales are mains-powered — no battery alert needed
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