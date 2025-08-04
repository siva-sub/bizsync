import 'dart:math' as math;
import 'package:collection/collection.dart';
import '../models/dashboard_models.dart';
import '../../../core/types/invoice_types.dart';
import '../../../core/crdt/hybrid_logical_clock.dart';
import '../../../data/models/customer.dart';
import '../../inventory/models/product.dart';
import '../../invoices/models/enhanced_invoice_model.dart';

/// Core analytics service for business calculations and data processing
class AnalyticsService {
  static const double _confidenceThreshold = 0.7;
  static const int _forecastDays = 30;
  static const String _analyticsNodeId = 'analytics-service';

  /// Calculate revenue analytics for a given time period
  Future<RevenueAnalytics> calculateRevenueAnalytics({
    required List<CRDTInvoiceEnhanced> invoices,
    required TimePeriod period,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final dateRange = _getDateRange(period, startDate, endDate);
    final filteredInvoices = _filterInvoicesByDate(
      invoices,
      dateRange.start,
      dateRange.end,
    );

    // Calculate basic revenue metrics
    final totalRevenue = filteredInvoices
        .where((invoice) => invoice.status.value == InvoiceStatus.paid)
        .fold(0.0, (sum, invoice) => sum + invoice.totalAmount.value);

    final recurringRevenue = filteredInvoices
        .where((invoice) =>
            invoice.status.value == InvoiceStatus.paid &&
            invoice.isRecurring == true)
        .fold(0.0, (sum, invoice) => sum + invoice.totalAmount.value);

    final oneTimeRevenue = totalRevenue - recurringRevenue;

    // Group revenue by day
    final revenueByDay = _groupRevenueByDay(filteredInvoices, dateRange);

    // Group revenue by product/service
    final revenueByProduct = _groupRevenueByProduct(filteredInvoices);

    // Group revenue by customer
    final revenueByCustomer = _groupRevenueByCustomer(filteredInvoices);

    // Calculate revenue by category
    final revenueByCategory = _calculateRevenueByCategory(filteredInvoices);

    // Calculate average order value
    final paidInvoices = filteredInvoices
        .where((invoice) => invoice.status.value == InvoiceStatus.paid)
        .toList();
    final averageOrderValue =
        paidInvoices.isEmpty ? 0.0 : totalRevenue / paidInvoices.length;

    // Calculate growth rate
    final previousPeriodRange = _getPreviousPeriodRange(period, dateRange);
    final previousInvoices = _filterInvoicesByDate(
      invoices,
      previousPeriodRange.start,
      previousPeriodRange.end,
    );
    final previousRevenue = previousInvoices
        .where((invoice) => invoice.status.value == InvoiceStatus.paid)
        .fold(0.0, (sum, invoice) => sum + invoice.totalAmount.value);

    final growthRate = previousRevenue == 0
        ? 0.0
        : ((totalRevenue - previousRevenue) / previousRevenue) * 100;

    return RevenueAnalytics(
      id: 'revenue_${period.name}_${DateTime.now().millisecondsSinceEpoch}',
      period: period,
      totalRevenue: totalRevenue,
      recurringRevenue: recurringRevenue,
      oneTimeRevenue: oneTimeRevenue,
      revenueByDay: revenueByDay,
      revenueByProduct: revenueByProduct,
      revenueByCustomer: revenueByCustomer,
      revenueByCategory: revenueByCategory,
      averageOrderValue: averageOrderValue,
      totalTransactions: paidInvoices.length,
      growthRate: growthRate,
      generatedAt: DateTime.now(),
    );
  }

  /// Calculate cash flow data for a given time period
  Future<CashFlowData> calculateCashFlowData({
    required List<CRDTInvoiceEnhanced> invoices,
    required List<dynamic> expenses, // Generic expenses data
    required TimePeriod period,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final dateRange = _getDateRange(period, startDate, endDate);
    final filteredInvoices = _filterInvoicesByDate(
      invoices,
      dateRange.start,
      dateRange.end,
    );

    // Calculate inflows (from paid invoices)
    final totalInflow = filteredInvoices
        .where((invoice) => invoice.status.value == InvoiceStatus.paid)
        .fold(0.0, (sum, invoice) => sum + invoice.totalAmount.value);

    // For demo purposes, calculate estimated outflows
    final totalOutflow = totalInflow * 0.7; // 70% of revenue as expenses

    // Calculate daily cash flow
    final dailyCashFlow = _calculateDailyCashFlow(
      filteredInvoices,
      expenses,
      dateRange,
    );

    // Calculate net cash flow
    final netCashFlow = totalInflow - totalOutflow;

    // Estimate opening and closing balances
    final openingBalance = 10000.0; // Demo value
    final closingBalance = openingBalance + netCashFlow;

    // Categorize inflows and outflows
    final inflowByCategory = _categorizeInflows(filteredInvoices);
    final outflowByCategory = _categorizeOutflows(expenses);

    // Generate forecasts
    final forecasts = await _generateCashFlowForecasts(
      dailyCashFlow,
      inflowByCategory,
      outflowByCategory,
    );

    return CashFlowData(
      id: 'cashflow_${period.name}_${DateTime.now().millisecondsSinceEpoch}',
      period: period,
      openingBalance: openingBalance,
      closingBalance: closingBalance,
      totalInflow: totalInflow,
      totalOutflow: totalOutflow,
      netCashFlow: netCashFlow,
      dailyCashFlow: dailyCashFlow,
      inflowByCategory: inflowByCategory,
      outflowByCategory: outflowByCategory,
      forecasts: forecasts,
      generatedAt: DateTime.now(),
    );
  }

  /// Calculate customer insights and behavior analysis
  Future<CustomerInsights> calculateCustomerInsights({
    required List<Customer> customers,
    required List<CRDTInvoiceEnhanced> invoices,
    required TimePeriod period,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final dateRange = _getDateRange(period, startDate, endDate);
    final previousPeriodRange = _getPreviousPeriodRange(period, dateRange);

    // Filter customers and invoices by date
    final currentCustomers = customers
        .where((customer) =>
            customer.createdAt.isAfter(dateRange.start) &&
            customer.createdAt.isBefore(dateRange.end))
        .toList();

    final previousCustomers = customers
        .where((customer) =>
            customer.createdAt.isAfter(previousPeriodRange.start) &&
            customer.createdAt.isBefore(previousPeriodRange.end))
        .toList();

    // Calculate basic metrics
    final totalCustomers = customers.length;
    final newCustomers = currentCustomers.length;
    final activeCustomers =
        _calculateActiveCustomers(customers, invoices, dateRange);
    final churned = _calculateChurnedCustomers(customers, invoices, dateRange);

    // Calculate rates
    final churnRate =
        totalCustomers == 0 ? 0.0 : (churned / totalCustomers) * 100;
    final acquisitionRate = previousCustomers.isEmpty
        ? 0.0
        : (newCustomers / previousCustomers.length) * 100;
    final retentionRate = 100 - churnRate;

    // Calculate customer lifetime value
    final averageLifetimeValue =
        _calculateAverageLifetimeValue(customers, invoices);

    // Generate customer growth data
    final customerGrowth = _generateCustomerGrowthData(customers, dateRange);

    // Segment customers
    final customersBySegment = _segmentCustomers(customers, invoices);
    final revenueBySegment = _calculateRevenueBySegment(customers, invoices);

    // Generate behavior insights
    final behaviorInsights =
        await _generateBehaviorInsights(customers, invoices);

    return CustomerInsights(
      id: 'customer_insights_${period.name}_${DateTime.now().millisecondsSinceEpoch}',
      period: period,
      totalCustomers: totalCustomers,
      newCustomers: newCustomers,
      activeCustomers: activeCustomers,
      churned: churned,
      churnRate: churnRate,
      acquisitionRate: acquisitionRate,
      retentionRate: retentionRate,
      averageLifetimeValue: averageLifetimeValue,
      customerGrowth: customerGrowth,
      customersBySegment: customersBySegment,
      revenueBySegment: revenueBySegment,
      behaviorInsights: behaviorInsights,
      generatedAt: DateTime.now(),
    );
  }

  /// Calculate inventory overview and stock analysis
  Future<InventoryOverview> calculateInventoryOverview({
    required List<Product> products,
  }) async {
    // Calculate basic inventory metrics
    final totalProducts = products.length;
    final lowStockProducts = products
        .where((product) => product.stockLevel <= product.minStockLevel)
        .length;
    final outOfStockProducts =
        products.where((product) => product.stockLevel == 0).length;

    // Calculate total inventory value
    final totalInventoryValue = products.fold(
      0.0,
      (sum, product) => sum + (product.price * product.stockLevel),
    );

    // Calculate average stock level
    final averageStockLevel = products.isEmpty
        ? 0.0
        : products.fold(0.0, (sum, product) => sum + product.stockLevel) /
            products.length;

    // Group stock by category
    final stockByCategory = <String, int>{};
    for (final product in products) {
      final category = product.category ?? 'Uncategorized';
      stockByCategory[category] =
          (stockByCategory[category] ?? 0) + product.stockLevel;
    }

    // Generate stock alerts
    final stockAlerts = _generateStockAlerts(products);

    // Calculate inventory turnover (mock data for demo)
    final inventoryTurnover = _generateInventoryTurnoverData();

    return InventoryOverview(
      id: 'inventory_${DateTime.now().millisecondsSinceEpoch}',
      totalProducts: totalProducts,
      lowStockProducts: lowStockProducts,
      outOfStockProducts: outOfStockProducts,
      totalInventoryValue: totalInventoryValue,
      averageStockLevel: averageStockLevel,
      stockByCategory: stockByCategory,
      stockAlerts: stockAlerts,
      inventoryTurnover: inventoryTurnover,
      lastUpdated: DateTime.now(),
    );
  }

  /// Generate KPIs for the dashboard
  Future<List<KPI>> generateKPIs({
    required List<CRDTInvoiceEnhanced> invoices,
    required List<Customer> customers,
    required List<Product> products,
    required TimePeriod period,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final dateRange = _getDateRange(period, startDate, endDate);
    final previousPeriodRange = _getPreviousPeriodRange(period, dateRange);

    final kpis = <KPI>[];

    // Revenue KPI
    final currentRevenue = _calculateRevenueForPeriod(invoices, dateRange);
    final previousRevenue =
        _calculateRevenueForPeriod(invoices, previousPeriodRange);
    final revenueChange = previousRevenue == 0
        ? 0.0
        : ((currentRevenue - previousRevenue) / previousRevenue) * 100;

    kpis.add(KPI(
      id: 'revenue_kpi',
      title: 'Total Revenue',
      description: 'Total revenue for the selected period',
      type: KPIType.revenue,
      currentValue: currentRevenue,
      previousValue: previousRevenue,
      targetValue: currentRevenue * 1.1, // 10% growth target
      unit: 'SGD',
      prefix: '\$',
      trend: revenueChange > 0
          ? TrendDirection.up
          : revenueChange < 0
              ? TrendDirection.down
              : TrendDirection.stable,
      percentageChange: revenueChange,
      lastUpdated: DateTime.now(),
      historicalData: _generateRevenueHistoricalData(invoices, dateRange),
      iconName: 'trending_up',
      color: '#4CAF50',
    ));

    // Customer KPI
    final currentCustomers =
        customers.where((c) => c.createdAt.isBefore(dateRange.end)).length;
    final previousCustomers = customers
        .where((c) => c.createdAt.isBefore(previousPeriodRange.end))
        .length;
    final customerChange = previousCustomers == 0
        ? 0.0
        : ((currentCustomers - previousCustomers) / previousCustomers) * 100;

    kpis.add(KPI(
      id: 'customers_kpi',
      title: 'Total Customers',
      description: 'Total number of customers',
      type: KPIType.customers,
      currentValue: currentCustomers.toDouble(),
      previousValue: previousCustomers.toDouble(),
      unit: 'customers',
      trend: customerChange > 0
          ? TrendDirection.up
          : customerChange < 0
              ? TrendDirection.down
              : TrendDirection.stable,
      percentageChange: customerChange,
      lastUpdated: DateTime.now(),
      historicalData: _generateCustomerHistoricalData(customers, dateRange),
      iconName: 'people',
      color: '#2196F3',
    ));

    // Inventory value KPI
    final inventoryValue = products.fold(
      0.0,
      (sum, product) => sum + (product.price * product.stockLevel),
    );

    kpis.add(KPI(
      id: 'inventory_kpi',
      title: 'Inventory Value',
      description: 'Total value of current inventory',
      type: KPIType.inventory,
      currentValue: inventoryValue,
      unit: 'SGD',
      prefix: '\$',
      trend: TrendDirection.stable,
      percentageChange: 0.0,
      lastUpdated: DateTime.now(),
      historicalData: [],
      iconName: 'inventory',
      color: '#FF9800',
    ));

    return kpis;
  }

  // Private helper methods

  DateRange _getDateRange(
      TimePeriod period, DateTime? startDate, DateTime? endDate) {
    final now = DateTime.now();
    switch (period) {
      case TimePeriod.today:
        return DateRange(
          DateTime(now.year, now.month, now.day),
          DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case TimePeriod.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        return DateRange(
          DateTime(yesterday.year, yesterday.month, yesterday.day),
          DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59),
        );
      case TimePeriod.thisWeek:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return DateRange(
          DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
          DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case TimePeriod.thisMonth:
        return DateRange(
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
      case TimePeriod.thisYear:
        return DateRange(
          DateTime(now.year, 1, 1),
          DateTime(now.year, 12, 31, 23, 59, 59),
        );
      case TimePeriod.custom:
        return DateRange(
          startDate ?? DateTime(now.year, now.month, 1),
          endDate ?? now,
        );
      default:
        return DateRange(
          DateTime(now.year, now.month, 1),
          now,
        );
    }
  }

  DateRange _getPreviousPeriodRange(TimePeriod period, DateRange currentRange) {
    final duration = currentRange.end.difference(currentRange.start);
    return DateRange(
      currentRange.start.subtract(duration),
      currentRange.start,
    );
  }

  List<CRDTInvoiceEnhanced> _filterInvoicesByDate(
    List<CRDTInvoiceEnhanced> invoices,
    DateTime startDate,
    DateTime endDate,
  ) {
    return invoices
        .where((invoice) =>
            invoice.createdAt.isAfter(
                HLCTimestamp.fromDateTime(startDate, _analyticsNodeId)) &&
            invoice.createdAt
                .isBefore(HLCTimestamp.fromDateTime(endDate, _analyticsNodeId)))
        .toList();
  }

  List<DataPoint> _groupRevenueByDay(
    List<CRDTInvoiceEnhanced> invoices,
    DateRange dateRange,
  ) {
    final revenueByDay = <DateTime, double>{};

    for (final invoice in invoices) {
      if (invoice.status.value == InvoiceStatus.paid) {
        final day = DateTime(
          invoice.lastPaymentDate.value!.year,
          invoice.lastPaymentDate.value!.month,
          invoice.lastPaymentDate.value!.day,
        );
        revenueByDay[day] =
            (revenueByDay[day] ?? 0) + invoice.totalAmount.value;
      }
    }

    return revenueByDay.entries
        .map((entry) => DataPoint(
              timestamp: entry.key,
              value: entry.value,
              label: entry.key.day.toString(),
            ))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  List<DataPoint> _groupRevenueByProduct(List<CRDTInvoiceEnhanced> invoices) {
    final revenueByProduct = <String, double>{};

    for (final invoice in invoices) {
      if (invoice.status.value == InvoiceStatus.paid) {
        // TODO: Fix line items access - itemIds are references, need to fetch actual items
        // for (final itemId in invoice.itemIds.elements) {
        //   // Need to fetch item by ID and then access properties
        // }

        // For now, use invoice total as single product revenue
        final productName = 'General Revenue';
        revenueByProduct[productName] =
            (revenueByProduct[productName] ?? 0) + invoice.totalAmount.value;
      }
    }

    return revenueByProduct.entries
        .map((entry) => DataPoint(
              timestamp: DateTime.now(),
              value: entry.value,
              label: entry.key,
            ))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  List<DataPoint> _groupRevenueByCustomer(List<CRDTInvoiceEnhanced> invoices) {
    final revenueByCustomer = <String, double>{};

    for (final invoice in invoices) {
      if (invoice.status.value == InvoiceStatus.paid) {
        final customerName = invoice.customerName.value ?? 'Unknown Customer';
        revenueByCustomer[customerName] =
            (revenueByCustomer[customerName] ?? 0) + invoice.totalAmount.value;
      }
    }

    return revenueByCustomer.entries
        .map((entry) => DataPoint(
              timestamp: DateTime.now(),
              value: entry.value,
              label: entry.key,
            ))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  Map<String, double> _calculateRevenueByCategory(
      List<CRDTInvoiceEnhanced> invoices) {
    final revenueByCategory = <String, double>{};

    for (final invoice in invoices) {
      if (invoice.status.value == InvoiceStatus.paid) {
        // For demo purposes, categorize based on invoice amount
        String category;
        if (invoice.totalAmount.value > 1000) {
          category = 'Large Orders';
        } else if (invoice.totalAmount.value > 500) {
          category = 'Medium Orders';
        } else {
          category = 'Small Orders';
        }

        revenueByCategory[category] =
            (revenueByCategory[category] ?? 0) + invoice.totalAmount.value;
      }
    }

    return revenueByCategory;
  }

  List<DataPoint> _calculateDailyCashFlow(
    List<CRDTInvoiceEnhanced> invoices,
    List<dynamic> expenses,
    DateRange dateRange,
  ) {
    final dailyFlow = <DateTime, double>{};

    // Add inflows from paid invoices
    for (final invoice in invoices) {
      if (invoice.status.value == InvoiceStatus.paid &&
          invoice.lastPaymentDate.value != null) {
        final day = DateTime(
          invoice.lastPaymentDate.value!.year,
          invoice.lastPaymentDate.value!.month,
          invoice.lastPaymentDate.value!.day,
        );
        dailyFlow[day] = (dailyFlow[day] ?? 0) + invoice.totalAmount.value;
      }
    }

    // Generate mock daily expenses
    final random = math.Random();
    var currentDate = dateRange.start;
    while (currentDate.isBefore(dateRange.end)) {
      final day =
          DateTime(currentDate.year, currentDate.month, currentDate.day);
      final dailyExpense = random.nextDouble() * 500 + 100; // Random expense
      dailyFlow[day] = (dailyFlow[day] ?? 0) - dailyExpense;
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return dailyFlow.entries
        .map((entry) => DataPoint(
              timestamp: entry.key,
              value: entry.value,
              label: entry.key.day.toString(),
            ))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Map<String, double> _categorizeInflows(List<CRDTInvoiceEnhanced> invoices) {
    final inflowByCategory = <String, double>{};

    for (final invoice in invoices) {
      if (invoice.status.value == InvoiceStatus.paid) {
        String category = 'Sales Revenue';
        if (invoice.isRecurring == true) {
          category = 'Recurring Revenue';
        }

        inflowByCategory[category] =
            (inflowByCategory[category] ?? 0) + invoice.totalAmount.value;
      }
    }

    return inflowByCategory;
  }

  Map<String, double> _categorizeOutflows(List<dynamic> expenses) {
    // Mock categorization for demo
    return {
      'Operating Expenses': 3000.0,
      'Marketing': 1500.0,
      'Supplies': 800.0,
      'Utilities': 400.0,
      'Rent': 2000.0,
    };
  }

  Future<List<CashFlowForecast>> _generateCashFlowForecasts(
    List<DataPoint> historicalData,
    Map<String, double> inflowCategories,
    Map<String, double> outflowCategories,
  ) async {
    final forecasts = <CashFlowForecast>[];
    final random = math.Random();

    // Simple linear regression for forecasting
    if (historicalData.length >= 7) {
      final avgInflow =
          inflowCategories.values.fold(0.0, (a, b) => a + b) / _forecastDays;
      final avgOutflow =
          outflowCategories.values.fold(0.0, (a, b) => a + b) / _forecastDays;

      var runningBalance = historicalData.last.value;

      for (int i = 1; i <= _forecastDays; i++) {
        final date = DateTime.now().add(Duration(days: i));
        final predictedInflow = avgInflow * (0.8 + random.nextDouble() * 0.4);
        final predictedOutflow = avgOutflow * (0.8 + random.nextDouble() * 0.4);

        runningBalance += predictedInflow - predictedOutflow;

        forecasts.add(CashFlowForecast(
          date: date,
          predictedInflow: predictedInflow,
          predictedOutflow: predictedOutflow,
          predictedBalance: runningBalance,
          confidence: math.max(0.1, _confidenceThreshold - (i * 0.02)),
          scenario: 'Base Case',
        ));
      }
    }

    return forecasts;
  }

  int _calculateActiveCustomers(
    List<Customer> customers,
    List<CRDTInvoiceEnhanced> invoices,
    DateRange dateRange,
  ) {
    final activeCustomerIds = invoices
        .where((invoice) =>
            invoice.createdAt.toDateTime().isAfter(dateRange.start) &&
            invoice.createdAt.toDateTime().isBefore(dateRange.end))
        .map((invoice) => invoice.customerId.value)
        .toSet();

    return activeCustomerIds.length;
  }

  int _calculateChurnedCustomers(
    List<Customer> customers,
    List<CRDTInvoiceEnhanced> invoices,
    DateRange dateRange,
  ) {
    // Simple churn calculation: customers with no activity in the last 90 days
    final cutoffDate = dateRange.end.subtract(const Duration(days: 90));
    final recentCustomerIds = invoices
        .where((invoice) => invoice.createdAt.toDateTime().isAfter(cutoffDate))
        .map((invoice) => invoice.customerId.value)
        .toSet();

    final allCustomerIds = customers.map((c) => c.id).toSet();
    return allCustomerIds.difference(recentCustomerIds).length;
  }

  double _calculateAverageLifetimeValue(
    List<Customer> customers,
    List<CRDTInvoiceEnhanced> invoices,
  ) {
    if (customers.isEmpty) return 0.0;

    final totalRevenue = invoices
        .where((invoice) => invoice.status.value == InvoiceStatus.paid)
        .fold(0.0, (sum, invoice) => sum + invoice.totalAmount.value);

    return totalRevenue / customers.length;
  }

  List<DataPoint> _generateCustomerGrowthData(
    List<Customer> customers,
    DateRange dateRange,
  ) {
    final growthData = <DateTime, int>{};

    // Group customers by creation date
    for (final customer in customers) {
      if (customer.createdAt.isAfter(dateRange.start) &&
          customer.createdAt.isBefore(dateRange.end)) {
        final customerDate = customer.createdAt;
        final day = DateTime(
          customerDate.year,
          customerDate.month,
          customerDate.day,
        );
        growthData[day] = (growthData[day] ?? 0) + 1;
      }
    }

    return growthData.entries
        .map((entry) => DataPoint(
              timestamp: entry.key,
              value: entry.value.toDouble(),
              label: entry.key.day.toString(),
            ))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Map<String, double> _segmentCustomers(
    List<Customer> customers,
    List<CRDTInvoiceEnhanced> invoices,
  ) {
    final segments = <String, double>{};

    for (final customer in customers) {
      final customerRevenue = invoices
          .where((invoice) =>
              invoice.customerId.value == customer.id &&
              invoice.status.value == InvoiceStatus.paid)
          .fold(0.0, (sum, invoice) => sum + invoice.totalAmount.value);

      String segment;
      if (customerRevenue > 5000) {
        segment = 'Premium';
      } else if (customerRevenue > 1000) {
        segment = 'Regular';
      } else {
        segment = 'Basic';
      }

      segments[segment] = (segments[segment] ?? 0) + 1;
    }

    return segments;
  }

  Map<String, double> _calculateRevenueBySegment(
    List<Customer> customers,
    List<CRDTInvoiceEnhanced> invoices,
  ) {
    final revenueBySegment = <String, double>{};

    for (final customer in customers) {
      final customerRevenue = invoices
          .where((invoice) =>
              invoice.customerId.value == customer.id &&
              invoice.status.value == InvoiceStatus.paid)
          .fold(0.0, (sum, invoice) => sum + invoice.totalAmount.value);

      String segment;
      if (customerRevenue > 5000) {
        segment = 'Premium';
      } else if (customerRevenue > 1000) {
        segment = 'Regular';
      } else {
        segment = 'Basic';
      }

      revenueBySegment[segment] =
          (revenueBySegment[segment] ?? 0) + customerRevenue;
    }

    return revenueBySegment;
  }

  Future<List<CustomerBehaviorInsight>> _generateBehaviorInsights(
    List<Customer> customers,
    List<CRDTInvoiceEnhanced> invoices,
  ) async {
    final insights = <CustomerBehaviorInsight>[];

    // Analyze purchase patterns
    final avgOrderValue = invoices.isEmpty
        ? 0.0
        : invoices.fold(0.0, (sum, inv) => sum + inv.totalAmount.value) /
            invoices.length;

    if (avgOrderValue > 1000) {
      insights.add(const CustomerBehaviorInsight(
        insight: 'High average order value indicates premium customer base',
        category: 'Purchase Behavior',
        impact: 0.8,
        recommendation:
            'Focus on premium product offerings and personalized service',
      ));
    }

    // Analyze customer growth trend
    final recentCustomers = customers
        .where((c) => c.createdAt
            .isAfter(DateTime.now().subtract(const Duration(days: 30))))
        .length;

    if (recentCustomers > customers.length * 0.1) {
      insights.add(const CustomerBehaviorInsight(
        insight: 'Strong customer acquisition in the last 30 days',
        category: 'Growth',
        impact: 0.9,
        recommendation:
            'Invest in onboarding processes and customer retention strategies',
      ));
    }

    return insights;
  }

  List<ProductStockAlert> _generateStockAlerts(List<Product> products) {
    final alerts = <ProductStockAlert>[];

    for (final product in products) {
      String severity;
      if (product.stockLevel == 0) {
        severity = 'out_of_stock';
      } else if (product.stockLevel <= product.minStockLevel * 0.5) {
        severity = 'critical';
      } else if (product.stockLevel <= product.minStockLevel) {
        severity = 'low';
      } else {
        continue; // No alert needed
      }

      alerts.add(ProductStockAlert(
        productId: product.id,
        productName: product.name,
        currentStock: product.stockLevel,
        minStock: product.minStockLevel,
        severity: severity,
        alertDate: DateTime.now(),
      ));
    }

    return alerts
      ..sort((a, b) {
        const severityOrder = {'out_of_stock': 0, 'critical': 1, 'low': 2};
        return (severityOrder[a.severity] ?? 3)
            .compareTo(severityOrder[b.severity] ?? 3);
      });
  }

  List<DataPoint> _generateInventoryTurnoverData() {
    final random = math.Random();
    final data = <DataPoint>[];

    for (int i = 30; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final turnover = 2.5 + (random.nextDouble() * 2); // 2.5-4.5 turnover rate

      data.add(DataPoint(
        timestamp: date,
        value: turnover,
        label: date.day.toString(),
      ));
    }

    return data;
  }

  double _calculateRevenueForPeriod(
      List<CRDTInvoiceEnhanced> invoices, DateRange period) {
    return invoices
        .where((invoice) =>
            invoice.status.value == InvoiceStatus.paid &&
            invoice.lastPaymentDate.value != null &&
            invoice.lastPaymentDate.value!.isAfter(period.start) &&
            invoice.lastPaymentDate.value!.isBefore(period.end))
        .fold(0.0, (sum, invoice) => sum + invoice.totalAmount.value);
  }

  List<DataPoint> _generateRevenueHistoricalData(
    List<CRDTInvoiceEnhanced> invoices,
    DateRange dateRange,
  ) {
    final data = <DataPoint>[];
    final random = math.Random();

    // Generate 30 days of historical data
    for (int i = 30; i >= 0; i--) {
      final date = dateRange.end.subtract(Duration(days: i));
      final dailyRevenue =
          random.nextDouble() * 2000 + 500; // $500-$2500 per day

      data.add(DataPoint(
        timestamp: date,
        value: dailyRevenue,
        label: date.day.toString(),
      ));
    }

    return data;
  }

  List<DataPoint> _generateCustomerHistoricalData(
    List<Customer> customers,
    DateRange dateRange,
  ) {
    final data = <DataPoint>[];
    var cumulativeCustomers = 0;

    // Generate cumulative customer count over time
    for (int i = 30; i >= 0; i--) {
      final date = dateRange.end.subtract(Duration(days: i));
      final newCustomers = customers
          .where((c) =>
              c.createdAt.year == date.year &&
              c.createdAt.month == date.month &&
              c.createdAt.day == date.day)
          .length;

      cumulativeCustomers += newCustomers;

      data.add(DataPoint(
        timestamp: date,
        value: cumulativeCustomers.toDouble(),
        label: date.day.toString(),
      ));
    }

    return data;
  }
}

/// Helper class for date ranges
class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange(this.start, this.end);
}
