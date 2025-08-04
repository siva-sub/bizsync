import 'package:json_annotation/json_annotation.dart';
import '../rates/tax_rate_model.dart';
import '../company/company_tax_profile.dart';

part 'tax_relief_model.g.dart';

enum ReliefType {
  startupExemption,
  partialExemption,
  doubleDeductionRelief,
  acceleratedDepreciation,
  researchDevelopmentRelief,
  trainingRelief,
  charitableDonationRelief,
  lossCarryForward,
  lossCarryBack,
  foreignTaxCredit,
  unilateralTaxCredit,
  treatyRelief,
  investmentAllowance,
  reinvestmentAllowance,
  machineryCredit,
  automationCredit,
  productivityInnovationCredit,
  energyEfficiencyRelief,
  internationalExpansionRelief,
}

enum ReliefStatus {
  eligible,
  applied,
  approved,
  rejected,
  expired,
  utilized,
}

@JsonSerializable()
class TaxRelief {
  final String id;
  final String name;
  final ReliefType reliefType;
  final String description;
  final double reliefAmount;
  final double? reliefRate;
  final double? maximumRelief;
  final TaxType applicableTaxType;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final Map<String, dynamic> eligibilityCriteria;
  final Map<String, dynamic> calculationParameters;
  final List<CompanyType> applicableCompanyTypes;
  final List<IndustryClassification>? applicableIndustries;
  final String? legislation;
  final String? administrationAuthority;
  final ReliefStatus status;
  final DateTime? applicationDate;
  final DateTime? approvalDate;
  final String? remarks;

  const TaxRelief({
    required this.id,
    required this.name,
    required this.reliefType,
    required this.description,
    required this.reliefAmount,
    this.reliefRate,
    this.maximumRelief,
    required this.applicableTaxType,
    required this.effectiveFrom,
    this.effectiveTo,
    this.eligibilityCriteria = const {},
    this.calculationParameters = const {},
    this.applicableCompanyTypes = const [],
    this.applicableIndustries,
    this.legislation,
    this.administrationAuthority,
    this.status = ReliefStatus.eligible,
    this.applicationDate,
    this.approvalDate,
    this.remarks,
  });

  factory TaxRelief.fromJson(Map<String, dynamic> json) =>
      _$TaxReliefFromJson(json);
  Map<String, dynamic> toJson() => _$TaxReliefToJson(this);

  bool isApplicableTo(CompanyTaxProfile profile, DateTime date) {
    // Check date validity
    if (!_isValidOnDate(date)) return false;
    
    // Check company type eligibility
    if (applicableCompanyTypes.isNotEmpty && 
        !applicableCompanyTypes.contains(profile.companyType)) {
      return false;
    }
    
    // Check industry eligibility
    if (applicableIndustries != null && 
        applicableIndustries!.isNotEmpty &&
        !applicableIndustries!.contains(profile.industryClassification)) {
      return false;
    }
    
    // Check specific eligibility criteria
    return _meetsEligibilityCriteria(profile);
  }

  bool _isValidOnDate(DateTime date) {
    final isAfterStart = date.isAfter(effectiveFrom) || 
                        date.isAtSameMomentAs(effectiveFrom);
    final isBeforeEnd = effectiveTo == null || date.isBefore(effectiveTo!);
    return isAfterStart && isBeforeEnd;
  }

  bool _meetsEligibilityCriteria(CompanyTaxProfile profile) {
    switch (reliefType) {
      case ReliefType.startupExemption:
        return profile.isEligibleForStartupExemption();
      
      case ReliefType.partialExemption:
        return profile.isQualifiedForPartialExemption();
      
      case ReliefType.charitableDonationRelief:
        return profile.companyType != CompanyType.charity; // Companies can claim donation relief
      
      default:
        return true; // Default to eligible, specific checks can be added
    }
  }

  double calculateReliefAmount(double taxableAmount, Map<String, dynamic> context) {
    switch (reliefType) {
      case ReliefType.startupExemption:
        return _calculateStartupExemption(taxableAmount);
      
      case ReliefType.partialExemption:
        return _calculatePartialExemption(taxableAmount);
      
      case ReliefType.doubleDeductionRelief:
        return _calculateDoubleDeduction(taxableAmount, context);
      
      case ReliefType.foreignTaxCredit:
        return _calculateForeignTaxCredit(taxableAmount, context);
      
      default:
        return reliefRate != null ? taxableAmount * reliefRate! : reliefAmount;
    }
  }

  double _calculateStartupExemption(double taxableIncome) {
    const exemptAmount = 100000.0; // First S$100,000 exempt
    return taxableIncome <= exemptAmount ? taxableIncome : exemptAmount;
  }

  double _calculatePartialExemption(double taxableIncome) {
    const exemptAmount = 10000; // First S$10,000 exempt at 0%
    const partialAmount = 190000; // Next S$190,000 at 8.5%
    
    if (taxableIncome <= exemptAmount) {
      return taxableIncome; // Full exemption
    } else if (taxableIncome <= exemptAmount + partialAmount) {
      // Partial exemption calculation
      final partialTaxableAmount = taxableIncome - exemptAmount;
      return exemptAmount + (partialTaxableAmount * 0.085);
    } else {
      // Standard rate applies beyond S$200,000
      return exemptAmount + (partialAmount * 0.085);
    }
  }

