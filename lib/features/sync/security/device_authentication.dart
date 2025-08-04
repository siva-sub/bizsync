import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/sync_models.dart';
import 'encryption_service.dart';

/// Device authentication and pairing service
class DeviceAuthenticationService {
  static const String _keyPairedDevices = 'paired_devices';
  static const String _keyDeviceKeyPair = 'device_key_pair';
  static const String _keyDeviceId = 'device_id';
  static const Duration _pairingTimeout = Duration(minutes: 5);
  static const Duration _authTimeout = Duration(seconds: 30);
  static const int _pinCodeLength = 6;

  final EncryptionService _encryptionService;
  final StreamController<DevicePairing> _pairingController =
      StreamController<DevicePairing>.broadcast();
  final StreamController<AuthenticationEvent> _authController =
      StreamController<AuthenticationEvent>.broadcast();

  final Map<String, DevicePairing> _activePairings = {};
  final Map<String, Timer> _pairingTimers = {};
  final Map<String, SharedPreferences> _prefs = {};

  KeyPair? _deviceKeyPair;
  String? _deviceId;

  DeviceAuthenticationService(this._encryptionService);

  /// Initialize the authentication service
  Future<void> initialize() async {
    await _loadDeviceIdentity();
    await _loadPairedDevices();

    debugPrint('Device authentication service initialized');
    debugPrint('Device ID: $_deviceId');
  }

  /// Dispose resources
  Future<void> dispose() async {
    // Cancel all active pairing timers
    for (final timer in _pairingTimers.values) {
      timer.cancel();
    }
    _pairingTimers.clear();
    _activePairings.clear();

    await _pairingController.close();
    await _authController.close();
  }

  /// Get the local device ID
  String get deviceId => _deviceId!;

  /// Get the local device public key
  Uint8List get devicePublicKey => _deviceKeyPair!.publicKey;

  /// Stream of pairing events
  Stream<DevicePairing> get pairingEvents => _pairingController.stream;

  /// Stream of authentication events
  Stream<AuthenticationEvent> get authenticationEvents =>
      _authController.stream;

  /// Initialize pairing with a remote device using QR code
  Future<DevicePairing> initiatePairingWithQR(
    String remoteDeviceId,
    PairingMethod method,
  ) async {
    final pairingId = const Uuid().v4();

    // Generate pairing data
    final pairingData = PairingData(
      pairingId: pairingId,
      localDeviceId: _deviceId!,
      remoteDeviceId: remoteDeviceId,
      localPublicKey: _deviceKeyPair!.publicKey,
      method: method,
      timestamp: DateTime.now(),
    );

    // Create QR code data
    final qrData = _createQRCodeData(pairingData);

    // Create pairing session
    final pairing = DevicePairing(
      pairingId: pairingId,
      localDeviceId: _deviceId!,
      remoteDeviceId: remoteDeviceId,
      method: method,
      state: PairingState.codeGenerated,
      createdAt: DateTime.now(),
      qrCode: qrData,
    );

    _activePairings[pairingId] = pairing;

    // Set pairing timeout
    _setPairingTimeout(pairingId);

    _pairingController.add(pairing);

    debugPrint('Initiated QR pairing: $pairingId');
    return pairing;
  }

  /// Initialize pairing with PIN code
  Future<DevicePairing> initiatePairingWithPIN(
    String remoteDeviceId,
  ) async {
    final pairingId = const Uuid().v4();
    final pinCode = _generatePinCode();

    // Create pairing session
    final pairing = DevicePairing(
      pairingId: pairingId,
      localDeviceId: _deviceId!,
      remoteDeviceId: remoteDeviceId,
      method: PairingMethod.pinCode,
      state: PairingState.codeGenerated,
      createdAt: DateTime.now(),
      pairingCode: pinCode,
    );

    _activePairings[pairingId] = pairing;

    // Set pairing timeout
    _setPairingTimeout(pairingId);

    _pairingController.add(pairing);

    debugPrint('Initiated PIN pairing: $pairingId with code: $pinCode');
    return pairing;
  }

