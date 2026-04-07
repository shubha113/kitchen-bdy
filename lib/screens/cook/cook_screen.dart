import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../providers/app_provider.dart';
import '../../services/auth_service.dart';
import '../../services/manual_inventory.dart';
import '../../utils/constant.dart';

const _cuisines = [
  'North Indian',
  'South Indian',
  'Punjabi',
  'Gujarati',
  'Bengali',
  'Italian',
  'Maxican',
  'Mughlai',
  'Indo-Chinese',
  'Street Food',
  'Biryani & Rice',
  'Dal & Curries',
  'Snacks & Starters',
  'Desserts & Sweets',
];

class CookScreen extends StatefulWidget {
  const CookScreen({super.key});
  @override
  State<CookScreen> createState() => _CookScreenState();
}

class _CookScreenState extends State<CookScreen> {
  String _cuisine = 'North Indian';
  int _servings = 1;
  bool _healthy = false;
  bool _loading = false;
  List<Map<String, dynamic>> _recipes = [];
  bool _hasSearched = false;
  String? _error;
  bool _formCollapsed = false;

  Future<void> _findRecipes() async {
    setState(() {
      _loading = true;
      _error = null;
      _recipes = [];
      _formCollapsed = false;
    });

    try {
      final prov = context.read<AppProvider>();
      final inventory = <Map<String, dynamic>>[];

      for (final d in prov.devices) {
        if (d.currentWeight > 0) {
          inventory.add({
            'name': d.name,
            'quantity': d.currentWeight,
            'unit': d.unit,
          });
        }
      }

      final manualItems = await ManualInventoryService.getUserInventory();
      for (final m in manualItems) {
        if (m.packsRemaining > 0) {
          inventory.add({
            'name': m.itemName,
            'quantity': m.packsRemaining,
            'unit': m.unit,
          });
        }
      }

      if (inventory.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No inventory found. Add items to your pantry first.';
          _hasSearched = true;
        });
        return;
      }

      final token = await ApiService.getToken();
      if (token == null) {
        setState(() {
          _loading = false;
          _error = 'Not logged in.';
        });
        return;
      }

