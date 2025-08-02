import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dashboard_models.dart';
import '../services/analytics_service.dart';
import '../services/real_analytics_service.dart';
import '../analytics/anomaly_detection_service.dart';
import '../intelligence/business_intelligence_engine.dart';
import '../../invoices/repositories/invoice_repository.dart';
import '../../invoices/models/enhanced_invoice_model.dart';
import '../../customers/repositories/customer_repository.dart';
import '../../customers/models/customer.dart';
import '../../inventory/repositories/product_repository.dart';
import '../../inventory/models/product.dart';

// Core service providers
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

final anomalyDetectionServiceProvider = Provider<AnomalyDetectionService>((ref) {
  return AnomalyDetectionService();
});

final businessIntelligenceEngineProvider = Provider<BusinessIntelligenceEngine>((ref) {
  return BusinessIntelligenceEngine();
});

// Repository providers (mock implementations for dashboard)
final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return MockInvoiceRepository();
});

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return MockCustomerRepository();
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return MockProductRepository();
});

// Dashboard data provider
final dashboardDataProvider = StateNotifierProvider<DashboardDataNotifier, AsyncValue<DashboardData>>((ref) {
  return DashboardDataNotifier(
    analyticsService: ref.watch(analyticsServiceProvider),
    invoiceRepository: ref.watch(invoiceRepositoryProvider),
    customerRepository: ref.watch(customerRepositoryProvider),
    productRepository: ref.watch(productRepositoryProvider),
  );
});

// Anomalies provider
final anomaliesProvider = FutureProvider<List<BusinessAnomaly>>((ref) async {
  final anomalyService = ref.watch(anomalyDetectionServiceProvider);
  
  try {
    // Get data from repositories
    final invoices = await ref.watch(invoiceRepositoryProvider).getAllInvoices();
    final customers = await ref.watch(customerRepositoryProvider).getAllCustomers();
    final products = await ref.watch(productRepositoryProvider).getAllProducts();
    
    // Detect anomalies
    return await anomalyService.detectAllAnomalies(
      invoices: invoices,
      customers: customers,
      products: products,
    );
  } catch (e) {
    // Return empty list if data loading fails
    return [];
  }
});

// Business forecast provider
final businessForecastProvider = FutureProvider<BusinessForecast?>((ref) async {
  final intelligenceEngine = ref.watch(businessIntelligenceEngineProvider);
  
  try {
    // Get data from repositories
    final invoices = await ref.watch(invoiceRepositoryProvider).getAllInvoices();
    final customers = await ref.watch(customerRepositoryProvider).getAllCustomers();
    final products = await ref.watch(productRepositoryProvider).getAllProducts();
    
    // Generate forecast
    return await intelligenceEngine.generateBusinessForecast(
      historicalInvoices: invoices,
      customers: customers,
      products: products,
    );
  } catch (e) {
    return null;
  }
});

// Revenue analytics provider
final revenueAnalyticsProvider = FutureProvider.family<RevenueAnalytics?, TimePeriod>((ref, period) async {
  final analyticsService = ref.watch(analyticsServiceProvider);
  
  try {
    final invoices = await ref.watch(invoiceRepositoryProvider).getAllInvoices();
    
    return await analyticsService.calculateRevenueAnalytics(
      invoices: invoices,
      period: period,
    );
  } catch (e) {
    return null;
  }
});

// Cash flow data provider
final cashFlowDataProvider = FutureProvider.family<CashFlowData?, TimePeriod>((ref, period) async {
  final analyticsService = ref.watch(analyticsServiceProvider);
  
  try {
    final invoices = await ref.watch(invoiceRepositoryProvider).getAllInvoices();
    
    return await analyticsService.calculateCashFlowData(
      invoices: invoices,
      expenses: [], // TODO: Add expenses data
      period: period,
    );
  } catch (e) {
    return null;
  }
});

