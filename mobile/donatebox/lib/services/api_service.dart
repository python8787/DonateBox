import 'dart:async' as async_lib;
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/donation_config.dart';

/// DonateBox - API Service
///
/// Handles all communication with the FastAPI backend.
/// Payment secrets are NEVER sent from or stored in the app.
///
/// Features:
///  - Typed error classes for UI-friendly messages
///  - Automatic retry on transient failures (timeout, 5xx)
///  - Consistent timeout handling

// --- Custom exceptions ---

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  NetworkException([String? message])
      : super(message ??
            'Unable to connect. Please check your internet connection and try again.');
}

class ApiTimeoutException extends ApiException {
  ApiTimeoutException([String? message])
      : super(message ?? 'The request timed out. Please try again.');
}

class ServerException extends ApiException {
  ServerException([String? message, int? statusCode])
      : super(
            message ??
                'Something went wrong on the server. Please try again later.',
            statusCode: statusCode);
}

class ValidationException extends ApiException {
  ValidationException(String message, {int? statusCode})
      : super(message, statusCode: statusCode);
}

class RateLimitException extends ApiException {
  RateLimitException([String? message])
      : super(message ??
            'Too many requests. Please wait a moment and try again.');
}

class ApiService {
  static const int _maxRetries = 2;
  static const Duration _defaultTimeout = Duration(seconds: 15);
  static const Duration _shortTimeout = Duration(seconds: 5);

  static String get baseUrl {
    if (Platform.isAndroid) {
      return AppConfig.apiBaseUrl;
    }
    return AppConfig.apiBaseUrlIos;
  }

  // --- Core HTTP helpers with retry ---

  /// Execute a GET request with retry and error handling.
  static Future<http.Response> _get(
    String path, {
    Duration timeout = _defaultTimeout,
    int retries = _maxRetries,
  }) async {
    return _withRetry(
      () => http.get(Uri.parse('$baseUrl$path')).timeout(timeout),
      retries: retries,
    );
  }

  /// Execute a POST request with retry and error handling.
  static Future<http.Response> _post(
    String path, {
    required Map<String, dynamic> body,
    Duration timeout = _defaultTimeout,
    int retries = _maxRetries,
  }) async {
    return _withRetry(
      () => http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(timeout),
      retries: retries,
    );
  }

  /// Retry wrapper for transient failures (timeouts, network errors, 5xx).
  static Future<http.Response> _withRetry(
    Future<http.Response> Function() request, {
    int retries = _maxRetries,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        final response = await request();

        // Don't retry client errors (4xx) — they won't change.
        // Do retry server errors (5xx) up to the limit.
        if (response.statusCode >= 500 && attempt < retries) {
          attempt++;
          await Future.delayed(Duration(milliseconds: 500 * attempt));
          continue;
        }

        return response;
      } on SocketException {
        if (attempt < retries) {
          attempt++;
          await Future.delayed(Duration(milliseconds: 500 * attempt));
          continue;
        }
        throw NetworkException();
      } on async_lib.TimeoutException {
        if (attempt < retries) {
          attempt++;
          await Future.delayed(Duration(milliseconds: 500 * attempt));
          continue;
        }
        throw ApiTimeoutException();
      } on HandshakeException {
        throw NetworkException('Secure connection failed. Please try again.');
      } catch (e) {
        if (e is ApiException) rethrow;
        if (attempt < retries) {
          attempt++;
          await Future.delayed(Duration(milliseconds: 500 * attempt));
          continue;
        }
        throw NetworkException();
      }
    }
  }

  /// Parse an error response body into a user-friendly exception.
  static ApiException _parseError(http.Response response) {
    if (response.statusCode == 429) {
      return RateLimitException();
    }

    String message;
    try {
      final body = json.decode(response.body);
      message = body['detail'] ?? 'Request failed';
    } catch (_) {
      message = 'Request failed (${response.statusCode})';
    }

    if (response.statusCode >= 500) {
      return ServerException(message, response.statusCode);
    }
    return ValidationException(message, statusCode: response.statusCode);
  }

  // --- Public API methods ---

  /// Get donation configuration from backend.
  /// Amount limits and presets come from here — not hardcoded.
  static Future<DonationConfig> getDonationConfig() async {
    final response =
        await _get('/donations/config', timeout: const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return DonationConfig.fromJson(json.decode(response.body));
    }
    throw _parseError(response);
  }

  /// Create a new donation.
  static Future<Map<String, dynamic>> createDonation({
    String? name,
    required double amount,
    required String currency,
    required String termsVersion,
  }) async {
    final response = await _post(
      '/donations',
      body: {
        'name': name,
        'amount': amount,
        'currency': currency,
        'terms_version': termsVersion,
        'terms_accepted': true,
      },
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    }
    throw _parseError(response);
  }

  /// Create a payment order for a donation.
  static Future<Map<String, dynamic>> createPayment(String donationId) async {
    final response = await _post(
      '/donations/$donationId/payment',
      body: {},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw _parseError(response);
  }

  /// Verify a payment after completion.
  static Future<Map<String, dynamic>> verifyPayment({
    required String donationId,
    required Map<String, dynamic> paymentData,
  }) async {
    final response = await _post(
      '/payments/verify',
      body: {
        'donation_id': donationId,
        'payment_data': paymentData,
      },
      retries: 1, // Fewer retries for verification — idempotent but sensitive
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw _parseError(response);
  }

  /// Health check — returns true if backend is reachable.
  static Future<bool> checkHealth() async {
    try {
      final response =
          await _get('/health', timeout: _shortTimeout, retries: 0);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
