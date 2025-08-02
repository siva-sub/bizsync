import 'package:json_annotation/json_annotation.dart';

part 'tax_rate_model.g.dart';

enum TaxType {
  gst,
  corporateTax,
  withholdingTax,
  stampDuty,
  importDuty,
  exportDuty,
  propertyTax,
  vehicleRoadTax,
}

enum CompanyType {
  privateLimited,
  publicLimited,
  charity,
  cooperativeSociety,
  limitedLiabilityPartnership,
  partnership,
  soleProprietorship,
  branch,
  representativeOffice,
  startup,
  reit,
  businessTrust,
}

@JsonSerializable()
class TaxRate {
  final String id;
  final TaxType taxType;
  final double rate;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final String description;
  final List<CompanyType>? applicableCompanyTypes;
  final Map<String, dynamic>? conditions;
  final bool isActive;
  final String? legislation;
  final String? remarks;

  const TaxRate({
    required this.id,
    required this.taxType,
    required this.rate,
    required this.effectiveFrom,
    this.effectiveTo,
    required this.description,
    this.applicableCompanyTypes,
    this.conditions,
    this.isActive = true,
    this.legislation,
    this.remarks,
  });

  factory TaxRate.fromJson(Map<String, dynamic> json) {
    // TODO: Implement proper JSON deserialization when build_runner generates the code
    throw UnimplementedError('JSON serialization not yet implemented');
  }
  
  Map<String, dynamic> toJson() {
    // TODO: Implement proper JSON serialization when build_runner generates the code
    throw UnimplementedError('JSON serialization not yet implemented');
  }

  TaxRate copyWith({
    String? id,
    TaxType? taxType,
    double? rate,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
    String? description,
    List<CompanyType>? applicableCompanyTypes,
    Map<String, dynamic>? conditions,
    bool? isActive,
    String? legislation,
    String? remarks,
  }) {
    return TaxRate(
      id: id ?? this.id,
      taxType: taxType ?? this.taxType,
      rate: rate ?? this.rate,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveTo: effectiveTo ?? this.effectiveTo,
      description: description ?? this.description,
      applicableCompanyTypes: applicableCompanyTypes ?? this.applicableCompanyTypes,
      conditions: conditions ?? this.conditions,
      isActive: isActive ?? this.isActive,
      legislation: legislation ?? this.legislation,
      remarks: remarks ?? this.remarks,
    );
  }

  bool isEffectiveOn(DateTime date) {
    final isAfterStart = date.isAfter(effectiveFrom) || date.isAtSameMomentAs(effectiveFrom);
    final isBeforeEnd = effectiveTo == null || date.isBefore(effectiveTo!);
    return isAfterStart && isBeforeEnd && isActive;
  }

  bool appliesTo(CompanyType companyType) {
    return applicableCompanyTypes == null || 
           applicableCompanyTypes!.contains(companyType);
  }
}

@JsonSerializable()
class HistoricalTaxRates {
  final TaxType taxType;
  final List<TaxRate> rates;
  final DateTime lastUpdated;

  const HistoricalTaxRates({
    required this.taxType,
    required this.rates,
    required this.lastUpdated,
  });

  factory HistoricalTaxRates.fromJson(Map<String, dynamic> json) {
    // TODO: Implement proper JSON deserialization when build_runner generates the code
    throw UnimplementedError('JSON serialization not yet implemented');
  }
  
  Map<String, dynamic> toJson() {
    // TODO: Implement proper JSON serialization when build_runner generates the code
    throw UnimplementedError('JSON serialization not yet implemented');
  }

  TaxRate? getRateForDate(DateTime date, {CompanyType? companyType}) {
    return rates
        .where((rate) => rate.isEffectiveOn(date))
        .where((rate) => companyType == null || rate.appliesTo(companyType))
        .firstOrNull;
  }

  List<TaxRate> getRatesInPeriod(DateTime startDate, DateTime endDate) {
    return rates.where((rate) {
      return (rate.effectiveFrom.isBefore(endDate) || 
              rate.effectiveFrom.isAtSameMomentAs(endDate)) &&
             (rate.effectiveTo == null || 
              rate.effectiveTo!.isAfter(startDate) ||
              rate.effectiveTo!.isAtSameMomentAs(startDate));
    }).toList();
  }
}

// Singapore-specific tax rate constants and historical data
class SingaporeTaxRates {
  static final List<TaxRate> gstRates = [
    TaxRate(
      id: 'gst_1994',
      taxType: TaxType.gst,
      rate: 0.03,
      effectiveFrom: DateTime(1994, 4, 1),
      effectiveTo: DateTime(2003, 12, 31),
      description: 'Goods and Services Tax 3%',
      legislation: 'Goods and Services Tax Act',
    ),
    TaxRate(
      id: 'gst_2004',
      taxType: TaxType.gst,
      rate: 0.05,
      effectiveFrom: DateTime(2004, 1, 1),
      effectiveTo: DateTime(2007, 6, 30),
      description: 'Goods and Services Tax 5%',
      legislation: 'Goods and Services Tax Act',
    ),
    TaxRate(
      id: 'gst_2007',
      taxType: TaxType.gst,
      rate: 0.07,
      effectiveFrom: DateTime(2007, 7, 1),
      effectiveTo: DateTime(2022, 12, 31),
      description: 'Goods and Services Tax 7%',
      legislation: 'Goods and Services Tax Act',
    ),
    TaxRate(
      id: 'gst_2023',
      taxType: TaxType.gst,
      rate: 0.08,
      effectiveFrom: DateTime(2023, 1, 1),
      effectiveTo: DateTime(2024, 12, 31),
      isActive: false,
      description: 'Goods and Services Tax 8%',
      legislation: 'Goods and Services Tax Act',
    ),
    TaxRate(
      id: 'gst_2024',
      taxType: TaxType.gst,
      rate: 0.09,
      effectiveFrom: DateTime(2024, 1, 1),
      description: 'Goods and Services Tax 9%',
      legislation: 'Goods and Services Tax Act',
    ),
  ];

