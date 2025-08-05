# BizSync Permission System

This module provides comprehensive permission handling for the BizSync business management app, with special focus on Android storage permissions and compatibility with modern Android versions.

## Overview

The permission system handles:
- Android 13+ (API 33+) granular media permissions
- Android 10+ (API 29+) scoped storage
- Legacy storage permissions for older Android versions
- Camera, notification, and location permissions
- User-friendly permission request flows with rationales

## Key Components

### 1. PermissionUtils (`permission_utils.dart`)
Core utilities for checking Android versions and determining appropriate permissions.

**Key Features:**
- Automatic Android version detection
- Dynamic permission list generation based on OS version
- User-friendly permission names and descriptions
- Debug logging for permission states

**Usage:**
```dart
// Check if device supports granular media permissions
final isAndroid13Plus = await PermissionUtils.isAndroid13OrAbove;

// Get appropriate storage permissions for current Android version
final storagePermissions = await PermissionUtils.getStoragePermissions();

// Request storage permissions with rationale
final results = await PermissionUtils.requestStoragePermissions(
  context: context,
  showRationale: true,
);
```

### 2. PermissionManager (`permission_manager.dart`)
Centralized permission management with caching and Riverpod integration.

**Key Features:**
- Permission status caching (5-minute expiry)
- Batch permission requests
- Riverpod providers for reactive UI updates
- Permission request flow management

**Usage:**
```dart
final manager = PermissionManager.instance;

// Get cached or fresh permission status
final status = await manager.getPermissionStatus(Permission.photos);

// Request permission with user-friendly flow
final result = await manager.requestPermissionWithFlow(
  permission: Permission.camera,
  context: context,
  showRationale: true,
);
```

### 3. StoragePermissionService (`storage_permission_service.dart`)
Specialized service for handling storage permissions and scoped storage access.

**Key Features:**
- Android version-aware storage handling
- Scoped storage compatibility
- Directory management and recommendations
- File access validation

**Usage:**
```dart
final service = StoragePermissionService.instance;

// Check if app can access files
final canAccess = await service.canAccessFiles();

// Request storage permissions with business rationale
final result = await service.requestStoragePermissions(
  context: context,
  includeExternalStorage: true,
);

// Get best available storage directory
final directory = await service.getBestStorageDirectory();
```

### 4. PermissionConfig (`permission_config.dart`)
Configuration and constants for permission handling.

**Key Features:**
- Centralized permission rationales and messages
- Business-specific explanations
- Permission categorization (essential/enhanced/optional)
- UI configuration constants

## Android Version Compatibility

### Android 13+ (API 33+)
**Granular Media Permissions:**
- `READ_MEDIA_IMAGES` - For profile pictures and document images
- `READ_MEDIA_VIDEO` - For business videos and presentations  
- `READ_MEDIA_AUDIO` - For voice memos and audio files

**Benefits:**
- Better user privacy control
- More specific permission requests
- Reduced permission scope

### Android 10-12 (API 29-32)
**Scoped Storage:**
- Uses app-specific directories by default
- Requires Storage Access Framework (SAF) for shared storage
- `READ_EXTERNAL_STORAGE` for legacy compatibility

### Android 9 and below (API 28-)
**Legacy Storage:**
- `READ_EXTERNAL_STORAGE` and `WRITE_EXTERNAL_STORAGE`
- Full external storage access
- Simpler but less secure model

## Permission Categories

### Essential Permissions
Required for core app functionality:
- **Notifications** - Business reminders and alerts
- **Photos** (Android 13+) or **Storage** (older) - Document management

### Enhanced Permissions  
Greatly improve functionality:
- **Camera** - QR code scanning and document capture
- **Storage/Manage External Storage** - Advanced file operations

### Optional Permissions
Nice-to-have features:
- **Location** - Address autofill and location-based insights
- **Audio/Video** - Multimedia business content

## Implementation Examples

### Basic Permission Check
```dart
import 'package:bizsync/core/permissions/index.dart';

// Check if storage permission is granted
final manager = PermissionManager.instance;
final hasStorage = await manager.hasAnyStoragePermission();

if (!hasStorage) {
  // Request permission
  final result = await StoragePermissionService.instance
      .requestStoragePermissions(context: context);
      
  if (result.isGranted) {
    // Proceed with file operations
  }
}
```

### Riverpod Integration
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bizsync/core/permissions/index.dart';

