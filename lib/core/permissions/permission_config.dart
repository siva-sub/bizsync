/// Configuration and constants for permission handling
class PermissionConfig {
  static const String appName = 'BizSync';
  
  /// Permission request rationale messages
  static const Map<String, Map<String, String>> permissionRationales = {
    'storage': {
      'title': 'Storage Access Required',
      'description': 'BizSync needs storage access to save your business documents, invoices, and create backups. This ensures your important business data is preserved and accessible when you need it.',
      'businessReason': 'Essential for managing business documents and data backup.',
    },
    'photos': {
      'title': 'Photo Access Required', 
      'description': 'BizSync needs access to photos to set profile pictures and attach images to your business documents and invoices. We only access photos you specifically choose.',
      'businessReason': 'Required for profile pictures and document attachments.',
    },
    'camera': {
      'title': 'Camera Access Required',
      'description': 'BizSync needs camera access to scan QR codes for payments, capture receipts and documents, and take photos for your business records. The camera is only used when you actively choose to scan or take a photo.',
      'businessReason': 'Enables QR code scanning and document capture.',
    },
    'notifications': {
      'title': 'Notification Permission Required',
      'description': 'BizSync needs notification permission to remind you about important business tasks, payment due dates, tax deadlines, and backup schedules. These notifications help keep your business running smoothly.',
      'businessReason': 'Critical for business reminders and alerts.',
    },
    'location': {
      'title': 'Location Access Required',
      'description': 'BizSync uses your location to automatically fill in business addresses, provide location-based business insights, and help track business expenses by location. Your location data is never shared with third parties.',
      'businessReason': 'Helpful for address autofill and expense tracking.',
    },
    'manageStorage': {
      'title': 'File Management Permission Required',
      'description': 'BizSync needs advanced file management permission to organize your business documents, create structured backup files, and provide comprehensive file export options. This permission helps maintain an organized business document system.',
      'businessReason': 'Enables advanced file organization and backup features.',
    },
  };

  /// Android version specific explanations
  static const Map<String, Map<String, String>> androidVersionExplanations = {
    'android13Plus': {
      'title': 'Android 13+ Privacy Enhancement',
      'description': 'Android 13 and above uses granular media permissions for better privacy. BizSync will only request access to specific file types needed for business operations.',
    },
    'android10Plus': {
      'title': 'Scoped Storage Information', 
      'description': 'Android 10+ uses scoped storage to protect your privacy. BizSync will primarily use its own secure storage area, with access to shared storage only when you explicitly choose files.',
    },
  };

  /// Business specific rationales
  static const Map<String, Map<String, String>> businessRationales = {
    'backup': {
      'title': 'Business Data Backup',
      'description': 'Regular backups protect your valuable business data. Storage permission ensures your invoices, customer information, and financial records are safely preserved.',
    },
    'documents': {
      'title': 'Document Management',
      'description': 'Effective document management is crucial for business success. Storage access allows BizSync to help you organize, search, and retrieve business documents efficiently.',
    },
    'compliance': {
      'title': 'Business Compliance',
      'description': 'Many businesses are required to maintain digital records for compliance purposes. Storage access ensures you can maintain proper business documentation and audit trails.',
    },
  };

  /// Privacy and security assurances
  static const Map<String, String> privacyAssurances = {
    'privacy': 'BizSync only accesses files you explicitly choose or create. We never browse or access your personal files without permission. All business data remains private and secure on your device.',
    'security': 'Your business data is encrypted and stored securely on your device. BizSync uses industry-standard security practices to protect your sensitive business information.',
    'offline': 'BizSync works entirely offline, ensuring your business data never leaves your device unless you explicitly choose to export or share it. Your data, your control.',
  };

  /// Permission categories and priorities
  static const Map<String, List<String>> permissionCategories = {
    'essential': ['notifications', 'photos'], // Must have for core functionality
    'enhanced': ['camera', 'storage'], // Greatly improves functionality  
    'optional': ['location', 'manageStorage'], // Nice to have features
  };

  /// File type specific rationales
  static const Map<String, Map<String, String>> fileTypeRationales = {
    'images': {
      'title': 'Business Images',
      'description': 'Access to images allows you to attach receipts, product photos, and business documents to your records, creating comprehensive business documentation.',
    },
    'documents': {
      'title': 'Business Documents', 
      'description': 'Access to documents enables import and export of invoices, contracts, and other business files, ensuring seamless integration with your existing business workflow.',
    },
    'audio': {
      'title': 'Voice Records',
      'description': 'Audio access enables voice memos for business meetings, recorded instructions, and audio notes for comprehensive business documentation.',
    },
    'video': {
      'title': 'Business Videos',
      'description': 'Video access allows for training materials, product demonstrations, and video documentation of business processes.',
    },
  };

  /// Get rationale for specific permission
  static Map<String, String>? getRationaleForPermission(String permissionKey) {
    return permissionRationales[permissionKey];
  }

