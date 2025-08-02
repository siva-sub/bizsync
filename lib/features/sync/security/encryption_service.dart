import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/export.dart' as pc;

/// Advanced encryption service implementing Signal Protocol-like concepts
class EncryptionService {
  static const int _keySize = 32; // 256 bits
  static const int _nonceSize = 12; // 96 bits for AES-GCM
  static const int _tagSize = 16; // 128 bits for AES-GCM authentication tag
  static const String _kdfInfo = 'BizSync P2P Encryption';

  final pc.SecureRandom _secureRandom;
  
  EncryptionService() : _secureRandom = _initSecureRandom();

  /// Initialize secure random number generator
  static pc.SecureRandom _initSecureRandom() {
    final secureRandom = pc.SecureRandom('Fortuna')
      ..seed(pc.KeyParameter(Uint8List.fromList(
        List.generate(32, (i) => Random.secure().nextInt(256))
      )));
    return secureRandom;
  }

  /// Generate a new key pair for ECDH key exchange (STUB)
  /// X25519 not available, using random keys for compilation
  KeyPair generateKeyPair() {
    final privateKey = _generateRandomBytes(_keySize);
    final publicKey = _generateRandomBytes(_keySize);
    
    return KeyPair(
      privateKey: privateKey,
      publicKey: publicKey,
    );
  }

  /// Perform key exchange to derive shared secret (STUB)
  /// X25519 not available, using hash of combined keys
  Uint8List performKeyExchange(Uint8List privateKey, Uint8List publicKey) {
    final combined = Uint8List.fromList([...privateKey, ...publicKey]);
    return hash(combined);
  }

  /// Derive keys using HKDF (HMAC-based Key Derivation Function)
  HKDFResult deriveKeys(Uint8List sharedSecret, {
    Uint8List? salt,
    String? info,
  }) {
    salt ??= Uint8List(_keySize);
    info ??= _kdfInfo;
    
    // HKDF Extract phase
    final hmacSha256 = Hmac(sha256, salt);
    final prk = Uint8List.fromList(hmacSha256.convert(sharedSecret).bytes);
    
    // HKDF Expand phase to derive multiple keys
    final encryptionKey = _hkdfExpand(prk, '${info}_encryption', _keySize);
    final authenticationKey = _hkdfExpand(prk, '${info}_authentication', _keySize);
    final nextChainKey = _hkdfExpand(prk, '${info}_chain', _keySize);
    
    return HKDFResult(
      encryptionKey: encryptionKey,
      authenticationKey: authenticationKey,
      nextChainKey: nextChainKey,
    );
  }

  /// HKDF Expand implementation
  Uint8List _hkdfExpand(Uint8List prk, String info, int length) {
    final infoBytes = utf8.encode(info);
    final hmac = Hmac(sha256, prk);
    final output = <int>[];
    
    var t = <int>[];
    var counter = 1;
    
    while (output.length < length) {
      final input = [...t, ...infoBytes, counter];
      t = hmac.convert(input).bytes;
      output.addAll(t);
      counter++;
    }
    
    return Uint8List.fromList(output.take(length).toList());
  }

  /// Encrypt data using AES-256-GCM with additional authenticated data
  EncryptionResult encrypt(
    Uint8List data, 
    Uint8List key, {
    Uint8List? aad,
  }) {
    // Generate random nonce
    final nonce = _generateRandomBytes(_nonceSize);
    
    // Create AES-GCM cipher
    final cipher = pc.GCMBlockCipher(pc.AESEngine());
    final params = pc.AEADParameters(
      pc.KeyParameter(key),
      _tagSize * 8, // Convert bytes to bits
      nonce,
      aad ?? Uint8List(0),
    );
    
    cipher.init(true, params);
    
    // Encrypt data
    final ciphertext = Uint8List(data.length);
    var offset = cipher.processBytes(data, 0, data.length, ciphertext, 0);
    
    // Get authentication tag
    final tag = Uint8List(_tagSize);
    cipher.doFinal(tag, 0);
    
    return EncryptionResult(
      ciphertext: ciphertext,
      nonce: nonce,
      tag: tag,
      aad: aad,
    );
  }

