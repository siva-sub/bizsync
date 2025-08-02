import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/export.dart';
import '../models/backup_models.dart';

/// Handles the .bdb (Business Data Bundle) file format
/// 
/// File Structure:
/// - manifest.json: Backup metadata and file information
/// - data/: Directory containing database exports
/// - attachments/: Directory containing file attachments
/// - checksums.txt: Integrity verification data
/// 
/// The entire structure is compressed using Zstandard or gzip
/// and optionally encrypted using AES-256-GCM
class BackupFormatHandler {
  static const String manifestFileName = 'manifest.json';
  static const String dataDirectoryName = 'data';
  static const String attachmentsDirectoryName = 'attachments';
  static const String checksumsFileName = 'checksums.txt';
  static const String bdbExtension = '.bdb';
  
  static const String encryptionAlgorithm = 'AES-256-GCM';
  static const String keyDerivationAlgorithm = 'PBKDF2';
  static const int keyDerivationIterations = 100000;
  static const int keySize = 32; // 256 bits
  static const int ivSize = 12; // 96 bits for GCM
  static const int saltSize = 32; // 256 bits

  /// Creates a .bdb backup file from the provided data
  static Future<String> createBackupFile({
    required String outputPath,
    required BackupManifest manifest,
    required Map<String, List<Map<String, dynamic>>> tableData,
    required Map<String, Uint8List> attachments,
    String? password,
  }) async {
    final fileName = _generateBackupFileName(manifest);
    final fullPath = '$outputPath/$fileName';
    
    // Create temporary directory for building the backup
    final tempDir = await Directory.systemTemp.createTemp('bizsync_backup_');
    
    try {
      // Create directory structure
      await Directory('${tempDir.path}/$dataDirectoryName').create();
      await Directory('${tempDir.path}/$attachmentsDirectoryName').create();
      
      // Write manifest
      final manifestFile = File('${tempDir.path}/$manifestFileName');
      await manifestFile.writeAsString(jsonEncode(manifest.toJson()));
      
      // Write table data
      final checksums = <String, String>{};
      for (final entry in tableData.entries) {
        final tableName = entry.key;
        final data = entry.value;
        
        final tableFile = File('${tempDir.path}/$dataDirectoryName/$tableName.json');
        final jsonData = jsonEncode(data);
        await tableFile.writeAsString(jsonData);
        
        // Calculate checksum
        checksums[tableName] = sha256.convert(utf8.encode(jsonData)).toString();
      }
      
      // Write attachments
      for (final entry in attachments.entries) {
        final fileName = entry.key;
        final data = entry.value;
        
        final attachmentFile = File('${tempDir.path}/$attachmentsDirectoryName/$fileName');
        await attachmentFile.writeAsBytes(data);
        
        // Calculate checksum
        checksums['attachment_$fileName'] = sha256.convert(data).toString();
      }
      
      // Write checksums file
      final checksumsFile = File('${tempDir.path}/$checksumsFileName');
      final checksumsContent = checksums.entries
          .map((e) => '${e.key}:${e.value}')
          .join('\n');
      await checksumsFile.writeAsString(checksumsContent);
      
      // Create archive
      final archive = Archive();
      await _addDirectoryToArchive(archive, tempDir, '');
      
      // Compress
      Uint8List compressedData;
      final tarEncoder = TarEncoder();
      final archiveBytes = tarEncoder.encode(archive);
      final zlibEncoder = ZLibEncoder();
      compressedData = Uint8List.fromList(zlibEncoder.encode(archiveBytes, level: 6));
      
      // Encrypt if password provided
      if (password != null && password.isNotEmpty) {
        compressedData = await _encryptData(compressedData, password);
      }
      
      // Write final file
      final outputFile = File(fullPath);
      await outputFile.writeAsBytes(compressedData);
      
      return fullPath;
    } finally {
      // Cleanup temporary directory
      await tempDir.delete(recursive: true);
    }
  }
  
  /// Extracts and validates a .bdb backup file
  static Future<BackupExtractResult> extractBackupFile({
    required String backupFilePath,
    required String extractPath,
    String? password,
  }) async {
    final backupFile = File(backupFilePath);
    
    if (!await backupFile.exists()) {
      throw BackupException('Backup file not found: $backupFilePath');
    }
    
    var data = await backupFile.readAsBytes();
    
    // Decrypt if needed
    if (password != null && password.isNotEmpty) {
      try {
        data = await _decryptData(data, password);
      } catch (e) {
        throw BackupException('Failed to decrypt backup: Invalid password or corrupted file');
      }
    }
    
    // Decompress
    Archive archive;
    try {
      final zlibDecoder = ZLibDecoder();
      final decompressedData = zlibDecoder.decodeBytes(data);
      final tarDecoder = TarDecoder();
      archive = tarDecoder.decodeBytes(decompressedData);
    } catch (e) {
      throw BackupException('Failed to decompress backup: Corrupted file');
    }
    
    // Extract to directory
    final extractDir = Directory(extractPath);
    if (!await extractDir.exists()) {
      await extractDir.create(recursive: true);
    }
    
    for (final file in archive) {
      final filePath = '${extractDir.path}/${file.name}';
      final fileDir = Directory(File(filePath).parent.path);
      if (!await fileDir.exists()) {
        await fileDir.create(recursive: true);
      }
      
      if (file.isFile) {
        final outputFile = File(filePath);
        await outputFile.writeAsBytes(file.content as List<int>);
      }
    }
    
    // Load and validate manifest
    final manifestFile = File('${extractDir.path}/$manifestFileName');
    if (!await manifestFile.exists()) {
      throw BackupException('Invalid backup: Missing manifest file');
    }
    
    final manifestJson = await manifestFile.readAsString();
    final manifest = BackupManifest.fromJson(jsonDecode(manifestJson));
    
    // Validate integrity
    final isValid = await _validateIntegrity(extractDir.path, manifest);
    if (!isValid) {
      throw BackupException('Backup integrity validation failed');
    }
    
    return BackupExtractResult(
      manifest: manifest,
      extractPath: extractDir.path,
      isValid: true,
    );
  }
  