      final res = await http.post(
        Uri.parse('${AppConstants.baseUrl}/cook/suggest'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'cuisine': _cuisine,
          'servings': _servings,
          'healthy': _healthy,
          'inventory': inventory,
        }),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final recipes = (data['recipes'] as List<dynamic>? ?? [])
            .map((r) => r as Map<String, dynamic>)
            .toList();
        setState(() {
          _recipes = recipes;
          _hasSearched = true;
          _formCollapsed = recipes.isNotEmpty;
        });
      } else {
        setState(() {
          _error = 'Could not get suggestions. Try again.';
          _hasSearched = true;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Something went wrong: $e';
        _hasSearched = true;
      });
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      backgroundColor: t.bgPrimary,
      appBar: AppBar(
        backgroundColor: t.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: t.textSecondary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'What Can I Cook?',
          style: AppTextStyles.headingLargeOf(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildForm(context, t),
            Expanded(child: _buildResults(context, t)),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, AppTheme t) {
    if (_formCollapsed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: t.bgCard,
          border: Border(bottom: BorderSide(color: t.borderSubtle)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _SummaryChip(
                    label: _cuisine,
                    color: AppColors.goldPrimary,
                    t: t,
                  ),
                  _SummaryChip(
                    label: '$_servings people',
                    color: t.textSecondary,
                    t: t,
                  ),
                  if (_healthy)
                    _SummaryChip(
                      label: '🌿 Healthy',
                      color: AppColors.success,
                      t: t,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => setState(() => _formCollapsed = false),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: t.goldDim,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.goldPrimary.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  'Change',
                  style: TextStyle(
                    color: AppColors.goldPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.bgCard,
        border: Border(bottom: BorderSide(color: t.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CUISINE', style: AppTextStyles.goldLabel),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _cuisine,
            dropdownColor: t.bgCardElevated,
            isExpanded: true,
            style: TextStyle(color: t.textPrimary, fontSize: 14),
            decoration: _inputDec(
              context,
              t,
              'Select cuisine',
              Icons.restaurant_outlined,
            ),
            items: _cuisines
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: _loading ? null : (v) => setState(() => _cuisine = v!),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              // Servings
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PEOPLE', style: AppTextStyles.goldLabel),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: t.bgSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: t.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _loading || _servings <= 1
                                ? null
                                : () => setState(() => _servings--),
                            child: SizedBox(
                              height: 39,
                              width: 39,
                              child: Icon(
                                Icons.remove,
                                size: 16,
                                color: t.textSecondary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                '$_servings',
                                style: TextStyle(
                                  color: t.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _loading || _servings >= 20
                                ? null
                                : () => setState(() => _servings++),
                            child: SizedBox(
                              height: 39,
                              width: 39,
                              child: Icon(
                                Icons.add,
                                size: 16,
                                color: AppColors.goldPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Healthy toggle
              // Replace the entire PREFERENCE column with this:
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PREFERENCE', style: AppTextStyles.goldLabel),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: t.bgSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: t.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          // ANY pill
                          Expanded(
                            child: GestureDetector(
                              onTap: _loading
                                  ? null
                                  : () => setState(() => _healthy = false),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: !_healthy
                                      ? t.bgCard
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: !_healthy
                                        ? t.borderMedium
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.tune_rounded,
                                      size: 13,
                                      color: !_healthy
                                          ? t.textPrimary
                                          : t.textMuted,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Any',
                                      style: TextStyle(
                                        color: !_healthy
                                            ? t.textPrimary
                                            : t.textMuted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // HEALTHY pill
                          Expanded(
                            child: GestureDetector(
                              onTap: _loading
                                  ? null
                                  : () => setState(() => _healthy = true),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: _healthy
                                      ? AppColors.success.withValues(
                                          alpha: 0.12,
                                        )
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _healthy
                                        ? AppColors.success.withValues(
                                            alpha: 0.4,
                                          )
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.eco_rounded,
                                      size: 13,
                                      color: _healthy
                                          ? AppColors.success
                                          : t.textMuted,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Healthy',
                                      style: TextStyle(
                                        color: _healthy
                                            ? AppColors.success
                                            : t.textMuted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.goldPrimary,
                foregroundColor: AppColors.textOnGold,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: _loading ? null : _findRecipes,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Find Recipes with My Ingredients',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context, AppTheme t) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.goldPrimary),
            const SizedBox(height: 20),
            Text(
              'Checking your pantry…',
              style: AppTextStyles.bodyMediumOf(context),
            ),
            const SizedBox(height: 8),
            Text(
              'Gemini is finding recipes for you',
              style: AppTextStyles.bodySmallOf(context),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: AppTextStyles.bodyMediumOf(context),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.restaurant_menu_outlined,
                color: t.textMuted,
                size: 64,
              ),
              const SizedBox(height: 20),
              Text(
                'Ready to Cook?',
                style: AppTextStyles.headingMediumOf(context),
              ),
              const SizedBox(height: 8),
              Text(
                'Pick a cuisine, number of people, and tap Find Recipes.\nWe\'ll check your pantry and suggest what you can make.',
                style: AppTextStyles.bodySmallOf(context),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_recipes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.no_food_outlined, color: t.textMuted, size: 48),
              const SizedBox(height: 16),
              Text(
                'Nothing found',
                style: AppTextStyles.headingMediumOf(context),
              ),
              const SizedBox(height: 8),
              Text(
                'Try a different cuisine or add more items to your pantry.',
                style: AppTextStyles.bodySmallOf(context),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _recipes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _RecipeCard(recipe: _recipes[i]),
    );
  }

  static InputDecoration _inputDec(
    BuildContext context,
    AppTheme t,
    String label,
    IconData icon,
  ) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: t.textSecondary, fontSize: 12),
    prefixIcon: Icon(icon, color: t.textSecondary, size: 18),
    filled: true,
    fillColor: t.bgSurface,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: t.borderSubtle),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.goldPrimary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  );
}

// ── Recipe Card ───────────────────────────────────────────────────────────────
class _RecipeCard extends StatefulWidget {
  final Map<String, dynamic> recipe;
  const _RecipeCard({required this.recipe});
  @override
  State<_RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<_RecipeCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final r = widget.recipe;
    final canMake = r['canMake'] as bool? ?? false;
    final healthy = r['healthy'] as bool? ?? false;
    final missing = (r['missingIngredients'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final ingredients = (r['ingredients'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
    final steps = (r['steps'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: t.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: canMake
              ? AppColors.success.withValues(alpha: 0.4)
              : t.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: canMake
                            ? AppColors.success.withValues(alpha: 0.12)
                            : t.warningDim,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: canMake
                              ? AppColors.success.withValues(alpha: 0.4)
                              : AppColors.warning.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            canMake
                                ? Icons.check_circle_outline
                                : Icons.warning_amber_outlined,
                            size: 11,
                            color: canMake
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            canMake ? 'Can Make' : 'Missing Items',
                            style: TextStyle(
                              color: canMake
                                  ? AppColors.success
                                  : AppColors.warning,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (healthy)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.eco, size: 11, color: AppColors.success),
                            SizedBox(width: 4),
                            Text(
                              'Healthy',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    Text(
                      '${r['prepTime'] ?? ''} + ${r['cookTime'] ?? ''}',
                      style: AppTextStyles.bodySmallOf(context),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  r['name'] as String? ?? '',
                  style: AppTextStyles.headingMediumOf(context),
                ),
                const SizedBox(height: 4),
                Text(
                  r['description'] as String? ?? '',
                  style: AppTextStyles.bodySmallOf(context),
                  maxLines: _expanded ? null : 2,
                  overflow: _expanded ? null : TextOverflow.ellipsis,
                ),
                if (missing.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: t.warningDim,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppColors.warning,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Short on: ${missing.join(', ')}',
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Expand / collapse
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: t.bgSurface,
                borderRadius: _expanded
                    ? BorderRadius.zero
                    : const BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _expanded ? 'Hide Details' : 'View Ingredients & Steps',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.goldPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.goldPrimary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),

          // Expanded details
          if (_expanded) ...[
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('INGREDIENTS', style: AppTextStyles.goldLabel),
                  const SizedBox(height: 8),
                  ...ingredients.map((ing) {
                    final sufficient = ing['sufficient'] as bool? ?? false;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(
                            sufficient
                                ? Icons.check_circle
                                : Icons.cancel_outlined,
                            size: 14,
                            color: sufficient
                                ? AppColors.success
                                : AppColors.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ing['name'] as String? ?? '',
                              style: AppTextStyles.bodySmallOf(context),
                            ),
                          ),
                          Text(
                            'Need ${ing['required'] ?? ''}',
                            style: AppTextStyles.bodySmallOf(
                              context,
                            ).copyWith(color: t.textMuted),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Have ${ing['available'] ?? ''}',
                            style: AppTextStyles.bodySmallOf(context).copyWith(
                              color: sufficient
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  if (steps.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('HOW TO COOK', style: AppTextStyles.goldLabel),
                    const SizedBox(height: 8),
                    ...steps.asMap().entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: t.goldDim,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${e.key + 1}',
                                  style: const TextStyle(
                                    color: AppColors.goldPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                e.value,
                                style: AppTextStyles.bodySmallOf(
                                  context,
                                ).copyWith(height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;
  final AppTheme t;
  const _SummaryChip({
    required this.label,
    required this.color,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
