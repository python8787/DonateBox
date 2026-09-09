import 'dart:io';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../models/donation_config.dart';

/// DonateBox — API Service
///
/// Handles all communication with the FastAPI backend.
/// Payment secrets are NEVER sent from or stored in the app.
class ApiService {
  static Dio? _dio;

  static String get baseUrl {
    if (Platform.isAndroid) {
      return AppConfig.apiBaseUrl;
    }
    return AppConfig.apiBaseUrlIos;
  }

  static Dio get dio {
    _dio ??= Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    return _dio!;
  }

  /// Get donation configuration from backend.
  /// Amount limits and presets come from here — not hardcoded.
  static Future<DonationConfig> getDonationConfig() async {
    try {
      final response = await dio.get('/donations/config');
      return DonationConfig.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Create a new donation record on the backend.
  static Future<Map<String, dynamic>> createDonation({
    String? name,
    required double amount,
    required String currency,
    required String termsVersion,
  }) async {
    try {
      final response = await dio.post(
        '/donations',
        data: {
          'name': name,
          'amount': amount,
          'currency': currency,
          'terms_version': termsVersion,
          'terms_accepted': true,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Create a payment order for a donation.
  /// Returns provider info + data to launch payment UI.
  static Future<Map<String, dynamic>> createPayment({
    required String donationId,
  }) async {
    try {
      final response = await dio.post(
        '/donations/$donationId/payment',
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Verify a payment after the user completes it.
  /// The backend checks with the gateway — never trust the client.
  static Future<Map<String, dynamic>> verifyPayment({
    required String donationId,
    required Map<String, dynamic> paymentData,
  }) async {
    try {
      final response = await dio.post(
        '/payments/verify',
        data: {
          'donation_id': donationId,
          'payment_data': paymentData,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Health check
  static Future<bool> checkHealth() async {
    try {
      final response = await dio.get('/health');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Convert Dio errors into user-friendly messages.
  static Exception _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Exception('Connection timed out. Please check your internet and try again.');
      case DioExceptionType.connectionError:
        return Exception('Unable to connect to server. Please check your internet connection.');
      case DioExceptionType.badResponse:
        final data = e.response?.data;
        if (data is Map && data.containsKey('detail')) {
          return Exception(data['detail']);
        }
        return Exception('Server error (${e.response?.statusCode}). Please try again.');
      default:
        return Exception('Something went wrong. Please try again.');
    }
  }
}
