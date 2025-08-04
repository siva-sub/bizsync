import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_models.dart';
import '../models/notification_settings.dart';
import '../models/notification_types.dart';
import '../models/notification_template.dart';
import '../services/enhanced_notification_service.dart';
import '../services/business_notification_service.dart';
import '../services/notification_template_service.dart';
import '../services/notification_scheduler.dart';

/// Providers for notification system state management

/// Enhanced notification service provider
final notificationServiceProvider =
    Provider<EnhancedNotificationService>((ref) {
  return EnhancedNotificationService();
});

/// Business notification service provider
final businessNotificationServiceProvider =
    Provider<BusinessNotificationService>((ref) {
  return BusinessNotificationService();
});

/// Template service provider
final notificationTemplateServiceProvider =
    Provider<NotificationTemplateService>((ref) {
  return NotificationTemplateService();
});

/// Scheduler service provider
final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) {
  return NotificationScheduler();
});

/// Notification settings provider
final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings?>(
        (ref) {
  final service = ref.read(notificationServiceProvider);
  return NotificationSettingsNotifier(service);
});

/// Active notifications provider
final activeNotificationsProvider = StateNotifierProvider<
    ActiveNotificationsNotifier, List<BizSyncNotification>>((ref) {
  final service = ref.read(notificationServiceProvider);
  return ActiveNotificationsNotifier(service);
});

/// Notification metrics provider
final notificationMetricsProvider = StateNotifierProvider<
    NotificationMetricsNotifier, List<NotificationMetrics>>((ref) {
  final service = ref.read(notificationServiceProvider);
  return NotificationMetricsNotifier(service);
});

/// Filtered notifications by category provider
final notificationsByCategoryProvider =
    Provider.family<List<BizSyncNotification>, NotificationCategory>(
        (ref, category) {
  final notifications = ref.watch(activeNotificationsProvider);
  return notifications.where((n) => n.category == category).toList();
});

/// Unread notifications count provider
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(activeNotificationsProvider);
  return notifications.where((n) => !n.isRead).length;
});

/// Notification settings state notifier
class NotificationSettingsNotifier
    extends StateNotifier<NotificationSettings?> {
  final EnhancedNotificationService _service;

  NotificationSettingsNotifier(this._service) : super(null) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _service.initialize();
    state = _service.settings;
  }

  Future<void> updateSettings(NotificationSettings settings) async {
    await _service.updateSettings(settings);
    state = settings;
  }

  Future<void> updateGlobalEnabled(bool enabled) async {
    if (state == null) return;

    final updatedSettings = state!.copyWith(
      globalEnabled: enabled,
      updatedAt: DateTime.now(),
    );
    await updateSettings(updatedSettings);
  }

  Future<void> updateCategorySettings(
    NotificationCategory category,
    CategorySettings settings,
  ) async {
    if (state == null) return;

    final updatedCategorySettings =
        Map<NotificationCategory, CategorySettings>.from(
            state!.categorySettings);
    updatedCategorySettings[category] = settings;

    final updatedSettings = state!.copyWith(
      categorySettings: updatedCategorySettings,
      updatedAt: DateTime.now(),
    );
    await updateSettings(updatedSettings);
  }

  Future<void> updateDoNotDisturbSettings(
      DoNotDisturbSettings dndSettings) async {
    if (state == null) return;

    final updatedSettings = state!.copyWith(
      doNotDisturb: dndSettings,
      updatedAt: DateTime.now(),
    );
    await updateSettings(updatedSettings);
  }

  Future<void> updateBatchingSettings(BatchingSettings batchingSettings) async {
    if (state == null) return;

    final updatedSettings = state!.copyWith(
      batching: batchingSettings,
      updatedAt: DateTime.now(),
    );
    await updateSettings(updatedSettings);
  }

  Future<void> updateIntelligentSettings(
      IntelligentSettings intelligentSettings) async {
    if (state == null) return;

    final updatedSettings = state!.copyWith(
      intelligent: intelligentSettings,
      updatedAt: DateTime.now(),
    );
    await updateSettings(updatedSettings);
  }
}

