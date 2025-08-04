import 'package:json_annotation/json_annotation.dart';

part 'dashboard_models.g.dart';

/// Enumeration for different types of KPI metrics
enum KPIType {
  revenue,
  profit,
  expenses,
  customers,
  inventory,
  cashFlow,
  taxCompliance,
  employeePerformance,
  customerSatisfaction,
  marketShare
}

/// Enumeration for time periods
enum TimePeriod {
  today,
  yesterday,
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
  thisQuarter,
  lastQuarter,
  thisYear,
  lastYear,
  custom
}

/// Enumeration for chart types
enum ChartType {
  line,
  bar,
  pie,
  donut,
  area,
  scatter,
  gauge,
  heatmap,
  candlestick,
  treemap
}

/// Enumeration for trend directions
enum TrendDirection { up, down, stable, volatile }

/// Data point for charts and analytics
@JsonSerializable()
class DataPoint {
  final DateTime timestamp;
  final double value;
  final String? label;
  final Map<String, dynamic>? metadata;

  const DataPoint({
    required this.timestamp,
    required this.value,
    this.label,
    this.metadata,
  });

  factory DataPoint.fromJson(Map<String, dynamic> json) =>
      _$DataPointFromJson(json);

  Map<String, dynamic> toJson() => _$DataPointToJson(this);
}

/// KPI (Key Performance Indicator) model
@JsonSerializable()
class KPI {
  final String id;
  final String title;
  final String description;
  final KPIType type;
  final double currentValue;
  final double? previousValue;
  final double? targetValue;
  final String unit;
  final String? prefix;
  final String? suffix;
  final TrendDirection trend;
  final double percentageChange;
  final DateTime lastUpdated;
  final List<DataPoint> historicalData;
  final String? iconName;
  final String? color;

  const KPI({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.currentValue,
    this.previousValue,
    this.targetValue,
    required this.unit,
    this.prefix,
    this.suffix,
    required this.trend,
    required this.percentageChange,
    required this.lastUpdated,
    required this.historicalData,
    this.iconName,
    this.color,
  });

  factory KPI.fromJson(Map<String, dynamic> json) => _$KPIFromJson(json);

  Map<String, dynamic> toJson() => _$KPIToJson(this);

  /// Calculate achievement percentage against target
  double get achievementPercentage {
    if (targetValue == null || targetValue == 0) return 0.0;
    return (currentValue / targetValue!) * 100;
  }

  /// Get formatted value with prefix/suffix
  String get formattedValue {
    String value = currentValue.toStringAsFixed(
      unit == '%' || unit == 'ratio' ? 2 : 0,
    );

    String result = '';
    if (prefix != null) result += prefix!;
    result += value;
    if (suffix != null) result += suffix!;
    if (unit.isNotEmpty && suffix == null) result += ' $unit';

    return result;
  }
}

/// Revenue analytics data model
@JsonSerializable()
class RevenueAnalytics {
  final String id;
  final TimePeriod period;
  final double totalRevenue;
  final double recurringRevenue;
  final double oneTimeRevenue;
  final List<DataPoint> revenueByDay;
  final List<DataPoint> revenueByProduct;
  final List<DataPoint> revenueByCustomer;
  final Map<String, double> revenueByCategory;
  final double averageOrderValue;
  final int totalTransactions;
  final double growthRate;
  final DateTime generatedAt;

  const RevenueAnalytics({
    required this.id,
    required this.period,
    required this.totalRevenue,
    required this.recurringRevenue,
    required this.oneTimeRevenue,
    required this.revenueByDay,
    required this.revenueByProduct,
    required this.revenueByCustomer,
    required this.revenueByCategory,
    required this.averageOrderValue,
    required this.totalTransactions,
    required this.growthRate,
    required this.generatedAt,
  });

  factory RevenueAnalytics.fromJson(Map<String, dynamic> json) =>
      _$RevenueAnalyticsFromJson(json);

  Map<String, dynamic> toJson() => _$RevenueAnalyticsToJson(this);
}

/// Cash flow data model
@JsonSerializable()
class CashFlowData {
  final String id;
  final TimePeriod period;
  final double openingBalance;
  final double closingBalance;
  final double totalInflow;
  final double totalOutflow;
  final double netCashFlow;
  final List<DataPoint> dailyCashFlow;
  final Map<String, double> inflowByCategory;
  final Map<String, double> outflowByCategory;
  final List<CashFlowForecast> forecasts;
  final DateTime generatedAt;