  /// Validates the integrity of an extracted backup
  static Future<bool> _validateIntegrity(String extractPath, BackupManifest manifest) async {
    try {
      // Read checksums file
      final checksumsFile = File('$extractPath/$checksumsFileName');
      if (!await checksumsFile.exists()) {
        return false;
      }
      
      final checksumsContent = await checksumsFile.readAsString();
      final expectedChecksums = <String, String>{};
      
      for (final line in checksumsContent.split('\n')) {
        if (line.isNotEmpty) {
          final parts = line.split(':');
          if (parts.length == 2) {
            expectedChecksums[parts[0]] = parts[1];
          }
        }
      }
      
      // Validate table data
      for (final table in manifest.tables) {
        final tableFile = File('$extractPath/$dataDirectoryName/${table.name}.json');
        if (!await tableFile.exists()) {
          return false;
        }
        
        final content = await tableFile.readAsString();
        final actualChecksum = sha256.convert(utf8.encode(content)).toString();
        final expectedChecksum = expectedChecksums[table.name];
        
        if (actualChecksum != expectedChecksum) {
          return false;
        }
      }
      
      // Validate attachments
      for (final attachment in manifest.attachments) {
        final attachmentFile = File('$extractPath/$attachmentsDirectoryName/${attachment.name}');
        if (!await attachmentFile.exists()) {
          return false;
        }
        
        final content = await attachmentFile.readAsBytes();
        final actualChecksum = sha256.convert(content).toString();
        final expectedChecksum = expectedChecksums['attachment_${attachment.name}'];
        
        if (actualChecksum != expectedChecksum) {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Encrypts data using AES-256-GCM with PBKDF2 key derivation
  static Future<Uint8List> _encryptData(Uint8List data, String password) async {
    // Generate salt and IV
    final salt = _generateRandomBytes(saltSize);
    final iv = _generateRandomBytes(ivSize);
    
    // Derive key using PBKDF2
    final key = _deriveKey(password, salt, keyDerivationIterations, keySize);
    
    // Encrypt data
    final encrypter = Encrypter(AES(Key(key), mode: AESMode.gcm));
    final encrypted = encrypter.encryptBytes(data, iv: IV(iv));
    
    // Combine salt + IV + encrypted data + auth tag
    final result = BytesBuilder();
    result.add(salt);
    result.add(iv);
    result.add(encrypted.bytes);
    
    return result.toBytes();
  }
  
  /// Decrypts data using AES-256-GCM with PBKDF2 key derivation
  static Future<Uint8List> _decryptData(Uint8List encryptedData, String password) async {
    if (encryptedData.length < saltSize + ivSize) {
      throw BackupException('Invalid encrypted data: Too short');
    }
    
    // Extract salt, IV, and encrypted data
    final salt = encryptedData.sublist(0, saltSize);
    final iv = encryptedData.sublist(saltSize, saltSize + ivSize);
    final encrypted = encryptedData.sublist(saltSize + ivSize);
    
    // Derive key using PBKDF2
    final key = _deriveKey(password, salt, keyDerivationIterations, keySize);
    
    // Decrypt data
    final encrypter = Encrypter(AES(Key(key), mode: AESMode.gcm));
    final decrypted = encrypter.decryptBytes(Encrypted(encrypted), iv: IV(iv));
    
    return Uint8List.fromList(decrypted);
  }
  
  /// Derives a key using PBKDF2
  static Uint8List _deriveKey(String password, Uint8List salt, int iterations, int keyLength) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(salt, iterations, keyLength));
    
    return pbkdf2.process(Uint8List.fromList(password.codeUnits));
  }
  
  /// Generates cryptographically secure random bytes
  static Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }
  
  /// Adds a directory and its contents to an archive
  static Future<void> _addDirectoryToArchive(Archive archive, Directory dir, String basePath) async {
    await for (final entity in dir.list(recursive: false)) {
      final relativePath = basePath.isEmpty 
          ? entity.path.split('/').last
          : '$basePath/${entity.path.split('/').last}';
      
      if (entity is Directory) {
        await _addDirectoryToArchive(archive, entity, relativePath);
      } else if (entity is File) {
        final content = await entity.readAsBytes();
        final archiveFile = ArchiveFile(relativePath, content.length, content);
        archive.addFile(archiveFile);
      }
    }
  }
  
  /// Generates a backup file name with timestamp
  static String _generateBackupFileName(BackupManifest manifest) {
    final timestamp = manifest.createdAt.toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final type = manifest.metadata.type.name;
    return 'bizsync_${type}_backup_$timestamp$bdbExtension';
  }
}

/// Result of backup extraction
class BackupExtractResult {
  final BackupManifest manifest;
  final String extractPath;
  final bool isValid;

  const BackupExtractResult({
    required this.manifest,
    required this.extractPath,
    required this.isValid,
  });
}

/// Backup-related exceptions
class BackupException implements Exception {
  final String message;
  final dynamic originalError;
  
  const BackupException(this.message, [this.originalError]);
  
  @override
  String toString() => 'BackupException: $message';
}