  /// Process scanned QR code for pairing
  Future<DevicePairing> processScannedQR(String qrData) async {
    try {
      final pairingData = _parseQRCodeData(qrData);

      // Validate pairing data
      if (pairingData.timestamp.difference(DateTime.now()).abs() >
          _pairingTimeout) {
        throw Exception('QR code has expired');
      }

      if (pairingData.localDeviceId == _deviceId) {
        throw Exception('Cannot pair with self');
      }

      // Create pairing session
      final pairing = DevicePairing(
        pairingId: pairingData.pairingId,
        localDeviceId: _deviceId!,
        remoteDeviceId: pairingData.localDeviceId,
        method: pairingData.method,
        state: PairingState.codeScanned,
        createdAt: DateTime.now(),
        qrCode: qrData,
      );

      _activePairings[pairingData.pairingId] = pairing;

      // Start authentication process
      await _performKeyExchange(pairing, pairingData.localPublicKey);

      return pairing;
    } catch (e) {
      throw Exception('Invalid QR code: $e');
    }
  }

  /// Process PIN code for pairing
  Future<DevicePairing> processPinCode(String pairingId, String pinCode) async {
    final pairing = _activePairings[pairingId];
    if (pairing == null) {
      throw Exception('Pairing session not found');
    }

    if (pairing.pairingCode != pinCode) {
      throw Exception('Invalid PIN code');
    }

    // Update pairing state
    final updatedPairing = DevicePairing(
      pairingId: pairing.pairingId,
      localDeviceId: pairing.localDeviceId,
      remoteDeviceId: pairing.remoteDeviceId,
      method: pairing.method,
      state: PairingState.codeScanned,
      createdAt: pairing.createdAt,
      pairingCode: pairing.pairingCode,
    );

    _activePairings[pairingId] = updatedPairing;
    _pairingController.add(updatedPairing);

    return updatedPairing;
  }

  /// Authenticate with a paired device
  Future<AuthenticationResult> authenticateDevice(
    String deviceId,
    Uint8List challenge,
  ) async {
    final pairedDevice = await _getPairedDevice(deviceId);
    if (pairedDevice == null) {
      throw Exception('Device not paired: $deviceId');
    }

    try {
      // Create authentication challenge
      final authChallenge = AuthenticationChallenge(
        challengerId: _deviceId!,
        challengedId: deviceId,
        challenge: challenge,
        timestamp: DateTime.now(),
      );

      // Sign challenge with device private key
      final signature = await _signChallenge(authChallenge);

      // Create authentication response
      final authResponse = AuthenticationResponse(
        challengeId: authChallenge.challengeId,
        responderId: _deviceId!,
        signature: signature,
        publicKey: _deviceKeyPair!.publicKey,
        timestamp: DateTime.now(),
      );

      // Emit authentication event
      _authController.add(AuthenticationEvent(
        type: AuthenticationEventType.challengeCreated,
        deviceId: deviceId,
        challenge: authChallenge,
        response: authResponse,
      ));

      return AuthenticationResult(
        success: true,
        deviceId: deviceId,
        challenge: authChallenge,
        response: authResponse,
      );
    } catch (e) {
      _authController.add(AuthenticationEvent(
        type: AuthenticationEventType.authenticationFailed,
        deviceId: deviceId,
        error: e.toString(),
      ));

      throw Exception('Authentication failed: $e');
    }
  }

  /// Verify authentication response from remote device
  Future<bool> verifyAuthenticationResponse(
    AuthenticationChallenge challenge,
    AuthenticationResponse response,
  ) async {
    try {
      // Verify response is for the correct challenge
      if (response.challengeId != challenge.challengeId) {
        return false;
      }

      // Verify response is from expected device
      if (response.responderId != challenge.challengedId) {
        return false;
      }

      // Verify response is not too old
      if (DateTime.now().difference(response.timestamp) > _authTimeout) {
        return false;
      }

      // Get paired device info
      final pairedDevice = await _getPairedDevice(response.responderId);
      if (pairedDevice == null) {
        return false;
      }

      // Verify signature
      final isValid = await _verifySignature(challenge, response);

      if (isValid) {
        _authController.add(AuthenticationEvent(
          type: AuthenticationEventType.authenticationSucceeded,
          deviceId: response.responderId,
          challenge: challenge,
          response: response,
        ));
      } else {
        _authController.add(AuthenticationEvent(
          type: AuthenticationEventType.authenticationFailed,
          deviceId: response.responderId,
          challenge: challenge,
          response: response,
          error: 'Signature verification failed',
        ));
      }

      return isValid;
    } catch (e) {
      debugPrint('Authentication verification error: $e');
      return false;
    }
  }