  const CashFlowData({
    required this.id,
    required this.period,
    required this.openingBalance,
    required this.closingBalance,
    required this.totalInflow,
    required this.totalOutflow,
    required this.netCashFlow,
    required this.dailyCashFlow,
    required this.inflowByCategory,
    required this.outflowByCategory,
    required this.forecasts,
    required this.generatedAt,
  });

  factory CashFlowData.fromJson(Map<String, dynamic> json) =>
      _$CashFlowDataFromJson(json);

  Map<String, dynamic> toJson() => _$CashFlowDataToJson(this);
}

/// Cash flow forecast model
@JsonSerializable()
class CashFlowForecast {
  final DateTime date;
  final double predictedInflow;
  final double predictedOutflow;
  final double predictedBalance;
  final double confidence;
  final String? scenario;

  const CashFlowForecast({
    required this.date,
    required this.predictedInflow,
    required this.predictedOutflow,
    required this.predictedBalance,
    required this.confidence,
    this.scenario,
  });

  factory CashFlowForecast.fromJson(Map<String, dynamic> json) =>
      _$CashFlowForecastFromJson(json);

  Map<String, dynamic> toJson() => _$CashFlowForecastToJson(this);
}

/// Customer insights data model
@JsonSerializable()
class CustomerInsights {
  final String id;
  final TimePeriod period;
  final int totalCustomers;
  final int newCustomers;
  final int activeCustomers;
  final int churned;
  final double churnRate;
  final double acquisitionRate;
  final double retentionRate;
  final double averageLifetimeValue;
  final List<DataPoint> customerGrowth;
  final Map<String, double> customersBySegment;
  final Map<String, double> revenueBySegment;
  final List<CustomerBehaviorInsight> behaviorInsights;
  final DateTime generatedAt;

  const CustomerInsights({
    required this.id,
    required this.period,
    required this.totalCustomers,
    required this.newCustomers,
    required this.activeCustomers,
    required this.churned,
    required this.churnRate,
    required this.acquisitionRate,
    required this.retentionRate,
    required this.averageLifetimeValue,
    required this.customerGrowth,
    required this.customersBySegment,
    required this.revenueBySegment,
    required this.behaviorInsights,
    required this.generatedAt,
  });

  factory CustomerInsights.fromJson(Map<String, dynamic> json) =>
      _$CustomerInsightsFromJson(json);

  Map<String, dynamic> toJson() => _$CustomerInsightsToJson(this);
}

/// Customer behavior insight model
@JsonSerializable()
class CustomerBehaviorInsight {
  final String insight;
  final String category;
  final double impact;
  final String recommendation;
  final Map<String, dynamic>? data;

  const CustomerBehaviorInsight({
    required this.insight,
    required this.category,
    required this.impact,
    required this.recommendation,
    this.data,
  });

  factory CustomerBehaviorInsight.fromJson(Map<String, dynamic> json) =>
      _$CustomerBehaviorInsightFromJson(json);

  Map<String, dynamic> toJson() => _$CustomerBehaviorInsightToJson(this);
}

/// Inventory overview data model
@JsonSerializable()
class InventoryOverview {
  final String id;
  final int totalProducts;
  final int lowStockProducts;
  final int outOfStockProducts;
  final double totalInventoryValue;
  final double averageStockLevel;
  final Map<String, int> stockByCategory;
  final List<ProductStockAlert> stockAlerts;
  final List<DataPoint> inventoryTurnover;
  final DateTime lastUpdated;

  const InventoryOverview({
    required this.id,
    required this.totalProducts,
    required this.lowStockProducts,
    required this.outOfStockProducts,
    required this.totalInventoryValue,
    required this.averageStockLevel,
    required this.stockByCategory,
    required this.stockAlerts,
    required this.inventoryTurnover,
    required this.lastUpdated,
  });

  factory InventoryOverview.fromJson(Map<String, dynamic> json) =>
      _$InventoryOverviewFromJson(json);

  Map<String, dynamic> toJson() => _$InventoryOverviewToJson(this);
}

/// Product stock alert model
@JsonSerializable()
class ProductStockAlert {
  final String productId;
  final String productName;
  final int currentStock;
  final int minStock;
  final String severity; // low, critical, out_of_stock
  final DateTime alertDate;

  const ProductStockAlert({
    required this.productId,
    required this.productName,
    required this.currentStock,
    required this.minStock,
    required this.severity,
    required this.alertDate,
  });

  factory ProductStockAlert.fromJson(Map<String, dynamic> json) =>
      _$ProductStockAlertFromJson(json);

  Map<String, dynamic> toJson() => _$ProductStockAlertToJson(this);
}

