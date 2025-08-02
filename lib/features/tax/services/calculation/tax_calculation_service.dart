import 'dart:math' as math;
import '../../models/rates/tax_rate_model.dart';
import '../../models/company/company_tax_profile.dart';
import '../../models/relief/tax_relief_model.dart';
import '../../models/fx/fx_rate_model.dart';

class TaxCalculationResult {
  final double grossAmount;
  final double taxableAmount;
  final double taxRate;
  final double taxAmount;
  final double netAmount;
  final List<TaxCalculationBreakdown> breakdown;
  final List<TaxRelief> appliedReliefs;
  final Map<String, dynamic> metadata;

  const TaxCalculationResult({
    required this.grossAmount,
    required this.taxableAmount,
    required this.taxRate,
    required this.taxAmount,
    required this.netAmount,
    required this.breakdown,
    required this.appliedReliefs,
    required this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'grossAmount': grossAmount,
    'taxableAmount': taxableAmount,
    'taxRate': taxRate,
    'taxAmount': taxAmount,
    'netAmount': netAmount,
    'breakdown': breakdown.map((b) => b.toJson()).toList(),
    'appliedReliefs': appliedReliefs.map((r) => r.toJson()).toList(),
    'metadata': metadata,
  };
}

class TaxCalculationBreakdown {
  final String description;
  final double amount;
  final double rate;
  final double taxAmount;
  final TaxType taxType;
  final String? legislation;

  const TaxCalculationBreakdown({
    required this.description,
    required this.amount,
    required this.rate,
    required this.taxAmount,
    required this.taxType,
    this.legislation,
  });

  Map<String, dynamic> toJson() => {
    'description': description,
    'amount': amount,
    'rate': rate,
    'taxAmount': taxAmount,
    'taxType': taxType.name,
    'legislation': legislation,
  };
}

class TaxCalculationContext {
  final CompanyTaxProfile companyProfile;
  final DateTime calculationDate;
  final Currency currency;
  final Map<String, dynamic> transactionDetails;
  final List<TaxRelief> availableReliefs;
  final FxRate? fxRate;

  const TaxCalculationContext({
    required this.companyProfile,
    required this.calculationDate,
    required this.currency,
    required this.transactionDetails,
    required this.availableReliefs,
    this.fxRate,
  });
}

abstract class TaxCalculationService {
  Future<TaxCalculationResult> calculateTax({
    required double amount,
    required TaxType taxType,
    required TaxCalculationContext context,
  });

  Future<TaxRate?> getTaxRate({
    required TaxType taxType,
    required CompanyType companyType,
    required DateTime date,
  });

  Future<List<TaxRelief>> getApplicableReliefs({
    required CompanyTaxProfile profile,
    required TaxType taxType,
    required DateTime date,
  });
}

class TaxCalculationServiceImpl implements TaxCalculationService {
  final TaxRateRepository _taxRateRepository;
  final TaxReliefRepository _taxReliefRepository;
  final FxRateService _fxRateService;

  TaxCalculationServiceImpl({
    required TaxRateRepository taxRateRepository,
    required TaxReliefRepository taxReliefRepository,
    required FxRateService fxRateService,
  }) : _taxRateRepository = taxRateRepository,
       _taxReliefRepository = taxReliefRepository,
       _fxRateService = fxRateService;

  @override
  Future<TaxCalculationResult> calculateTax({
    required double amount,
    required TaxType taxType,
    required TaxCalculationContext context,
  }) async {
    try {
      // Convert amount to SGD if necessary
      double sgdAmount = amount;
      if (context.currency != Currency.sgd && context.fxRate != null) {
        sgdAmount = context.fxRate!.convertAmount(amount);
      }

      switch (taxType) {
        case TaxType.gst:
          return await _calculateGst(sgdAmount, context);
        case TaxType.corporateTax:
          return await _calculateCorporateTax(sgdAmount, context);
        case TaxType.withholdingTax:
          return await _calculateWithholdingTax(sgdAmount, context);
        case TaxType.stampDuty:
          return await _calculateStampDuty(sgdAmount, context);
        default:
          throw UnsupportedError('Tax type $taxType not supported');
      }
    } catch (e) {
      throw TaxCalculationException('Failed to calculate tax: $e');
    }
  }