  /// Get list of paired devices
  Future<List<PairedDevice>> getPairedDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final pairedDevicesJson = prefs.getString(_keyPairedDevices);

    if (pairedDevicesJson == null) {
      return [];
    }

    try {
      final List<dynamic> deviceList = jsonDecode(pairedDevicesJson);
      return deviceList.map((json) => PairedDevice.fromMap(json)).toList();
    } catch (e) {
      debugPrint('Error loading paired devices: $e');
      return [];
    }
  }

  /// Remove a paired device
  Future<void> unpairDevice(String deviceId) async {
    final pairedDevices = await getPairedDevices();
    pairedDevices.removeWhere((device) => device.deviceId == deviceId);

    await _savePairedDevices(pairedDevices);

    debugPrint('Unpaired device: $deviceId');
  }

  /// Check if a device is paired
  Future<bool> isDevicePaired(String deviceId) async {
    final pairedDevice = await _getPairedDevice(deviceId);
    return pairedDevice != null;
  }

  // Private methods

  /// Load or create device identity
  Future<void> _loadDeviceIdentity() async {
    final prefs = await SharedPreferences.getInstance();

    // Load device ID
    _deviceId = prefs.getString(_keyDeviceId);
    if (_deviceId == null) {
      _deviceId = const Uuid().v4();
      await prefs.setString(_keyDeviceId, _deviceId!);
    }

    // Load or generate key pair
    final keyPairJson = prefs.getString(_keyDeviceKeyPair);
    if (keyPairJson != null) {
      try {
        final keyPairMap = jsonDecode(keyPairJson) as Map<String, dynamic>;
        _deviceKeyPair = KeyPair.fromMap(Map<String, String>.from(keyPairMap));
      } catch (e) {
        debugPrint('Error loading key pair, generating new one: $e');
        _deviceKeyPair = _encryptionService.generateKeyPair();
        await _saveDeviceKeyPair();
      }
    } else {
      _deviceKeyPair = _encryptionService.generateKeyPair();
      await _saveDeviceKeyPair();
    }
  }

  /// Save device key pair
  Future<void> _saveDeviceKeyPair() async {
    final prefs = await SharedPreferences.getInstance();
    final keyPairJson = jsonEncode(_deviceKeyPair!.toMap());
    await prefs.setString(_keyDeviceKeyPair, keyPairJson);
  }

  /// Load paired devices from storage
  Future<void> _loadPairedDevices() async {
    // Paired devices are loaded on demand in getPairedDevices()
  }

  /// Save paired devices to storage
  Future<void> _savePairedDevices(List<PairedDevice> devices) async {
    final prefs = await SharedPreferences.getInstance();
    final devicesJson = jsonEncode(devices.map((d) => d.toMap()).toList());
    await prefs.setString(_keyPairedDevices, devicesJson);
  }

  /// Get a specific paired device
  Future<PairedDevice?> _getPairedDevice(String deviceId) async {
    final pairedDevices = await getPairedDevices();
    try {
      return pairedDevices.firstWhere((device) => device.deviceId == deviceId);
    } catch (e) {
      return null;
    }
  }

  /// Set pairing timeout
  void _setPairingTimeout(String pairingId) {
    _pairingTimers[pairingId]?.cancel();

    _pairingTimers[pairingId] = Timer(_pairingTimeout, () {
      final pairing = _activePairings[pairingId];
      if (pairing != null && pairing.state != PairingState.completed) {
        final expiredPairing = DevicePairing(
          pairingId: pairing.pairingId,
          localDeviceId: pairing.localDeviceId,
          remoteDeviceId: pairing.remoteDeviceId,
          method: pairing.method,
          state: PairingState.expired,
          createdAt: pairing.createdAt,
          pairingCode: pairing.pairingCode,
          qrCode: pairing.qrCode,
        );

        _activePairings[pairingId] = expiredPairing;
        _pairingController.add(expiredPairing);

        debugPrint('Pairing expired: $pairingId');
      }

      _pairingTimers.remove(pairingId);
    });
  }

  /// Generate a random PIN code
  String _generatePinCode() {
    final random = Random.secure();
    final code = List.generate(_pinCodeLength, (_) => random.nextInt(10));
    return code.join();
  }

  /// Create QR code data
  String _createQRCodeData(PairingData pairingData) {
    final data = {
      'pairingId': pairingData.pairingId,
      'deviceId': pairingData.localDeviceId,
      'remoteDeviceId': pairingData.remoteDeviceId,
      'publicKey': base64.encode(pairingData.localPublicKey),
      'method': pairingData.method.name,
      'timestamp': pairingData.timestamp.millisecondsSinceEpoch,
    };

    final json = jsonEncode(data);
    return base64.encode(utf8.encode(json));
  }

  /// Parse QR code data
  PairingData _parseQRCodeData(String qrData) {
    final json = utf8.decode(base64.decode(qrData));
    final data = jsonDecode(json) as Map<String, dynamic>;

    return PairingData(
      pairingId: data['pairingId'],
      localDeviceId: data['deviceId'],
      remoteDeviceId: data['remoteDeviceId'],
      localPublicKey: base64.decode(data['publicKey']),
      method: PairingMethod.values.firstWhere((m) => m.name == data['method']),
      timestamp: DateTime.fromMillisecondsSinceEpoch(data['timestamp']),
    );
  }

  /// Perform key exchange during pairing
  Future<void> _performKeyExchange(
      DevicePairing pairing, Uint8List remotePublicKey) async {
    try {
      // Update pairing state
      final authenticatingPairing = DevicePairing(
        pairingId: pairing.pairingId,
        localDeviceId: pairing.localDeviceId,
        remoteDeviceId: pairing.remoteDeviceId,
        method: pairing.method,
        state: PairingState.authenticating,
        createdAt: pairing.createdAt,
        pairingCode: pairing.pairingCode,
        qrCode: pairing.qrCode,
      );

      _activePairings[pairing.pairingId] = authenticatingPairing;
      _pairingController.add(authenticatingPairing);

      // Perform ECDH key exchange
      final sharedSecret = _encryptionService.performKeyExchange(
        _deviceKeyPair!.privateKey,
        remotePublicKey,
      );

      // Create paired device record
      final pairedDevice = PairedDevice(
        deviceId: pairing.remoteDeviceId,
        deviceName: 'Device ${pairing.remoteDeviceId.substring(0, 8)}',
        publicKey: remotePublicKey,
        sharedSecret: sharedSecret,
        pairedAt: DateTime.now(),
        pairingMethod: pairing.method,
      );

      // Save paired device
      final pairedDevices = await getPairedDevices();
      pairedDevices.removeWhere((d) => d.deviceId == pairing.remoteDeviceId);
      pairedDevices.add(pairedDevice);
      await _savePairedDevices(pairedDevices);

      // Complete pairing
      final completedPairing = DevicePairing(
        pairingId: pairing.pairingId,
        localDeviceId: pairing.localDeviceId,
        remoteDeviceId: pairing.remoteDeviceId,
        method: pairing.method,
        state: PairingState.completed,
        createdAt: pairing.createdAt,
        completedAt: DateTime.now(),
        pairingCode: pairing.pairingCode,
        qrCode: pairing.qrCode,
        sharedSecret: sharedSecret,
      );

      _activePairings[pairing.pairingId] = completedPairing;
      _pairingController.add(completedPairing);

      // Cancel timeout timer
      _pairingTimers[pairing.pairingId]?.cancel();
      _pairingTimers.remove(pairing.pairingId);

      debugPrint('Pairing completed: ${pairing.pairingId}');
    } catch (e) {
      // Pairing failed
      final failedPairing = DevicePairing(
        pairingId: pairing.pairingId,
        localDeviceId: pairing.localDeviceId,
        remoteDeviceId: pairing.remoteDeviceId,
        method: pairing.method,
        state: PairingState.failed,
        createdAt: pairing.createdAt,
        pairingCode: pairing.pairingCode,
        qrCode: pairing.qrCode,
      );

      _activePairings[pairing.pairingId] = failedPairing;
      _pairingController.add(failedPairing);

      debugPrint('Pairing failed: ${pairing.pairingId} - $e');
      throw Exception('Key exchange failed: $e');
    }
  }

  /// Sign authentication challenge
  Future<Uint8List> _signChallenge(AuthenticationChallenge challenge) async {
    final challengeBytes = challenge.toBytes();
    return _encryptionService.createMAC(
        challengeBytes, _deviceKeyPair!.privateKey);
  }

  /// Verify authentication signature
  Future<bool> _verifySignature(
    AuthenticationChallenge challenge,
    AuthenticationResponse response,
  ) async {
    final pairedDevice = await _getPairedDevice(response.responderId);
    if (pairedDevice == null) {
      return false;
    }

    final challengeBytes = challenge.toBytes();
    return _encryptionService.verifyMAC(
      challengeBytes,
      response.signature,
      pairedDevice.publicKey,
    );
  }
}

