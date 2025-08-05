import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../providers/dashboard_providers.dart';
import '../models/dashboard_models.dart';
import '../widgets/chart_widgets.dart';
import 'dashboard_widgets.dart';
import '../../invoices/models/invoice_models.dart';

class MainDashboardScreen extends ConsumerStatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  ConsumerState<MainDashboardScreen> createState() =>
      _MainDashboardScreenState();
}

class _MainDashboardScreenState extends ConsumerState<MainDashboardScreen>
    with DashboardWidgetsMixin {
  TimePeriod _selectedPeriod = TimePeriod.thisMonth;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    // Load dashboard data on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshDashboard();
    });
  }

  Future<void> _refreshDashboard() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await ref
          .read(dashboardDataProvider.notifier)
          .loadDashboardData(_selectedPeriod);
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardData = ref.watch(dashboardDataProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Dashboard'),
        backgroundColor: theme.colorScheme.inversePrimary,
        elevation: 0,
        actions: [
          // Period selector
          PopupMenuButton<TimePeriod>(
            icon: const Icon(Icons.date_range),
            initialValue: _selectedPeriod,
            onSelected: (period) {
              setState(() {
                _selectedPeriod = period;
              });
              _refreshDashboard();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: TimePeriod.today,
                child: Text('Today'),
              ),
              const PopupMenuItem(
                value: TimePeriod.thisWeek,
                child: Text('This Week'),
              ),
              const PopupMenuItem(
                value: TimePeriod.thisMonth,
                child: Text('This Month'),
              ),
              const PopupMenuItem(
                value: TimePeriod.thisYear,
                child: Text('This Year'),
              ),
            ],
          ),
          // Refresh button
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshDashboard,
          ),
        ],
      ),
      body: dashboardData.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading dashboard data...'),
            ],
          ),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 64, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Failed to load dashboard',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _refreshDashboard,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: _refreshDashboard,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Actions Row
                buildQuickActions(context),
                const SizedBox(height: 24),

                // KPI Cards
                buildKPISection(context, data.kpis, theme),
                const SizedBox(height: 24),

                // Revenue Chart
                if (data.revenueAnalytics != null)
                  buildRevenueChart(context, data.revenueAnalytics!, theme),
                const SizedBox(height: 24),

                // Charts Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cash Flow Chart
                    if (data.cashFlowData != null)
                      Expanded(
                        flex: 2,
                        child: buildCashFlowChart(
                            context, data.cashFlowData!, theme),
                      ),
                    const SizedBox(width: 16),

                    // Invoice Status Pie Chart
                    Expanded(
                      child: buildInvoiceStatusChart(context, data, theme),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Customer Growth and Activity Feed Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer Growth Chart
                    if (data.customerInsights != null)
                      Expanded(
                        child: buildCustomerGrowthChart(
                            context, data.customerInsights!, theme),
                      ),
                    const SizedBox(width: 16),

                    // Activity Feed
                    Expanded(
                      child: buildActivityFeed(theme),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Top Customers
                if (data.revenueAnalytics != null)
                  buildTopCustomers(context, data.revenueAnalytics!, theme),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
