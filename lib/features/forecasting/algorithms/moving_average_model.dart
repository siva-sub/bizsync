import 'dart:math' as math;
import '../models/forecasting_models.dart';

/// Moving average forecasting model
class MovingAverageModel implements ForecastingModel {
  @override
  String get name => 'Moving Average';

  @override
  ForecastingMethod get method => ForecastingMethod.movingAverage;

  int _windowSize = 3;
  List<TimeSeriesPoint> _trainingData = [];
  List<double> _movingAverages = [];

  /// Creates a moving average model with specified window size
  MovingAverageModel({int windowSize = 3}) : _windowSize = windowSize;

  @override
  Future<void> train(List<TimeSeriesPoint> data) async {
    if (data.length < _windowSize) {
      throw ArgumentError(
          'Need at least $_windowSize data points for moving average');
    }

    _trainingData = List.from(data);
    _movingAverages =
        _calculateMovingAverages(data.map((p) => p.value).toList());
  }

  List<double> _calculateMovingAverages(List<double> values) {
    final movingAverages = <double>[];

    for (int i = _windowSize - 1; i < values.length; i++) {
      double sum = 0.0;
      for (int j = i - _windowSize + 1; j <= i; j++) {
        sum += values[j];
      }
      movingAverages.add(sum / _windowSize);
    }

    return movingAverages;
  }

  @override
  Future<List<ForecastResult>> forecast(int periods) async {
    if (_trainingData.isEmpty) {
      throw StateError('Model must be trained before forecasting');
    }

    final results = <ForecastResult>[];
    final lastValues = _trainingData
        .skip(_trainingData.length - _windowSize)
        .map((p) => p.value)
        .toList();

    // Calculate standard deviation for confidence intervals
    final standardDeviation = _calculateStandardDeviation();

    for (int i = 1; i <= periods; i++) {
      final futureDate = _trainingData.last.date.add(Duration(days: i));

      // Calculate moving average of last window
      final average = lastValues.reduce((a, b) => a + b) / lastValues.length;

      // For confidence intervals, use standard deviation
      final margin = 1.96 * standardDeviation; // 95% confidence

      results.add(ForecastResult(
        date: futureDate,
        predictedValue: average,
        lowerBound: average - margin,
        upperBound: average + margin,
        confidence: 0.95,
        method: method.displayName,
        metrics: {
          'window_size': _windowSize,
          'last_values': lastValues,
          'standard_deviation': standardDeviation,
        },
      ));

      // Update lastValues for next prediction (use predicted value)
      lastValues.removeAt(0);
      lastValues.add(average);
    }

    return results;
  }

  double _calculateStandardDeviation() {
    if (_movingAverages.isEmpty) return 0.0;

    final mean =
        _movingAverages.reduce((a, b) => a + b) / _movingAverages.length;
    double sumSquaredDifferences = 0.0;

    for (final value in _movingAverages) {
      sumSquaredDifferences += (value - mean) * (value - mean);
    }

    return math.sqrt(sumSquaredDifferences / _movingAverages.length);
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

    // Use the last windowSize values from training data as initial values
    final predictorValues = _trainingData
        .skip(_trainingData.length - _windowSize)
        .map((p) => p.value)
        .toList();

    for (final point in testData) {
      final predicted =
          predictorValues.reduce((a, b) => a + b) / predictorValues.length;
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

      // Update predictor values for next prediction
      predictorValues.removeAt(0);
      predictorValues.add(actual);
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

    // Reset predictor values for R-squared calculation
    final predictorValuesR2 = _trainingData
        .skip(_trainingData.length - _windowSize)
        .map((p) => p.value)
        .toList();

    for (final point in testData) {
      if (point.value != 0) {
        ssTot += (point.value - meanActual) * (point.value - meanActual);
      }
      predictorValuesR2.removeAt(0);
      predictorValuesR2.add(point.value);
    }

    final r2 = ssTot != 0 ? 1 - (sumSquaredResiduals / ssTot) : 0.0;

    // Calculate AIC and BIC (simplified versions)
    final n = validPoints;
    final k = 1; // Number of parameters (window size)
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
      'window_size': _windowSize,
      'training_points': _trainingData.length,
      'moving_averages_count': _movingAverages.length,
    };
  }

