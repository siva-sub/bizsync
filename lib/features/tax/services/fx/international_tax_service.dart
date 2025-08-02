import '../../models/fx/fx_rate_model.dart';
import '../../models/company/company_tax_profile.dart';

enum TreatyBenefit {
  reducedWithholdingTax,
  exemptionFromTax,
  creditForForeignTax,
  reducedCorporateTax,
  mutualAgreementProcedure,
  exchangeOfInformation,
}

enum TaxResidencyStatus {
  resident,
  nonResident,
  dualResident,
  treatyResident,
}

class TaxTreaty {
  final String treatyId;
  final String countryA;
  final String countryB;
  final String officialName;
  final DateTime signedDate;
  final DateTime effectiveDate;
  final DateTime? terminationDate;
  final Map<String, double> withholdingTaxRates;
  final Map<String, dynamic> specialProvisions;
  final List<TreatyBenefit> availableBenefits;
  final String? protocolReference;
  final DateTime lastAmended;

  TaxTreaty({
    required this.treatyId,
    required this.countryA,
    required this.countryB,
    required this.officialName,
    required this.signedDate,
    required this.effectiveDate,
    this.terminationDate,
    required this.withholdingTaxRates,
    this.specialProvisions = const {},
    required this.availableBenefits,
    this.protocolReference,
    required this.lastAmended,
  });

  bool isEffectiveOn(DateTime date) {
    return date.isAfter(effectiveDate) &&
           (terminationDate == null || date.isBefore(terminationDate!));
  }

  double? getWithholdingTaxRate(String incomeType, {Map<String, dynamic>? conditions}) {
    final baseRate = withholdingTaxRates[incomeType];
    if (baseRate == null) return null;

    // Apply special conditions if applicable
    if (conditions != null && specialProvisions.containsKey(incomeType)) {
      final provisions = specialProvisions[incomeType] as Map<String, dynamic>?;
      if (provisions != null) {
        return _applySpecialProvisions(baseRate, provisions, conditions);
      }
    }

    return baseRate;
  }

  double _applySpecialProvisions(
    double baseRate,
    Map<String, dynamic> provisions,
    Map<String, dynamic> conditions,
  ) {
    // Example: Reduced rate for substantial shareholding
    if (provisions.containsKey('substantial_shareholding')) {
      final threshold = provisions['substantial_shareholding']['threshold'] as double?;
      final reducedRate = provisions['substantial_shareholding']['rate'] as double?;
      final shareholding = conditions['shareholding_percentage'] as double?;

      if (threshold != null && reducedRate != null && shareholding != null && shareholding >= threshold) {
        return reducedRate;
      }
    }

    // Example: Government securities exemption
    if (provisions.containsKey('government_securities') && conditions['is_government_security'] == true) {
      return 0.0;
    }

    return baseRate;
  }
}

class InternationalTaxContext {
  final String payerCountry;
  final String recipientCountry;
  final TaxResidencyStatus recipientResidency;
  final String incomeType;
  final double amount;
  final DateTime paymentDate;
  final Map<String, dynamic> transactionDetails;
  final bool hasCertificateOfResidence;
  final Map<String, dynamic>? certificateDetails;

  InternationalTaxContext({
    required this.payerCountry,
    required this.recipientCountry,
    required this.recipientResidency,
    required this.incomeType,
    required this.amount,
    required this.paymentDate,
    this.transactionDetails = const {},
    this.hasCertificateOfResidence = false,
    this.certificateDetails,
  });
}

class InternationalTaxResult {
  final double grossAmount;
  final double withholdingTaxRate;
  final double withholdingTaxAmount;
  final double netAmount;
  final String treatyApplied;
  final List<TreatyBenefit> benefitsReceived;
  final double treatySavings;
  final String taxBasis;
  final Map<String, dynamic> complianceRequirements;

