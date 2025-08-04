import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:shared_preferences/shared_preferences.dart';

// Biometric authentication result
enum BiometricAuthResult {
  success,
  failure,
  unavailable,
  notSetup,
  cancelled,
  error,
}

// Biometric authentication configuration
class BiometricConfig {
  final bool enabled;
  final bool requireForSensitiveData;
  final bool requireForAppLaunch;
  final Duration sessionTimeout;

  const BiometricConfig({
    this.enabled = false,
    this.requireForSensitiveData = true,
    this.requireForAppLaunch = false,
    this.sessionTimeout = const Duration(minutes: 15),
  });

  BiometricConfig copyWith({
    bool? enabled,
    bool? requireForSensitiveData,
    bool? requireForAppLaunch,
    Duration? sessionTimeout,
  }) {
    return BiometricConfig(
      enabled: enabled ?? this.enabled,
      requireForSensitiveData:
          requireForSensitiveData ?? this.requireForSensitiveData,
      requireForAppLaunch: requireForAppLaunch ?? this.requireForAppLaunch,
      sessionTimeout: sessionTimeout ?? this.sessionTimeout,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'requireForSensitiveData': requireForSensitiveData,
      'requireForAppLaunch': requireForAppLaunch,
      'sessionTimeoutMinutes': sessionTimeout.inMinutes,
    };
  }

  static BiometricConfig fromJson(Map<String, dynamic> json) {
    return BiometricConfig(
      enabled: json['enabled'] ?? false,
      requireForSensitiveData: json['requireForSensitiveData'] ?? true,
      requireForAppLaunch: json['requireForAppLaunch'] ?? false,
      sessionTimeout: Duration(minutes: json['sessionTimeoutMinutes'] ?? 15),
    );
  }
}

// Biometric capabilities
class BiometricCapabilities {
  final bool isAvailable;
  final bool canCheckBiometrics;
  final List<BiometricType> availableBiometrics;
  final bool isDeviceSupported;

  const BiometricCapabilities({
    required this.isAvailable,
    required this.canCheckBiometrics,
    required this.availableBiometrics,
    required this.isDeviceSupported,
  });

  bool get hasFaceID => availableBiometrics.contains(BiometricType.face);
  bool get hasFingerprint =>
      availableBiometrics.contains(BiometricType.fingerprint);
  bool get hasIris => availableBiometrics.contains(BiometricType.iris);
  bool get hasAny => availableBiometrics.isNotEmpty;

  String get primaryBiometricName {
    if (hasFingerprint) return 'Fingerprint';
    if (hasFaceID) return 'Face ID';
    if (hasIris) return 'Iris';
    return 'Biometric';
  }
}

// Biometric authentication service
class BiometricAuthService extends ChangeNotifier {
  static const String _configKey = 'biometric_config';
  static const String _lastAuthKey = 'last_biometric_auth';

  final LocalAuthentication _localAuth = LocalAuthentication();
  BiometricConfig _config = const BiometricConfig();
  BiometricCapabilities? _capabilities;
  DateTime? _lastAuthTime;
  SharedPreferences? _prefs;

