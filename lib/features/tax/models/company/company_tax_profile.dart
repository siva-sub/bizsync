import 'package:json_annotation/json_annotation.dart';
import '../rates/tax_rate_model.dart';

part 'company_tax_profile.g.dart';

enum CompanyStatus {
  active,
  dormant,
  striking,
  wound,
  dissolved,
}

enum ResidencyStatus {
  resident,
  nonResident,
  deemedResident,
}

enum IndustryClassification {
  manufacturing,
  trading,
  services,
  financial,
  real_estate,
  construction,
  technology,
  healthcare,
  education,
  transport,
  hospitality,
  retail,
  agriculture,
  mining,
  utilities,
  telecommunications,
  media,
  professional_services,
  consulting,
  research_development,
}

@JsonSerializable()
class CompanyTaxProfile {
  final String companyId;
  final String companyName;
  final String registrationNumber;
  final CompanyType companyType;
  final CompanyStatus status;
  final ResidencyStatus residencyStatus;
  final IndustryClassification industryClassification;
  final DateTime incorporationDate;
  final DateTime financialYearEnd;
  final bool isGstRegistered;
  final String? gstNumber;
  final DateTime? gstRegistrationDate;
  final double? gstTurnoverThreshold;
  final List<TaxExemption> exemptions;
  final List<TaxIncentive> incentives;
  final Map<String, dynamic> additionalDetails;
  final DateTime lastUpdated;

  const CompanyTaxProfile({
    required this.companyId,
    required this.companyName,
    required this.registrationNumber,
    required this.companyType,
    required this.status,
    required this.residencyStatus,
    required this.industryClassification,
    required this.incorporationDate,
    required this.financialYearEnd,
    required this.isGstRegistered,
    this.gstNumber,
    this.gstRegistrationDate,
    this.gstTurnoverThreshold,
    this.exemptions = const [],
    this.incentives = const [],
    this.additionalDetails = const {},
    required this.lastUpdated,
  });

  factory CompanyTaxProfile.fromJson(Map<String, dynamic> json) {
    // TODO: Implement proper JSON deserialization when build_runner generates the code
    throw UnimplementedError('JSON serialization not yet implemented');
  }

  Map<String, dynamic> toJson() {
    // TODO: Implement proper JSON serialization when build_runner generates the code
    throw UnimplementedError('JSON serialization not yet implemented');
  }

  bool isEligibleForStartupExemption() {
    if (companyType != CompanyType.startup) return false;

    final yearsSinceIncorporation =
        DateTime.now().difference(incorporationDate).inDays / 365;
    return yearsSinceIncorporation <= 3; // First 3 consecutive years
  }

  bool isQualifiedForPartialExemption() {
    return companyType == CompanyType.privateLimited ||
        companyType == CompanyType.publicLimited ||
        companyType == CompanyType.startup;
  }

  bool requiresGstRegistration(double annualTurnover) {
    const gstThreshold = 1000000; // S$1M threshold for GST registration
    return annualTurnover >= gstThreshold;
  }

  List<TaxRate> getApplicableTaxRates(TaxType taxType, DateTime date) {
    // This would typically query the tax rate service
    // For now, return basic logic
    switch (taxType) {
      case TaxType.gst:
        return isGstRegistered ? [_getCurrentGstRate(date)] : [];
      case TaxType.corporateTax:
        return _getCorporateTaxRates(date);
      default:
        return [];
    }
  }

  TaxRate _getCurrentGstRate(DateTime date) {
    // Simplified - in real implementation, would query historical rates
    final currentYear = DateTime.now().year;
    if (date.year >= currentYear) {
      return TaxRate(
        id: 'gst_current',
        taxType: TaxType.gst,
        rate: 0.09,
        effectiveFrom: DateTime(currentYear, 1, 1),
        description: 'GST 9%',
      );
    } else if (date.year >= 2023) {
      return TaxRate(
        id: 'gst_2023',
        taxType: TaxType.gst,
        rate: 0.08,
        effectiveFrom: DateTime(2023, 1, 1),
        description: 'GST 8%',
      );
    }
    return TaxRate(
      id: 'gst_2007',
      taxType: TaxType.gst,
      rate: 0.07,
      effectiveFrom: DateTime(2024, 1, 1),
      description: 'GST 7%',
    );
  }

  List<TaxRate> _getCorporateTaxRates(DateTime date) {
    List<TaxRate> rates = [];

    if (companyType == CompanyType.charity) {
      rates.add(TaxRate(
        id: 'charity_exemption',
        taxType: TaxType.corporateTax,
        rate: 0.0,
        effectiveFrom: DateTime(DateTime.now().year, 1, 1),
        description: 'Charity Exemption',
      ));
    } else if (isEligibleForStartupExemption()) {
      rates.addAll([
        TaxRate(
          id: 'startup_first_100k',
          taxType: TaxType.corporateTax,
          rate: 0.0,
          effectiveFrom: DateTime(DateTime.now().year, 1, 1),
          description: 'Startup Exemption - First S\$100k',
        ),
        TaxRate(
          id: 'startup_next_200k',
          taxType: TaxType.corporateTax,
          rate: 0.085,
          effectiveFrom: DateTime(DateTime.now().year, 1, 1),
          description: 'Startup Partial Exemption - Next S\$200k',
        ),
      ]);
    }

    // Standard corporate tax rate
    rates.add(TaxRate(
      id: 'standard_corporate',
      taxType: TaxType.corporateTax,
      rate: 0.17,
      effectiveFrom: DateTime(2024, 1, 1),
      description: 'Standard Corporate Tax 17%',
    ));

    return rates;
  }
}

// Helper constant for const constructors
// Removed const_date definition as it was causing compilation issues

