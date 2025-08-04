import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';

/// Service for managing image storage operations in the app
class ImageStorageService {
  static const String _imagesDirName = 'images';
  static const String _profilePicturesDirName = 'profile_pictures';
  static const String _thumbnailsDirName = 'thumbnails';

  /// Saves an image file to the app's storage directory
  Future<String> saveImage(File sourceFile, {String? customDir}) async {
    final appDir = await getApplicationDocumentsDirectory();
    final targetDir = customDir ?? _imagesDirName;
    final imagesDir = Directory(path.join(appDir.path, targetDir));

    // Create directory if it doesn't exist
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    // Generate unique filename based on file content hash
    final bytes = await sourceFile.readAsBytes();
    final hash = sha256.convert(bytes).toString().substring(0, 16);
    final extension = path.extension(sourceFile.path);
    final fileName = '${hash}_${DateTime.now().millisecondsSinceEpoch}$extension';
    
    final destinationPath = path.join(imagesDir.path, fileName);
    final destinationFile = await sourceFile.copy(destinationPath);

    return destinationFile.path;
  }

  /// Saves image bytes to the app's storage directory
  Future<String> saveImageBytes(
    Uint8List bytes, 
    String extension, {
    String? customDir,
    String? fileName,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final targetDir = customDir ?? _imagesDirName;
    final imagesDir = Directory(path.join(appDir.path, targetDir));

    // Create directory if it doesn't exist
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    // Generate filename if not provided
    final actualFileName = fileName ?? _generateUniqueFileName(bytes, extension);
    final destinationPath = path.join(imagesDir.path, actualFileName);
    
    final file = File(destinationPath);
    await file.writeAsBytes(bytes);

    return destinationPath;
  }

  /// Loads image bytes from file path
  Future<Uint8List?> loadImageBytes(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (e) {
      debugPrint('Error loading image bytes: $e');
      return null;
    }
  }

  /// Checks if an image file exists
  Future<bool> imageExists(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      debugPrint('Error checking if image exists: $e');
      return false;
    }
  }

  /// Deletes an image file
  Future<bool> deleteImage(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting image: $e');
      return false;
    }
  }

  /// Gets the size of an image file in bytes
  Future<int> getImageSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      debugPrint('Error getting image size: $e');
      return 0;
    }
  }

  /// Lists all images in a directory
  Future<List<String>> listImages({String? customDir}) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final targetDir = customDir ?? _imagesDirName;
      final imagesDir = Directory(path.join(appDir.path, targetDir));

      if (!await imagesDir.exists()) {
        return [];
      }

      final List<FileSystemEntity> files = await imagesDir.list().toList();
      final List<String> imagePaths = [];

      for (final file in files) {
        if (file is File && _isImageFile(file.path)) {
          imagePaths.add(file.path);
        }
      }

      // Sort by modification date (newest first)
      imagePaths.sort((a, b) {
        final fileA = File(a);
        final fileB = File(b);
        return fileB.lastModifiedSync().compareTo(fileA.lastModifiedSync());
      });

      return imagePaths;
    } catch (e) {
      debugPrint('Error listing images: $e');
      return [];
    }
  }

  /// Cleans up images older than specified days
  Future<void> cleanupOldImages({
    int daysOld = 30,
    String? customDir,
    List<String>? excludePaths,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final targetDir = customDir ?? _imagesDirName;
      final imagesDir = Directory(path.join(appDir.path, targetDir));

      if (!await imagesDir.exists()) return;

      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      final List<FileSystemEntity> files = await imagesDir.list().toList();

      for (final file in files) {
        if (file is File) {
          // Skip excluded paths
          if (excludePaths?.contains(file.path) == true) continue;

          final lastModified = await file.lastModified();
          if (lastModified.isBefore(cutoffDate)) {
            try {
              await file.delete();
              debugPrint('Deleted old image: ${file.path}');
            } catch (e) {
              debugPrint('Error deleting old image ${file.path}: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up old images: $e');
    }
  }

  /// Gets the total storage used by images
  Future<int> getTotalStorageUsed({String? customDir}) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final targetDir = customDir ?? _imagesDirName;
      final imagesDir = Directory(path.join(appDir.path, targetDir));

      if (!await imagesDir.exists()) return 0;

      int totalSize = 0;
      final List<FileSystemEntity> files = await imagesDir.list().toList();

      for (final file in files) {
        if (file is File) {
          totalSize += await file.length();
        }
      }

      return totalSize;
    } catch (e) {
      debugPrint('Error calculating total storage used: $e');
      return 0;
    }
  }

  /// Creates a thumbnail from an image file
  Future<String?> createThumbnail(
    String originalImagePath, {
    int maxWidth = 200,
    int maxHeight = 200,
  }) async {
    try {
      // For this implementation, we'll just copy the original file
      // In a production app, you might want to use image processing libraries
      // like image package to actually resize the image
      final originalFile = File(originalImagePath);
      if (!await originalFile.exists()) return null;

      final appDir = await getApplicationDocumentsDirectory();
      final thumbnailsDir = Directory(path.join(appDir.path, _thumbnailsDirName));

      if (!await thumbnailsDir.exists()) {
        await thumbnailsDir.create(recursive: true);
      }

      final originalBytes = await originalFile.readAsBytes();
      final hash = sha256.convert(originalBytes).toString().substring(0, 16);
      final extension = path.extension(originalImagePath);
      final thumbnailFileName = 'thumb_${hash}_${maxWidth}x$maxHeight$extension';
      
      final thumbnailPath = path.join(thumbnailsDir.path, thumbnailFileName);
      
      // Check if thumbnail already exists
      final thumbnailFile = File(thumbnailPath);
      if (await thumbnailFile.exists()) {
        return thumbnailPath;
      }

      // For now, just copy the original (in production, resize it)
      await originalFile.copy(thumbnailPath);
      return thumbnailPath;
    } catch (e) {
      debugPrint('Error creating thumbnail: $e');
      return null;
    }
  }

  /// Validates if file is a supported image format
  bool _isImageFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(extension);
  }

  /// Generates a unique filename based on content hash
  String _generateUniqueFileName(Uint8List bytes, String extension) {
    final hash = sha256.convert(bytes).toString().substring(0, 16);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${hash}_$timestamp$extension';
  }

  /// Gets the app's images directory path
  Future<String> getImagesDirectoryPath({String? customDir}) async {
    final appDir = await getApplicationDocumentsDirectory();
    final targetDir = customDir ?? _imagesDirName;
    return path.join(appDir.path, targetDir);
  }

  /// Formats file size in human readable format
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}