// Customer insights provider
final customerInsightsProvider = FutureProvider.family<CustomerInsights?, TimePeriod>((ref, period) async {
  final analyticsService = ref.watch(analyticsServiceProvider);
  
  try {
    final customers = await ref.watch(customerRepositoryProvider).getAllCustomers();
    final invoices = await ref.watch(invoiceRepositoryProvider).getAllInvoices();
    
    return await analyticsService.calculateCustomerInsights(
      customers: customers,
      invoices: invoices,
      period: period,
    );
  } catch (e) {
    return null;
  }
});

// Inventory overview provider
final inventoryOverviewProvider = FutureProvider<InventoryOverview?>((ref) async {
  final analyticsService = ref.watch(analyticsServiceProvider);
  
  try {
    final products = await ref.watch(productRepositoryProvider).getAllProducts();
    
    return await analyticsService.calculateInventoryOverview(
      products: products,
    );
  } catch (e) {
    return null;
  }
});

// Tax compliance status provider
final taxComplianceStatusProvider = FutureProvider<TaxComplianceStatus?>((ref) async {
  // TODO: Implement tax compliance status calculation
  return TaxComplianceStatus(
    id: 'demo_tax_compliance',
    complianceScore: 85.0,
    upcomingObligations: const [],
    alerts: const [],
    taxLiabilities: const {},
    totalTaxPaid: 0.0,
    pendingTaxes: 0.0,
    lastAssessment: DateTime.now().subtract(const Duration(days: 30)),
  );
});

// KPIs provider
final kpisProvider = FutureProvider.family<List<KPI>, TimePeriod>((ref, period) async {
  final analyticsService = ref.watch(analyticsServiceProvider);
  
  try {
    final invoices = await ref.watch(invoiceRepositoryProvider).getAllInvoices();
    final customers = await ref.watch(customerRepositoryProvider).getAllCustomers();
    final products = await ref.watch(productRepositoryProvider).getAllProducts();
    
    return await analyticsService.generateKPIs(
      invoices: invoices,
      customers: customers,
      products: products,
      period: period,
    );
  } catch (e) {
    return [];
  }
});

// Dashboard configuration provider
final dashboardConfigProvider = StateNotifierProvider<DashboardConfigNotifier, DashboardConfig>((ref) {
  return DashboardConfigNotifier();
});

// Real-time updates provider
final realTimeUpdatesProvider = StreamProvider<DashboardUpdate>((ref) {
  // TODO: Implement real-time updates stream
  return Stream.periodic(const Duration(minutes: 5), (count) {
    return DashboardUpdate(
      timestamp: DateTime.now(),
      type: 'periodic_refresh',
      data: {},
    );
  });
});

/// Dashboard data state notifier
class DashboardDataNotifier extends StateNotifier<AsyncValue<DashboardData>> {
  final AnalyticsService _analyticsService;
  final InvoiceRepository _invoiceRepository;
  final CustomerRepository _customerRepository;
  final ProductRepository _productRepository;

  DashboardDataNotifier({
    required AnalyticsService analyticsService,
    required InvoiceRepository invoiceRepository,
    required CustomerRepository customerRepository,
    required ProductRepository productRepository,
  })  : _analyticsService = analyticsService,
        _invoiceRepository = invoiceRepository,
        _customerRepository = customerRepository,
        _productRepository = productRepository,
        super(const AsyncValue.loading());

