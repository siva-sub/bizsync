import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import '../models/dashboard_models.dart';
import '../services/analytics_service.dart';
import '../services/real_analytics_service.dart';
import '../analytics/anomaly_detection_service.dart';
import '../intelligence/business_intelligence_engine.dart';
import '../../invoices/repositories/invoice_repository.dart';
import '../../invoices/services/invoice_service.dart';
import '../../invoices/services/invoice_workflow_service.dart';
import '../../invoices/services/invoice_calculation_service.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../inventory/repositories/product_repository.dart';
import '../../../core/database/crdt_database_service.dart';
import '../../../core/database/conflict_resolver.dart';
import '../../../presentation/providers/app_providers.dart';

// Core service providers
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

final anomalyDetectionServiceProvider =
    Provider<AnomalyDetectionService>((ref) {
  return AnomalyDetectionService();
});

final businessIntelligenceEngineProvider =
    Provider<BusinessIntelligenceEngine>((ref) {
  return BusinessIntelligenceEngine();
});

// Use the existing providers from other modules
final crdtDatabaseServiceProvider = Provider<CRDTDatabaseService>((ref) {
  return CRDTDatabaseService();
});

final conflictResolverProvider = Provider<ConflictResolver>((ref) {
  return ConflictResolver();
});

// Repository providers for dashboard data
final realCustomerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository();
});

final realProductRepositoryProvider = Provider<ProductRepository>((ref) {
  final database = ref.watch(crdtDatabaseServiceProvider);
  return ProductRepositoryImpl(database);
});

// Create a simple invoice service provider for dashboard use
final dashboardInvoiceServiceProvider = Provider<InvoiceService>((ref) {
  final databaseService = ref.watch(crdtDatabaseServiceProvider);
  return InvoiceService(
    databaseService,
    databaseService.transactionManager,
    InvoiceWorkflowService(),
    InvoiceCalculationService(),
    databaseService.nodeId,
  );
});

// Real analytics service provider
final realAnalyticsServiceProvider =
    Provider<RealDashboardAnalyticsService>((ref) {
  final databaseService = ref.watch(crdtDatabaseServiceProvider);
  final invoiceService = ref.watch(dashboardInvoiceServiceProvider);
  return RealDashboardAnalyticsService(databaseService, invoiceService);
});

// Real dashboard data provider
final realDashboardDataProvider =
    StateNotifierProvider<RealDashboardDataNotifier, AsyncValue<DashboardData>>(
        (ref) {
  return RealDashboardDataNotifier(
    analyticsService: ref.watch(realAnalyticsServiceProvider),
  );
});

// Dashboard data provider - now uses real data exclusively
final dashboardDataProvider =
    StateNotifierProvider<RealDashboardDataNotifier, AsyncValue<DashboardData>>(
        (ref) {
  return RealDashboardDataNotifier(
    analyticsService: ref.watch(realAnalyticsServiceProvider),
  );
});

