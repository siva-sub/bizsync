import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Window Configuration Model
class WindowConfig {
  final String id;
  final String title;
  final Size size;
  final Offset position;
  final bool isMaximized;
  final bool isMinimized;
  final String route;
  final Map<String, dynamic> params;

  WindowConfig({
    required this.id,
    required this.title,
    required this.size,
    required this.position,
    this.isMaximized = false,
    this.isMinimized = false,
    required this.route,
    this.params = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'width': size.width,
        'height': size.height,
        'x': position.dx,
        'y': position.dy,
        'isMaximized': isMaximized,
        'isMinimized': isMinimized,
        'route': route,
        'params': params,
      };

  factory WindowConfig.fromJson(Map<String, dynamic> json) => WindowConfig(
        id: json['id'],
        title: json['title'],
        size: Size(json['width']?.toDouble() ?? 800.0,
            json['height']?.toDouble() ?? 600.0),
        position: Offset(
            json['x']?.toDouble() ?? 100.0, json['y']?.toDouble() ?? 100.0),
        isMaximized: json['isMaximized'] ?? false,
        isMinimized: json['isMinimized'] ?? false,
        route: json['route'],
        params: json['params'] ?? {},
      );
}

/// Multi-Window Support Service for Linux Desktop
///
/// Provides multi-window functionality:
/// - Open invoices in separate windows
/// - Detachable panels
/// - Remember window positions/sizes
/// - Window state management
class MultiWindowService extends ChangeNotifier {
  static final MultiWindowService _instance = MultiWindowService._internal();
  factory MultiWindowService() => _instance;
  MultiWindowService._internal();

  bool _isInitialized = false;
  final Map<String, WindowConfig> _windowConfigs = {};
  final Map<String, GlobalKey<NavigatorState>> _navigatorKeys = {};
  String? _mainWindowId;

  /// Initialize the multi-window service
  Future<void> initialize() async {
    if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) {
      debugPrint('Multi-window support not available on this platform');
      return;
    }

    try {
      // Set up main window
      await _initializeMainWindow();

      // Load saved window configurations
      await _loadWindowConfigurations();

      _isInitialized = true;
      debugPrint('✅ Multi-window service initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize multi-window service: $e');
    }
  }

  /// Initialize the main application window
  Future<void> _initializeMainWindow() async {
    // Ensure window manager is initialized
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 720),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'BizSync - Business Management',
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    // Register main window
    _mainWindowId = 'main';
    _windowConfigs[_mainWindowId!] = WindowConfig(
      id: _mainWindowId!,
      title: 'BizSync - Business Management',
      size: const Size(1280, 720),
      position: const Offset(100, 100),
      route: '/dashboard',
    );

