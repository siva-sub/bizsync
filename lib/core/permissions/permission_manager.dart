import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'permission_utils.dart';

/// Permission manager service for handling app-wide permission requests and caching
class PermissionManager {
  static final instance = PermissionManager._internal();
  PermissionManager._internal();

  final Map<Permission, PermissionStatus> _cachedStatuses = {};
  final Map<String, DateTime> _lastChecked = {};
  
  static const Duration _cacheExpiry = Duration(minutes: 5);
  static const String _tag = 'PermissionManager';

  /// Get cached permission status or check fresh if cache expired
  Future<PermissionStatus> getPermissionStatus(Permission permission) async {
    final cacheKey = permission.toString();
    final lastCheck = _lastChecked[cacheKey];
    final now = DateTime.now();
    
    // Return cached status if available and not expired
    if (lastCheck != null && 
        now.difference(lastCheck) < _cacheExpiry && 
        _cachedStatuses.containsKey(permission)) {
      return _cachedStatuses[permission]!;
    }
    
    // Check fresh status
    try {
      final status = await permission.status;
      _cachedStatuses[permission] = status;
      _lastChecked[cacheKey] = now;
      return status;
    } catch (e) {
      debugPrint('$_tag: Error checking permission $permission: $e');
      return PermissionStatus.denied;
    }
  }

  /// Check multiple permissions at once
  Future<Map<Permission, PermissionStatus>> getMultiplePermissionStatuses(
    List<Permission> permissions,
  ) async {
    final results = <Permission, PermissionStatus>{};
    
    for (final permission in permissions) {
      results[permission] = await getPermissionStatus(permission);
    }
    
    return results;
  }

  /// Request single permission with caching
  Future<PermissionStatus> requestPermission(Permission permission) async {
    try {
      final status = await permission.request();
      
      // Update cache
      _cachedStatuses[permission] = status;
      _lastChecked[permission.toString()] = DateTime.now();
      
      debugPrint('$_tag: Requested permission $permission, result: $status');
      return status;
    } catch (e) {
      debugPrint('$_tag: Error requesting permission $permission: $e');
      return PermissionStatus.denied;
    }
  }

  /// Request multiple permissions
  Future<Map<Permission, PermissionStatus>> requestMultiplePermissions(
    List<Permission> permissions,
  ) async {
    final results = <Permission, PermissionStatus>{};
    
    for (final permission in permissions) {
      results[permission] = await requestPermission(permission);
    }
    
    return results;
  }

  /// Clear permission cache
  void clearCache() {
    _cachedStatuses.clear();
    _lastChecked.clear();
    debugPrint('$_tag: Permission cache cleared');
  }

  /// Force refresh specific permission status
  Future<PermissionStatus> refreshPermissionStatus(Permission permission) async {
    // Remove from cache to force fresh check
    _cachedStatuses.remove(permission);
    _lastChecked.remove(permission.toString());
    
    return await getPermissionStatus(permission);
  }

  /// Check if any storage permission is granted
  Future<bool> hasAnyStoragePermission() async {
    final storagePermissions = await PermissionUtils.getStoragePermissions();
    final statuses = await getMultiplePermissionStatuses(storagePermissions);
    
    return statuses.values.any((status) => status.isGranted);
  }

  /// Check if all required permissions are granted
  Future<bool> hasAllRequiredPermissions() async {
    final requiredPermissions = [
      Permission.notification, // Essential for business reminders
    ];
    
    // Add storage permissions based on Android version
    final storagePermissions = await PermissionUtils.getStoragePermissions();
    
    // For Android 13+, at least photos permission is required
    final isAndroid13Plus = await PermissionUtils.isAndroid13OrAbove;
    if (isAndroid13Plus) {
      requiredPermissions.add(Permission.photos);
    } else {
      requiredPermissions.add(Permission.storage);
    }
    
    final statuses = await getMultiplePermissionStatuses(requiredPermissions);
    return statuses.values.every((status) => status.isGranted);
  }

  /// Get permission summary for UI display
  Future<List<PermissionState>> getPermissionSummary() async {
    final permissionGroups = await PermissionUtils.getAllRequiredPermissions();
    final states = <PermissionState>[];
    
    for (final group in permissionGroups.entries) {
      for (final permission in group.value) {
        final status = await getPermissionStatus(permission);
        final state = PermissionState(
          permission: permission,
          status: status,
          displayName: PermissionUtils.getPermissionDisplayName(permission),
          description: PermissionUtils.getPermissionDescription(permission),
          isRequired: _isPermissionRequired(permission),
        );
        states.add(state);
      }
    }
    
    return states;
  }