  InternationalTaxResult({
    required this.grossAmount,
    required this.withholdingTaxRate,
    required this.withholdingTaxAmount,
    required this.netAmount,
    required this.treatyApplied,
    required this.benefitsReceived,
    required this.treatySavings,
    required this.taxBasis,
    required this.complianceRequirements,
  });

  Map<String, dynamic> toJson() => {
    'grossAmount': grossAmount,
    'withholdingTaxRate': withholdingTaxRate,
    'withholdingTaxAmount': withholdingTaxAmount,
    'netAmount': netAmount,
    'treatyApplied': treatyApplied,
    'benefitsReceived': benefitsReceived.map((b) => b.name).toList(),
    'treatySavings': treatySavings,
    'taxBasis': taxBasis,
    'complianceRequirements': complianceRequirements,
  };
}

class InternationalTaxService {
  final Map<String, TaxTreaty> _treaties;

  InternationalTaxService({Map<String, TaxTreaty>? treaties})
      : _treaties = treaties ?? _getDefaultTreaties();

  InternationalTaxResult calculateInternationalTax(InternationalTaxContext context) {
    // Find applicable treaty
    final treaty = _findApplicableTreaty(context.payerCountry, context.recipientCountry, context.paymentDate);
    
    double withholdingTaxRate;
    double treatySavings = 0;
    String treatyApplied = 'None';
    List<TreatyBenefit> benefitsReceived = [];
    String taxBasis = 'Domestic law';

    if (treaty != null && context.hasCertificateOfResidence) {
      // Apply treaty rates
      final treatyRate = treaty.getWithholdingTaxRate(
        context.incomeType,
        conditions: context.transactionDetails,
      );
      
      if (treatyRate != null) {
        withholdingTaxRate = treatyRate;
        treatyApplied = treaty.officialName;
        benefitsReceived = [TreatyBenefit.reducedWithholdingTax];
        taxBasis = 'Double taxation agreement';
        
        // Calculate savings compared to domestic rate
        final domesticRate = _getDomesticWithholdingTaxRate(context);
        treatySavings = context.amount * (domesticRate - treatyRate);
      } else {
        withholdingTaxRate = _getDomesticWithholdingTaxRate(context);
      }
    } else {
      // Apply domestic rates
      withholdingTaxRate = _getDomesticWithholdingTaxRate(context);
    }

    final withholdingTaxAmount = context.amount * withholdingTaxRate;
    final netAmount = context.amount - withholdingTaxAmount;

    return InternationalTaxResult(
      grossAmount: context.amount,
      withholdingTaxRate: withholdingTaxRate,
      withholdingTaxAmount: withholdingTaxAmount,
      netAmount: netAmount,
      treatyApplied: treatyApplied,
      benefitsReceived: benefitsReceived,
      treatySavings: treatySavings,
      taxBasis: taxBasis,
      complianceRequirements: _getComplianceRequirements(context, treaty),
    );
  }

  TaxTreaty? _findApplicableTreaty(String payerCountry, String recipientCountry, DateTime date) {
    final treatyKey = '${payerCountry}_$recipientCountry';
    final reverseTreatyKey = '${recipientCountry}_$payerCountry';
    
    var treaty = _treaties[treatyKey] ?? _treaties[reverseTreatyKey];
    
    if (treaty != null && treaty.isEffectiveOn(date)) {
      return treaty;
    }
    
    return null;
  }

  double _getDomesticWithholdingTaxRate(InternationalTaxContext context) {
    // Singapore domestic withholding tax rates
    switch (context.incomeType.toLowerCase()) {
      case 'dividends':
        return 0.0; // One-tier system
      case 'interest':
        return context.recipientResidency == TaxResidencyStatus.nonResident ? 0.15 : 0.0;
      case 'royalties':
        return context.recipientResidency == TaxResidencyStatus.nonResident ? 0.10 : 0.0;
      case 'management_fees':
      case 'technical_fees':
        return context.recipientResidency == TaxResidencyStatus.nonResident ? 0.17 : 0.0;
      default:
        return 0.17; // Standard corporate rate
    }
  }

