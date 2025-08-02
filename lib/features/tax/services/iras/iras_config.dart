import 'package:flutter/foundation.dart';
import 'iras_credentials_service.dart';

/// IRAS API configuration service
/// Manages API endpoints, credentials, and environment settings
/// Updated to match official YAML specifications
class IrasConfig {
  static const String _baseUrl = 'https://apiservices.iras.gov.sg/iras/prod';
  
  // Production API paths based on YAML specifications
  static const String _authPath = '';
  static const String _gstListingPath = '/GSTListing';
  static const String _gstReturnPath = '/GST';
  static const String _employmentPath = '/EmpIncomeRecords';
  static const String _corporateTaxPath = '/ct';
  
  // Client credentials service for secure storage
  static final IrasCredentialsService _credentialsService = IrasCredentialsService.instance;
  
  /// Get base API URL
  static String get baseUrl => _baseUrl;
  
  /// Authentication endpoints (SingPass Authentication API)
  static String get authBaseUrl => '$_baseUrl$_authPath';
  static String get singPassAuthUrl => '$authBaseUrl/SingPassServiceAuth';
  static String get singPassTokenUrl => '$authBaseUrl/SingPassServiceAuthToken';
  
  /// GST Register Check endpoints (Check_GST_Register-1.0.7.yaml)
  static String get gstListingBaseUrl => '$_baseUrl$_gstListingPath';
  static String get gstRegisterCheckUrl => '$gstListingBaseUrl/SearchGSTRegistered';
  
  /// GST Return endpoints (File_GST_Return and Edit_Past_GST_Return YAML specs)
  static String get gstReturnBaseUrl => '$_baseUrl$_gstReturnPath';
  static String get gstF5SubmissionUrl => '$gstReturnBaseUrl/SubmitF5ReturnCorpPass';
  static String get gstF8SubmissionUrl => '$gstReturnBaseUrl/SubmitF8ReturnCorpPass';
  static String get gstF7EditUrl => '$gstReturnBaseUrl/EditF7ReturnCorpPass';
  static String get gstTransactionListingUrl => '$gstReturnBaseUrl/SubmitGSTTransactionListingCorpPass';
  
  /// Employment Income Records endpoints (Submission_of_Employment_Income_Records-1.0.6.yaml)
  static String get employmentBaseUrl => '$_baseUrl$_employmentPath';
  static String get employmentSubmissionUrl => '$employmentBaseUrl/Submit';
  
  /// Corporate Tax endpoints (CIT_Conversion-1.0.8.yaml)
  static String get corporateTaxBaseUrl => '$_baseUrl$_corporateTaxPath';
  static String get citConversionUrl => '$corporateTaxBaseUrl/convertformcs';
  
  /// Client credentials (async - retrieved from secure storage)
  static Future<String> getClientId() => _credentialsService.getClientId();
  static Future<String> getClientSecret() => _credentialsService.getClientSecret();
  
  /// Client credentials (sync - for backwards compatibility)
  /// Note: These will use default values and should be migrated to async versions
  static String get clientId => '7130ed796204e0726bb3a217eb96f3e0';
  static String get clientSecret => '1868dc0eff3ad7df0719af2da41294bd';
  
  /// Common headers for all IRAS API calls (sync version)
  static Map<String, String> get commonHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-IBM-Client-Id': clientId,
    'X-IBM-Client-Secret': clientSecret,
  };
  
  /// Common headers for all IRAS API calls (async version with secure credentials)
  static Future<Map<String, String>> getCommonHeaders() async => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-IBM-Client-Id': await getClientId(),
    'X-IBM-Client-Secret': await getClientSecret(),
  };
  
  /// Get headers with access token for authenticated calls (sync version)
  static Map<String, String> getAuthenticatedHeaders(String accessToken) => {
    ...commonHeaders,
    'access_token': accessToken,
  };
  
  /// Get headers with access token for authenticated calls (async version)
  static Future<Map<String, String>> getAuthenticatedHeadersAsync(String accessToken) async => {
    ...await getCommonHeaders(),
    'access_token': accessToken,
  };
  
  /// Timeout configurations
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const Duration authTimeout = Duration(seconds: 45);
  
  /// Retry configurations
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  /// Validation (sync version)
  static bool get isConfigured => 
      clientId.isNotEmpty && 
      clientSecret.isNotEmpty;
  
  /// Validation (async version with secure credentials)
  static Future<bool> isConfiguredAsync() async {
    try {
      final id = await getClientId();
      final secret = await getClientSecret();
      return id.isNotEmpty && secret.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Initialize secure credentials
  static Future<void> initializeCredentials() async {
    await _credentialsService.initialize();
  }
  
  /// Verify credentials integrity
  static Future<bool> verifyCredentials() async {
    return await _credentialsService.verifyCredentialsIntegrity();
  }
  
  /// Get credentials summary (debug only)
  static Future<Map<String, dynamic>> getCredentialsSummary() async {
    return await _credentialsService.getCredentialsSummary();
  }
  
  /// Debug logging
  static void logApiCall(String endpoint, Map<String, dynamic>? data) {
    if (kDebugMode) {
      print('🔗 IRAS API Call: $endpoint');
      if (data != null) {
        print('📤 Request data keys: ${data.keys.toList()}');
      }
    }
  }
  
  static void logApiResponse(String endpoint, int statusCode, dynamic response) {
    if (kDebugMode) {
      print('📥 IRAS API Response: $endpoint - Status: $statusCode');
      if (response is Map && response.containsKey('returnCode')) {
        print('   Return Code: ${response['returnCode']}');
      }
    }
  }
  
  static void logApiError(String endpoint, dynamic error) {
    if (kDebugMode) {
      print('❌ IRAS API Error: $endpoint - $error');
    }
  }
}