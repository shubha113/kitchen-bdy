import 'package:app/services/scheduled_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/schedule.dart';

// Ingredient categorisation helpers

const _kCatKeywords = <String, List<String>>{
  'Dairy': [
    'milk',
    'cream',
    'butter',
    'cheese',
    'paneer',
    'curd',
    'yogurt',
    'ghee',
    'dahi',
    'khoya',
    'malai',
    'mawa',
    'condensed milk',
  ],
  'Grains': [
    'rice',
    'wheat',
    'oats',
    'corn',
    'barley',
    'semolina',
    'rava',
    'poha',
    'quinoa',
    'millet',
    'bajra',
    'jowar',
    'daliya',
  ],
  'Spices': [
    'cumin',
    'turmeric',
    'coriander',
    'cardamom',
    'clove',
    'pepper',
    'chili',
    'chilli',
    'masala',
    'garam',
    'fennel',
    'fenugreek',
    'methi',
    'hing',
    'asafoetida',
    'bay leaf',
    'cinnamon',
    'saffron',
    'nutmeg',
    'paprika',
    'mustard seed',
    'ajwain',
    'carom',
    'star anise',
    'amchur',
    'kala namak',
    'dry ginger',
    'kasuri',
  ],
  'Oils': ['oil', 'vanaspati', 'Refined oil', 'Sunflower oil', 'Mustard oil'],
  'Pulses': [
    'dal',
    'lentil',
    'chickpea',
    'chana',
    'rajma',
    'kidney',
    'moong',
    'urad',
    'toor',
    'masoor',
    'pea',
    'bean',
    'soybean',
    'lobiya',
    'moth',
  ],
  'Beverages': [
    'tea',
    'coffee',
    'juice',
    'cold drink',
    'chai',
    'lassi',
    'sharbat',
    'Roohafja',
  ],
  'Flour': [
    'flour',
    'maida',
    'besan',
    'atta',
    'suji',
    'cornflour',
    'starch',
    'breadcrumb',
    'bread crumb',
    'gram flour',
    'rice flour',
  ],
  'Sugar': [
    'sugar',
    'jaggery',
    'honey',
    'molasses',
    'gur',
    'mishri',
    'brown sugar',
    'icing sugar',
    'powdered sugar',
  ],
  'Snacks': ['chips', 'biscuit', 'cracker', 'namkeen', 'papad', 'murmura'],
};

const _kCatEmojis = <String, String>{
  'Dairy': '🥛',
  'Grains': '🌾',
  'Spices': '🌶️',
  'Oils': '🫙',
  'Pulses': '🫘',
  'Beverages': '☕',
  'Flour': '🫓',
  'Sugar': '🍯',
  'Snacks': '🍿',
  'Other': '📦',
};

Map<String, List<String>> _categorizeMissing(List<String> items) {
  final map = <String, List<String>>{};
  for (final item in items) {
    final lower = item.toLowerCase();
    String cat = 'Other';
    outer:
    for (final entry in _kCatKeywords.entries) {
      for (final kw in entry.value) {
        if (lower.contains(kw)) {
          cat = entry.key;
          break outer;
        }
      }
    }
    map.putIfAbsent(cat, () => []).add(item);
  }
  final result = <String, List<String>>{};
  for (final k in (map.keys.where((k) => k != 'Other').toList()..sort())) {
    result[k] = map[k]!;
  }
  if (map.containsKey('Other')) result['Other'] = map['Other']!;
  return result;
}