  Future<TaxCalculationResult> _calculateGst(
    double amount,
    TaxCalculationContext context,
  ) async {
    if (!context.companyProfile.isGstRegistered) {
      return TaxCalculationResult(
        grossAmount: amount,
        taxableAmount: 0,
        taxRate: 0,
        taxAmount: 0,
        netAmount: amount,
        breakdown: [],
        appliedReliefs: [],
        metadata: {'reason': 'Company not GST registered'},
      );
    }

    final taxRate = await _getTaxRateForDate(
      TaxType.gst,
      context.companyProfile.companyType,
      context.calculationDate,
    );

    if (taxRate == null) {
      throw TaxCalculationException('No GST rate found for date ${context.calculationDate}');
    }

    final taxAmount = amount * taxRate.rate;
    final netAmount = amount + taxAmount;

    return TaxCalculationResult(
      grossAmount: amount,
      taxableAmount: amount,
      taxRate: taxRate.rate,
      taxAmount: taxAmount,
      netAmount: netAmount,
      breakdown: [
        TaxCalculationBreakdown(
          description: 'GST ${(taxRate.rate * 100).toStringAsFixed(1)}%',
          amount: amount,
          rate: taxRate.rate,
          taxAmount: taxAmount,
          taxType: TaxType.gst,
          legislation: 'Goods and Services Tax Act',
        ),
      ],
      appliedReliefs: [],
      metadata: {
        'taxRateId': taxRate.id,
        'effectiveDate': taxRate.effectiveFrom.toIso8601String(),
      },
    );
  }

  Future<TaxCalculationResult> _calculateCorporateTax(
    double income,
    TaxCalculationContext context,
  ) async {
    final reliefs = await getApplicableReliefs(
      profile: context.companyProfile,
      taxType: TaxType.corporateTax,
      date: context.calculationDate,
    );

    double taxableIncome = income;
    double totalTax = 0;
    List<TaxCalculationBreakdown> breakdown = [];
    List<TaxRelief> appliedReliefs = [];

    // Apply reliefs and exemptions
    for (final relief in reliefs) {
      if (relief.reliefType == ReliefType.startupExemption && 
          context.companyProfile.isEligibleForStartupExemption()) {
        
        final exemptAmount = math.min(taxableIncome, 100000); // First S$100k
        taxableIncome -= exemptAmount;
        appliedReliefs.add(relief);
        
        breakdown.add(TaxCalculationBreakdown(
          description: 'Startup Tax Exemption - First S\$100,000',
          amount: exemptAmount.toDouble(),
          rate: 0,
          taxAmount: 0,
          taxType: TaxType.corporateTax,
          legislation: 'Income Tax Act Section 43A',
        ));

        // Next S$200k at 8.5% for startups
        if (taxableIncome > 0) {
          final partialAmount = math.min(taxableIncome, 200000);
          final partialTax = partialAmount * 0.085;
          totalTax += partialTax;
          taxableIncome -= partialAmount;
          
          breakdown.add(TaxCalculationBreakdown(
            description: 'Startup Partial Exemption - Next S\$200,000 at 8.5%',
            amount: partialAmount.toDouble(),
            rate: 0.085,
            taxAmount: partialTax,
            taxType: TaxType.corporateTax,
            legislation: 'Income Tax Act Section 43A',
          ));
        }
      } else if (relief.reliefType == ReliefType.partialExemption &&
                 context.companyProfile.isQualifiedForPartialExemption()) {
        
        // First S$10k at 0%
        final exemptAmount = math.min(taxableIncome, 10000);
        taxableIncome -= exemptAmount;
        appliedReliefs.add(relief);
        
        breakdown.add(TaxCalculationBreakdown(
          description: 'Partial Tax Exemption - First S\$10,000',
          amount: exemptAmount.toDouble(),
          rate: 0,
          taxAmount: 0,
          taxType: TaxType.corporateTax,
          legislation: 'Income Tax Act Section 43B',
        ));

        // Next S$190k at 8.5%
        if (taxableIncome > 0) {
          final partialAmount = math.min(taxableIncome, 190000);
          final partialTax = partialAmount * 0.085;
          totalTax += partialTax;
          taxableIncome -= partialAmount;
          
          breakdown.add(TaxCalculationBreakdown(
            description: 'Partial Tax Exemption - Next S\$190,000 at 8.5%',
            amount: partialAmount.toDouble(),
            rate: 0.085,
            taxAmount: partialTax,
            taxType: TaxType.corporateTax,
            legislation: 'Income Tax Act Section 43B',
          ));
        }
      }
    }

    // Standard corporate tax rate for remaining amount
    if (taxableIncome > 0) {
      final standardRate = 0.17; // 17% standard rate
      final standardTax = taxableIncome * standardRate;
      totalTax += standardTax;
      
      breakdown.add(TaxCalculationBreakdown(
        description: 'Standard Corporate Tax Rate 17%',
        amount: taxableIncome,
        rate: standardRate,
        taxAmount: standardTax,
        taxType: TaxType.corporateTax,
        legislation: 'Income Tax Act',
      ));
    }

    final effectiveTaxRate = income > 0 ? totalTax / income : 0;
    final netIncome = income - totalTax;

    return TaxCalculationResult(
      grossAmount: income,
      taxableAmount: income,
      taxRate: effectiveTaxRate.toDouble(),
      taxAmount: totalTax,
      netAmount: netIncome,
      breakdown: breakdown,
      appliedReliefs: appliedReliefs,
      metadata: {
        'companyType': context.companyProfile.companyType.name,
        'assessmentYear': context.calculationDate.year.toString(),
      },
    );
  }

