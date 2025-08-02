import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/notification_models.dart';
import '../models/notification_types.dart';
import '../providers/notification_providers.dart';
import '../utils/notification_utils.dart';

/// Notification history and analytics screen
class NotificationHistoryScreen extends ConsumerStatefulWidget {
  const NotificationHistoryScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<NotificationHistoryScreen> createState() => 
      _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState 
    extends ConsumerState<NotificationHistoryScreen>
    with SingleTickerProviderStateMixin {
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification History'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.history), text: 'History'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
            Tab(icon: Icon(Icons.trending_up), text: 'Insights'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHistoryTab(),
          _buildAnalyticsTab(),
          _buildInsightsTab(),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Consumer(
      builder: (context, ref, child) {
        final notifications = ref.watch(activeNotificationsProvider);
        final sortedNotifications = [...notifications]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return Column(
          children: [
            // Summary cards
            _buildHistorySummary(notifications),
            
            // Filters
            _buildHistoryFilters(),
            
            // History list
            Expanded(
              child: ListView.builder(
                itemCount: sortedNotifications.length,
                itemBuilder: (context, index) {
                  final notification = sortedNotifications[index];
                  return _buildHistoryItem(notification);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHistorySummary(List<BizSyncNotification> notifications) {
    final today = DateTime.now();
    final todayNotifications = notifications.where((n) =>
        n.createdAt.day == today.day &&
        n.createdAt.month == today.month &&
        n.createdAt.year == today.year).length;
    
    final thisWeekNotifications = notifications.where((n) =>
        today.difference(n.createdAt).inDays < 7).length;
    
    final readNotifications = notifications.where((n) => n.isRead).length;
    final readRate = notifications.isEmpty ? 0.0 : readNotifications / notifications.length;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Today',
              todayNotifications.toString(),
              Icons.today,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSummaryCard(
              'This Week',
              thisWeekNotifications.toString(),
              Icons.date_range,
              Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSummaryCard(
              'Read Rate',
              '${(readRate * 100).toStringAsFixed(0)}%',
              Icons.visibility,
              Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search notifications...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (query) {
                ref.read(notificationSearchProvider.notifier).search(query);
              },
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) => _applyFilter(value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(value: 'unread', child: Text('Unread')),
              const PopupMenuItem(value: 'today', child: Text('Today')),
              const PopupMenuItem(value: 'week', child: Text('This Week')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(BizSyncNotification notification) {
    final formatted = NotificationUtils.formatNotificationForDisplay(notification);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(int.parse('0xFF${formatted.priorityColor.substring(1)}')),
          child: Icon(
            _getCategoryIcon(notification.category),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  formatted.formattedTime,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.category,
                  size: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  notification.category.displayName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            if (notification.hasActions)
              Icon(
                Icons.touch_app,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          ],
        ),
        onTap: () => Navigator.of(context).pushNamed(
          '/notifications/detail',
          arguments: notification.id,
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return Consumer(
      builder: (context, ref, child) {
        final notifications = ref.watch(activeNotificationsProvider);
        final metrics = ref.watch(notificationMetricsProvider);
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overview cards
              _buildAnalyticsOverview(notifications, metrics),
              
              const SizedBox(height: 24),
              
              // Category distribution chart
              _buildCategoryDistributionChart(notifications),
              
              const SizedBox(height: 24),
              
              // Priority distribution chart
              _buildPriorityDistributionChart(notifications),
              
              const SizedBox(height: 24),
              
              // Engagement metrics
              _buildEngagementMetrics(metrics),
              
              const SizedBox(height: 24),
              
              // Weekly activity chart
              _buildWeeklyActivityChart(notifications),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsOverview(
    List<BizSyncNotification> notifications,
    List<NotificationMetrics> metrics,
  ) {
    final totalNotifications = notifications.length;
    final openedCount = metrics.where((m) => m.wasOpened).length;
    final actionCount = metrics.where((m) => m.hadAction).length;
    final dismissedCount = metrics.where((m) => m.wasDismissed).length;
    
    final openRate = totalNotifications > 0 ? (openedCount / totalNotifications) * 100 : 0.0;
    final actionRate = totalNotifications > 0 ? (actionCount / totalNotifications) * 100 : 0.0;
    final dismissalRate = totalNotifications > 0 ? (dismissedCount / totalNotifications) * 100 : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analytics Overview',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total',
                totalNotifications.toString(),
                Icons.notifications,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricCard(
                'Open Rate',
                '${openRate.toStringAsFixed(1)}%',
                Icons.visibility,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Action Rate',
                '${actionRate.toStringAsFixed(1)}%',
                Icons.touch_app,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricCard(
                'Dismissal Rate',
                '${dismissalRate.toStringAsFixed(1)}%',
                Icons.close,
                Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDistributionChart(List<BizSyncNotification> notifications) {
    final categoryData = <NotificationCategory, int>{};
    
    for (final notification in notifications) {
      categoryData[notification.category] = 
          (categoryData[notification.category] ?? 0) + 1;
    }

    final sections = categoryData.entries.map((entry) {
      final percentage = (entry.value / notifications.length) * 100;
      return PieChartSectionData(
        color: _getCategoryColor(entry.key),
        value: entry.value.toDouble(),
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category Distribution',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        sections: sections,
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: categoryData.entries.map((entry) =>
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                color: _getCategoryColor(entry.key),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  entry.key.displayName,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              Text(
                                entry.value.toString(),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityDistributionChart(List<BizSyncNotification> notifications) {
    final priorityData = <NotificationPriority, int>{};
    
    for (final notification in notifications) {
      priorityData[notification.priority] = 
          (priorityData[notification.priority] ?? 0) + 1;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Priority Distribution',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: priorityData.entries.map((entry) {
                    final index = NotificationPriority.values.indexOf(entry.key);
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.toDouble(),
                          color: _getPriorityColor(entry.key),
                          width: 20,
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < NotificationPriority.values.length) {
                            final priority = NotificationPriority.values[value.toInt()];
                            return Text(
                              priority.name.toUpperCase(),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementMetrics(List<NotificationMetrics> metrics) {
    if (metrics.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No engagement data available'),
        ),
      );
    }

    final summary = NotificationUtils.generateAnalyticsSummary(metrics);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Engagement Metrics',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${(summary.averageEngagement * 100).toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('Avg Engagement'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${summary.averageTimeToOpen.inMinutes}m',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('Avg Open Time'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyActivityChart(List<BizSyncNotification> notifications) {
    final weekData = <int, int>{};
    final now = DateTime.now();
    
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayKey = date.weekday;
      weekData[dayKey] = notifications.where((n) =>
          n.createdAt.day == date.day &&
          n.createdAt.month == date.month &&
          n.createdAt.year == date.year).length;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Activity',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                          if (value.toInt() > 0 && value.toInt() <= 7) {
                            return Text(
                              days[value.toInt() - 1],
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: weekData.entries.map((entry) =>
                          FlSpot(entry.key.toDouble(), entry.value.toDouble())).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsTab() {
    return Consumer(
      builder: (context, ref, child) {
        final notifications = ref.watch(activeNotificationsProvider);
        final metrics = ref.watch(notificationMetricsProvider);
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notification Insights',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              
              // Performance insights
              _buildPerformanceInsights(notifications, metrics),
              
              const SizedBox(height: 16),
              
              // Usage patterns
              _buildUsagePatterns(notifications),
              
              const SizedBox(height: 16),
              
              // Recommendations
              _buildRecommendations(notifications, metrics),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPerformanceInsights(
    List<BizSyncNotification> notifications,
    List<NotificationMetrics> metrics,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Insights',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildInsightItem(
              'Most Active Category',
              _getMostActiveCategory(notifications),
              Icons.trending_up,
              Colors.blue,
            ),
            _buildInsightItem(
              'Peak Hour',
              _getPeakHour(notifications),
              Icons.schedule,
              Colors.orange,
            ),
            _buildInsightItem(
              'Engagement Trend',
              _getEngagementTrend(metrics),
              Icons.analytics,
              Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsagePatterns(List<BizSyncNotification> notifications) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Usage Patterns',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildInsightItem(
              'Daily Average',
              '${(notifications.length / 7).toStringAsFixed(1)} notifications',
              Icons.today,
              Colors.purple,
            ),
            _buildInsightItem(
              'Most Common Priority',
              _getMostCommonPriority(notifications),
              Icons.priority_high,
              Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendations(
    List<BizSyncNotification> notifications,
    List<NotificationMetrics> metrics,
  ) {
    final recommendations = _generateRecommendations(notifications, metrics);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recommendations',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ...recommendations.map((recommendation) =>
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        recommendation,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightItem(String title, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _applyFilter(String filter) {
    // Implementation for applying filters
    final notifier = ref.read(notificationSearchProvider.notifier);
    
    switch (filter) {
      case 'unread':
        // Filter to show only unread notifications
        break;
      case 'today':
        // Filter to show only today's notifications
        break;
      case 'week':
        // Filter to show only this week's notifications
        break;
      default:
        notifier.clearFilters();
        break;
    }
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

  Color _getCategoryColor(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.invoice:
        return Colors.blue;
      case NotificationCategory.payment:
        return Colors.green;
      case NotificationCategory.tax:
        return Colors.orange;
      case NotificationCategory.backup:
        return Colors.purple;
      case NotificationCategory.insight:
        return Colors.amber;
      case NotificationCategory.reminder:
        return Colors.cyan;
      case NotificationCategory.system:
        return Colors.grey;
      case NotificationCategory.custom:
        return Colors.brown;
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

  String _getMostActiveCategory(List<BizSyncNotification> notifications) {
    if (notifications.isEmpty) return 'None';
    
    final categoryCount = <NotificationCategory, int>{};
    for (final notification in notifications) {
      categoryCount[notification.category] = 
          (categoryCount[notification.category] ?? 0) + 1;
    }
    
    final mostActive = categoryCount.entries
        .reduce((a, b) => a.value > b.value ? a : b);
    
    return mostActive.key.displayName;
  }

  String _getPeakHour(List<BizSyncNotification> notifications) {
    if (notifications.isEmpty) return 'N/A';
    
    final hourCount = <int, int>{};
    for (final notification in notifications) {
      final hour = notification.createdAt.hour;
      hourCount[hour] = (hourCount[hour] ?? 0) + 1;
    }
    
    final peakHour = hourCount.entries
        .reduce((a, b) => a.value > b.value ? a : b);
    
    return '${peakHour.key}:00';
  }

  String _getEngagementTrend(List<NotificationMetrics> metrics) {
    if (metrics.isEmpty) return 'N/A';
    
    final avgEngagement = metrics
        .map((m) => m.engagementScore)
        .reduce((a, b) => a + b) / metrics.length;
    
    if (avgEngagement > 0.7) return 'High';
    if (avgEngagement > 0.4) return 'Medium';
    return 'Low';
  }

  String _getMostCommonPriority(List<BizSyncNotification> notifications) {
    if (notifications.isEmpty) return 'None';
    
    final priorityCount = <NotificationPriority, int>{};
    for (final notification in notifications) {
      priorityCount[notification.priority] = 
          (priorityCount[notification.priority] ?? 0) + 1;
    }
    
    final mostCommon = priorityCount.entries
        .reduce((a, b) => a.value > b.value ? a : b);
    
    return mostCommon.key.name.toUpperCase();
  }

  List<String> _generateRecommendations(
    List<BizSyncNotification> notifications,
    List<NotificationMetrics> metrics,
  ) {
    final recommendations = <String>[];
    
    if (notifications.isEmpty) {
      recommendations.add('No notifications yet. Set up your first notification to get started!');
      return recommendations;
    }
    
    // Analyze engagement
    if (metrics.isNotEmpty) {
      final avgEngagement = metrics
          .map((m) => m.engagementScore)
          .reduce((a, b) => a + b) / metrics.length;
      
      if (avgEngagement < 0.3) {
        recommendations.add('Consider reviewing notification content to improve engagement.');
      }
    }
    
    // Analyze timing
    final hourCount = <int, int>{};
    for (final notification in notifications) {
      final hour = notification.createdAt.hour;
      hourCount[hour] = (hourCount[hour] ?? 0) + 1;
    }
    
    if (hourCount.isNotEmpty) {
      final peakHour = hourCount.entries
          .reduce((a, b) => a.value > b.value ? a : b);
      
      if (peakHour.key < 9 || peakHour.key > 17) {
        recommendations.add('Most notifications are sent outside business hours. Consider adjusting timing.');
      }
    }
    
    // Analyze frequency
    final dailyAverage = notifications.length / 7;
    if (dailyAverage > 20) {
      recommendations.add('You receive many notifications daily. Consider enabling batching to reduce interruptions.');
    }
    
    if (recommendations.isEmpty) {
      recommendations.add('Your notification system is performing well! Keep up the good work.');
    }
    
    return recommendations;
  }
}