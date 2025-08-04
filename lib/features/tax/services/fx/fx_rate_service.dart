import 'dart:convert';
import 'dart:math' as math;
import '../../models/fx/fx_rate_model.dart';

abstract class FxRateProvider {
  Future<FxRate?> fetchRate(Currency from, Currency to, DateTime date);
  Future<List<FxRate>> fetchHistoricalRates(
      Currency from, Currency to, DateTime startDate, DateTime endDate);
}

class MasRateProvider implements FxRateProvider {
  // Simulated MAS (Monetary Authority of Singapore) rate provider
  @override
  Future<FxRate?> fetchRate(Currency from, Currency to, DateTime date) async {
    // In real implementation, this would call MAS API
    return _getSimulatedMasRate(from, to, date);
  }

  @override
  Future<List<FxRate>> fetchHistoricalRates(
    Currency from,
    Currency to,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final rates = <FxRate>[];
    var currentDate = startDate;

    while (currentDate.isBefore(endDate) ||
        currentDate.isAtSameMomentAs(endDate)) {
      final rate = await fetchRate(from, to, currentDate);
      if (rate != null) rates.add(rate);
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return rates;
  }

  FxRate? _getSimulatedMasRate(Currency from, Currency to, DateTime date) {
    // Simulate realistic exchange rates with slight daily variations
    final baseRates = {
      'USD_SGD': 1.3520,
      'EUR_SGD': 1.4820,
      'GBP_SGD': 1.7150,
      'JPY_SGD': 0.0091,
      'AUD_SGD': 0.9180,
      'CAD_SGD': 1.0020,
      'CHF_SGD': 1.4950,
      'CNY_SGD': 0.1890,
      'HKD_SGD': 0.1730,
      'INR_SGD': 0.0162,
    };

    final pairKey = '${from.name.toUpperCase()}_${to.name.toUpperCase()}';
    final inversePairKey =
        '${to.name.toUpperCase()}_${from.name.toUpperCase()}';

    double? baseRate;
    bool isInverse = false;

    if (baseRates.containsKey(pairKey)) {
      baseRate = baseRates[pairKey];
    } else if (baseRates.containsKey(inversePairKey)) {
      baseRate = 1.0 / baseRates[inversePairKey]!;
      isInverse = true;
    } else if (from == Currency.sgd) {
      // SGD to other currencies
      final usdSgdRate = baseRates['USD_SGD']!;
      final targetUsdRate = baseRates['USD_${to.name.toUpperCase()}'];
      if (targetUsdRate != null) {
        baseRate = targetUsdRate / usdSgdRate;
      }
    } else if (to == Currency.sgd) {
      // Other currencies to SGD
      final usdSgdRate = baseRates['USD_SGD']!;
      final fromUsdRate = baseRates['USD_${from.name.toUpperCase()}'];
      if (fromUsdRate != null) {
        baseRate = usdSgdRate / fromUsdRate;
      }
    }

    if (baseRate == null) return null;

    // Add daily variation (±0.5%)
    final daysSinceEpoch = date.difference(DateTime(2024, 1, 1)).inDays;
    final variation =
        math.sin(daysSinceEpoch * 0.1) * 0.005; // 0.5% max variation
    final adjustedRate = baseRate * (1 + variation);

    return FxRate(
      id: '${pairKey}_${date.toIso8601String().split('T')[0]}',
      baseCurrency: from,
      targetCurrency: to,
      rate: adjustedRate,
      rateType: RateType.reference,
      source: RateSource.masReferenceRate,
      effectiveDate: date,
      timestamp: date.add(const Duration(hours: 9)), // 9 AM Singapore time
      sourceReference: 'MAS Reference Exchange Rate',
    );
  }
}

class FxRateServiceImpl implements FxRateService {
  final List<FxRateProvider> _providers;
  final Map<String, FxRateHistory> _cache = {};
  final Duration _cacheExpiry = const Duration(hours: 1);

  FxRateServiceImpl({List<FxRateProvider>? providers})
      : _providers = providers ?? [MasRateProvider()];

