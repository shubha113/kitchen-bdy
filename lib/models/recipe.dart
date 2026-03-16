class RecipeIngredient {
  final String name;
  final double requiredAmount;
  final String unit;

  const RecipeIngredient({
    required this.name,
    required this.requiredAmount,
    required this.unit,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) =>
      RecipeIngredient(
        name: json['name'],
        requiredAmount: (json['required_amount'] as num).toDouble(),
        unit: json['unit'],
      );
}

class Recipe {
  final String id;
  final String name;
  final String description;
  final String category;
  final int cookTimeMinutes;
  final int servings;
  final String difficulty;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final String imageEmoji;

  const Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.cookTimeMinutes,
    required this.servings,
    required this.difficulty,
    required this.ingredients,
    required this.steps,
    this.imageEmoji = '🍽️',
  });

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
    id: json['id'],
    name: json['name'],
    description: json['description'],
    category: json['category'],
    cookTimeMinutes: json['cook_time_minutes'],
    servings: json['servings'],
    difficulty: json['difficulty'],
    ingredients: (json['ingredients'] as List)
        .map((e) => RecipeIngredient.fromJson(e))
        .toList(),
    steps: List<String>.from(json['steps']),
    imageEmoji: json['emoji'] ?? '🍽️',
  );

  /// How many ingredients are available in inventory (0.0–1.0)
  double availabilityScore(Map<String, double> inventory) {
    if (ingredients.isEmpty) return 0.0;
    int available = 0;
    for (final ing in ingredients) {
      final stock = inventory[ing.name.toLowerCase()] ?? 0.0;
      if (stock >= ing.requiredAmount) available++;
    }
    return available / ingredients.length;
  }

  bool canMake(Map<String, double> inventory) =>
      availabilityScore(inventory) == 1.0;

  List<RecipeIngredient> missingIngredients(Map<String, double> inventory) {
    return ingredients
        .where(
          (ing) =>
              (inventory[ing.name.toLowerCase()] ?? 0.0) < ing.requiredAmount,
        )
        .toList();
  }
}
