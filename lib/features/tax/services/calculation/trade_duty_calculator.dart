import '../../models/rates/tax_rate_model.dart';
import '../../models/fx/fx_rate_model.dart';

enum DutyType {
  importDuty,
  exportDuty,
  exciseDuty,
  antiDumpingDuty,
  countervailingDuty,
  safeguardDuty,
}

enum TradeClassification {
  rawMaterials,
  intermediateGoods,
  finishedGoods,
  capitalGoods,
  consumerGoods,
  luxuryGoods,
  strategicGoods,
  controlledGoods,
}

enum OriginCountry {
  asean,
  cptpp,
  eusfs,
  china,
  india,
  usa,
  uk,
  other,
}

class TradeItem {
  final String hsCode; // Harmonized System Code
  final String description;
  final double quantity;
  final String unitOfMeasure;
  final double unitValue;
  final double totalValue;
  final OriginCountry originCountry;
  final TradeClassification classification;
  final Map<String, dynamic> attributes;

  TradeItem({
    required this.hsCode,
    required this.description,
    required this.quantity,
    required this.unitOfMeasure,
    required this.unitValue,
    required this.totalValue,
    required this.originCountry,
    required this.classification,
    this.attributes = const {},
  });

  Map<String, dynamic> toJson() => {
        'hsCode': hsCode,
        'description': description,
        'quantity': quantity,
        'unitOfMeasure': unitOfMeasure,
        'unitValue': unitValue,
        'totalValue': totalValue,
        'originCountry': originCountry.name,
        'classification': classification.name,
        'attributes': attributes,
      };
}

class DutyRate {
  final String id;
  final String hsCode;
  final DutyType dutyType;
  final double rate;
  final String rateType; // 'percentage', 'specific', 'compound'
  final double? specificAmount;
  final String? unit;
  final OriginCountry? applicableOrigin;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final String? preferentialScheme;
  final Map<String, dynamic> conditions;

  DutyRate({
    required this.id,
    required this.hsCode,
    required this.dutyType,
    required this.rate,
    this.rateType = 'percentage',
    this.specificAmount,
    this.unit,
    this.applicableOrigin,
    required this.effectiveFrom,
    this.effectiveTo,
    this.preferentialScheme,
    this.conditions = const {},
  });

  bool isApplicableTo(TradeItem item, DateTime date) {
    // Check date validity
    if (!_isValidOnDate(date)) return false;

    // Check HS code match
    if (!_hsCodeMatches(item.hsCode)) return false;

    // Check origin if specified
    if (applicableOrigin != null && applicableOrigin != item.originCountry) {
      return false;
    }

    return true;
  }

  bool _isValidOnDate(DateTime date) {
    final isAfterStart =
        date.isAfter(effectiveFrom) || date.isAtSameMomentAs(effectiveFrom);
    final isBeforeEnd = effectiveTo == null || date.isBefore(effectiveTo!);
    return isAfterStart && isBeforeEnd;
  }

  bool _hsCodeMatches(String itemHsCode) {
    // Support wildcard matching (e.g., "8471*" matches "847130")
    if (hsCode.endsWith('*')) {
      final prefix = hsCode.substring(0, hsCode.length - 1);
      return itemHsCode.startsWith(prefix);
    }
    return hsCode == itemHsCode;
  }

  double calculateDuty(double value, {double? quantity}) {
    switch (rateType) {
      case 'percentage':
        return value * rate;
      case 'specific':
        if (specificAmount != null && quantity != null) {
          return quantity * specificAmount!;
        }
        return 0;
      case 'compound':
        final percentageDuty = value * rate;
        final specificDuty = specificAmount != null && quantity != null
            ? quantity * specificAmount!
            : 0;
        return percentageDuty + specificDuty;
      default:
        return value * rate;
    }
  }
}

class TradeDutyResult {
  final TradeItem item;
  final double dutyableValue;
  final List<DutyBreakdown> duties;
  final double totalDutyAmount;
  final double gstAmount;
  final double totalTaxAndDuty;
  final Map<String, dynamic> preferentialBenefits;