  double _calculateDoubleDeduction(double expenseAmount, Map<String, dynamic> context) {
    final deductionRate = calculationParameters['deductionMultiplier'] ?? 2.0;
    final maxDeduction = maximumRelief ?? double.infinity;
    
    final calculatedRelief = expenseAmount * (deductionRate - 1.0); // Additional deduction
    return calculatedRelief > maxDeduction ? maxDeduction : calculatedRelief;
  }

  double _calculateForeignTaxCredit(double taxableAmount, Map<String, dynamic> context) {
    final foreignTaxPaid = context['foreignTaxPaid'] ?? 0.0;
    final singaporeTaxRate = context['singaporeTaxRate'] ?? 0.17;
    final foreignSourceIncome = context['foreignSourceIncome'] ?? taxableAmount;
    
    // Credit limited to Singapore tax on foreign income
    final singaporeTaxOnForeignIncome = foreignSourceIncome * singaporeTaxRate;
    
    return foreignTaxPaid < singaporeTaxOnForeignIncome 
        ? foreignTaxPaid 
        : singaporeTaxOnForeignIncome;
  }
}

@JsonSerializable()
class TaxReliefApplication {
  final String id;
  final String companyId;
  final String reliefId;
  final double claimedAmount;
  final double approvedAmount;
  final ReliefStatus status;
  final DateTime applicationDate;
  final DateTime? approvalDate;
  final String assessmentYear;
  final Map<String, dynamic> supportingDocuments;
  final List<String> conditions;
  final String? rejectionReason;
  final DateTime? expiryDate;

  const TaxReliefApplication({
    required this.id,
    required this.companyId,
    required this.reliefId,
    required this.claimedAmount,
    this.approvedAmount = 0.0,
    required this.status,
    required this.applicationDate,
    this.approvalDate,
    required this.assessmentYear,
    this.supportingDocuments = const {},
    this.conditions = const [],
    this.rejectionReason,
    this.expiryDate,
  });

  factory TaxReliefApplication.fromJson(Map<String, dynamic> json) =>
      _$TaxReliefApplicationFromJson(json);
  Map<String, dynamic> toJson() => _$TaxReliefApplicationToJson(this);
}