  /// Check if a permission is required for core functionality
  bool _isPermissionRequired(Permission permission) {
    switch (permission) {
      case Permission.notification:
        return true; // Essential for business app
      case Permission.photos:
      case Permission.storage:
        return true; // Need at least one for file operations
      case Permission.camera:
        return false; // Nice to have for QR scanning
      case Permission.location:
      case Permission.locationWhenInUse:
        return false; // Optional for address autofill
      default:
        return false;
    }
  }

  /// Handle permission request with user-friendly flow
  Future<PermissionRequestResult> requestPermissionWithFlow({
    required Permission permission,
    required BuildContext context,
    bool showRationale = true,
  }) async {
    final currentStatus = await getPermissionStatus(permission);
    
    // Already granted
    if (currentStatus.isGranted) {
      return PermissionRequestResult.granted;
    }
    
    // Permanently denied - direct to settings
    if (currentStatus.isPermanentlyDenied) {
      if (context.mounted) {
        await _showSettingsDialog(context, permission);
      }
      return PermissionRequestResult.permanentlyDenied;
    }
    
    // Show rationale if requested
    if (showRationale && context.mounted) {
      final shouldRequest = await _showRationaleDialog(context, permission);
      if (!shouldRequest) {
        return PermissionRequestResult.denied;
      }
    }
    
    // Request permission
    final newStatus = await requestPermission(permission);
    
    switch (newStatus) {
      case PermissionStatus.granted:
        return PermissionRequestResult.granted;
      case PermissionStatus.permanentlyDenied:
        return PermissionRequestResult.permanentlyDenied;
      default:
        return PermissionRequestResult.denied;
    }
  }

  /// Show rationale dialog for permission
  Future<bool> _showRationaleDialog(BuildContext context, Permission permission) async {
    final displayName = PermissionUtils.getPermissionDisplayName(permission);
    final description = PermissionUtils.getPermissionDescription(permission);
    
    return await PermissionUtils.requestPermissionWithRationale(
      permission: permission,
      context: context,
      title: '$displayName Permission',
      description: description,
      rationale: 'This permission helps provide better functionality.',
    ).then((status) => status.isGranted);
  }

  /// Show settings dialog for permanently denied permission
  Future<void> _showSettingsDialog(BuildContext context, Permission permission) async {
    final displayName = PermissionUtils.getPermissionDisplayName(permission);
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$displayName Permission Required'),
        content: Text(
          'This permission has been permanently denied. '
          'Please enable it in Settings to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
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
}

/// Result of permission request flow
enum PermissionRequestResult {
  granted,
  denied,
  permanentlyDenied,
}

/// Riverpod provider for permission manager
final permissionManagerProvider = Provider<PermissionManager>((ref) {
  return PermissionManager.instance;
});

/// Riverpod provider for storage permission status
final storagePermissionStatusProvider = FutureProvider<bool>((ref) async {
  final manager = ref.read(permissionManagerProvider);
  return await manager.hasAnyStoragePermission();
});

/// Riverpod provider for all required permissions status
final allRequiredPermissionsProvider = FutureProvider<bool>((ref) async {
  final manager = ref.read(permissionManagerProvider);
  return await manager.hasAllRequiredPermissions();
});

/// Riverpod provider for permission summary
final permissionSummaryProvider = FutureProvider<List<PermissionState>>((ref) async {
  final manager = ref.read(permissionManagerProvider);
  return await manager.getPermissionSummary();
});

/// Auto-refresh permission statuses when app becomes active
final permissionRefreshProvider = StateNotifierProvider<PermissionRefreshNotifier, DateTime>((ref) {
  return PermissionRefreshNotifier(ref);
});

class PermissionRefreshNotifier extends StateNotifier<DateTime> {
  final Ref ref;
  
  PermissionRefreshNotifier(this.ref) : super(DateTime.now());
  
  void refreshPermissions() {
    final manager = ref.read(permissionManagerProvider);
    manager.clearCache();
    state = DateTime.now();
    
    // Invalidate providers to trigger refresh
    ref.invalidate(storagePermissionStatusProvider);
    ref.invalidate(allRequiredPermissionsProvider);
    ref.invalidate(permissionSummaryProvider);
  }
}