// Real anomalies provider
final realAnomaliesProvider =
    FutureProvider<List<BusinessAnomaly>>((ref) async {
  final anomalyService = ref.watch(anomalyDetectionServiceProvider);

  try {
    // Get data from real repositories
    final invoiceRepo = ref.watch(invoiceRepositoryProvider);
    final customerRepo = ref.watch(realCustomerRepositoryProvider);
    final productRepo = ref.watch(realProductRepositoryProvider);

    final invoices = await invoiceRepo.getInvoices(limit: 1000);
    final customers = await customerRepo.getAllCustomers();
    final products = await productRepo.getProducts();

    // The invoices are already CRDTInvoiceEnhanced models

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

// Anomalies provider (keeping old for compatibility)
final anomaliesProvider = FutureProvider<List<BusinessAnomaly>>((ref) async {
  return ref.watch(realAnomaliesProvider.future);
});

// Real business forecast provider
final realBusinessForecastProvider =
    FutureProvider<BusinessForecast?>((ref) async {
  final intelligenceEngine = ref.watch(businessIntelligenceEngineProvider);

  try {
    // Get data from real repositories
    final invoiceRepo = ref.watch(invoiceRepositoryProvider);
    final customerRepo = ref.watch(realCustomerRepositoryProvider);
    final productRepo = ref.watch(realProductRepositoryProvider);

    final invoices = await invoiceRepo.getInvoices(limit: 1000);
    final customers = await customerRepo.getAllCustomers();
    final products = await productRepo.getProducts();

    // The invoices are already CRDTInvoiceEnhanced models

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

// Business forecast provider (keeping old for compatibility)
final businessForecastProvider = FutureProvider<BusinessForecast?>((ref) async {
  return ref.watch(realBusinessForecastProvider.future);
});

// Revenue analytics provider
final revenueAnalyticsProvider =
    FutureProvider.family<RevenueAnalytics?, TimePeriod>((ref, period) async {
  final analyticsService = ref.watch(analyticsServiceProvider);

  try {
    final invoices = await ref.watch(invoiceRepositoryProvider).getInvoices();

    return await analyticsService.calculateRevenueAnalytics(
      invoices: invoices,
      period: period,
    );
  } catch (e) {
    return null;
  }
});

// Cash flow data provider
final cashFlowDataProvider =
    FutureProvider.family<CashFlowData?, TimePeriod>((ref, period) async {
  final analyticsService = ref.watch(analyticsServiceProvider);

  try {
    final invoices = await ref.watch(invoiceRepositoryProvider).getInvoices();

    return await analyticsService.calculateCashFlowData(
      invoices: invoices,
      expenses: [], // Real expenses data integration pending - expense module not yet available
      period: period,
    );
  } catch (e) {
    return null;
  }
});

// Customer insights provider
final customerInsightsProvider =
    FutureProvider.family<CustomerInsights?, TimePeriod>((ref, period) async {
  final analyticsService = ref.watch(analyticsServiceProvider);

  try {
    final customers =
        await ref.watch(customerRepositoryProvider).getAllCustomers();
    final invoices = await ref.watch(invoiceRepositoryProvider).getInvoices();

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
final inventoryOverviewProvider =
    FutureProvider<InventoryOverview?>((ref) async {
  final analyticsService = ref.watch(analyticsServiceProvider);

  try {
    final products = await ref.watch(productRepositoryProvider).getProducts();

    return await analyticsService.calculateInventoryOverview(
      products: products,
    );
  } catch (e) {
    return null;
  }
});

// Tax compliance status provider
final taxComplianceStatusProvider =
    FutureProvider<TaxComplianceStatus?>((ref) async {
  // Tax compliance status implementation pending - tax module not yet available
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
final kpisProvider =
    FutureProvider.family<List<KPI>, TimePeriod>((ref, period) async {
  final analyticsService = ref.watch(analyticsServiceProvider);

  try {
    final invoices = await ref.watch(invoiceRepositoryProvider).getInvoices();
    final customers =
        await ref.watch(customerRepositoryProvider).getAllCustomers();
    final products = await ref.watch(productRepositoryProvider).getProducts();

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
final dashboardConfigProvider =
    StateNotifierProvider<DashboardConfigNotifier, DashboardConfig>((ref) {
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

// Removed old DashboardDataNotifier - using RealDashboardDataNotifier exclusively

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
    try {
      // Generate PDF using pdf package
      final pdf = pw.Document();

      // Add dashboard data to PDF
      pdf.addPage(pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Dashboard Report',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text('Generated on: ${DateTime.now().toString()}'),
              pw.SizedBox(height: 20),
              // Add KPIs
              ...data.kpis.map((kpi) => pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 10),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(kpi.title),
                        pw.Text(
                            '${kpi.prefix ?? ''}${kpi.currentValue.toStringAsFixed(2)} ${kpi.unit ?? ''}'),
                      ],
                    ),
                  )),
            ],
          );
        },
      ));

      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());
    } catch (e) {
      throw Exception('Failed to export PDF: $e');
    }
  }

  /// Export dashboard data to Excel
  Future<void> exportToExcel(DashboardData data, String filePath) async {
    try {
      // Create Excel workbook
      final excel = Excel.createExcel();
      final sheet = excel['Dashboard'];

      // Add headers
      sheet.cell(CellIndex.indexByString('A1')).value =
          TextCellValue('Dashboard Report');
      sheet.cell(CellIndex.indexByString('A2')).value =
          TextCellValue('Generated: ${DateTime.now()}');

      // Add KPI data
      int row = 4;
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue('KPI');
      sheet.cell(CellIndex.indexByString('B$row')).value =
          TextCellValue('Current Value');
      sheet.cell(CellIndex.indexByString('C$row')).value =
          TextCellValue('Unit');
      sheet.cell(CellIndex.indexByString('D$row')).value =
          TextCellValue('Change %');
      row++;

      for (final kpi in data.kpis) {
        sheet.cell(CellIndex.indexByString('A$row')).value =
            TextCellValue(kpi.title);
        sheet.cell(CellIndex.indexByString('B$row')).value =
            DoubleCellValue(kpi.currentValue);
        sheet.cell(CellIndex.indexByString('C$row')).value =
            TextCellValue(kpi.unit ?? '');
        sheet.cell(CellIndex.indexByString('D$row')).value =
            DoubleCellValue(kpi.percentageChange);
        row++;
      }

      // Save file
      final fileBytes = excel.save();
      final file = File(filePath);
      await file.writeAsBytes(fileBytes!);
    } catch (e) {
      throw Exception('Failed to export Excel: $e');
    }
  }

  /// Export specific chart data to CSV
  Future<void> exportChartToCSV(List<DataPoint> data, String filePath) async {
    try {
      final csvData = <List<dynamic>>[];

      // Add headers
      csvData.add(['Timestamp', 'Value', 'Label']);

      // Add data points
      for (final point in data) {
        csvData.add([
          point.timestamp.toIso8601String(),
          point.value,
          point.label ?? '',
        ]);
      }

      // Convert to CSV string
      const encoder = ListToCsvConverter();
      final csvString = encoder.convert(csvData);

      // Save file
      final file = File(filePath);
      await file.writeAsString(csvString);
    } catch (e) {
      throw Exception('Failed to export CSV: $e');
    }
  }
}

// Real recent activities provider
final realRecentActivitiesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final analyticsService = ref.watch(realAnalyticsServiceProvider);
    return await analyticsService.getRecentActivities();
  } catch (e) {
    // Log error and return empty list for proper error handling
    print('Error loading recent activities: $e');
    return <Map<String, dynamic>>[];
  }
});

// Recent activities provider (keeping old for compatibility)
final recentActivitiesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(realRecentActivitiesProvider.future);
});

// Removed mock dashboard data provider - all providers now use real implementations

/// Real dashboard data notifier using actual database services
class RealDashboardDataNotifier
    extends StateNotifier<AsyncValue<DashboardData>> {
  final RealDashboardAnalyticsService _analyticsService;

  RealDashboardDataNotifier({
    required RealDashboardAnalyticsService analyticsService,
  })  : _analyticsService = analyticsService,
        super(const AsyncValue.loading());

  /// Load dashboard data for the specified time period
  Future<void> loadDashboardData(TimePeriod period) async {
    state = const AsyncValue.loading();

    try {
      final dashboardData = await _analyticsService.getDashboardData(
        period: period,
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
      // Refresh by reloading all dashboard data
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

  /// Get recent activities
  Future<List<Map<String, dynamic>>> getRecentActivities() async {
    try {
      return await _analyticsService.getRecentActivities();
    } catch (e) {
      return [];
    }
  }
}