  Map<String, dynamic> _getComplianceRequirements(InternationalTaxContext context, TaxTreaty? treaty) {
    final requirements = <String, dynamic>{
      'filingRequirements': [],
      'documentationNeeded': [],
      'deadlines': {},
    };

    if (context.recipientResidency == TaxResidencyStatus.nonResident) {
      requirements['filingRequirements'].add('File withholding tax return');
      requirements['documentationNeeded'].add('Recipient details and tax identification');
      requirements['deadlines']['withholdingTaxReturn'] = 'Within 1 month of payment';
    }

    if (treaty != null) {
      requirements['documentationNeeded'].add('Certificate of residence from recipient country');
      requirements['documentationNeeded'].add('Treaty claim form');
      
      if (treaty.availableBenefits.contains(TreatyBenefit.mutualAgreementProcedure)) {
        requirements['additionalBenefits'] = 'Mutual agreement procedure available for disputes';
      }
    }

    return requirements;
  }

  Future<Map<String, dynamic>> analyzeTreatyBenefits({
    required String payerCountry,
    required String recipientCountry,
    required List<Map<String, dynamic>> plannedPayments,
  }) async {
    final treaty = _findApplicableTreaty(payerCountry, recipientCountry, DateTime.now());
    
    if (treaty == null) {
      return {
        'treatyAvailable': false,
        'totalSavings': 0,
        'recommendation': 'No tax treaty available between $payerCountry and $recipientCountry',
      };
    }

    double totalTreatySavings = 0;
    final paymentAnalysis = <Map<String, dynamic>>[];

    for (final payment in plannedPayments) {
      final context = InternationalTaxContext(
        payerCountry: payerCountry,
        recipientCountry: recipientCountry,
        recipientResidency: TaxResidencyStatus.nonResident,
        incomeType: payment['incomeType'],
        amount: payment['amount'],
        paymentDate: DateTime.parse(payment['paymentDate']),
        hasCertificateOfResidence: true,
      );

      final result = calculateInternationalTax(context);
      totalTreatySavings += result.treatySavings;

      paymentAnalysis.add({
        'incomeType': payment['incomeType'],
        'amount': payment['amount'],
        'treatyRate': result.withholdingTaxRate,
        'domesticRate': _getDomesticWithholdingTaxRate(context),
        'savings': result.treatySavings,
      });
    }

    return {
      'treatyAvailable': true,
      'treatyName': treaty.officialName,
      'totalSavings': totalTreatySavings,
      'paymentAnalysis': paymentAnalysis,
      'recommendation': totalTreatySavings > 1000 
          ? 'Significant treaty benefits available. Ensure proper documentation.'
          : 'Limited treaty benefits for planned payments.',
      'requiredDocuments': _getRequiredTreatyDocuments(treaty),
    };
  }

  List<String> _getRequiredTreatyDocuments(TaxTreaty treaty) {
    return [
      'Certificate of residence from ${treaty.countryB} tax authorities',
      'Completed treaty claim form',
      'Evidence of beneficial ownership',
      'Copy of relevant treaty provisions',
      'Recipient\'s tax identification number',
    ];
  }

  Map<String, dynamic> generateTreatyMap() {
    final treatyMap = <String, dynamic>{};
    
    _treaties.forEach((key, treaty) {
      treatyMap[key] = {
        'countries': [treaty.countryA, treaty.countryB],
        'officialName': treaty.officialName,
        'effectiveDate': treaty.effectiveDate.toIso8601String(),
        'withholdingTaxRates': treaty.withholdingTaxRates,
        'availableBenefits': treaty.availableBenefits.map((b) => b.name).toList(),
        'lastAmended': treaty.lastAmended.toIso8601String(),
      };
    });
    
    return {
      'totalTreaties': _treaties.length,
      'treaties': treatyMap,
      'coverage': _calculateTreatyCoverage(),
    };
  }