class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storagePermission = ref.watch(storagePermissionStatusProvider);
    
    return storagePermission.when(
      data: (hasPermission) => hasPermission 
          ? FileOperationsWidget()
          : PermissionRequestWidget(),
      loading: () => CircularProgressIndicator(),
      error: (error, stack) => ErrorWidget(error),
    );
  }
}
```

### Advanced Storage Operations
```dart
// Get recommended directories for different file types
final service = StoragePermissionService.instance;
final directories = await service.getRecommendedDirectories();

// Create app-specific folder structure
final appFolders = await service.createAppFolders();
final invoicesFolder = appFolders['invoices'];

// Check if directory is writable
final canWrite = await service.isDirectoryWritable(invoicesFolder!);
```

## Best Practices

### 1. Always Check Permissions Before Operations
```dart
// DON'T do this
await File('/storage/emulated/0/invoice.pdf').writeAsString(data);

// DO this
final hasPermission = await manager.hasAnyStoragePermission();
if (hasPermission) {
  final directory = await service.getBestStorageDirectory();
  await File('${directory.path}/invoice.pdf').writeAsString(data);
}
```

### 2. Provide Clear Rationales
```dart
// Use business-focused explanations
final result = await PermissionUtils.requestPermissionWithRationale(
  permission: Permission.camera,
  context: context,
  title: 'Camera Access Required',
  description: 'BizSync needs camera access to scan QR codes for payments and capture business documents.',
  rationale: 'This enables quick payment processing and digital document management.',
);
```

### 3. Handle Permanent Denials Gracefully
```dart
if (result == PermissionRequestResult.permanentlyDenied) {
  // Show dialog explaining how to enable in settings
  // Provide alternative workflows when possible
}
```

### 4. Use Scoped Storage Appropriately
```dart
// For app-specific data (always accessible)
final appDir = await getApplicationDocumentsDirectory();
final businessDataFile = File('${appDir.path}/business_data.json');

// For shared files (requires permission)
if (await service.canAccessExternalStorage()) {
  final publicDir = await service.getBestStorageDirectory();
  final exportFile = File('${publicDir.path}/BizSync/exports/report.pdf');
}
```

## Testing

### Permission Testing Checklist
- [ ] Test on Android 10, 13, and 14 devices
- [ ] Verify permission dialogs show appropriate rationales
- [ ] Test permission denial and retry flows
- [ ] Ensure app works with minimal permissions
- [ ] Verify file operations work in scoped storage
- [ ] Test permission state persistence across app restarts

### Debug Tools
```dart
// Enable debug logging
await PermissionUtils.debugLogAllPermissions();

// Check permission summary
final summary = await PermissionManager.instance.getPermissionSummary();
for (final state in summary) {
  print('${state.displayName}: ${state.status}');
}
```

## Security Considerations

1. **Minimal Permissions**: Only request permissions actually needed
2. **User Control**: Always explain why permissions are needed
3. **Graceful Degradation**: App should work with reduced functionality if permissions are denied
4. **Data Protection**: Use app-specific directories when possible
5. **Audit Trail**: Log permission requests and changes for compliance

## Migration Guide

### From Legacy Storage to Granular Permissions

**Before (Android 12 and below):**
```dart
final status = await Permission.storage.request();
```

**After (Android 13+):**
```dart
final storageService = StoragePermissionService.instance;
final result = await storageService.requestStoragePermissions(context: context);
```

The permission system automatically handles version detection and requests appropriate permissions.

## Troubleshooting

### Common Issues

1. **Permission not granted on Android 13+**
   - Ensure you're requesting the correct granular permission
   - Check if `READ_MEDIA_IMAGES` is declared in AndroidManifest.xml

2. **File access denied despite permission**
   - Verify you're using scoped storage correctly
   - Check if file path is accessible in scoped storage

3. **Permission dialog not showing**
   - Ensure context is from an active Activity
   - Check if permission was already permanently denied

### Debug Commands
```dart
// Force refresh all permissions
final notifier = ref.read(permissionRefreshProvider.notifier);
notifier.refreshPermissions();

// Clear permission cache
PermissionManager.instance.clearCache();
```

## Contributing

When adding new permissions:
1. Add permission rationale to `PermissionConfig`
2. Update `PermissionUtils.getAllRequiredPermissions()`
3. Add ProGuard rules if needed
4. Update this documentation
5. Add tests for the new permission flow

## References

- [Android Permissions Overview](https://developer.android.com/guide/topics/permissions/overview)
- [Granular Media Permissions](https://developer.android.com/about/versions/13/behavior-changes-13#granular-media-permissions)
- [Scoped Storage](https://developer.android.com/training/data-storage/shared/scoped-directory-access)
- [Flutter Permission Handler](https://pub.dev/packages/permission_handler)