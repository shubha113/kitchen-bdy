import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../services/waitlist_service.dart';

class WaitlistScreen extends StatefulWidget {
  const WaitlistScreen({super.key});
  @override
  State<WaitlistScreen> createState() => _WaitlistScreenState();
}

class _WaitlistScreenState extends State<WaitlistScreen> {
  bool _loading = false;
  bool _joined = false;

  Future<void> _join() async {
    setState(() => _loading = true);

    final result = await WaitlistService.join();

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('waitlist_joined', true);

    setState(() {
      _loading = false;
      _joined = true;
    });

    final msg = result['message'] as String? ?? "You're on the waitlist!";

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.goldPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          msg,
          style: const TextStyle(
            color: AppColors.textOnGold,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Future<void> _loadJoinedState() async {
    final prefs = await SharedPreferences.getInstance();
    final joined = prefs.getBool('waitlist_joined') ?? false;

    setState(() {
      _joined = joined;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadJoinedState();
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
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(),

              // Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.goldPrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.goldPrimary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.kitchen_outlined,
                  color: AppColors.goldPrimary,
                  size: 48,
                ),
              ),

              const SizedBox(height: 36),

              // Headline
              Text(
                'Something extraordinary\nis on its way.',
                style: AppTextStyles.headingLargeOf(context),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Subtext
              Text(
                'We\'re crafting a smart experience '
                'that will transform the way your kitchen '
                'thinks. Be the first to know when it\'s ready.',
                style: AppTextStyles.bodyMediumOf(
                  context,
                ).copyWith(color: t.textSecondary, height: 1.6),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _joined
                        ? AppColors.success
                        : AppColors.goldPrimary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: (_loading || _joined) ? null : _join,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _joined
                                  ? Icons.check_circle_outline
                                  : Icons.notifications_outlined,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _joined
                                  ? "You're on the waitlist!"
                                  : 'Add me to the waitlist',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Back link
              if (!_joined)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Maybe later',
                    style: AppTextStyles.bodySmallOf(
                      context,
                    ).copyWith(color: t.textSecondary),
                  ),
                ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