  TradeDutyResult({
    required this.item,
    required this.dutyableValue,
    required this.duties,
    required this.totalDutyAmount,
    required this.gstAmount,
    required this.totalTaxAndDuty,
    this.preferentialBenefits = const {},
  });

  Map<String, dynamic> toJson() => {
        'item': item.toJson(),
        'dutyableValue': dutyableValue,
        'duties': duties.map((d) => d.toJson()).toList(),
        'totalDutyAmount': totalDutyAmount,
        'gstAmount': gstAmount,
        'totalTaxAndDuty': totalTaxAndDuty,
        'preferentialBenefits': preferentialBenefits,
      };
}

class DutyBreakdown {
  final DutyType dutyType;
  final String description;
  final double rate;
  final double dutyAmount;
  final String? preferentialScheme;
  final double? standardRate;
  final double? preferentialSavings;

  DutyBreakdown({
    required this.dutyType,
    required this.description,
    required this.rate,
    required this.dutyAmount,
    this.preferentialScheme,
    this.standardRate,
    this.preferentialSavings,
  });

  Map<String, dynamic> toJson() => {
        'dutyType': dutyType.name,
        'description': description,
        'rate': rate,
        'dutyAmount': dutyAmount,
        'preferentialScheme': preferentialScheme,
        'standardRate': standardRate,
        'preferentialSavings': preferentialSavings,
      };
}

class TradeDutyCalculator {
  final Map<String, List<DutyRate>> _dutyRates;
  final double _currentGstRate;

  TradeDutyCalculator({
    Map<String, List<DutyRate>>? dutyRates,
    double currentGstRate = 0.09,
  })  : _dutyRates = dutyRates ?? _getDefaultDutyRates(),
        _currentGstRate = currentGstRate;

  TradeDutyResult calculateImportDuty({
    required TradeItem item,
    required DateTime importDate,
    bool applyPreferentialTreatment = true,
  }) {
    final applicableDuties =
        _getApplicableDuties(item, importDate, DutyType.importDuty);

    // Apply preferential treatment if applicable
    final selectedDuties = applyPreferentialTreatment
        ? _applyPreferentialTreatment(applicableDuties, item)
        : applicableDuties;

    final dutyBreakdowns = <DutyBreakdown>[];
    double totalDutyAmount = 0;

    for (final dutyRate in selectedDuties) {
      final dutyAmount =
          dutyRate.calculateDuty(item.totalValue, quantity: item.quantity);
      totalDutyAmount += dutyAmount;

      // Check for preferential savings
      final standardDuty = _getStandardDuty(item, dutyRate.dutyType);
      final standardAmount = standardDuty?.calculateDuty(item.totalValue,
              quantity: item.quantity) ??
          dutyAmount;
      final savings = standardAmount - dutyAmount;

      dutyBreakdowns.add(DutyBreakdown(
        dutyType: dutyRate.dutyType,
        description: _getDutyDescription(dutyRate),
        rate: dutyRate.rate,
        dutyAmount: dutyAmount,
        preferentialScheme: dutyRate.preferentialScheme,
        standardRate: standardDuty?.rate,
        preferentialSavings: savings > 0 ? savings : null,
      ));
    }

    // Calculate GST on dutyable value (CIF + duties)
    final dutyableValue = item.totalValue + totalDutyAmount;
    final gstAmount = dutyableValue * _currentGstRate;
    final totalTaxAndDuty = totalDutyAmount + gstAmount;

    return TradeDutyResult(
      item: item,
      dutyableValue: dutyableValue,
      duties: dutyBreakdowns,
      totalDutyAmount: totalDutyAmount,
      gstAmount: gstAmount,
      totalTaxAndDuty: totalTaxAndDuty,
      preferentialBenefits: _calculatePreferentialBenefits(dutyBreakdowns),
    );
  }

  List<TradeDutyResult> calculateBulkImportDuty({
    required List<TradeItem> items,
    required DateTime importDate,
    bool applyPreferentialTreatment = true,
  }) {
    return items
        .map((item) => calculateImportDuty(
              item: item,
              importDate: importDate,
              applyPreferentialTreatment: applyPreferentialTreatment,
            ))
        .toList();
  }

