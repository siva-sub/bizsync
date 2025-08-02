import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_models.dart';
import '../models/notification_types.dart';
import '../providers/notification_providers.dart';
import '../utils/notification_utils.dart';

/// Notification card widget for displaying individual notifications
class NotificationCard extends ConsumerWidget {
  final BizSyncNotification notification;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final bool showActions;

  const NotificationCard({
    Key? key,
    required this.notification,
    this.onTap,
    this.onDismiss,
    this.showActions = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final formatted = NotificationUtils.formatNotificationForDisplay(notification);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: notification.isRead ? 1 : 3,
      child: InkWell(
        onTap: () {
          if (!notification.isRead) {
            ref.read(activeNotificationsProvider.notifier)
                .markAsRead(notification.id);
          }
          onTap?.call();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(int.parse('0xFF${formatted.priorityColor.substring(1)}')),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      _getCategoryIcon(notification.category),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and time
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: notification.isRead 
                                      ? FontWeight.normal 
                                      : FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              formatted.formattedTime,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        
                        // Body
                        Text(
                          notification.body,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: notification.isRead 
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.onSurface,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        // Priority indicator
                        if (notification.priority == NotificationPriority.critical ||
                            notification.priority == NotificationPriority.high) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Color(int.parse('0xFF${formatted.priorityColor.substring(1)}'))
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              notification.priority.name.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Color(int.parse('0xFF${formatted.priorityColor.substring(1)}')),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        
                        // Actions
                        if (showActions && notification.hasActions) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              for (final action in notification.actions!.take(2))
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: OutlinedButton(
                                    onPressed: () => _handleAction(context, ref, action),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                    ),
                                    child: Text(
                                      action.title,
                                      style: theme.textTheme.labelSmall,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Dismiss button
                  if (onDismiss != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: onDismiss,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                ],
              ),
              
              // Progress indicator
              if (notification.hasProgress) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: notification.indeterminate 
                      ? null 
                      : (notification.progress! / notification.maxProgress!),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ],
            ],
          ),
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

  void _handleAction(BuildContext context, WidgetRef ref, NotificationAction action) {
    // Handle notification actions
    switch (action.type) {
      case NotificationActionType.view:
        // Navigate to relevant screen
        _navigateToAction(context, action);
        break;
      case NotificationActionType.dismiss:
        onDismiss?.call();
        break;
      case NotificationActionType.snooze:
        _snoozeNotification(ref, notification.id);
        break;
      default:
        // Handle custom actions
        _handleCustomAction(context, ref, action);
        break;
    }
  }

  void _navigateToAction(BuildContext context, NotificationAction action) {
    final deepLink = NotificationUtils.createDeepLink(action.payload);
    if (deepLink != null) {
      Navigator.of(context).pushNamed(deepLink);
    }
  }

  void _snoozeNotification(WidgetRef ref, String notificationId) {
    // Snooze for 15 minutes
    final scheduler = ref.read(notificationSchedulerProvider);
    // Implementation would reschedule the notification
  }

  void _handleCustomAction(BuildContext context, WidgetRef ref, NotificationAction action) {
    // Handle custom actions based on action ID
    switch (action.id) {
      case 'mark_complete':
        // Mark task as complete
        break;
      case 'contact_customer':
        // Open contact screen
        break;
      case 'retry_payment':
        // Retry payment process
        break;
      default:
        break;
    }
  }
}

/// Notification list widget
class NotificationList extends ConsumerWidget {
  final List<BizSyncNotification> notifications;
  final bool showSearch;
  final bool showFilters;
  final String? emptyMessage;

  const NotificationList({
    Key? key,
    required this.notifications,
    this.showSearch = true,
    this.showFilters = true,
    this.emptyMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage ?? 'No notifications',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return Dismissible(
          key: Key(notification.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red,
            child: const Icon(
              Icons.delete,
              color: Colors.white,
            ),
          ),
          onDismissed: (direction) {
            ref.read(activeNotificationsProvider.notifier)
                .dismissNotification(notification.id);
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Notification dismissed'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () {
                    // Restore notification (would need to implement)
                  },
                ),
              ),
            );
          },
          child: NotificationCard(
            notification: notification,
            onTap: () => _handleNotificationTap(context, ref, notification),
            onDismiss: () => ref.read(activeNotificationsProvider.notifier)
                .dismissNotification(notification.id),
          ),
        );
      },
    );
  }

  void _handleNotificationTap(
    BuildContext context,
    WidgetRef ref,
    BizSyncNotification notification,
  ) {
    // Navigate based on notification payload
    final deepLink = NotificationUtils.createDeepLink(notification.payload);
    if (deepLink != null) {
      Navigator.of(context).pushNamed(deepLink);
    }
  }
}

