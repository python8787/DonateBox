import 'dart:async';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../models/donation.dart';

/// DonateBox — Payment Client Service
///
/// Launches native payment UIs (Razorpay for INR).
/// Stripe support can be added later when available.
/// This code NEVER handles secrets — it only uses public keys and
/// client-side tokens provided by the backend.

class PaymentResult {
  final bool success;
  final Map<String, dynamic> data;
  final String? error;
  final bool wasCancelled;

  PaymentResult({
    required this.success,
    this.data = const {},
    this.error,
    this.wasCancelled = false,
  });
}

class PaymentClientService {
  static Razorpay? _razorpay;

  /// Launch payment based on provider.
  static Future<PaymentResult> launchPayment(PaymentInitData initData) async {
    if (initData.provider == 'razorpay') {
      return _launchRazorpay(initData);
    } else if (initData.provider == 'stripe') {
      // Stripe not yet available — return friendly message
      return PaymentResult(
        success: false,
        error: 'USD payments via Stripe are not yet available. Please use INR.',
      );
    } else {
      return PaymentResult(
        success: false,
        error: 'Unknown payment provider: ${initData.provider}',
      );
    }
  }

  /// Launch Razorpay native checkout.
  static Future<PaymentResult> _launchRazorpay(PaymentInitData initData) async {
    _razorpay?.clear();
    _razorpay = Razorpay();

    final completer = Completer<PaymentResult>();

    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
      if (!completer.isCompleted) {
        completer.complete(PaymentResult(
          success: true,
          data: {
            'razorpay_payment_id': response.paymentId ?? '',
            'razorpay_order_id': response.orderId ?? '',
            'razorpay_signature': response.signature ?? '',
          },
        ));
      }
    });

    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
      if (!completer.isCompleted) {
        final code = response.code ?? 0;
        // Code 2 = user cancelled/dismissed
        final cancelled = code == 2;
        completer.complete(PaymentResult(
          success: false,
          error: response.message ?? 'Payment failed',
          wasCancelled: cancelled,
        ));
      }
    });

    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse response) {
      if (!completer.isCompleted) {
        completer.complete(PaymentResult(
          success: false,
          error: 'External wallet selected: ${response.walletName}. Payment is being processed.',
          wasCancelled: false,
        ));
      }
    });

    // Build checkout options from backend-provided data
    final options = {
      'key': initData.razorpayKey,
      'order_id': initData.razorpayOrderId,
      'amount': initData.razorpayAmount,
      'currency': 'INR',
      'name': 'DonateBox',
      'description': initData.razorpayDescription ?? 'Donation',
      'prefill': initData.paymentInitData['prefill'] ?? {},
      'theme': {
        'color': '#7C3AED', // Match app's primary purple
      },
    };

    try {
      _razorpay!.open(options);
      return await completer.future;
    } catch (e) {
      debugPrint('Razorpay launch error: $e');
      return PaymentResult(
        success: false,
        error: 'Failed to open payment: $e',
      );
    } finally {
      _razorpay?.clear();
      _razorpay = null;
    }
  }
}