  /// Decrypt data using AES-256-GCM with authentication verification
  Uint8List decrypt(EncryptionResult encryptionResult, Uint8List key) {
    // Create AES-GCM cipher
    final cipher = pc.GCMBlockCipher(pc.AESEngine());
    final params = pc.AEADParameters(
      pc.KeyParameter(key),
      _tagSize * 8, // Convert bytes to bits
      encryptionResult.nonce,
      encryptionResult.aad ?? Uint8List(0),
    );
    
    cipher.init(false, params);
    
    // Combine ciphertext and tag for decryption
    final input = Uint8List.fromList([
      ...encryptionResult.ciphertext,
      ...encryptionResult.tag,
    ]);
    
    // Decrypt and verify
    final plaintext = Uint8List(encryptionResult.ciphertext.length);
    final bytesDecrypted = cipher.processBytes(
      input, 0, input.length, plaintext, 0
    );
    
    // Verify authentication tag
    try {
      cipher.doFinal(Uint8List(0), 0);
    } catch (e) {
      throw Exception('Authentication verification failed: $e');
    }
    
    return plaintext.sublist(0, bytesDecrypted);
  }

  /// Create message authentication code (MAC) using HMAC-SHA256
  Uint8List createMAC(Uint8List data, Uint8List key) {
    final hmac = Hmac(sha256, key);
    return Uint8List.fromList(hmac.convert(data).bytes);
  }

  /// Verify message authentication code
  bool verifyMAC(Uint8List data, Uint8List mac, Uint8List key) {
    final expectedMAC = createMAC(data, key);
    return _constantTimeEquals(mac, expectedMAC);
  }

  /// Secure hash function using SHA-256
  Uint8List hash(Uint8List data) {
    return Uint8List.fromList(sha256.convert(data).bytes);
  }

  /// Generate cryptographically secure random bytes
  Uint8List _generateRandomBytes(int length) {
    return _secureRandom.nextBytes(length);
  }

  /// Constant-time comparison to prevent timing attacks
  bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    
    return result == 0;
  }

  /// Generate a cryptographically secure random nonce
  Uint8List generateNonce() {
    return _generateRandomBytes(_nonceSize);
  }

  /// Generate a cryptographically secure random key
  Uint8List generateKey() {
    return _generateRandomBytes(_keySize);
  }

  /// Generate a cryptographically secure random salt
  Uint8List generateSalt() {
    return _generateRandomBytes(_keySize);
  }
}

/// Key pair for asymmetric cryptography
class KeyPair {
  final Uint8List privateKey;
  final Uint8List publicKey;

  const KeyPair({
    required this.privateKey,
    required this.publicKey,
  });

  /// Convert to map for serialization
  Map<String, String> toMap() {
    return {
      'privateKey': base64.encode(privateKey),
      'publicKey': base64.encode(publicKey),
    };
  }

  /// Create from map for deserialization
  factory KeyPair.fromMap(Map<String, String> map) {
    return KeyPair(
      privateKey: base64.decode(map['privateKey']!),
      publicKey: base64.decode(map['publicKey']!),
    );
  }
}

/// Result of HKDF key derivation
class HKDFResult {
  final Uint8List encryptionKey;
  final Uint8List authenticationKey;
  final Uint8List nextChainKey;

  const HKDFResult({
    required this.encryptionKey,
    required this.authenticationKey,
    required this.nextChainKey,
  });
}

/// Result of encryption operation
class EncryptionResult {
  final Uint8List ciphertext;
  final Uint8List nonce;
  final Uint8List tag;
  final Uint8List? aad;

