import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../models/iras/singpass_auth_models.dart';
import 'iras_client.dart';
import 'iras_config.dart';
import 'iras_exceptions.dart';
import 'iras_audit_service.dart';

/// IRAS SingPass Authentication Service
/// Based on SingPass_Authentication-apigw-2.0.1.yaml specification
/// Handles SingPass OAuth 2.0 authentication flow for IRAS APIs
class IrasSingPassAuthService {
  final IrasApiClient _client;
  final IrasAuditService _auditService;
  static IrasSingPassAuthService? _instance;
  
  // Store active authentication states
  final Map<String, SingPassAuthState> _authStates = {};
  
  IrasSingPassAuthService._({
    IrasApiClient? client,
    IrasAuditService? auditService,
  }) : _client = client ?? IrasApiClient.instance,
       _auditService = auditService ?? IrasAuditService.instance;
  
  /// Singleton instance
  static IrasSingPassAuthService get instance {
    _instance ??= IrasSingPassAuthService._();
    return _instance!;
  }
  
  /// Step 1: Initiate SingPass authentication
  /// Returns authorization URL for user to complete SingPass login
  Future<String> initiateAuthentication({
    required String callbackUrl,
    List<SingPassScope>? scopes,
    String? state,
  }) async {
    const operation = 'SINGPASS_AUTH_INITIATE';
    
    try {
      // Generate state if not provided
      final authState = state ?? _generateState();
      
      // Validate callback URL
      if (!_isValidCallbackUrl(callbackUrl)) {
        throw const IrasValidationException(
          'Invalid callback URL',
          {'callback_url': ['Must be a valid HTTPS URL']},
        );
      }
      
      // Prepare scope string
      final scopeString = scopes?.map((s) => s.value).join(' ') ?? 
                         SingPassScope.corppass.value;
      
      await _auditService.logOperation(
        operation: operation,
        entityType: 'SINGPASS_AUTH',
        entityId: authState,
        details: {
          'callback_url': callbackUrl,
          'scopes': scopeString,
          'has_custom_state': state != null,
        },
      );
      
      final request = SingPassAuthRequest(
        scope: scopeString,
        callbackUrl: callbackUrl,
        state: authState,
      );
      
      // Store auth state for later validation
      _authStates[authState] = SingPassAuthState(
        state: authState,
        callbackUrl: callbackUrl,
        scope: scopeString,
        createdAt: DateTime.now(),
      );
      
      // Make GET request to SingPass auth endpoint
      final responseData = await _client.get(
        IrasConfig.singPassAuthUrl,
        queryParams: request.toQueryParams(),
      );
      
      final response = SingPassAuthResponse.fromJson(responseData);
      
      if (response.isSuccess) {
        await _auditService.logSuccess(
          operation: operation,
          entityType: 'SINGPASS_AUTH',
          entityId: authState,
          details: {
            'auth_url_generated': response.data?.authUrl != null,
          },
        );
        
        // In a real implementation, this would return the auth URL
        // For now, we'll construct it based on SingPass standards
        final authUrl = response.data?.authUrl ?? 
                       _constructAuthUrl(callbackUrl, scopeString, authState);
        
        if (kDebugMode) {
          print('✅ SingPass authentication initiated');
          print('🔗 Authorization URL: $authUrl');
          print('🔑 State: $authState');
        }
        
        return authUrl;
      } else {
        await _auditService.logFailure(
          operation: operation,
          entityType: 'SINGPASS_AUTH',
          entityId: authState,
          error: 'SingPass auth initiation failed: ${response.returnCode}',
          details: response.info?.toJson(),
        );
        
        throw IrasApiException(
          'Failed to initiate SingPass authentication',
          response.returnCode,
          response.info?.toJson(),
        );
      }
    } catch (e) {
      await _auditService.logFailure(
        operation: operation,
        entityType: 'SINGPASS_AUTH',
        entityId: state ?? 'unknown',
        error: 'Failed to initiate authentication: $e',
      );
      rethrow;
    }
  }
  
