import '../../models/rates/tax_rate_model.dart';
import '../../models/company/company_tax_profile.dart';
import '../../models/fx/fx_rate_model.dart';

enum WithholdingTaxType {
  dividends,
  interest,
  royalties,
  managementFees,
  technicalFees,
  consultingFees,
  rentalIncome,
  capitalGains,
  other,
}

enum RecipientType {
  resident,
  nonResident,
  company,
  individual,
  government,
  treaty,
}

class WithholdingTaxContext {
  final WithholdingTaxType incomeType;
  final RecipientType recipientType;
  final String? recipientCountry;
  final String? treatyReference;
  final bool isTreatyApplicable;
  final Map<String, dynamic> additionalDetails;

  WithholdingTaxContext({
    required this.incomeType,
    required this.recipientType,
    this.recipientCountry,
    this.treatyReference,
    this.isTreatyApplicable = false,
    this.additionalDetails = const {},
  });
}

class WithholdingTaxResult {
  final double grossAmount;
  final double withholdingTaxRate;
  final double withholdingTaxAmount;
  final double netAmount;
  final String taxBasis;
  final String legislation;
  final bool treatyApplied;
  final String? treatyReference;
  final Map<String, dynamic> breakdown;

  WithholdingTaxResult({
    required this.grossAmount,
    required this.withholdingTaxRate,
    required this.withholdingTaxAmount,
    required this.netAmount,
    required this.taxBasis,
    required this.legislation,
    required this.treatyApplied,
    this.treatyReference,
    required this.breakdown,
  });

  Map<String, dynamic> toJson() => {
        'grossAmount': grossAmount,
        'withholdingTaxRate': withholdingTaxRate,
        'withholdingTaxAmount': withholdingTaxAmount,
        'netAmount': netAmount,
        'taxBasis': taxBasis,
        'legislation': legislation,
        'treatyApplied': treatyApplied,
        'treatyReference': treatyReference,
        'breakdown': breakdown,
      };
}

class WithholdingTaxCalculator {
  final Map<String, TaxTreatyRate> _treatyRates;

  WithholdingTaxCalculator({Map<String, TaxTreatyRate>? treatyRates})
      : _treatyRates = treatyRates ?? _getDefaultTreatyRates();

  WithholdingTaxResult calculateWithholdingTax({
    required double amount,
    required WithholdingTaxContext context,
    required DateTime paymentDate,
    Currency? currency,
  }) {
    // Determine applicable rate
    final rateInfo = _determineWithholdingTaxRate(context, paymentDate);

    final withholdingTaxAmount = amount * rateInfo['rate'];
    final netAmount = amount - withholdingTaxAmount;

    return WithholdingTaxResult(
      grossAmount: amount,
      withholdingTaxRate: rateInfo['rate'],
      withholdingTaxAmount: withholdingTaxAmount,
      netAmount: netAmount,
      taxBasis: rateInfo['basis'],
      legislation: rateInfo['legislation'],
      treatyApplied: rateInfo['treatyApplied'],
      treatyReference: rateInfo['treatyReference'],
      breakdown: _generateBreakdown(context, rateInfo, amount),
    );
  }

  Map<String, dynamic> _determineWithholdingTaxRate(
    WithholdingTaxContext context,
    DateTime paymentDate,
  ) {
    // Check for treaty rates first
    if (context.isTreatyApplicable && context.recipientCountry != null) {
      final treatyRate = _getTreatyRate(
        context.recipientCountry!,
        context.incomeType,
        paymentDate,
      );

      if (treatyRate != null) {
        return {
          'rate': treatyRate,
          'basis': 'Double Taxation Agreement',
          'legislation': 'Tax Treaty',
          'treatyApplied': true,
          'treatyReference': context.treatyReference,
        };
      }
    }

    // Fallback to domestic rates
    final domesticRate = _getDomesticWithholdingTaxRate(context);

    return {
      'rate': domesticRate['rate'],
      'basis': domesticRate['basis'],
      'legislation': 'Income Tax Act Section 45',
      'treatyApplied': false,
      'treatyReference': null,
    };
  }

  double? _getTreatyRate(
      String countryCode, WithholdingTaxType incomeType, DateTime date) {
    final treaty = _treatyRates[countryCode];
    if (treaty == null || !treaty.isEffectiveOn(date)) return null;

    final incomeTypeKey = _mapIncomeTypeToTreatyKey(incomeType);
    return treaty.getWithholdingTaxRate(incomeTypeKey);
  }

  String _mapIncomeTypeToTreatyKey(WithholdingTaxType incomeType) {
    switch (incomeType) {
      case WithholdingTaxType.dividends:
        return 'dividends';
      case WithholdingTaxType.interest:
        return 'interest';
      case WithholdingTaxType.royalties:
        return 'royalties';
      case WithholdingTaxType.managementFees:
      case WithholdingTaxType.technicalFees:
        return 'fees_for_technical_services';
      default:
        return 'other';
    }
  }