  Future<TaxCalculationResult> _calculateWithholdingTax(
    double amount,
    TaxCalculationContext context,
  ) async {
    final incomeType = context.transactionDetails['incomeType'] as String?;
    final recipientCountry = context.transactionDetails['recipientCountry'] as String?;
    
    if (incomeType == null) {
      throw TaxCalculationException('Income type is required for withholding tax calculation');
    }

    double withholdingRate = 0;
    String legislation = 'Income Tax Act Section 45';
    String description = 'Withholding Tax';

    // Check for tax treaty rates first
    if (recipientCountry != null) {
      final treatyRate = SingaporeFxConfig.getWithholdingTaxRate(
        recipientCountry,
        incomeType,
        context.calculationDate,
      );
      
      if (treatyRate != null) {
        withholdingRate = treatyRate;
        legislation = 'Double Taxation Agreement';
        description = 'Treaty Withholding Tax';
      }
    }

    // Fallback to domestic rates
    if (withholdingRate == 0) {
      switch (incomeType.toLowerCase()) {
        case 'dividends':
          withholdingRate = 0.0; // Singapore one-tier system
          description = 'Withholding Tax on Dividends (One-tier system)';
          break;
        case 'interest':
          withholdingRate = 0.15;
          description = 'Withholding Tax on Interest 15%';
          break;
        case 'royalties':
          withholdingRate = 0.10;
          description = 'Withholding Tax on Royalties 10%';
          break;
        default:
          withholdingRate = 0.17; // Standard corporate rate
          description = 'Withholding Tax (Standard rate)';
      }
    }

    final taxAmount = amount * withholdingRate;
    final netAmount = amount - taxAmount;

    return TaxCalculationResult(
      grossAmount: amount,
      taxableAmount: amount,
      taxRate: withholdingRate,
      taxAmount: taxAmount,
      netAmount: netAmount,
      breakdown: [
        TaxCalculationBreakdown(
          description: '$description ${(withholdingRate * 100).toStringAsFixed(1)}%',
          amount: amount,
          rate: withholdingRate,
          taxAmount: taxAmount,
          taxType: TaxType.withholdingTax,
          legislation: legislation,
        ),
      ],
      appliedReliefs: [],
      metadata: {
        'incomeType': incomeType,
        'recipientCountry': recipientCountry,
        'treatyApplied': recipientCountry != null,
      },
    );
  }