  /// Step 2: Exchange authorization code for access token
  Future<String> exchangeCodeForToken({
    required String authorizationCode,
    required String state,
  }) async {
    const operation = 'SINGPASS_TOKEN_EXCHANGE';
    
    try {
      // Validate state and get stored auth state
      final authState = _authStates[state];
      if (authState == null) {
        throw const IrasValidationException(
          'Invalid or expired authentication state',
          {'state': ['Authentication state not found or expired']},
        );
      }
      
      if (authState.hasExpired) {
        _authStates.remove(state);
        throw const IrasValidationException(
          'Authentication state has expired',
          {'state': ['Please restart the authentication process']},
        );
      }
      
      await _auditService.logOperation(
        operation: operation,
        entityType: 'SINGPASS_TOKEN',
        entityId: state,
        details: {
          'has_authorization_code': authorizationCode.isNotEmpty,
          'auth_initiated_at': authState.createdAt.toIso8601String(),
        },
      );
      
      final request = SingPassTokenRequest(
        authorizationCode: authorizationCode,
        state: state,
      );
      
      // Exchange code for token
      final responseData = await _client.post(
        IrasConfig.singPassTokenUrl,
        request.toJson(),
      );
      
      final response = SingPassTokenResponse.fromJson(responseData);
      
      if (response.isSuccess && response.data?.token != null) {
        final token = response.data!.token!;
        final expiresIn = response.data!.expiresIn ?? 3600; // Default 1 hour
        final tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
        
        // Update auth state with token
        _authStates[state] = authState.copyWith(
          authorizationCode: authorizationCode,
          accessToken: token,
          tokenExpiry: tokenExpiry,
        );
        
        await _auditService.logSuccess(
          operation: operation,
          entityType: 'SINGPASS_TOKEN',
          entityId: state,
          details: {
            'token_received': true,
            'token_type': response.data?.tokenType ?? 'Bearer',
            'expires_in': expiresIn,
            'token_expiry': tokenExpiry.toIso8601String(),
          },
        );
        
        if (kDebugMode) {
          print('✅ SingPass token exchange successful');
          print('⏰ Token expires at: $tokenExpiry');
        }
        
        return token;
      } else {
        await _auditService.logFailure(
          operation: operation,
          entityType: 'SINGPASS_TOKEN',
          entityId: state,
          error: 'Token exchange failed: ${response.returnCode}',
          details: response.info?.toJson(),
        );
        
        throw IrasApiException(
          'Failed to exchange authorization code for token',
          response.returnCode,
          response.info?.toJson(),
        );
      }
    } catch (e) {
      await _auditService.logFailure(
        operation: operation,
        entityType: 'SINGPASS_TOKEN',
        entityId: state,
        error: 'Failed to exchange code for token: $e',
      );
      rethrow;
    }
  }
  
  /// Get stored access token for a state
  String? getAccessToken(String state) {
    final authState = _authStates[state];
    if (authState == null || !authState.isTokenValid) {
      return null;
    }
    return authState.accessToken;
  }
  
  /// Check if access token is valid for a state
  bool isTokenValid(String state) {
    final authState = _authStates[state];
    return authState?.isTokenValid ?? false;
  }
  
  /// Refresh access token (if refresh token is available)
  Future<String?> refreshToken(String state) async {
    final authState = _authStates[state];
    if (authState == null) return null;
    
    // Note: Implementation would depend on whether IRAS supports refresh tokens
    // For now, return null indicating refresh is not available
    if (kDebugMode) {
      print('ℹ️ Token refresh not implemented - user needs to re-authenticate');
    }
    return null;
  }
  
  /// Clear authentication state
  void clearAuthState(String state) {
    _authStates.remove(state);
  }
  
  /// Clear all expired authentication states
  void clearExpiredStates() {
    final now = DateTime.now();
    _authStates.removeWhere((key, value) => 
        value.hasExpired || 
        (value.tokenExpiry != null && now.isAfter(value.tokenExpiry!))
    );
  }
  
  /// Execute an authenticated request using stored token
  Future<Map<String, dynamic>> executeAuthenticatedRequest(
    String state,
    Future<Map<String, dynamic>> Function(String token) request,
  ) async {
    final token = getAccessToken(state);
    if (token == null) {
      throw const IrasAuthenticationException(
        'No valid access token available - please authenticate first',
      );
    }
    
    try {
      return await request(token);
    } catch (e) {
      // If authentication fails, clear the token
      if (e is IrasAuthenticationException) {
        clearAuthState(state);
      }
      rethrow;
    }
  }
  
  /// Generate a secure random state string
  String _generateState() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    final length = 32;
    
    return List.generate(length, (index) => chars[random.nextInt(chars.length)]).join();
  }
  
  /// Validate callback URL format
  bool _isValidCallbackUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.isScheme('https') && uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Construct SingPass authorization URL (fallback)
  String _constructAuthUrl(String callbackUrl, String scope, String state) {
    // This is a fallback implementation
    // In real implementation, the actual auth URL would be returned by the API
    final encodedCallback = Uri.encodeComponent(callbackUrl);
    final encodedScope = Uri.encodeComponent(scope);
    final encodedState = Uri.encodeComponent(state);
    
    return 'https://saml.singpass.gov.sg/FIM/sps/SingpassIDPDev/saml20/logininitial?RequestBinding=HTTPPost'
           '&ResponseBinding=HTTPPost&PartnerId=IRAS&Target=${encodedCallback}'
           '&scope=${encodedScope}&state=${encodedState}';
  }
  
  /// Get summary of all active auth states (for debugging)
  Map<String, Map<String, dynamic>> getActiveAuthStates() {
    if (!kDebugMode) return {};
    
    return _authStates.map((key, value) => MapEntry(key, {
      'created_at': value.createdAt.toIso8601String(),
      'has_token': value.accessToken != null,
      'is_valid': value.isTokenValid,
      'has_expired': value.hasExpired,
      'callback_url': value.callbackUrl,
      'scope': value.scope,
    }));
  }
}