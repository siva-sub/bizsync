import 'dart:math' as math;
import '../models/forecasting_models.dart';

/// Seasonal Decomposition Model using additive or multiplicative decomposition
class SeasonalDecompositionModel implements ForecastingModel {
  @override
  String get name => 'Seasonal Decomposition';

  @override
  ForecastingMethod get method => ForecastingMethod.seasonalDecomposition;

  int _seasonalPeriod = 12; // Default to monthly seasonality
  bool _multiplicative = false; // Additive by default
  List<TimeSeriesPoint> _trainingData = [];
  
  late List<double> _trend;
  late List<double> _seasonal;
  late List<double> _residual;
  late double _lastTrendValue;
  late List<double> _seasonalPattern;

  /// Creates a seasonal decomposition model
  SeasonalDecompositionModel({
    int seasonalPeriod = 12,
    bool multiplicative = false,
  }) : _seasonalPeriod = seasonalPeriod, _multiplicative = multiplicative;

  @override
  Future<void> train(List<TimeSeriesPoint> data) async {
    if (data.length < _seasonalPeriod * 2) {
      throw ArgumentError('Need at least ${_seasonalPeriod * 2} data points for seasonal decomposition');
    }

    _trainingData = List.from(data);
    await _performDecomposition(data.map((p) => p.value).toList());
  }

  Future<void> _performDecomposition(List<double> values) async {
    final n = values.length;
    
    // Step 1: Calculate trend using centered moving average
    _trend = _calculateTrend(values);
    
    // Step 2: Detrend the series
    final detrended = <double>[];
    for (int i = 0; i < n; i++) {
      if (i < _trend.length && _trend[i] != double.nan) {
        if (_multiplicative) {
          detrended.add(_trend[i] != 0 ? values[i] / _trend[i] : 0.0);
        } else {
          detrended.add(values[i] - _trend[i]);
        }
      } else {
        detrended.add(double.nan);
      }
    }
    
    // Step 3: Calculate seasonal component
    _seasonal = _calculateSeasonal(detrended);
    _seasonalPattern = _extractSeasonalPattern();
    
    // Step 4: Calculate residual component
    _residual = _calculateResidual(values);
    
    // Store last trend value for forecasting
    _lastTrendValue = _trend.where((t) => !t.isNaN).last;
  }

  List<double> _calculateTrend(List<double> values) {
    final n = values.length;
    final trend = List.filled(n, double.nan);
    final halfPeriod = _seasonalPeriod ~/ 2;
    
    // Calculate centered moving average
    for (int i = halfPeriod; i < n - halfPeriod; i++) {
      double sum = 0.0;
      for (int j = i - halfPeriod; j <= i + halfPeriod; j++) {
        sum += values[j];
      }
      trend[i] = sum / _seasonalPeriod;
    }
    
    // Linear extrapolation for missing values at ends
    _extrapolateTrend(trend);
    
    return trend;
  }

  void _extrapolateTrend(List<double> trend) {
    final n = trend.length;
    final halfPeriod = _seasonalPeriod ~/ 2;
    
    // Find first and last valid trend values
    int firstValid = -1;
    int lastValid = -1;
    
    for (int i = 0; i < n; i++) {
      if (!trend[i].isNaN) {
        if (firstValid == -1) firstValid = i;
        lastValid = i;
      }
    }
    
    if (firstValid == -1 || lastValid == -1) return;
    
    // Calculate slope for extrapolation
    double slope = 0.0;
    int slopeCount = 0;
    
    for (int i = firstValid + 1; i <= math.min(firstValid + halfPeriod, lastValid); i++) {
      if (!trend[i].isNaN && !trend[i - 1].isNaN) {
        slope += trend[i] - trend[i - 1];
        slopeCount++;
      }
    }
    
    if (slopeCount > 0) {
      slope /= slopeCount;
    }
    
    // Extrapolate backwards
    for (int i = firstValid - 1; i >= 0; i--) {
      trend[i] = trend[i + 1] - slope;
    }
    
    // Extrapolate forwards
    for (int i = lastValid + 1; i < n; i++) {
      trend[i] = trend[i - 1] + slope;
    }
  }

