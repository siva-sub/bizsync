import 'dart:async';
import 'dart:math' as math;
import '../../../core/database/crdt_database_service.dart';
import '../../../core/crdt/hybrid_logical_clock.dart';
import '../../invoices/services/invoice_service.dart';
import '../../invoices/models/enhanced_invoice_model.dart';
import '../../invoices/models/invoice_models.dart';
import '../../../data/models/customer.dart';
import '../../../data/repositories/customer_repository.dart';
import '../models/dashboard_models.dart';

/// Real dashboard analytics service that pulls actual data from the database
class RealDashboardAnalyticsService {
  static const String _analyticsNodeId = 'real-analytics-service';
  
  final CRDTDatabaseService _databaseService;
  final InvoiceService _invoiceService;
  final CustomerRepository _customerRepository = CustomerRepository();

  RealDashboardAnalyticsService(
    this._databaseService,
    this._invoiceService,
  );

  /// Get comprehensive dashboard data with real metrics
  Future<DashboardData> getDashboardData({
    TimePeriod period = TimePeriod.thisMonth,
    DateTime? customStartDate,
    DateTime? customEndDate,
  }) async {
    final now = DateTime.now();
    final dateRange = _getDateRange(period, customStartDate, customEndDate);
    
    // Get all data in parallel for better performance
    final results = await Future.wait([
      _calculateRevenueMetrics(dateRange),
      _calculateCashFlowMetrics(dateRange),
      _calculateCustomerMetrics(dateRange),
      _calculateInvoiceMetrics(dateRange),
    ]);

    final revenueData = results[0] as Map<String, dynamic>;
    final cashFlowData = results[1] as Map<String, dynamic>;
    final customerData = results[2] as Map<String, dynamic>;
    final invoiceData = results[3] as Map<String, dynamic>;

    // Build KPIs
    final kpis = _buildKPIs(revenueData, cashFlowData, customerData, invoiceData);

    // Build revenue analytics
    final revenueAnalytics = _buildRevenueAnalytics(revenueData, period, dateRange);

    // Build cash flow data
    final cashFlow = _buildCashFlowData(cashFlowData, period, dateRange);

    // Build customer insights
    final customerInsights = _buildCustomerInsights(customerData, period, dateRange);

    return DashboardData(
      id: 'dashboard_${DateTime.now().millisecondsSinceEpoch}',
      kpis: kpis,
      revenueAnalytics: revenueAnalytics,
      cashFlowData: cashFlow,
      customerInsights: customerInsights,
      inventoryOverview: null, // TODO: Implement when inventory module is ready
      taxComplianceStatus: null, // TODO: Implement when tax module is ready
      anomalies: [], // TODO: Implement anomaly detection
      currentPeriod: period,
      lastUpdated: now,
      config: _getDefaultDashboardConfig(),
    );
  }

