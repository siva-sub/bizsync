import 'dart:math' as math;
import '../models/forecasting_models.dart';

/// Simple Exponential Smoothing Model
class ExponentialSmoothingModel implements ForecastingModel {
  @override
  String get name => 'Exponential Smoothing';

  @override
  ForecastingMethod get method => ForecastingMethod.exponentialSmoothing;

  double _alpha = 0.3; // Smoothing parameter (0 < alpha <= 1)
  List<TimeSeriesPoint> _trainingData = [];
  List<double> _smoothedValues = [];
  double _lastSmoothedValue = 0.0;

  /// Creates an exponential smoothing model with specified alpha
  ExponentialSmoothingModel({double alpha = 0.3}) : _alpha = alpha {
    if (_alpha <= 0 || _alpha > 1) {
      throw ArgumentError('Alpha must be between 0 and 1');
    }
  }

  @override
  Future<void> train(List<TimeSeriesPoint> data) async {
    if (data.isEmpty) {
      throw ArgumentError(
          'Need at least 1 data point for exponential smoothing');
    }

    _trainingData = List.from(data);
    _smoothedValues =
        _calculateSmoothedValues(data.map((p) => p.value).toList());
    _lastSmoothedValue = _smoothedValues.last;
  }

  List<double> _calculateSmoothedValues(List<double> values) {
    final smoothed = <double>[];

    if (values.isEmpty) return smoothed;

    // Initialize with first value
    smoothed.add(values.first);

    // Calculate exponentially smoothed values
    for (int i = 1; i < values.length; i++) {
      final smoothedValue = _alpha * values[i] + (1 - _alpha) * smoothed[i - 1];
      smoothed.add(smoothedValue);
    }

    return smoothed;
  }

  @override
  Future<List<ForecastResult>> forecast(int periods) async {
    if (_trainingData.isEmpty) {
      throw StateError('Model must be trained before forecasting');
    }

    final results = <ForecastResult>[];
    final standardError = _calculateStandardError();

    for (int i = 1; i <= periods; i++) {
      final futureDate = _trainingData.last.date.add(Duration(days: i));

      // For simple exponential smoothing, forecast is constant (last smoothed value)
      final predicted = _lastSmoothedValue;

      // Calculate confidence interval using standard error
      final margin = 1.96 *
          standardError *
          math.sqrt(i); // Wider intervals for longer horizons

      results.add(ForecastResult(
        date: futureDate,
        predictedValue: predicted,
        lowerBound: predicted - margin,
        upperBound: predicted + margin,
        confidence: 0.95,
        method: method.displayName,
        metrics: {
          'alpha': _alpha,
          'last_smoothed_value': _lastSmoothedValue,
          'standard_error': standardError,
          'horizon': i,
        },
      ));
    }

    return results;
  }

  double _calculateStandardError() {
    if (_trainingData.length < 2 || _smoothedValues.length < 2) return 0.0;

    double sumSquaredErrors = 0.0;
    int count = 0;

    for (int i = 1; i < _trainingData.length; i++) {
      final actual = _trainingData[i].value;
      final predicted = _smoothedValues[i - 1];
      sumSquaredErrors += (actual - predicted) * (actual - predicted);
      count++;
    }

    return count > 0 ? math.sqrt(sumSquaredErrors / count) : 0.0;
  }

  @override
  Future<ForecastAccuracy> calculateAccuracy(
      List<TimeSeriesPoint> testData) async {
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

    double currentSmoothed = _lastSmoothedValue;

    for (final point in testData) {
      final predicted = currentSmoothed;
      final actual = point.value;

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

      // Update smoothed value for next prediction
      currentSmoothed = _alpha * actual + (1 - _alpha) * currentSmoothed;
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
    final k = 1; // Number of parameters (alpha)
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
      'alpha': _alpha,
      'last_smoothed_value': _lastSmoothedValue,
      'training_points': _trainingData.length,
      'smoothed_values_count': _smoothedValues.length,
    };
  }

  @override
  void setParameters(Map<String, dynamic> parameters) {
    if (parameters['alpha'] != null) {
      final alpha = parameters['alpha'].toDouble();
      if (alpha > 0 && alpha <= 1) {
        _alpha = alpha;
      }
    }
    _lastSmoothedValue = parameters['last_smoothed_value']?.toDouble() ?? 0.0;
  }
}

/// Double Exponential Smoothing (Holt's Method) for trend data
class DoubleExponentialSmoothingModel implements ForecastingModel {
  @override
  String get name => 'Double Exponential Smoothing (Holt)';

  @override
  ForecastingMethod get method => ForecastingMethod.exponentialSmoothing;

