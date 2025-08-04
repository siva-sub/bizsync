import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'iras_client.dart';
import 'iras_config.dart';
import 'iras_exceptions.dart';

/// Authentication service for IRAS APIs
/// Handles SingPass and CorpPass authentication flows
class IrasAuthService {
  final IrasApiClient _client;
  static IrasAuthService? _instance;

  // Authentication state
  String? _accessToken;
  DateTime? _tokenExpiry;
  String? _currentState;

  IrasAuthService._({IrasApiClient? client})
      : _client = client ?? IrasApiClient.instance;

  /// Singleton instance
  static IrasAuthService get instance {
    _instance ??= IrasAuthService._();
    return _instance!;
  }

  /// Check if currently authenticated
  bool get isAuthenticated =>
      _accessToken != null &&
      _tokenExpiry != null &&
      DateTime.now().isBefore(_tokenExpiry!);

  /// Get current access token (null if not authenticated)
  String? get accessToken => isAuthenticated ? _accessToken : null;

  /// Time until token expires (null if not authenticated)
  Duration? get timeUntilExpiry =>
      isAuthenticated ? _tokenExpiry!.difference(DateTime.now()) : null;

  /// Initiate SingPass authentication flow
  /// Returns the authorization URL for user redirect
  Future<String> initiateSingPassAuth({
    required String callbackUrl,
    required List<String> scopes,
    String? state,
  }) async {
    if (!IrasConfig.isConfigured) {
      throw const IrasConfigException('IRAS API credentials not configured');
    }

    // Generate state parameter if not provided
    _currentState = state ?? _generateState();

    try {
      final response = await _client.get(
        IrasConfig.singPassAuthUrl,
        queryParams: {
          'callback_url': callbackUrl,
          'scope': scopes.join(' '),
          'state': _currentState!,
        },
      );

      final data = response['data'] as Map<String, dynamic>?;
      if (data?['url'] is String) {
        return data!['url'] as String;
      } else {
        throw const IrasAuthException('No authorization URL received');
      }
    } on IrasApiException catch (e) {
      throw IrasAuthException(
          'SingPass auth initiation failed: ${e.userFriendlyMessage}');
    }
  }

  /// Complete SingPass authentication with authorization code
  /// Call this after user returns from SingPass with the code
  Future<void> completeSingPassAuth({
    required String code,
    required String state,
    required String callbackUrl,
    required List<String> scopes,
  }) async {
    // Verify state parameter
    if (_currentState != state) {
      throw const IrasAuthException(
          'Invalid state parameter - possible CSRF attack');
    }

    try {
      final response = await _client.post(
        IrasConfig.singPassTokenUrl,
        {
          'code': code,
          'state': state,
          'callback_url': callbackUrl,
          'scope': scopes.join(' '),
        },
      );

      final data = response['data'] as Map<String, dynamic>?;
      if (data?['token'] is String) {
        _accessToken = data!['token'] as String;

        // Parse JWT to get expiry (simplified - in production use proper JWT library)
        _parseTokenExpiry(_accessToken!);

        _currentState = null; // Clear state after successful auth

        if (kDebugMode) {
          print('✅ SingPass authentication successful');
          print('🔑 Token expires in: ${timeUntilExpiry?.inMinutes} minutes');
        }
      } else {
        throw const IrasAuthException('No access token received');
      }
    } on IrasApiException catch (e) {
      throw IrasAuthException(
          'SingPass auth completion failed: ${e.userFriendlyMessage}');
    }
  }

  /// Clear authentication state (logout)
  void clearAuth() {
    _accessToken = null;
    _tokenExpiry = null;
    _currentState = null;

    if (kDebugMode) {
      print('🔓 IRAS authentication cleared');
    }
  }

  /// Refresh token if needed (automatic)
  Future<void> ensureValidToken() async {
    if (!isAuthenticated) {
      throw const IrasAuthException('Not authenticated - please login first');
    }

    // Check if token expires soon (within 5 minutes)
    final expiresIn = timeUntilExpiry!;
    if (expiresIn.inMinutes < 5) {
      if (kDebugMode) {
        print('⚠️ Token expires soon, consider re-authentication');
      }
      // In a real implementation, you might trigger automatic refresh here
      // For now, we'll just warn the user
    }
  }

  /// Execute authenticated request with automatic token validation
  Future<Map<String, dynamic>> executeAuthenticatedRequest(
    Future<Map<String, dynamic>> Function(String token) request,
  ) async {
    await ensureValidToken();
    return await request(_accessToken!);
  }

  /// Generate random state parameter for CSRF protection
  String _generateState() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = List.generate(
        16,
        (i) => 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'[
            (timestamp + i) % 62]).join();
    return '$timestamp-$random';
  }

  /// Parse JWT token to extract expiry (simplified implementation)
  void _parseTokenExpiry(String token) {
    try {
      // Split JWT token
      final parts = token.split('.');
      if (parts.length != 3) {
        throw const FormatException('Invalid JWT format');
      }

      // Decode payload (add padding if needed)
      String payload = parts[1];
      while (payload.length % 4 != 0) {
        payload += '=';
      }

      final decoded = utf8.decode(base64.decode(payload));
      final payloadData = json.decode(decoded) as Map<String, dynamic>;

      // Extract expiry timestamp
      if (payloadData['exp'] is int) {
        final expTimestamp = payloadData['exp'] as int;
        _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(expTimestamp * 1000);
      } else {
        // Default to 1 hour if no expiry found
        _tokenExpiry = DateTime.now().add(const Duration(hours: 1));
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Could not parse token expiry: $e');
      }
      // Default to 1 hour
      _tokenExpiry = DateTime.now().add(const Duration(hours: 1));
    }
  }

  /// Get common scopes for different IRAS services
  static const Map<String, List<String>> commonScopes = {
    'gst': ['GSTReturnsSub', 'GSTTransListSub'],
    'employment': ['EmpIncomeRecordsSub'],
    'corporate_tax': ['CorporateTaxSub'],
    'full': [
      'GSTReturnsSub',
      'GSTTransListSub',
      'EmpIncomeRecordsSub',
      'CorporateTaxSub'
    ],
  };
}