  /// Calculate revenue metrics from invoice data
  Future<Map<String, dynamic>> _calculateRevenueMetrics(DateRange dateRange) async {
    try {
      // Get all paid invoices in the date range
      final paidInvoices = await _getInvoicesInRange(
        dateRange, 
        statuses: [InvoiceStatus.paid, InvoiceStatus.partiallyPaid]
      );

      // Get previous period for comparison
      final previousRange = _getPreviousDateRange(dateRange);
      final previousPaidInvoices = await _getInvoicesInRange(
        previousRange,
        statuses: [InvoiceStatus.paid, InvoiceStatus.partiallyPaid]
      );

      final totalRevenue = paidInvoices.fold<double>(
        0.0, 
        (sum, invoice) => sum + (invoice.totalAmount.value - invoice.remainingBalance)
      );

      final previousRevenue = previousPaidInvoices.fold<double>(
        0.0, 
        (sum, invoice) => sum + (invoice.totalAmount.value - invoice.remainingBalance)
      );

      // Calculate revenue by day
      final revenueByDay = <DataPoint>[];
      final dailyRevenue = <DateTime, double>{};

      for (final invoice in paidInvoices) {
        final paymentDate = invoice.lastPaymentDate.value ?? invoice.issueDate.value;
        final dateKey = DateTime(paymentDate.year, paymentDate.month, paymentDate.day);
        dailyRevenue[dateKey] = (dailyRevenue[dateKey] ?? 0.0) + 
          (invoice.totalAmount.value - invoice.remainingBalance);
      }

      // Fill in missing days with zero
      var currentDate = dateRange.start;
      while (currentDate.isBefore(dateRange.end) || currentDate.isAtSameMomentAs(dateRange.end)) {
        final dateKey = DateTime(currentDate.year, currentDate.month, currentDate.day);
        revenueByDay.add(DataPoint(
          timestamp: dateKey,
          value: dailyRevenue[dateKey] ?? 0.0,
        ));
        currentDate = currentDate.add(const Duration(days: 1));
      }

      // Calculate revenue by customer
      final revenueByCustomer = <String, double>{};
      for (final invoice in paidInvoices) {
        final customerId = invoice.customerId.value ?? 'unknown';
        revenueByCustomer[customerId] = (revenueByCustomer[customerId] ?? 0.0) + 
          (invoice.totalAmount.value - invoice.remainingBalance);
      }

      final revenueByCustomerPoints = revenueByCustomer.entries
          .map((e) => DataPoint(
                timestamp: DateTime.now(),
                value: e.value,
                label: e.key,
              ))
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return {
        'total_revenue': totalRevenue,
        'previous_revenue': previousRevenue,
        'revenue_by_day': revenueByDay,
        'revenue_by_customer': revenueByCustomerPoints.take(10).toList(),
        'average_order_value': paidInvoices.isNotEmpty ? totalRevenue / paidInvoices.length : 0.0,
        'total_transactions': paidInvoices.length,
        'growth_rate': previousRevenue > 0 ? ((totalRevenue - previousRevenue) / previousRevenue) * 100 : 0.0,
      };
    } catch (e) {
      // Return default values on error
      return {
        'total_revenue': 0.0,
        'previous_revenue': 0.0,
        'revenue_by_day': <DataPoint>[],
        'revenue_by_customer': <DataPoint>[],
        'average_order_value': 0.0,
        'total_transactions': 0,
        'growth_rate': 0.0,
      };
    }
  }

  /// Calculate cash flow metrics
  Future<Map<String, dynamic>> _calculateCashFlowMetrics(DateRange dateRange) async {
    try {
      // Get all invoices for cash flow calculation  
      final allInvoices = await _getInvoicesInRange(dateRange);
      
      double totalInflow = 0.0;
      double totalOutflow = 0.0; // For now, we don't have expense data
      final dailyCashFlow = <DateTime, double>{};

      for (final invoice in allInvoices) {
        if (invoice.status.value == InvoiceStatus.paid || 
            invoice.status.value == InvoiceStatus.partiallyPaid) {
          final paymentAmount = invoice.totalAmount.value - invoice.remainingBalance;
          totalInflow += paymentAmount;

          final paymentDate = invoice.lastPaymentDate.value ?? invoice.issueDate.value;
          final dateKey = DateTime(paymentDate.year, paymentDate.month, paymentDate.day);
          dailyCashFlow[dateKey] = (dailyCashFlow[dateKey] ?? 0.0) + paymentAmount;
        }
      }

      // Convert to data points
      final cashFlowPoints = <DataPoint>[];
      var currentDate = dateRange.start;
      double runningBalance = 0.0;

      while (currentDate.isBefore(dateRange.end) || currentDate.isAtSameMomentAs(dateRange.end)) {
        final dateKey = DateTime(currentDate.year, currentDate.month, currentDate.day);
        final dayFlow = dailyCashFlow[dateKey] ?? 0.0;
        runningBalance += dayFlow;
        
        cashFlowPoints.add(DataPoint(
          timestamp: dateKey,
          value: runningBalance,
        ));
        currentDate = currentDate.add(const Duration(days: 1));
      }

      return {
        'total_inflow': totalInflow,
        'total_outflow': totalOutflow,
        'net_cash_flow': totalInflow - totalOutflow,
        'daily_cash_flow': cashFlowPoints,
        'opening_balance': 0.0, // TODO: Get from accounting module
        'closing_balance': totalInflow - totalOutflow,
      };
    } catch (e) {
      return {
        'total_inflow': 0.0,
        'total_outflow': 0.0,
        'net_cash_flow': 0.0,
        'daily_cash_flow': <DataPoint>[],
        'opening_balance': 0.0,
        'closing_balance': 0.0,
      };
    }
  }