  Map<String, dynamic> generateCustomsDeclaration({
    required List<TradeDutyResult> results,
    required String importerName,
    required String importerNumber,
    required DateTime declarationDate,
  }) {
    final totalValue =
        results.fold<double>(0, (sum, r) => sum + r.item.totalValue);
    final totalDuty =
        results.fold<double>(0, (sum, r) => sum + r.totalDutyAmount);
    final totalGst = results.fold<double>(0, (sum, r) => sum + r.gstAmount);

    return {
      'declarationNumber': 'IMP${DateTime.now().millisecondsSinceEpoch}',
      'declarationDate': declarationDate.toIso8601String(),
      'importer': {
        'name': importerName,
        'number': importerNumber,
      },
      'items': results.map((r) => r.toJson()).toList(),
      'summary': {
        'totalItems': results.length,
        'totalValue': totalValue,
        'totalDuty': totalDuty,
        'totalGst': totalGst,
        'totalPayable': totalDuty + totalGst,
      },
      'preferentialSchemes': _summarizePreferentialBenefits(results),
    };
  }

  List<DutyRate> _getApplicableDuties(
      TradeItem item, DateTime date, DutyType dutyType) {
    final hsCodeRates = _dutyRates[item.hsCode] ?? [];
    final wildcardRates = _dutyRates.entries
        .where((entry) =>
            entry.key.endsWith('*') &&
            item.hsCode
                .startsWith(entry.key.substring(0, entry.key.length - 1)))
        .expand((entry) => entry.value)
        .toList();

    final allRates = [...hsCodeRates, ...wildcardRates];

    return allRates
        .where((rate) =>
            rate.dutyType == dutyType && rate.isApplicableTo(item, date))
        .toList();
  }

  List<DutyRate> _applyPreferentialTreatment(
      List<DutyRate> duties, TradeItem item) {
    // Find the most beneficial rates for each duty type
    final Map<DutyType, DutyRate> bestRates = {};

    for (final duty in duties) {
      final existing = bestRates[duty.dutyType];
      if (existing == null || duty.rate < existing.rate) {
        bestRates[duty.dutyType] = duty;
      }
    }

    return bestRates.values.toList();
  }

  DutyRate? _getStandardDuty(TradeItem item, DutyType dutyType) {
    return _dutyRates[item.hsCode]
        ?.where((rate) =>
            rate.dutyType == dutyType && rate.preferentialScheme == null)
        .firstOrNull;
  }

  String _getDutyDescription(DutyRate dutyRate) {
    final baseDesc = '${dutyRate.dutyType.name.replaceAll('Duty', ' Duty')}';
    if (dutyRate.preferentialScheme != null) {
      return '$baseDesc (${dutyRate.preferentialScheme})';
    }
    return baseDesc;
  }

  Map<String, dynamic> _calculatePreferentialBenefits(
      List<DutyBreakdown> breakdowns) {
    final schemes = <String, double>{};
    double totalSavings = 0;

    for (final breakdown in breakdowns) {
      if (breakdown.preferentialSavings != null &&
          breakdown.preferentialSavings! > 0) {
        final scheme = breakdown.preferentialScheme ?? 'Standard';
        schemes[scheme] =
            (schemes[scheme] ?? 0) + breakdown.preferentialSavings!;
        totalSavings += breakdown.preferentialSavings!;
      }
    }

    return {
      'totalSavings': totalSavings,
      'schemeBreakdown': schemes,
      'savingsPercentage': totalSavings > 0
          ? (totalSavings /
                  breakdowns.fold<double>(
                      0, (sum, b) => sum + (b.standardRate ?? b.rate))) *
              100
          : 0,
    };
  }

