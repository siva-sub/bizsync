import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Global Keyboard Shortcuts Service for Linux Desktop
///
/// Provides system-wide keyboard shortcuts for:
/// - Quick actions (Ctrl+N for new invoice, etc.)
/// - Navigation shortcuts (Ctrl+Tab to switch tabs)
/// - Search shortcut (Ctrl+F)
/// - Help shortcuts (F1)
/// - Window management shortcuts
class KeyboardShortcutsService {
  static final KeyboardShortcutsService _instance =
      KeyboardShortcutsService._internal();
  factory KeyboardShortcutsService() => _instance;
  KeyboardShortcutsService._internal();

  bool _isInitialized = false;
  final Map<String, HotKey> _registeredHotkeys = {};
  final Map<String, VoidCallback> _shortcutCallbacks = {};

  /// Initialize global keyboard shortcuts
  Future<void> initialize() async {
    if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) {
      debugPrint('Keyboard shortcuts not supported on this platform');
      return;
    }

    try {
      // Initialize hotkey manager
      await hotKeyManager.unregisterAll();

      // Register all shortcuts
      await _registerGlobalShortcuts();

      _isInitialized = true;
      debugPrint('✅ Global keyboard shortcuts initialized successfully');
      _printRegisteredShortcuts();
    } catch (e) {
      debugPrint('❌ Failed to initialize keyboard shortcuts: $e');
    }
  }

  /// Register all global keyboard shortcuts
  Future<void> _registerGlobalShortcuts() async {
    // Business Action Shortcuts
    await _registerShortcut(
      'new_invoice',
      HotKey(
        key: LogicalKeyboardKey.keyN,
        modifiers: [HotKeyModifier.control],
        scope: HotKeyScope.system,
      ),
      () => _handleShortcut('new_invoice'),
      'Create New Invoice',
    );

    await _registerShortcut(
      'new_customer',
      HotKey(
        key: LogicalKeyboardKey.keyU,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      ),
      () => _handleShortcut('new_customer'),
      'Create New Customer',
    );

    await _registerShortcut(
      'new_product',
      HotKey(
        key: LogicalKeyboardKey.keyP,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      ),
      () => _handleShortcut('new_product'),
      'Create New Product',
    );

    // Navigation Shortcuts
    await _registerShortcut(
      'dashboard',
      HotKey(
        key: LogicalKeyboardKey.keyD,
        modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
        scope: HotKeyScope.system,
      ),
      () => _handleShortcut('dashboard'),
      'Open Dashboard',
    );

    await _registerShortcut(
      'invoices',
      HotKey(
        key: LogicalKeyboardKey.keyI,
        modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
        scope: HotKeyScope.system,
      ),
      () => _handleShortcut('invoices'),
      'Open Invoices',
    );

    await _registerShortcut(
      'customers',
      HotKey(
        key: LogicalKeyboardKey.keyC,
        modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
        scope: HotKeyScope.system,
      ),
      () => _handleShortcut('customers'),
      'Open Customers',
    );

    await _registerShortcut(
      'inventory',
      HotKey(
        key: LogicalKeyboardKey.keyV,
        modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
        scope: HotKeyScope.system,
      ),
      () => _handleShortcut('inventory'),
      'Open Inventory',
    );

    await _registerShortcut(
      'reports',
      HotKey(
        key: LogicalKeyboardKey.keyR,
        modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
        scope: HotKeyScope.system,
      ),
      () => _handleShortcut('reports'),
      'Open Reports',
    );

    // Search and Help Shortcuts
    await _registerShortcut(
      'global_search',
      HotKey(
        key: LogicalKeyboardKey.keyF,
        modifiers: [HotKeyModifier.control],
        scope: HotKeyScope.system,
      ),
      () => _handleShortcut('global_search'),
      'Global Search',
    );

    await _registerShortcut(
      'help',
      HotKey(
        key: LogicalKeyboardKey.f1,
        modifiers: [],
        scope: HotKeyScope.system,
      ),
      () => _handleShortcut('help'),
      'Show Help',
    );

    // Window Management Shortcuts
    await _registerShortcut(
      'minimize_window',
      HotKey(
        key: LogicalKeyboardKey.keyM,
        modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
        scope: HotKeyScope.system,
      ),
      () => _handleShortcut('minimize_window'),
      'Minimize Window',
    );

    await _registerShortcut(
      'toggle_fullscreen',
      HotKey(
        key: LogicalKeyboardKey.f11,
        modifiers: [],
        scope: HotKeyScope.system,
      ),
      () => _handleShortcut('toggle_fullscreen'),
      'Toggle Fullscreen',
    );

    await _registerShortcut(
      'show_hide_window',
      HotKey(
        key: LogicalKeyboardKey.keyH,
        modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
        scope: HotKeyScope.system,
      ),
      () => _handleShortcut('show_hide_window'),
      'Show/Hide Window',
    );

    // Quick Settings
    await _registerShortcut(
      'settings',
      HotKey(
        key: LogicalKeyboardKey.comma,
        modifiers: [HotKeyModifier.control],
        scope: HotKeyScope.system,
      ),
      () => _handleShortcut('settings'),
      'Open Settings',
    );

    // Export/Import Shortcuts
    await _registerShortcut(
      'export_data',
      HotKey(
        key: LogicalKeyboardKey.keyE,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      ),
      () => _handleShortcut('export_data'),
      'Export Data',
    );

    await _registerShortcut(
      'import_data',
      HotKey(
        key: LogicalKeyboardKey.keyI,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      ),
      () => _handleShortcut('import_data'),
      'Import Data',
    );

    // Quick Actions
    await _registerShortcut(
      'quick_calculator',
      HotKey(
        key: LogicalKeyboardKey.keyQ,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      ),
      () => _handleShortcut('quick_calculator'),
      'Quick Calculator',
    );
  }

  /// Register a single keyboard shortcut
  Future<void> _registerShortcut(
    String id,
    HotKey hotKey,
    VoidCallback callback,
    String description,
  ) async {
    try {
      await hotKeyManager.register(
        hotKey,
        keyDownHandler: (hotKey) {
          debugPrint('Hotkey triggered: $id ($description)');
          callback();
        },
      );

      _registeredHotkeys[id] = hotKey;
      _shortcutCallbacks[id] = callback;
    } catch (e) {
      debugPrint('Failed to register shortcut $id: $e');
    }
  }

  /// Handle shortcut actions
  Future<void> _handleShortcut(String action) async {
    debugPrint('Keyboard shortcut triggered: $action');

    // Ensure window is visible and focused for all actions
    await _ensureWindowVisible();

    switch (action) {
      case 'new_invoice':
        _navigateToRoute('/invoices/new');
        break;
      case 'new_customer':
        _navigateToRoute('/customers/new');
        break;
      case 'new_product':
        _navigateToRoute('/inventory/new');
        break;
      case 'dashboard':
        _navigateToRoute('/dashboard');
        break;
      case 'invoices':
        _navigateToRoute('/invoices');
        break;
      case 'customers':
        _navigateToRoute('/customers');
        break;
      case 'inventory':
        _navigateToRoute('/inventory');
        break;
      case 'reports':
        _navigateToRoute('/reports');
        break;
      case 'global_search':
        _triggerGlobalSearch();
        break;
      case 'help':
        _showHelp();
        break;
      case 'minimize_window':
        await windowManager.minimize();
        break;
      case 'toggle_fullscreen':
        await _toggleFullscreen();
        break;
      case 'show_hide_window':
        await _toggleWindowVisibility();
        break;
      case 'settings':
        _navigateToRoute('/settings');
        break;
      case 'export_data':
        _triggerExport();
        break;
      case 'import_data':
        _triggerImport();
        break;
      case 'quick_calculator':
        _showQuickCalculator();
        break;
    }
  }

  /// Ensure window is visible and focused
  Future<void> _ensureWindowVisible() async {
    try {
      if (!await windowManager.isVisible()) {
        await windowManager.show();
      }
      await windowManager.focus();
    } catch (e) {
      debugPrint('Failed to show/focus window: $e');
    }
  }

  /// Navigate to a specific route
  void _navigateToRoute(String route) {
    debugPrint('Navigate to: $route');
    // This would be handled by the app's navigation service
    // For now, we'll just ensure the window is visible
  }

  /// Trigger global search functionality
  void _triggerGlobalSearch() {
    debugPrint('Triggering global search');
    // This would trigger the global search overlay or dialog
  }

  /// Show help dialog or navigate to help
  void _showHelp() {
    debugPrint('Showing help');
    _navigateToRoute('/help');
  }

  /// Toggle fullscreen mode
  Future<void> _toggleFullscreen() async {
    try {
      if (await windowManager.isFullScreen()) {
        await windowManager.setFullScreen(false);
      } else {
        await windowManager.setFullScreen(true);
      }
    } catch (e) {
      debugPrint('Failed to toggle fullscreen: $e');
    }
  }

  /// Toggle window visibility
  Future<void> _toggleWindowVisibility() async {
    try {
      if (await windowManager.isVisible()) {
        await windowManager.hide();
      } else {
        await windowManager.show();
        await windowManager.focus();
      }
    } catch (e) {
      debugPrint('Failed to toggle window visibility: $e');
    }
  }

  /// Trigger data export
  void _triggerExport() {
    debugPrint('Triggering data export');
    // This would open export dialog or start export process
  }

  /// Trigger data import
  void _triggerImport() {
    debugPrint('Triggering data import');
    // This would open file picker for import
  }

  /// Show quick calculator overlay
  void _showQuickCalculator() {
    debugPrint('Showing quick calculator');
    // This would show a floating calculator widget
  }

  /// Print all registered shortcuts for debugging
  void _printRegisteredShortcuts() {
    if (kDebugMode) {
      debugPrint('\n📋 Registered Keyboard Shortcuts:');
      debugPrint('═══════════════════════════════════');
      debugPrint('Business Actions:');
      debugPrint('  Ctrl+N                 → New Invoice');
      debugPrint('  Ctrl+Shift+U          → New Customer');
      debugPrint('  Ctrl+Shift+P          → New Product');
      debugPrint('\nNavigation:');
      debugPrint('  Ctrl+Alt+D            → Dashboard');
      debugPrint('  Ctrl+Alt+I            → Invoices');
      debugPrint('  Ctrl+Alt+C            → Customers');
      debugPrint('  Ctrl+Alt+V            → Inventory');
      debugPrint('  Ctrl+Alt+R            → Reports');
      debugPrint('\nSearch & Help:');
      debugPrint('  Ctrl+F                → Global Search');
      debugPrint('  F1                    → Help');
      debugPrint('\nWindow Management:');
      debugPrint('  Ctrl+Alt+M            → Minimize Window');
      debugPrint('  F11                   → Toggle Fullscreen');
      debugPrint('  Ctrl+Alt+H            → Show/Hide Window');
      debugPrint('\nOther:');
      debugPrint('  Ctrl+,                → Settings');
      debugPrint('  Ctrl+Shift+E          → Export Data');
      debugPrint('  Ctrl+Shift+I          → Import Data');
      debugPrint('  Ctrl+Shift+Q          → Quick Calculator');
      debugPrint('═══════════════════════════════════\n');
    }
  }

  /// Register a custom shortcut
  Future<bool> registerCustomShortcut({
    required String id,
    required HotKey hotKey,
    required VoidCallback callback,
    String? description,
  }) async {
    if (_registeredHotkeys.containsKey(id)) {
      debugPrint('Shortcut $id already registered');
      return false;
    }

    try {
      await hotKeyManager.register(
        hotKey,
        keyDownHandler: (hotKey) {
          debugPrint('Custom hotkey triggered: $id');
          callback();
        },
      );

      _registeredHotkeys[id] = hotKey;
      _shortcutCallbacks[id] = callback;

      debugPrint('Custom shortcut registered: $id ${description ?? ''}');
      return true;
    } catch (e) {
      debugPrint('Failed to register custom shortcut $id: $e');
      return false;
    }
  }

  /// Unregister a specific shortcut
  Future<bool> unregisterShortcut(String id) async {
    final hotKey = _registeredHotkeys[id];
    if (hotKey == null) {
      debugPrint('Shortcut $id not found');
      return false;
    }

    try {
      await hotKeyManager.unregister(hotKey);
      _registeredHotkeys.remove(id);
      _shortcutCallbacks.remove(id);

      debugPrint('Shortcut unregistered: $id');
      return true;
    } catch (e) {
      debugPrint('Failed to unregister shortcut $id: $e');
      return false;
    }
  }

  /// Get all registered shortcuts
  Map<String, HotKey> get registeredShortcuts =>
      Map.unmodifiable(_registeredHotkeys);

  /// Check if shortcuts are initialized
  bool get isInitialized => _isInitialized;

  /// Clean up all keyboard shortcuts
  Future<void> dispose() async {
    try {
      await hotKeyManager.unregisterAll();
      _registeredHotkeys.clear();
      _shortcutCallbacks.clear();
      _isInitialized = false;
      debugPrint('Keyboard shortcuts disposed');
    } catch (e) {
      debugPrint('Failed to dispose keyboard shortcuts: $e');
    }
  }
}
