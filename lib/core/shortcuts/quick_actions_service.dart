import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_actions/quick_actions.dart';

// Quick action types
enum QuickActionType {
  createInvoice,
  addCustomer,
  addProduct,
  viewReports,
  scanReceipt,
  syncData,
}

// Quick action model
class QuickActionItem {
  final String type;
  final String localizedTitle;
  final String localizedDescription;
  final String icon;

  const QuickActionItem({
    required this.type,
    required this.localizedTitle,
    required this.localizedDescription,
    required this.icon,
  });
}

// Quick actions service
class QuickActionsService extends ChangeNotifier {
  static final QuickActionsService _instance = QuickActionsService._internal();
  factory QuickActionsService() => _instance;
  QuickActionsService._internal();

  final QuickActions _quickActions = const QuickActions();
  String? _lastActionType;
  Function(String)? _onActionCallback;

  String? get lastActionType => _lastActionType;

  // Initialize quick actions
  Future<void> initialize() async {
    await _setupQuickActions();
    _quickActions.initialize(_handleQuickAction);
    debugPrint('Quick Actions Service initialized');
  }

  // Set up the quick actions
  Future<void> _setupQuickActions() async {
    await _quickActions.setShortcutItems([
      const ShortcutItem(
        type: 'create_invoice',
        localizedTitle: 'Create Invoice',
        localizedDescription: 'Quickly create a new invoice',
        icon: 'ic_create_invoice',
      ),
      const ShortcutItem(
        type: 'add_customer',
        localizedTitle: 'Add Customer',
        localizedDescription: 'Add a new customer',
        icon: 'ic_add_customer',
      ),
      const ShortcutItem(
        type: 'add_product',
        localizedTitle: 'Add Product',
        localizedDescription: 'Add a new product to inventory',
        icon: 'ic_add_product',
      ),
      const ShortcutItem(
        type: 'view_reports',
        localizedTitle: 'View Reports',
        localizedDescription: 'View business reports and analytics',
        icon: 'ic_reports',
      ),
      const ShortcutItem(
        type: 'sync_data',
        localizedTitle: 'Sync Data',
        localizedDescription: 'Sync offline data to cloud',
        icon: 'ic_sync',
      ),
    ]);
  }

  // Handle quick action selection
  void _handleQuickAction(String shortcutType) {
    debugPrint('Quick action triggered: $shortcutType');
    _lastActionType = shortcutType;
    _onActionCallback?.call(shortcutType);
    notifyListeners();
  }

  // Set callback for handling quick actions
  void setActionCallback(Function(String) callback) {
    _onActionCallback = callback;
  }

  // Clear last action
  void clearLastAction() {
    _lastActionType = null;
    notifyListeners();
  }

  // Update quick actions based on user preferences or app state
  Future<void> updateQuickActions({
    bool showCreateInvoice = true,
    bool showAddCustomer = true,
    bool showAddProduct = true,
    bool showViewReports = true,
    bool showSyncData = true,
  }) async {
    final List<ShortcutItem> shortcuts = [];

    if (showCreateInvoice) {
      shortcuts.add(const ShortcutItem(
        type: 'create_invoice',
        localizedTitle: 'Create Invoice',
        localizedDescription: 'Quickly create a new invoice',
        icon: 'ic_create_invoice',
      ));
    }

    if (showAddCustomer) {
      shortcuts.add(const ShortcutItem(
        type: 'add_customer',
        localizedTitle: 'Add Customer',
        localizedDescription: 'Add a new customer',
        icon: 'ic_add_customer',
      ));
    }

    if (showAddProduct) {
      shortcuts.add(const ShortcutItem(
        type: 'add_product',
        localizedTitle: 'Add Product',
        localizedDescription: 'Add a new product to inventory',
        icon: 'ic_add_product',
      ));
    }

    if (showViewReports) {
      shortcuts.add(const ShortcutItem(
        type: 'view_reports',
        localizedTitle: 'View Reports',
        localizedDescription: 'View business reports and analytics',
        icon: 'ic_reports',
      ));
    }

    if (showSyncData) {
      shortcuts.add(const ShortcutItem(
        type: 'sync_data',
        localizedTitle: 'Sync Data',
        localizedDescription: 'Sync offline data to cloud',
        icon: 'ic_sync',
      ));
    }

    await _quickActions.setShortcutItems(shortcuts);
  }

