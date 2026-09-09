import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/donation_config.dart';

/// DonateBox - API Service
///
/// Handles all communication with the FastAPI backend.
/// Payment secrets are NEVER sent from or stored in the app.

class ApiService {
  static String get baseUrl {
    // Use different base URL for Android emulator vs iOS
    if (Platform.isAndroid) {
      return AppConfig.apiBaseUrl;
    }
    return AppConfig.apiBaseUrlIos;
  }

  /// Get donation configuration from backend
  /// Amount limits and presets come from here — not hardcoded.
  static Future<DonationConfig> getDonationConfig() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/donations/config'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return DonationConfig.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load donation config: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception(
        'Unable to connect to server. Please check your internet connection and try again.',
      );
    }
  }

  /// Create a new donation
  static Future<Map<String, dynamic>> createDonation({
    String? name,
    required double amount,
    required String currency,
    required String termsVersion,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/donations'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'name': name,
              'amount': amount,
              'currency': currency,
              'terms_version': termsVersion,
              'terms_accepted': true,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Failed to create donation');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Unable to connect to server. Please try again.');
    }
  }

  /// Health check
  static Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