  List<double> _calculateSeasonal(List<double> detrended) {
    final n = detrended.length;
    final seasonal = <double>[];
    
    // Calculate average for each season
    final seasonalAverages = List.filled(_seasonalPeriod, 0.0);
    final seasonalCounts = List.filled(_seasonalPeriod, 0);
    
    for (int i = 0; i < n; i++) {
      if (!detrended[i].isNaN) {
        final seasonIndex = i % _seasonalPeriod;
        seasonalAverages[seasonIndex] += detrended[i];
        seasonalCounts[seasonIndex]++;
      }
    }
    
    // Calculate averages
    for (int i = 0; i < _seasonalPeriod; i++) {
      if (seasonalCounts[i] > 0) {
        seasonalAverages[i] /= seasonalCounts[i];
      }
    }
    
    // Normalize seasonal components (sum to 0 for additive, average to 1 for multiplicative)
    if (_multiplicative) {
      final avgSeasonal = seasonalAverages.reduce((a, b) => a + b) / _seasonalPeriod;
      if (avgSeasonal != 0) {
        for (int i = 0; i < _seasonalPeriod; i++) {
          seasonalAverages[i] /= avgSeasonal;
        }
      }
    } else {
      final sumSeasonal = seasonalAverages.reduce((a, b) => a + b);
      final avgSeasonal = sumSeasonal / _seasonalPeriod;
      for (int i = 0; i < _seasonalPeriod; i++) {
        seasonalAverages[i] -= avgSeasonal;
      }
    }
    
    // Create seasonal series
    for (int i = 0; i < n; i++) {
      seasonal.add(seasonalAverages[i % _seasonalPeriod]);
    }
    
    return seasonal;
  }

  List<double> _extractSeasonalPattern() {
    final pattern = <double>[];
    for (int i = 0; i < _seasonalPeriod; i++) {
      if (i < _seasonal.length) {
        pattern.add(_seasonal[i]);
      } else {
        pattern.add(0.0);
      }
    }
    return pattern;
  }

  List<double> _calculateResidual(List<double> values) {
    final n = values.length;
    final residual = <double>[];
    
    for (int i = 0; i < n; i++) {
      if (i < _trend.length && i < _seasonal.length && 
          !_trend[i].isNaN && !_seasonal[i].isNaN) {
        if (_multiplicative) {
          final expected = _trend[i] * _seasonal[i];
          residual.add(expected != 0 ? values[i] / expected : 0.0);
        } else {
          residual.add(values[i] - _trend[i] - _seasonal[i]);
        }
      } else {
        residual.add(double.nan);
      }
    }
    
    return residual;
  }

  @override
  Future<List<ForecastResult>> forecast(int periods) async {
    if (_trainingData.isEmpty) {
      throw StateError('Model must be trained before forecasting');
    }

    final results = <ForecastResult>[];
    final standardError = _calculateStandardError();
    
    // Calculate trend slope for extrapolation
    final trendSlope = _calculateTrendSlope();
    
    for (int i = 1; i <= periods; i++) {
      final futureDate = _trainingData.last.date.add(Duration(days: i));
      
      // Extrapolate trend
      final futureTrend = _lastTrendValue + trendSlope * i;
      
      // Get seasonal component
      final seasonIndex = (_trainingData.length + i - 1) % _seasonalPeriod;
      final seasonalComponent = _seasonalPattern[seasonIndex];
      
      // Combine components
      double predicted;
      if (_multiplicative) {
        predicted = futureTrend * seasonalComponent;
      } else {
        predicted = futureTrend + seasonalComponent;
      }
      
      // Calculate confidence interval
      final margin = 1.96 * standardError * math.sqrt(i);
      
      results.add(ForecastResult(
        date: futureDate,
        predictedValue: predicted,
        lowerBound: predicted - margin,
        upperBound: predicted + margin,
        confidence: 0.95,
        method: method.displayName,
        metrics: {
          'seasonal_period': _seasonalPeriod,
          'multiplicative': _multiplicative,
          'trend_slope': trendSlope,
          'seasonal_component': seasonalComponent,
          'future_trend': futureTrend,
          'standard_error': standardError,
        },
      ));
    }

    return results;
  }

  double _calculateTrendSlope() {
    if (_trend.length < 2) return 0.0;
    
    final validTrends = _trend.where((t) => !t.isNaN).toList();
    if (validTrends.length < 2) return 0.0;
    
    // Calculate average slope over the last few periods
    final slopePeriods = math.min(validTrends.length - 1, _seasonalPeriod);
    double totalSlope = 0.0;
    int slopeCount = 0;
    
    for (int i = validTrends.length - slopePeriods; i < validTrends.length - 1; i++) {
      totalSlope += validTrends[i + 1] - validTrends[i];
      slopeCount++;
    }
    
    return slopeCount > 0 ? totalSlope / slopeCount : 0.0;
  }