  Map<String, dynamic> _getDomesticWithholdingTaxRate(
      WithholdingTaxContext context) {
    switch (context.incomeType) {
      case WithholdingTaxType.dividends:
        // Singapore one-tier system - no withholding tax on dividends
        return {
          'rate': 0.0,
          'basis': 'One-tier corporate tax system',
        };

      case WithholdingTaxType.interest:
        if (context.recipientType == RecipientType.nonResident) {
          return {
            'rate': 0.15,
            'basis': 'Standard withholding tax rate for non-residents',
          };
        } else {
          return {
            'rate': 0.0,
            'basis': 'No withholding tax for residents',
          };
        }

      case WithholdingTaxType.royalties:
        if (context.recipientType == RecipientType.nonResident) {
          return {
            'rate': 0.10,
            'basis':
                'Standard withholding tax rate for royalties to non-residents',
          };
        } else {
          return {
            'rate': 0.0,
            'basis': 'No withholding tax for residents',
          };
        }

      case WithholdingTaxType.managementFees:
      case WithholdingTaxType.technicalFees:
      case WithholdingTaxType.consultingFees:
        if (context.recipientType == RecipientType.nonResident) {
          return {
            'rate': 0.17,
            'basis':
                'Standard corporate tax rate applied to non-resident services',
          };
        } else {
          return {
            'rate': 0.0,
            'basis': 'No withholding tax for residents',
          };
        }

      case WithholdingTaxType.rentalIncome:
        if (context.recipientType == RecipientType.nonResident) {
          return {
            'rate': 0.15,
            'basis': 'Withholding tax on rental income for non-residents',
          };
        } else {
          return {
            'rate': 0.0,
            'basis': 'No withholding tax for residents',
          };
        }

      default:
        return {
          'rate': 0.17,
          'basis': 'Standard corporate tax rate',
        };
    }
  }

  Map<String, dynamic> _generateBreakdown(
    WithholdingTaxContext context,
    Map<String, dynamic> rateInfo,
    double amount,
  ) {
    return {
      'incomeType': context.incomeType.name,
      'recipientType': context.recipientType.name,
      'recipientCountry': context.recipientCountry,
      'applicableRate': rateInfo['rate'],
      'taxBasis': rateInfo['basis'],
      'treatyBenefits':
          rateInfo['treatyApplied'] ? 'Applied' : 'Not Applicable',
      'calculation': {
        'grossAmount': amount,
        'taxRate': rateInfo['rate'],
        'taxAmount': amount * rateInfo['rate'],
        'netAmount': amount - (amount * rateInfo['rate']),
      },
    };
  }

  // Certificate of Residence verification
  bool verifyCertificateOfResidence(Map<String, dynamic> certificate) {
    final requiredFields = [
      'recipientName',
      'recipientAddress',
      'countryOfResidence',
      'taxIdentificationNumber',
      'issueDate',
      'validity'
    ];

    for (final field in requiredFields) {
      if (!certificate.containsKey(field) || certificate[field] == null) {
        return false;
      }
    }

    // Check validity period
    final issueDate = DateTime.parse(certificate['issueDate']);
    final validityPeriod = certificate['validity'] as int? ?? 12; // months
    final expiryDate = issueDate.add(Duration(days: validityPeriod * 30));

    return DateTime.now().isBefore(expiryDate);
  }

  // Bulk withholding tax calculation for multiple payments
  List<WithholdingTaxResult> calculateBulkWithholdingTax({
    required List<Map<String, dynamic>> payments,
    required DateTime paymentDate,
  }) {
    return payments.map((payment) {
      final context = WithholdingTaxContext(
        incomeType: WithholdingTaxType.values.byName(payment['incomeType']),
        recipientType: RecipientType.values.byName(payment['recipientType']),
        recipientCountry: payment['recipientCountry'],
        isTreatyApplicable: payment['isTreatyApplicable'] ?? false,
      );

      return calculateWithholdingTax(
        amount: payment['amount'],
        context: context,
        paymentDate: paymentDate,
      );
    }).toList();
  }

  // Generate withholding tax certificate
  Map<String, dynamic> generateWithholdingTaxCertificate({
    required WithholdingTaxResult result,
    required String payerName,
    required String payerTaxNumber,
    required String recipientName,
    required String recipientAddress,
    required DateTime paymentDate,
  }) {
    return {
      'certificateNumber': 'WHT${DateTime.now().millisecondsSinceEpoch}',
      'issueDate': DateTime.now().toIso8601String(),
      'payer': {
        'name': payerName,
        'taxNumber': payerTaxNumber,
      },
      'recipient': {
        'name': recipientName,
        'address': recipientAddress,
      },
      'payment': {
        'date': paymentDate.toIso8601String(),
        'grossAmount': result.grossAmount,
        'withholdingTaxAmount': result.withholdingTaxAmount,
        'netAmount': result.netAmount,
        'taxRate': result.withholdingTaxRate,
      },
      'legal': {
        'legislation': result.legislation,
        'treatyApplied': result.treatyApplied,
        'treatyReference': result.treatyReference,
      },
    };
  }

  static Map<String, TaxTreatyRate> _getDefaultTreatyRates() {
    return {
      'US': TaxTreatyRate(
        treatyId: 'sg_us_treaty',
        countryCode: 'US',
        countryName: 'United States',
        currency: Currency.usd,
        withholdingTaxRates: {
          'dividends': 0.05,
          'interest': 0.10,
          'royalties': 0.10,
        },
        effectiveFrom: DateTime(2000, 1, 1),
      ),
      'GB': TaxTreatyRate(
        treatyId: 'sg_uk_treaty',
        countryCode: 'GB',
        countryName: 'United Kingdom',
        currency: Currency.gbp,
        withholdingTaxRates: {
          'dividends': 0.05,
          'interest': 0.10,
          'royalties': 0.10,
        },
        effectiveFrom: DateTime(1997, 1, 1),
      ),
      'CN': TaxTreatyRate(
        treatyId: 'sg_china_treaty',
        countryCode: 'CN',
        countryName: 'China',
        currency: Currency.cny,
        withholdingTaxRates: {
          'dividends': 0.05,
          'interest': 0.07,
          'royalties': 0.10,
        },
        effectiveFrom: DateTime(2009, 1, 1),
      ),
    };
  }
}