/// Active notifications state notifier
class ActiveNotificationsNotifier
    extends StateNotifier<List<BizSyncNotification>> {
  final EnhancedNotificationService _service;

  ActiveNotificationsNotifier(this._service) : super([]) {
    _initialize();
  }

  Future<void> _initialize() async {
    await _service.initialize();
    _loadNotifications();

    // Listen to notification stream
    _service.notificationStream.listen((notification) {
      _updateNotification(notification);
    });
  }

  void _loadNotifications() {
    state = _service.getActiveNotifications();
  }

  void _updateNotification(BizSyncNotification notification) {
    final notifications = List<BizSyncNotification>.from(state);
    final index = notifications.indexWhere((n) => n.id == notification.id);

    if (index != -1) {
      notifications[index] = notification;
    } else {
      notifications.insert(0, notification);
    }

    state = notifications;
  }

  Future<void> markAsRead(String notificationId) async {
    final notifications = List<BizSyncNotification>.from(state);
    final index = notifications.indexWhere((n) => n.id == notificationId);

    if (index != -1) {
      final notification = notifications[index];
      final updatedNotification = notification.copyWith(
        readAt: DateTime.now(),
        status: NotificationStatus.opened,
      );
      notifications[index] = updatedNotification;
      state = notifications;
    }
  }

  Future<void> dismissNotification(String notificationId) async {
    await _service.cancelNotification(notificationId);
    state = state.where((n) => n.id != notificationId).toList();
  }

  Future<void> clearAll() async {
    await _service.cancelAllNotifications();
    state = [];
  }

  void refresh() {
    _loadNotifications();
  }
}