  // Get quick action type from string
  QuickActionType? getActionType(String actionString) {
    switch (actionString) {
      case 'create_invoice':
        return QuickActionType.createInvoice;
      case 'add_customer':
        return QuickActionType.addCustomer;
      case 'add_product':
        return QuickActionType.addProduct;
      case 'view_reports':
        return QuickActionType.viewReports;
      case 'scan_receipt':
        return QuickActionType.scanReceipt;
      case 'sync_data':
        return QuickActionType.syncData;
      default:
        return null;
    }
  }

  // Get action description for UI
  String getActionDescription(QuickActionType actionType) {
    switch (actionType) {
      case QuickActionType.createInvoice:
        return 'Create a new invoice for your customers';
      case QuickActionType.addCustomer:
        return 'Add a new customer to your business';
      case QuickActionType.addProduct:
        return 'Add a new product to your inventory';
      case QuickActionType.viewReports:
        return 'View your business reports and analytics';
      case QuickActionType.scanReceipt:
        return 'Scan receipts and extract data automatically';
      case QuickActionType.syncData:
        return 'Sync your offline data to the cloud';
    }
  }

  // Get action icon for UI
  IconData getActionIcon(QuickActionType actionType) {
    switch (actionType) {
      case QuickActionType.createInvoice:
        return Icons.description_outlined;
      case QuickActionType.addCustomer:
        return Icons.person_add_outlined;
      case QuickActionType.addProduct:
        return Icons.inventory_2_outlined;
      case QuickActionType.viewReports:
        return Icons.analytics_outlined;
      case QuickActionType.scanReceipt:
        return Icons.camera_alt_outlined;
      case QuickActionType.syncData:
        return Icons.sync_outlined;
    }
  }
}

// Quick action handler widget
class QuickActionHandler extends ConsumerStatefulWidget {
  final Widget child;
  final Function(QuickActionType)? onQuickAction;

  const QuickActionHandler({
    super.key,
    required this.child,
    this.onQuickAction,
  });

  @override
  ConsumerState<QuickActionHandler> createState() => _QuickActionHandlerState();
}

class _QuickActionHandlerState extends ConsumerState<QuickActionHandler> {
  @override
  void initState() {
    super.initState();
    
    // Set up the callback for handling quick actions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final quickActionsService = ref.read(quickActionsServiceProvider);
      quickActionsService.setActionCallback(_handleQuickAction);
      
      // Check if there's a pending action from app launch
      if (quickActionsService.lastActionType != null) {
        _handleQuickAction(quickActionsService.lastActionType!);
        quickActionsService.clearLastAction();
      }
    });
  }

  void _handleQuickAction(String actionType) {
    final quickActionsService = ref.read(quickActionsServiceProvider);
    final actionTypeEnum = quickActionsService.getActionType(actionType);
    
    if (actionTypeEnum != null) {
      widget.onQuickAction?.call(actionTypeEnum);
      
      // Show a snackbar to indicate the action
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quick action: ${quickActionsService.getActionDescription(actionTypeEnum)}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// Quick actions floating action button
class QuickActionsFAB extends ConsumerWidget {
  final Function(QuickActionType)? onActionSelected;

  const QuickActionsFAB({
    super.key,
    this.onActionSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton(
      onPressed: () => _showQuickActionsBottomSheet(context, ref),
      child: const Icon(Icons.add),
    );
  }

  void _showQuickActionsBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: QuickActionType.values.map((actionType) {
                final quickActionsService = ref.read(quickActionsServiceProvider);
                return _QuickActionTile(
                  actionType: actionType,
                  title: _getActionTitle(actionType),
                  icon: quickActionsService.getActionIcon(actionType),
                  onTap: () {
                    Navigator.pop(context);
                    onActionSelected?.call(actionType);
                  },
                );
              }).toList(),
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _getActionTitle(QuickActionType actionType) {
    switch (actionType) {
      case QuickActionType.createInvoice:
        return 'Create Invoice';
      case QuickActionType.addCustomer:
        return 'Add Customer';
      case QuickActionType.addProduct:
        return 'Add Product';
      case QuickActionType.viewReports:
        return 'View Reports';
      case QuickActionType.scanReceipt:
        return 'Scan Receipt';
      case QuickActionType.syncData:
        return 'Sync Data';
    }
  }
}

class _QuickActionTile extends StatelessWidget {
  final QuickActionType actionType;
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.actionType,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).dividerColor,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 32,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Riverpod providers
final quickActionsServiceProvider = Provider<QuickActionsService>((ref) {
  final service = QuickActionsService();
  service.initialize();
  return service;
});

final lastQuickActionProvider = StateProvider<String?>((ref) {
  final service = ref.watch(quickActionsServiceProvider);
  return service.lastActionType;
});