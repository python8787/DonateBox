import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../widgets/glassmorphic_card.dart';

/// Screen shown when a payment fails or is cancelled.
///
/// Provides context-appropriate messaging and action buttons:
/// - Failed: "Try Again" + "Go Back"
/// - Cancelled: "Try Again" + "Go Back"
class PaymentFailedScreen extends StatelessWidget {
  final double amount;
  final String currencySymbol;
  final String currency;
  final String? errorMessage;
  final bool wasCancelled;
  final VoidCallback? onRetry;

  const PaymentFailedScreen({
    super.key,
    required this.amount,
    required this.currencySymbol,
    required this.currency,
    this.errorMessage,
    this.wasCancelled = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final title = wasCancelled ? 'Payment Cancelled' : 'Payment Failed';
    final subtitle = wasCancelled
        ? 'You cancelled the payment. No amount was charged.'
        : 'Something went wrong with the payment.\nDon\'t worry — you were not charged.';
    final iconData = wasCancelled ? Icons.cancel_outlined : Icons.error_outline_rounded;
    final iconColor = wasCancelled ? AppTheme.warningAmber : AppTheme.errorRed;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Error/Cancel icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: iconColor.withValues(alpha: 0.15),
                        border: Border.all(
                          color: iconColor.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(iconData, size: 50, color: iconColor),
                    )
                        .animate()
                        .scale(
                          begin: const Offset(0.5, 0.5),
                          end: const Offset(1, 1),
                          duration: 500.ms,
                          curve: Curves.elasticOut,
                        )
                        .fadeIn(duration: 300.ms),

                    const SizedBox(height: AppTheme.spacingXl),

                    // Title
                    Text(
                      title,
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            color: iconColor,
                          ),
                      textAlign: TextAlign.center,
                    ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

                    const SizedBox(height: AppTheme.spacingSm),

                    // Subtitle
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ).animate(delay: 300.ms).fadeIn(duration: 400.ms),

                    const SizedBox(height: AppTheme.spacingXl),

                    // Error details card (if error message provided)
                    if (errorMessage != null)
                      GlassmorphicCard(
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppTheme.textMuted,
                              size: 20,
                            ),
                            const SizedBox(width: AppTheme.spacingSm),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate(delay: 400.ms).fadeIn(duration: 400.ms),

                    if (errorMessage != null)
                      const SizedBox(height: AppTheme.spacingLg),

                    // Amount attempted
                    GlassmorphicCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Amount',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '$currencySymbol${amount.toStringAsFixed(2)} $currency',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: 500.ms).fadeIn(duration: 400.ms),

                    const SizedBox(height: AppTheme.spacingXl),

                    // Retry button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          gradient: AppTheme.buttonGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (onRetry != null) {
                              onRetry!();
                            } else {
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            }
                          },
                          icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                          label: const Text(
                            'Try Again',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            ),
                          ),
                        ),
                      ),
                    ).animate(delay: 600.ms).fadeIn(duration: 400.ms),

                    const SizedBox(height: AppTheme.spacingMd),

                    // Go back button
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      child: const Text(
                        'Go Back',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 15,
                        ),
                      ),
                    ).animate(delay: 700.ms).fadeIn(duration: 400.ms),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