  @override
  Future<FxRate?> getFxRate(Currency from, Currency to, DateTime date) async {
    if (from == to) {
      return FxRate(
        id: 'same_currency',
        baseCurrency: from,
        targetCurrency: to,
        rate: 1.0,
        rateType: RateType.reference,
        source: RateSource.manual,
        effectiveDate: date,
        timestamp: DateTime.now(),
      );
    }

    // Try providers in order
    for (final provider in _providers) {
      try {
        final rate = await provider.fetchRate(from, to, date);
        if (rate != null) {
          _cacheRate(rate);
          return rate;
        }
      } catch (e) {
        // Continue to next provider
        continue;
      }
    }

    // Fallback to cached data
    return _getCachedRate(from, to, date);
  }

  @override
  Future<double?> convertAmount(
    double amount,
    Currency from,
    Currency to,
    DateTime date,
  ) async {
    final rate = await getFxRate(from, to, date);
    return rate?.convertAmount(amount);
  }

  Future<List<FxRate>> getHistoricalRates(
    Currency from,
    Currency to,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final cacheKey =
        '${from.name}_${to.name}_${startDate.toIso8601String()}_${endDate.toIso8601String()}';

    // Check cache first
    if (_cache.containsKey(cacheKey)) {
      final cachedHistory = _cache[cacheKey]!;
      if (DateTime.now().difference(cachedHistory.lastUpdated) < _cacheExpiry) {
        return cachedHistory.rates;
      }
    }

    // Fetch from providers
    for (final provider in _providers) {
      try {
        final rates =
            await provider.fetchHistoricalRates(from, to, startDate, endDate);
        if (rates.isNotEmpty) {
          _cacheHistoricalRates(from, to, rates, cacheKey);
          return rates;
        }
      } catch (e) {
        continue;
      }
    }

    return [];
  }

  Future<CurrencyConversion> performConversion({
    required double amount,
    required Currency from,
    required Currency to,
    required DateTime date,
    String? transactionReference,
    String? purpose,
  }) async {
    final rate = await getFxRate(from, to, date);
    if (rate == null) {
      throw Exception(
          'Exchange rate not available for ${from.name} to ${to.name} on $date');
    }

    final convertedAmount = rate.convertAmount(amount);

    return CurrencyConversion(
      id: 'conv_${DateTime.now().millisecondsSinceEpoch}',
      fromCurrency: from,
      toCurrency: to,
      originalAmount: amount,
      convertedAmount: convertedAmount,
      exchangeRate: rate.rate,
      conversionDate: date,
      rateSource: rate.source,
      transactionReference: transactionReference,
      purpose: purpose,
    );
  }

  Future<Map<String, dynamic>> getRateAnalysis(
    Currency from,
    Currency to,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final rates = await getHistoricalRates(from, to, startDate, endDate);
    if (rates.isEmpty) return {};

    final rateValues = rates.map((r) => r.rate).toList();
    rateValues.sort();

    final average = rateValues.reduce((a, b) => a + b) / rateValues.length;
    final median = rateValues.length % 2 == 0
        ? (rateValues[rateValues.length ~/ 2 - 1] +
                rateValues[rateValues.length ~/ 2]) /
            2
        : rateValues[rateValues.length ~/ 2];

    final min = rateValues.first;
    final max = rateValues.last;
    final volatility = _calculateVolatility(rateValues);

    return {
      'currencyPair': '${from.name.toUpperCase()}/${to.name.toUpperCase()}',
      'period': {
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'days': rates.length,
      },
      'statistics': {
        'average': average,
        'median': median,
        'minimum': min,
        'maximum': max,
        'volatility': volatility,
        'range': max - min,
        'rangePercentage': ((max - min) / average) * 100,
      },
      'trend': _calculateTrend(rates),
      'lastRate': rates.last.rate,
      'lastUpdated': rates.last.timestamp.toIso8601String(),
    };
  }

