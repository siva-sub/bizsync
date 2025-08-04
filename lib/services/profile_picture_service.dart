import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for handling profile picture operations including selection,
/// storage, and retrieval across Android and desktop platforms.
class ProfilePictureService {
  static const String _profilePicturePathKey = 'profile_picture_path';
  static const String _profilePicturesDirName = 'profile_pictures';
  
  final ImagePicker _imagePicker = ImagePicker();

  /// Shows an action sheet for selecting image source (camera or gallery)
  Future<String?> selectAndSaveProfilePicture(BuildContext context) async {
    try {
      final ImageSource? source = await _showImageSourceDialog(context);
      if (source == null) return null;

      // Check and request permissions
      final hasPermission = await _checkAndRequestPermissions(source);
      if (!hasPermission) {
        if (context.mounted) {
          _showPermissionDeniedMessage(context);
        }
        return null;
      }

      // Pick the image
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image == null) return null;

      // Save the image and return the path
      return await _saveProfilePicture(image);
    } catch (e) {
      debugPrint('Error selecting profile picture: $e');
      if (context.mounted) {
        _showErrorMessage(context, 'Failed to select image: ${e.toString()}');
      }
      return null;
    }
  }

  /// Shows dialog for selecting image source
  Future<ImageSource?> _showImageSourceDialog(BuildContext context) async {
    // On desktop, only show gallery option
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      return ImageSource.gallery;
    }

    return await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Select Profile Picture',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Camera'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Checks and requests necessary permissions
  Future<bool> _checkAndRequestPermissions(ImageSource source) async {
    // On desktop platforms, no permissions needed
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      return true;
    }

    // On mobile platforms, check specific permissions
    if (source == ImageSource.camera) {
      final cameraStatus = await Permission.camera.status;
      if (cameraStatus.isDenied) {
        final result = await Permission.camera.request();
        return result.isGranted;
      }
      return cameraStatus.isGranted;
    } else {
      // For gallery access
      if (Platform.isAndroid) {
        // Android 13+ uses different permissions
        final androidInfo = await _getAndroidVersion();
        if (androidInfo >= 33) {
          final photosStatus = await Permission.photos.status;
          if (photosStatus.isDenied) {
            final result = await Permission.photos.request();
            return result.isGranted;
          }
          return photosStatus.isGranted;
        } else {
          final storageStatus = await Permission.storage.status;
          if (storageStatus.isDenied) {
            final result = await Permission.storage.request();
            return result.isGranted;
          }
          return storageStatus.isGranted;
        }
      }
    }

    return true;
  }

  /// Gets Android SDK version for permission handling
  Future<int> _getAndroidVersion() async {
    if (!Platform.isAndroid) return 0;
    
    try {
      // This is a simplified version - in practice you might want to use device_info_plus
      return 33; // Assume modern Android for safety
    } catch (e) {
      return 33; // Default to modern Android
    }
  }

  /// Saves the selected image to app's documents directory
  Future<String> _saveProfilePicture(XFile image) async {
    final appDir = await getApplicationDocumentsDirectory();
    final profilePicturesDir = Directory(path.join(appDir.path, _profilePicturesDirName));
    
    // Create directory if it doesn't exist
    if (!await profilePicturesDir.exists()) {
      await profilePicturesDir.create(recursive: true);
    }

    // Generate unique filename
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = path.extension(image.path);
    final fileName = 'profile_$timestamp$extension';
    final filePath = path.join(profilePicturesDir.path, fileName);

    // Copy file to app directory
    final File sourceFile = File(image.path);
    final File destinationFile = await sourceFile.copy(filePath);

    // Save path to shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profilePicturePathKey, destinationFile.path);

    return destinationFile.path;
  }

  /// Retrieves the current profile picture path
  Future<String?> getProfilePicturePath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final picturePath = prefs.getString(_profilePicturePathKey);
      
      // Verify file still exists
      if (picturePath != null) {
        final file = File(picturePath);
        if (await file.exists()) {
          return picturePath;
        } else {
          // Clean up invalid path
          await prefs.remove(_profilePicturePathKey);
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting profile picture path: $e');
      return null;
    }
  }

  /// Retrieves profile picture as bytes for display
  Future<Uint8List?> getProfilePictureBytes() async {
    try {
      final picturePath = await getProfilePicturePath();
      if (picturePath == null) return null;

      final file = File(picturePath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      
      return null;
    } catch (e) {
      debugPrint('Error reading profile picture bytes: $e');
      return null;
    }
  }

  /// Deletes the current profile picture
  Future<bool> deleteProfilePicture() async {
    try {
      final picturePath = await getProfilePicturePath();
      if (picturePath == null) return true;

      final file = File(picturePath);
      if (await file.exists()) {
        await file.delete();
      }

      // Remove from shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_profilePicturePathKey);

      return true;
    } catch (e) {
      debugPrint('Error deleting profile picture: $e');
      return false;
    }
  }

  /// Shows permission denied message
  void _showPermissionDeniedMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Permission denied. Please grant camera/storage access in Settings.'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Settings',
          onPressed: () => openAppSettings(),
        ),
      ),
    );
  }

  /// Shows error message
  void _showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  /// Cleans up old profile pictures (keeps only the latest one)
  Future<void> cleanupOldProfilePictures() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final profilePicturesDir = Directory(path.join(appDir.path, _profilePicturesDirName));
      
      if (!await profilePicturesDir.exists()) return;

      final currentPath = await getProfilePicturePath();
      final List<FileSystemEntity> files = await profilePicturesDir.list().toList();
      
      for (final file in files) {
        if (file is File && file.path != currentPath) {
          try {
            await file.delete();
          } catch (e) {
            debugPrint('Error deleting old profile picture: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up old profile pictures: $e');
    }
  }
}