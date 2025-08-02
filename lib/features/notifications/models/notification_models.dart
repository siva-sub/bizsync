import 'package:json_annotation/json_annotation.dart';
import 'notification_types.dart';

part 'notification_models.g.dart';

/// Alias for backward compatibility
typedef NotificationModel = BizSyncNotification;

/// Core notification model
@JsonSerializable()
class BizSyncNotification {
  final String id;
  final String title;
  final String body;
  final BusinessNotificationType type;
  final NotificationCategory category;
  final NotificationPriority priority;
  final NotificationChannel channel;
  final DateTime createdAt;
  final DateTime? scheduledFor;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime? expiresAt;
  final NotificationStatus status;
  final Map<String, dynamic>? payload;
  final List<NotificationAction>? actions;
  final String? imageUrl;
  final String? largeIcon;
  final String? bigText;
  final NotificationStyle style;
  final bool persistent;
  final bool autoCancel;
  final String? groupKey;
  final String? sortKey;
  final int? progress;
  final int? maxProgress;
  final bool indeterminate;
  final String? tag;
  final Map<String, dynamic>? metadata;

  const BizSyncNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.category,
    this.priority = NotificationPriority.medium,
    required this.channel,
    required this.createdAt,
    this.scheduledFor,
    this.deliveredAt,
    this.readAt,
    this.expiresAt,
    this.status = NotificationStatus.pending,
    this.payload,
    this.actions,
    this.imageUrl,
    this.largeIcon,
    this.bigText,
    this.style = NotificationStyle.basic,
    this.persistent = false,
    this.autoCancel = true,
    this.groupKey,
    this.sortKey,
    this.progress,
    this.maxProgress,
    this.indeterminate = false,
    this.tag,
    this.metadata,
  });

  factory BizSyncNotification.fromJson(Map<String, dynamic> json) =>
      _$BizSyncNotificationFromJson(json);

  Map<String, dynamic> toJson() => _$BizSyncNotificationToJson(this);

  BizSyncNotification copyWith({
    String? id,
    String? title,
    String? body,
    BusinessNotificationType? type,
    NotificationCategory? category,
    NotificationPriority? priority,
    NotificationChannel? channel,
    DateTime? createdAt,
    DateTime? scheduledFor,
    DateTime? deliveredAt,
    DateTime? readAt,
    DateTime? expiresAt,
    NotificationStatus? status,
    Map<String, dynamic>? payload,
    List<NotificationAction>? actions,
    String? imageUrl,
    String? largeIcon,
    String? bigText,
    NotificationStyle? style,
    bool? persistent,
    bool? autoCancel,
    String? groupKey,
    String? sortKey,
    int? progress,
    int? maxProgress,
    bool? indeterminate,
    String? tag,
    Map<String, dynamic>? metadata,
  }) {
    return BizSyncNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      channel: channel ?? this.channel,
      createdAt: createdAt ?? this.createdAt,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
      payload: payload ?? this.payload,
      actions: actions ?? this.actions,
      imageUrl: imageUrl ?? this.imageUrl,
      largeIcon: largeIcon ?? this.largeIcon,
      bigText: bigText ?? this.bigText,
      style: style ?? this.style,
      persistent: persistent ?? this.persistent,
      autoCancel: autoCancel ?? this.autoCancel,
      groupKey: groupKey ?? this.groupKey,
      sortKey: sortKey ?? this.sortKey,
      progress: progress ?? this.progress,
      maxProgress: maxProgress ?? this.maxProgress,
      indeterminate: indeterminate ?? this.indeterminate,
      tag: tag ?? this.tag,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isRead => readAt != null;
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isScheduled => scheduledFor != null && DateTime.now().isBefore(scheduledFor!);
  bool get isDelivered => deliveredAt != null;
  bool get hasActions => actions != null && actions!.isNotEmpty;
  bool get hasProgress => progress != null || indeterminate;
}

/// Recurring notification rule
@JsonSerializable()
class NotificationRecurrenceRule {
  final String id;
  final NotificationFrequency frequency;
  final int interval;
  final List<int>? daysOfWeek; // 1=Monday, 7=Sunday
  final List<int>? daysOfMonth; // 1-31
  final List<int>? monthsOfYear; // 1-12
  final DateTime? startDate;
  final DateTime? endDate;
  final int? maxOccurrences;
  final Map<String, dynamic>? exceptions;

  const NotificationRecurrenceRule({
    required this.id,
    required this.frequency,
    this.interval = 1,
    this.daysOfWeek,
    this.daysOfMonth,
    this.monthsOfYear,
    this.startDate,
    this.endDate,
    this.maxOccurrences,
    this.exceptions,
  });

  factory NotificationRecurrenceRule.fromJson(Map<String, dynamic> json) =>
      _$NotificationRecurrenceRuleFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationRecurrenceRuleToJson(this);

  DateTime? getNextOccurrence(DateTime from) {
    if (endDate != null && from.isAfter(endDate!)) return null;
    
    switch (frequency) {
      case NotificationFrequency.daily:
        return from.add(Duration(days: interval));
      case NotificationFrequency.weekly:
        return from.add(Duration(days: 7 * interval));
      case NotificationFrequency.monthly:
        return DateTime(from.year, from.month + interval, from.day);
      case NotificationFrequency.yearly:
        return DateTime(from.year + interval, from.month, from.day);
      default:
        return null;
    }
  }
}