  @override
  void setParameters(Map<String, dynamic> parameters) {
    _windowSize = parameters['window_size'] ?? 3;
  }
}

/// Weighted Moving Average Model
class WeightedMovingAverageModel implements ForecastingModel {
  @override
  String get name => 'Weighted Moving Average';

  @override
  ForecastingMethod get method => ForecastingMethod.movingAverage;

  List<double> _weights = [];
  List<TimeSeriesPoint> _trainingData = [];

  /// Creates a weighted moving average model with specified weights
  /// Weights should be in ascending order of importance (latest weight last)
  WeightedMovingAverageModel({List<double>? weights}) {
    _weights =
        weights ?? [0.1, 0.3, 0.6]; // Default weights favoring recent data
    _normalizeWeights();
  }

  void _normalizeWeights() {
    final sum = _weights.reduce((a, b) => a + b);
    if (sum > 0) {
      _weights = _weights.map((w) => w / sum).toList();
    }
  }

  @override
  Future<void> train(List<TimeSeriesPoint> data) async {
    if (data.length < _weights.length) {
      throw ArgumentError(
          'Need at least ${_weights.length} data points for weighted moving average');
    }

    _trainingData = List.from(data);
  }

  @override
  Future<List<ForecastResult>> forecast(int periods) async {
    if (_trainingData.isEmpty) {
      throw StateError('Model must be trained before forecasting');
    }

    final results = <ForecastResult>[];
    final lastValues = _trainingData
        .skip(_trainingData.length - _weights.length)
        .map((p) => p.value)
        .toList();

    // Calculate standard deviation for confidence intervals
    final standardDeviation = _calculateStandardDeviation();

    for (int i = 1; i <= periods; i++) {
      final futureDate = _trainingData.last.date.add(Duration(days: i));

      // Calculate weighted average
      double weightedSum = 0.0;
      for (int j = 0; j < _weights.length; j++) {
        weightedSum += lastValues[j] * _weights[j];
      }

      // For confidence intervals, use standard deviation
      final margin = 1.96 * standardDeviation; // 95% confidence

      results.add(ForecastResult(
        date: futureDate,
        predictedValue: weightedSum,
        lowerBound: weightedSum - margin,
        upperBound: weightedSum + margin,
        confidence: 0.95,
        method: method.displayName,
        metrics: {
          'weights': _weights,
          'last_values': lastValues,
          'standard_deviation': standardDeviation,
        },
      ));

      // Update lastValues for next prediction
      lastValues.removeAt(0);
      lastValues.add(weightedSum);
    }

    return results;
  }

  double _calculateStandardDeviation() {
    if (_trainingData.length < 2) return 0.0;

    final values = _trainingData.map((p) => p.value).toList();
    final mean = values.reduce((a, b) => a + b) / values.length;
    double sumSquaredDifferences = 0.0;

    for (final value in values) {
      sumSquaredDifferences += (value - mean) * (value - mean);
    }

    return math.sqrt(sumSquaredDifferences / values.length);
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

    // Use the last weights.length values from training data as initial values
    final predictorValues = _trainingData
        .skip(_trainingData.length - _weights.length)
        .map((p) => p.value)
        .toList();

    for (final point in testData) {
      // Calculate weighted average
      double weightedSum = 0.0;
      for (int j = 0; j < _weights.length; j++) {
        weightedSum += predictorValues[j] * _weights[j];
      }

      final predicted = weightedSum;
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

      // Update predictor values for next prediction
      predictorValues.removeAt(0);
      predictorValues.add(actual);
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
    final k = _weights.length; // Number of parameters (weights)
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
      'weights': _weights,
      'training_points': _trainingData.length,
    };
  }

  @override
  void setParameters(Map<String, dynamic> parameters) {
    if (parameters['weights'] != null) {
      _weights = List<double>.from(parameters['weights']);
      _normalizeWeights();
    }
  }
}