/// Pairing data for QR code generation
class PairingData {
  final String pairingId;
  final String localDeviceId;
  final String remoteDeviceId;
  final Uint8List localPublicKey;
  final PairingMethod method;
  final DateTime timestamp;

  const PairingData({
    required this.pairingId,
    required this.localDeviceId,
    required this.remoteDeviceId,
    required this.localPublicKey,
    required this.method,
    required this.timestamp,
  });
}

/// Paired device information
class PairedDevice {
  final String deviceId;
  final String deviceName;
  final Uint8List publicKey;
  final Uint8List sharedSecret;
  final DateTime pairedAt;
  final PairingMethod pairingMethod;

  const PairedDevice({
    required this.deviceId,
    required this.deviceName,
    required this.publicKey,
    required this.sharedSecret,
    required this.pairedAt,
    required this.pairingMethod,
  });

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'publicKey': base64.encode(publicKey),
      'sharedSecret': base64.encode(sharedSecret),
      'pairedAt': pairedAt.millisecondsSinceEpoch,
      'pairingMethod': pairingMethod.name,
    };
  }

  factory PairedDevice.fromMap(Map<String, dynamic> map) {
    return PairedDevice(
      deviceId: map['deviceId'],
      deviceName: map['deviceName'],
      publicKey: base64.decode(map['publicKey']),
      sharedSecret: base64.decode(map['sharedSecret']),
      pairedAt: DateTime.fromMillisecondsSinceEpoch(map['pairedAt']),
      pairingMethod: PairingMethod.values
          .firstWhere((m) => m.name == map['pairingMethod']),
    );
  }
}