/// Notification filter chip widget
class NotificationFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;

  const NotificationFilterChip({
    Key? key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: selectedColor ?? Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: selected ? Theme.of(context).colorScheme.onPrimaryContainer : null,
    );
  }
}

/// Notification statistics widget
class NotificationStatistics extends ConsumerWidget {
  const NotificationStatistics({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categoryCounts = ref.watch(categoryNotificationCountsProvider);
    final priorityCounts = ref.watch(priorityNotificationCountsProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notification Statistics',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            // Unread count
            Row(
              children: [
                Icon(
                  Icons.markunread,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text('Unread: $unreadCount'),
              ],
            ),
            const SizedBox(height: 12),
            
            // Category breakdown
            Text(
              'By Category',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...categoryCounts.entries.map((entry) {
              if (entry.value == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      _getCategoryIcon(entry.key),
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text('${entry.key.displayName}: ${entry.value}'),
                  ],
                ),
              );
            }).toList(),
            
            const SizedBox(height: 12),
            
            // Priority breakdown
            Text(
              'By Priority',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...priorityCounts.entries.map((entry) {
              if (entry.value == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getPriorityColor(entry.key),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${entry.key.name.toUpperCase()}: ${entry.value}'),
                  ],
                ),
              );
            }).toList(),
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
}

/// Quick action buttons for notifications
class NotificationQuickActions extends ConsumerWidget {
  const NotificationQuickActions({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _QuickActionButton(
              icon: Icons.mark_email_read,
              label: 'Mark All Read',
              onTap: () => _markAllAsRead(ref),
            ),
            _QuickActionButton(
              icon: Icons.clear_all,
              label: 'Clear All',
              onTap: () => _showClearAllDialog(context, ref),
            ),
            _QuickActionButton(
              icon: Icons.filter_list,
              label: 'Filter',
              onTap: () => _showFilterDialog(context, ref),
            ),
            _QuickActionButton(
              icon: Icons.settings,
              label: 'Settings',
              onTap: () => Navigator.of(context).pushNamed('/notifications/settings'),
            ),
          ],
        ),
      ),
    );
  }

  void _markAllAsRead(WidgetRef ref) {
    final notifications = ref.read(activeNotificationsProvider);
    final notifier = ref.read(activeNotificationsProvider.notifier);
    
    for (final notification in notifications) {
      if (!notification.isRead) {
        notifier.markAsRead(notification.id);
      }
    }
  }

  void _showClearAllDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('Are you sure you want to clear all notifications? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(activeNotificationsProvider.notifier).clearAll();
              Navigator.of(context).pop();
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context, WidgetRef ref) {
    // Show filter dialog
    showModalBottomSheet(
      context: context,
      builder: (context) => const NotificationFilterSheet(),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Notification filter bottom sheet
class NotificationFilterSheet extends ConsumerWidget {
  const NotificationFilterSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(notificationSearchProvider);
    final searchNotifier = ref.read(notificationSearchProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter Notifications',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          
          // Category filters
          Text(
            'Categories',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: NotificationCategory.values.map((category) {
              final selected = searchState.categoryFilters.contains(category);
              return NotificationFilterChip(
                label: category.displayName,
                selected: selected,
                onTap: () {
                  if (selected) {
                    searchNotifier.removeCategoryFilter(category);
                  } else {
                    searchNotifier.addCategoryFilter(category);
                  }
                },
              );
            }).toList(),
          ),
          
          const SizedBox(height: 16),
          
          // Priority filters
          Text(
            'Priorities',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: NotificationPriority.values.map((priority) {
              final selected = searchState.priorityFilters.contains(priority);
              return NotificationFilterChip(
                label: priority.name.toUpperCase(),
                selected: selected,
                onTap: () {
                  if (selected) {
                    searchNotifier.removePriorityFilter(priority);
                  } else {
                    searchNotifier.addPriorityFilter(priority);
                  }
                },
              );
            }).toList(),
          ),
          
          const SizedBox(height: 24),
          
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () {
                  searchNotifier.clearFilters();
                  Navigator.of(context).pop();
                },
                child: const Text('Clear Filters'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Apply'),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}