  double _calculateStandardError() {
    if (_residual.isEmpty) return 0.0;
    
    final validResiduals = _residual.where((r) => !r.isNaN).toList();
    if (validResiduals.isEmpty) return 0.0;
    
    // Calculate standard deviation of residuals
    final mean = validResiduals.reduce((a, b) => a + b) / validResiduals.length;
    double sumSquaredDiff = 0.0;
    
    for (final residual in validResiduals) {
      sumSquaredDiff += (residual - mean) * (residual - mean);
    }
    
    return math.sqrt(sumSquaredDiff / validResiduals.length);
  }

  @override
  Future<ForecastAccuracy> calculateAccuracy(List<TimeSeriesPoint> testData) async {
    if (_trainingData.isEmpty) {
      throw StateError('Model must be trained before calculating accuracy');
    }

    if (testData.isEmpty) {
      throw ArgumentError('Test data cannot be empty');
    }

    double sumAbsoluteError = 0.0;
    double sumAbsolutePercentageError = 0.0;
    double sumSquaredError = 0.0;
    double sumActual = 0.0;
    double sumSquaredResiduals = 0.0;
    int validPoints = 0;

    final trendSlope = _calculateTrendSlope();
    
    for (int i = 0; i < testData.length; i++) {
      final futureTrend = _lastTrendValue + trendSlope * (i + 1);
      final seasonIndex = (_trainingData.length + i) % _seasonalPeriod;
      final seasonalComponent = _seasonalPattern[seasonIndex];
      
      double predicted;
      if (_multiplicative) {
        predicted = futureTrend * seasonalComponent;
      } else {
        predicted = futureTrend + seasonalComponent;
      }
      
      final actual = testData[i].value;
      
      if (actual != 0) {
        final absoluteError = (actual - predicted).abs();
        final percentageError = (absoluteError / actual.abs()) * 100;
        
        sumAbsoluteError += absoluteError;
        sumAbsolutePercentageError += percentageError;
        sumSquaredError += (actual - predicted) * (actual - predicted);
        sumActual += actual;
        sumSquaredResiduals += (actual - predicted) * (actual - predicted);
        validPoints++;
      }
    }

    if (validPoints == 0) {
      throw ArgumentError('No valid test data points');
    }

    final mae = sumAbsoluteError / validPoints;
    final mape = sumAbsolutePercentageError / validPoints;
    final mse = sumSquaredError / validPoints;
    final rmse = math.sqrt(mse);

    // Calculate R-squared for test data
    final meanActual = sumActual / validPoints;
    double ssTot = 0.0;
    for (final point in testData) {
      if (point.value != 0) {
        ssTot += (point.value - meanActual) * (point.value - meanActual);
      }
    }
    final r2 = ssTot != 0 ? 1 - (sumSquaredResiduals / ssTot) : 0.0;

    // Calculate AIC and BIC (simplified versions)
    final n = validPoints;
    final k = _seasonalPeriod + 1; // Number of parameters (seasonal factors + trend)
    final aic = n * math.log(mse) + 2 * k;
    final bic = n * math.log(mse) + k * math.log(n);

    return ForecastAccuracy(
      mape: mape,
      mae: mae,
      mse: mse,
      rmse: rmse,
      r2: r2,
      aic: aic,
      bic: bic,
    );
  }

  @override
  Map<String, dynamic> getParameters() {
    return {
      'seasonal_period': _seasonalPeriod,
      'multiplicative': _multiplicative,
      'last_trend_value': _lastTrendValue,
      'seasonal_pattern': _seasonalPattern,
      'training_points': _trainingData.length,
    };
  }

  @override
  void setParameters(Map<String, dynamic> parameters) {
    _seasonalPeriod = parameters['seasonal_period'] ?? 12;
    _multiplicative = parameters['multiplicative'] ?? false;
    _lastTrendValue = parameters['last_trend_value']?.toDouble() ?? 0.0;
    if (parameters['seasonal_pattern'] != null) {
      _seasonalPattern = List<double>.from(parameters['seasonal_pattern']);
    }
  }

  /// Get decomposition components for analysis
  Map<String, List<double>> getDecomposition() {
    return {
      'trend': _trend,
      'seasonal': _seasonal,
      'residual': _residual,
      'seasonal_pattern': _seasonalPattern,
    };
  }
}