/// Authentication challenge
class AuthenticationChallenge {
  final String challengeId;
  final String challengerId;
  final String challengedId;
  final Uint8List challenge;
  final DateTime timestamp;

  AuthenticationChallenge({
    String? challengeId,
    required this.challengerId,
    required this.challengedId,
    required this.challenge,
    required this.timestamp,
  }) : challengeId = challengeId ?? const Uuid().v4();

  Uint8List toBytes() {
    final data = {
      'challengeId': challengeId,
      'challengerId': challengerId,
      'challengedId': challengedId,
      'challenge': base64.encode(challenge),
      'timestamp': timestamp.millisecondsSinceEpoch,
    };

    final json = jsonEncode(data);
    return Uint8List.fromList(utf8.encode(json));
  }
}

/// Authentication response
class AuthenticationResponse {
  final String challengeId;
  final String responderId;
  final Uint8List signature;
  final Uint8List publicKey;
  final DateTime timestamp;

  const AuthenticationResponse({
    required this.challengeId,
    required this.responderId,
    required this.signature,
    required this.publicKey,
    required this.timestamp,
  });

  Uint8List toBytes() {
    final data = {
      'challengeId': challengeId,
      'responderId': responderId,
      'signature': base64.encode(signature),
      'publicKey': base64.encode(publicKey),
      'timestamp': timestamp.millisecondsSinceEpoch,
    };

    final json = jsonEncode(data);
    return Uint8List.fromList(utf8.encode(json));
  }
}

/// Authentication result
class AuthenticationResult {
  final bool success;
  final String deviceId;
  final AuthenticationChallenge challenge;
  final AuthenticationResponse response;
  final String? error;

  const AuthenticationResult({
    required this.success,
    required this.deviceId,
    required this.challenge,
    required this.response,
    this.error,
  });
}

/// Authentication event types
enum AuthenticationEventType {
  challengeCreated,
  challengeReceived,
  responseCreated,
  responseReceived,
  authenticationSucceeded,
  authenticationFailed,
}

/// Authentication event
class AuthenticationEvent {
  final AuthenticationEventType type;
  final String deviceId;
  final AuthenticationChallenge? challenge;
  final AuthenticationResponse? response;
  final String? error;

  const AuthenticationEvent({
    required this.type,
    required this.deviceId,
    this.challenge,
    this.response,
    this.error,
  });
}