// Singapore-specific tax reliefs and exemptions
class SingaporeTaxReliefs {
  static final List<TaxRelief> corporateTaxReliefs = [
    // Startup Tax Exemption
    TaxRelief(
      id: 'startup_exemption_2024',
      name: 'Startup Tax Exemption Scheme',
      reliefType: ReliefType.startupExemption,
      description: 'Tax exemption for qualifying new companies',
      reliefAmount: 100000, // S$100,000 exemption
      reliefRate: 0.0,
      applicableTaxType: TaxType.corporateTax,
      effectiveFrom: DateTime(2024, 1, 1),
      applicableCompanyTypes: [
        CompanyType.privateLimited,
        CompanyType.publicLimited,
        CompanyType.startup,
      ],
      eligibilityCriteria: {
        'newCompany': true,
        'firstThreeYears': true,
        'localShareholding': 0.20, // At least 20% local shareholding
        'excludedActivities': [
          'Investment holding',
          'Property development',
          'Financial services (with exceptions)',
        ],
      },
      legislation: 'Income Tax Act Section 43A',
      administrationAuthority: 'IRAS',
    ),

    // Partial Tax Exemption
    TaxRelief(
      id: 'partial_exemption_2024',
      name: 'Partial Tax Exemption',
      reliefType: ReliefType.partialExemption,
      description: 'Partial exemption for all qualifying companies',
      reliefAmount: 200000, // Applied to first S$200,000
      applicableTaxType: TaxType.corporateTax,
      effectiveFrom: DateTime(2024, 1, 1),
      applicableCompanyTypes: [
        CompanyType.privateLimited,
        CompanyType.publicLimited,
        CompanyType.startup,
      ],
      calculationParameters: {
        'firstTier': {'amount': 10000, 'rate': 0.0}, // First S$10,000 at 0%
        'secondTier': {'amount': 190000, 'rate': 0.085}, // Next S$190,000 at 8.5%
      },
      legislation: 'Income Tax Act Section 43B',
      administrationAuthority: 'IRAS',
    ),

    // R&D Double Deduction
    TaxRelief(
      id: 'rd_double_deduction_2024',
      name: 'Research & Development Double Deduction',
      reliefType: ReliefType.researchDevelopmentRelief,
      description: 'Double deduction for qualifying R&D expenses',
      reliefAmount: 0,
      reliefRate: 1.0, // 100% additional deduction (total 200%)
      applicableTaxType: TaxType.corporateTax,
      effectiveFrom: DateTime(2024, 1, 1),
      applicableCompanyTypes: [
        CompanyType.privateLimited,
        CompanyType.publicLimited,
        CompanyType.startup,
      ],
      eligibilityCriteria: {
        'qualifyingRnDExpenses': true,
        'conductedInSingapore': true,
        'approvedByEDB': false, // Automatic for most cases
      },
      calculationParameters: {
        'deductionMultiplier': 2.0,
        'maxAnnualClaim': 2000000, // S$2M per year
      },
      legislation: 'Income Tax Act Section 14DA',
      administrationAuthority: 'IRAS',
    ),

    // PIC (Productivity and Innovation Credit) - if still applicable
    TaxRelief(
      id: 'pic_scheme_2024',
      name: 'Productivity and Innovation Credit',
      reliefType: ReliefType.productivityInnovationCredit,
      description: 'Enhanced deductions/allowances for productivity improvements',
      reliefAmount: 0,
      reliefRate: 3.0, // 300% deduction or 60% cash payout
      maximumRelief: 600000, // S$600,000 per year
      applicableTaxType: TaxType.corporateTax,
      effectiveFrom: DateTime(2024, 1, 1),
      effectiveTo: DateTime(DateTime.now().year, 12, 31), // Check current validity
      applicableCompanyTypes: [
        CompanyType.privateLimited,
        CompanyType.publicLimited,
        CompanyType.startup,
      ],
      eligibilityCriteria: {
        'qualifyingActivities': [
          'Research and Development',
          'Intellectual Property registration',
          'Automation equipment',
          'Training',
          'Design projects',
        ],
      },
      legislation: 'Income Tax Act Section 37K',
      administrationAuthority: 'IRAS',
    ),

    // Foreign-sourced Income Exemption
    TaxRelief(
      id: 'foreign_income_exemption_2024',
      name: 'Foreign-sourced Income Exemption',
      reliefType: ReliefType.foreignTaxCredit,
      description: 'Exemption for qualifying foreign-sourced income',
      reliefAmount: 0,
      reliefRate: 1.0, // Full exemption
      applicableTaxType: TaxType.corporateTax,
      effectiveFrom: DateTime(2024, 1, 1),
      applicableCompanyTypes: [
        CompanyType.privateLimited,
        CompanyType.publicLimited,
        CompanyType.branch,
      ],
      eligibilityCriteria: {
        'foreignSourceIncome': true,
        'subjectToForeignTax': true,
        'remittedToSingapore': true,
      },
      legislation: 'Income Tax Act Section 13(1)(za)',
      administrationAuthority: 'IRAS',
    ),

    // Loss Carry-forward
    TaxRelief(
      id: 'loss_carry_forward_2024',
      name: 'Loss Carry-forward',
      reliefType: ReliefType.lossCarryForward,
      description: 'Carry forward losses to offset future profits',
      reliefAmount: 0,
      reliefRate: 1.0,
      applicableTaxType: TaxType.corporateTax,
      effectiveFrom: DateTime(2024, 1, 1),
      applicableCompanyTypes: [
        CompanyType.privateLimited,
        CompanyType.publicLimited,
        CompanyType.startup,
      ],
      eligibilityCriteria: {
        'shareholderTest': 'Required for companies',
        'sameTradeTest': 'Required for companies',
        'carryForwardPeriod': 'Indefinite (subject to tests)',
      },
      legislation: 'Income Tax Act Section 37',
      administrationAuthority: 'IRAS',
    ),
  ];

  static final List<TaxRelief> gstReliefs = [
    TaxRelief(
      id: 'gst_bad_debt_relief_2024',
      name: 'GST Bad Debt Relief',
      reliefType: ReliefType.charitableDonationRelief, // Reusing enum
      description: 'Relief for GST on bad debts written off',
      reliefAmount: 0,
      reliefRate: 1.0, // Full GST amount
      applicableTaxType: TaxType.gst,
      effectiveFrom: DateTime(2024, 1, 1),
      applicableCompanyTypes: [], // All GST-registered businesses
      eligibilityCriteria: {
        'gstRegistered': true,
        'debtWrittenOff': true,
        'sixMonthsPastDue': true,
        'reasonableStepsForRecovery': true,
      },
      legislation: 'GST Act Section 19',
      administrationAuthority: 'IRAS',
    ),
  ];

  static List<TaxRelief> getApplicableReliefs(
    CompanyTaxProfile profile,
    TaxType taxType,
    DateTime date,
  ) {
    List<TaxRelief> allReliefs;
    
    switch (taxType) {
      case TaxType.corporateTax:
        allReliefs = corporateTaxReliefs;
        break;
      case TaxType.gst:
        allReliefs = gstReliefs;
        break;
      default:
        return [];
    }
    
    return allReliefs
        .where((relief) => relief.isApplicableTo(profile, date))
        .toList();
  }

  static double calculateTotalRelief(
    List<TaxRelief> reliefs,
    double taxableAmount,
    Map<String, dynamic> context,
  ) {
    double totalRelief = 0;
    
    for (final relief in reliefs) {
      final reliefAmount = relief.calculateReliefAmount(taxableAmount, context);
      totalRelief += reliefAmount;
      
      // Update context for subsequent calculations
      context['appliedReliefs'] = (context['appliedReliefs'] ?? [])..add({
        'reliefId': relief.id,
        'amount': reliefAmount,
      });
    }
    
    return totalRelief;
  }
}