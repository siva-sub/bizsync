import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'permission_utils.dart';
import 'permission_manager.dart';

/// Service for handling storage permissions and scoped storage access
class StoragePermissionService {
  static final instance = StoragePermissionService._internal();
  StoragePermissionService._internal();
  
  static const String _tag = 'StoragePermissionService';

  /// Check if we have sufficient permissions for file operations
  Future<bool> canAccessFiles() async {
    if (!Platform.isAndroid) return true; // iOS handles this differently
    
    final isAndroid10Plus = await PermissionUtils.isAndroid10OrAbove;
    
    if (isAndroid10Plus) {
      // Android 10+ with scoped storage
      return await _canAccessScopedStorage();
    } else {
      // Legacy storage access
      final status = await Permission.storage.status;
      return status.isGranted;
    }
  }

  /// Check if we can access scoped storage (Android 10+)
  Future<bool> _canAccessScopedStorage() async {
    try {
      // Test access to app-specific directory (always available)
      final appDir = await getApplicationDocumentsDirectory();
      final testFile = File('${appDir.path}/test_access.txt');
      
      await testFile.writeAsString('test');
      await testFile.delete();
      
      return true;
    } catch (e) {
      debugPrint('$_tag: Cannot access scoped storage: $e');
      return false;
    }
  }

  /// Check if we can access external storage for exports
  Future<bool> canAccessExternalStorage() async {
    if (!Platform.isAndroid) return true;
    
    final isAndroid10Plus = await PermissionUtils.isAndroid10OrAbove;
    
    if (isAndroid10Plus) {
      // Android 10+ - check if we have MANAGE_EXTERNAL_STORAGE or use SAF
      final manageStatus = await Permission.manageExternalStorage.status;
      if (manageStatus.isGranted) return true;
      
      // Otherwise, we'll need to use Storage Access Framework (SAF)
      return await _canUseSAF();
    } else {
      // Legacy external storage
      final status = await Permission.storage.status;
      return status.isGranted;
    }
  }

  /// Check if we can use Storage Access Framework
  Future<bool> _canUseSAF() async {
    // SAF is always available on Android 10+, but we need to guide users
    // to select directories through file picker
    return true;
  }

  /// Request appropriate storage permissions based on Android version
  Future<StoragePermissionResult> requestStoragePermissions({
    required BuildContext context,
    bool includeExternalStorage = false,
  }) async {
    if (!Platform.isAndroid) {
      return StoragePermissionResult.granted;
    }
    
    final isAndroid13Plus = await PermissionUtils.isAndroid13OrAbove;
    
    if (isAndroid13Plus) {
      return await _requestAndroid13PlusPermissions(context, includeExternalStorage);
    } else {
      return await _requestLegacyStoragePermissions(context, includeExternalStorage);
    }
  }

  /// Request storage permissions for Android 13+
  Future<StoragePermissionResult> _requestAndroid13PlusPermissions(
    BuildContext context,
    bool includeExternalStorage,
  ) async {
    // Show rationale for granular permissions
    if (context.mounted) {
      final shouldProceed = await _showAndroid13PermissionRationale(context);
      if (!shouldProceed) {
        return StoragePermissionResult.denied;
      }
    }
    
    // Request granular media permissions
    final permissions = [
      Permission.photos, // For profile pictures and document images
    ];
    
    if (includeExternalStorage) {
      permissions.add(Permission.manageExternalStorage);
    }
    
    final manager = PermissionManager.instance;
    final results = await manager.requestMultiplePermissions(permissions);
    
    // Check if we got at least photos permission
    final photosGranted = results[Permission.photos]?.isGranted ?? false;
    
    if (photosGranted) {
      return StoragePermissionResult.granted;
    } else if (results[Permission.photos]?.isPermanentlyDenied ?? false) {
      return StoragePermissionResult.permanentlyDenied;
    } else {
      return StoragePermissionResult.denied;
    }
  }

  /// Request legacy storage permissions (Android 12 and below)
  Future<StoragePermissionResult> _requestLegacyStoragePermissions(
    BuildContext context,
    bool includeExternalStorage,
  ) async {
    if (context.mounted) {
      final shouldProceed = await _showLegacyStorageRationale(context);
      if (!shouldProceed) {
        return StoragePermissionResult.denied;
      }
    }
    
    final manager = PermissionManager.instance;
    final storageStatus = await manager.requestPermission(Permission.storage);
    
    if (storageStatus.isGranted) {
      return StoragePermissionResult.granted;
    } else if (storageStatus.isPermanentlyDenied) {
      return StoragePermissionResult.permanentlyDenied;
    } else {
      return StoragePermissionResult.denied;
    }
  }

