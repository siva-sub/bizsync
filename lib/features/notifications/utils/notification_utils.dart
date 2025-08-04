import 'dart:math';
import '../models/notification_models.dart';
import '../models/notification_types.dart';
import '../models/notification_settings.dart';

/// Utility functions for notification processing
class NotificationUtils {
  /// Generate unique notification ID
  static int generateNotificationId() {
    return DateTime.now().millisecondsSinceEpoch % 2147483647;
  }

  /// Calculate optimal delivery time based on user activity
  static DateTime? calculateOptimalDeliveryTime({
    required DateTime requestedTime,
    required UserActivityContext userContext,
    required IntelligentSettings settings,
  }) {
    if (!settings.enabled) return requestedTime;

    final now = DateTime.now();

    // Don't schedule in the past
    if (requestedTime.isBefore(now)) {
      return now.add(const Duration(minutes: 1));
    }

    // If user is currently active and it's business hours, deliver immediately
    if (userContext.isAppActive && settings.isBusinessHours(requestedTime)) {
      return requestedTime.add(settings.optimalDelay);
    }

    // If it's outside business hours, schedule for next business day
    if (!settings.isBusinessHours(requestedTime)) {
      return settings.getOptimalDeliveryTime(requestedTime);
    }

    // Apply intelligent delay based on user behavior
    if (settings.adaptToUserBehavior) {
      final delay = _calculateIntelligentDelay(userContext, settings);
      return requestedTime.add(delay);
    }

    return requestedTime;
  }

  static Duration _calculateIntelligentDelay(
    UserActivityContext context,
    IntelligentSettings settings,
  ) {
    // Base delay
    Duration delay = settings.optimalDelay;

    // Reduce delay if user is active
    if (context.isAppActive) {
      delay = Duration(milliseconds: (delay.inMilliseconds * 0.5).round());
    }

    // Increase delay if user has been dismissing notifications frequently
    if (context.recentActions.where((action) => action == 'dismiss').length >
        3) {
      delay = Duration(milliseconds: (delay.inMilliseconds * 2).round());
    }

    // Adjust based on screen usage patterns
    if (context.currentScreen != null) {
      final screenUsage = context.screenUsage[context.currentScreen!] ?? 0;
      if (screenUsage > 300) {
        // User spends a lot of time on this screen
        delay = Duration(milliseconds: (delay.inMilliseconds * 0.7).round());
      }
    }

    return delay;
  }

  /// Determine if notifications should be batched
  static bool shouldBatchNotifications({
    required List<BizSyncNotification> pendingNotifications,
    required NotificationCategory category,
    required BatchingSettings settings,
  }) {
    if (!settings.enabled) return false;
    if (settings.neverBatchCategories.contains(category)) return false;

    final categoryNotifications =
        pendingNotifications.where((n) => n.category == category).toList();

    final threshold = settings.categoryThresholds[category] ?? 2;
    return categoryNotifications.length >= threshold;
  }

  /// Create notification batch from multiple notifications
  static NotificationBatch createNotificationBatch({
    required List<BizSyncNotification> notifications,
    required String batchId,
    int maxNotifications = 5,
  }) {
    if (notifications.isEmpty) {
      throw ArgumentError('Cannot create batch from empty notification list');
    }

    final category = notifications.first.category;
    final limitedNotifications = notifications.take(maxNotifications).toList();

    String title;
    String summary;

    switch (category) {
      case NotificationCategory.invoice:
        title = 'Invoice Updates';
        summary = '${limitedNotifications.length} invoice notifications';
        break;
      case NotificationCategory.payment:
        title = 'Payment Updates';
        summary = '${limitedNotifications.length} payment notifications';
        break;
      case NotificationCategory.reminder:
        title = 'Reminders';
        summary = '${limitedNotifications.length} reminders';
        break;
      default:
        title = category.displayName;
        summary =
            '${limitedNotifications.length} ${category.displayName.toLowerCase()}';
    }

    return NotificationBatch(
      id: batchId,
      title: title,
      summary: summary,
      notificationIds: limitedNotifications.map((n) => n.id).toList(),
      category: category,
      createdAt: DateTime.now(),
      maxNotifications: maxNotifications,
    );
  }

  /// Calculate notification priority score for ranking
  static double calculatePriorityScore(BizSyncNotification notification) {
    double score = 0;

    // Base priority score
    switch (notification.priority) {
      case NotificationPriority.critical:
        score += 100;
        break;
      case NotificationPriority.high:
        score += 75;
        break;
      case NotificationPriority.medium:
        score += 50;
        break;
      case NotificationPriority.low:
        score += 25;
        break;
      case NotificationPriority.info:
        score += 10;
        break;
    }

    // Category importance
    switch (notification.category) {
      case NotificationCategory.invoice:
      case NotificationCategory.payment:
        score += 20;
        break;
      case NotificationCategory.tax:
        score += 15;
        break;
      case NotificationCategory.reminder:
        score += 10;
        break;
      case NotificationCategory.backup:
      case NotificationCategory.system:
        score += 5;
        break;
      default:
        break;
    }

    // Time sensitivity
    if (notification.scheduledFor != null) {
      final timeDiff = notification.scheduledFor!.difference(DateTime.now());
      if (timeDiff.inHours < 1) {
        score += 30; // Very urgent
      } else if (timeDiff.inHours < 24) {
        score += 15; // Moderately urgent
      }
    }

    // Expiry urgency
    if (notification.expiresAt != null) {
      final timeToExpiry = notification.expiresAt!.difference(DateTime.now());
      if (timeToExpiry.inHours < 1) {
        score += 25;
      }
    }

    return score;
  }