  /// Calculate customer metrics
  Future<Map<String, dynamic>> _calculateCustomerMetrics(DateRange dateRange) async {
    try {
      // Get all customers
      final customers = await _customerRepository.getAllCustomers();
      
      // Get customers created in this period
      final newCustomers = customers.where((c) => 
        c.createdAt.isAfter(dateRange.start) && 
        c.createdAt.isBefore(dateRange.end)
      ).toList();

      // Get active customers (those with invoices in period)
      final invoicesInPeriod = await _getInvoicesInRange(dateRange);
      final activeCustomerIds = invoicesInPeriod
          .map((i) => i.customerId.value)
          .where((id) => id != null)
          .toSet();

      // Customer growth over time
      final customerGrowth = <DataPoint>[];
      var currentDate = dateRange.start;
      var cumulativeCustomers = customers.where((c) => c.createdAt.isBefore(dateRange.start)).length;

      while (currentDate.isBefore(dateRange.end) || currentDate.isAtSameMomentAs(dateRange.end)) {
        final customersOnDay = customers.where((c) => 
          c.createdAt.year == currentDate.year &&
          c.createdAt.month == currentDate.month &&
          c.createdAt.day == currentDate.day
        ).length;
        
        cumulativeCustomers += customersOnDay;
        
        customerGrowth.add(DataPoint(
          timestamp: currentDate,
          value: cumulativeCustomers.toDouble(),
        ));
        
        currentDate = currentDate.add(const Duration(days: 1));
      }

      return {
        'total_customers': customers.length,
        'new_customers': newCustomers.length,
        'active_customers': activeCustomerIds.length,
        'previous_active_customers': 0, // Would calculate from previous period in real implementation
        'customer_growth': customerGrowth,
        'all_customers': customers.map((c) => {
          'id': c.id,
          'name': c.name,
          'created_at': c.createdAt,
          'total_spent': 0.0, // Would calculate from invoice data in real implementation
        }).toList(),
      };
    } catch (e) {
      return {
        'total_customers': 0,
        'new_customers': 0,
        'active_customers': 0,
        'previous_active_customers': 0,
        'customer_growth': <DataPoint>[],
        'all_customers': <Map<String, dynamic>>[],
      };
    }
  }

  /// Calculate invoice-specific metrics
  Future<Map<String, dynamic>> _calculateInvoiceMetrics(DateRange dateRange) async {
    try {
      final allInvoices = await _getInvoicesInRange(dateRange);
      
      final pendingInvoices = allInvoices.where((i) => 
        i.status.value == InvoiceStatus.sent || 
        i.status.value == InvoiceStatus.pending ||
        i.status.value == InvoiceStatus.approved
      ).toList();

      final overdueInvoices = allInvoices.where((i) => i.isOverdue).toList();
      
      final outstandingReceivables = pendingInvoices.fold<double>(
        0.0, 
        (sum, invoice) => sum + invoice.remainingBalance
      );

      // Invoice status breakdown
      final statusBreakdown = <String, int>{};
      for (final invoice in allInvoices) {
        final status = invoice.status.value.value;
        statusBreakdown[status] = (statusBreakdown[status] ?? 0) + 1;
      }

      return {
        'total_invoices': allInvoices.length,
        'pending_invoices': pendingInvoices.length,
        'overdue_invoices': overdueInvoices.length,
        'outstanding_receivables': outstandingReceivables,
        'status_breakdown': statusBreakdown,
      };
    } catch (e) {
      return {
        'total_invoices': 0,
        'pending_invoices': 0,
        'overdue_invoices': 0,
        'outstanding_receivables': 0.0,
        'status_breakdown': <String, int>{},
      };
    }
  }

  /// Get invoices in date range with optional status filter
  Future<List<CRDTInvoiceEnhanced>> _getInvoicesInRange(
    DateRange dateRange, {
    List<InvoiceStatus>? statuses,
  }) async {
    try {
      // This is a simplified implementation - in a real app you'd want to use
      // proper database queries with date and status filters
      final searchFilters = InvoiceSearchFilters(
        issueDateFrom: dateRange.start,
        issueDateTo: dateRange.end,
        statuses: statuses,
      );
      
      final result = await _invoiceService.searchInvoices(searchFilters);
      return result.success ? result.data! : [];
    } catch (e) {
      return [];
    }
  }

