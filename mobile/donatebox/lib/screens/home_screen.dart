import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../config/app_config.dart';
import '../models/donation_config.dart';
import '../models/donation.dart';
import '../services/api_service.dart';
import '../services/payment_client_service.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/amount_selector.dart';
import '../widgets/donation_dialog.dart';
import 'thank_you_screen.dart';
import 'payment_failed_screen.dart';
import 'processing_screen.dart';

/// Home screen — the core donation experience.
///
/// Loads config from backend on init. Falls back to hardcoded
/// defaults if the server is unreachable (offline-friendly).
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
  bool _configLoading = true;
  String? _configError;
  DonationConfig? _serverConfig;

  // Default config — used as fallback when backend is unreachable
  static final Map<String, _CurrencyPreset> _defaultPresets = {
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

  String get _termsVersion => _serverConfig?.termsVersion ?? '1.0';

  _CurrencyPreset get _currentPreset {
    if (_serverConfig != null) {
      final config = _serverConfig!.getConfig(_selectedCurrency);
      if (config != null) {
        return _CurrencyPreset(
          symbol: _selectedCurrency == 'INR' ? '₹' : '\$',
          presets: config.presets,
          min: config.minAmount,
          max: config.maxAmount,
        );
      }
    }
    return _defaultPresets[_selectedCurrency]!;
  }

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _configLoading = true;
      _configError = null;
    });

    try {
      final config = await ApiService.getDonationConfig();
      if (mounted) {
        setState(() {
          _serverConfig = config;
          _configLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _configLoading = false;
          _configError = 'Using offline mode — server unreachable';
        });
      }
    }
  }

  void _onCurrencyChanged(String currency) {
    setState(() {
      _selectedCurrency = currency;
      _selectedAmount = null;
    });
  }

  void _onDonatePressed() {
    if (_selectedAmount == null) {
      _showSnackBar('Please select or enter a donation amount', isError: true);
      return;
    }

    final preset = _currentPreset;
    if (_selectedAmount! < preset.min || _selectedAmount! > preset.max) {
      _showSnackBar(
        'Amount must be between ${preset.symbol}${preset.min.toStringAsFixed(0)} '
        'and ${preset.symbol}${preset.max.toStringAsFixed(0)}',
        isError: true,
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DonationConfirmDialog(
        amount: _selectedAmount!,
        currency: _selectedCurrency,
        currencySymbol: _currentPreset.symbol,
        termsVersion: _termsVersion,
        onProceed: () {
          Navigator.of(context).pop();
          _processDonation();
        },
      ),
    );
  }

  Future<void> _processDonation() async {
    final amount = _selectedAmount!;
    final currency = _selectedCurrency;
    final symbol = _currentPreset.symbol;
    final name = _nameController.text.trim().isEmpty
        ? null
        : _nameController.text.trim();

    setState(() => _isLoading = true);

    // Navigate to processing screen
    if (mounted) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => ProcessingScreen(
            amount: amount,
            currencySymbol: symbol,
            currency: currency,
          ),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }

    try {
      // Step 1: Create donation on backend
      final donationData = await ApiService.createDonation(
        name: name,
        amount: amount,
        currency: currency,
        termsVersion: _termsVersion,
      );
      final donation = Donation.fromJson(donationData);

      // Step 2: Create payment order on backend
      final paymentData = await ApiService.createPayment(
        donationId: donation.id,
      );
      final paymentInit = PaymentInitData.fromJson(paymentData);

      // Step 3: Launch native payment UI (Razorpay or Stripe)
      final paymentResult = await PaymentClientService.launchPayment(paymentInit);

      if (paymentResult.success) {
        // Step 4: Verify payment on backend (NEVER trust client)
        final verifyResult = await ApiService.verifyPayment(
          donationId: donation.id,
          paymentData: paymentResult.data,
        );

        final verified = verifyResult['status'] == 'SUCCESS';

        if (verified && mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => ThankYouScreen(
                amount: amount,
                currencySymbol: symbol,
                currency: currency,
                donorName: name,
                donationId: donation.id,
              ),
              transitionsBuilder: (_, animation, __, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 400),
            ),
            (route) => route.isFirst,
          );
        } else if (mounted) {
          // Server says payment didn't verify
          _navigateToFailed(
            amount: amount,
            symbol: symbol,
            currency: currency,
            message: verifyResult['message'] ?? 'Payment verification failed',
            wasCancelled: false,
          );
        }
      } else {
        // Payment was cancelled or failed at gateway
        if (mounted) {
          _navigateToFailed(
            amount: amount,
            symbol: symbol,
            currency: currency,
            message: paymentResult.error ?? 'Payment failed',
            wasCancelled: paymentResult.wasCancelled,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _navigateToFailed(
          amount: amount,
          symbol: symbol,
          currency: currency,
          message: e.toString().replaceAll('Exception: ', ''),
          wasCancelled: false,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToFailed({
    required double amount,
    required String symbol,
    required String currency,
    required String message,
    required bool wasCancelled,
  }) {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => PaymentFailedScreen(
          amount: amount,
          currencySymbol: symbol,
          currency: currency,
          errorMessage: message,
          wasCancelled: wasCancelled,
          onRetry: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
      (route) => route.isFirst,
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? AppTheme.errorRed.withValues(alpha: 0.9)
            : AppTheme.successGreen.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

                Text(
                  _serverConfig?.recipientName != null
                      ? 'Support ${_serverConfig!.recipientName}'
                      : 'Make a difference, one donation at a time',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ).animate(delay: 100.ms).fadeIn(duration: 400.ms),

                // Server status indicator
                if (_configError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppTheme.spacingSm),
                    child: GestureDetector(
                      onTap: _loadConfig,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.warningAmber,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$_configError  (tap to retry)',
                            style: const TextStyle(
                              color: AppTheme.warningAmber,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (_configLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: AppTheme.spacingSm),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.accentTeal,
                      ),
                    ),
                  ),

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

/// Currency preset configuration
class _CurrencyPreset {
  final String symbol;
  final List<int> presets;
  final double min;
  final double max;

  _CurrencyPreset({
    required this.symbol,
    required this.presets,
    required this.min,
    required this.max,
  });
}