  Future<List<Map<String, dynamic>>> getMultiCurrencyRates(
    Currency baseCurrency,
    List<Currency> targetCurrencies,
    DateTime date,
  ) async {
    final results = <Map<String, dynamic>>[];

    for (final target in targetCurrencies) {
      final rate = await getFxRate(baseCurrency, target, date);
      results.add({
        'currency': target.name.toUpperCase(),
        'rate': rate?.rate,
        'available': rate != null,
        'source': rate?.source.name,
        'timestamp': rate?.timestamp.toIso8601String(),
      });
    }

    return results;
  }

  Future<Map<String, dynamic>> calculateFxExposure({
    required List<Map<String, dynamic>>
        positions, // {'currency': Currency, 'amount': double}
    required Currency baseCurrency,
    required DateTime valuationDate,
  }) async {
    final exposures = <String, double>{};
    double totalExposure = 0;

    for (final position in positions) {
      final currency = position['currency'] as Currency;
      final amount = position['amount'] as double;

      if (currency == baseCurrency) {
        exposures[currency.name.toUpperCase()] = amount;
        totalExposure += amount;
      } else {
        final convertedAmount =
            await convertAmount(amount, currency, baseCurrency, valuationDate);
        if (convertedAmount != null) {
          exposures[currency.name.toUpperCase()] = convertedAmount;
          totalExposure += convertedAmount;
        }
      }
    }

    // Calculate percentage exposure
    final percentageExposures = <String, double>{};
    exposures.forEach((currency, amount) {
      percentageExposures[currency] =
          totalExposure != 0 ? (amount / totalExposure) * 100 : 0;
    });

    return {
      'baseCurrency': baseCurrency.name.toUpperCase(),
      'valuationDate': valuationDate.toIso8601String(),
      'positions': exposures,
      'percentageExposures': percentageExposures,
      'totalExposure': totalExposure,
      'diversification': _calculateDiversification(percentageExposures),
    };
  }

  void _cacheRate(FxRate rate) {
    final key = '${rate.baseCurrency.name}_${rate.targetCurrency.name}';
    if (!_cache.containsKey(key)) {
      _cache[key] = FxRateHistory(
        baseCurrency: rate.baseCurrency,
        targetCurrency: rate.targetCurrency,
        rates: [rate],
        lastUpdated: DateTime.now(),
      );
    } else {
      final existing = _cache[key]!;
      if (!existing.rates
          .any((r) => r.effectiveDate.isAtSameMomentAs(rate.effectiveDate))) {
        existing.rates.add(rate);
      }
    }
  }

  void _cacheHistoricalRates(
      Currency from, Currency to, List<FxRate> rates, String cacheKey) {
    _cache[cacheKey] = FxRateHistory(
      baseCurrency: from,
      targetCurrency: to,
      rates: rates,
      lastUpdated: DateTime.now(),
    );
  }

  FxRate? _getCachedRate(Currency from, Currency to, DateTime date) {
    final key = '${from.name}_${to.name}';
    final history = _cache[key];
    return history?.getRateForDate(date);
  }

  double _calculateVolatility(List<double> rates) {
    if (rates.length < 2) return 0;

    final mean = rates.reduce((a, b) => a + b) / rates.length;
    final squaredDifferences = rates.map((rate) => math.pow(rate - mean, 2));
    final variance =
        squaredDifferences.reduce((a, b) => a + b) / (rates.length - 1);

    return math.sqrt(variance);
  }

  String _calculateTrend(List<FxRate> rates) {
    if (rates.length < 2) return 'insufficient_data';

    final firstRate = rates.first.rate;
    final lastRate = rates.last.rate;
    final change = ((lastRate - firstRate) / firstRate) * 100;

    if (change > 1) return 'strengthening';
    if (change < -1) return 'weakening';
    return 'stable';
  }