  /// Build KPI list from calculated metrics
  List<KPI> _buildKPIs(
    Map<String, dynamic> revenueData,
    Map<String, dynamic> cashFlowData,
    Map<String, dynamic> customerData,
    Map<String, dynamic> invoiceData,
  ) {
    final now = DateTime.now();
    
    return [
      // Revenue KPI
      KPI(
        id: 'total_revenue',
        title: 'Total Revenue',
        description: 'Total revenue from paid invoices',
        type: KPIType.revenue,
        currentValue: revenueData['total_revenue'] ?? 0.0,
        previousValue: revenueData['previous_revenue'] ?? 0.0,
        unit: 'SGD',
        prefix: '\$',
        trend: _calculateTrend(
          revenueData['total_revenue'] ?? 0.0,
          revenueData['previous_revenue'] ?? 0.0,
        ),
        percentageChange: revenueData['growth_rate'] ?? 0.0,
        lastUpdated: now,
        historicalData: revenueData['revenue_by_day'] ?? [],
        iconName: 'trending_up',
        color: '#4CAF50',
      ),

      // Cash Flow KPI
      KPI(
        id: 'net_cash_flow',
        title: 'Net Cash Flow',
        description: 'Net cash flow from operations',
        type: KPIType.cashFlow,
        currentValue: cashFlowData['net_cash_flow'] ?? 0.0,
        unit: 'SGD',
        prefix: '\$',
        trend: cashFlowData['net_cash_flow'] >= 0 ? TrendDirection.up : TrendDirection.down,
        percentageChange: 0.0,
        lastUpdated: now,
        historicalData: cashFlowData['daily_cash_flow'] ?? [],
        iconName: 'account_balance',
        color: '#2196F3',
      ),

      // Customers KPI
      KPI(
        id: 'total_customers',
        title: 'Total Customers',
        description: 'Total number of customers',
        type: KPIType.customers,
        currentValue: (customerData['total_customers'] ?? 0).toDouble(),
        unit: 'customers',
        trend: customerData['new_customers'] > 0 ? TrendDirection.up : TrendDirection.stable,
        percentageChange: 0.0,
        lastUpdated: now,
        historicalData: customerData['customer_growth'] ?? [],
        iconName: 'people',
        color: '#FF9800',
      ),

      // Outstanding Receivables KPI
      KPI(
        id: 'outstanding_receivables',
        title: 'Outstanding Receivables',
        description: 'Amount pending from customers',
        type: KPIType.revenue,
        currentValue: invoiceData['outstanding_receivables'] ?? 0.0,
        unit: 'SGD',
        prefix: '\$',
        trend: TrendDirection.stable,
        percentageChange: 0.0,
        lastUpdated: now,
        historicalData: [],
        iconName: 'account_balance_wallet',
        color: '#F44336',
      ),

      // Average Order Value KPI
      KPI(
        id: 'average_order_value',
        title: 'Average Order Value',
        description: 'Average value per invoice',
        type: KPIType.revenue,
        currentValue: revenueData['average_order_value'] ?? 0.0,
        unit: 'SGD',
        prefix: '\$',
        trend: TrendDirection.stable,
        percentageChange: 0.0,
        lastUpdated: now,
        historicalData: [],
        iconName: 'receipt',
        color: '#9C27B0',
      ),

      // Overdue Invoices KPI
      KPI(
        id: 'overdue_invoices',
        title: 'Overdue Invoices',
        description: 'Number of overdue invoices',
        type: KPIType.revenue,
        currentValue: (invoiceData['overdue_invoices'] ?? 0).toDouble(),
        unit: 'invoices',
        trend: invoiceData['overdue_invoices'] > 0 ? TrendDirection.down : TrendDirection.stable,
        percentageChange: 0.0,
        lastUpdated: now,
        historicalData: [],
        iconName: 'warning',
        color: '#FF5722',
      ),
    ];
  }