  BiometricConfig get config => _config;
  BiometricCapabilities? get capabilities => _capabilities;
  bool get isSessionValid {
    if (_lastAuthTime == null) return false;
    return DateTime.now().difference(_lastAuthTime!) < _config.sessionTimeout;
  }

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadConfig();
    await _checkCapabilities();
    _loadLastAuthTime();
  }

  Future<void> _loadConfig() async {
    if (_prefs == null) return;

    final configJson = _prefs!.getString(_configKey);
    if (configJson != null) {
      try {
        final Map<String, dynamic> data = _parseJson(configJson);
        _config = BiometricConfig.fromJson(data);
        notifyListeners();
      } catch (e) {
        debugPrint('Error loading biometric config: $e');
      }
    }
  }

  void _loadLastAuthTime() {
    if (_prefs == null) return;

    final lastAuthTimestamp = _prefs!.getInt(_lastAuthKey);
    if (lastAuthTimestamp != null) {
      _lastAuthTime = DateTime.fromMillisecondsSinceEpoch(lastAuthTimestamp);
    }
  }

  Future<void> _saveConfig() async {
    if (_prefs == null) return;

    try {
      final configJson = _stringifyJson(_config.toJson());
      await _prefs!.setString(_configKey, configJson);
    } catch (e) {
      debugPrint('Error saving biometric config: $e');
    }
  }

  Future<void> _saveLastAuthTime() async {
    if (_prefs == null || _lastAuthTime == null) return;

    await _prefs!.setInt(_lastAuthKey, _lastAuthTime!.millisecondsSinceEpoch);
  }

  Future<void> _checkCapabilities() async {
    try {
      final isAvailable = await _localAuth.isDeviceSupported();
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final availableBiometrics = await _localAuth.getAvailableBiometrics();

      _capabilities = BiometricCapabilities(
        isAvailable: isAvailable,
        canCheckBiometrics: canCheckBiometrics,
        availableBiometrics: availableBiometrics,
        isDeviceSupported: isAvailable && canCheckBiometrics,
      );

      notifyListeners();
    } catch (e) {
      debugPrint('Error checking biometric capabilities: $e');
      _capabilities = const BiometricCapabilities(
        isAvailable: false,
        canCheckBiometrics: false,
        availableBiometrics: [],
        isDeviceSupported: false,
      );
    }
  }

  Future<BiometricAuthResult> authenticate({
    required String reason,
    bool stickyAuth = true,
    bool biometricOnly = false,
  }) async {
    if (_capabilities == null || !_capabilities!.isDeviceSupported) {
      return BiometricAuthResult.unavailable;
    }

    if (!_capabilities!.hasAny) {
      return BiometricAuthResult.notSetup;
    }

    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: stickyAuth,
          biometricOnly: biometricOnly,
        ),
      );

      if (didAuthenticate) {
        _lastAuthTime = DateTime.now();
        await _saveLastAuthTime();
        return BiometricAuthResult.success;
      } else {
        return BiometricAuthResult.failure;
      }
    } on PlatformException catch (e) {
      switch (e.code) {
        case auth_error.notAvailable:
          return BiometricAuthResult.unavailable;
        case auth_error.notEnrolled:
          return BiometricAuthResult.notSetup;
        case auth_error.lockedOut:
        case auth_error.permanentlyLockedOut:
          return BiometricAuthResult.error;
        default:
          if (e.code == 'UserCancel') {
            return BiometricAuthResult.cancelled;
          }
          debugPrint(
              'Biometric authentication error: ${e.code} - ${e.message}');
          return BiometricAuthResult.error;
      }
    } catch (e) {
      debugPrint('Unexpected biometric authentication error: $e');
      return BiometricAuthResult.error;
    }
  }

  Future<bool> authenticateForSensitiveData({
    String reason = 'Access sensitive business data',
  }) async {
    if (!_config.enabled || !_config.requireForSensitiveData) {
      return true; // Allow access if biometric auth is not required
    }

    if (isSessionValid) {
      return true; // Session is still valid
    }

    final result = await authenticate(reason: reason);
    return result == BiometricAuthResult.success;
  }

  Future<bool> authenticateForAppLaunch({
    String reason = 'Unlock BizSync',
  }) async {
    if (!_config.enabled || !_config.requireForAppLaunch) {
      return true; // Allow access if biometric auth is not required
    }

    final result = await authenticate(reason: reason);
    return result == BiometricAuthResult.success;
  }

  Future<void> updateConfig(BiometricConfig newConfig) async {
    _config = newConfig;
    await _saveConfig();
    notifyListeners();
  }

  Future<void> enableBiometricAuth({
    bool requireForSensitiveData = true,
    bool requireForAppLaunch = false,
  }) async {
    final newConfig = _config.copyWith(
      enabled: true,
      requireForSensitiveData: requireForSensitiveData,
      requireForAppLaunch: requireForAppLaunch,
    );
    await updateConfig(newConfig);
  }

  Future<void> disableBiometricAuth() async {
    final newConfig = _config.copyWith(enabled: false);
    await updateConfig(newConfig);
    _lastAuthTime = null;
    if (_prefs != null) {
      await _prefs!.remove(_lastAuthKey);
    }
  }

  void invalidateSession() {
    _lastAuthTime = null;
    if (_prefs != null) {
      _prefs!.remove(_lastAuthKey);
    }
  }

  String getBiometricAuthResultMessage(BiometricAuthResult result) {
    switch (result) {
      case BiometricAuthResult.success:
        return 'Authentication successful';
      case BiometricAuthResult.failure:
        return 'Authentication failed. Please try again.';
      case BiometricAuthResult.unavailable:
        return 'Biometric authentication is not available on this device';
      case BiometricAuthResult.notSetup:
        return 'No biometric authentication is set up. Please enable it in your device settings.';
      case BiometricAuthResult.cancelled:
        return 'Authentication was cancelled';
      case BiometricAuthResult.error:
        return 'An error occurred during authentication. Please try again.';
    }
  }

  // Simple JSON parsing without dart:convert
  Map<String, dynamic> _parseJson(String jsonString) {
    final Map<String, dynamic> result = {};

    final content = jsonString.replaceAll(RegExp(r'[{}"]'), '');
    final pairs = content.split(',');

    for (final pair in pairs) {
      final keyValue = pair.split(':');
      if (keyValue.length == 2) {
        final key = keyValue[0].trim();
        final value = keyValue[1].trim();

        if (value == 'true') {
          result[key] = true;
        } else if (value == 'false') {
          result[key] = false;
        } else if (value == 'null') {
          result[key] = null;
        } else if (int.tryParse(value) != null) {
          result[key] = int.parse(value);
        } else {
          result[key] = value;
        }
      }
    }

    return result;
  }

  String _stringifyJson(Map<String, dynamic> data) {
    final List<String> pairs = [];

    data.forEach((key, value) {
      String valueStr;
      if (value == null) {
        valueStr = 'null';
      } else if (value is bool) {
        valueStr = value.toString();
      } else if (value is int) {
        valueStr = value.toString();
      } else {
        valueStr = '"$value"';
      }
      pairs.add('"$key":$valueStr');
    });

    return '{${pairs.join(',')}}';
  }
}