  Map<String, dynamic> _calculateTreatyCoverage() {
    final countries = <String>{};
    _treaties.values.forEach((treaty) {
      countries.add(treaty.countryA);
      countries.add(treaty.countryB);
    });
    
    return {
      'countriesWithTreaties': countries.length,
      'majorTradingPartners': _getMajorTradingPartners(),
      'recommendedExpansion': _getRecommendedTreatyExpansion(),
    };
  }

  List<String> _getMajorTradingPartners() {
    // Singapore's major trading partners with treaties
    return ['United States', 'United Kingdom', 'China', 'India', 'Japan', 'Australia'];
  }

  List<String> _getRecommendedTreatyExpansion() {
    return ['Vietnam', 'Indonesia', 'Philippines', 'Brazil'];
  }

  static Map<String, TaxTreaty> _getDefaultTreaties() {
    return {
      'SG_US': TaxTreaty(
        treatyId: 'sg_us_dta',
        countryA: 'Singapore',
        countryB: 'United States',
        officialName: 'Singapore-United States Double Taxation Agreement',
        signedDate: DateTime(1999, 1, 1),
        effectiveDate: DateTime(2000, 1, 1),
        withholdingTaxRates: {
          'dividends': 0.05, // 5% for substantial holdings, 15% otherwise
          'interest': 0.10,
          'royalties': 0.10,
        },
        specialProvisions: {
          'dividends': {
            'substantial_shareholding': {'threshold': 10.0, 'rate': 0.05},
            'other': {'rate': 0.15},
          },
          'interest': {
            'government_securities': {'rate': 0.0},
          },
        },
        availableBenefits: [
          TreatyBenefit.reducedWithholdingTax,
          TreatyBenefit.mutualAgreementProcedure,
          TreatyBenefit.exchangeOfInformation,
        ],
        lastAmended: DateTime(2009, 1, 1),
      ),
      
      'SG_UK': TaxTreaty(
        treatyId: 'sg_uk_dta',
        countryA: 'Singapore',
        countryB: 'United Kingdom',
        officialName: 'Singapore-United Kingdom Double Taxation Agreement',
        signedDate: DateTime(1996, 1, 1),
        effectiveDate: DateTime(1997, 1, 1),
        withholdingTaxRates: {
          'dividends': 0.05,
          'interest': 0.10,
          'royalties': 0.10,
        },
        availableBenefits: [
          TreatyBenefit.reducedWithholdingTax,
          TreatyBenefit.mutualAgreementProcedure,
        ],
        lastAmended: DateTime(2010, 1, 1),
      ),
      
      'SG_CN': TaxTreaty(
        treatyId: 'sg_china_dta',
        countryA: 'Singapore',
        countryB: 'China',
        officialName: 'Singapore-China Double Taxation Agreement',
        signedDate: DateTime(2007, 1, 1),
        effectiveDate: DateTime(2009, 1, 1),
        withholdingTaxRates: {
          'dividends': 0.05,
          'interest': 0.07,
          'royalties': 0.10,
        },
        availableBenefits: [
          TreatyBenefit.reducedWithholdingTax,
          TreatyBenefit.mutualAgreementProcedure,
        ],
        lastAmended: DateTime(2009, 1, 1),
      ),
      
      'SG_IN': TaxTreaty(
        treatyId: 'sg_india_ceca',
        countryA: 'Singapore',
        countryB: 'India',
        officialName: 'Singapore-India Comprehensive Economic Cooperation Agreement',
        signedDate: DateTime(1993, 1, 1),
        effectiveDate: DateTime(1994, 1, 1),
        withholdingTaxRates: {
          'dividends': 0.05,
          'interest': 0.10,
          'royalties': 0.10,
          'fees_for_technical_services': 0.10,
        },
        availableBenefits: [
          TreatyBenefit.reducedWithholdingTax,
          TreatyBenefit.mutualAgreementProcedure,
        ],
        lastAmended: DateTime(2005, 1, 1),
      ),
    };
  }
}