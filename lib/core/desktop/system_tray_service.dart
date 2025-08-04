import 'dart:io';
import 'package:flutter/foundation.dart';
// import 'package:system_tray/system_tray.dart'; // Commented due to dependency conflicts
import 'package:window_manager/window_manager.dart';
import 'package:path/path.dart' as path;

/// System Tray Integration Service for Linux Desktop
/// 
/// Provides system tray functionality with quick actions:
/// - Minimize to tray option
/// - Quick access to key features
/// - System notifications
/// - Window management
// Stub implementation due to system_tray package conflicts
class SystemTrayService {
  static final SystemTrayService _instance = SystemTrayService._internal();
  factory SystemTrayService() => _instance;
  SystemTrayService._internal();

  // final SystemTray _systemTray = SystemTray(); // Disabled due to dependency
  bool _isInitialized = false;
  bool _minimizeToTray = false;

  /// Initialize the system tray with menu items
  Future<void> initialize() async {
    if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) {
      debugPrint('System tray not supported on this platform');
      return;
    }

    try {
      // Initialize the system tray
      await _systemTray.initSystemTray(
        title: "BizSync",
        iconPath: _getTrayIconPath(),
        toolTip: "BizSync - Business Management",
      );

      // Set up the tray menu
      await _setupTrayMenu();

      _isInitialized = true;
      debugPrint('✅ System tray initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize system tray: $e');
    }
  }

  /// Get the appropriate tray icon path for the platform
  String _getTrayIconPath() {
    if (Platform.isLinux) {
      // For Linux, use a simple icon path
      return path.join(Directory.current.path, 'assets', 'icon', 'app_icon.png');
    } else if (Platform.isWindows) {
      return path.join(Directory.current.path, 'assets', 'icon', 'app_icon.ico');
    } else if (Platform.isMacOS) {
      return path.join(Directory.current.path, 'assets', 'icon', 'app_icon.png');
    }
    return '';
  }

  /// Set up the system tray context menu
  Future<void> _setupTrayMenu() async {
    final Menu menu = Menu();

    // Quick Actions Section
    await menu.buildFrom([
      MenuItemLabel(
        label: 'BizSync - Business Management',
        enabled: false,
      ),
      MenuSeparator(),
      
      // Main Actions
      MenuItemLabel(
        label: '📊 Dashboard',
        onClicked: (menuItem) => _handleMenuAction('dashboard'),
      ),
      MenuItemLabel(
        label: '📄 New Invoice',
        onClicked: (menuItem) => _handleMenuAction('new_invoice'),
      ),
      MenuItemLabel(
        label: '👥 Customers',
        onClicked: (menuItem) => _handleMenuAction('customers'),
      ),
      MenuItemLabel(
        label: '📦 Inventory',
        onClicked: (menuItem) => _handleMenuAction('inventory'),
      ),
      MenuItemLabel(
        label: '📈 Reports',
        onClicked: (menuItem) => _handleMenuAction('reports'),
      ),
      
      MenuSeparator(),
      
      // Window Management
      MenuItemLabel(
        label: '🔍 Search (Ctrl+F)',
        onClicked: (menuItem) => _handleMenuAction('search'),
      ),
      MenuItemLabel(
        label: '⚙️ Settings',
        onClicked: (menuItem) => _handleMenuAction('settings'),
      ),
      
      MenuSeparator(),
      
      // Application Control
      MenuItemCheckbox(
        label: 'Minimize to Tray',
        checked: _minimizeToTray,
        onClicked: (menuItem) => _toggleMinimizeToTray(),
      ),
      MenuItemLabel(
        label: _isWindowVisible() ? '🗗 Hide Window' : '🗖 Show Window',
        onClicked: (menuItem) => _toggleWindowVisibility(),
      ),
      
      MenuSeparator(),
      
      MenuItemLabel(
        label: '❌ Exit BizSync',
        onClicked: (menuItem) => _handleMenuAction('exit'),
      ),
    ]);

    await _systemTray.setContextMenu(menu);
  }

  /// Handle menu action clicks
  void _handleMenuAction(String action) {
    debugPrint('System tray action: $action');
    
    switch (action) {
      case 'dashboard':
        _showWindowAndNavigate('/dashboard');
        break;
      case 'new_invoice':
        _showWindowAndNavigate('/invoices/new');
        break;
      case 'customers':
        _showWindowAndNavigate('/customers');
        break;
      case 'inventory':
        _showWindowAndNavigate('/inventory');
        break;
      case 'reports':
        _showWindowAndNavigate('/reports');
        break;
      case 'search':
        _showWindowAndTriggerSearch();
        break;
      case 'settings':
        _showWindowAndNavigate('/settings');
        break;
      case 'exit':
        _exitApplication();
        break;
    }
  }

  /// Show window and navigate to specific route
  void _showWindowAndNavigate(String route) async {
    await windowManager.show();
    await windowManager.focus();
    
    // Navigate to route - this would be handled by the app's navigation service
    // For now, just ensure window is visible
    debugPrint('Navigate to: $route');
  }

  /// Show window and trigger global search
  void _showWindowAndTriggerSearch() async {
    await windowManager.show();
    await windowManager.focus();
    
    // Trigger search functionality
    debugPrint('Trigger search functionality');
  }

  /// Toggle window visibility
  void _toggleWindowVisibility() async {
    if (await windowManager.isVisible()) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
    
    // Update menu to reflect current state
    await _setupTrayMenu();
  }

  /// Check if window is currently visible
  bool _isWindowVisible() {
    // This is a simplified check - in a real implementation,
    // you'd want to track window state more accurately
    return true; // Placeholder
  }

  /// Toggle minimize to tray setting
  void _toggleMinimizeToTray() {
    _minimizeToTray = !_minimizeToTray;
    debugPrint('Minimize to tray: $_minimizeToTray');
    
    // Save preference
    _saveMinimizeToTrayPreference(_minimizeToTray);
    
    // Update menu
    _setupTrayMenu();
  }

  /// Save minimize to tray preference
  void _saveMinimizeToTrayPreference(bool enabled) {
    // Save to shared preferences or local storage
    debugPrint('Saving minimize to tray preference: $enabled');
  }

  /// Handle window close event (minimize to tray if enabled)
  Future<bool> handleWindowClose() async {
    if (_minimizeToTray) {
      await windowManager.hide();
      return false; // Prevent actual window close
    }
    return true; // Allow window close
  }

  /// Exit the application completely
  void _exitApplication() async {
    debugPrint('Exiting BizSync application');
    await _systemTray.destroy();
    exit(0);
  }

  /// Show system tray notification
  void showNotification({
    required String title,
    required String message,
    String? iconPath,
  }) async {
    if (!_isInitialized) return;

    try {
      // Use system tray to show notification
      // Note: system_tray package may not have direct notification support
      // You might need to use flutter_local_notifications_linux instead
      debugPrint('Showing tray notification: $title - $message');
    } catch (e) {
      debugPrint('Failed to show tray notification: $e');
    }
  }

  /// Update tray icon dynamically (e.g., for status indication)
  void updateTrayIcon({String? iconPath, String? toolTip}) async {
    if (!_isInitialized) return;

    try {
      if (iconPath != null) {
        await _systemTray.setImage(iconPath);
      }
      if (toolTip != null) {
        await _systemTray.setToolTip(toolTip);
      }
    } catch (e) {
      debugPrint('Failed to update tray icon: $e');
    }
  }

  /// Clean up system tray resources
  Future<void> dispose() async {
    if (_isInitialized) {
      await _systemTray.destroy();
      _isInitialized = false;
      debugPrint('System tray disposed');
    }
  }

  /// Get current minimize to tray setting
  bool get minimizeToTray => _minimizeToTray;

  /// Set minimize to tray setting
  set minimizeToTray(bool value) {
    _minimizeToTray = value;
    _saveMinimizeToTrayPreference(value);
    _setupTrayMenu();
  }
}