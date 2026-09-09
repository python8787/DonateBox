import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Donation confirmation dialog with terms and mandatory checkbox.
///
/// Proceed button stays DISABLED until the checkbox is ticked.
/// Terms version is recorded with the donation.
class DonationConfirmDialog extends StatefulWidget {
  final double amount;
  final String currency;
  final String currencySymbol;
  final String termsVersion;
  final VoidCallback onProceed;

  const DonationConfirmDialog({
    super.key,
    required this.amount,
    required this.currency,
    required this.currencySymbol,
    required this.termsVersion,
    required this.onProceed,
  });

  @override
  State<DonationConfirmDialog> createState() => _DonationConfirmDialogState();
}

class _DonationConfirmDialogState extends State<DonationConfirmDialog> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppTheme.spacingMd),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 600),
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0x33FFFFFF),
                  Color(0x1AFFFFFF),
                ],
              ),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  'Donation Confirmation',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppTheme.spacingSm),

                // Amount
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMd,
                    vertical: AppTheme.spacingSm,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                  ),
                  child: Text(
                    '${widget.currencySymbol}${widget.amount.toStringAsFixed(2)} ${widget.currency}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentTeal,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMd),

                // Terms text (scrollable)
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _termsText(
                          'I confirm that this is a voluntary donation made by me '
                          'using my own free will and with full understanding of '
                          'the purpose and terms of this donation.',
                        ),
                        _termsText(
                          'I understand that this donation goes directly to an '
                          'individual and is NOT a donation to any registered '
                          'charity, NGO, or nonprofit organization. There are no '
                          'tax benefits, deductions, or exemptions associated with '
                          'this donation.',
                          bold: true,
                        ),
                        _termsText(
                          'I understand that this payment is a donation and that '
                          'I am not purchasing any product or service in return.',
                        ),
                        _termsText(
                          'I understand that once the donation is successfully '
                          'completed, I will have no ownership, claim, or '
                          'entitlement over the donated amount.',
                        ),
                        _termsText(
                          'I understand that the donation is final and '
                          'non-refundable, except where required by applicable '
                          'law or where a transaction is technically reversed by '
                          'the payment provider.',
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () {
                              // TODO: Open rules and policies page
                            },
                            child: const Text(
                              'I have read and agree to the Rules and Policies.',
                              style: TextStyle(
                                color: AppTheme.accentTeal,
                                decoration: TextDecoration.underline,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMd),

                // Checkbox
                GestureDetector(
                  onTap: () => setState(() => _accepted = !_accepted),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: _accepted ? AppTheme.buttonGradient : null,
                          border: Border.all(
                            color: _accepted
                                ? Colors.transparent
                                : AppTheme.glassBorder,
                            width: 2,
                          ),
                        ),
                        child: _accepted
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: AppTheme.spacingSm),
                      const Expanded(
                        child: Text(
                          'I accept all the rules and policies and confirm the above.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLg),

                // Proceed button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _accepted ? 1.0 : 0.4,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        gradient: _accepted
                            ? AppTheme.buttonGradient
                            : const LinearGradient(
                                colors: [Colors.grey, Colors.grey],
                              ),
                      ),
                      child: ElevatedButton(
                        onPressed: _accepted ? widget.onProceed : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMedium),
                          ),
                        ),
                        child: const Text(
                          'Proceed to Pay',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Terms version footer
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  'Terms v${widget.termsVersion}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _termsText(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          height: 1.5,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}
