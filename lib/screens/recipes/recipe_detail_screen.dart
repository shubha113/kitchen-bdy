import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/recipe.dart';

class RecipeDetailScreen extends StatelessWidget {
  final Recipe recipe;
  final Map<String, double> inventory;

  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    required this.inventory,
  });

  @override
  Widget build(BuildContext context) {
    final score = recipe.availabilityScore(inventory);
    final canMake = score == 1.0;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.bgPrimary,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_back_ios,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      canMake ? AppColors.successDim : const Color(0xFF1A1500),
                      AppColors.bgPrimary,
                    ],
                  ),
                ),
                child: Center(
                  child: Text(
                    recipe.imageEmoji,
                    style: const TextStyle(fontSize: 80),
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Title & Meta
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        recipe.name,
                        style: AppTextStyles.displaySmall,
                      ),
                    ),
                    if (canMake)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.successDim,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'READY TO COOK',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.success,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  recipe.description,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),

                // Quick stats
                Row(
                  children: [
                    _MetaChip(
                      icon: Icons.timer_outlined,
                      label: '${recipe.cookTimeMinutes} min',
                    ),
                    const SizedBox(width: 8),
                    _MetaChip(
                      icon: Icons.people_outline,
                      label: '${recipe.servings} servings',
                    ),
                    const SizedBox(width: 8),
                    _MetaChip(icon: Icons.bar_chart, label: recipe.difficulty),
                    const SizedBox(width: 8),
                    _MetaChip(
                      icon: Icons.restaurant_menu,
                      label: recipe.category,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Availability bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'INGREDIENT AVAILABILITY',
                            style: AppTextStyles.goldLabel,
                          ),
                          const Spacer(),
                          Text(
                            '${(score * 100).round()}%',
                            style: AppTextStyles.headingSmall.copyWith(
                              color: canMake
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: score,
                          backgroundColor: AppColors.bgSurface,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            canMake ? AppColors.success : AppColors.warning,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Ingredients
                Text('INGREDIENTS', style: AppTextStyles.goldLabel),
                const SizedBox(height: 12),
                ...recipe.ingredients.map((ing) {
                  final avail = inventory[ing.name.toLowerCase()] ?? 0.0;
                  final hasEnough = avail >= ing.requiredAmount;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: hasEnough
                            ? AppColors.successDim
                            : AppColors.errorDim,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            hasEnough ? Icons.check_circle : Icons.cancel,
                            color: hasEnough
                                ? AppColors.success
                                : AppColors.error,
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              ing.name,
                              style: AppTextStyles.bodyMedium,
                            ),
                          ),
                          Text(
                            '${ing.requiredAmount.toStringAsFixed(0)} ${ing.unit}',
                            style: AppTextStyles.weightUnit.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '/ ${avail.toStringAsFixed(0)} ${ing.unit}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: hasEnough
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 24),

                // Steps
                Text('PREPARATION', style: AppTextStyles.goldLabel),
                const SizedBox(height: 12),
                ...List.generate(
                  recipe.steps.length,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            gradient: AppColors.goldGradient,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.textOnGold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              recipe.steps[i],
                              style: AppTextStyles.bodyMedium.copyWith(
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                if (canMake)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Start Cooking',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headingMedium.copyWith(
                        color: AppColors.textOnGold,
                      ),
                    ),
                  ),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.borderSubtle),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.goldPrimary),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 0,
          ),
        ),
      ],
    ),
  );
}