// Entry screen

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  List<ScheduledMeal> _meals = [];
  bool _loading = true;
  String? _error;

  // Live missing totals per meal id — updated instantly when user marks items done
  final Map<int, int> _liveTotals = {};

  void _onMealMissingChanged(int mealId, int newTotal) {
    setState(() => _liveTotals[mealId] = newTotal);
  }

  int _liveTotalFor(ScheduledMeal meal) =>
      _liveTotals[meal.id] ??
      meal.recipes.fold(0, (s, r) => s + r.missingIngredients.length);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final meals = await ScheduledMealsService.fetchAll();
      if (mounted) {
        setState(() {
          _meals = meals;
          _liveTotals.clear();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(ScheduledMeal meal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDeleteDialog(meal: meal),
    );
    if (confirmed != true) return;

    try {
      await ScheduledMealsService.delete(meal.id);
      setState(() {
        _meals.removeWhere((m) => m.id == meal.id);
        _liveTotals.remove(meal.id);
      });
      if (mounted) _showSnack('Event deleted', isError: false);
    } catch (e) {
      if (mounted) _showSnack('Failed to delete: $e', isError: true);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isError ? AppColors.error : AppColors.textPrimary,
          ),
        ),
        backgroundColor: isError
            ? AppColors.errorDim
            : AppColors.bgCardElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _openScheduleSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScheduleBottomSheet(
        onSaved: (meal) {
          setState(() => _meals.insert(0, meal));
          _showSnack('Meal scheduled! 🎉', isError: false);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);

    return Scaffold(
      backgroundColor: t.bgPrimary,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: t.bgPrimary,
            elevation: 0,
            title: Text(
              'Scheduled Meals',
              style: AppTextStyles.headingLargeOf(context),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 32),
                      backgroundColor: AppColors.goldPrimary,
                      foregroundColor: Colors.black,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _openScheduleSheet,
                    child: const Text('+ Schedule'),
                  ),
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),
                if (_loading)
                  const _LoadingState()
                else if (_error != null)
                  _ErrorState(error: _error!, onRetry: _load)
                else if (_meals.isEmpty)
                  _EmptyState(onTap: _openScheduleSheet)
                else ...[
                  _SummaryBar(
                    meals: _meals,
                    liveTotalMissing: _meals.fold(
                      0,
                      (s, m) => s + _liveTotalFor(m),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ..._meals.map(
                    (meal) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _MealCard(
                        meal: meal,
                        onDelete: () => _delete(meal),
                        onMissingChanged: (newTotal) =>
                            _onMealMissingChanged(meal.id, newTotal),
                        onRescheduled: (updated) {
                          setState(() {
                            final idx = _meals.indexWhere(
                              (m) => m.id == updated.id,
                            );
                            if (idx != -1) _meals[idx] = updated;
                          });
                        },
                        onRefresh: () async {
                          try {
                            final fresh = await ScheduledMealsService.fetchOne(
                              meal.id,
                            );
                            if (mounted) {
                              setState(() {
                                final idx = _meals.indexWhere(
                                  (m) => m.id == fresh.id,
                                );
                                if (idx != -1) _meals[idx] = fresh;
                              });
                            }
                          } catch (_) {}
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// Summary bar

class _SummaryBar extends StatelessWidget {
  final List<ScheduledMeal> meals;
  final int liveTotalMissing;

  const _SummaryBar({required this.meals, required this.liveTotalMissing});

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final upcoming = meals
        .where((m) => m.scheduledAt.isAfter(DateTime.now()))
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.borderSubtle),
      ),
      child: Row(
        children: [
          _StatCell('Scheduled', '${meals.length}', t.textPrimary),
          _vDivider(t),
          _StatCell('Upcoming', '$upcoming', AppColors.goldPrimary),
          _vDivider(t),
          _StatCell(
            'To Buy',
            '$liveTotalMissing',
            liveTotalMissing > 0 ? AppColors.warning : AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _vDivider(AppTheme t) => Container(
    width: 1,
    height: 28,
    color: t.borderSubtle,
    margin: const EdgeInsets.symmetric(horizontal: 12),
  );
}

class _StatCell extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatCell(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: AppTextStyles.headingMediumOf(context).copyWith(color: color),
        ),
        Text(label, style: AppTextStyles.labelSmallOf(context)),
      ],
    ),
  );
}

// Meal card

class _MealCard extends StatefulWidget {
  final ScheduledMeal meal;
  final VoidCallback onDelete;
  final void Function(ScheduledMeal) onRescheduled;
  final Future<void> Function() onRefresh;
  final void Function(int newTotal) onMissingChanged;

  const _MealCard({
    required this.meal,
    required this.onDelete,
    required this.onRescheduled,
    required this.onRefresh,
    required this.onMissingChanged,
  });

  @override
  State<_MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<_MealCard> {
  bool _expanded = false;

  // Live missing counts per recipe id
  late Map<int, int> _liveMissingCounts;

  @override
  void initState() {
    super.initState();
    _liveMissingCounts = {
      for (final r in widget.meal.recipes) r.id: r.missingIngredients.length,
    };
  }

  void _onRecipeMissingChanged(int recipeId, int newCount) {
    setState(() => _liveMissingCounts[recipeId] = newCount);
    widget.onMissingChanged(_totalMissing);
  }

  int get _totalMissing =>
      _liveMissingCounts.values.fold(0, (sum, c) => sum + c);

  Future<void> _reschedule() async {
    final now = DateTime.now();
    final initialDate = widget.meal.scheduledAt.isAfter(now)
        ? widget.meal.scheduledAt
        : now.add(const Duration(days: 1));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => _goldDatePickerTheme(ctx, child),
    );
    if (picked == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(widget.meal.scheduledAt),
      builder: (ctx, child) => _goldDatePickerTheme(ctx, child),
    );
    if (time == null || !mounted) return;

    final newDate = DateTime(
      picked.year,
      picked.month,
      picked.day,
      time.hour,
      time.minute,
    );

    try {
      final updated = await ScheduledMealsService.reschedule(
        widget.meal.id,
        newDate,
      );
      widget.onRescheduled(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Rescheduled to ${DateFormat('MMM d • h:mm a').format(newDate)}',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            backgroundColor: AppColors.bgCardElevated,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to reschedule: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final meal = widget.meal;
    final isPast = meal.scheduledAt.isBefore(DateTime.now());
    final totalMissing = _totalMissing;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: t.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPast
              ? t.borderSubtle
              : totalMissing > 0
              ? AppColors.warning.withValues(alpha: 0.35)
              : AppColors.goldPrimary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          // ── Card header
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: t.goldDim,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        meal.mealType.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meal.displayTitle,
                          style: AppTextStyles.headingMediumOf(context),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: t.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat(
                                'MMM d, yyyy • h:mm a',
                              ).format(meal.scheduledAt),
                              style: AppTextStyles.bodySmallOf(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          runSpacing: 6,
                          children: [
                            _Chip(
                              meal.cuisine.toUpperCase(),
                              AppColors.goldPrimary,
                              t.goldDim,
                            ),
                            const SizedBox(width: 6),
                            _Chip(
                              meal.mealType.label,
                              t.textSecondary,
                              t.bgCardElevated,
                            ),
                            const SizedBox(width: 6),
                            _Chip(
                              '${meal.servings} ppl',
                              t.textSecondary,
                              t.bgCardElevated,
                            ),
                            if (meal.healthy) ...[
                              const SizedBox(width: 6),
                              _Chip(
                                '🥗',
                                AppColors.success,
                                AppColors.successDim,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: t.textMuted,
                      ),
                      if (totalMissing > 0) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$totalMissing missing',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded body
          if (_expanded) ...[
            Divider(
              height: 1,
              color: t.borderSubtle,
              indent: 16,
              endIndent: 16,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PLANNED RECIPES',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: t.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...meal.recipes.map(
                    (r) => _RecipeDetailRow(
                      recipe: r,
                      onMissingChanged: (newCount) =>
                          _onRecipeMissingChanged(r.id, newCount),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _OutlineButton(
                          label: 'Reschedule',
                          icon: Icons.edit_calendar_rounded,
                          color: AppColors.goldPrimary,
                          onTap: _reschedule,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _OutlineButton(
                          label: 'Cancel',
                          icon: Icons.delete_outline_rounded,
                          color: AppColors.error,
                          onTap: widget.onDelete,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Shopping list section

class _ShoppingListSection extends StatefulWidget {
  final int recipeId;
  final List<String> initialItems;
  final void Function(List<String> removedItems) onItemsMarkedDone;

  const _ShoppingListSection({
    required this.recipeId,
    required this.initialItems,
    required this.onItemsMarkedDone,
  });

  @override
  State<_ShoppingListSection> createState() => _ShoppingListSectionState();
}

class _ShoppingListSectionState extends State<_ShoppingListSection> {
  late List<String> _remaining;
  final Set<String> _selected = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _remaining = List<String>.from(widget.initialItems);
  }

  void _toggle(String item) => setState(() {
    _selected.contains(item) ? _selected.remove(item) : _selected.add(item);
  });

  Future<void> _markDone() async {
    final removedItems = _selected.toList();
    final nowRemaining = _remaining
        .where((i) => !_selected.contains(i))
        .toList();

    setState(() => _saving = true);

    try {
      await ScheduledMealsService.updateMissingIngredients(
        recipeId: widget.recipeId,
        remaining: nowRemaining,
      );
      setState(() {
        _remaining = nowRemaining;
        _selected.clear();
      });
      widget.onItemsMarkedDone(removedItems);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not save: $e',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            backgroundColor: AppColors.errorDim,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);

    if (_remaining.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.successDim.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'All items accounted for!',
              style: TextStyle(
                color: AppColors.success,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final categorized = _categorizeMissing(_remaining);

    return Container(
      decoration: BoxDecoration(
        color: t.bgCardElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.goldPrimary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: Row(
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  color: AppColors.warning,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Shopping List',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: t.textPrimary,
                  ),
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    key: ValueKey(_remaining.length),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_remaining.length} item${_remaining.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Hint
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Text(
              'Tap items to select · confirm to remove from list',
              style: TextStyle(color: t.textMuted, fontSize: 11),
            ),
          ),

          // ── Category rows
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: categorized.entries
                  .map(
                    (e) => _CategoryChipsRow(
                      category: e.key,
                      items: e.value,
                      selected: _selected,
                      onToggle: _toggle,
                    ),
                  )
                  .toList(),
            ),
          ),

          // ── Mark as done button
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: _selected.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                    child: GestureDetector(
                      onTap: (_selected.isEmpty || _saving) ? null : _markDone,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.45),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 18,
                                child: Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.success,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline_rounded,
                                    color: AppColors.success,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    'Mark ${_selected.length} item${_selected.length == 1 ? '' : 's'} as Done  ✓',
                                    style: const TextStyle(
                                      color: AppColors.success,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  )
                : const SizedBox(height: 14),
          ),
        ],
      ),
    );
  }
}

// Single category row

class _CategoryChipsRow extends StatelessWidget {
  final String category;
  final List<String> items;
  final Set<String> selected;
  final void Function(String) onToggle;

  const _CategoryChipsRow({
    required this.category,
    required this.items,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _kCatEmojis[category] ?? '📦',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 5),
              Text(
                category.toUpperCase(),
                style: AppTextStyles.labelLarge.copyWith(
                  color: t.textPrimary,
                  fontSize: 10,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: t.bgCardElevated,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: items.map((item) {
              final isSel = selected.contains(item);
              return GestureDetector(
                onTap: () => onToggle(item),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isSel
                        ? AppColors.success.withValues(alpha: 0.12)
                        : t.bgCard,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: isSel
                          ? AppColors.success.withValues(alpha: 0.55)
                          : AppColors.warning.withValues(alpha: 0.3),
                      width: isSel ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSel
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        size: 13,
                        color: isSel
                            ? AppColors.success
                            : AppColors.warning.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        item,
                        style: TextStyle(
                          color: isSel ? AppColors.success : AppColors.warning,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// Recipe detail row

class _RecipeDetailRow extends StatefulWidget {
  final ScheduledMealRecipe recipe;
  final void Function(int newCount) onMissingChanged;

  const _RecipeDetailRow({
    required this.recipe,
    required this.onMissingChanged,
  });

  @override
  State<_RecipeDetailRow> createState() => _RecipeDetailRowState();
}

class _RecipeDetailRowState extends State<_RecipeDetailRow> {
  bool _open = false;
  late Set<String> _stillMissing;

  @override
  void initState() {
    super.initState();
    _stillMissing = Set<String>.from(widget.recipe.missingIngredients);
  }

  void _onItemsMarkedDone(List<String> removedItems) {
    setState(() {
      for (final item in removedItems) {
        _stillMissing.remove(item);
      }
    });
    widget.onMissingChanged(_stillMissing.length);
  }

  // Case-insensitive: ingredient gets tick if originally in inventory
  // OR if user has marked it done (no longer in _stillMissing)
  bool _isAvailable(GeminiIngredient ing) {
    if (ing.inUserInventory) return true;
    final nameLower = ing.name.toLowerCase().trim();
    return !_stillMissing.any((m) => m.toLowerCase().trim() == nameLower);
  }

  String _getTotalTime(String prep, String cook) {
    int parseMinutes(String input) {
      final lower = input.toLowerCase();
      int total = 0;
      final rangeMatch = RegExp(r'(\d+)\s*-\s*(\d+)').firstMatch(lower);
      if (rangeMatch != null) {
        final maxVal = int.parse(rangeMatch.group(2)!);
        if (lower.contains('h')) return maxVal * 60;
        return maxVal;
      }
      final hourMatches = RegExp(r'(\d+)\s*h').allMatches(lower);
      for (final m in hourMatches) {
        total += int.parse(m.group(1)!) * 60;
      }
      final minMatches = RegExp(r'(\d+)\s*m').allMatches(lower);
      for (final m in minMatches) {
        total += int.parse(m.group(1)!);
      }
      if (total == 0) {
        final numMatch = RegExp(r'(\d+)').firstMatch(lower);
        if (numMatch != null) {
          final v = int.parse(numMatch.group(1)!);
          return lower.contains('h') ? v * 60 : v;
        }
      }
      return total;
    }

    final total = parseMinutes(prep) + parseMinutes(cook);
    if (total >= 60) {
      final h = total ~/ 60;
      final m = total % 60;
      return m == 0 ? '$h hr' : '$h hr $m min';
    }
    return total > 0 ? '$total min' : '—';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final r = widget.recipe.recipe;
    final missingCount = _stillMissing.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: t.bgCardElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: missingCount > 0
              ? AppColors.warning.withValues(alpha: 0.2)
              : t.borderSubtle,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  const Text('🍳', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.name,
                          style: AppTextStyles.headingSmallOf(context),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 11,
                              color: t.textMuted,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '⏱ ${_getTotalTime(r.prepTime, r.cookTime)}',
                              style: AppTextStyles.bodySmallOf(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (missingCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '−$missingCount',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 18,
                    ),
                  const SizedBox(width: 6),
                  Icon(
                    _open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: t.textMuted,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (_open) ...[
            Divider(
              height: 1,
              color: t.borderSubtle,
              indent: 12,
              endIndent: 12,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (r.description.isNotEmpty) ...[
                    Text(
                      r.description,
                      style: AppTextStyles.bodySmallOf(
                        context,
                      ).copyWith(fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Chip(
                        '👥 ${r.servings} servings',
                        t.textSecondary,
                        t.bgSurface,
                      ),
                      if (r.healthy)
                        _Chip(
                          '🥗 Healthy',
                          AppColors.success,
                          AppColors.successDim,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionHeader('Ingredients', Icons.kitchen_outlined),
                  const SizedBox(height: 8),
                  ...r.ingredients.map((ing) {
                    final available = _isAvailable(ing);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(
                        children: [
                          Icon(
                            available
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            size: 15,
                            color: available
                                ? AppColors.success
                                : AppColors.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ing.name,
                              style: AppTextStyles.bodySmallOf(context)
                                  .copyWith(
                                    color: available
                                        ? t.textPrimary
                                        : AppColors.error,
                                  ),
                            ),
                          ),
                          Text(
                            ing.quantity,
                            style: AppTextStyles.bodySmallOf(
                              context,
                            ).copyWith(color: t.textMuted),
                          ),
                        ],
                      ),
                    );
                  }),

                  // ── Per-recipe shopping list
                  if (_stillMissing.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _ShoppingListSection(
                      recipeId: widget.recipe.id,
                      initialItems: _stillMissing.toList(),
                      onItemsMarkedDone: _onItemsMarkedDone,
                    ),
                  ] else if (widget.recipe.missingIngredients.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successDim.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.success,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'All items accounted for!',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (r.steps.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SectionHeader(
                      'Cooking Steps',
                      Icons.format_list_numbered_rounded,
                    ),
                    const SizedBox(height: 10),
                    ...r.steps.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: AppColors.goldDim,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '${entry.key + 1}',
                                  style: const TextStyle(
                                    color: AppColors.goldPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  entry.value,
                                  style: AppTextStyles.bodySmallOf(
                                    context,
                                  ).copyWith(color: t.textPrimary, height: 1.5),
                                ),
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
          ],
        ],
      ),
    );
  }
}

// Bottom Sheet

class _ScheduleBottomSheet extends StatefulWidget {
  final void Function(ScheduledMeal) onSaved;
  const _ScheduleBottomSheet({required this.onSaved});

  @override
  State<_ScheduleBottomSheet> createState() => _ScheduleBottomSheetState();
}

enum _SheetStep { form, results }

class _ScheduleBottomSheetState extends State<_ScheduleBottomSheet>
    with SingleTickerProviderStateMixin {
  _SheetStep _step = _SheetStep.form;

  final _labelCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 19, minute: 0);

  final Set<String> _selectedCuisines = {'North Indian'};
  final Set<MealType> _selectedMealTypes = {MealType.dinner};

  int _servings = 4;
  bool _healthy = false;
  int _limit = 5;

  List<GeminiRecipe> _suggestions = [];
  final Set<int> _selectedIndices = {};
  bool _loadingSuggest = false;
  bool _savingMeal = false;
  String? _suggestError;

  static const _cuisines = [
    'North Indian',
    'South Indian',
    'Punjabi',
    'Gujarati',
    'Bengali',
    'Italian',
    'Mexican',
    'Mughlai',
    'Indo-Chinese',
    'Street Food',
    'Biryani & Rice',
    'Dal & Curries',
    'Snacks & Starters',
    'Desserts & Sweets',
  ];

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  String get _cuisineString => _selectedCuisines.join(', ');
  String get _mealTypeString =>
      _selectedMealTypes.map((m) => m.value).join(' & ');
  String get _primaryMealTypeValue {
    if (_selectedMealTypes.length == 1) return _selectedMealTypes.first.value;
    if (_selectedMealTypes.contains(MealType.allDay))
      return MealType.allDay.value;
    return _selectedMealTypes.first.value;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => _goldDatePickerTheme(ctx, child),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (ctx, child) => _goldDatePickerTheme(ctx, child),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _generateSuggestions() async {
    setState(() {
      _loadingSuggest = true;
      _suggestError = null;
      _step = _SheetStep.results;
      _suggestions = [];
      _selectedIndices.clear();
    });

    try {
      final recipes = await ScheduledMealsService.suggest(
        cuisine: _cuisineString,
        servings: _servings,
        healthy: _healthy,
        mealType: _mealTypeString,
        limit: _limit,
      );
      setState(() => _suggestions = recipes);
    } catch (e) {
      setState(() => _suggestError = e.toString());
    } finally {
      setState(() => _loadingSuggest = false);
    }
  }

  Future<void> _saveSchedule() async {
    if (_selectedIndices.isEmpty) return;
    setState(() => _savingMeal = true);

    final chosen = _selectedIndices.map((i) => _suggestions[i]).toList();
    final scheduledAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    try {
      final saved = await ScheduledMealsService.create(
        scheduledAt: scheduledAt,
        mealType: _primaryMealTypeValue,
        cuisine: _cuisineString,
        healthy: _healthy,
        servings: _servings,
        eventLabel: _labelCtrl.text.trim().isEmpty
            ? null
            : _labelCtrl.text.trim(),
        chosenRecipes: chosen,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved(saved);
      }
    } catch (e) {
      setState(() => _savingMeal = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.errorDim,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final mq = MediaQuery.of(context);

    return Container(
      height: mq.size.height * 0.92,
      decoration: BoxDecoration(
        color: t.bgSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: t.borderGold.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: t.borderMedium,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                if (_step == _SheetStep.results)
                  GestureDetector(
                    onTap: () => setState(() {
                      _step = _SheetStep.form;
                      _suggestions = [];
                      _selectedIndices.clear();
                      _suggestError = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: t.bgCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: t.borderSubtle),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: t.textSecondary,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _step == _SheetStep.form
                        ? 'Plan a Meal Event'
                        : 'Choose Your Recipes',
                    style: AppTextStyles.displaySmallOf(context),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 46),
              ],
            ),
          ),
          Divider(height: 1, color: t.borderSubtle),
          Expanded(
            child: _step == _SheetStep.form
                ? _buildForm(t, mq)
                : _buildResults(t),
          ),
          _buildFooter(t, mq),
        ],
      ),
    );
  }

  Widget _buildForm(AppTheme t, MediaQueryData mq) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, mq.viewInsets.bottom + 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('Event Name (optional)'),
          const SizedBox(height: 8),
          _StyledTextField(
            controller: _labelCtrl,
            hint: 'e.g. Birthday dinner for Rahul',
            icon: Icons.celebration_outlined,
          ),
          const SizedBox(height: 22),
          _SectionLabel('When?'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _PickerTile(
                  icon: Icons.calendar_today_rounded,
                  label: DateFormat('MMM d, yyyy').format(_selectedDate),
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PickerTile(
                  icon: Icons.access_time_rounded,
                  label: _selectedTime.format(context),
                  onTap: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _SectionLabel('Meal Type'),
          const SizedBox(height: 3),
          Text(
            'Select one or more',
            style: AppTextStyles.bodySmallOf(
              context,
            ).copyWith(color: t.textMuted),
          ),
          const SizedBox(height: 10),
          Row(
            children: MealType.values.map((mt) {
              final sel = _selectedMealTypes.contains(mt);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: mt != MealType.allDay ? 8 : 0,
                  ),
                  child: _MealTypeChip(
                    mealType: mt,
                    selected: sel,
                    onTap: () => setState(() {
                      if (sel) {
                        if (_selectedMealTypes.length > 1)
                          _selectedMealTypes.remove(mt);
                      } else {
                        _selectedMealTypes.add(mt);
                      }
                    }),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_selectedMealTypes.length > 1) ...[
            const SizedBox(height: 8),
            _MultiSelectBadge(
              label: _selectedMealTypes.map((m) => m.label).join(' + '),
            ),
          ],
          const SizedBox(height: 22),
          _SectionLabel('Cuisine'),
          const SizedBox(height: 3),
          Text(
            'Select one or more',
            style: AppTextStyles.bodySmallOf(
              context,
            ).copyWith(color: t.textMuted),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _cuisines.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = _cuisines[i];
                final sel = _selectedCuisines.contains(c);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (sel) {
                      if (_selectedCuisines.length > 1)
                        _selectedCuisines.remove(c);
                    } else {
                      _selectedCuisines.add(c);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.goldDim : t.bgCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel ? AppColors.goldPrimary : t.borderSubtle,
                        width: sel ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        c,
                        style: TextStyle(
                          color: sel ? AppColors.goldPrimary : t.textSecondary,
                          fontSize: 13,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_selectedCuisines.length > 1) ...[
            const SizedBox(height: 8),
            _MultiSelectBadge(
              label:
                  '${_selectedCuisines.length} cuisines selected: $_cuisineString',
            ),
          ],
          const SizedBox(height: 22),
          _SectionLabel('Guests (servings)'),
          const SizedBox(height: 8),
          _StepperRow(
            value: _servings,
            min: 1,
            max: 20,
            onChanged: (v) => setState(() => _servings = v),
          ),
          const SizedBox(height: 22),
          _SectionLabel('Dietary Preference'),
          const SizedBox(height: 8),
          _ToggleRow(
            label: 'Healthy meals only',
            value: _healthy,
            onChanged: (v) => setState(() => _healthy = v),
          ),
          const SizedBox(height: 22),
          _SectionLabel('How many recipe suggestions? ($_limit)'),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.goldPrimary,
              inactiveTrackColor: t.borderMedium,
              thumbColor: AppColors.goldPrimary,
              overlayColor: AppColors.goldPrimary.withValues(alpha: 0.15),
              valueIndicatorColor: AppColors.goldDark,
              trackHeight: 3,
            ),
            child: Slider(
              value: _limit.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '$_limit',
              onChanged: (v) => setState(() => _limit = v.round()),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildResults(AppTheme t) {
    if (_loadingSuggest) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.goldPrimary,
                ),
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Generating recipes with AI...',
              style: AppTextStyles.bodyMediumOf(
                context,
              ).copyWith(color: t.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              'This may take up to 30 seconds',
              style: AppTextStyles.bodySmallOf(context),
            ),
          ],
        ),
      );
    }

    if (_suggestError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: AppTextStyles.headingMediumOf(context),
              ),
              const SizedBox(height: 8),
              Text(
                _suggestError!,
                style: AppTextStyles.bodySmallOf(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _GoldButton(label: 'Try Again', onTap: _generateSuggestions),
            ],
          ),
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.goldPrimary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Text(
            'Tap to select the recipes you want to cook',
            style: AppTextStyles.bodyMediumOf(
              context,
            ).copyWith(color: t.textSecondary),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: _suggestions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _RecipePickerCard(
              recipe: _suggestions[i],
              selected: _selectedIndices.contains(i),
              onToggle: () => setState(() {
                _selectedIndices.contains(i)
                    ? _selectedIndices.remove(i)
                    : _selectedIndices.add(i);
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(AppTheme t, MediaQueryData mq) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, mq.padding.bottom + 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.borderSubtle)),
      ),
      child: _step == _SheetStep.form
          ? _GoldButton(
              label: 'Generate Recipes  →',
              onTap: _generateSuggestions,
              fullWidth: true,
            )
          : _loadingSuggest
          ? const SizedBox.shrink()
          : _GoldButton(
              label: _savingMeal
                  ? 'Saving...'
                  : _selectedIndices.isEmpty
                  ? 'Select at least one recipe'
                  : 'Confirm ${_selectedIndices.length} Recipe${_selectedIndices.length > 1 ? "s" : ""}  ✓',
              onTap: _selectedIndices.isEmpty || _savingMeal
                  ? null
                  : _saveSchedule,
              fullWidth: true,
              disabled: _selectedIndices.isEmpty || _savingMeal,
            ),
    );
  }
}

// Recipe picker card

class _RecipePickerCard extends StatefulWidget {
  final GeminiRecipe recipe;
  final bool selected;
  final VoidCallback onToggle;

  const _RecipePickerCard({
    required this.recipe,
    required this.selected,
    required this.onToggle,
  });

  @override
  State<_RecipePickerCard> createState() => _RecipePickerCardState();
}

class _RecipePickerCardState extends State<_RecipePickerCard> {
  bool _detailsOpen = false;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final r = widget.recipe;
    final hasMissing = r.missingIngredients.isNotEmpty;

    return GestureDetector(
      onTap: widget.onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: widget.selected
              ? AppColors.goldDim.withValues(alpha: 0.6)
              : t.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.selected
                ? AppColors.goldPrimary
                : hasMissing
                ? AppColors.warning.withValues(alpha: 0.35)
                : t.borderSubtle,
            width: widget.selected ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      r.name,
                      style: AppTextStyles.headingSmallOf(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: widget.selected
                          ? AppColors.goldPrimary
                          : t.bgCardElevated,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.selected
                            ? AppColors.goldPrimary
                            : t.borderMedium,
                      ),
                    ),
                    child: widget.selected
                        ? const Icon(Icons.check, color: Colors.black, size: 15)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                r.description,
                style: AppTextStyles.bodySmallOf(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _Chip(
                    '⏱ Prep: ${r.prepTime}',
                    t.textSecondary,
                    t.bgCardElevated,
                  ),
                  _Chip(
                    '🔥 Cook: ${r.cookTime}',
                    t.textSecondary,
                    t.bgCardElevated,
                  ),
                  if (r.healthy)
                    _Chip(
                      '🥗 Healthy',
                      AppColors.success,
                      AppColors.successDim,
                    ),
                  if (hasMissing)
                    _Chip(
                      '🛒 ${r.missingIngredients.length} missing',
                      AppColors.warning,
                      AppColors.warningDim,
                    )
                  else
                    _Chip(
                      '✓ All in stock',
                      AppColors.success,
                      AppColors.successDim,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _detailsOpen = !_detailsOpen),
                child: Row(
                  children: [
                    Text(
                      _detailsOpen
                          ? 'Hide details'
                          : 'View ingredients & steps',
                      style: const TextStyle(
                        color: AppColors.goldPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _detailsOpen
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.goldPrimary,
                      size: 16,
                    ),
                  ],
                ),
              ),
              if (_detailsOpen) ...[
                const SizedBox(height: 12),
                _SectionHeader('Ingredients', Icons.kitchen_outlined),
                const SizedBox(height: 8),
                ...r.ingredients.map(
                  (ing) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          ing.inUserInventory
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          size: 14,
                          color: ing.inUserInventory
                              ? AppColors.success
                              : AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ing.name,
                            style: AppTextStyles.bodySmallOf(context).copyWith(
                              color: ing.inUserInventory
                                  ? AppTheme.of(context).textPrimary
                                  : AppColors.error,
                            ),
                          ),
                        ),
                        Text(
                          ing.quantity,
                          style: AppTextStyles.bodySmallOf(
                            context,
                          ).copyWith(color: AppTheme.of(context).textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                if (r.steps.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _SectionHeader('Steps', Icons.format_list_numbered_rounded),
                  const SizedBox(height: 8),
                  ...r.steps.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.goldDim,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Center(
                              child: Text(
                                '${entry.key + 1}',
                                style: const TextStyle(
                                  color: AppColors.goldPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                entry.value,
                                style: AppTextStyles.bodySmallOf(context)
                                    .copyWith(
                                      color: AppTheme.of(context).textPrimary,
                                      height: 1.5,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Helpers

Widget _goldDatePickerTheme(BuildContext context, Widget? child) {
  return Theme(
    data: Theme.of(context).copyWith(
      colorScheme: const ColorScheme.dark(
        primary: AppColors.goldPrimary,
        onPrimary: Colors.black,
        surface: AppColors.bgCard,
        onSurface: AppColors.textPrimary,
      ),
      dialogBackgroundColor: AppColors.bgSecondary,
    ),
    child: child!,
  );
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionHeader(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Row(
      children: [
        Icon(icon, size: 14, color: t.textSecondary),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: AppTextStyles.labelLarge.copyWith(color: t.textSecondary),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: AppTextStyles.labelLarge.copyWith(
      color: AppTheme.of(context).textSecondary,
    ),
  );
}

class _MultiSelectBadge extends StatelessWidget {
  final String label;
  const _MultiSelectBadge({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.goldDim,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.goldPrimary.withValues(alpha: 0.4)),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: AppColors.goldPrimary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;

  const _StyledTextField({
    required this.controller,
    required this.hint,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return TextField(
      controller: controller,
      style: AppTextStyles.bodyMediumOf(context),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: t.textMuted),
        prefixIcon: Icon(icon, color: t.textMuted, size: 18),
        filled: true,
        fillColor: t.bgCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.goldPrimary,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: t.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.borderSubtle),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.goldPrimary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMediumOf(context),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealTypeChip extends StatelessWidget {
  final MealType mealType;
  final bool selected;
  final VoidCallback onTap;

  const _MealTypeChip({
    required this.mealType,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.goldDim : t.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.goldPrimary : t.borderSubtle,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mealType.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 3),
            Text(
              mealType.label,
              style: TextStyle(
                color: selected ? AppColors.goldPrimary : t.textSecondary,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  final int value, min, max;
  final void Function(int) onChanged;

  const _StepperRow({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: t.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBtn(
            icon: Icons.remove,
            onTap: value > min ? () => onChanged(value - 1) : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '$value',
              style: AppTextStyles.headingMediumOf(context),
            ),
          ),
          _StepBtn(
            icon: Icons.add,
            onTap: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: onTap != null ? AppColors.goldDim : t.bgCardElevated,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap != null ? AppColors.goldPrimary : t.textMuted,
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final void Function(bool) onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: t.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.borderSubtle),
      ),
      child: Row(
        children: [
          const Icon(Icons.eco_outlined, color: AppColors.success, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: AppTextStyles.bodyMediumOf(context)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.goldPrimary,
            activeTrackColor: AppColors.goldDim,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color textColor, bgColor;
  const _Chip(this.label, this.textColor, this.bgColor);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: textColor,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _OutlineButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: t.bgCardElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool fullWidth;
  final bool disabled;

  const _GoldButton({
    required this.label,
    required this.onTap,
    this.fullWidth = false,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: disabled ? null : AppColors.goldGradient,
          color: disabled ? t.bgCard : null,
          borderRadius: BorderRadius.circular(12),
          border: disabled ? Border.all(color: t.borderSubtle) : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.headingSmall.copyWith(
            color: disabled ? t.textMuted : AppColors.textOnGold,
          ),
        ),
      ),
    );
  }
}

// Loading / Error / Empty states

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 80),
    child: Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.goldPrimary),
        strokeWidth: 2,
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 60),
    child: Column(
      children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 48),
        const SizedBox(height: 16),
        Text(
          'Failed to load meals',
          style: AppTextStyles.headingMediumOf(context),
        ),
        const SizedBox(height: 8),
        Text(
          error,
          style: AppTextStyles.bodySmallOf(context),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        _GoldButton(label: 'Retry', onTap: onRetry),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: t.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.borderGold),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: t.goldDim,
                  shape: BoxShape.circle,
                ),
                child: const Text('🍽️', style: TextStyle(fontSize: 38)),
              ),
              const SizedBox(height: 22),
              Text(
                'Plan Your First Meal Event',
                style: AppTextStyles.displaySmallOf(context),
              ),
              const SizedBox(height: 10),
              Text(
                'Schedule meals for guests, birthdays or any\nspecial occasion. We\'ll help you plan and\nbuild your shopping list.',
                style: AppTextStyles.bodyMediumOf(
                  context,
                ).copyWith(color: t.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Schedule a Meal',
                  style: AppTextStyles.headingSmallOf(
                    context,
                  ).copyWith(color: AppColors.textOnGold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmDeleteDialog extends StatelessWidget {
  final ScheduledMeal meal;
  const _ConfirmDeleteDialog({required this.meal});

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return AlertDialog(
      backgroundColor: t.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Cancel Meal?',
        style: AppTextStyles.headingMediumOf(context),
      ),
      content: Text(
        'Remove "${meal.displayTitle}" scheduled for '
        '${DateFormat('MMM d, yyyy').format(meal.scheduledAt)}?',
        style: AppTextStyles.bodyMediumOf(
          context,
        ).copyWith(color: t.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Keep it', style: TextStyle(color: t.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Remove', style: TextStyle(color: AppColors.error)),
        ),
      ],
    );
  }
}