  const EncryptionResult({
    required this.ciphertext,
    required this.nonce,
    required this.tag,
    this.aad,
  });

  /// Convert to map for serialization
  Map<String, String> toMap() {
    return {
      'ciphertext': base64.encode(ciphertext),
      'nonce': base64.encode(nonce),
      'tag': base64.encode(tag),
      if (aad != null) 'aad': base64.encode(aad!),
    };
  }

  /// Create from map for deserialization
  factory EncryptionResult.fromMap(Map<String, String> map) {
    return EncryptionResult(
      ciphertext: base64.decode(map['ciphertext']!),
      nonce: base64.decode(map['nonce']!),
      tag: base64.decode(map['tag']!),
      aad: map['aad'] != null ? base64.decode(map['aad']!) : null,
    );
  }

  /// Serialize to bytes for transmission
  Uint8List toBytes() {
    final json = jsonEncode(toMap());
    return Uint8List.fromList(utf8.encode(json));
  }

  /// Deserialize from bytes
  factory EncryptionResult.fromBytes(Uint8List bytes) {
    final json = utf8.decode(bytes);
    final map = jsonDecode(json) as Map<String, dynamic>;
    return EncryptionResult.fromMap(Map<String, String>.from(map));
  }
}

/// Secure session state for ongoing communication
class SecureSession {
  final String sessionId;
  final Uint8List encryptionKey;
  final Uint8List authenticationKey;
  final Uint8List chainKey;
  final int messageNumber;
  final DateTime createdAt;
  final DateTime lastUsed;

  const SecureSession({
    required this.sessionId,
    required this.encryptionKey,
    required this.authenticationKey,
    required this.chainKey,
    required this.messageNumber,
    required this.createdAt,
    required this.lastUsed,
  });

  /// Create new session from key derivation result
  factory SecureSession.create(String sessionId, HKDFResult keys) {
    final now = DateTime.now();
    return SecureSession(
      sessionId: sessionId,
      encryptionKey: keys.encryptionKey,
      authenticationKey: keys.authenticationKey,
      chainKey: keys.nextChainKey,
      messageNumber: 0,
      createdAt: now,
      lastUsed: now,
    );
  }

  /// Update session with new message number and timestamp
  SecureSession updateMessageNumber(int newMessageNumber) {
    return SecureSession(
      sessionId: sessionId,
      encryptionKey: encryptionKey,
      authenticationKey: authenticationKey,
      chainKey: chainKey,
      messageNumber: newMessageNumber,
      createdAt: createdAt,
      lastUsed: DateTime.now(),
    );
  }

  /// Update session with new chain key (for forward secrecy)
  SecureSession updateChainKey(Uint8List newChainKey) {
    return SecureSession(
      sessionId: sessionId,
      encryptionKey: encryptionKey,
      authenticationKey: authenticationKey,
      chainKey: newChainKey,
      messageNumber: messageNumber,
      createdAt: createdAt,
      lastUsed: DateTime.now(),
    );
  }

  /// Check if session has expired
  bool isExpired(Duration maxAge) {
    return DateTime.now().difference(lastUsed) > maxAge;
  }

  /// Serialize to map
  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'encryptionKey': base64.encode(encryptionKey),
      'authenticationKey': base64.encode(authenticationKey),
      'chainKey': base64.encode(chainKey),
      'messageNumber': messageNumber,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastUsed': lastUsed.millisecondsSinceEpoch,
    };
  }

  /// Deserialize from map
  factory SecureSession.fromMap(Map<String, dynamic> map) {
    return SecureSession(
      sessionId: map['sessionId'],
      encryptionKey: base64.decode(map['encryptionKey']),
      authenticationKey: base64.decode(map['authenticationKey']),
      chainKey: base64.decode(map['chainKey']),
      messageNumber: map['messageNumber'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      lastUsed: DateTime.fromMillisecondsSinceEpoch(map['lastUsed']),
    );
  }
}