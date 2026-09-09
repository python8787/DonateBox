/// DonateBox - App Configuration
///
/// API URLs and app-wide constants.
/// Never put secret keys here — secrets stay on the backend only.

class AppConfig {
  // API Base URL - change for production
  static const String apiBaseUrl = 'http://10.0.2.2:8000/api/v1'; // Android emulator localhost
  static const String apiBaseUrlIos = 'http://localhost:8000/api/v1'; // iOS simulator

  // App Info
  static const String appName = 'DonateBox';
  static const String appVersion = '1.0.0';

  // Razorpay (public key only — secret is NEVER in the app)
  static const String razorpayKeyId = 'rzp_test_xxxxxxxxxxxx'; // Replace with your test key

  // Stripe (publishable key only — secret is NEVER in the app)
  static const String stripePublishableKey = 'pk_test_xxxxxxxxxxxx'; // Replace with your test key

  // Animation durations
  static const Duration splashDuration = Duration(milliseconds: 2000);
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationMedium = Duration(milliseconds: 400);
  static const Duration animationSlow = Duration(milliseconds: 600);

  // Input limits
  static const int maxNameLength = 100;

  // Policy URLs (served by backend)
  static const String privacyPolicyUrl = 'http://10.0.2.2:8000/policy/privacy';
  static const String termsOfServiceUrl = 'http://10.0.2.2:8000/policy/terms';
  static const String refundPolicyUrl = 'http://10.0.2.2:8000/policy/refund';
}