/// Notification scheduling configuration
@JsonSerializable()
class NotificationSchedule {
  final String id;
  final String notificationTemplateId;
  final NotificationTrigger triggerType;
  final DateTime? scheduledTime;
  final NotificationRecurrenceRule? recurrenceRule;
  final Map<String, dynamic>? conditions;
  final bool enabled;
  final DateTime createdAt;
  final DateTime? lastTriggered;
  final int triggerCount;

  const NotificationSchedule({
    required this.id,
    required this.notificationTemplateId,
    required this.triggerType,
    this.scheduledTime,
    this.recurrenceRule,
    this.conditions,
    this.enabled = true,
    required this.createdAt,
    this.lastTriggered,
    this.triggerCount = 0,
  });

  factory NotificationSchedule.fromJson(Map<String, dynamic> json) =>
      _$NotificationScheduleFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationScheduleToJson(this);

  bool shouldTrigger(DateTime now, Map<String, dynamic>? context) {
    if (!enabled) return false;
    
    // Check if conditions are met
    if (conditions != null && context != null) {
      // Implement condition checking logic
      for (final condition in conditions!.entries) {
        if (!_evaluateCondition(condition.key, condition.value, context)) {
          return false;
        }
      }
    }
    
    // Check trigger type specific logic
    switch (triggerType) {
      case NotificationTrigger.immediate:
        return true;
      case NotificationTrigger.scheduled:
        return scheduledTime != null && now.isAfter(scheduledTime!);
      case NotificationTrigger.recurring:
        if (recurrenceRule == null) return false;
        final nextOccurrence = recurrenceRule!.getNextOccurrence(
          lastTriggered ?? createdAt
        );
        return nextOccurrence != null && now.isAfter(nextOccurrence);
      default:
        return false;
    }
  }

  bool _evaluateCondition(String key, dynamic value, Map<String, dynamic> context) {
    // Simple condition evaluation - can be extended
    return context.containsKey(key) && context[key] == value;
  }
}

/// Batch notification for grouping related notifications
@JsonSerializable()
class NotificationBatch {
  final String id;
  final String title;
  final String summary;
  final List<String> notificationIds;
  final NotificationCategory category;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final bool collapsed;
  final int maxNotifications;

  const NotificationBatch({
    required this.id,
    required this.title,
    required this.summary,
    required this.notificationIds,
    required this.category,
    required this.createdAt,
    this.deliveredAt,
    this.collapsed = true,
    this.maxNotifications = 5,
  });

  factory NotificationBatch.fromJson(Map<String, dynamic> json) =>
      _$NotificationBatchFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationBatchToJson(this);

  bool get isDelivered => deliveredAt != null;
  int get notificationCount => notificationIds.length;
  bool get shouldBatch => notificationCount >= 2;
}

/// User activity context for intelligent scheduling
@JsonSerializable()
class UserActivityContext {
  final DateTime timestamp;
  final bool isAppActive;
  final String? currentScreen;
  final Map<String, int> screenUsage;
  final List<String> recentActions;
  final bool isBusinessHours;
  final bool isWeekend;
  final String timezone;

  const UserActivityContext({
    required this.timestamp,
    required this.isAppActive,
    this.currentScreen,
    this.screenUsage = const {},
    this.recentActions = const [],
    required this.isBusinessHours,
    required this.isWeekend,
    required this.timezone,
  });

  factory UserActivityContext.fromJson(Map<String, dynamic> json) =>
      _$UserActivityContextFromJson(json);

  Map<String, dynamic> toJson() => _$UserActivityContextToJson(this);

  bool get isOptimalTime {
    // Logic to determine if it's a good time to send notifications
    if (!isBusinessHours && !isWeekend) return false;
    if (isAppActive) return true;
    return isBusinessHours;
  }
}

/// Notification analytics and metrics
@JsonSerializable()
class NotificationMetrics {
  final String notificationId;
  final DateTime deliveredAt;
  final DateTime? firstSeenAt;
  final DateTime? openedAt;
  final DateTime? dismissedAt;
  final String? actionTaken;
  final int impressionCount;
  final Duration? timeToOpen;
  final Duration? timeToAction;
  final String? dismissalReason;

  const NotificationMetrics({
    required this.notificationId,
    required this.deliveredAt,
    this.firstSeenAt,
    this.openedAt,
    this.dismissedAt,
    this.actionTaken,
    this.impressionCount = 1,
    this.timeToOpen,
    this.timeToAction,
    this.dismissalReason,
  });

  factory NotificationMetrics.fromJson(Map<String, dynamic> json) =>
      _$NotificationMetricsFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationMetricsToJson(this);

  bool get wasOpened => openedAt != null;
  bool get wasDismissed => dismissedAt != null;
  bool get hadAction => actionTaken != null;
  double get engagementScore {
    double score = 0.0;
    if (wasOpened) score += 0.5;
    if (hadAction) score += 0.5;
    if (wasDismissed) score -= 0.2;
    return score.clamp(0.0, 1.0);
  }
}