@JsonSerializable()
class TaxExemption {
  final String id;
  final String name;
  final String description;
  final TaxType taxType;
  final double exemptionRate;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final Map<String, dynamic> conditions;
  final String? legislation;

  const TaxExemption({
    required this.id,
    required this.name,
    required this.description,
    required this.taxType,
    required this.exemptionRate,
    required this.effectiveFrom,
    this.effectiveTo,
    this.conditions = const {},
    this.legislation,
  });

  factory TaxExemption.fromJson(Map<String, dynamic> json) =>
      _$TaxExemptionFromJson(json);
  Map<String, dynamic> toJson() => _$TaxExemptionToJson(this);

  bool isValidOn(DateTime date) {
    return date.isAfter(effectiveFrom) ||
        date.isAtSameMomentAs(effectiveFrom) &&
            (effectiveTo == null || date.isBefore(effectiveTo!));
  }
}

@JsonSerializable()
class TaxIncentive {
  final String id;
  final String name;
  final String description;
  final TaxType taxType;
  final double incentiveRate;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final Map<String, dynamic> eligibilityCriteria;
  final String? scheme;
  final String? authority;

  const TaxIncentive({
    required this.id,
    required this.name,
    required this.description,
    required this.taxType,
    required this.incentiveRate,
    required this.effectiveFrom,
    this.effectiveTo,
    this.eligibilityCriteria = const {},
    this.scheme,
    this.authority,
  });

  factory TaxIncentive.fromJson(Map<String, dynamic> json) =>
      _$TaxIncentiveFromJson(json);
  Map<String, dynamic> toJson() => _$TaxIncentiveToJson(this);

  bool isValidOn(DateTime date) {
    return date.isAfter(effectiveFrom) ||
        date.isAtSameMomentAs(effectiveFrom) &&
            (effectiveTo == null || date.isBefore(effectiveTo!));
  }
}

// Singapore-specific company tax rules and configurations
class SingaporeCompanyTaxRules {
  static const double gstRegistrationThreshold = 1000000; // S$1M
  static const double smallCompanyThreshold = 5000000; // S$5M
  static const int startupExemptionYears = 3;

  static final Map<CompanyType, Map<String, dynamic>> companyTypeRules = {
    CompanyType.privateLimited: {
      'taxable': true,
      'gstEligible': true,
      'corporateTaxRate': 0.17,
      'partialExemptionEligible': true,
      'minimumPaidUpCapital': 1,
    },
    CompanyType.publicLimited: {
      'taxable': true,
      'gstEligible': true,
      'corporateTaxRate': 0.17,
      'partialExemptionEligible': true,
      'minimumPaidUpCapital': 50000,
    },
    CompanyType.charity: {
      'taxable': false,
      'gstEligible': true,
      'corporateTaxRate': 0.0,
      'partialExemptionEligible': false,
      'ipcStatusRequired': false,
    },
    CompanyType.startup: {
      'taxable': true,
      'gstEligible': true,
      'corporateTaxRate': 0.17,
      'startupExemptionEligible': true,
      'partialExemptionEligible': true,
      'localShareholderRequirement': 0.20, // 20% local ownership
    },
    CompanyType.branch: {
      'taxable': true,
      'gstEligible': true,
      'corporateTaxRate': 0.17,
      'branchProfitsRemittanceTax': false, // Singapore doesn't impose this
    },
    CompanyType.representativeOffice: {
      'taxable': false,
      'gstEligible': false,
      'revenueGeneratingActivities': false,
    },
  };

  static final Map<IndustryClassification, Map<String, dynamic>>
      industrySpecificRules = {
    IndustryClassification.financial: {
      'additionalRegulations': ['MAS licensing', 'Financial sector incentives'],
      'specialTaxTreatment': true,
      'witholdingTaxExemptions': ['Qualifying debt securities'],
    },
    IndustryClassification.real_estate: {
      'propertyTax': true,
      'stampDutyApplicable': true,
      'additionalBuyerStampDuty': true,
      'sellerStampDuty': true,
    },
    IndustryClassification.technology: {
      'developmentIncentives': ['PIC scheme', 'R&D tax incentives'],
      'intellectualPropertyTax': 'Reduced rates available',
      'startupFriendly': true,
    },
  };

  static bool isEligibleForPartialExemption(CompanyTaxProfile profile) {
    final rules = companyTypeRules[profile.companyType];
    return rules?['partialExemptionEligible'] == true;
  }

  static double getStandardCorporateTaxRate(CompanyType companyType) {
    final rules = companyTypeRules[companyType];
    return rules?['corporateTaxRate'] ?? 0.17;
  }

  static bool requiresGstRegistration(double annualTurnover) {
    return annualTurnover >= gstRegistrationThreshold;
  }

  static List<String> getComplianceRequirements(CompanyTaxProfile profile) {
    List<String> requirements = [];

    if (profile.isGstRegistered) {
      requirements.addAll([
        'GST F5 return filing',
        'GST record keeping (5 years)',
        'Tax invoices for GST-registered supplies',
      ]);
    }

    if (companyTypeRules[profile.companyType]?['taxable'] == true) {
      requirements.addAll([
        'Corporate income tax return (Form C-S or Form C)',
        'Estimated chargeable income filing',
        'Audit requirements (if revenue > S\$5M)',
      ]);
    }

    switch (profile.industryClassification) {
      case IndustryClassification.financial:
        requirements.add('MAS regulatory compliance');
        break;
      case IndustryClassification.real_estate:
        requirements.addAll([
          'Property tax assessment',
          'Stamp duty compliance',
        ]);
        break;
      default:
        break;
    }

    return requirements;
  }
}