  static final List<TaxRate> corporateTaxRates = [
    // Standard corporate tax rate
    TaxRate(
      id: 'corp_tax_2024',
      taxType: TaxType.corporateTax,
      rate: 0.17,
      effectiveFrom: DateTime(2024, 1, 1),
      description: 'Corporate Income Tax 17%',
      applicableCompanyTypes: [
        CompanyType.privateLimited,
        CompanyType.publicLimited,
        CompanyType.branch,
      ],
      legislation: 'Income Tax Act',
    ),
    
    // Startup exemption scheme
    TaxRate(
      id: 'startup_exemption_2024',
      taxType: TaxType.corporateTax,
      rate: 0.0,
      effectiveFrom: DateTime(2024, 1, 1),
      description: 'Startup Tax Exemption - First S\$100,000',
      applicableCompanyTypes: [CompanyType.startup],
      conditions: {
        'maxTaxableIncome': 100000,
        'exemptionType': 'first_100k',
        'shareholderRequirement': 'local_ownership_20percent',
      },
      legislation: 'Income Tax Act Section 43A',
    ),
    
    TaxRate(
      id: 'startup_partial_2024',
      taxType: TaxType.corporateTax,
      rate: 0.085,
      effectiveFrom: DateTime(2024, 1, 1),
      description: 'Startup Partial Exemption - Next S\$200,000 at 8.5%',
      applicableCompanyTypes: [CompanyType.startup],
      conditions: {
        'minTaxableIncome': 100001,
        'maxTaxableIncome': 300000,
        'exemptionType': 'next_200k',
        'shareholderRequirement': 'local_ownership_20percent',
      },
      legislation: 'Income Tax Act Section 43A',
    ),

    // Charity exemption
    TaxRate(
      id: 'charity_exemption_2024',
      taxType: TaxType.corporateTax,
      rate: 0.0,
      effectiveFrom: DateTime(2024, 1, 1),
      description: 'Charitable Organization Tax Exemption',
      applicableCompanyTypes: [CompanyType.charity],
      conditions: {
        'charitableStatus': 'required',
        'ipcStatus': 'optional_enhanced_deduction',
      },
      legislation: 'Income Tax Act Section 13(1)(zm)',
    ),
  ];

  static final List<TaxRate> withholdingTaxRates = [
    TaxRate(
      id: 'wht_dividends_2024',
      taxType: TaxType.withholdingTax,
      rate: 0.0,
      effectiveFrom: DateTime(2024, 1, 1),
      description: 'Withholding Tax on Dividends - 0% (one-tier system)',
      conditions: {
        'paymentType': 'dividends',
        'oneTimerSystem': true,
      },
      legislation: 'Income Tax Act',
    ),
    
    TaxRate(
      id: 'wht_interest_2024',
      taxType: TaxType.withholdingTax,
      rate: 0.15,
      effectiveFrom: DateTime(2024, 1, 1),
      description: 'Withholding Tax on Interest - 15%',
      conditions: {
        'paymentType': 'interest',
        'recipientType': 'non_resident',
      },
      legislation: 'Income Tax Act Section 45',
    ),
    
    TaxRate(
      id: 'wht_royalties_2024',
      taxType: TaxType.withholdingTax,
      rate: 0.10,
      effectiveFrom: DateTime(2024, 1, 1),
      description: 'Withholding Tax on Royalties - 10%',
      conditions: {
        'paymentType': 'royalties',
        'recipientType': 'non_resident',
      },
      legislation: 'Income Tax Act Section 45',
    ),
  ];

  static final List<TaxRate> stampDutyRates = [
    TaxRate(
      id: 'stamp_duty_property_2024',
      taxType: TaxType.stampDuty,
      rate: 0.04,
      effectiveFrom: DateTime(2024, 1, 1),
      description: 'Stamp Duty on Property - 4% (above S\$1M)',
      conditions: {
        'propertyValue': 'above_1000000',
        'buyerType': 'singapore_citizen_first_property',
      },
      legislation: 'Stamp Duties Act',
    ),
    
    TaxRate(
      id: 'stamp_duty_shares_2024',
      taxType: TaxType.stampDuty,
      rate: 0.002,
      effectiveFrom: DateTime(2024, 1, 1),
      description: 'Stamp Duty on Shares - 0.2%',
      conditions: {
        'instrumentType': 'shares_transfer',
      },
      legislation: 'Stamp Duties Act',
    ),
  ];

  static HistoricalTaxRates getGstHistory() {
    return HistoricalTaxRates(
      taxType: TaxType.gst,
      rates: gstRates,
      lastUpdated: DateTime.now(),
    );
  }

  static HistoricalTaxRates getCorporateTaxHistory() {
    return HistoricalTaxRates(
      taxType: TaxType.corporateTax,
      rates: corporateTaxRates,
      lastUpdated: DateTime.now(),
    );
  }

  static HistoricalTaxRates getWithholdingTaxHistory() {
    return HistoricalTaxRates(
      taxType: TaxType.withholdingTax,
      rates: withholdingTaxRates,
      lastUpdated: DateTime.now(),
    );
  }

  static HistoricalTaxRates getStampDutyHistory() {
    return HistoricalTaxRates(
      taxType: TaxType.stampDuty,
      rates: stampDutyRates,
      lastUpdated: DateTime.now(),
    );
  }
}