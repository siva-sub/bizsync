import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Comprehensive permission utilities for Android storage and media permissions
/// Handles Android 10+ scoped storage and Android 13+ granular media permissions
class PermissionUtils {
  static const String _tag = 'PermissionUtils';

  /// Check if the current Android version supports scoped storage
  static Future<bool> get isAndroid10OrAbove async {
    if (!Platform.isAndroid) return false;
    
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.version.sdkInt >= 29; // Android 10
    } catch (e) {
      debugPrint('$_tag: Error checking Android version: $e');
      return false;
    }
  }

  /// Check if the current Android version supports granular media permissions
  static Future<bool> get isAndroid13OrAbove async {
    if (!Platform.isAndroid) return false;
    
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.version.sdkInt >= 33; // Android 13
    } catch (e) {
      debugPrint('$_tag: Error checking Android version: $e');
      return false;
    }
  }

  /// Check if the current Android version supports enhanced photo picker
  static Future<bool> get isAndroid14OrAbove async {
    if (!Platform.isAndroid) return false;
    
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.version.sdkInt >= 34; // Android 14
    } catch (e) {
      debugPrint('$_tag: Error checking Android version: $e');
      return false;
    }
  }

  /// Get appropriate storage permissions based on Android version
  static Future<List<Permission>> getStoragePermissions() async {
    final permissions = <Permission>[];
    
    if (Platform.isAndroid) {
      final isAndroid13Plus = await isAndroid13OrAbove;
      
      if (isAndroid13Plus) {
        // Android 13+ granular media permissions
        permissions.addAll([
          Permission.photos, // READ_MEDIA_IMAGES
          Permission.videos, // READ_MEDIA_VIDEO
          Permission.audio,  // READ_MEDIA_AUDIO
        ]);
        
        // Check for Android 14+ enhanced photo picker
        final isAndroid14Plus = await isAndroid14OrAbove;
        if (isAndroid14Plus) {
          permissions.add(Permission.photosAddOnly); // READ_MEDIA_VISUAL_USER_SELECTED
        }
      } else {
        // Android 12 and below - use legacy storage permissions
        permissions.addAll([
          Permission.storage,
          Permission.manageExternalStorage,
        ]);
      }
    }
    
    return permissions;
  }

  /// Get all required permissions for the app
  static Future<Map<String, List<Permission>>> getAllRequiredPermissions() async {
    final permissions = <String, List<Permission>>{};
    
    // Storage permissions (varies by Android version)
    permissions['storage'] = await getStoragePermissions();
    
    // Camera permission
    permissions['camera'] = [Permission.camera];
    
    // Notification permissions
    permissions['notifications'] = [Permission.notification];
    
    // Location permissions
    permissions['location'] = [
      Permission.locationWhenInUse,
      Permission.location,
    ];
    
    // Biometric permissions
    permissions['biometric'] = []; // Handled by local_auth plugin
    
    return permissions;
  }

  /// Check status of all storage-related permissions
  static Future<Map<Permission, PermissionStatus>> checkStoragePermissions() async {
    final storagePermissions = await getStoragePermissions();
    final statuses = <Permission, PermissionStatus>{};
    
    for (final permission in storagePermissions) {
      try {
        statuses[permission] = await permission.status;
      } catch (e) {
        debugPrint('$_tag: Error checking permission $permission: $e');
        statuses[permission] = PermissionStatus.denied;
      }
    }
    
    return statuses;
  }

  /// Request storage permissions with proper Android version handling
  static Future<Map<Permission, PermissionStatus>> requestStoragePermissions({
    bool showRationale = true,
    BuildContext? context,
  }) async {
    final storagePermissions = await getStoragePermissions();
    final results = <Permission, PermissionStatus>{};
    
    // Show rationale if needed and context is provided
    if (showRationale && context != null) {
      final shouldProceed = await _showStoragePermissionRationale(context);
      if (!shouldProceed) {
        // User declined, return denied status for all
        for (final permission in storagePermissions) {
          results[permission] = PermissionStatus.denied;
        }
        return results;
      }
    }
    
    // Request permissions one by one for better error handling
    for (final permission in storagePermissions) {
      try {
        final status = await permission.request();
        results[permission] = status;
        
        debugPrint('$_tag: Permission $permission result: $status');
      } catch (e) {
        debugPrint('$_tag: Error requesting permission $permission: $e');
        results[permission] = PermissionStatus.denied;
      }
    }
    
    return results;
  }

  /// Request specific permission with rationale
  static Future<PermissionStatus> requestPermissionWithRationale({
    required Permission permission,
    required BuildContext context,
    required String title,
    required String description,
    required String rationale,
  }) async {
    // Check current status
    final currentStatus = await permission.status;
    
    // If already granted, return
    if (currentStatus.isGranted) {
      return currentStatus;
    }
    
    // If permanently denied, direct to settings
    if (currentStatus.isPermanentlyDenied) {
      await _showPermanentlyDeniedDialog(
        context: context,
        title: title,
        description: description,
      );
      return currentStatus;
    }
    
    // Show rationale dialog
    final shouldRequest = await _showPermissionRationaleDialog(
      context: context,
      title: title,
      description: description,
      rationale: rationale,
    );
    
    if (!shouldRequest) {
      return PermissionStatus.denied;
    }
    
    // Request permission
    return await permission.request();
  }

  /// Check if storage permissions are sufficient for the app's needs
  static Future<bool> areStoragePermissionsSufficient() async {
    final storageStatuses = await checkStoragePermissions();
    
    // For Android 13+, we need at least images permission for profile pictures
    final isAndroid13Plus = await isAndroid13OrAbove;
    
    if (isAndroid13Plus) {
      // Check if we have at least image access
      final imageStatus = storageStatuses[Permission.photos];
      return imageStatus?.isGranted ?? false;
    } else {
      // For older Android versions, check legacy storage permission
      final storageStatus = storageStatuses[Permission.storage];
      return storageStatus?.isGranted ?? false;
    }
  }

  /// Show storage permission rationale dialog
  static Future<bool> _showStoragePermissionRationale(BuildContext context) async {
    final isAndroid13Plus = await isAndroid13OrAbove;
    
    final title = 'Storage Access Required';
    final content = isAndroid13Plus
        ? 'BizSync needs access to photos and files to:\n\n'
          '• Save and backup your business data\n'
          '• Import/export invoices and documents\n'
          '• Set profile pictures\n'
          '• Store generated reports\n\n'
          'We only access files you specifically choose or create.'
        : 'BizSync needs storage access to:\n\n'
          '• Save and backup your business data\n'
          '• Import/export invoices and documents\n'
          '• Store generated reports and files\n'
          '• Manage your business documents\n\n'
          'Your data remains private and secure on your device.';
    
    return await _showPermissionRationaleDialog(
      context: context,
      title: title,
      description: content,
      rationale: 'This permission is essential for core app functionality.',
    );
  }

  /// Show permission rationale dialog
  static Future<bool> _showPermissionRationaleDialog({
    required BuildContext context,
    required String title,
    required String description,
    required String rationale,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.security,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rationale,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
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
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  /// Show permanently denied permission dialog
  static Future<void> _showPermanentlyDeniedDialog({
    required BuildContext context,
    required String title,
    required String description,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_outlined,
              color: Colors.orange,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Permission Required',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The $title permission has been permanently denied.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.settings_outlined,
                    size: 20,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please enable this permission in Settings > Apps > BizSync > Permissions',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Get user-friendly permission names
  static String getPermissionDisplayName(Permission permission) {
    switch (permission) {
      case Permission.storage:
        return 'Storage';
      case Permission.photos:
        return 'Photos';
      case Permission.videos:
        return 'Videos';
      case Permission.audio:
        return 'Audio Files';
      case Permission.camera:
        return 'Camera';
      case Permission.notification:
        return 'Notifications';
      case Permission.location:
      case Permission.locationWhenInUse:
        return 'Location';
      case Permission.manageExternalStorage:
        return 'File Management';
      case Permission.photosAddOnly:
        return 'Photo Selection';
      default:
        return permission.toString().split('.').last.capitalize();
    }
  }

  /// Get permission descriptions for rationales
  static String getPermissionDescription(Permission permission) {
    switch (permission) {
      case Permission.storage:
        return 'Access files and documents on your device for backup and restore operations.';
      case Permission.photos:
        return 'Access photos for profile pictures and document attachments.';
      case Permission.videos:
        return 'Access videos for business presentations and training materials.';
      case Permission.audio:
        return 'Access audio files for voice memos and recorded meetings.';
      case Permission.camera:
        return 'Take photos of documents and scan QR codes for payments.';
      case Permission.notification:
        return 'Show important business reminders and payment notifications.';
      case Permission.location:
      case Permission.locationWhenInUse:
        return 'Auto-fill addresses and provide location-based business insights.';
      case Permission.manageExternalStorage:
        return 'Manage business files and create organized backup structures.';
      case Permission.photosAddOnly:
        return 'Select specific photos without accessing your entire photo library.';
      default:
        return 'Enable this feature for full app functionality.';
    }
  }

  /// Debug: Log all permission statuses
  static Future<void> debugLogAllPermissions() async {
    if (!Platform.isAndroid) return;
    
    debugPrint('$_tag: === Permission Status Debug ===');
    
    final permissions = await getAllRequiredPermissions();
    
    for (final category in permissions.entries) {
      debugPrint('$_tag: ${category.key.toUpperCase()} Permissions:');
      
      for (final permission in category.value) {
        try {
          final status = await permission.status;
          debugPrint('$_tag:   ${getPermissionDisplayName(permission)}: $status');
        } catch (e) {
          debugPrint('$_tag:   ${getPermissionDisplayName(permission)}: ERROR - $e');
        }
      }
    }
    
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    debugPrint('$_tag: Android SDK: ${androidInfo.version.sdkInt}');
    debugPrint('$_tag: Android Release: ${androidInfo.version.release}');
    debugPrint('$_tag: === End Permission Debug ===');
  }
}

/// Extension for string capitalization
extension StringCapitalization on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}

/// Permission state data class
class PermissionState {
  final Permission permission;
  final PermissionStatus status;
  final String displayName;
  final String description;
  final bool isRequired;

  const PermissionState({
    required this.permission,
    required this.status,
    required this.displayName,
    required this.description,
    this.isRequired = false,
  });

  bool get isGranted => status.isGranted;
  bool get isDenied => status.isDenied;
  bool get isPermanentlyDenied => status.isPermanentlyDenied;
  bool get isRestricted => status.isRestricted;
  bool get isLimited => status.isLimited;

  PermissionState copyWith({
    Permission? permission,
    PermissionStatus? status,
    String? displayName,
    String? description,
    bool? isRequired,
  }) {
    return PermissionState(
      permission: permission ?? this.permission,
      status: status ?? this.status,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      isRequired: isRequired ?? this.isRequired,
    );
  }
}