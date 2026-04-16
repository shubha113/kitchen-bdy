enum MealType { breakfast, lunch, dinner, allDay }

extension MealTypeExt on MealType {
  String get value {
    switch (this) {
      case MealType.breakfast:
        return 'breakfast';
      case MealType.lunch:
        return 'lunch';
      case MealType.dinner:
        return 'dinner';
      case MealType.allDay:
        return 'all-day';
    }
  }

  String get label {
    switch (this) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
      case MealType.allDay:
        return 'All Day';
    }
  }

  String get emoji {
    switch (this) {
      case MealType.breakfast:
        return '🌅';
      case MealType.lunch:
        return '☀️';
      case MealType.dinner:
        return '🌙';
      case MealType.allDay:
        return '🍽️';
    }
  }

  static MealType fromString(String s) {
    switch (s.trim().toLowerCase()) {
      case 'breakfast':
        return MealType.breakfast;
      case 'lunch':
        return MealType.lunch;
      case 'dinner':
        return MealType.dinner;
      default:
        return MealType.allDay;
    }
  }
}

class GeminiIngredient {
  final String name;
  final String quantity;
  final bool inUserInventory;

  GeminiIngredient({
    required this.name,
    required this.quantity,
    required this.inUserInventory,
  });

  factory GeminiIngredient.fromJson(Map<String, dynamic> json) {
    return GeminiIngredient(
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? '',
      inUserInventory: json['inUserInventory'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'inUserInventory': inUserInventory,
  };
}

class GeminiRecipe {
  final String name;
  final String description;
  final String cuisine;
  final String mealType;
  final String prepTime;
  final String cookTime;
  final bool healthy;
  final int servings;
  final List<GeminiIngredient> ingredients;
  final List<String> missingIngredients;
  final List<String> steps;
  final String? source;

  GeminiRecipe({
    required this.name,
    required this.description,
    required this.cuisine,
    required this.mealType,
    required this.prepTime,
    required this.cookTime,
    required this.healthy,
    required this.servings,
    required this.ingredients,
    required this.missingIngredients,
    required this.steps,
    this.source,
  });

  factory GeminiRecipe.fromJson(Map<String, dynamic> json) {
    return GeminiRecipe(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      cuisine: json['cuisine'] ?? '',
      mealType: json['mealType'] ?? '',
      prepTime: json['prepTime'] ?? '',
      cookTime: json['cookTime'] ?? '',
      healthy: json['healthy'] ?? false,
      servings: json['servings'] ?? 1,
      ingredients: (json['ingredients'] as List<dynamic>? ?? [])
          .map((e) => GeminiIngredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      missingIngredients: List<String>.from(
        json['missingIngredients'] as List? ?? [],
      ),
      steps: List<String>.from(json['steps'] as List? ?? []),
      source: json['source'],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'cuisine': cuisine,
    'mealType': mealType,
    'prepTime': prepTime,
    'cookTime': cookTime,
    'healthy': healthy,
    'servings': servings,
    'ingredients': ingredients.map((e) => e.toJson()).toList(),
    'missingIngredients': missingIngredients,
    'steps': steps,
    if (source != null) 'source': source,
  };
}

class ScheduledMealRecipe {
  final int id;
  final GeminiRecipe recipe;
  final List<String> missingIngredients;

  ScheduledMealRecipe({
    required this.id,
    required this.recipe,
    required this.missingIngredients,
  });

  factory ScheduledMealRecipe.fromJson(Map<String, dynamic> json) {
    return ScheduledMealRecipe(
      id: json['id'] ?? 0,
      recipe: GeminiRecipe.fromJson(json['recipe'] as Map<String, dynamic>),
      missingIngredients: List<String>.from(
        json['missingIngredients'] as List? ?? [],
      ),
    );
  }
}

class ScheduledMeal {
  final int id;
  final int userId;
  final DateTime scheduledAt;
  final String mealType;
  final String cuisine;
  final bool healthy;
  final int servings;
  final String? eventLabel;
  final bool notificationFired;
  final List<ScheduledMealRecipe> recipes;
  final DateTime createdAt;

  ScheduledMeal({
    required this.id,
    required this.userId,
    required this.scheduledAt,
    required this.mealType,
    required this.cuisine,
    required this.healthy,
    required this.servings,
    this.eventLabel,
    required this.notificationFired,
    required this.recipes,
    required this.createdAt,
  });

  /// Splits "breakfast & dinner" → "Breakfast + Dinner"
  String get mealTypeLabel {
    return mealType
        .split(RegExp(r'[&,]+'))
        .map((s) => MealTypeExt.fromString(s.trim()).label)
        .where((s) => s.isNotEmpty)
        .join(' + ');
  }

  /// Returns the emoji of the first meal type in the string
  String get mealTypeEmoji {
    final first = mealType.split(RegExp(r'[&,]+')).first.trim();
    return MealTypeExt.fromString(first).emoji;
  }

  String get displayTitle =>
      eventLabel?.isNotEmpty == true ? eventLabel! : '$mealTypeLabel Event';

  int get totalMissingCount =>
      recipes.fold(0, (sum, r) => sum + r.missingIngredients.length);

  factory ScheduledMeal.fromJson(Map<String, dynamic> json) {
    return ScheduledMeal(
      id: json['id'] ?? 0,
      userId: json['userId'] ?? 0,
      scheduledAt: DateTime.parse(json['scheduledAt']).toLocal(),
      mealType: json['mealType'] ?? '',
      cuisine: json['cuisine'] ?? '',
      healthy: json['healthy'] ?? false,
      servings: json['servings'] ?? 1,
      eventLabel: json['eventLabel'],
      notificationFired: json['notificationFired'] ?? false,
      recipes: (json['recipes'] as List<dynamic>? ?? [])
          .map((e) => ScheduledMealRecipe.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ).toLocal(),
    );
  }
}
