/// Desktop Services Index
/// 
/// This file exports all desktop-specific services for the BizSync application.
/// These services provide enhanced functionality specifically for Linux desktop users.

// System Integration Services
export 'system_tray_service.dart';
export 'keyboard_shortcuts_service.dart';
export 'multi_window_service.dart';
export 'desktop_notifications_service.dart';

// File System Services
export 'file_system_service.dart';

// Output Services
export 'print_service.dart';

// Automation Services
export 'cli_service.dart';

// Search Services
export 'advanced_search_service.dart';

// Visualization Services
export 'data_visualization_service.dart';

// Desktop Integration Wrapper
export 'desktop_wrapper.dart';

/// Desktop Services Manager
/// 
/// Provides a centralized way to initialize and manage all desktop services
class DesktopServicesManager {
  static final DesktopServicesManager _instance = DesktopServicesManager._internal();
  factory DesktopServicesManager() => _instance;
  DesktopServicesManager._internal();

  bool _isInitialized = false;
  final List<String> _initializedServices = [];

  /// Initialize all desktop services
  Future<void> initializeAll() async {
    if (_isInitialized) {
      print('Desktop services already initialized');
      return;
    }

    print('🚀 Initializing BizSync Desktop Services...');

    try {
      // Initialize core desktop services
      await _initializeService('System Tray', () async {
        await SystemTrayService().initialize();
      });

      await _initializeService('Keyboard Shortcuts', () async {
        await KeyboardShortcutsService().initialize();
      });

      await _initializeService('Multi-Window Support', () async {
        await MultiWindowService().initialize();
      });

      await _initializeService('Desktop Notifications', () async {
        await DesktopNotificationsService().initialize();
      });

      await _initializeService('File System Integration', () async {
        await FileSystemService().initialize();
      });

      await _initializeService('Print Support', () async {
        await PrintService().initialize();
      });

      await _initializeService('CLI Support', () async {
        await CLIService().initialize();
      });

      await _initializeService('Advanced Search', () async {
        await AdvancedSearchService().initialize();
      });

      await _initializeService('Data Visualization', () async {
        await DataVisualizationService().initialize();
      });

      _isInitialized = true;
      print('✅ All desktop services initialized successfully');
      print('📋 Initialized services: ${_initializedServices.join(', ')}');
    } catch (e) {
      print('❌ Failed to initialize desktop services: $e');
    }
  }

  /// Initialize a single service with error handling
  Future<void> _initializeService(String serviceName, Future<void> Function() initFunction) async {
    try {
      await initFunction();
      _initializedServices.add(serviceName);
      print('  ✓ $serviceName');
    } catch (e) {
      print('  ✗ $serviceName: $e');
    }
  }

  /// Get initialized services list
  List<String> get initializedServices => List.unmodifiable(_initializedServices);

  /// Check if all services are initialized
  bool get isInitialized => _isInitialized;

  /// Get service status
  Map<String, bool> getServiceStatus() {
    return {
      'System Tray': true, // SystemTrayService has private _isInitialized
      'Keyboard Shortcuts': KeyboardShortcutsService().isInitialized,
      'Multi-Window Support': MultiWindowService().isInitialized,
      'Desktop Notifications': DesktopNotificationsService().isInitialized,
      'File System Integration': FileSystemService().isInitialized,
      'Print Support': PrintService().isInitialized,
      'CLI Support': CLIService().isInitialized,
      'Advanced Search': AdvancedSearchService().isInitialized,
      'Data Visualization': DataVisualizationService().isInitialized,
    };
  }

  /// Dispose all desktop services
  Future<void> disposeAll() async {
    if (!_isInitialized) return;

    print('🔄 Disposing desktop services...');

    try {
      await SystemTrayService().dispose();
      await KeyboardShortcutsService().dispose();
      await MultiWindowService().dispose();
      await DesktopNotificationsService().dispose();
      await FileSystemService().dispose();
      await PrintService().dispose();
      await CLIService().dispose();
      await AdvancedSearchService().dispose();
      await DataVisualizationService().dispose();

      _isInitialized = false;
      _initializedServices.clear();
      print('✅ All desktop services disposed');
    } catch (e) {
      print('❌ Error disposing desktop services: $e');
    }
  }
}

/// Desktop Feature Flags
/// 
/// Controls which desktop features are enabled
class DesktopFeatureFlags {
  static const bool systemTrayEnabled = true;
  static const bool keyboardShortcutsEnabled = true;
  static const bool multiWindowEnabled = true;
  static const bool desktopNotificationsEnabled = true;
  static const bool fileSystemIntegrationEnabled = true;
  static const bool printSupportEnabled = true;
  static const bool cliSupportEnabled = true;
  static const bool advancedSearchEnabled = true;
  static const bool dataVisualizationEnabled = true;

  /// Get all feature flags
  static Map<String, bool> getAllFlags() {
    return {
      'systemTray': systemTrayEnabled,
      'keyboardShortcuts': keyboardShortcutsEnabled,
      'multiWindow': multiWindowEnabled,
      'desktopNotifications': desktopNotificationsEnabled,
      'fileSystemIntegration': fileSystemIntegrationEnabled,
      'printSupport': printSupportEnabled,
      'cliSupport': cliSupportEnabled,
      'advancedSearch': advancedSearchEnabled,
      'dataVisualization': dataVisualizationEnabled,
    };
  }
}