  double _alpha = 0.3; // Level smoothing parameter
  double _beta = 0.3; // Trend smoothing parameter
  List<TimeSeriesPoint> _trainingData = [];
  double _lastLevel = 0.0;
  double _lastTrend = 0.0;

  /// Creates a double exponential smoothing model
  DoubleExponentialSmoothingModel({double alpha = 0.3, double beta = 0.3})
      : _alpha = alpha,
        _beta = beta {
    if (_alpha <= 0 || _alpha > 1) {
      throw ArgumentError('Alpha must be between 0 and 1');
    }
    if (_beta <= 0 || _beta > 1) {
      throw ArgumentError('Beta must be between 0 and 1');
    }
  }

  @override
  Future<void> train(List<TimeSeriesPoint> data) async {
    if (data.length < 2) {
      throw ArgumentError(
          'Need at least 2 data points for double exponential smoothing');
    }

    _trainingData = List.from(data);
    _calculateHoltParameters(data.map((p) => p.value).toList());
  }

  void _calculateHoltParameters(List<double> values) {
    if (values.length < 2) return;

    // Initialize level and trend
    _lastLevel = values.first;
    _lastTrend = values.length > 1 ? values[1] - values[0] : 0.0;

    // Calculate level and trend for each data point
    for (int i = 1; i < values.length; i++) {
      final previousLevel = _lastLevel;

      // Update level
      _lastLevel =
          _alpha * values[i] + (1 - _alpha) * (_lastLevel + _lastTrend);

      // Update trend
      _lastTrend =
          _beta * (_lastLevel - previousLevel) + (1 - _beta) * _lastTrend;
    }
  }

  @override
  Future<List<ForecastResult>> forecast(int periods) async {
    if (_trainingData.isEmpty) {
      throw StateError('Model must be trained before forecasting');
    }

    final results = <ForecastResult>[];
    final standardError = _calculateStandardError();

    for (int i = 1; i <= periods; i++) {
      final futureDate = _trainingData.last.date.add(Duration(days: i));

      // Holt's method: forecast = level + trend * horizon
      final predicted = _lastLevel + _lastTrend * i;

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
          'alpha': _alpha,
          'beta': _beta,
          'last_level': _lastLevel,
          'last_trend': _lastTrend,
          'standard_error': standardError,
          'horizon': i,
        },
      ));
    }

    return results;
  }

  double _calculateStandardError() {
    if (_trainingData.length < 3) return 0.0;

    final values = _trainingData.map((p) => p.value).toList();
    double level = values.first;
    double trend = values.length > 1 ? values[1] - values[0] : 0.0;

    double sumSquaredErrors = 0.0;
    int count = 0;

    for (int i = 1; i < values.length; i++) {
      final predicted = level + trend;
      final actual = values[i];
      sumSquaredErrors += (actual - predicted) * (actual - predicted);
      count++;

      // Update level and trend
      final previousLevel = level;
      level = _alpha * actual + (1 - _alpha) * (level + trend);
      trend = _beta * (level - previousLevel) + (1 - _beta) * trend;
    }

    return count > 0 ? math.sqrt(sumSquaredErrors / count) : 0.0;
  }

  @override
  Future<ForecastAccuracy> calculateAccuracy(
      List<TimeSeriesPoint> testData) async {
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

    double currentLevel = _lastLevel;
    double currentTrend = _lastTrend;

    for (int i = 0; i < testData.length; i++) {
      final predicted = currentLevel + currentTrend;
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

      // Update level and trend for next prediction
      final previousLevel = currentLevel;
      currentLevel =
          _alpha * actual + (1 - _alpha) * (currentLevel + currentTrend);
      currentTrend =
          _beta * (currentLevel - previousLevel) + (1 - _beta) * currentTrend;
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
    final k = 2; // Number of parameters (alpha, beta)
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
      'alpha': _alpha,
      'beta': _beta,
      'last_level': _lastLevel,
      'last_trend': _lastTrend,
      'training_points': _trainingData.length,
    };
  }

  @override
  void setParameters(Map<String, dynamic> parameters) {
    if (parameters['alpha'] != null) {
      final alpha = parameters['alpha'].toDouble();
      if (alpha > 0 && alpha <= 1) {
        _alpha = alpha;
      }
    }
    if (parameters['beta'] != null) {
      final beta = parameters['beta'].toDouble();
      if (beta > 0 && beta <= 1) {
        _beta = beta;
      }
    }
    _lastLevel = parameters['last_level']?.toDouble() ?? 0.0;
    _lastTrend = parameters['last_trend']?.toDouble() ?? 0.0;
  }
}