/// Tax compliance status model
@JsonSerializable()
class TaxComplianceStatus {
  final String id;
  final double complianceScore;
  final List<TaxObligation> upcomingObligations;
  final List<TaxAlert> alerts;
  final Map<String, double> taxLiabilities;
  final double totalTaxPaid;
  final double pendingTaxes;
  final DateTime lastAssessment;

  const TaxComplianceStatus({
    required this.id,
    required this.complianceScore,
    required this.upcomingObligations,
    required this.alerts,
    required this.taxLiabilities,
    required this.totalTaxPaid,
    required this.pendingTaxes,
    required this.lastAssessment,
  });

  factory TaxComplianceStatus.fromJson(Map<String, dynamic> json) =>
      _$TaxComplianceStatusFromJson(json);

  Map<String, dynamic> toJson() => _$TaxComplianceStatusToJson(this);
}

/// Tax obligation model
@JsonSerializable()
class TaxObligation {
  final String id;
  final String type;
  final String description;
  final DateTime dueDate;
  final double estimatedAmount;
  final String status;
  final int daysUntilDue;

  const TaxObligation({
    required this.id,
    required this.type,
    required this.description,
    required this.dueDate,
    required this.estimatedAmount,
    required this.status,
    required this.daysUntilDue,
  });

  factory TaxObligation.fromJson(Map<String, dynamic> json) =>
      _$TaxObligationFromJson(json);

  Map<String, dynamic> toJson() => _$TaxObligationToJson(this);
}

/// Tax alert model
@JsonSerializable()
class TaxAlert {
  final String id;
  final String title;
  final String message;
  final String severity;
  final String category;
  final DateTime createdAt;
  final bool isRead;

  const TaxAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.category,
    required this.createdAt,
    required this.isRead,
  });

  factory TaxAlert.fromJson(Map<String, dynamic> json) =>
      _$TaxAlertFromJson(json);

  Map<String, dynamic> toJson() => _$TaxAlertToJson(this);
}

/// Business anomaly detection model
@JsonSerializable()
class BusinessAnomaly {
  final String id;
  final String type;
  final String description;
  final double severity;
  final DateTime detectedAt;
  final Map<String, dynamic> context;
  final List<String> possibleCauses;
  final List<String> recommendations;
  final bool isResolved;

  const BusinessAnomaly({
    required this.id,
    required this.type,
    required this.description,
    required this.severity,
    required this.detectedAt,
    required this.context,
    required this.possibleCauses,
    required this.recommendations,
    required this.isResolved,
  });

  factory BusinessAnomaly.fromJson(Map<String, dynamic> json) =>
      _$BusinessAnomalyFromJson(json);

  Map<String, dynamic> toJson() => _$BusinessAnomalyToJson(this);
}

/// Dashboard configuration model
@JsonSerializable()
class DashboardConfig {
  final String id;
  final String name;
  final List<String> enabledKPIs;
  final Map<String, dynamic> chartSettings;
  final TimePeriod defaultTimePeriod;
  final bool autoRefresh;
  final int refreshInterval; // in seconds
  final Map<String, dynamic> customSettings;
  final DateTime lastModified;

  const DashboardConfig({
    required this.id,
    required this.name,
    required this.enabledKPIs,
    required this.chartSettings,
    required this.defaultTimePeriod,
    required this.autoRefresh,
    required this.refreshInterval,
    required this.customSettings,
    required this.lastModified,
  });

  factory DashboardConfig.fromJson(Map<String, dynamic> json) =>
      _$DashboardConfigFromJson(json);

  Map<String, dynamic> toJson() => _$DashboardConfigToJson(this);
}

/// Main dashboard data model that aggregates all dashboard information
@JsonSerializable()
class DashboardData {
  final String id;
  final List<KPI> kpis;
  final RevenueAnalytics? revenueAnalytics;
  final CashFlowData? cashFlowData;
  final CustomerInsights? customerInsights;
  final InventoryOverview? inventoryOverview;
  final TaxComplianceStatus? taxComplianceStatus;
  final List<BusinessAnomaly> anomalies;
  final TimePeriod currentPeriod;
  final DateTime lastUpdated;
  final DashboardConfig config;

  const DashboardData({
    required this.id,
    required this.kpis,
    this.revenueAnalytics,
    this.cashFlowData,
    this.customerInsights,
    this.inventoryOverview,
    this.taxComplianceStatus,
    required this.anomalies,
    required this.currentPeriod,
    required this.lastUpdated,
    required this.config,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) =>
      _$DashboardDataFromJson(json);

  Map<String, dynamic> toJson() => _$DashboardDataToJson(this);
}
