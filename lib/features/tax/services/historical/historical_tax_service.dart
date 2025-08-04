import 'dart:convert';
import '../../models/rates/tax_rate_model.dart';
import '../../models/company/company_tax_profile.dart';

class TaxRateChange {
  final TaxRate previousRate;
  final TaxRate newRate;
  final DateTime changeDate;
  final String reason;
  final double impact; // Percentage change

  TaxRateChange({
    required this.previousRate,
    required this.newRate,
    required this.changeDate,
    required this.reason,
    required this.impact,
  });

  Map<String, dynamic> toJson() => {
        'previousRate': previousRate.toJson(),
        'newRate': newRate.toJson(),
        'changeDate': changeDate.toIso8601String(),
        'reason': reason,
        'impact': impact,
      };
}

class TaxImpactAnalysis {
  final double previousTaxAmount;
  final double newTaxAmount;
  final double absoluteChange;
  final double percentageChange;
  final DateTime effectiveDate;
  final String description;

  TaxImpactAnalysis({
    required this.previousTaxAmount,
    required this.newTaxAmount,
    required this.absoluteChange,
    required this.percentageChange,
    required this.effectiveDate,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
        'previousTaxAmount': previousTaxAmount,
        'newTaxAmount': newTaxAmount,
        'absoluteChange': absoluteChange,
        'percentageChange': percentageChange,
        'effectiveDate': effectiveDate.toIso8601String(),
        'description': description,
      };
}

class HistoricalTaxQuery {
  final TaxType taxType;
  final DateTime startDate;
  final DateTime endDate;
  final CompanyType? companyType;
  final double? transactionAmount;

  HistoricalTaxQuery({
    required this.taxType,
    required this.startDate,
    required this.endDate,
    this.companyType,
    this.transactionAmount,
  });
}

abstract class HistoricalTaxService {
  Future<List<TaxRate>> getHistoricalRates(HistoricalTaxQuery query);
  Future<TaxRate?> getRateForSpecificDate(TaxType taxType, DateTime date,
      {CompanyType? companyType});
  Future<List<TaxRateChange>> getTaxRateChanges(
      TaxType taxType, DateTime startDate, DateTime endDate);
  Future<TaxImpactAnalysis> analyzeTaxImpact(
      TaxType taxType, double amount, DateTime oldDate, DateTime newDate,
      {CompanyType? companyType});
  Future<Map<String, dynamic>> generateTaxRateReport(
      DateTime startDate, DateTime endDate);
}

class HistoricalTaxServiceImpl implements HistoricalTaxService {
  // In a real implementation, this would connect to a database
  final Map<TaxType, HistoricalTaxRates> _historicalRates = {
    TaxType.gst: SingaporeTaxRates.getGstHistory(),
    TaxType.corporateTax: SingaporeTaxRates.getCorporateTaxHistory(),
    TaxType.withholdingTax: SingaporeTaxRates.getWithholdingTaxHistory(),
    TaxType.stampDuty: SingaporeTaxRates.getStampDutyHistory(),
  };