  /// Build revenue analytics
  RevenueAnalytics _buildRevenueAnalytics(
    Map<String, dynamic> revenueData,
    TimePeriod period,
    DateRange dateRange,
  ) {
    return RevenueAnalytics(
      id: 'revenue_${DateTime.now().millisecondsSinceEpoch}',
      period: period,
      totalRevenue: revenueData['total_revenue'] ?? 0.0,
      recurringRevenue: 0.0, // TODO: Calculate based on subscription data
      oneTimeRevenue: revenueData['total_revenue'] ?? 0.0,
      revenueByDay: revenueData['revenue_by_day'] ?? [],
      revenueByProduct: [], // TODO: Implement when product data is available
      revenueByCustomer: revenueData['revenue_by_customer'] ?? [],
      revenueByCategory: {}, // TODO: Implement when categories are available
      averageOrderValue: revenueData['average_order_value'] ?? 0.0,
      totalTransactions: revenueData['total_transactions'] ?? 0,
      growthRate: revenueData['growth_rate'] ?? 0.0,
      generatedAt: DateTime.now(),
    );
  }

  /// Build cash flow data
  CashFlowData _buildCashFlowData(
    Map<String, dynamic> cashFlowData,
    TimePeriod period,
    DateRange dateRange,
  ) {
    return CashFlowData(
      id: 'cashflow_${DateTime.now().millisecondsSinceEpoch}',
      period: period,
      openingBalance: cashFlowData['opening_balance'] ?? 0.0,
      closingBalance: cashFlowData['closing_balance'] ?? 0.0,
      totalInflow: cashFlowData['total_inflow'] ?? 0.0,
      totalOutflow: cashFlowData['total_outflow'] ?? 0.0,
      netCashFlow: cashFlowData['net_cash_flow'] ?? 0.0,
      dailyCashFlow: cashFlowData['daily_cash_flow'] ?? [],
      inflowByCategory: {'Invoice Payments': cashFlowData['total_inflow'] ?? 0.0},
      outflowByCategory: {}, // TODO: Implement when expense data is available
      forecasts: [], // TODO: Implement cash flow forecasting
      generatedAt: DateTime.now(),
    );
  }

  /// Build customer insights
  CustomerInsights _buildCustomerInsights(
    Map<String, dynamic> customerData,
    TimePeriod period,
    DateRange dateRange,
  ) {
    return CustomerInsights(
      id: 'customers_${DateTime.now().millisecondsSinceEpoch}',
      period: period,
      totalCustomers: customerData['total_customers'] ?? 0,
      newCustomers: customerData['new_customers'] ?? 0,
      activeCustomers: customerData['active_customers'] ?? 0,
      churned: _calculateChurnedCustomers(customerData, dateRange),
      churnRate: _calculateChurnRate(customerData, dateRange),
      acquisitionRate: _calculateAcquisitionRate(customerData, dateRange),
      retentionRate: _calculateRetentionRate(customerData, dateRange),
      averageLifetimeValue: _calculateAverageLifetimeValue(customerData, {}),
      customerGrowth: customerData['customer_growth'] ?? [],
      customersBySegment: _segmentCustomers(customerData['all_customers'] ?? []),
      revenueBySegment: _calculateRevenueBySegment({}, customerData['all_customers'] ?? []),
      behaviorInsights: _generateBehaviorInsights(customerData, {}),
      generatedAt: DateTime.now(),
    );
  }

  /// Get recent business activities for activity feed
  Future<List<Map<String, dynamic>>> getRecentActivities({int limit = 10}) async {
    try {
      final activities = <Map<String, dynamic>>[];
      
      // Get recent invoices
      final recentInvoices = await _getRecentInvoices(limit: 5);
      for (final invoice in recentInvoices) {
        activities.add({
          'type': 'invoice_created',
          'title': 'New Invoice Created',
          'description': 'Invoice ${invoice.invoiceNumber.value} for ${invoice.customerName.value ?? 'Unknown Customer'}',
          'amount': invoice.totalAmount.value,
          'timestamp': invoice.createdAt.physicalTime,
          'status': invoice.status.value.value,
          'icon': 'receipt',
          'color': '#4CAF50',
        });
      }

      // Get recent payments
      final paidInvoices = await _getRecentPayments(limit: 5);
      for (final invoice in paidInvoices) {
        activities.add({
          'type': 'payment_received',
          'title': 'Payment Received',
          'description': 'Payment for Invoice ${invoice.invoiceNumber.value}',
          'amount': invoice.totalAmount.value - invoice.remainingBalance,
          'timestamp': invoice.lastPaymentDate.value?.millisecondsSinceEpoch ?? 
                      invoice.updatedAt.physicalTime,
          'icon': 'payment',
          'color': '#2196F3',
        });
      }

      // Sort by timestamp and limit
      activities.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
      return activities.take(limit).toList();
      
    } catch (e) {
      return [];
    }
  }

