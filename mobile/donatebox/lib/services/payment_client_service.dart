import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../models/donation.dart';

/// DonateBox — Payment Client Service
///
/// Launches native payment UIs (Razorpay for INR, Stripe for USD).
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
      return _launchStripe(initData);
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

    final completer = _RazorpayCompleter();

    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
      completer.complete(PaymentResult(
        success: true,
        data: {
          'razorpay_payment_id': response.paymentId ?? '',
          'razorpay_order_id': response.orderId ?? '',
          'razorpay_signature': response.signature ?? '',
        },
      ));
    });

    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
      final code = response.code ?? 0;
      // Code 2 = user cancelled/dismissed
      final cancelled = code == 2;
      completer.complete(PaymentResult(
        success: false,
        error: response.message ?? 'Payment failed',
        wasCancelled: cancelled,
      ));
    });

    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse response) {
      // External wallet selected — treat as pending
      completer.complete(PaymentResult(
        success: false,
        error: 'External wallet selected: ${response.walletName}. Payment is being processed.',
        wasCancelled: false,
      ));
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

  /// Launch Stripe PaymentSheet.
  static Future<PaymentResult> _launchStripe(PaymentInitData initData) async {
    final clientSecret = initData.stripeClientSecret;
    final publishableKey = initData.stripePublishableKey;

    if (clientSecret == null || publishableKey == null) {
      return PaymentResult(
        success: false,
        error: 'Missing Stripe payment configuration',
      );
    }

    try {
      // Initialize Stripe with publishable key
      Stripe.publishableKey = publishableKey;

      // Initialize the payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'DonateBox',
          style: ThemeMode.dark,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Color(0xFF7C3AED),
            ),
          ),
        ),
      );

      // Present the payment sheet
      await Stripe.instance.presentPaymentSheet();

      // If presentPaymentSheet completes without throwing, payment succeeded
      return PaymentResult(
        success: true,
        data: {
          'payment_intent_id': initData.paymentInitData['payment_intent_id'] ?? '',
        },
      );
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        return PaymentResult(
          success: false,
          error: 'Payment was cancelled',
          wasCancelled: true,
        );
      }
      return PaymentResult(
        success: false,
        error: e.error.localizedMessage ?? 'Stripe payment failed',
      );
    } catch (e) {
      debugPrint('Stripe error: $e');
      return PaymentResult(
        success: false,
        error: 'Payment failed: $e',
      );
    }
  }
}

/// Simple completer for Razorpay's callback-based API.
class _RazorpayCompleter {
  PaymentResult? _result;
  void Function(PaymentResult)? _callback;

  Future<PaymentResult> get future {
    if (_result != null) return Future.value(_result!);
    return Future<PaymentResult>((resolve) {
      _callback = resolve;
    });
  }

  void complete(PaymentResult result) {
    _result = result;
    _callback?.call(result);
  }
}