  /// Show rationale for Android 13+ permissions
  Future<bool> _showAndroid13PermissionRationale(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.photo_library_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Media Access Required',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BizSync needs access to photos and files for:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 12),
            Text('• Setting profile pictures'),
            Text('• Attaching images to invoices'),
            Text('• Importing business documents'),
            Text('• Backing up your data'),
            SizedBox(height: 16),
            Text(
              'We only access files you specifically choose. Your privacy is protected by Android\'s granular permissions.',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Show rationale for legacy storage permissions
  Future<bool> _showLegacyStorageRationale(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.folder_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Storage Access Required',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BizSync needs storage access for:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 12),
            Text('• Saving business documents and invoices'),
            Text('• Creating and restoring backups'),
            Text('• Exporting reports and data'),
            Text('• Managing your business files'),
            SizedBox(height: 16),
            Text(
              'All data remains secure on your device. We never access personal files outside the app.',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Grant Access'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Get recommended storage directories for different file types
  Future<Map<String, Directory>> getRecommendedDirectories() async {
    final directories = <String, Directory>{};
    
    try {
      // App-specific directories (always accessible)
      final appDocs = await getApplicationDocumentsDirectory();
      directories['documents'] = appDocs;
      
      final appSupport = await getApplicationSupportDirectory();
      directories['data'] = appSupport;
      
      // Try to get external storage directories if available
      if (Platform.isAndroid) {
        try {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            directories['external'] = externalDir;
          }
        } catch (e) {
          debugPrint('$_tag: Cannot access external storage: $e');
        }
      }
      
      // Downloads directory (if accessible)
      try {
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null) {
          directories['downloads'] = downloadsDir;
        }
      } catch (e) {
        debugPrint('$_tag: Cannot access downloads directory: $e');
      }
      
    } catch (e) {
      debugPrint('$_tag: Error getting directories: $e');
    }
    
    return directories;
  }

  /// Check if a specific directory is writable
  Future<bool> isDirectoryWritable(Directory directory) async {
    try {
      final testFile = File('${directory.path}/.bizsync_write_test');
      await testFile.writeAsString('test');
      await testFile.delete();
      return true;
    } catch (e) {
      debugPrint('$_tag: Directory ${directory.path} is not writable: $e');
      return false;
    }
  }

  /// Get the best available directory for file operations
  Future<Directory> getBestStorageDirectory() async {
    final directories = await getRecommendedDirectories();
    
    // Prefer external storage if available and writable
    if (directories.containsKey('external')) {
      final externalDir = directories['external']!;
      if (await isDirectoryWritable(externalDir)) {
        return externalDir;
      }
    }
    
    // Fall back to documents directory
    return directories['documents']!;
  }

  /// Create app-specific folders in the best storage location
  Future<Map<String, Directory>> createAppFolders() async {
    final baseDir = await getBestStorageDirectory();
    final folders = <String, Directory>{};
    
    final folderNames = [
      'invoices',
      'receipts', 
      'backups',
      'exports',
      'templates',
      'documents',
    ];
    
    for (final folderName in folderNames) {
      try {
        final folder = Directory('${baseDir.path}/BizSync/$folderName');
        await folder.create(recursive: true);
        folders[folderName] = folder;
        
        debugPrint('$_tag: Created folder: ${folder.path}');
      } catch (e) {
        debugPrint('$_tag: Failed to create folder $folderName: $e');
      }
    }
    
    return folders;
  }
}

/// Result of storage permission request
enum StoragePermissionResult {
  granted,
  denied,
  permanentlyDenied,
}

/// Extension to check Android storage permission requirements
extension StoragePermissionResultExt on StoragePermissionResult {
  bool get isGranted => this == StoragePermissionResult.granted;
  bool get isDenied => this == StoragePermissionResult.denied;
  bool get isPermanentlyDenied => this == StoragePermissionResult.permanentlyDenied;
  
  String get message {
    switch (this) {
      case StoragePermissionResult.granted:
        return 'Storage access granted successfully';
      case StoragePermissionResult.denied:
        return 'Storage access denied';
      case StoragePermissionResult.permanentlyDenied:
        return 'Storage access permanently denied. Please enable in Settings.';
    }
  }
}