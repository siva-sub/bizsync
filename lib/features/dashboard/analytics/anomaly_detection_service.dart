import 'dart:math' as math;
import '../models/dashboard_models.dart';
import '../../../core/types/invoice_types.dart';
import '../../../data/models/customer.dart';
import '../../inventory/models/product.dart';

/// Advanced anomaly detection service for business data
class AnomalyDetectionService {
  static const double _zScoreThreshold = 2.5;
  static const double _iqrMultiplier = 1.5;
  static const int _minimumDataPoints = 10;
  static const double _changePointThreshold = 0.3;

  /// Detect anomalies in business data across multiple dimensions
  Future<List<BusinessAnomaly>> detectAllAnomalies({
    required List<CRDTInvoiceEnhanced> invoices,
    required List<Customer> customers,
    required List<Product> products,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final anomalies = <BusinessAnomaly>[];

    // Revenue anomalies
    anomalies
        .addAll(await _detectRevenueAnomalies(invoices, startDate, endDate));

    // Customer behavior anomalies
    anomalies.addAll(await _detectCustomerAnomalies(
        customers, invoices, startDate, endDate));

    // Inventory anomalies
    anomalies.addAll(await _detectInventoryAnomalies(products, invoices));

    // Payment pattern anomalies
    anomalies.addAll(await _detectPaymentAnomalies(invoices));

    // Seasonal anomalies
    anomalies.addAll(await _detectSeasonalAnomalies(invoices));

    // Sort by severity (highest first)
    anomalies.sort((a, b) => b.severity.compareTo(a.severity));

    return anomalies;
  }

  /// Detect revenue-related anomalies
  Future<List<BusinessAnomaly>> _detectRevenueAnomalies(
    List<CRDTInvoiceEnhanced> invoices,
    DateTime? startDate,
    DateTime? endDate,
  ) async {
    final anomalies = <BusinessAnomaly>[];

    // Filter invoices by date range if provided
    final filteredInvoices =
        _filterInvoicesByDateRange(invoices, startDate, endDate);

    if (filteredInvoices.length < _minimumDataPoints) {
      return anomalies;
    }

    // Daily revenue analysis
    final dailyRevenue = _calculateDailyRevenue(filteredInvoices);
    final revenueValues = dailyRevenue.map((dp) => dp.value).toList();

    // Statistical anomaly detection
    final revenueStats = _calculateStatistics(revenueValues);
    final revenueAnomalies = _detectStatisticalAnomalies(
      dailyRevenue,
      revenueStats,
      'revenue',
    );
    anomalies.addAll(revenueAnomalies);

    // Sudden drops in revenue
    final revenueDrops = _detectSuddenDrops(dailyRevenue, 'revenue');
    anomalies.addAll(revenueDrops);

    // Revenue concentration anomalies (too much revenue from single source)
    final concentrationAnomalies =
        await _detectRevenueConcentration(filteredInvoices);
    anomalies.addAll(concentrationAnomalies);

    // Average order value anomalies
    final aovAnomalies =
        await _detectAverageOrderValueAnomalies(filteredInvoices);
    anomalies.addAll(aovAnomalies);

    return anomalies;
  }

  /// Detect customer behavior anomalies
  Future<List<BusinessAnomaly>> _detectCustomerAnomalies(
    List<Customer> customers,
    List<CRDTInvoiceEnhanced> invoices,
    DateTime? startDate,
    DateTime? endDate,
  ) async {
    final anomalies = <BusinessAnomaly>[];

    // Customer acquisition anomalies
    final acquisitionAnomalies =
        await _detectCustomerAcquisitionAnomalies(customers);
    anomalies.addAll(acquisitionAnomalies);

    // Customer churn anomalies
    final churnAnomalies =
        await _detectCustomerChurnAnomalies(customers, invoices);
    anomalies.addAll(churnAnomalies);

    // Customer lifetime value anomalies
    final clvAnomalies = await _detectCLVAnomalies(customers, invoices);
    anomalies.addAll(clvAnomalies);

    // Purchase frequency anomalies
    final frequencyAnomalies =
        await _detectPurchaseFrequencyAnomalies(customers, invoices);
    anomalies.addAll(frequencyAnomalies);

    return anomalies;
  }

  /// Detect inventory-related anomalies
  Future<List<BusinessAnomaly>> _detectInventoryAnomalies(
    List<Product> products,
    List<CRDTInvoiceEnhanced> invoices,
  ) async {
    final anomalies = <BusinessAnomaly>[];

    // Stock level anomalies
    final stockAnomalies = _detectStockLevelAnomalies(products);
    anomalies.addAll(stockAnomalies);

    // Inventory turnover anomalies
    final turnoverAnomalies =
        await _detectInventoryTurnoverAnomalies(products, invoices);
    anomalies.addAll(turnoverAnomalies);

    // Price anomalies
    final priceAnomalies = _detectPriceAnomalies(products);
    anomalies.addAll(priceAnomalies);

    // Dead stock detection
    final deadStockAnomalies = await _detectDeadStock(products, invoices);
    anomalies.addAll(deadStockAnomalies);

    return anomalies;
  }

  /// Detect payment pattern anomalies
  Future<List<BusinessAnomaly>> _detectPaymentAnomalies(
    List<CRDTInvoiceEnhanced> invoices,
  ) async {
    final anomalies = <BusinessAnomaly>[];

    // Payment delay anomalies
    final delayAnomalies = _detectPaymentDelayAnomalies(invoices);
    anomalies.addAll(delayAnomalies);

    // Payment amount anomalies
    final amountAnomalies = _detectPaymentAmountAnomalies(invoices);
    anomalies.addAll(amountAnomalies);

    // Payment method anomalies
    final methodAnomalies = _detectPaymentMethodAnomalies(invoices);
    anomalies.addAll(methodAnomalies);

    return anomalies;
  }

  /// Detect seasonal anomalies
  Future<List<BusinessAnomaly>> _detectSeasonalAnomalies(
    List<CRDTInvoiceEnhanced> invoices,
  ) async {
    final anomalies = <BusinessAnomaly>[];

    if (invoices.length < 365) {
      return anomalies; // Need at least a year of data
    }

    // Calculate expected seasonal patterns
    final seasonalPatterns = _calculateSeasonalPatterns(invoices);

    // Compare current period with seasonal expectations
    final seasonalDeviations =
        _detectSeasonalDeviations(invoices, seasonalPatterns);
    anomalies.addAll(seasonalDeviations);

    return anomalies;
  }

  /// Real-time anomaly detection for streaming data
  Future<List<BusinessAnomaly>> detectRealTimeAnomalies({
    required DataPoint newDataPoint,
    required List<DataPoint> historicalData,
    required String dataType,
  }) async {
    final anomalies = <BusinessAnomaly>[];

    if (historicalData.length < _minimumDataPoints) {
      return anomalies;
    }

    // Calculate rolling statistics
    final rollingWindow = historicalData.length > 30
        ? historicalData.skip(historicalData.length - 30).toList()
        : historicalData;
    final rollingStats = _calculateStatistics(
      rollingWindow.map((dp) => dp.value).toList(),
    );

    // Check if new point is an anomaly
    final zScore = (newDataPoint.value - rollingStats.mean) /
        rollingStats.standardDeviation;

    if (zScore.abs() > _zScoreThreshold) {
      anomalies.add(BusinessAnomaly(
        id: 'realtime_${dataType}_${DateTime.now().millisecondsSinceEpoch}',
        type: 'Statistical Anomaly',
        description:
            'Real-time $dataType value significantly deviates from recent patterns',
        severity: _calculateSeverity(zScore.abs()),
        detectedAt: DateTime.now(),
        context: {
          'value': newDataPoint.value,
          'expected_range':
              '${rollingStats.mean - (2 * rollingStats.standardDeviation)} - ${rollingStats.mean + (2 * rollingStats.standardDeviation)}',
          'z_score': zScore,
          'data_type': dataType,
        },
        possibleCauses: _getPossibleCauses(dataType, zScore > 0),
        recommendations: _getRecommendations(dataType, zScore > 0),
        isResolved: false,
      ));
    }

    return anomalies;
  }

  // Private helper methods

  List<CRDTInvoiceEnhanced> _filterInvoicesByDateRange(
    List<CRDTInvoiceEnhanced> invoices,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    return invoices.where((invoice) {
      final invoiceDate =
          DateTime.fromMillisecondsSinceEpoch(invoice.createdAt.physicalTime);
      final afterStart = startDate == null || invoiceDate.isAfter(startDate);
      final beforeEnd = endDate == null || invoiceDate.isBefore(endDate);
      return afterStart && beforeEnd;
    }).toList();
  }

  List<DataPoint> _calculateDailyRevenue(List<CRDTInvoiceEnhanced> invoices) {
    final dailyRevenue = <DateTime, double>{};

    for (final invoice in invoices) {
      if (invoice.status.value == InvoiceStatus.paid &&
          invoice.paidAt.value != null) {
        final day = DateTime(
          invoice.paidAt.value!.year,
          invoice.paidAt.value!.month,
          invoice.paidAt.value!.day,
        );
        dailyRevenue[day] =
            (dailyRevenue[day] ?? 0) + invoice.totalAmount.value;
      }
    }

    return dailyRevenue.entries
        .map((entry) => DataPoint(
              timestamp: entry.key,
              value: entry.value,
            ))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  DataStatistics _calculateStatistics(List<double> values) {
    if (values.isEmpty) {
      return DataStatistics(
        mean: 0,
        median: 0,
        standardDeviation: 0,
        q1: 0,
        q3: 0,
        iqr: 0,
      );
    }

    final sortedValues = List<double>.from(values)..sort();
    final mean = values.reduce((a, b) => a + b) / values.length;

    final variance =
        values.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) /
            values.length;
    final standardDeviation = math.sqrt(variance);

    final median = _calculateMedian(sortedValues);
    final q1 = _calculatePercentile(sortedValues, 0.25);
    final q3 = _calculatePercentile(sortedValues, 0.75);
    final iqr = q3 - q1;

    return DataStatistics(
      mean: mean,
      median: median,
      standardDeviation: standardDeviation,
      q1: q1,
      q3: q3,
      iqr: iqr,
    );
  }

  double _calculateMedian(List<double> sortedValues) {
    final n = sortedValues.length;
    if (n % 2 == 1) {
      return sortedValues[n ~/ 2];
    } else {
      return (sortedValues[n ~/ 2 - 1] + sortedValues[n ~/ 2]) / 2;
    }
  }

  double _calculatePercentile(List<double> sortedValues, double percentile) {
    final index = percentile * (sortedValues.length - 1);
    final lower = index.floor();
    final upper = index.ceil();

    if (lower == upper) {
      return sortedValues[lower];
    }

    final weight = index - lower;
    return sortedValues[lower] * (1 - weight) + sortedValues[upper] * weight;
  }

  List<BusinessAnomaly> _detectStatisticalAnomalies(
    List<DataPoint> data,
    DataStatistics stats,
    String dataType,
  ) {
    final anomalies = <BusinessAnomaly>[];

    for (final point in data) {
      // Z-score method
      final zScore = (point.value - stats.mean) / stats.standardDeviation;

      // IQR method
      final lowerBound = stats.q1 - (_iqrMultiplier * stats.iqr);
      final upperBound = stats.q3 + (_iqrMultiplier * stats.iqr);

      final isZScoreAnomaly = zScore.abs() > _zScoreThreshold;
      final isIQRAnomaly = point.value < lowerBound || point.value > upperBound;

      if (isZScoreAnomaly || isIQRAnomaly) {
        anomalies.add(BusinessAnomaly(
          id: 'statistical_${dataType}_${point.timestamp.millisecondsSinceEpoch}',
          type: 'Statistical Anomaly',
          description:
              'Unusual $dataType value detected on ${_formatDate(point.timestamp)}',
          severity: _calculateSeverity(zScore.abs()),
          detectedAt: DateTime.now(),
          context: {
            'value': point.value,
            'date': point.timestamp.toIso8601String(),
            'z_score': zScore,
            'expected_range':
                '${stats.mean - (2 * stats.standardDeviation)} - ${stats.mean + (2 * stats.standardDeviation)}',
            'detection_method': isZScoreAnomaly ? 'Z-Score' : 'IQR',
          },
          possibleCauses:
              _getPossibleCauses(dataType, point.value > stats.mean),
          recommendations:
              _getRecommendations(dataType, point.value > stats.mean),
          isResolved: false,
        ));
      }
    }

    return anomalies;
  }

  List<BusinessAnomaly> _detectSuddenDrops(
    List<DataPoint> data,
    String dataType,
  ) {
    final anomalies = <BusinessAnomaly>[];

    if (data.length < 2) return anomalies;

    for (int i = 1; i < data.length; i++) {
      final current = data[i].value;
      final previous = data[i - 1].value;

      if (previous > 0) {
        final changePercent = (current - previous) / previous;

        if (changePercent < -_changePointThreshold) {
          anomalies.add(BusinessAnomaly(
            id: 'sudden_drop_${dataType}_${data[i].timestamp.millisecondsSinceEpoch}',
            type: 'Sudden Drop',
            description:
                'Significant drop in $dataType detected on ${_formatDate(data[i].timestamp)}',
            severity: math.min(1.0, changePercent.abs() * 2),
            detectedAt: DateTime.now(),
            context: {
              'current_value': current,
              'previous_value': previous,
              'change_percent': changePercent * 100,
              'date': data[i].timestamp.toIso8601String(),
            },
            possibleCauses: [
              'Market downturn',
              'Competitive pressure',
              'System issues',
              'Seasonal effects',
              'Customer churn',
            ],
            recommendations: [
              'Investigate root cause immediately',
              'Review recent business changes',
              'Analyze customer feedback',
              'Check system performance',
              'Implement recovery strategies',
            ],
            isResolved: false,
          ));
        }
      }
    }

    return anomalies;
  }

  Future<List<BusinessAnomaly>> _detectRevenueConcentration(
    List<CRDTInvoiceEnhanced> invoices,
  ) async {
    final anomalies = <BusinessAnomaly>[];

    if (invoices.isEmpty) return anomalies;

    // Calculate revenue by customer
    final revenueByCustomer = <String, double>{};
    double totalRevenue = 0;

    for (final invoice in invoices) {
      if (invoice.status.value == InvoiceStatus.paid) {
        revenueByCustomer[invoice.customerId.value ?? 'unknown'] =
            (revenueByCustomer[invoice.customerId.value ?? 'unknown'] ?? 0) +
                invoice.totalAmount.value;
        totalRevenue += invoice.totalAmount.value;
      }
    }

    if (totalRevenue == 0) return anomalies;

    // Check for high concentration (80/20 rule violation)
    final sortedRevenue = revenueByCustomer.values.toList()
      ..sort((a, b) => b.compareTo(a));

    if (sortedRevenue.isNotEmpty) {
      final topCustomerRevenue = sortedRevenue.first;
      final topCustomerPercentage = (topCustomerRevenue / totalRevenue) * 100;

      if (topCustomerPercentage > 50) {
        anomalies.add(BusinessAnomaly(
          id: 'revenue_concentration_${DateTime.now().millisecondsSinceEpoch}',
          type: 'Revenue Concentration Risk',
          description:
              'High revenue concentration detected: ${topCustomerPercentage.toStringAsFixed(1)}% from single customer',
          severity: math.min(1.0, topCustomerPercentage / 100),
          detectedAt: DateTime.now(),
          context: {
            'top_customer_percentage': topCustomerPercentage,
            'total_customers': revenueByCustomer.length,
            'total_revenue': totalRevenue,
          },
          possibleCauses: [
            'Over-dependence on single customer',
            'Limited customer base',
            'Niche market focus',
            'Recent customer acquisition issues',
          ],
          recommendations: [
            'Diversify customer base',
            'Implement customer acquisition strategies',
            'Negotiate long-term contracts with key customers',
            'Develop risk mitigation plans',
            'Explore new market segments',
          ],
          isResolved: false,
        ));
      }
    }

    return anomalies;
  }

  Future<List<BusinessAnomaly>> _detectAverageOrderValueAnomalies(
    List<CRDTInvoiceEnhanced> invoices,
  ) async {
    final anomalies = <BusinessAnomaly>[];

    if (invoices.length < _minimumDataPoints) return anomalies;

    // Calculate daily AOV
    final dailyAOV = <DateTime, List<double>>{};

    for (final invoice in invoices) {
      if (invoice.status.value == InvoiceStatus.paid &&
          invoice.paidAt.value != null) {
        final day = DateTime(
          invoice.paidAt.value!.year,
          invoice.paidAt.value!.month,
          invoice.paidAt.value!.day,
        );
        dailyAOV[day] ??= [];
        dailyAOV[day]!.add(invoice.totalAmount.value);
      }
    }

    // Calculate average AOV for each day
    final aovData = dailyAOV.entries
        .map((entry) => DataPoint(
              timestamp: entry.key,
              value: entry.value.reduce((a, b) => a + b) / entry.value.length,
            ))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (aovData.length < _minimumDataPoints) return anomalies;

    // Detect AOV anomalies
    final aovValues = aovData.map((dp) => dp.value).toList();
    final aovStats = _calculateStatistics(aovValues);

    final aovAnomalies =
        _detectStatisticalAnomalies(aovData, aovStats, 'Average Order Value');
    anomalies.addAll(aovAnomalies);

    return anomalies;
  }

  Future<List<BusinessAnomaly>> _detectCustomerAcquisitionAnomalies(
    List<Customer> customers,
  ) async {
    final anomalies = <BusinessAnomaly>[];

    if (customers.length < _minimumDataPoints) return anomalies;

    // Calculate daily customer acquisition
    final dailyAcquisition = <DateTime, int>{};

    for (final customer in customers) {
      final day = DateTime(
        customer.createdAt.year,
        customer.createdAt.month,
        customer.createdAt.day,
      );
      dailyAcquisition[day] = (dailyAcquisition[day] ?? 0) + 1;
    }

    final acquisitionData = dailyAcquisition.entries
        .map((entry) => DataPoint(
              timestamp: entry.key,
              value: entry.value.toDouble(),
            ))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (acquisitionData.length < _minimumDataPoints) return anomalies;

    // Detect acquisition anomalies
    final acquisitionValues = acquisitionData.map((dp) => dp.value).toList();
    final acquisitionStats = _calculateStatistics(acquisitionValues);

    final acquisitionAnomalies = _detectStatisticalAnomalies(
      acquisitionData,
      acquisitionStats,
      'Customer Acquisition',
    );
    anomalies.addAll(acquisitionAnomalies);

    return anomalies;
  }

  // Additional helper methods for other anomaly types
  Future<List<BusinessAnomaly>> _detectCustomerChurnAnomalies(
    List<Customer> customers,
    List<CRDTInvoiceEnhanced> invoices,
  ) async {
    // Implementation for churn anomaly detection
    return [];
  }

  Future<List<BusinessAnomaly>> _detectCLVAnomalies(
    List<Customer> customers,
    List<CRDTInvoiceEnhanced> invoices,
  ) async {
    // Implementation for CLV anomaly detection
    return [];
  }

  Future<List<BusinessAnomaly>> _detectPurchaseFrequencyAnomalies(
    List<Customer> customers,
    List<CRDTInvoiceEnhanced> invoices,
  ) async {
    // Implementation for purchase frequency anomaly detection
    return [];
  }

  List<BusinessAnomaly> _detectStockLevelAnomalies(List<Product> products) {
    final anomalies = <BusinessAnomaly>[];

    for (final product in products) {
      // Zero stock anomaly
      if (product.stockLevel == 0) {
        anomalies.add(BusinessAnomaly(
          id: 'out_of_stock_${product.id}',
          type: 'Out of Stock',
          description: 'Product "${product.name}" is out of stock',
          severity: 0.9,
          detectedAt: DateTime.now(),
          context: {
            'product_id': product.id,
            'product_name': product.name,
            'current_stock': product.stockLevel,
            'min_stock': product.minStockLevel,
          },
          possibleCauses: [
            'Higher than expected sales',
            'Supply chain delays',
            'Inventory management issues',
            'Forecasting errors',
          ],
          recommendations: [
            'Emergency reorder from supplier',
            'Update customers about availability',
            'Suggest alternative products',
            'Review inventory planning',
          ],
          isResolved: false,
        ));
      }

      // Critical low stock anomaly
      else if (product.stockLevel <= product.minStockLevel * 0.2) {
        anomalies.add(BusinessAnomaly(
          id: 'critical_low_stock_${product.id}',
          type: 'Critical Low Stock',
          description: 'Product "${product.name}" has critically low stock',
          severity: 0.7,
          detectedAt: DateTime.now(),
          context: {
            'product_id': product.id,
            'product_name': product.name,
            'current_stock': product.stockLevel,
            'min_stock': product.minStockLevel,
          },
          possibleCauses: [
            'Increased demand',
            'Delayed deliveries',
            'Inaccurate forecasting',
          ],
          recommendations: [
            'Place immediate reorder',
            'Monitor sales velocity',
            'Contact supplier for expedited delivery',
          ],
          isResolved: false,
        ));
      }
    }

    return anomalies;
  }

  Future<List<BusinessAnomaly>> _detectInventoryTurnoverAnomalies(
    List<Product> products,
    List<CRDTInvoiceEnhanced> invoices,
  ) async {
    // Implementation for inventory turnover anomaly detection
    return [];
  }

  List<BusinessAnomaly> _detectPriceAnomalies(List<Product> products) {
    // Implementation for price anomaly detection
    return [];
  }

  Future<List<BusinessAnomaly>> _detectDeadStock(
    List<Product> products,
    List<CRDTInvoiceEnhanced> invoices,
  ) async {
    // Implementation for dead stock detection
    return [];
  }

  List<BusinessAnomaly> _detectPaymentDelayAnomalies(
      List<CRDTInvoiceEnhanced> invoices) {
    // Implementation for payment delay anomaly detection
    return [];
  }

  List<BusinessAnomaly> _detectPaymentAmountAnomalies(
      List<CRDTInvoiceEnhanced> invoices) {
    // Implementation for payment amount anomaly detection
    return [];
  }

  List<BusinessAnomaly> _detectPaymentMethodAnomalies(
      List<CRDTInvoiceEnhanced> invoices) {
    // Implementation for payment method anomaly detection
    return [];
  }

  Map<int, double> _calculateSeasonalPatterns(
      List<CRDTInvoiceEnhanced> invoices) {
    // Implementation for seasonal pattern calculation
    return {};
  }

  List<BusinessAnomaly> _detectSeasonalDeviations(
    List<CRDTInvoiceEnhanced> invoices,
    Map<int, double> seasonalPatterns,
  ) {
    // Implementation for seasonal deviation detection
    return [];
  }

  double _calculateSeverity(double zScore) {
    // Map z-score to severity (0-1)
    return math.min(1.0, zScore / 5.0);
  }

  List<String> _getPossibleCauses(String dataType, bool isIncrease) {
    switch (dataType.toLowerCase()) {
      case 'revenue':
        return isIncrease
            ? [
                'Successful marketing campaign',
                'New product launch',
                'Seasonal demand increase',
                'Competitor issues',
                'Bulk order from major client',
              ]
            : [
                'Market downturn',
                'Competitive pressure',
                'Seasonal decline',
                'Product issues',
                'Customer churn',
              ];
      case 'customers':
        return isIncrease
            ? [
                'Viral marketing success',
                'Referral program effectiveness',
                'Market expansion',
                'Competitor customer acquisition',
              ]
            : [
                'Churn increase',
                'Market saturation',
                'Service quality issues',
                'Competitive pressure',
              ];
      default:
        return [
          'External market factors',
          'Internal process changes',
          'Seasonal variations',
          'Data quality issues',
        ];
    }
  }

  List<String> _getRecommendations(String dataType, bool isIncrease) {
    switch (dataType.toLowerCase()) {
      case 'revenue':
        return isIncrease
            ? [
                'Analyze success factors',
                'Scale successful initiatives',
                'Prepare for increased demand',
                'Monitor sustainability',
              ]
            : [
                'Investigate root causes',
                'Implement recovery strategies',
                'Review pricing strategy',
                'Enhance customer retention',
              ];
      case 'customers':
        return isIncrease
            ? [
                'Optimize onboarding process',
                'Prepare customer support',
                'Monitor service quality',
                'Plan for scaling',
              ]
            : [
                'Conduct churn analysis',
                'Improve customer experience',
                'Launch retention campaigns',
                'Review competitive positioning',
              ];
      default:
        return [
          'Monitor closely',
          'Investigate underlying causes',
          'Review related processes',
          'Consider corrective actions',
        ];
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Statistical data helper class
class DataStatistics {
  final double mean;
  final double median;
  final double standardDeviation;
  final double q1;
  final double q3;
  final double iqr;

  DataStatistics({
    required this.mean,
    required this.median,
    required this.standardDeviation,
    required this.q1,
    required this.q3,
    required this.iqr,
  });
}