  /// Helper methods

  DateRange _getDateRange(TimePeriod period, DateTime? customStart, DateTime? customEnd) {
    final now = DateTime.now();
    
    switch (period) {
      case TimePeriod.today:
        return DateRange(
          DateTime(now.year, now.month, now.day),
          DateTime(now.year, now.month, now.day, 23, 59, 59)
        );
      case TimePeriod.thisWeek:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return DateRange(
          DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
          now
        );
      case TimePeriod.thisMonth:
        return DateRange(
          DateTime(now.year, now.month, 1),
          now
        );
      case TimePeriod.thisYear:
        return DateRange(
          DateTime(now.year, 1, 1),
          now
        );
      case TimePeriod.custom:
        return DateRange(
          customStart ?? now.subtract(const Duration(days: 30)),
          customEnd ?? now
        );
      default:
        return DateRange(
          DateTime(now.year, now.month, 1),
          now
        );
    }
  }

  DateRange _getPreviousDateRange(DateRange current) {
    final duration = current.end.difference(current.start);
    return DateRange(
      current.start.subtract(duration),
      current.start
    );
  }

  TrendDirection _calculateTrend(double current, double previous) {
    if (previous == 0) return TrendDirection.stable;
    final change = ((current - previous) / previous) * 100;
    if (change > 5) return TrendDirection.up;
    if (change < -5) return TrendDirection.down;
    return TrendDirection.stable;
  }

  Future<List<CRDTInvoiceEnhanced>> _getRecentInvoices({int limit = 10}) async {
    try {
      final result = await _invoiceService.searchInvoices(
        InvoiceSearchFilters(limit: limit, sortBy: 'created_at', sortAscending: false)
      );
      return result.success ? result.data! : [];
    } catch (e) {
      return [];
    }
  }

  Future<List<CRDTInvoiceEnhanced>> _getRecentPayments({int limit = 10}) async {
    try {
      final result = await _invoiceService.searchInvoices(
        InvoiceSearchFilters(
          statuses: [InvoiceStatus.paid, InvoiceStatus.partiallyPaid],
          limit: limit,
          sortBy: 'last_payment_date',
          sortAscending: false,
        )
      );
      return result.success ? result.data! : [];
    } catch (e) {
      return [];
    }
  }

  DashboardConfig _getDefaultDashboardConfig() {
    return DashboardConfig(
      id: 'default_config',
      name: 'Default Dashboard',
      enabledKPIs: ['total_revenue', 'net_cash_flow', 'total_customers', 'outstanding_receivables'],
      chartSettings: {
        'revenue_chart': {'type': 'line', 'color': '#4CAF50'},
        'cash_flow_chart': {'type': 'area', 'color': '#2196F3'},
        'customer_chart': {'type': 'line', 'color': '#FF9800'},
        'status_chart': {'type': 'pie', 'colors': ['#4CAF50', '#FF9800', '#F44336', '#9C27B0']},
      },
      defaultTimePeriod: TimePeriod.thisMonth,
      autoRefresh: true,
      refreshInterval: 300, // 5 minutes
      customSettings: {},
      lastModified: DateTime.now(),
    );
  }

  /// Advanced analytics helper methods

  int _calculateChurnedCustomers(Map<String, dynamic> customerData, DateRange dateRange) {
    try {
      final allCustomers = customerData['all_customers'] as List? ?? [];
      final currentPeriodCustomers = customerData['active_customers'] as int? ?? 0;
      final previousPeriodCustomers = customerData['previous_active_customers'] as int? ?? 0;
      
      // Simple churn calculation: customers who were active in previous period but not in current
      return previousPeriodCustomers > currentPeriodCustomers 
          ? previousPeriodCustomers - currentPeriodCustomers 
          : 0;
    } catch (e) {
      return 0;
    }
  }

