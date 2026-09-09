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

/// Payment initialization response from backend.
class PaymentInitData {
  final String paymentId;
  final String provider;
  final Map<String, dynamic> providerData;

  PaymentInitData({
    required this.paymentId,
    required this.provider,
    required this.providerData,
  });

  factory PaymentInitData.fromJson(Map<String, dynamic> json) {
    return PaymentInitData(
      paymentId: json['payment_id'] as String,
      provider: json['provider'] as String,
      providerData: json['provider_data'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Razorpay order ID
  String? get razorpayOrderId => providerData['order_id'] as String?;

  /// Stripe client secret
  String? get stripeClientSecret => providerData['client_secret'] as String?;
}
