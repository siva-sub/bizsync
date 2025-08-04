import 'dart:math' as math;
import '../models/forecasting_models.dart';

/// Linear regression forecasting model
class LinearRegressionModel implements ForecastingModel {
  @override
  String get name => 'Linear Regression';

  @override
  ForecastingMethod get method => ForecastingMethod.linearRegression;

  double _slope = 0.0;
  double _intercept = 0.0;
  double _r2 = 0.0;
  List<TimeSeriesPoint> _trainingData = [];
  int _n = 0;

  @override
  Future<void> train(List<TimeSeriesPoint> data) async {
    if (data.length < 2) {
      throw ArgumentError('Need at least 2 data points for linear regression');
    }

    _trainingData = List.from(data);
    _n = data.length;

    // Convert dates to numeric values (days since first data point)
    final firstDate = data.first.date;
    final List<double> x = [];
    final List<double> y = [];

    for (final point in data) {
      x.add(point.date.difference(firstDate).inDays.toDouble());
      y.add(point.value);
    }

    // Calculate linear regression coefficients
    _calculateLinearRegression(x, y);
  }

  void _calculateLinearRegression(List<double> x, List<double> y) {
    final n = x.length;

    // Calculate means
    final meanX = x.reduce((a, b) => a + b) / n;
    final meanY = y.reduce((a, b) => a + b) / n;

    // Calculate slope and intercept using least squares method
    double numerator = 0.0;
    double denominator = 0.0;

    for (int i = 0; i < n; i++) {
      numerator += (x[i] - meanX) * (y[i] - meanY);
      denominator += (x[i] - meanX) * (x[i] - meanX);
    }

    _slope = denominator != 0 ? numerator / denominator : 0.0;
    _intercept = meanY - _slope * meanX;

    // Calculate R-squared
    double ssRes = 0.0; // Sum of squares of residuals
    double ssTot = 0.0; // Total sum of squares

    for (int i = 0; i < n; i++) {
      final predicted = _slope * x[i] + _intercept;
      ssRes += (y[i] - predicted) * (y[i] - predicted);
      ssTot += (y[i] - meanY) * (y[i] - meanY);
    }

    _r2 = ssTot != 0 ? 1 - (ssRes / ssTot) : 0.0;
  }

  @override
  Future<List<ForecastResult>> forecast(int periods) async {
    if (_trainingData.isEmpty) {
      throw StateError('Model must be trained before forecasting');
    }

    final results = <ForecastResult>[];
    final lastDate = _trainingData.last.date;
    final firstDate = _trainingData.first.date;
    final lastDaysSinceStart = lastDate.difference(firstDate).inDays.toDouble();

    // Calculate standard error for confidence intervals
    final standardError = _calculateStandardError();

    for (int i = 1; i <= periods; i++) {
      final futureDate = lastDate.add(Duration(days: i));
      final daysSinceStart = lastDaysSinceStart + i;

      final predicted = _slope * daysSinceStart + _intercept;

      // Calculate confidence interval (95% by default)
      final tValue = 1.96; // For 95% confidence
      final margin = tValue *
          standardError *
          math.sqrt(1 +
              1 / _n +
              (daysSinceStart - _getMeanX()) *
                  (daysSinceStart - _getMeanX()) /
                  _getSumXSquared());

      results.add(ForecastResult(
        date: futureDate,
        predictedValue: predicted,
        lowerBound: predicted - margin,
        upperBound: predicted + margin,
        confidence: 0.95,
        method: method.displayName,
        metrics: {
          'slope': _slope,
          'intercept': _intercept,
          'r_squared': _r2,
          'standard_error': standardError,
        },
      ));
    }

    return results;
  }

  double _calculateStandardError() {
    if (_trainingData.length < 2) return 0.0;

    final firstDate = _trainingData.first.date;
    double sumSquaredResiduals = 0.0;

    for (final point in _trainingData) {
      final x = point.date.difference(firstDate).inDays.toDouble();
      final predicted = _slope * x + _intercept;
      final residual = point.value - predicted;
      sumSquaredResiduals += residual * residual;
    }

    return math.sqrt(sumSquaredResiduals / (_trainingData.length - 2));
  }

  double _getMeanX() {
    if (_trainingData.isEmpty) return 0.0;

    final firstDate = _trainingData.first.date;
    double sum = 0.0;

    for (final point in _trainingData) {
      sum += point.date.difference(firstDate).inDays.toDouble();
    }

    return sum / _trainingData.length;
  }

  double _getSumXSquared() {
    if (_trainingData.isEmpty) return 0.0;

    final firstDate = _trainingData.first.date;
    final meanX = _getMeanX();
    double sum = 0.0;

    for (final point in _trainingData) {
      final x = point.date.difference(firstDate).inDays.toDouble();
      sum += (x - meanX) * (x - meanX);
    }

    return sum;
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

    final firstDate = _trainingData.first.date;
    double sumAbsoluteError = 0.0;
    double sumAbsolutePercentageError = 0.0;
    double sumSquaredError = 0.0;
    double sumActual = 0.0;
    double sumSquaredActual = 0.0;
    double sumSquaredResiduals = 0.0;
    int validPoints = 0;

    for (final point in testData) {
      final x = point.date.difference(firstDate).inDays.toDouble();
      final predicted = _slope * x + _intercept;
      final actual = point.value;

      if (actual != 0) {
        final absoluteError = (actual - predicted).abs();
        final percentageError = (absoluteError / actual.abs()) * 100;

        sumAbsoluteError += absoluteError;
        sumAbsolutePercentageError += percentageError;
        sumSquaredError += (actual - predicted) * (actual - predicted);
        sumActual += actual;
        sumSquaredActual += actual * actual;
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
    final k = 2; // Number of parameters (slope and intercept)
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
      'slope': _slope,
      'intercept': _intercept,
      'r_squared': _r2,
      'training_points': _n,
    };
  }

  @override
  void setParameters(Map<String, dynamic> parameters) {
    _slope = parameters['slope']?.toDouble() ?? 0.0;
    _intercept = parameters['intercept']?.toDouble() ?? 0.0;
    _r2 = parameters['r_squared']?.toDouble() ?? 0.0;
    _n = parameters['training_points'] ?? 0;
  }
}