  Future<TaxCalculationResult> _calculateStampDuty(
    double amount,
    TaxCalculationContext context,
  ) async {
    final instrumentType = context.transactionDetails['instrumentType'] as String?;
    
    if (instrumentType == null) {
      throw TaxCalculationException('Instrument type is required for stamp duty calculation');
    }

    double stampDutyRate = 0;
    String description = 'Stamp Duty';

    switch (instrumentType.toLowerCase()) {
      case 'property':
        stampDutyRate = _calculatePropertyStampDuty(amount, context);
        description = 'Property Stamp Duty';
        break;
      case 'shares':
        stampDutyRate = 0.002; // 0.2%
        description = 'Stamp Duty on Shares 0.2%';
        break;
      case 'mortgage':
        stampDutyRate = 0.004; // 0.4%
        description = 'Mortgage Stamp Duty 0.4%';
        break;
      default:
        stampDutyRate = 0.001; // 0.1% default
        description = 'General Stamp Duty 0.1%';
    }

    final taxAmount = amount * stampDutyRate;

    return TaxCalculationResult(
      grossAmount: amount,
      taxableAmount: amount,
      taxRate: stampDutyRate,
      taxAmount: taxAmount,
      netAmount: amount, // Stamp duty doesn't reduce the transaction amount
      breakdown: [
        TaxCalculationBreakdown(
          description: description,
          amount: amount,
          rate: stampDutyRate,
          taxAmount: taxAmount,
          taxType: TaxType.stampDuty,
          legislation: 'Stamp Duties Act',
        ),
      ],
      appliedReliefs: [],
      metadata: {
        'instrumentType': instrumentType,
      },
    );
  }

  double _calculatePropertyStampDuty(double propertyValue, TaxCalculationContext context) {
    final buyerType = context.transactionDetails['buyerType'] as String? ?? 'citizen';
    final isFirstProperty = context.transactionDetails['isFirstProperty'] as bool? ?? true;

    // Simplified progressive rates for Singapore citizens (first property)
    if (buyerType == 'citizen' && isFirstProperty) {
      if (propertyValue <= 180000) return 0.01; // 1%
      if (propertyValue <= 360000) return 0.02; // 2%
      if (propertyValue <= 1000000) return 0.03; // 3%
      return 0.04; // 4% for above S$1M
    } else {
      // Higher rates for non-citizens or additional properties
      return 0.20; // 20% ABSD for foreigners
    }
  }

  Future<TaxRate?> _getTaxRateForDate(
    TaxType taxType,
    CompanyType companyType,
    DateTime date,
  ) async {
    // In a real implementation, this would query the database
    // For now, return from static data
    switch (taxType) {
      case TaxType.gst:
        return SingaporeTaxRates.getGstHistory().getRateForDate(date, companyType: companyType);
      case TaxType.corporateTax:
        return SingaporeTaxRates.getCorporateTaxHistory().getRateForDate(date, companyType: companyType);
      default:
        return null;
    }
  }

  @override
  Future<TaxRate?> getTaxRate({
    required TaxType taxType,
    required CompanyType companyType,
    required DateTime date,
  }) async {
    return await _getTaxRateForDate(taxType, companyType, date);
  }

  @override
  Future<List<TaxRelief>> getApplicableReliefs({
    required CompanyTaxProfile profile,
    required TaxType taxType,
    required DateTime date,
  }) async {
    return SingaporeTaxReliefs.getApplicableReliefs(profile, taxType, date);
  }
}

// Abstract repository interfaces (to be implemented with actual data sources)
abstract class TaxRateRepository {
  Future<TaxRate?> getTaxRate(TaxType taxType, DateTime date, {CompanyType? companyType});
  Future<List<TaxRate>> getHistoricalRates(TaxType taxType, DateTime startDate, DateTime endDate);
}

abstract class TaxReliefRepository {
  Future<List<TaxRelief>> getApplicableReliefs(CompanyTaxProfile profile, TaxType taxType, DateTime date);
  Future<TaxRelief?> getReliefById(String reliefId);
}

abstract class FxRateService {
  Future<FxRate?> getFxRate(Currency from, Currency to, DateTime date);
  Future<double?> convertAmount(double amount, Currency from, Currency to, DateTime date);
}

class TaxCalculationException implements Exception {
  final String message;
  TaxCalculationException(this.message);
  
  @override
  String toString() => 'TaxCalculationException: $message';
}