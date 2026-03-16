class GroceryItem {
  final String id;
  String name;
  String category;
  double quantity;
  String unit;
  double threshold;
  DateTime? purchaseDate;
  double? price;

  GroceryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    this.threshold = 200,
    this.purchaseDate,
    this.price,
  });

  factory GroceryItem.fromJson(Map<String, dynamic> json) => GroceryItem(
    id: json['id'],
    name: json['name'],
    category: json['category'],
    quantity: (json['quantity'] as num).toDouble(),
    unit: json['unit'],
    threshold: (json['threshold'] as num?)?.toDouble() ?? 200,
    price: (json['price'] as num?)?.toDouble(),
  );
}
