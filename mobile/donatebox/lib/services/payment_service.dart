/// DonateBox - Payment Service (Client Side)
///
/// Handles launching payment gateways from Flutter.
/// NEVER verifies payment success — that's the backend's job.
///
/// Will be implemented in Phase 4.

class PaymentClientService {
  /// Launch Razorpay checkout (INR)
  /// Implemented in Phase 4
  static Future<void> launchRazorpay({
    required String orderId,
    required double amount,
    required String currency,
    required Map<String, dynamic> initData,
  }) async {
    throw UnimplementedError('Razorpay integration coming in Phase 4');
  }

  /// Launch Stripe checkout (USD)
  /// Implemented in Phase 4
  static Future<void> launchStripe({
    required String clientSecret,
    required double amount,
    required String currency,
  }) async {
    throw UnimplementedError('Stripe integration coming in Phase 4');
  }
}