  @override
  Future<List<TaxRate>> getHistoricalRates(HistoricalTaxQuery query) async {
    final historicalRates = _historicalRates[query.taxType];
    if (historicalRates == null) return [];

    return historicalRates
        .getRatesInPeriod(query.startDate, query.endDate)
        .where((rate) =>
            query.companyType == null || rate.appliesTo(query.companyType!))
        .toList()
      ..sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom));
  }

  @override
  Future<TaxRate?> getRateForSpecificDate(
    TaxType taxType,
    DateTime date, {
    CompanyType? companyType,
  }) async {
    final historicalRates = _historicalRates[taxType];
    if (historicalRates == null) return null;

    return historicalRates.getRateForDate(date, companyType: companyType);
  }

  @override
  Future<List<TaxRateChange>> getTaxRateChanges(
    TaxType taxType,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final rates = await getHistoricalRates(HistoricalTaxQuery(
      taxType: taxType,
      startDate: startDate,
      endDate: endDate,
    ));

    final changes = <TaxRateChange>[];
    for (int i = 1; i < rates.length; i++) {
      final previousRate = rates[i - 1];
      final currentRate = rates[i];

      final impact =
          ((currentRate.rate - previousRate.rate) / previousRate.rate) * 100;

      changes.add(TaxRateChange(
        previousRate: previousRate,
        newRate: currentRate,
        changeDate: currentRate.effectiveFrom,
        reason: _getRateChangeReason(taxType, currentRate),
        impact: impact,
      ));
    }

    return changes;
  }

  @override
  Future<TaxImpactAnalysis> analyzeTaxImpact(
    TaxType taxType,
    double amount,
    DateTime oldDate,
    DateTime newDate, {
    CompanyType? companyType,
  }) async {
    final oldRate = await getRateForSpecificDate(taxType, oldDate,
        companyType: companyType);
    final newRate = await getRateForSpecificDate(taxType, newDate,
        companyType: companyType);

    if (oldRate == null || newRate == null) {
      throw Exception('Tax rate not found for specified dates');
    }

    final previousTaxAmount = amount * oldRate.rate;
    final newTaxAmount = amount * newRate.rate;
    final absoluteChange = newTaxAmount - previousTaxAmount;
    final percentageChange =
        previousTaxAmount != 0 ? (absoluteChange / previousTaxAmount) * 100 : 0;

    return TaxImpactAnalysis(
      previousTaxAmount: previousTaxAmount,
      newTaxAmount: newTaxAmount,
      absoluteChange: absoluteChange,
      percentageChange: percentageChange,
      effectiveDate: newRate.effectiveFrom,
      description:
          _generateImpactDescription(taxType, oldRate, newRate, absoluteChange),
    );
  }

  @override
  Future<Map<String, dynamic>> generateTaxRateReport(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final report = <String, dynamic>{
      'reportPeriod': {
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      },
      'taxTypes': <String, dynamic>{},
      'summary': <String, dynamic>{},
      'generatedAt': DateTime.now().toIso8601String(),
    };

    int totalChanges = 0;

    for (final taxType in TaxType.values) {
      final changes = await getTaxRateChanges(taxType, startDate, endDate);
      totalChanges += changes.length;

      report['taxTypes'][taxType.name] = {
        'changes': changes.map((c) => c.toJson()).toList(),
        'changeCount': changes.length,
        'currentRate': await _getCurrentRate(taxType),
      };
    }

    report['summary'] = {
      'totalTaxTypes': TaxType.values.length,
      'totalChanges': totalChanges,
      'mostVolatileTaxType': _findMostVolatileTaxType(report['taxTypes']),
      'significantChanges': _findSignificantChanges(report['taxTypes']),
    };

    return report;
  }

  String _getRateChangeReason(TaxType taxType, TaxRate newRate) {
    switch (taxType) {
      case TaxType.gst:
        if (newRate.effectiveFrom.year == 2023) {
          return 'Budget 2022 announcement - GST increase to fund social spending';
        } else if (newRate.effectiveFrom.year >= DateTime.now().year) {
          return 'Second phase of GST increase as announced in Budget 2022';
        }
        return 'Government policy adjustment';

      case TaxType.corporateTax:
        return 'Corporate tax policy revision';

      default:
        return 'Tax policy adjustment';
    }
  }

  String _generateImpactDescription(
    TaxType taxType,
    TaxRate oldRate,
    TaxRate newRate,
    double absoluteChange,
  ) {
    final direction = absoluteChange >= 0 ? 'increase' : 'decrease';
    final oldPercentage = (oldRate.rate * 100).toStringAsFixed(1);
    final newPercentage = (newRate.rate * 100).toStringAsFixed(1);

    return 'Tax rate changed from $oldPercentage% to $newPercentage%, '
        'resulting in a ${direction} of S\$${absoluteChange.abs().toStringAsFixed(2)}';
  }

  Future<Map<String, dynamic>?> _getCurrentRate(TaxType taxType) async {
    final currentRate = await getRateForSpecificDate(taxType, DateTime.now());
    return currentRate?.toJson();
  }

  String _findMostVolatileTaxType(Map<String, dynamic> taxTypes) {
    String mostVolatile = '';
    int maxChanges = 0;

    taxTypes.forEach((taxType, data) {
      final changeCount = data['changeCount'] as int;
      if (changeCount > maxChanges) {
        maxChanges = changeCount;
        mostVolatile = taxType;
      }
    });

    return mostVolatile;
  }

  List<Map<String, dynamic>> _findSignificantChanges(
      Map<String, dynamic> taxTypes) {
    final significantChanges = <Map<String, dynamic>>[];

    taxTypes.forEach((taxType, data) {
      final changes = data['changes'] as List;
      for (final change in changes) {
        final impact = (change['impact'] as num).abs();
        if (impact >= 10) {
          // Changes of 10% or more
          significantChanges.add({
            'taxType': taxType,
            'impact': impact,
            'changeDate': change['changeDate'],
            'reason': change['reason'],
          });
        }
      }
    });

    return significantChanges;
  }

  // Utility methods for specific historical queries
  Future<List<TaxRate>> getGstRateHistory() async {
    return await getHistoricalRates(HistoricalTaxQuery(
      taxType: TaxType.gst,
      startDate: DateTime(1994, 1, 1),
      endDate: DateTime.now(),
    ));
  }

  Future<double> calculateHistoricalGstImpact(
      double amount, DateTime transactionDate) async {
    final currentRate =
        await getRateForSpecificDate(TaxType.gst, DateTime.now());
    final historicalRate =
        await getRateForSpecificDate(TaxType.gst, transactionDate);

    if (currentRate == null || historicalRate == null) return 0;

    final currentTax = amount * currentRate.rate;
    final historicalTax = amount * historicalRate.rate;

    return currentTax - historicalTax;
  }

  Future<Map<String, dynamic>> getCorporateTaxEvolution(
      CompanyType companyType) async {
    final rates = await getHistoricalRates(HistoricalTaxQuery(
      taxType: TaxType.corporateTax,
      startDate: DateTime(2000, 1, 1),
      endDate: DateTime.now(),
      companyType: companyType,
    ));

    return {
      'companyType': companyType.name,
      'rateHistory': rates
          .map((r) => {
                'rate': r.rate,
                'effectiveFrom': r.effectiveFrom.toIso8601String(),
                'effectiveTo': r.effectiveTo?.toIso8601String(),
                'description': r.description,
              })
          .toList(),
      'averageRate': rates.isNotEmpty
          ? rates.map((r) => r.rate).reduce((a, b) => a + b) / rates.length
          : 0,
      'lowestRate': rates.isNotEmpty
          ? rates.map((r) => r.rate).reduce((a, b) => a < b ? a : b)
          : 0,
      'highestRate': rates.isNotEmpty
          ? rates.map((r) => r.rate).reduce((a, b) => a > b ? a : b)
          : 0,
    };
  }

  Future<List<Map<String, dynamic>>> predictUpcomingChanges() async {
    // This would integrate with government announcements, budget data, etc.
    // For now, return empty list as no changes are announced
    return [];
  }

  Future<Map<String, dynamic>> benchmarkAgainstRegion() async {
    // Compare Singapore tax rates with regional peers
    return {
      'gst': {
        'singapore': 0.09, // Current as of 2024
        'malaysia': 0.06, // SST
        'thailand': 0.07, // VAT
        'indonesia': 0.11, // VAT
        'philippines': 0.12, // VAT
        'vietnam': 0.10, // VAT
      },
      'corporateTax': {
        'singapore': 0.17,
        'malaysia': 0.24,
        'thailand': 0.20,
        'indonesia': 0.22,
        'philippines': 0.25,
        'vietnam': 0.20,
      },
      'analysis': {
        'gstRanking': 'competitive',
        'corporateTaxRanking': 'competitive',
        'overallRanking': 'favorable',
      },
    };
  }
}
