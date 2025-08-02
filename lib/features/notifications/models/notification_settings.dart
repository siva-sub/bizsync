import 'package:json_annotation/json_annotation.dart';
import 'notification_types.dart';

part 'notification_settings.g.dart';

/// Time of day for notification scheduling
@JsonSerializable()
class NotificationTimeOfDay {
  final int hour;
  final int minute;

  const NotificationTimeOfDay({
    required this.hour,
    required this.minute,
  });

  factory NotificationTimeOfDay.fromJson(Map<String, dynamic> json) =>
      _$NotificationTimeOfDayFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationTimeOfDayToJson(this);

  factory NotificationTimeOfDay.fromDateTime(DateTime dateTime) {
    return NotificationTimeOfDay(
      hour: dateTime.hour,
      minute: dateTime.minute,
    );
  }

  bool isBefore(NotificationTimeOfDay other) {
    if (hour < other.hour) return true;
    if (hour > other.hour) return false;
    return minute < other.minute;
  }

  bool isAfter(NotificationTimeOfDay other) {
    if (hour > other.hour) return true;
    if (hour < other.hour) return false;
    return minute > other.minute;
  }

  @override
  String toString() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// User preferences for notifications
@JsonSerializable()
class NotificationSettings {
  final bool globalEnabled;
  final Map<NotificationCategory, CategorySettings> categorySettings;
  final DoNotDisturbSettings doNotDisturb;
  final BatchingSettings batching;
  final Map<NotificationChannel, ChannelSettings> channelSettings;
  final IntelligentSettings intelligent;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const NotificationSettings({
    this.globalEnabled = true,
    this.categorySettings = const {},
    this.doNotDisturb = const DoNotDisturbSettings(),
    this.batching = const BatchingSettings(),
    this.channelSettings = const {},
    this.intelligent = const IntelligentSettings(),
    required this.createdAt,
    this.updatedAt,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      _$NotificationSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationSettingsToJson(this);

  factory NotificationSettings.defaultSettings() {
    final now = DateTime.now();
    return NotificationSettings(
      globalEnabled: true,
      categorySettings: {
        for (final category in NotificationCategory.values)
          category: CategorySettings.defaultForCategory(category),
      },
      channelSettings: {
        for (final channel in NotificationChannel.values)
          channel: ChannelSettings.defaultForChannel(channel),
      },
      createdAt: now,
    );
  }

  bool shouldShowNotification(
    NotificationCategory category,
    NotificationPriority priority,
    DateTime now,
  ) {
    if (!globalEnabled) return false;
    
    final categoryConfig = categorySettings[category];
    if (categoryConfig == null || !categoryConfig.enabled) return false;
    
    if (doNotDisturb.isActive(now) && 
        !doNotDisturb.shouldBypass(priority)) return false;
    
    return true;
  }

  NotificationSettings copyWith({
    bool? globalEnabled,
    Map<NotificationCategory, CategorySettings>? categorySettings,
    DoNotDisturbSettings? doNotDisturb,
    BatchingSettings? batching,
    Map<NotificationChannel, ChannelSettings>? channelSettings,
    IntelligentSettings? intelligent,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationSettings(
      globalEnabled: globalEnabled ?? this.globalEnabled,
      categorySettings: categorySettings ?? this.categorySettings,
      doNotDisturb: doNotDisturb ?? this.doNotDisturb,
      batching: batching ?? this.batching,
      channelSettings: channelSettings ?? this.channelSettings,
      intelligent: intelligent ?? this.intelligent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Settings for specific notification categories
@JsonSerializable()
class CategorySettings {
  final bool enabled;
  final NotificationPriority minimumPriority;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool showPreview;
  final int maxPerHour;
  final List<String> keywords;
  final bool smartTiming;

  const CategorySettings({
    this.enabled = true,
    this.minimumPriority = NotificationPriority.info,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.showPreview = true,
    this.maxPerHour = 10,
    this.keywords = const [],
    this.smartTiming = true,
  });

  factory CategorySettings.fromJson(Map<String, dynamic> json) =>
      _$CategorySettingsFromJson(json);

  Map<String, dynamic> toJson() => _$CategorySettingsToJson(this);

  factory CategorySettings.defaultForCategory(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.invoice:
      case NotificationCategory.payment:
      case NotificationCategory.tax:
        return const CategorySettings(
          enabled: true,
          minimumPriority: NotificationPriority.medium,
          maxPerHour: 20,
          smartTiming: true,
        );
      
      case NotificationCategory.backup:
      case NotificationCategory.system:
        return const CategorySettings(
          enabled: true,
          minimumPriority: NotificationPriority.low,
          soundEnabled: false,
          maxPerHour: 5,
        );
      
      case NotificationCategory.insight:
        return const CategorySettings(
          enabled: true,
          minimumPriority: NotificationPriority.info,
          maxPerHour: 3,
          smartTiming: true,
        );
      
      case NotificationCategory.reminder:
        return const CategorySettings(
          enabled: true,
          minimumPriority: NotificationPriority.medium,
          maxPerHour: 15,
        );
      
      case NotificationCategory.custom:
        return const CategorySettings(
          enabled: true,
          minimumPriority: NotificationPriority.medium,
          maxPerHour: 10,
        );
    }
  }
}

/// Do Not Disturb settings
@JsonSerializable()
class DoNotDisturbSettings {
  final bool enabled;
  final NotificationTimeOfDay startTime;
  final NotificationTimeOfDay endTime;
  final List<int> daysOfWeek; // 1=Monday, 7=Sunday
  final List<NotificationPriority> allowedPriorities;
  final List<NotificationCategory> allowedCategories;
  final bool allowRepeatedCalls;
  final Duration repeatedCallWindow;

  const DoNotDisturbSettings({
    this.enabled = false,
    this.startTime = const NotificationTimeOfDay(hour: 22, minute: 0),
    this.endTime = const NotificationTimeOfDay(hour: 8, minute: 0),
    this.daysOfWeek = const [1, 2, 3, 4, 5, 6, 7],
    this.allowedPriorities = const [NotificationPriority.critical],
    this.allowedCategories = const [],
    this.allowRepeatedCalls = true,
    this.repeatedCallWindow = const Duration(minutes: 15),
  });

  factory DoNotDisturbSettings.fromJson(Map<String, dynamic> json) =>
      _$DoNotDisturbSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$DoNotDisturbSettingsToJson(this);

  bool isActive(DateTime now) {
    if (!enabled) return false;
    
    final weekday = now.weekday;
    if (!daysOfWeek.contains(weekday)) return false;
    
    final currentTime = NotificationTimeOfDay.fromDateTime(now);
    
    if (startTime.hour < endTime.hour) {
      // Same day range (e.g., 10 PM to 8 AM next day)
      return currentTime.isAfter(startTime) || currentTime.isBefore(endTime);
    } else {
      // Cross-day range (e.g., 8 PM to 6 AM)
      return currentTime.isAfter(startTime) && currentTime.isBefore(endTime);
    }
  }

  bool shouldBypass(NotificationPriority priority) {
    return allowedPriorities.contains(priority);
  }

  bool shouldBypassCategory(NotificationCategory category) {
    return allowedCategories.contains(category);
  }
}


/// Notification batching settings
@JsonSerializable()
class BatchingSettings {
  final bool enabled;
  final Duration batchWindow;
  final int maxBatchSize;
  final Map<NotificationCategory, int> categoryThresholds;
  final bool intelligentBatching;
  final List<NotificationCategory> neverBatchCategories;

  const BatchingSettings({
    this.enabled = true,
    this.batchWindow = const Duration(minutes: 15),
    this.maxBatchSize = 5,
    this.categoryThresholds = const {},
    this.intelligentBatching = true,
    this.neverBatchCategories = const [NotificationCategory.system],
  });

  factory BatchingSettings.fromJson(Map<String, dynamic> json) =>
      _$BatchingSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$BatchingSettingsToJson(this);

  bool shouldBatch(NotificationCategory category, int pendingCount) {
    if (!enabled) return false;
    if (neverBatchCategories.contains(category)) return false;
    
    final threshold = categoryThresholds[category] ?? 2;
    return pendingCount >= threshold;
  }
}

/// Channel-specific settings
@JsonSerializable()
class ChannelSettings {
  final bool enabled;
  final NotificationPriority minimumPriority;
  final bool soundEnabled;
  final String? customSoundUri;
  final bool vibrationEnabled;
  final List<int>? customVibrationPattern;
  final bool lightEnabled;
  final int? lightColor;
  final bool showBadge;
  final bool bypassDnd;

  const ChannelSettings({
    this.enabled = true,
    this.minimumPriority = NotificationPriority.info,
    this.soundEnabled = true,
    this.customSoundUri,
    this.vibrationEnabled = true,
    this.customVibrationPattern,
    this.lightEnabled = true,
    this.lightColor,
    this.showBadge = true,
    this.bypassDnd = false,
  });

  factory ChannelSettings.fromJson(Map<String, dynamic> json) =>
      _$ChannelSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$ChannelSettingsToJson(this);

  factory ChannelSettings.defaultForChannel(NotificationChannel channel) {
    switch (channel) {
      case NotificationChannel.urgent:
        return const ChannelSettings(
          enabled: true,
          minimumPriority: NotificationPriority.critical,
          bypassDnd: true,
          lightColor: 0xFFFF0000, // Red
        );
      
      case NotificationChannel.business:
        return const ChannelSettings(
          enabled: true,
          minimumPriority: NotificationPriority.medium,
          lightColor: 0xFF0000FF, // Blue
        );
      
      case NotificationChannel.reminders:
        return const ChannelSettings(
          enabled: true,
          minimumPriority: NotificationPriority.medium,
          lightColor: 0xFF00FF00, // Green
        );
      
      case NotificationChannel.insights:
        return const ChannelSettings(
          enabled: true,
          minimumPriority: NotificationPriority.low,
          soundEnabled: false,
          lightColor: 0xFFFFFF00, // Yellow
        );
      
      case NotificationChannel.system:
        return const ChannelSettings(
          enabled: true,
          minimumPriority: NotificationPriority.low,
          soundEnabled: false,
          vibrationEnabled: false,
        );
      
      case NotificationChannel.marketing:
        return const ChannelSettings(
          enabled: false,
          minimumPriority: NotificationPriority.info,
          soundEnabled: false,
        );
    }
  }
}

/// Intelligent notification settings
@JsonSerializable()
class IntelligentSettings {
  final bool enabled;
  final bool adaptToUserBehavior;
  final bool considerAppUsage;
  final bool respectBusinessHours;
  final NotificationTimeOfDay businessHoursStart;
  final NotificationTimeOfDay businessHoursEnd;
  final bool weekendsAreBusinessDays;
  final Duration optimalDelay;
  final bool learnFromDismissals;
  final double engagementThreshold;

  const IntelligentSettings({
    this.enabled = true,
    this.adaptToUserBehavior = true,
    this.considerAppUsage = true,
    this.respectBusinessHours = true,
    this.businessHoursStart = const NotificationTimeOfDay(hour: 9, minute: 0),
    this.businessHoursEnd = const NotificationTimeOfDay(hour: 17, minute: 0),
    this.weekendsAreBusinessDays = false,
    this.optimalDelay = const Duration(minutes: 5),
    this.learnFromDismissals = true,
    this.engagementThreshold = 0.3,
  });

  factory IntelligentSettings.fromJson(Map<String, dynamic> json) =>
      _$IntelligentSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$IntelligentSettingsToJson(this);

  bool isBusinessHours(DateTime dateTime) {
    if (!respectBusinessHours) return true;
    
    final isWeekend = dateTime.weekday == DateTime.saturday || 
                     dateTime.weekday == DateTime.sunday;
    
    if (isWeekend && !weekendsAreBusinessDays) return false;
    
    final currentTime = NotificationTimeOfDay.fromDateTime(dateTime);
    return currentTime.isAfter(businessHoursStart) && 
           currentTime.isBefore(businessHoursEnd);
  }

  DateTime? getOptimalDeliveryTime(DateTime requestedTime) {
    if (!enabled) return requestedTime;
    
    if (isBusinessHours(requestedTime)) {
      return requestedTime.add(optimalDelay);
    }
    
    // Schedule for next business day
    DateTime nextBusinessDay = requestedTime;
    while (!isBusinessHours(nextBusinessDay)) {
      nextBusinessDay = nextBusinessDay.add(const Duration(hours: 1));
    }
    
    return DateTime(
      nextBusinessDay.year,
      nextBusinessDay.month,
      nextBusinessDay.day,
      businessHoursStart.hour,
      businessHoursStart.minute,
    );
  }
}