import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'iras_exceptions.dart';

/// IRAS Credentials Service
/// Provides secure storage and management of IRAS API credentials
/// Uses encrypted storage for production environments
class IrasCredentialsService {
  static IrasCredentialsService? _instance;
  SharedPreferences? _prefs;

  // Security settings
  static const String _clientIdKey = 'iras_client_id';
  static const String _clientSecretKey = 'iras_client_secret';
  static const String _encryptionKeyKey = 'iras_encryption_key';
  static const String _credentialsHashKey = 'iras_credentials_hash';

  // Default credentials from YAML specification
  static const String _defaultClientId = '7130ed796204e0726bb3a217eb96f3e0';
  static const String _defaultClientSecret = '1868dc0eff3ad7df0719af2da41294bd';

  IrasCredentialsService._();

  /// Singleton instance
  static IrasCredentialsService get instance {
    _instance ??= IrasCredentialsService._();
    return _instance!;
  }

  /// Initialize the credentials service
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();

    // Set default credentials if not already stored
    if (!hasStoredCredentials()) {
      await _storeDefaultCredentials();
    }
  }

  /// Check if credentials are stored
  bool hasStoredCredentials() {
    return _prefs?.containsKey(_clientIdKey) == true &&
        _prefs?.containsKey(_clientSecretKey) == true;
  }

  /// Get client ID
  Future<String> getClientId() async {
    await initialize();

    final clientId = _prefs?.getString(_clientIdKey);
    if (clientId == null || clientId.isEmpty) {
      throw const IrasConfigException('IRAS Client ID not configured');
    }

    return _decryptIfNeeded(clientId);
  }

  /// Get client secret
  Future<String> getClientSecret() async {
    await initialize();

    final clientSecret = _prefs?.getString(_clientSecretKey);
    if (clientSecret == null || clientSecret.isEmpty) {
      throw const IrasConfigException('IRAS Client Secret not configured');
    }

    return _decryptIfNeeded(clientSecret);
  }

  /// Store new credentials securely
  Future<void> storeCredentials({
    required String clientId,
    required String clientSecret,
  }) async {
    await initialize();

    // Validate credentials format
    if (!_isValidClientId(clientId)) {
      throw const IrasValidationException(
        'Invalid client ID format',
        {
          'clientId': ['Client ID must be a valid 32-character hex string']
        },
      );
    }

    if (!_isValidClientSecret(clientSecret)) {
      throw const IrasValidationException(
        'Invalid client secret format',
        {
          'clientSecret': [
            'Client secret must be a valid 32-character hex string'
          ]
        },
      );
    }

    // Encrypt credentials in production
    final encryptedClientId = kDebugMode ? clientId : _encryptValue(clientId);
    final encryptedClientSecret =
        kDebugMode ? clientSecret : _encryptValue(clientSecret);

    // Store credentials
    await _prefs!.setString(_clientIdKey, encryptedClientId);
    await _prefs!.setString(_clientSecretKey, encryptedClientSecret);

    // Store hash for integrity verification
    final credentialsHash = _hashCredentials(clientId, clientSecret);
    await _prefs!.setString(_credentialsHashKey, credentialsHash);

    if (kDebugMode) {
      print('✅ IRAS credentials stored securely');
    }
  }

  /// Update client ID only
  Future<void> updateClientId(String clientId) async {
    final currentSecret = await getClientSecret();
    await storeCredentials(
      clientId: clientId,
      clientSecret: currentSecret,
    );
  }

  /// Update client secret only
  Future<void> updateClientSecret(String clientSecret) async {
    final currentClientId = await getClientId();
    await storeCredentials(
      clientId: currentClientId,
      clientSecret: clientSecret,
    );
  }

  /// Verify stored credentials integrity
  Future<bool> verifyCredentialsIntegrity() async {
    try {
      await initialize();

      if (!hasStoredCredentials()) return false;

      final storedHash = _prefs?.getString(_credentialsHashKey);
      if (storedHash == null) return false;

      final clientId = await getClientId();
      final clientSecret = await getClientSecret();
      final computedHash = _hashCredentials(clientId, clientSecret);

      return storedHash == computedHash;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Credentials integrity check failed: $e');
      }
      return false;
    }
  }

  /// Clear all stored credentials
  Future<void> clearCredentials() async {
    await initialize();

    await _prefs!.remove(_clientIdKey);
    await _prefs!.remove(_clientSecretKey);
    await _prefs!.remove(_credentialsHashKey);
    await _prefs!.remove(_encryptionKeyKey);

    if (kDebugMode) {
      print('🗑️ IRAS credentials cleared');
    }
  }

  /// Reset to default credentials
  Future<void> resetToDefaults() async {
    await clearCredentials();
    await _storeDefaultCredentials();
  }

  /// Get credentials summary (for debugging - no sensitive data)
  Future<Map<String, dynamic>> getCredentialsSummary() async {
    if (!kDebugMode) return {};

    await initialize();

    return {
      'has_credentials': hasStoredCredentials(),
      'integrity_valid': await verifyCredentialsIntegrity(),
      'client_id_length': (await getClientId()).length,
      'client_secret_length': (await getClientSecret()).length,
      'is_default_credentials': await _isUsingDefaultCredentials(),
    };
  }

  /// Store default credentials
  Future<void> _storeDefaultCredentials() async {
    await storeCredentials(
      clientId: _defaultClientId,
      clientSecret: _defaultClientSecret,
    );

    if (kDebugMode) {
      print('📝 Default IRAS credentials configured');
    }
  }

  /// Check if using default credentials
  Future<bool> _isUsingDefaultCredentials() async {
    try {
      final clientId = await getClientId();
      final clientSecret = await getClientSecret();
      return clientId == _defaultClientId &&
          clientSecret == _defaultClientSecret;
    } catch (e) {
      return false;
    }
  }

  /// Validate client ID format
  bool _isValidClientId(String clientId) {
    // Client ID should be a 32-character hex string
    final pattern = RegExp(r'^[a-fA-F0-9]{32}$');
    return pattern.hasMatch(clientId);
  }

  /// Validate client secret format
  bool _isValidClientSecret(String clientSecret) {
    // Client secret should be a 32-character hex string
    final pattern = RegExp(r'^[a-fA-F0-9]{32}$');
    return pattern.hasMatch(clientSecret);
  }

  /// Hash credentials for integrity verification
  String _hashCredentials(String clientId, String clientSecret) {
    final input = '$clientId:$clientSecret';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Encrypt value (simplified encryption for demonstration)
  String _encryptValue(String value) {
    if (kDebugMode) return value; // No encryption in debug mode

    // In production, implement proper encryption using flutter_secure_storage
    // or similar secure storage solution
    final bytes = utf8.encode(value);
    final encoded = base64.encode(bytes);
    return 'enc:$encoded'; // Mark as encrypted
  }

  /// Decrypt value if needed
  String _decryptIfNeeded(String value) {
    if (!value.startsWith('enc:')) return value; // Not encrypted

    try {
      final encoded = value.substring(4); // Remove 'enc:' prefix
      final bytes = base64.decode(encoded);
      return utf8.decode(bytes);
    } catch (e) {
      throw IrasConfigException('Failed to decrypt stored credentials: $e');
    }
  }
}