// Riverpod providers for biometric authentication
final biometricAuthServiceProvider = Provider<BiometricAuthService>((ref) {
  final service = BiometricAuthService();
  service.initialize();
  return service;
});

final biometricConfigProvider =
    StateNotifierProvider<BiometricConfigNotifier, BiometricConfig>((ref) {
  final service = ref.watch(biometricAuthServiceProvider);
  return BiometricConfigNotifier(service);
});

final biometricCapabilitiesProvider =
    StateProvider<BiometricCapabilities?>((ref) {
  final service = ref.watch(biometricAuthServiceProvider);
  return service.capabilities;
});

class BiometricConfigNotifier extends StateNotifier<BiometricConfig> {
  final BiometricAuthService _service;

  BiometricConfigNotifier(this._service) : super(_service.config) {
    _service.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    state = _service.config;
  }

  Future<void> updateConfig(BiometricConfig config) async {
    await _service.updateConfig(config);
  }

  Future<void> enableBiometricAuth({
    bool requireForSensitiveData = true,
    bool requireForAppLaunch = false,
  }) async {
    await _service.enableBiometricAuth(
      requireForSensitiveData: requireForSensitiveData,
      requireForAppLaunch: requireForAppLaunch,
    );
  }

  Future<void> disableBiometricAuth() async {
    await _service.disableBiometricAuth();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    super.dispose();
  }
}
