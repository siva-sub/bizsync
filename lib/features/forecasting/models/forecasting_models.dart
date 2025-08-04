import 'dart:math' as math;

/// Represents a time series data point
class TimeSeriesPoint {
  final DateTime date;
  final double value;
  final Map<String, dynamic>? metadata;

  const TimeSeriesPoint({
    required this.date,
    required this.value,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'value': value,
      'metadata': metadata,
    };
  }

  factory TimeSeriesPoint.fromJson(Map<String, dynamic> json) {
    return TimeSeriesPoint(
      date: DateTime.parse(json['date']),
      value: json['value'].toDouble(),
      metadata: json['metadata'],
    );
  }
}

/// Represents a forecast result with confidence intervals
class ForecastResult {
  final DateTime date;
  final double predictedValue;
  final double lowerBound;
  final double upperBound;
  final double confidence;
  final String method;
  final Map<String, dynamic>? metrics;

  const ForecastResult({
    required this.date,
    required this.predictedValue,
    required this.lowerBound,
    required this.upperBound,
    required this.confidence,
    required this.method,
    this.metrics,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'predicted_value': predictedValue,
      'lower_bound': lowerBound,
      'upper_bound': upperBound,
      'confidence': confidence,
      'method': method,
      'metrics': metrics,
    };
  }

  factory ForecastResult.fromJson(Map<String, dynamic> json) {
    return ForecastResult(
      date: DateTime.parse(json['date']),
      predictedValue: json['predicted_value'].toDouble(),
      lowerBound: json['lower_bound'].toDouble(),
      upperBound: json['upper_bound'].toDouble(),
      confidence: json['confidence'].toDouble(),
      method: json['method'],
      metrics: json['metrics'],
    );
  }
}

/// Represents seasonal patterns in data
class SeasonalComponent {
  final int period; // e.g., 12 for monthly data, 7 for daily data
  final List<double> seasonalFactors;
  final double trend;
  final double level;

  const SeasonalComponent({
    required this.period,
    required this.seasonalFactors,
    required this.trend,
    required this.level,
  });

  Map<String, dynamic> toJson() {
    return {
      'period': period,
      'seasonal_factors': seasonalFactors,
      'trend': trend,
      'level': level,
    };
  }

  factory SeasonalComponent.fromJson(Map<String, dynamic> json) {
    return SeasonalComponent(
      period: json['period'],
      seasonalFactors: List<double>.from(json['seasonal_factors']),
      trend: json['trend'].toDouble(),
      level: json['level'].toDouble(),
    );
  }
}

/// Represents forecast accuracy metrics
class ForecastAccuracy {
  final double mape; // Mean Absolute Percentage Error
  final double mae; // Mean Absolute Error
  final double mse; // Mean Squared Error
  final double rmse; // Root Mean Squared Error
  final double r2; // R-squared
  final double aic; // Akaike Information Criterion
  final double bic; // Bayesian Information Criterion

  const ForecastAccuracy({
    required this.mape,
    required this.mae,
    required this.mse,
    required this.rmse,
    required this.r2,
    required this.aic,
    required this.bic,
  });

  Map<String, dynamic> toJson() {
    return {
      'mape': mape,
      'mae': mae,
      'mse': mse,
      'rmse': rmse,
      'r2': r2,
      'aic': aic,
      'bic': bic,
    };
  }

  factory ForecastAccuracy.fromJson(Map<String, dynamic> json) {
    return ForecastAccuracy(
      mape: json['mape'].toDouble(),
      mae: json['mae'].toDouble(),
      mse: json['mse'].toDouble(),
      rmse: json['rmse'].toDouble(),
      r2: json['r2'].toDouble(),
      aic: json['aic'].toDouble(),
      bic: json['bic'].toDouble(),
    );
  }
}

/// Types of forecasting methods
enum ForecastingMethod {
  linearRegression('Linear Regression'),
  movingAverage('Moving Average'),
  exponentialSmoothing('Exponential Smoothing'),
  holtWinters('Holt-Winters'),
  seasonalDecomposition('Seasonal Decomposition'),
  arima('ARIMA'),
  ensemble('Ensemble');

  const ForecastingMethod(this.displayName);
  final String displayName;
}