  /// Load dashboard data for the specified time period
  Future<void> loadDashboardData(TimePeriod period) async {
    state = const AsyncValue.loading();
    
    try {
      // Load data from repositories
      final invoices = await _invoiceRepository.getAllInvoices();
      final customers = await _customerRepository.getAllCustomers();
      final products = await _productRepository.getAllProducts();

      // Generate KPIs
      final kpis = await _analyticsService.generateKPIs(
        invoices: invoices,
        customers: customers,
        products: products,
        period: period,
      );

      // Generate revenue analytics
      final revenueAnalytics = await _analyticsService.calculateRevenueAnalytics(
        invoices: invoices,
        period: period,
      );

      // Generate cash flow data
      final cashFlowData = await _analyticsService.calculateCashFlowData(
        invoices: invoices,
        expenses: [], // TODO: Add expenses
        period: period,
      );

      // Generate customer insights
      final customerInsights = await _analyticsService.calculateCustomerInsights(
        customers: customers,
        invoices: invoices,
        period: period,
      );

      // Generate inventory overview
      final inventoryOverview = await _analyticsService.calculateInventoryOverview(
        products: products,
      );

      // Create dashboard configuration
      final config = DashboardConfig(
        id: 'default_config',
        name: 'Default Dashboard',
        enabledKPIs: kpis.map((kpi) => kpi.id).toList(),
        chartSettings: {},
        defaultTimePeriod: period,
        autoRefresh: true,
        refreshInterval: 300, // 5 minutes
        customSettings: {},
        lastModified: DateTime.now(),
      );

      // Create dashboard data
      final dashboardData = DashboardData(
        id: 'dashboard_${period.name}_${DateTime.now().millisecondsSinceEpoch}',
        kpis: kpis,
        revenueAnalytics: revenueAnalytics,
        cashFlowData: cashFlowData,
        customerInsights: customerInsights,
        inventoryOverview: inventoryOverview,
        taxComplianceStatus: null, // TODO: Implement
        anomalies: [], // Will be loaded separately
        currentPeriod: period,
        lastUpdated: DateTime.now(),
        config: config,
      );

      state = AsyncValue.data(dashboardData);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Refresh specific KPI
  Future<void> refreshKPI(String kpiId) async {
    final currentState = state;
    if (currentState is! AsyncData<DashboardData>) return;

    try {
      // TODO: Implement specific KPI refresh
      await loadDashboardData(currentState.value.currentPeriod);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Update dashboard configuration
  Future<void> updateConfiguration(DashboardConfig newConfig) async {
    final currentState = state;
    if (currentState is! AsyncData<DashboardData>) return;

    try {
      final updatedData = DashboardData(
        id: currentState.value.id,
        kpis: currentState.value.kpis,
        revenueAnalytics: currentState.value.revenueAnalytics,
        cashFlowData: currentState.value.cashFlowData,
        customerInsights: currentState.value.customerInsights,
        inventoryOverview: currentState.value.inventoryOverview,
        taxComplianceStatus: currentState.value.taxComplianceStatus,
        anomalies: currentState.value.anomalies,
        currentPeriod: currentState.value.currentPeriod,
        lastUpdated: currentState.value.lastUpdated,
        config: newConfig,
      );

      state = AsyncValue.data(updatedData);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

/// Dashboard configuration state notifier
class DashboardConfigNotifier extends StateNotifier<DashboardConfig> {
  DashboardConfigNotifier()
      : super(DashboardConfig(
          id: 'default_config',
          name: 'Default Dashboard',
          enabledKPIs: [],
          chartSettings: {},
          defaultTimePeriod: TimePeriod.thisMonth,
          autoRefresh: true,
          refreshInterval: 300,
          customSettings: {},
          lastModified: DateTime.now(),
        ));

  /// Update dashboard configuration
  void updateConfig(DashboardConfig newConfig) {
    state = newConfig;
  }

  /// Toggle auto refresh
  void toggleAutoRefresh() {
    state = DashboardConfig(
      id: state.id,
      name: state.name,
      enabledKPIs: state.enabledKPIs,
      chartSettings: state.chartSettings,
      defaultTimePeriod: state.defaultTimePeriod,
      autoRefresh: !state.autoRefresh,
      refreshInterval: state.refreshInterval,
      customSettings: state.customSettings,
      lastModified: DateTime.now(),
    );
  }

  /// Update refresh interval
  void updateRefreshInterval(int seconds) {
    state = DashboardConfig(
      id: state.id,
      name: state.name,
      enabledKPIs: state.enabledKPIs,
      chartSettings: state.chartSettings,
      defaultTimePeriod: state.defaultTimePeriod,
      autoRefresh: state.autoRefresh,
      refreshInterval: seconds,
      customSettings: state.customSettings,
      lastModified: DateTime.now(),
    );
  }

  /// Enable/disable specific KPI
  void toggleKPI(String kpiId) {
    final enabledKPIs = List<String>.from(state.enabledKPIs);
    
    if (enabledKPIs.contains(kpiId)) {
      enabledKPIs.remove(kpiId);
    } else {
      enabledKPIs.add(kpiId);
    }

    state = DashboardConfig(
      id: state.id,
      name: state.name,
      enabledKPIs: enabledKPIs,
      chartSettings: state.chartSettings,
      defaultTimePeriod: state.defaultTimePeriod,
      autoRefresh: state.autoRefresh,
      refreshInterval: state.refreshInterval,
      customSettings: state.customSettings,
      lastModified: DateTime.now(),
    );
  }
}

/// Dashboard update model for real-time updates
class DashboardUpdate {
  final DateTime timestamp;
  final String type;
  final Map<String, dynamic> data;

  DashboardUpdate({
    required this.timestamp,
    required this.type,
    required this.data,
  });
}

/// Export data provider
final exportDataProvider = Provider<ExportService>((ref) {
  return ExportService();
});

/// Export service for dashboard data
class ExportService {
  /// Export dashboard data to PDF
  Future<void> exportToPDF(DashboardData data, String filePath) async {
    // TODO: Implement PDF export
    throw UnimplementedError('PDF export not implemented');
  }

  /// Export dashboard data to Excel
  Future<void> exportToExcel(DashboardData data, String filePath) async {
    // TODO: Implement Excel export
    throw UnimplementedError('Excel export not implemented');
  }

  /// Export specific chart data to CSV
  Future<void> exportChartToCSV(List<DataPoint> data, String filePath) async {
    // TODO: Implement CSV export
    throw UnimplementedError('CSV export not implemented');
  }
}

// Placeholder repository interfaces
abstract class InvoiceRepository {
  Future<List<CRDTInvoiceEnhanced>> getAllInvoices();
}

abstract class CustomerRepository {
  Future<List<Customer>> getAllCustomers();
}

abstract class ProductRepository {
  Future<List<Product>> getAllProducts();
}

// Recent activities provider with mock data
final recentActivitiesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  // Return mock data for development
  return [
    {
      'type': 'invoice_created',
      'title': 'New Invoice Created',
      'description': 'Invoice INV-2025-001 for ACME Corp',
      'amount': 2500.00,
      'timestamp': DateTime.now().subtract(const Duration(hours: 2)).millisecondsSinceEpoch,
      'icon': 'receipt',
      'color': '#4CAF50',
    },
    {
      'type': 'payment_received',
      'title': 'Payment Received',
      'description': 'Payment for Invoice INV-2024-156',
      'amount': 1200.00,
      'timestamp': DateTime.now().subtract(const Duration(hours: 4)).millisecondsSinceEpoch,
      'icon': 'payment',
      'color': '#2196F3',
    },
    {
      'type': 'customer_added',
      'title': 'New Customer Added',
      'description': 'TechStart Solutions added to customers',
      'timestamp': DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
      'icon': 'people',
      'color': '#FF9800',
    },
  ];
});


// Simple mock dashboard data provider for development
final mockDashboardDataProvider = StateNotifierProvider<MockDashboardDataNotifier, AsyncValue<DashboardData>>((ref) {
  return MockDashboardDataNotifier();
});

class MockDashboardDataNotifier extends StateNotifier<AsyncValue<DashboardData>> {
  MockDashboardDataNotifier() : super(const AsyncValue.loading()) {
    _loadMockData();
  }

  Future<void> refreshData(TimePeriod period) async {
    state = const AsyncValue.loading();
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay
    _loadMockData(period: period);
  }

  void _loadMockData({TimePeriod period = TimePeriod.thisMonth}) {
    final now = DateTime.now();
    
    // Create mock revenue data
    final revenueByDay = <DataPoint>[];
    for (int i = 0; i < 30; i++) {
      revenueByDay.add(DataPoint(
        timestamp: now.subtract(Duration(days: 29 - i)),
        value: 500 + (i * 100) + (i % 7 * 200), // Varying daily revenue
      ));
    }

    // Create mock customer growth data
    final customerGrowth = <DataPoint>[];
    for (int i = 0; i < 30; i++) {
      customerGrowth.add(DataPoint(
        timestamp: now.subtract(Duration(days: 29 - i)),
        value: (50 + i * 2).toDouble(), // Growing customer base
      ));
    }

    // Create mock cash flow data
    final cashFlowData = <DataPoint>[];
    double runningBalance = 10000;
    for (int i = 0; i < 30; i++) {
      final dailyFlow = 200 + (i % 5 * 100) - (i % 3 * 50);
      runningBalance += dailyFlow;
      cashFlowData.add(DataPoint(
        timestamp: now.subtract(Duration(days: 29 - i)),
        value: runningBalance,
      ));
    }

    // Create mock top customers
    final revenueByCustomer = [
      DataPoint(
        timestamp: now,
        value: 15000,
        label: 'ACME Corporation',
      ),
      DataPoint(
        timestamp: now,
        value: 12000,
        label: 'TechStart Solutions',
      ),
      DataPoint(
        timestamp: now,
        value: 8500,
        label: 'Global Enterprises',
      ),
      DataPoint(
        timestamp: now,
        value: 6200,
        label: 'Innovation Labs',
      ),
      DataPoint(
        timestamp: now,
        value: 4800,
        label: 'Digital Works',
      ),
    ];

    // Create KPIs
    final kpis = [
      KPI(
        id: 'total_revenue',
        title: 'Total Revenue',
        description: 'Total revenue from paid invoices',
        type: KPIType.revenue,
        currentValue: 45800,
        previousValue: 42300,
        unit: 'SGD',
        prefix: '\$',
        trend: TrendDirection.up,
        percentageChange: 8.3,
        lastUpdated: now,
        historicalData: revenueByDay,
        iconName: 'trending_up',
        color: '#4CAF50',
      ),
      KPI(
        id: 'net_cash_flow',
        title: 'Net Cash Flow',
        description: 'Net cash flow from operations',
        type: KPIType.cashFlow,
        currentValue: runningBalance,
        unit: 'SGD',
        prefix: '\$',
        trend: TrendDirection.up,
        percentageChange: 12.5,
        lastUpdated: now,
        historicalData: cashFlowData,
        iconName: 'account_balance',
        color: '#2196F3',
      ),
      KPI(
        id: 'total_customers',
        title: 'Total Customers',
        description: 'Total number of customers',
        type: KPIType.customers,
        currentValue: 108,
        previousValue: 95,
        unit: 'customers',
        trend: TrendDirection.up,
        percentageChange: 13.7,
        lastUpdated: now,
        historicalData: customerGrowth,
        iconName: 'people',
        color: '#FF9800',
      ),
      KPI(
        id: 'outstanding_receivables',
        title: 'Outstanding Receivables',
        description: 'Amount pending from customers',
        type: KPIType.revenue,
        currentValue: 8200,
        previousValue: 9100,
        unit: 'SGD',
        prefix: '\$',
        trend: TrendDirection.down, // Good - receivables are decreasing
        percentageChange: -9.9,
        lastUpdated: now,
        historicalData: [],
        iconName: 'account_balance_wallet',
        color: '#F44336',
      ),
      KPI(
        id: 'average_order_value',
        title: 'Average Order Value',
        description: 'Average value per invoice',
        type: KPIType.revenue,
        currentValue: 2840,
        previousValue: 2650,
        unit: 'SGD',
        prefix: '\$',
        trend: TrendDirection.up,
        percentageChange: 7.2,
        lastUpdated: now,
        historicalData: [],
        iconName: 'receipt',
        color: '#9C27B0',
      ),
      KPI(
        id: 'overdue_invoices',
        title: 'Overdue Invoices',
        description: 'Number of overdue invoices',
        type: KPIType.revenue,
        currentValue: 3,
        previousValue: 5,
        unit: 'invoices',
        trend: TrendDirection.down, // Good - fewer overdue invoices
        percentageChange: -40.0,
        lastUpdated: now,
        historicalData: [],
        iconName: 'warning',
        color: '#FF5722',
      ),
    ];

    // Create mock analytics
    final revenueAnalytics = RevenueAnalytics(
      id: 'revenue_${now.millisecondsSinceEpoch}',
      period: period,
      totalRevenue: 45800,
      recurringRevenue: 12000,
      oneTimeRevenue: 33800,
      revenueByDay: revenueByDay,
      revenueByProduct: [],
      revenueByCustomer: revenueByCustomer,
      revenueByCategory: {
        'Consulting': 18000,
        'Software': 15200,
        'Support': 8300,
        'Training': 4300,
      },
      averageOrderValue: 2840,
      totalTransactions: 16,
      growthRate: 8.3,
      generatedAt: now,
    );

    final cashFlow = CashFlowData(
      id: 'cashflow_${now.millisecondsSinceEpoch}',
      period: period,
      openingBalance: 10000,
      closingBalance: runningBalance,
      totalInflow: 48200,
      totalOutflow: 15000,
      netCashFlow: 33200,
      dailyCashFlow: cashFlowData,
      inflowByCategory: {
        'Invoice Payments': 45800,
        'Other Income': 2400,
      },
      outflowByCategory: {
        'Operating Expenses': 8000,
        'Office Rent': 3500,
        'Utilities': 1200,
        'Other': 2300,
      },
      forecasts: [],
      generatedAt: now,
    );

    final customerInsights = CustomerInsights(
      id: 'customers_${now.millisecondsSinceEpoch}',
      period: period,
      totalCustomers: 108,
      newCustomers: 13,
      activeCustomers: 67,
      churned: 2,
      churnRate: 1.9,
      acquisitionRate: 12.0,
      retentionRate: 98.1,
      averageLifetimeValue: 8500,
      customerGrowth: customerGrowth,
      customersBySegment: {
        'Enterprise': 25,
        'SMB': 58,
        'Startup': 25,
      },
      revenueBySegment: {
        'Enterprise': 28000,
        'SMB': 15800,
        'Startup': 2000,
      },
      behaviorInsights: [],
      generatedAt: now,
    );

    final mockData = DashboardData(
      id: 'dashboard_${now.millisecondsSinceEpoch}',
      kpis: kpis,
      revenueAnalytics: revenueAnalytics,
      cashFlowData: cashFlow,
      customerInsights: customerInsights,
      inventoryOverview: null,
      taxComplianceStatus: null,
      anomalies: [],
      currentPeriod: period,
      lastUpdated: now,
      config: DashboardConfig(
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
        refreshInterval: 300,
        customSettings: {},
        lastModified: now,
      ),
    );

    state = AsyncValue.data(mockData);
  }
}

// Mock repository implementations for dashboard functionality
class MockInvoiceRepository implements InvoiceRepository {
  @override
  Future<List<CRDTInvoiceEnhanced>> getAllInvoices() async {
    // Return empty list for now - dashboard will use mock data from providers
    return [];
  }
}

class MockCustomerRepository implements CustomerRepository {
  @override
  Future<List<Customer>> getAllCustomers() async {
    // Return empty list for now - dashboard will use mock data from providers
    return [];
  }
}

class MockProductRepository implements ProductRepository {
  @override
  Future<List<Product>> getAllProducts() async {
    // Return empty list for now - dashboard will use mock data from providers
    return [];
  }
}