    _navigatorKeys[_mainWindowId!] = GlobalKey<NavigatorState>();
  }

  /// Open a new window with specific content
  Future<String?> openWindow({
    required String title,
    required String route,
    Size size = const Size(800, 600),
    Offset? position,
    Map<String, dynamic> params = const {},
    bool rememberPosition = true,
  }) async {
    if (!_isInitialized) {
      debugPrint('Multi-window service not initialized');
      return null;
    }

    try {
      final windowId = 'window_${DateTime.now().millisecondsSinceEpoch}';

      // Calculate position if not provided
      position ??= _calculateNewWindowPosition();

      // Create window configuration
      final config = WindowConfig(
        id: windowId,
        title: title,
        size: size,
        position: position,
        route: route,
        params: params,
      );

      // Store configuration
      _windowConfigs[windowId] = config;
      _navigatorKeys[windowId] = GlobalKey<NavigatorState>();

      // For now, we'll log the window creation
      // In a full implementation, you'd create an actual new window
      debugPrint('Creating new window: $title at $route');

      if (rememberPosition) {
        await _saveWindowConfigurations();
      }

      notifyListeners();
      return windowId;
    } catch (e) {
      debugPrint('Failed to open new window: $e');
      return null;
    }
  }

  /// Open invoice in separate window
  Future<String?> openInvoiceWindow({
    required String invoiceId,
    required String title,
    bool readOnly = false,
  }) async {
    return await openWindow(
      title: title,
      route: '/invoices/detail',
      size: const Size(900, 700),
      params: {
        'invoiceId': invoiceId,
        'readOnly': readOnly,
      },
    );
  }

  /// Open customer window
  Future<String?> openCustomerWindow({
    required String customerId,
    required String title,
  }) async {
    return await openWindow(
      title: title,
      route: '/customers/detail',
      size: const Size(800, 600),
      params: {
        'customerId': customerId,
      },
    );
  }

  /// Open reports window
  Future<String?> openReportsWindow({
    String reportType = 'sales',
  }) async {
    return await openWindow(
      title: 'BizSync - Reports',
      route: '/reports',
      size: const Size(1000, 800),
      params: {
        'reportType': reportType,
      },
    );
  }

  /// Open calculator window
  Future<String?> openCalculatorWindow() async {
    return await openWindow(
      title: 'BizSync - Calculator',
      route: '/calculator',
      size: const Size(350, 500),
    );
  }

  /// Create detachable panel window
  Future<String?> createDetachablePanel({
    required String panelType,
    required String title,
    Size size = const Size(400, 300),
  }) async {
    String route;
    switch (panelType) {
      case 'customers':
        route = '/panels/customers';
        break;
      case 'inventory':
        route = '/panels/inventory';
        break;
      case 'recent_invoices':
        route = '/panels/recent-invoices';
        break;
      case 'notifications':
        route = '/panels/notifications';
        break;
      default:
        route = '/panels/generic';
    }

    return await openWindow(
      title: title,
      route: route,
      size: size,
      params: {
        'panelType': panelType,
        'detachable': true,
      },
    );
  }

  /// Close a specific window
  Future<void> closeWindow(String windowId) async {
    if (windowId == _mainWindowId) {
      debugPrint('Cannot close main window');
      return;
    }

    try {
      _windowConfigs.remove(windowId);
      _navigatorKeys.remove(windowId);

      await _saveWindowConfigurations();
      notifyListeners();

      debugPrint('Window closed: $windowId');
    } catch (e) {
      debugPrint('Failed to close window $windowId: $e');
    }
  }

  /// Update window position and size
  Future<void> updateWindowGeometry({
    required String windowId,
    Size? size,
    Offset? position,
    bool? isMaximized,
    bool? isMinimized,
  }) async {
    final config = _windowConfigs[windowId];
    if (config == null) return;

    final updatedConfig = WindowConfig(
      id: config.id,
      title: config.title,
      size: size ?? config.size,
      position: position ?? config.position,
      isMaximized: isMaximized ?? config.isMaximized,
      isMinimized: isMinimized ?? config.isMinimized,
      route: config.route,
      params: config.params,
    );

    _windowConfigs[windowId] = updatedConfig;
    await _saveWindowConfigurations();
    notifyListeners();
  }

  /// Calculate position for new window (cascade style)
  Offset _calculateNewWindowPosition() {
    final existingWindows = _windowConfigs.length;
    final offset = existingWindows * 30.0;
    return Offset(100 + offset, 100 + offset);
  }

  /// Get window configuration by ID
  WindowConfig? getWindowConfig(String windowId) {
    return _windowConfigs[windowId];
  }

  /// Get navigator key for window
  GlobalKey<NavigatorState>? getNavigatorKey(String windowId) {
    return _navigatorKeys[windowId];
  }

  /// Get all window configurations
  List<WindowConfig> getAllWindows() {
    return _windowConfigs.values.toList();
  }

  /// Get active windows (not minimized)
  List<WindowConfig> getActiveWindows() {
    return _windowConfigs.values
        .where((config) => !config.isMinimized)
        .toList();
  }

  /// Save window configurations to persistent storage
  Future<void> _saveWindowConfigurations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configsJson =
          _windowConfigs.values.map((config) => config.toJson()).toList();

      await prefs.setString('window_configurations', jsonEncode(configsJson));
      debugPrint('Window configurations saved');
    } catch (e) {
      debugPrint('Failed to save window configurations: $e');
    }
  }

  /// Load window configurations from persistent storage
  Future<void> _loadWindowConfigurations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configsString = prefs.getString('window_configurations');

      if (configsString != null) {
        final configsList = jsonDecode(configsString) as List;

        for (final configJson in configsList) {
          final config = WindowConfig.fromJson(configJson);
          if (config.id != _mainWindowId) {
            _windowConfigs[config.id] = config;
            _navigatorKeys[config.id] = GlobalKey<NavigatorState>();
          }
        }

        debugPrint('Loaded ${configsList.length} window configurations');
      }
    } catch (e) {
      debugPrint('Failed to load window configurations: $e');
    }
  }

  /// Restore window sessions from saved state
  Future<void> restoreWindowSessions() async {
    if (!_isInitialized) return;

    for (final config in _windowConfigs.values) {
      if (config.id != _mainWindowId) {
        // In a full implementation, you'd recreate these windows
        debugPrint('Would restore window: ${config.title} at ${config.route}');
      }
    }
  }

  /// Clear all saved window configurations
  Future<void> clearSavedConfigurations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('window_configurations');
      debugPrint('Window configurations cleared');
    } catch (e) {
      debugPrint('Failed to clear window configurations: $e');
    }
  }

  /// Window state management for main window
  Future<void> setupMainWindowStateTracking() async {
    if (!_isInitialized) return;

    // Set up window event listeners
    windowManager.addListener(_WindowListener(this));
  }

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Get main window ID
  String? get mainWindowId => _mainWindowId;

  /// Get window count
  int get windowCount => _windowConfigs.length;

  /// Dispose of the multi-window service
  Future<void> dispose() async {
    await _saveWindowConfigurations();
    _windowConfigs.clear();
    _navigatorKeys.clear();
    _isInitialized = false;
    debugPrint('Multi-window service disposed');
  }
}

/// Window event listener for tracking window state changes
class _WindowListener extends WindowListener {
  final MultiWindowService _service;

  _WindowListener(this._service);

  @override
  void onWindowResized() {
    _service._saveWindowConfigurations();
  }

  @override
  void onWindowMoved() {
    _service._saveWindowConfigurations();
  }

  @override
  void onWindowMaximized() {
    _service._saveWindowConfigurations();
  }

  @override
  void onWindowUnmaximized() {
    _service._saveWindowConfigurations();
  }

  @override
  void onWindowMinimized() {
    _service._saveWindowConfigurations();
  }

  @override
  void onWindowRestored() {
    _service._saveWindowConfigurations();
  }
}
