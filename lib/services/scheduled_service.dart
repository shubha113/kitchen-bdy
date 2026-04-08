import 'dart:convert';
import 'package:app/models/schedule.dart';
import 'package:app/utils/constant.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class ScheduledMealsService {
  static Future<Map<String, String>> get _headers async {
    return await ApiService.authHeaders();
  }

  // Get suggestions
  static Future<List<GeminiRecipe>> suggest({
    required String cuisine,
    required int servings,
    required bool healthy,
    required String mealType,
    required int limit,
  }) async {
    final uri = Uri.parse(
      '${AppConstants.baseUrl}${AppConstants.scheduledMealsSuggest}',
    );

    final response = await http
        .post(
          uri,
          headers: await _headers,
          body: jsonEncode({
            'cuisine': cuisine,
            'servings': servings,
            'healthy': healthy,
            'mealType': mealType,
            'limit': limit,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode == 200 || response.statusCode == 201) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => GeminiRecipe.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw Exception(
      'Failed to get suggestions: ${response.statusCode} ${response.body}',
    );
  }

  // Save the scheduled meal
  static Future<ScheduledMeal> create({
    required DateTime scheduledAt,
    required String mealType,
    required String cuisine,
    required bool healthy,
    required int servings,
    String? eventLabel,
    required List<GeminiRecipe> chosenRecipes,
  }) async {
    final uri = Uri.parse(
      '${AppConstants.baseUrl}${AppConstants.scheduledMeals}',
    );

    final body = {
      'scheduledAt': scheduledAt.toIso8601String(),
      'mealType': mealType,
      'cuisine': cuisine,
      'healthy': healthy,
      'servings': servings,
      if (eventLabel != null && eventLabel.isNotEmpty) 'eventLabel': eventLabel,
      'chosenRecipes': chosenRecipes
          .map(
            (r) => {
              'recipe': r.toJson(),
              'missingIngredients': r.missingIngredients,
            },
          )
          .toList(),
    };

    final response = await http
        .post(uri, headers: await _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return ScheduledMeal.fromJson(jsonDecode(response.body));
    }

    throw Exception(
      'Failed to save meal: ${response.statusCode} ${response.body}',
    );
  }

  // Fetch all
  static Future<List<ScheduledMeal>> fetchAll() async {
    final uri = Uri.parse(
      '${AppConstants.baseUrl}${AppConstants.scheduledMeals}',
    );

    final response = await http
        .get(uri, headers: await _headers)
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => ScheduledMeal.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw Exception('Failed to fetch meals: ${response.statusCode}');
  }

  // Fetch single — used after reschedule or to refresh a card
  static Future<ScheduledMeal> fetchOne(int id) async {
    final uri = Uri.parse(
      '${AppConstants.baseUrl}${AppConstants.scheduledMealSingle(id)}',
    );

    final response = await http
        .get(uri, headers: await _headers)
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      return ScheduledMeal.fromJson(jsonDecode(response.body));
    }

    throw Exception('Failed to fetch meal: ${response.statusCode}');
  }

  // Update remaining missing ingredients for a recipe
  static Future<void> updateMissingIngredients({
    required int recipeId,
    required List<String> remaining,
  }) async {
    final uri = Uri.parse(
      '${AppConstants.baseUrl}${AppConstants.scheduledMealRecipeMissing(recipeId)}',
    );

    final response = await http
        .patch(
          uri,
          headers: await _headers,
          body: jsonEncode({'remaining': remaining}),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Failed to update shopping list: ${response.statusCode} ${response.body}',
      );
    }
  }

  // Delete
  static Future<void> delete(int id) async {
    final uri = Uri.parse(
      '${AppConstants.baseUrl}${AppConstants.scheduledMealDelete(id)}',
    );

    final response = await http
        .delete(uri, headers: await _headers)
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete meal: ${response.statusCode}');
    }
  }

  // Reschedule
  static Future<ScheduledMeal> reschedule(
    int id,
    DateTime newScheduledAt,
  ) async {
    final uri = Uri.parse(
      '${AppConstants.baseUrl}${AppConstants.scheduledMealReschedule(id)}',
    );

    final response = await http
        .patch(
          uri,
          headers: await _headers,
          body: jsonEncode({'scheduledAt': newScheduledAt.toIso8601String()}),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      return ScheduledMeal.fromJson(jsonDecode(response.body));
    }

    throw Exception('Failed to reschedule: ${response.statusCode}');
  }
}
