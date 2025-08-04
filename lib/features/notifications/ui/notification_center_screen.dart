import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_types.dart';
import '../providers/notification_providers.dart';
import '../widgets/notification_widgets.dart';

/// Main notification center screen
class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: _showSearch ? _buildSearchField() : const Text('Notifications'),
        actions: [
          if (!_showSearch) ...[
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _showSearch = true),
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () =>
                  Navigator.of(context).pushNamed('/notifications/settings'),
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() => _showSearch = false);
                _searchController.clear();
                ref.read(notificationSearchProvider.notifier).clearSearch();
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('All'),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        unreadCount.toString(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onError,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Business'),
            const Tab(text: 'Reminders'),
            const Tab(text: 'Insights'),
            const Tab(text: 'System'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Quick actions
          const NotificationQuickActions(),

          // Statistics (collapsible)
          const NotificationStatistics(),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllNotificationsTab(),
                _buildCategoryTab(NotificationCategory.invoice),
                _buildCategoryTab(NotificationCategory.reminder),
                _buildCategoryTab(NotificationCategory.insight),
                _buildCategoryTab(NotificationCategory.system),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateNotificationDialog(context),
        tooltip: 'Create Test Notification',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      decoration: const InputDecoration(
        hintText: 'Search notifications...',
        border: InputBorder.none,
      ),
      onChanged: (query) {
        ref.read(notificationSearchProvider.notifier).search(query);
      },
    );
  }

  Widget _buildAllNotificationsTab() {
    if (_showSearch) {
      return _buildSearchResults();
    }

    return Consumer(
      builder: (context, ref, child) {
        final notifications = ref.watch(activeNotificationsProvider);
        final sortedNotifications = [...notifications]..sort((a, b) {
            // Unread first, then by creation time
            if (a.isRead != b.isRead) {
              return a.isRead ? 1 : -1;
            }
            return b.createdAt.compareTo(a.createdAt);
          });

        return RefreshIndicator(
          onRefresh: () async {
            ref.read(activeNotificationsProvider.notifier).refresh();
          },
          child: NotificationList(
            notifications: sortedNotifications,
            emptyMessage: 'No notifications yet',
          ),
        );
      },
    );
  }

  Widget _buildCategoryTab(NotificationCategory category) {
    return Consumer(
      builder: (context, ref, child) {
        final notifications =
            ref.watch(notificationsByCategoryProvider(category));

        return RefreshIndicator(
          onRefresh: () async {
            ref.read(activeNotificationsProvider.notifier).refresh();
          },
          child: NotificationList(
            notifications: notifications,
            emptyMessage:
                'No ${category.displayName.toLowerCase()} notifications',
          ),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    return Consumer(
      builder: (context, ref, child) {
        final searchState = ref.watch(notificationSearchProvider);

        if (searchState.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            // Search filters
            if (searchState.categoryFilters.isNotEmpty ||
                searchState.priorityFilters.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active filters:',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ...searchState.categoryFilters.map(
                          (category) => Chip(
                            label: Text(category.displayName),
                            onDeleted: () => ref
                                .read(notificationSearchProvider.notifier)
                                .removeCategoryFilter(category),
                          ),
                        ),
                        ...searchState.priorityFilters.map(
                          (priority) => Chip(
                            label: Text(priority.name.toUpperCase()),
                            onDeleted: () => ref
                                .read(notificationSearchProvider.notifier)
                                .removePriorityFilter(priority),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Search results
            Expanded(
              child: NotificationList(
                notifications: searchState.results,
                emptyMessage: searchState.query.isEmpty
                    ? 'Start typing to search notifications'
                    : 'No notifications found matching "${searchState.query}"',
                showSearch: false,
                showFilters: false,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCreateNotificationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Test Notification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.receipt),
              title: const Text('Invoice Due'),
              subtitle: const Text('Test invoice due notification'),
              onTap: () {
                _createTestNotification(
                  context,
                  'Invoice Due',
                  'Test invoice #INV-001 is due tomorrow',
                  NotificationCategory.invoice,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.payment),
              title: const Text('Payment Received'),
              subtitle: const Text('Test payment received notification'),
              onTap: () {
                _createTestNotification(
                  context,
                  'Payment Received',
                  'Received \$500.00 from John Doe',
                  NotificationCategory.payment,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance),
              title: const Text('Tax Deadline'),
              subtitle: const Text('Test tax deadline notification'),
              onTap: () {
                _createTestNotification(
                  context,
                  'Tax Deadline Approaching',
                  'GST filing deadline is in 7 days',
                  NotificationCategory.tax,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.backup),
              title: const Text('Backup Complete'),
              subtitle: const Text('Test backup notification'),
              onTap: () {
                _createTestNotification(
                  context,
                  'Backup Complete',
                  'Your data backup completed successfully',
                  NotificationCategory.backup,
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _createTestNotification(
    BuildContext context,
    String title,
    String body,
    NotificationCategory category,
  ) async {
    final notificationService = ref.read(notificationServiceProvider);

    await notificationService.showNotification(
      title: title,
      body: body,
      category: category,
      priority: NotificationPriority.medium,
      payload: {
        'test': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
    );

    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title notification created'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

/// Notification detail screen for expanded view
class NotificationDetailScreen extends ConsumerWidget {
  final String notificationId;

  const NotificationDetailScreen({
    Key? key,
    required this.notificationId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(activeNotificationsProvider);
    final notification =
        notifications.where((n) => n.id == notificationId).firstOrNull;

    if (notification == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notification')),
        body: const Center(
          child: Text('Notification not found'),
        ),
      );
    }

    // Mark as read when viewing
    if (!notification.isRead) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(activeNotificationsProvider.notifier)
            .markAsRead(notificationId);
      });
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(notification.category.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              ref
                  .read(activeNotificationsProvider.notifier)
                  .dismissNotification(notificationId);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              notification.title,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),

            // Metadata
            Row(
              children: [
                Icon(
                  _getCategoryIcon(notification.category),
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  notification.category.displayName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDateTime(notification.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Priority indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getPriorityColor(notification.priority)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getPriorityIcon(notification.priority),
                    size: 16,
                    color: _getPriorityColor(notification.priority),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    notification.priority.name.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _getPriorityColor(notification.priority),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Body
            Text(
              notification.body,
              style: theme.textTheme.bodyLarge,
            ),

            // Big text if available
            if (notification.bigText != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  notification.bigText!,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],

            // Progress indicator if available
            if (notification.hasProgress) ...[
              const SizedBox(height: 24),
              Text(
                'Progress',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: notification.indeterminate
                    ? null
                    : (notification.progress! / notification.maxProgress!),
              ),
              if (!notification.indeterminate) ...[
                const SizedBox(height: 4),
                Text(
                  '${notification.progress}/${notification.maxProgress}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],

            // Actions
            if (notification.hasActions) ...[
              const SizedBox(height: 24),
              Text(
                'Actions',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...notification.actions!
                  .map(
                    (action) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _handleAction(context, ref, action),
                          icon: Icon(_getActionIcon(action.type)),
                          label: Text(action.title),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ],

            // Payload information (debug)
            if (notification.payload != null) ...[
              const SizedBox(height: 24),
              ExpansionTile(
                title: const Text('Technical Details'),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      notification.payload.toString(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.invoice:
        return Icons.receipt;
      case NotificationCategory.payment:
        return Icons.payment;
      case NotificationCategory.tax:
        return Icons.account_balance;
      case NotificationCategory.backup:
        return Icons.backup;
      case NotificationCategory.insight:
        return Icons.analytics;
      case NotificationCategory.reminder:
        return Icons.schedule;
      case NotificationCategory.system:
        return Icons.settings;
      case NotificationCategory.custom:
        return Icons.notifications;
    }
  }

  Color _getPriorityColor(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.critical:
        return Colors.red;
      case NotificationPriority.high:
        return Colors.orange;
      case NotificationPriority.medium:
        return Colors.blue;
      case NotificationPriority.low:
        return Colors.green;
      case NotificationPriority.info:
        return Colors.grey;
    }
  }

  IconData _getPriorityIcon(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.critical:
        return Icons.error;
      case NotificationPriority.high:
        return Icons.warning;
      case NotificationPriority.medium:
        return Icons.info;
      case NotificationPriority.low:
        return Icons.check_circle;
      case NotificationPriority.info:
        return Icons.info_outline;
    }
  }

  IconData _getActionIcon(NotificationActionType type) {
    switch (type) {
      case NotificationActionType.view:
        return Icons.visibility;
      case NotificationActionType.dismiss:
        return Icons.close;
      case NotificationActionType.snooze:
        return Icons.snooze;
      case NotificationActionType.markAsPaid:
        return Icons.payment;
      case NotificationActionType.createInvoice:
        return Icons.receipt_long;
      case NotificationActionType.viewReport:
        return Icons.analytics;
      case NotificationActionType.openCalculator:
        return Icons.calculate;
      case NotificationActionType.startBackup:
        return Icons.backup;
      case NotificationActionType.custom:
        return Icons.touch_app;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _handleAction(
      BuildContext context, WidgetRef ref, NotificationAction action) {
    // Handle the action (similar to widget implementation)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${action.title} action triggered'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
