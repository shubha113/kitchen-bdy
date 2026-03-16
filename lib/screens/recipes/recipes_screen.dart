import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/recipe.dart';
import '../../providers/app_provider.dart';
import 'recipe_detail_screen.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});
  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final inv = prov.inventoryMap;
    final all = prov.recipes;
    final canMake = all.where((r) => r.canMake(inv)).toList();
    final almost = all
        .where((r) => !r.canMake(inv) && r.availabilityScore(inv) >= 0.5)
        .toList();
    final missing = all.where((r) => r.availabilityScore(inv) < 0.5).toList();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        title: Text('Recipes', style: AppTextStyles.headingLarge),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.goldPrimary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.goldPrimary,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: AppTextStyles.labelMedium.copyWith(letterSpacing: 0.5),
          tabs: [
            Tab(text: 'Ready (${canMake.length})'),
            Tab(text: 'Almost (${almost.length})'),
            Tab(text: 'Missing (${missing.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _RecipeList(recipes: canMake, inventory: inv, canMake: true),
          _RecipeList(recipes: almost, inventory: inv, canMake: false),
          _RecipeList(recipes: missing, inventory: inv, canMake: false),
        ],
      ),
    );
  }
}

class _RecipeList extends StatelessWidget {
  final List<Recipe> recipes;
  final Map<String, double> inventory;
  final bool canMake;

  const _RecipeList({
    required this.recipes,
    required this.inventory,
    required this.canMake,
  });

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(canMake ? '🍽️' : '🛒', style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              canMake ? 'No recipes ready yet' : 'Stock up to unlock recipes',
              style: AppTextStyles.headingMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: recipes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (ctx, i) => _RecipeCard(
        recipe: recipes[i],
        inventory: inventory,
        onTap: () => Navigator.push(
          ctx,
          MaterialPageRoute(
            builder: (_) =>
                RecipeDetailScreen(recipe: recipes[i], inventory: inventory),
          ),
        ),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final Map<String, double> inventory;
  final VoidCallback onTap;

  const _RecipeCard({
    required this.recipe,
    required this.inventory,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final score = recipe.availabilityScore(inventory);
    final canMake = score == 1.0;
    final missing = recipe.missingIngredients(inventory);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: canMake
                ? AppColors.success.withValues(alpha: 0.3)
                : AppColors.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            // Emoji
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: canMake
                    ? AppColors.successDim
                    : AppColors.bgCardElevated,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  recipe.imageEmoji,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          recipe.name,
                          style: AppTextStyles.headingSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (canMake)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.successDim,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'READY',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.success,
                              fontSize: 9,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 11,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${recipe.cookTimeMinutes} min',
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.people_outline,
                        size: 11,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${recipe.servings} servings',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Availability progress
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: score,
                            backgroundColor: AppColors.bgSurface,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              canMake
                                  ? AppColors.success
                                  : score > 0.5
                                  ? AppColors.warning
                                  : AppColors.error,
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(score * 100).round()}%',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: canMake
                              ? AppColors.success
                              : score > 0.5
                              ? AppColors.warning
                              : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  if (!canMake && missing.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Missing: ${missing.map((m) => m.name).take(2).join(', ')}${missing.length > 2 ? ' +${missing.length - 2}' : ''}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