/// Types of time series periodicity
enum Periodicity {
  daily(1, 'Daily'),
  weekly(7, 'Weekly'),
  monthly(30, 'Monthly'),
  quarterly(90, 'Quarterly'),
  yearly(365, 'Yearly');

  const Periodicity(this.days, this.displayName);
  final int days;
  final String displayName;
}

/// Base class for all forecasting models
abstract class ForecastingModel {
  String get name;
  ForecastingMethod get method;

  /// Train the model with historical data
  Future<void> train(List<TimeSeriesPoint> data);

  /// Generate forecasts for the specified number of periods
  Future<List<ForecastResult>> forecast(int periods);

  /// Calculate accuracy metrics against test data
  Future<ForecastAccuracy> calculateAccuracy(List<TimeSeriesPoint> testData);

  /// Get model parameters and configuration
  Map<String, dynamic> getParameters();

  /// Set model parameters
  void setParameters(Map<String, dynamic> parameters);
}

/// Configuration for forecasting scenarios
class ForecastScenario {
  final String id;
  final String name;
  final String description;
  final ForecastingMethod method;
  final Map<String, dynamic> parameters;
  final int forecastHorizon;
  final Periodicity periodicity;
  final double confidenceLevel;

  const ForecastScenario({
    required this.id,
    required this.name,
    required this.description,
    required this.method,
    required this.parameters,
    required this.forecastHorizon,
    required this.periodicity,
    this.confidenceLevel = 0.95,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'method': method.name,
      'parameters': parameters,
      'forecast_horizon': forecastHorizon,
      'periodicity': periodicity.name,
      'confidence_level': confidenceLevel,
    };
  }

  factory ForecastScenario.fromJson(Map<String, dynamic> json) {
    return ForecastScenario(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      method: ForecastingMethod.values.firstWhere(
        (m) => m.name == json['method'],
        orElse: () => ForecastingMethod.linearRegression,
      ),
      parameters: json['parameters'],
      forecastHorizon: json['forecast_horizon'],
      periodicity: Periodicity.values.firstWhere(
        (p) => p.name == json['periodicity'],
        orElse: () => Periodicity.monthly,
      ),
      confidenceLevel: json['confidence_level']?.toDouble() ?? 0.95,
    );
  }
}

/// Represents a complete forecast session with multiple scenarios
class ForecastSession {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime? lastModified;
  final List<ForecastScenario> scenarios;
  final Map<String, List<ForecastResult>> results;
  final Map<String, ForecastAccuracy> accuracyMetrics;
  final List<TimeSeriesPoint> historicalData;
  final String dataSource; // 'revenue', 'expenses', 'cashflow', 'inventory'

  const ForecastSession({
    required this.id,
    required this.name,
    required this.createdAt,
    this.lastModified,
    required this.scenarios,
    required this.results,
    required this.accuracyMetrics,
    required this.historicalData,
    required this.dataSource,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'last_modified': lastModified?.toIso8601String(),
      'scenarios': scenarios.map((s) => s.toJson()).toList(),
      'results': results.map((key, value) => MapEntry(
            key,
            value.map((r) => r.toJson()).toList(),
          )),
      'accuracy_metrics': accuracyMetrics.map((key, value) => MapEntry(
            key,
            value.toJson(),
          )),
      'historical_data': historicalData.map((d) => d.toJson()).toList(),
      'data_source': dataSource,
    };
  }

  factory ForecastSession.fromJson(Map<String, dynamic> json) {
    return ForecastSession(
      id: json['id'],
      name: json['name'],
      createdAt: DateTime.parse(json['created_at']),
      lastModified: json['last_modified'] != null
          ? DateTime.parse(json['last_modified'])
          : null,
      scenarios: (json['scenarios'] as List)
          .map((s) => ForecastScenario.fromJson(s))
          .toList(),
      results: (json['results'] as Map<String, dynamic>)
          .map((key, value) => MapEntry(
                key,
                (value as List).map((r) => ForecastResult.fromJson(r)).toList(),
              )),
      accuracyMetrics: (json['accuracy_metrics'] as Map<String, dynamic>)
          .map((key, value) => MapEntry(
                key,
                ForecastAccuracy.fromJson(value),
              )),
      historicalData: (json['historical_data'] as List)
          .map((d) => TimeSeriesPoint.fromJson(d))
          .toList(),
      dataSource: json['data_source'],
    );
  }
}