  Map<String, dynamic> _summarizePreferentialBenefits(
      List<TradeDutyResult> results) {
    final allSchemes = <String, double>{};
    double totalSavings = 0;

    for (final result in results) {
      final benefits = result.preferentialBenefits;
      if (benefits['schemeBreakdown'] != null) {
        final schemeBreakdown =
            benefits['schemeBreakdown'] as Map<String, dynamic>;
        schemeBreakdown.forEach((scheme, savings) {
          allSchemes[scheme] = (allSchemes[scheme] ?? 0) + (savings as double);
        });
      }
      totalSavings += benefits['totalSavings'] ?? 0;
    }

    return {
      'totalPreferentialSavings': totalSavings,
      'schemeUtilization': allSchemes,
      'benefitsApplied': allSchemes.isNotEmpty,
    };
  }

  // Certificate of Origin verification
  bool verifyCertificateOfOrigin(Map<String, dynamic> certificate) {
    final requiredFields = [
      'exporterName',
      'importerName',
      'goodsDescription',
      'originCountry',
      'issueDate',
      'certificateNumber'
    ];

    for (final field in requiredFields) {
      if (!certificate.containsKey(field)) return false;
    }

    // Verify validity period (typically 12 months)
    final issueDate = DateTime.parse(certificate['issueDate']);
    final validityPeriod = certificate['validityMonths'] ?? 12;
    final expiryDate = issueDate.add(Duration(days: validityPeriod * 30));

    return DateTime.now().isBefore(expiryDate);
  }

  static Map<String, List<DutyRate>> _getDefaultDutyRates() {
    return {
      // Electronics (HS Code 8471 - Computers)
      '8471*': [
        DutyRate(
          id: 'computers_standard',
          hsCode: '8471*',
          dutyType: DutyType.importDuty,
          rate: 0.0,
          effectiveFrom: DateTime(2020, 1, 1),
          preferentialScheme: null, // Standard rate
        ),
        DutyRate(
          id: 'computers_asean',
          hsCode: '8471*',
          dutyType: DutyType.importDuty,
          rate: 0.0,
          effectiveFrom: DateTime(2020, 1, 1),
          applicableOrigin: OriginCountry.asean,
          preferentialScheme: 'ASEAN Free Trade Area',
        ),
      ],

      // Textiles (HS Code 6204 - Women's clothing)
      '6204*': [
        DutyRate(
          id: 'textiles_standard',
          hsCode: '6204*',
          dutyType: DutyType.importDuty,
          rate: 0.05, // 5%
          effectiveFrom: DateTime(2020, 1, 1),
        ),
        DutyRate(
          id: 'textiles_asean',
          hsCode: '6204*',
          dutyType: DutyType.importDuty,
          rate: 0.0,
          effectiveFrom: DateTime(2020, 1, 1),
          applicableOrigin: OriginCountry.asean,
          preferentialScheme: 'ASEAN Free Trade Area',
        ),
        DutyRate(
          id: 'textiles_eusfs',
          hsCode: '6204*',
          dutyType: DutyType.importDuty,
          rate: 0.0,
          effectiveFrom: DateTime(2020, 1, 1),
          applicableOrigin: OriginCountry.eusfs,
          preferentialScheme: 'EU-Singapore Free Trade Agreement',
        ),
      ],

      // Luxury goods (HS Code 7113 - Jewelry)
      '7113*': [
        DutyRate(
          id: 'jewelry_standard',
          hsCode: '7113*',
          dutyType: DutyType.importDuty,
          rate: 0.07, // 7%
          effectiveFrom: DateTime(2020, 1, 1),
        ),
      ],

      // Alcohol (HS Code 2208 - Spirits)
      '2208*': [
        DutyRate(
          id: 'spirits_import_duty',
          hsCode: '2208*',
          dutyType: DutyType.importDuty,
          rate: 0.0,
          effectiveFrom: DateTime(2020, 1, 1),
        ),
        DutyRate(
          id: 'spirits_excise_duty',
          hsCode: '2208*',
          dutyType: DutyType.exciseDuty,
          rate: 0.0,
          rateType: 'specific',
          specificAmount: 88.0, // S$88 per litre of alcohol
          unit: 'litre',
          effectiveFrom: DateTime(2020, 1, 1),
        ),
      ],
    };
  }
}