  double _calculateChurnRate(Map<String, dynamic> customerData, DateRange dateRange) {
    try {
      final churned = _calculateChurnedCustomers(customerData, dateRange);
      final previousActive = customerData['previous_active_customers'] as int? ?? 0;
      
      return previousActive > 0 ? (churned / previousActive) * 100 : 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  double _calculateAcquisitionRate(Map<String, dynamic> customerData, DateRange dateRange) {
    try {
      final newCustomers = customerData['new_customers'] as int? ?? 0;
      final totalCustomers = customerData['total_customers'] as int? ?? 0;
      
      return totalCustomers > 0 ? (newCustomers / totalCustomers) * 100 : 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  double _calculateRetentionRate(Map<String, dynamic> customerData, DateRange dateRange) {
    try {
      final churnRate = _calculateChurnRate(customerData, dateRange);
      return 100.0 - churnRate;
    } catch (e) {
      return 0.0;
    }
  }

  double _calculateAverageLifetimeValue(Map<String, dynamic> customerData, Map<String, dynamic> revenueData) {
    try {
      final totalRevenue = revenueData['total_revenue'] as double? ?? 0.0;
      final totalCustomers = customerData['total_customers'] as int? ?? 0;
      
      return totalCustomers > 0 ? totalRevenue / totalCustomers : 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  Map<String, double> _segmentCustomers(List customers) {
    try {
      final segments = <String, double>{
        'High Value': 0.0,
        'Medium Value': 0.0,
        'Low Value': 0.0,
        'New': 0.0,
        'At Risk': 0.0,
      };

      for (final customer in customers) {
        // Simple segmentation logic - in a real app this would be more sophisticated
        final createdAt = customer['created_at'] as DateTime?;
        final totalSpent = customer['total_spent'] as double? ?? 0.0;
        
        if (createdAt != null && DateTime.now().difference(createdAt).inDays < 30) {
          segments['New'] = (segments['New'] ?? 0.0) + 1.0;
        } else if (totalSpent > 10000) {
          segments['High Value'] = (segments['High Value'] ?? 0.0) + 1.0;
        } else if (totalSpent > 1000) {
          segments['Medium Value'] = (segments['Medium Value'] ?? 0.0) + 1.0;
        } else if (totalSpent > 0) {
          segments['Low Value'] = (segments['Low Value'] ?? 0.0) + 1.0;
        } else {
          segments['At Risk'] = (segments['At Risk'] ?? 0.0) + 1.0;
        }
      }

      return segments;
    } catch (e) {
      return {
        'High Value': 0.0,
        'Medium Value': 0.0,
        'Low Value': 0.0,
        'New': 0.0,
        'At Risk': 0.0,
      };
    }
  }

  Map<String, double> _calculateRevenueBySegment(Map<String, dynamic> revenueData, List customers) {
    try {
      final revenueBySegment = <String, double>{
        'High Value': 0.0,
        'Medium Value': 0.0,
        'Low Value': 0.0,
        'New': 0.0,
        'At Risk': 0.0,
      };

      for (final customer in customers) {
        final totalSpent = customer['total_spent'] as double? ?? 0.0;
        final createdAt = customer['created_at'] as DateTime?;
        
        if (createdAt != null && DateTime.now().difference(createdAt).inDays < 30) {
          revenueBySegment['New'] = (revenueBySegment['New'] ?? 0.0) + totalSpent;
        } else if (totalSpent > 10000) {
          revenueBySegment['High Value'] = (revenueBySegment['High Value'] ?? 0.0) + totalSpent;
        } else if (totalSpent > 1000) {
          revenueBySegment['Medium Value'] = (revenueBySegment['Medium Value'] ?? 0.0) + totalSpent;
        } else if (totalSpent > 0) {
          revenueBySegment['Low Value'] = (revenueBySegment['Low Value'] ?? 0.0) + totalSpent;
        } else {
          revenueBySegment['At Risk'] = (revenueBySegment['At Risk'] ?? 0.0) + totalSpent;
        }
      }

      return revenueBySegment;
    } catch (e) {
      return {
        'High Value': 0.0,
        'Medium Value': 0.0,
        'Low Value': 0.0,
        'New': 0.0,
        'At Risk': 0.0,
      };
    }
  }

  List<CustomerBehaviorInsight> _generateBehaviorInsights(Map<String, dynamic> customerData, Map<String, dynamic> revenueData) {
    try {
      final insights = <CustomerBehaviorInsight>[];
      
      final totalCustomers = customerData['total_customers'] as int? ?? 0;
      final newCustomers = customerData['new_customers'] as int? ?? 0;
      final activeCustomers = customerData['active_customers'] as int? ?? 0;
      final totalRevenue = revenueData['total_revenue'] as double? ?? 0.0;
      final averageOrderValue = revenueData['average_order_value'] as double? ?? 0.0;

      // Growth insights
      if (newCustomers > 0) {
        final growthRate = totalCustomers > 0 ? (newCustomers / totalCustomers) * 100 : 0.0;
        if (growthRate > 10) {
          insights.add(CustomerBehaviorInsight(
            insight: 'Strong customer growth rate of ${growthRate.toStringAsFixed(1)}%',
            category: 'Growth',
            impact: 0.9,
            recommendation: 'Continue current growth strategies',
          ));
        } else if (growthRate > 0) {
          insights.add(CustomerBehaviorInsight(
            insight: 'Moderate customer growth rate of ${growthRate.toStringAsFixed(1)}%',
            category: 'Growth',
            impact: 0.6,
            recommendation: 'Consider implementing growth acceleration strategies',
          ));
        }
      }

      // Engagement insights
      if (totalCustomers > 0) {
        final engagementRate = (activeCustomers / totalCustomers) * 100;
        if (engagementRate > 70) {
          insights.add(CustomerBehaviorInsight(
            insight: 'High customer engagement rate of ${engagementRate.toStringAsFixed(1)}%',
            category: 'Engagement',
            impact: 0.9,
            recommendation: 'Maintain current engagement strategies',
          ));
        } else if (engagementRate < 30) {
          insights.add(CustomerBehaviorInsight(
            insight: 'Low customer engagement rate of ${engagementRate.toStringAsFixed(1)}%',
            category: 'Engagement',
            impact: 0.8,
            recommendation: 'Consider implementing re-engagement campaigns',
          ));
        }
      }

      // Revenue insights
      if (averageOrderValue > 0) {
        if (averageOrderValue > 5000) {
          insights.add(CustomerBehaviorInsight(
            insight: 'High average order value of \$${averageOrderValue.toStringAsFixed(2)} suggests premium customer base',
            category: 'Revenue',
            impact: 0.8,
            recommendation: 'Focus on retaining high-value customers',
          ));
        } else if (averageOrderValue < 100) {
          insights.add(CustomerBehaviorInsight(
            insight: 'Low average order value of \$${averageOrderValue.toStringAsFixed(2)}',
            category: 'Revenue',
            impact: 0.7,
            recommendation: 'Consider implementing upselling strategies',
          ));
        }
      }

      // Default insights if none generated
      if (insights.isEmpty) {
        insights.addAll([
          CustomerBehaviorInsight(
            insight: 'Monitor customer acquisition trends',
            category: 'General',
            impact: 0.5,
            recommendation: 'Track new customer metrics regularly',
          ),
          CustomerBehaviorInsight(
            insight: 'Focus on customer retention strategies',
            category: 'Retention',
            impact: 0.6,
            recommendation: 'Implement customer retention programs',
          ),
          CustomerBehaviorInsight(
            insight: 'Analyze payment patterns for insights',
            category: 'Analytics',
            impact: 0.4,
            recommendation: 'Set up detailed payment analytics',
          ),
        ]);
      }

      return insights;
    } catch (e) {
      return [
        CustomerBehaviorInsight(
          insight: 'Monitor customer acquisition trends',
          category: 'General',
          impact: 0.5,
          recommendation: 'Track new customer metrics regularly',
        ),
        CustomerBehaviorInsight(
          insight: 'Focus on customer retention strategies',
          category: 'Retention',
          impact: 0.6,
          recommendation: 'Implement customer retention programs',
        ),
        CustomerBehaviorInsight(
          insight: 'Analyze payment patterns for insights',
          category: 'Analytics',
          impact: 0.4,
          recommendation: 'Set up detailed payment analytics',
        ),
      ];
    }
  }
}

/// Date range helper class
class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange(this.start, this.end);
}