  double _calculateDiversification(Map<String, double> percentageExposures) {
    // Calculate Herfindahl-Hirschman Index for diversification
    double hhi = 0;
    percentageExposures.values.forEach((percentage) {
      hhi += math.pow(percentage, 2);
    });

    // Convert to diversification score (0-100, higher is more diversified)
    return math.max(0, 100 - (hhi / 100));
  }
}

// Utility class for FX risk management
class FxRiskManager {
  final FxRateServiceImpl _fxService;

  FxRiskManager(this._fxService);

  Future<Map<String, dynamic>> assessFxRisk({
    required List<Map<String, dynamic>> futurePayments,
    required Currency baseCurrency,
    required DateTime assessmentDate,
  }) async {
    final risks = <Map<String, dynamic>>[];
    double totalRiskAmount = 0;

    for (final payment in futurePayments) {
      final currency = payment['currency'] as Currency;
      final amount = payment['amount'] as double;
      final paymentDate = DateTime.parse(payment['paymentDate']);

      if (currency != baseCurrency) {
        // Calculate potential FX impact
        final currentRate =
            await _fxService.getFxRate(currency, baseCurrency, assessmentDate);
        final historicalRates = await _fxService.getHistoricalRates(
          currency,
          baseCurrency,
          assessmentDate.subtract(const Duration(days: 365)),
          assessmentDate,
        );

        if (currentRate != null && historicalRates.isNotEmpty) {
          final volatility =
              _calculateVolatility(historicalRates.map((r) => r.rate).toList());
          final potentialImpact = amount * currentRate.rate * volatility;
          totalRiskAmount += potentialImpact;

          risks.add({
            'currency': currency.name.toUpperCase(),
            'amount': amount,
            'paymentDate': paymentDate.toIso8601String(),
            'currentRate': currentRate.rate,
            'volatility': volatility,
            'potentialImpact': potentialImpact,
            'riskLevel': _assessRiskLevel(volatility),
          });
        }
      }
    }

    return {
      'assessmentDate': assessmentDate.toIso8601String(),
      'baseCurrency': baseCurrency.name.toUpperCase(),
      'totalPayments': futurePayments.length,
      'totalRiskAmount': totalRiskAmount,
      'risks': risks,
      'overallRiskLevel': _assessOverallRisk(risks),
      'recommendations': _generateRiskRecommendations(risks),
    };
  }

  double _calculateVolatility(List<double> rates) {
    if (rates.length < 2) return 0;

    final mean = rates.reduce((a, b) => a + b) / rates.length;
    final squaredDifferences = rates.map((rate) => math.pow(rate - mean, 2));
    final variance =
        squaredDifferences.reduce((a, b) => a + b) / (rates.length - 1);

    return math.sqrt(variance);
  }

  String _assessRiskLevel(double volatility) {
    if (volatility > 0.05) return 'high';
    if (volatility > 0.02) return 'medium';
    return 'low';
  }

  String _assessOverallRisk(List<Map<String, dynamic>> risks) {
    if (risks.isEmpty) return 'none';

    final highRiskCount = risks.where((r) => r['riskLevel'] == 'high').length;
    final mediumRiskCount =
        risks.where((r) => r['riskLevel'] == 'medium').length;

    if (highRiskCount > risks.length * 0.3) return 'high';
    if (mediumRiskCount > risks.length * 0.5) return 'medium';
    return 'low';
  }

  List<String> _generateRiskRecommendations(List<Map<String, dynamic>> risks) {
    final recommendations = <String>[];

    final highRiskCurrencies = risks
        .where((r) => r['riskLevel'] == 'high')
        .map((r) => r['currency'])
        .toSet();

    if (highRiskCurrencies.isNotEmpty) {
      recommendations.add(
          'Consider FX hedging for high-risk currencies: ${highRiskCurrencies.join(', ')}');
    }

    final totalExposure =
        risks.fold<double>(0, (sum, r) => sum + r['potentialImpact']);
    if (totalExposure > 100000) {
      // Threshold for significant exposure
      recommendations
          .add('Total FX exposure is significant. Review hedging strategies.');
    }

    recommendations.add(
        'Monitor exchange rates regularly and consider forward contracts for large payments.');

    return recommendations;
  }
}
