/// DonateBox - Donation Configuration Model
///
/// Loaded from the backend — amounts and presets are
/// server-controlled, never hardcoded in the client.

class CurrencyConfig {
  final double minAmount;
  final double maxAmount;
  final List<int> presets;

  CurrencyConfig({
    required this.minAmount,
    required this.maxAmount,
    required this.presets,
  });

  factory CurrencyConfig.fromJson(Map<String, dynamic> json) {
    return CurrencyConfig(
      minAmount: (json['min_amount'] as num).toDouble(),
      maxAmount: (json['max_amount'] as num).toDouble(),
      presets: (json['presets'] as List).map((e) => e as int).toList(),
    );
  }
}

class DonationConfig {
  final Map<String, CurrencyConfig> currencies;
  final String termsVersion;
  final String recipientName;

  DonationConfig({
    required this.currencies,
    required this.termsVersion,
    required this.recipientName,
  });

  factory DonationConfig.fromJson(Map<String, dynamic> json) {
    final currencyMap = <String, CurrencyConfig>{};
    (json['currencies'] as Map<String, dynamic>).forEach((key, value) {
      currencyMap[key] = CurrencyConfig.fromJson(value);
    });
    return DonationConfig(
      currencies: currencyMap,
      termsVersion: json['terms_version'] as String,
      recipientName: json['recipient_name'] as String,
    );
  }

  /// Get config for a specific currency
  CurrencyConfig? getConfig(String currency) => currencies[currency];

  /// Available currency codes
  List<String> get availableCurrencies => currencies.keys.toList();
}
