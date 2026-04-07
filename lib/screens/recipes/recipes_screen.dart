import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';

class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      backgroundColor: t.bgPrimary,
      appBar: AppBar(
        backgroundColor: t.bgPrimary,
        elevation: 0,
        title: Text('Recipes', style: AppTextStyles.headingLargeOf(context)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: t.goldDim,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: t.borderGold, width: 1.2),
              ),
              child: const Center(
                child: Text('👨‍🍳', style: TextStyle(fontSize: 42)),
              ),
            ),
            const SizedBox(height: 24),
            Text('Coming Soon', style: AppTextStyles.displaySmallOf(context)),
            const SizedBox(height: 10),
            Text(
              'Smart recipes based on your\npantry are on the way.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMediumOf(
                context,
              ).copyWith(color: t.textSecondary, height: 1.6),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: t.goldDim,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: t.borderGold),
              ),
              child: Text('STAY TUNED', style: AppTextStyles.goldLabel),
            ),
          ],
        ),
      ),
    );
  }
}