  /// Sort notifications by priority and relevance
  static List<BizSyncNotification> sortNotificationsByPriority(
    List<BizSyncNotification> notifications,
  ) {
    notifications.sort((a, b) {
      final scoreA = calculatePriorityScore(a);
      final scoreB = calculatePriorityScore(b);

      // Higher score first
      final scoreDiff = scoreB.compareTo(scoreA);
      if (scoreDiff != 0) return scoreDiff;

      // Then by creation time (newer first)
      return b.createdAt.compareTo(a.createdAt);
    });

    return notifications;
  }

  /// Filter notifications based on settings
  static List<BizSyncNotification> filterNotifications({
    required List<BizSyncNotification> notifications,
    required NotificationSettings settings,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();

    return notifications.where((notification) {
      // Global enabled check
      if (!settings.globalEnabled) return false;

      // Category enabled check
      final categorySettings = settings.categorySettings[notification.category];
      if (categorySettings == null || !categorySettings.enabled) return false;

      // Priority check
      final priorityIndex =
          NotificationPriority.values.indexOf(notification.priority);
      final minPriorityIndex =
          NotificationPriority.values.indexOf(categorySettings.minimumPriority);
      if (priorityIndex < minPriorityIndex) return false;

      // Do not disturb check
      if (settings.doNotDisturb.isActive(now) &&
          !settings.doNotDisturb.shouldBypass(notification.priority)) {
        return false;
      }

      // Expiry check
      if (notification.isExpired) return false;

      return true;
    }).toList();
  }

  /// Generate user activity context
  static UserActivityContext generateActivityContext({
    required bool isAppActive,
    String? currentScreen,
    Map<String, int>? screenUsage,
    List<String>? recentActions,
  }) {
    final now = DateTime.now();

    return UserActivityContext(
      timestamp: now,
      isAppActive: isAppActive,
      currentScreen: currentScreen,
      screenUsage: screenUsage ?? {},
      recentActions: recentActions ?? [],
      isBusinessHours: _isBusinessHours(now),
      isWeekend: _isWeekend(now),
      timezone: now.timeZoneName,
    );
  }

  static bool _isBusinessHours(DateTime time) {
    // Default business hours: 9 AM - 5 PM, Monday to Friday
    if (_isWeekend(time)) return false;
    return time.hour >= 9 && time.hour < 17;
  }

  static bool _isWeekend(DateTime time) {
    return time.weekday == DateTime.saturday || time.weekday == DateTime.sunday;
  }

  /// Validate notification data
  static ValidationResult validateNotification(
      BizSyncNotification notification) {
    final errors = <String>[];

    if (notification.title.trim().isEmpty) {
      errors.add('Title cannot be empty');
    }

    if (notification.body.trim().isEmpty) {
      errors.add('Body cannot be empty');
    }

    if (notification.scheduledFor != null &&
        notification.scheduledFor!.isBefore(DateTime.now())) {
      errors.add('Scheduled time cannot be in the past');
    }

    if (notification.expiresAt != null &&
        notification.expiresAt!.isBefore(DateTime.now())) {
      errors.add('Expiry time cannot be in the past');
    }

    if (notification.progress != null && notification.maxProgress != null) {
      if (notification.progress! > notification.maxProgress!) {
        errors.add('Progress cannot exceed max progress');
      }
      if (notification.progress! < 0) {
        errors.add('Progress cannot be negative');
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Calculate notification engagement score
  static double calculateEngagementScore(NotificationMetrics metrics) {
    double score = 0.0;

    // Base score for delivery
    score += 0.1;

    // Score for being seen
    if (metrics.firstSeenAt != null) {
      score += 0.2;
    }

    // Score for being opened
    if (metrics.wasOpened) {
      score += 0.4;

      // Bonus for quick opening
      if (metrics.timeToOpen != null && metrics.timeToOpen!.inMinutes < 5) {
        score += 0.1;
      }
    }

    // Score for taking action
    if (metrics.hadAction) {
      score += 0.3;

      // Bonus for quick action
      if (metrics.timeToAction != null && metrics.timeToAction!.inMinutes < 2) {
        score += 0.1;
      }
    }

    // Penalty for dismissal
    if (metrics.wasDismissed) {
      score -= 0.2;
    }

    return score.clamp(0.0, 1.0);
  }

  /// Generate notification analytics summary
  static NotificationAnalyticsSummary generateAnalyticsSummary(
    List<NotificationMetrics> metrics,
  ) {
    if (metrics.isEmpty) {
      return NotificationAnalyticsSummary(
        totalNotifications: 0,
        openRate: 0.0,
        actionRate: 0.0,
        dismissalRate: 0.0,
        averageEngagement: 0.0,
        averageTimeToOpen: Duration.zero,
        averageTimeToAction: Duration.zero,
      );
    }

    final totalCount = metrics.length;
    final openedCount = metrics.where((m) => m.wasOpened).length;
    final actionCount = metrics.where((m) => m.hadAction).length;
    final dismissedCount = metrics.where((m) => m.wasDismissed).length;

    final openTimes = metrics
        .where((m) => m.timeToOpen != null)
        .map((m) => m.timeToOpen!.inSeconds)
        .toList();

    final actionTimes = metrics
        .where((m) => m.timeToAction != null)
        .map((m) => m.timeToAction!.inSeconds)
        .toList();

    final engagementScores =
        metrics.map((m) => calculateEngagementScore(m)).toList();

    return NotificationAnalyticsSummary(
      totalNotifications: totalCount,
      openRate: openedCount / totalCount,
      actionRate: actionCount / totalCount,
      dismissalRate: dismissedCount / totalCount,
      averageEngagement: engagementScores.isEmpty
          ? 0.0
          : engagementScores.reduce((a, b) => a + b) / engagementScores.length,
      averageTimeToOpen: openTimes.isEmpty
          ? Duration.zero
          : Duration(
              seconds: (openTimes.reduce((a, b) => a + b) / openTimes.length)
                  .round()),
      averageTimeToAction: actionTimes.isEmpty
          ? Duration.zero
          : Duration(
              seconds:
                  (actionTimes.reduce((a, b) => a + b) / actionTimes.length)
                      .round()),
    );
  }

  /// Generate notification ID hash for Android
  static int generateAndroidNotificationId(String notificationId) {
    return notificationId.hashCode.abs() % 2147483647;
  }

  /// Create deep link from notification payload
  static String? createDeepLink(Map<String, dynamic>? payload) {
    if (payload == null) return null;

    final actionType = payload['actionType'] as String?;
    if (actionType == null) return null;

    switch (actionType) {
      case 'view_invoice':
        final invoiceId = payload['invoiceId'] as String?;
        return invoiceId != null ? '/invoices/$invoiceId' : null;

      case 'view_payment':
        final paymentId = payload['paymentId'] as String?;
        return paymentId != null ? '/payments/$paymentId' : null;

      case 'open_tax_calculator':
        return '/tax/calculator';

      case 'view_backup_details':
        return '/backup/history';

      case 'view_analytics':
        return '/dashboard/analytics';

      default:
        return null;
    }
  }

  /// Format notification for display
  static FormattedNotification formatNotificationForDisplay(
    BizSyncNotification notification,
  ) {
    return FormattedNotification(
      id: notification.id,
      title: notification.title,
      body: notification.body,
      formattedTime: _formatRelativeTime(notification.createdAt),
      categoryIcon: notification.category.icon,
      priorityColor: _getPriorityColor(notification.priority),
      isRead: notification.isRead,
      hasActions: notification.hasActions,
      actionCount: notification.actions?.length ?? 0,
    );
  }

  static String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  static String _getPriorityColor(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.critical:
        return '#F44336'; // Red
      case NotificationPriority.high:
        return '#FF9800'; // Orange
      case NotificationPriority.medium:
        return '#2196F3'; // Blue
      case NotificationPriority.low:
        return '#4CAF50'; // Green
      case NotificationPriority.info:
        return '#9E9E9E'; // Grey
    }
  }
}

/// Helper classes for notification utilities

class ValidationResult {
  final bool isValid;
  final List<String> errors;

  const ValidationResult({
    required this.isValid,
    required this.errors,
  });
}

class NotificationAnalyticsSummary {
  final int totalNotifications;
  final double openRate;
  final double actionRate;
  final double dismissalRate;
  final double averageEngagement;
  final Duration averageTimeToOpen;
  final Duration averageTimeToAction;

  const NotificationAnalyticsSummary({
    required this.totalNotifications,
    required this.openRate,
    required this.actionRate,
    required this.dismissalRate,
    required this.averageEngagement,
    required this.averageTimeToOpen,
    required this.averageTimeToAction,
  });
}

class FormattedNotification {
  final String id;
  final String title;
  final String body;
  final String formattedTime;
  final String categoryIcon;
  final String priorityColor;
  final bool isRead;
  final bool hasActions;
  final int actionCount;

  const FormattedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.formattedTime,
    required this.categoryIcon,
    required this.priorityColor,
    required this.isRead,
    required this.hasActions,
    required this.actionCount,
  });
}