  /// Get business rationale for specific feature
  static Map<String, String>? getBusinessRationale(String feature) {
    return businessRationales[feature];
  }

  /// Get privacy assurance text
  static String getPrivacyAssurance(String type) {
    return privacyAssurances[type] ?? '';
  }

  /// Check if permission is essential
  static bool isEssentialPermission(String permissionKey) {
    return permissionCategories['essential']?.contains(permissionKey) ?? false;
  }

  /// Check if permission is enhanced
  static bool isEnhancedPermission(String permissionKey) {
    return permissionCategories['enhanced']?.contains(permissionKey) ?? false;
  }

  /// Check if permission is optional
  static bool isOptionalPermission(String permissionKey) {
    return permissionCategories['optional']?.contains(permissionKey) ?? false;
  }

  /// Get permission priority (lower number = higher priority)
  static int getPermissionPriority(String permissionKey) {
    if (isEssentialPermission(permissionKey)) return 1;
    if (isEnhancedPermission(permissionKey)) return 2;
    if (isOptionalPermission(permissionKey)) return 3;
    return 4; // Unknown permissions have lowest priority
  }

  /// Get sorted permissions by priority
  static List<String> getSortedPermissions(List<String> permissions) {
    final sortedList = List<String>.from(permissions);
    sortedList.sort((a, b) => getPermissionPriority(a).compareTo(getPermissionPriority(b)));
    return sortedList;
  }

  /// Get permission category name
  static String getPermissionCategory(String permissionKey) {
    if (isEssentialPermission(permissionKey)) return 'Essential';
    if (isEnhancedPermission(permissionKey)) return 'Enhanced';
    if (isOptionalPermission(permissionKey)) return 'Optional';
    return 'Unknown';
  }

  /// Permission request flow configuration
  static const Map<String, dynamic> requestFlowConfig = {
    'showRationaleByDefault': true,
    'maxRetryAttempts': 2,
    'delayBetweenRetries': 1000, // milliseconds
    'showSuccessMessages': true,
    'showErrorMessages': true,
    'autoNavigateToSettings': true,
  };

  /// Debug configuration
  static const Map<String, dynamic> debugConfig = {
    'enablePermissionLogging': true,
    'logPermissionChanges': true,
    'showPermissionDebugInfo': false, // Set to true for development
  };
}

/// Permission request configuration for specific flows
class PermissionRequestConfig {
  final String title;
  final String description;
  final String businessReason;
  final bool isRequired;
  final bool showRationale;
  final int maxRetries;
  final Duration retryDelay;

  const PermissionRequestConfig({
    required this.title,
    required this.description,
    required this.businessReason,
    this.isRequired = false,
    this.showRationale = true,
    this.maxRetries = 2,
    this.retryDelay = const Duration(seconds: 1),
  });

  factory PermissionRequestConfig.fromPermissionKey(String permissionKey) {
    final rationale = PermissionConfig.getRationaleForPermission(permissionKey);
    final isRequired = PermissionConfig.isEssentialPermission(permissionKey);
    
    return PermissionRequestConfig(
      title: rationale?['title'] ?? 'Permission Required',
      description: rationale?['description'] ?? 'This permission is needed for app functionality.',
      businessReason: rationale?['businessReason'] ?? 'Required for app features.',
      isRequired: isRequired,
    );
  }
}

/// Permission UI configuration
class PermissionUIConfig {
  static const Map<String, Map<String, dynamic>> uiSettings = {
    'colors': {
      'essential': 0xFF1976D2, // Blue
      'enhanced': 0xFF388E3C,  // Green
      'optional': 0xFF8BC34A,  // Light Green
      'denied': 0xFFF57C00,    // Orange
      'error': 0xFFD32F2F,     // Red
    },
    'icons': {
      'storage': 0xe2c8, // Icons.folder_outlined
      'photos': 0xe3ad,  // Icons.photo_library_outlined  
      'camera': 0xe3b0,  // Icons.camera_alt_outlined
      'notifications': 0xe7f4, // Icons.notifications_outlined
      'location': 0xe55f, // Icons.location_on_outlined
      'manageStorage': 0xe2c7, // Icons.folder_open_outlined
    },
    'animations': {
      'duration': 300,
      'curve': 'easeInOut',
    },
  };

  static int getColorForPermission(String permissionKey) {
    if (PermissionConfig.isEssentialPermission(permissionKey)) {
      return uiSettings['colors']!['essential'] as int;
    } else if (PermissionConfig.isEnhancedPermission(permissionKey)) {
      return uiSettings['colors']!['enhanced'] as int;
    } else {
      return uiSettings['colors']!['optional'] as int;
    }
  }

  static int getIconForPermission(String permissionKey) {
    return uiSettings['icons']![permissionKey] as int? ?? 0xe8b9; // Icons.help_outline
  }
}