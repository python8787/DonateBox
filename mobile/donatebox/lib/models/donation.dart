/// DonateBox — Donation Model
///
/// Represents a donation record as returned by the backend API.

class Donation {
  final String id;
  final String? name;
  final double amount;
  final String currency;
  final String status;
  final String termsVersion;
  final String createdAt;

  Donation({
    required this.id,
    this.name,
    required this.amount,
    required this.currency,
    required this.status,
    required this.termsVersion,
    required this.createdAt,
  });

  factory Donation.fromJson(Map<String, dynamic> json) {
    return Donation(
      id: json['id'] as String,
      name: json['name'] as String?,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      status: json['status'] as String,
      termsVersion: json['terms_version'] as String,
      createdAt: json['created_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'currency': currency,
        'status': status,
        'terms_version': termsVersion,
        'created_at': createdAt,
      };

  bool get isSuccess => status == 'SUCCESS';
  bool get isPending => status == 'PENDING' || status == 'CREATED';
  bool get isFailed => status == 'FAILED';
  bool get isCancelled => status == 'CANCELLED';
}

/// Payment initialization data returned by POST /donations/{id}/payment.
///
/// Contains provider name, gateway order ID, and the data
/// Flutter needs to launch the native payment UI.
class PaymentInitData {
  final String provider;
  final String orderId;
  final Map<String, dynamic> paymentInitData;

  PaymentInitData({
    required this.provider,
    required this.orderId,
    required this.paymentInitData,
  });

  factory PaymentInitData.fromJson(Map<String, dynamic> json) {
    return PaymentInitData(
      provider: json['provider'] as String,
      orderId: json['order_id'] as String,
      paymentInitData: json['payment_init_data'] as Map<String, dynamic>? ?? {},
    );
  }

  // ── Razorpay helpers ──

  /// Razorpay API key (public, safe for Flutter)
  String? get razorpayKey => paymentInitData['key'] as String?;

  /// Razorpay order ID
  String? get razorpayOrderId => paymentInitData['order_id'] as String?;

  /// Amount in paise
  int? get razorpayAmount => paymentInitData['amount'] as int?;

  /// Description shown on Razorpay checkout
  String? get razorpayDescription => paymentInitData['description'] as String?;

  // ── Stripe helpers ──

  /// Stripe client secret for PaymentSheet
  String? get stripeClientSecret => paymentInitData['client_secret'] as String?;

  /// Stripe publishable key
  String? get stripePublishableKey => paymentInitData['publishable_key'] as String?;
}
