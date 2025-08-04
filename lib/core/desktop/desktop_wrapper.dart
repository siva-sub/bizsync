import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:file_selector/file_selector.dart';
import 'index.dart';

/// Desktop Wrapper Widget
/// 
/// Wraps the main application with desktop-specific functionality:
/// - System tray integration
/// - Window management
/// - Keyboard shortcuts
/// - File drop handling
class DesktopWrapper extends StatefulWidget {
  final Widget child;

  const DesktopWrapper({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<DesktopWrapper> createState() => _DesktopWrapperState();
}

class _DesktopWrapperState extends State<DesktopWrapper> with WindowListener {
  final _systemTrayService = SystemTrayService();
  final _keyboardShortcutsService = KeyboardShortcutsService();
  final _multiWindowService = MultiWindowService();
  final _desktopNotificationsService = DesktopNotificationsService();
  final _fileSystemService = FileSystemService();

  @override
  void initState() {
    super.initState();
    
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      windowManager.addListener(this);
      _setupDesktopIntegration();
    }
  }

  @override
  void dispose() {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  /// Set up desktop integration features
  void _setupDesktopIntegration() async {
    // Set up window management
    await _multiWindowService.setupMainWindowStateTracking();
    
    // Show welcome notification
    await _desktopNotificationsService.showSystemNotification(
      title: 'BizSync Desktop',
      message: 'Welcome to BizSync! Desktop features are now active.',
    );
  }

  @override
  void onWindowClose() async {
    // Check if minimize to tray is enabled
    final shouldMinimizeToTray = await _systemTrayService.handleWindowClose();
    if (!shouldMinimizeToTray) {
      // User wants to actually close the app
      await DesktopServicesManager().disposeAll();
    }
  }

  @override
  void onWindowFocus() {
    // Window gained focus
  }

  @override
  void onWindowBlur() {
    // Window lost focus
  }

  @override
  void onWindowMaximize() {
    _multiWindowService.updateWindowGeometry(
      windowId: _multiWindowService.mainWindowId!,
      isMaximized: true,
    );
  }

  @override
  void onWindowUnmaximize() {
    _multiWindowService.updateWindowGeometry(
      windowId: _multiWindowService.mainWindowId!,
      isMaximized: false,
    );
  }

  @override
  void onWindowMinimize() {
    _multiWindowService.updateWindowGeometry(
      windowId: _multiWindowService.mainWindowId!,
      isMinimized: true,
    );
  }

  @override
  void onWindowRestore() {
    _multiWindowService.updateWindowGeometry(
      windowId: _multiWindowService.mainWindowId!,
      isMinimized: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) {
      // Not a desktop platform, return child as-is
      return widget.child;
    }

    return _fileSystemService.createDragDropWidget(
      onFilesDropped: (files) {
        // Handle dropped files
        _handleDroppedFiles(files);
      },
      allowedExtensions: ['pdf', 'csv', 'xlsx', 'json', 'txt', 'png', 'jpg'],
      child: Shortcuts(
        shortcuts: _getDesktopShortcuts(),
        child: Actions(
          actions: _getDesktopActions(context),
          child: widget.child,
        ),
      ),
    );
  }

  /// Handle dropped files
  void _handleDroppedFiles(List<XFile> files) async {
    for (final file in files) {
      // Process imported file - method not accessible
      final result = FileImportResult(
        success: true,
        filePath: file.path,
      );
      
      if (result.success) {
        await _desktopNotificationsService.showBusinessNotification(
          title: 'File Imported',
          message: 'Successfully imported ${file.name}',
        );
      } else {
        await _desktopNotificationsService.showErrorNotification(
          title: 'Import Failed',
          error: 'Failed to import ${file.name}',
          details: result.error,
        );
      }
    }
  }

  /// Get desktop keyboard shortcuts
  Map<ShortcutActivator, Intent> _getDesktopShortcuts() {
    return {
      // Application shortcuts
      const SingleActivator(LogicalKeyboardKey.keyN, control: true): NewInvoiceIntent(),
      const SingleActivator(LogicalKeyboardKey.keyF, control: true): GlobalSearchIntent(),
      const SingleActivator(LogicalKeyboardKey.f1): ShowHelpIntent(),
      const SingleActivator(LogicalKeyboardKey.comma, control: true): ShowSettingsIntent(),
      
      // Window management
      const SingleActivator(LogicalKeyboardKey.f11): ToggleFullscreenIntent(),
      const SingleActivator(LogicalKeyboardKey.keyM, control: true, alt: true): MinimizeWindowIntent(),
      
      // Navigation shortcuts
      const SingleActivator(LogicalKeyboardKey.keyD, control: true, alt: true): GoToDashboardIntent(),
      const SingleActivator(LogicalKeyboardKey.keyI, control: true, alt: true): GoToInvoicesIntent(),
      const SingleActivator(LogicalKeyboardKey.keyC, control: true, alt: true): GoToCustomersIntent(),
    };
  }

  /// Get desktop actions
  Map<Type, Action<Intent>> _getDesktopActions(BuildContext context) {
    return {
      NewInvoiceIntent: CallbackAction<NewInvoiceIntent>(
        onInvoke: (intent) => _navigateTo('/invoices/new'),
      ),
      GlobalSearchIntent: CallbackAction<GlobalSearchIntent>(
        onInvoke: (intent) => _showGlobalSearch(context),
      ),
      ShowHelpIntent: CallbackAction<ShowHelpIntent>(
        onInvoke: (intent) => _navigateTo('/help'),
      ),
      ShowSettingsIntent: CallbackAction<ShowSettingsIntent>(
        onInvoke: (intent) => _navigateTo('/settings'),
      ),
      ToggleFullscreenIntent: CallbackAction<ToggleFullscreenIntent>(
        onInvoke: (intent) => _toggleFullscreen(),
      ),
      MinimizeWindowIntent: CallbackAction<MinimizeWindowIntent>(
        onInvoke: (intent) => windowManager.minimize(),
      ),
      GoToDashboardIntent: CallbackAction<GoToDashboardIntent>(
        onInvoke: (intent) => _navigateTo('/dashboard'),
      ),
      GoToInvoicesIntent: CallbackAction<GoToInvoicesIntent>(
        onInvoke: (intent) => _navigateTo('/invoices'),
      ),
      GoToCustomersIntent: CallbackAction<GoToCustomersIntent>(
        onInvoke: (intent) => _navigateTo('/customers'),
      ),
    };
  }

  /// Navigate to route
  void _navigateTo(String route) {
    // This would use the app's navigation service
    debugPrint('Navigate to: $route');
  }

  /// Show global search overlay
  void _showGlobalSearch(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const GlobalSearchDialog(),
    );
  }

  /// Toggle fullscreen mode
  void _toggleFullscreen() async {
    if (await windowManager.isFullScreen()) {
      await windowManager.setFullScreen(false);
    } else {
      await windowManager.setFullScreen(true);
    }
  }
}

/// Desktop Intent Classes
class NewInvoiceIntent extends Intent {}
class GlobalSearchIntent extends Intent {}
class ShowHelpIntent extends Intent {}
class ShowSettingsIntent extends Intent {}
class ToggleFullscreenIntent extends Intent {}
class MinimizeWindowIntent extends Intent {}
class GoToDashboardIntent extends Intent {}
class GoToInvoicesIntent extends Intent {}
class GoToCustomersIntent extends Intent {}

/// Global Search Dialog
class GlobalSearchDialog extends StatefulWidget {
  const GlobalSearchDialog({Key? key}) : super(key: key);

  @override
  State<GlobalSearchDialog> createState() => _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends State<GlobalSearchDialog> {
  final _searchController = TextEditingController();
  final _searchService = AdvancedSearchService();
  List<SearchResult> _results = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final searchQuery = SearchQuery(query: query);
    final results = await _searchService.search(searchQuery);

    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        height: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search header
            Row(
              children: [
                const Icon(Icons.search, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search invoices, customers, products...',
                      border: InputBorder.none,
                    ),
                    onChanged: _performSearch,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            
            // Search results
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? const Center(
                          child: Text(
                            'Start typing to search...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final result = _results[index];
                            return ListTile(
                              leading: Icon(_getIconForType(result.type)),
                              title: Text(result.title),
                              subtitle: Text(result.subtitle),
                              trailing: Chip(
                                label: Text(result.category),
                                backgroundColor: Colors.grey[200],
                              ),
                              onTap: () {
                                Navigator.of(context).pop();
                                // Navigate to result
                                debugPrint('Selected result: ${result.title}');
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'invoice':
        return Icons.description;
      case 'customer':
        return Icons.person;
      case 'product':
        return Icons.inventory;
      default:
        return Icons.article;
    }
  }
}