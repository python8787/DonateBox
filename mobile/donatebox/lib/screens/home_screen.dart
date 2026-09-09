import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../config/app_config.dart';
import '../services/api_service.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/amount_selector.dart';
import '../widgets/donation_dialog.dart';

/// Home screen — the core donation experience.
///
/// Minimal layout: name input + amount selector + currency toggle + Donate button.
/// Amount config would normally come from the backend; using defaults until connected.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _nameController = TextEditingController();
  String _selectedCurrency = 'INR';
  double? _selectedAmount;
  bool _isLoading = false;

  // Default config — replaced by backend config in Phase 3+
  final Map<String, _CurrencyPreset> _presets = {
    'INR': _CurrencyPreset(
      symbol: '₹',
      presets: [50, 100, 500, 1000],
      min: 1,
      max: 10000,
    ),
    'USD': _CurrencyPreset(
      symbol: '\$',
      presets: [5, 10, 25, 50],
      min: 1,
      max: 500,
    ),
  };

  _CurrencyPreset get _currentPreset => _presets[_selectedCurrency]!;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onCurrencyChanged(String currency) {
    setState(() {
      _selectedCurrency = currency;
      _selectedAmount = null; // Reset amount on currency change
    });
  }

  void _onDonatePressed() {
    if (_selectedAmount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select or enter a donation amount'),
          backgroundColor: AppTheme.errorRed.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Validate amount
    if (_selectedAmount! < _currentPreset.min ||
        _selectedAmount! > _currentPreset.max) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Amount must be between ${_currentPreset.symbol}${_currentPreset.min.toStringAsFixed(0)} '
            'and ${_currentPreset.symbol}${_currentPreset.max.toStringAsFixed(0)}',
          ),
          backgroundColor: AppTheme.errorRed.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Show confirmation dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DonationConfirmDialog(
        amount: _selectedAmount!,
        currency: _selectedCurrency,
        currencySymbol: _currentPreset.symbol,
        termsVersion: '1.0', // Will come from backend config
        onProceed: () {
          Navigator.of(context).pop();
          _processDonation();
        },
      ),
    );
  }

  Future<void> _processDonation() async {
    setState(() => _isLoading = true);

    try {
      // 1. Create donation on backend
      final donationResult = await ApiService.createDonation(
        name: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : null,
        amount: _selectedAmount!,
        currency: _selectedCurrency,
        termsVersion: '1.0', // Will come from backend config
      );

      if (!mounted) return;

      // 2. Navigate to thank-you (payment gateway integration in Phase 4)
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _ThankYouPlaceholder(
            amount: _selectedAmount!,
            symbol: _currentPreset.symbol,
            currency: _selectedCurrency,
          ),
        ),
      );
    } on RateLimitException catch (e) {
      _showErrorSnackBar(e.message);
    } on NetworkException catch (e) {
      _showErrorSnackBar(e.message);
    } on ApiTimeoutException catch (e) {
      _showErrorSnackBar(e.message);
    } on ServerException catch (e) {
      _showErrorSnackBar(e.message);
    } on ValidationException catch (e) {
      _showErrorSnackBar(e.message);
    } on ApiException catch (e) {
      _showErrorSnackBar(e.message);
    } catch (e) {
      _showErrorSnackBar('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.errorRed.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: AppTheme.spacingLg),

                // App title
                Text(
                  'DonateBox',
                  style: Theme.of(context).textTheme.displayMedium,
                ).animate().fadeIn(duration: 400.ms),

                const SizedBox(height: AppTheme.spacingSm),

                const Text(
                  'Make a difference, one donation at a time',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ).animate(delay: 100.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: AppTheme.spacingXl),

                // Main card
                GlassmorphicCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Currency toggle
                      _CurrencyToggle(
                        selected: _selectedCurrency,
                        onChanged: _onCurrencyChanged,
                      ),
                      const SizedBox(height: AppTheme.spacingLg),

                      // Name input
                      Text(
                        'Your Name (optional)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppTheme.spacingSm),
                      TextField(
                        controller: _nameController,
                        maxLength: AppConfig.maxNameLength,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Enter your name or leave blank',
                          counterText: '',
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingLg),

                      // Amount selector
                      AmountSelector(
                        presets: _currentPreset.presets,
                        minAmount: _currentPreset.min,
                        maxAmount: _currentPreset.max,
                        currencySymbol: _currentPreset.symbol,
                        selectedAmount: _selectedAmount,
                        onAmountChanged: (amount) {
                          setState(() => _selectedAmount = amount);
                        },
                      ),
                    ],
                  ),
                ).animate(delay: 200.ms).fadeIn(duration: 500.ms).slideY(
                      begin: 0.1,
                      end: 0,
                      duration: 500.ms,
                    ),

                const SizedBox(height: AppTheme.spacingLg),

                // Donate button
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium),
                      gradient: AppTheme.buttonGradient,
                      boxShadow: [
                        BoxShadow(
                          color:
                              AppTheme.primaryPurple.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _onDonatePressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.favorite, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Donate',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ).animate(delay: 400.ms).fadeIn(duration: 500.ms).slideY(
                      begin: 0.2,
                      end: 0,
                      duration: 500.ms,
                    ),

                const SizedBox(height: AppTheme.spacingMd),

                // Disclaimer
                const Text(
                  'This is a personal donation. No tax benefits apply.',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Currency toggle widget
class _CurrencyToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _CurrencyToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Currency', style: TextStyle(color: AppTheme.textSecondary)),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            color: AppTheme.glassWhite,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: ['INR', 'USD'].map((currency) {
              final isSelected = selected == currency;
              return GestureDetector(
                onTap: () => onChanged(currency),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    gradient: isSelected ? AppTheme.buttonGradient : null,
                  ),
                  child: Text(
                    currency == 'INR' ? '₹ INR' : '\$ USD',
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AppTheme.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// Placeholder thank you screen — replaced with proper screen in Phase 2
class _ThankYouPlaceholder extends StatelessWidget {
  final double amount;
  final String symbol;
  final String currency;

  const _ThankYouPlaceholder({
    required this.amount,
    required this.symbol,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Center(
          child: GlassmorphicCard(
            margin: const EdgeInsets.all(AppTheme.spacingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.successGreen,
                        AppTheme.successGreen.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                )
                    .animate()
                    .scale(
                      begin: const Offset(0, 0),
                      end: const Offset(1, 1),
                      duration: 500.ms,
                      curve: Curves.elasticOut,
                    ),
                const SizedBox(height: AppTheme.spacingLg),
                Text(
                  'Thank You!',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  'Your donation of $symbol${amount.toStringAsFixed(2)} $currency\n'
                  'has been received.',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingXl),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.glassWhite,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                        side: const BorderSide(color: AppTheme.glassBorder),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