/// Notification metrics state notifier
class NotificationMetricsNotifier
    extends StateNotifier<List<NotificationMetrics>> {
  final EnhancedNotificationService _service;

  NotificationMetricsNotifier(this._service) : super([]) {
    _initialize();
  }

  Future<void> _initialize() async {
    await _service.initialize();
    state = _service.getMetrics();

    // Listen to metrics stream
    _service.metricsStream.listen((metric) {
      state = [...state, metric];
    });
  }

  List<NotificationMetrics> getMetricsByCategory(
      NotificationCategory category) {
    // This would need category information from the notification
    // For now, return all metrics
    return state;
  }

  double getAverageEngagementScore() {
    if (state.isEmpty) return 0.0;

    final scores = state.map((m) => m.engagementScore).toList();
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  double getOpenRate() {
    if (state.isEmpty) return 0.0;

    final openedCount = state.where((m) => m.wasOpened).length;
    return openedCount / state.length;
  }

  void clearMetrics() {
    state = [];
  }
}

/// Notification templates provider
final notificationTemplatesProvider =
    FutureProvider<List<NotificationTemplate>>((ref) async {
  final service = ref.read(notificationTemplateServiceProvider);
  await service.initialize();
  return service.getAllTemplates();
});

/// Templates by category provider
final templatesByCategoryProvider = Provider.family<
    AsyncValue<List<NotificationTemplate>>, NotificationCategory>(
  (ref, category) {
    return ref.watch(notificationTemplatesProvider).when(
          data: (templates) => AsyncValue.data(
            templates.where((t) => t.category == category).toList(),
          ),
          loading: () => const AsyncValue.loading(),
          error: (error, stack) => AsyncValue.error(error, stack),
        );
  },
);

/// Popular templates provider
final popularTemplatesProvider =
    FutureProvider<List<NotificationTemplate>>((ref) async {
  final service = ref.read(notificationTemplateServiceProvider);
  return await service.getPopularTemplates(limit: 5);
});

/// Scheduled notifications count provider
final scheduledNotificationsCountProvider = FutureProvider<int>((ref) async {
  final scheduler = ref.read(notificationSchedulerProvider);
  return await scheduler.getScheduledNotificationsCount();
});

/// Category notification counts provider
final categoryNotificationCountsProvider =
    Provider<Map<NotificationCategory, int>>((ref) {
  final notifications = ref.watch(activeNotificationsProvider);
  final counts = <NotificationCategory, int>{};

  for (final category in NotificationCategory.values) {
    counts[category] =
        notifications.where((n) => n.category == category).length;
  }

  return counts;
});

/// Priority notification counts provider
final priorityNotificationCountsProvider =
    Provider<Map<NotificationPriority, int>>((ref) {
  final notifications = ref.watch(activeNotificationsProvider);
  final counts = <NotificationPriority, int>{};

  for (final priority in NotificationPriority.values) {
    counts[priority] =
        notifications.where((n) => n.priority == priority).length;
  }

  return counts;
});

/// Recent notifications provider (last 24 hours)
final recentNotificationsProvider = Provider<List<BizSyncNotification>>((ref) {
  final notifications = ref.watch(activeNotificationsProvider);
  final yesterday = DateTime.now().subtract(const Duration(days: 1));

  return notifications.where((n) => n.createdAt.isAfter(yesterday)).toList();
});

/// Critical notifications provider
final criticalNotificationsProvider =
    Provider<List<BizSyncNotification>>((ref) {
  final notifications = ref.watch(activeNotificationsProvider);
  return notifications
      .where((n) => n.priority == NotificationPriority.critical)
      .toList();
});

/// Notification search provider
final notificationSearchProvider =
    StateNotifierProvider<NotificationSearchNotifier, NotificationSearchState>(
        (ref) {
  final notifications = ref.read(activeNotificationsProvider.notifier);
  return NotificationSearchNotifier(notifications);
});

/// Notification search state
class NotificationSearchState {
  final String query;
  final List<BizSyncNotification> results;
  final List<NotificationCategory> categoryFilters;
  final List<NotificationPriority> priorityFilters;
  final bool isLoading;

  const NotificationSearchState({
    this.query = '',
    this.results = const [],
    this.categoryFilters = const [],
    this.priorityFilters = const [],
    this.isLoading = false,
  });

  NotificationSearchState copyWith({
    String? query,
    List<BizSyncNotification>? results,
    List<NotificationCategory>? categoryFilters,
    List<NotificationPriority>? priorityFilters,
    bool? isLoading,
  }) {
    return NotificationSearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      categoryFilters: categoryFilters ?? this.categoryFilters,
      priorityFilters: priorityFilters ?? this.priorityFilters,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Notification search notifier
class NotificationSearchNotifier
    extends StateNotifier<NotificationSearchState> {
  final ActiveNotificationsNotifier _notificationsNotifier;

  NotificationSearchNotifier(this._notificationsNotifier)
      : super(const NotificationSearchState());

  void search(String query) {
    state = state.copyWith(query: query, isLoading: true);

    final notifications = _notificationsNotifier.state;
    List<BizSyncNotification> results = [];

    if (query.isNotEmpty) {
      final lowercaseQuery = query.toLowerCase();
      results = notifications.where((notification) {
        final titleMatch =
            notification.title.toLowerCase().contains(lowercaseQuery);
        final bodyMatch =
            notification.body.toLowerCase().contains(lowercaseQuery);
        return titleMatch || bodyMatch;
      }).toList();
    } else {
      results = notifications;
    }

    // Apply category filters
    if (state.categoryFilters.isNotEmpty) {
      results = results
          .where((n) => state.categoryFilters.contains(n.category))
          .toList();
    }

    // Apply priority filters
    if (state.priorityFilters.isNotEmpty) {
      results = results
          .where((n) => state.priorityFilters.contains(n.priority))
          .toList();
    }

    state = state.copyWith(results: results, isLoading: false);
  }

  void addCategoryFilter(NotificationCategory category) {
    if (!state.categoryFilters.contains(category)) {
      final filters = [...state.categoryFilters, category];
      state = state.copyWith(categoryFilters: filters);
      search(state.query);
    }
  }

  void removeCategoryFilter(NotificationCategory category) {
    final filters = state.categoryFilters.where((c) => c != category).toList();
    state = state.copyWith(categoryFilters: filters);
    search(state.query);
  }

  void addPriorityFilter(NotificationPriority priority) {
    if (!state.priorityFilters.contains(priority)) {
      final filters = [...state.priorityFilters, priority];
      state = state.copyWith(priorityFilters: filters);
      search(state.query);
    }
  }

  void removePriorityFilter(NotificationPriority priority) {
    final filters = state.priorityFilters.where((p) => p != priority).toList();
    state = state.copyWith(priorityFilters: filters);
    search(state.query);
  }

  void clearFilters() {
    state = state.copyWith(
      categoryFilters: [],
      priorityFilters: [],
    );
    search(state.query);
  }

  void clearSearch() {
    state = const NotificationSearchState();
  }
}
