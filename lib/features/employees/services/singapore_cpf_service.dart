import 'dart:math' as math;

/// Singapore CPF calculation service with accurate 2024 rates
class SingaporeCpfService {
  static const double _ordinaryWageCeiling = 6000.0; // Monthly OW ceiling
  static const double _additionalWageCeiling = 102000.0; // Annual AW ceiling

  /// Calculate CPF contributions based on employee age and residency status
  static CpfCalculationResult calculateCpfContributions({
    required DateTime dateOfBirth,
    required String residencyStatus,
    required double ordinaryWage,
    required double additionalWage,
    required DateTime calculationDate,
    double? existingCpfForYear, // For AW ceiling calculation
  }) {
    final age = _calculateAge(dateOfBirth, calculationDate);
    final ageCategory = _getAgeCategory(age);

    // Check CPF eligibility
    if (!_isEligibleForCpf(residencyStatus, age)) {
      return CpfCalculationResult(
        ordinaryWage: ordinaryWage,
        additionalWage: additionalWage,
        employeeContribution: 0.0,
        employerContribution: 0.0,
        totalContribution: 0.0,
        employeeRate: 0.0,
        employerRate: 0.0,
        ageCategory: ageCategory,
        residencyStatus: residencyStatus,
        reasoning: _getIneligibilityReason(residencyStatus, age),
        breakdown: CpfBreakdown.empty(),
        isEligible: false,
      );
    }

    final rates = _getCpfRates(ageCategory, residencyStatus);

    // Calculate OW contribution (subject to monthly ceiling)
    final cappedOW = math.min(ordinaryWage, _ordinaryWageCeiling);
    final owEmployeeContribution = cappedOW * rates.employeeRate;
    final owEmployerContribution = cappedOW * rates.employerRate;

    // Calculate AW contribution (subject to annual ceiling)
    final currentYearCpf = existingCpfForYear ?? 0.0;
    final remainingAwCeiling =
        math.max(0.0, _additionalWageCeiling - currentYearCpf);
    final cappedAW = math.min(additionalWage, remainingAwCeiling);
    final awEmployeeContribution = cappedAW * rates.employeeRate;
    final awEmployerContribution = cappedAW * rates.employerRate;

    final totalEmployeeContribution =
        owEmployeeContribution + awEmployeeContribution;
    final totalEmployerContribution =
        owEmployerContribution + awEmployerContribution;
    final totalContribution =
        totalEmployeeContribution + totalEmployerContribution;

    // Calculate account allocations
    final breakdown = _calculateAccountBreakdown(
      totalEmployeeContribution,
      totalEmployerContribution,
      ageCategory,
    );

    return CpfCalculationResult(
      ordinaryWage: ordinaryWage,
      additionalWage: additionalWage,
      employeeContribution: totalEmployeeContribution,
      employerContribution: totalEmployerContribution,
      totalContribution: totalContribution,
      employeeRate: rates.employeeRate,
      employerRate: rates.employerRate,
      ageCategory: ageCategory,
      residencyStatus: residencyStatus,
      reasoning:
          'CPF calculated based on age $age (${ageCategory.displayName})',
      breakdown: breakdown,
      isEligible: true,
      cappedOrdinaryWage: cappedOW,
      cappedAdditionalWage: cappedAW,
      additionalInfo: {
        'age': age,
        'ow_ceiling_applied': ordinaryWage > _ordinaryWageCeiling,
        'aw_ceiling_applied': additionalWage > remainingAwCeiling,
        'remaining_aw_ceiling': remainingAwCeiling,
      },
    );
  }

  /// Get CPF rates based on age category and residency status
  static CpfRates _getCpfRates(
      CpfAgeCategory ageCategory, String residencyStatus) {
    // Special rates for new Singapore PRs (first 2 years)
    if (residencyStatus == 'pr_first_2_years') {
      return _getNewPrRates(ageCategory);
    }

    switch (ageCategory) {
      case CpfAgeCategory.below55:
        return const CpfRates(
            employeeRate: 0.20, employerRate: 0.17); // 20% + 17%
      case CpfAgeCategory.age55to60:
        return const CpfRates(
            employeeRate: 0.13, employerRate: 0.13); // 13% + 13%
      case CpfAgeCategory.age60to65:
        return const CpfRates(
            employeeRate: 0.075, employerRate: 0.09); // 7.5% + 9%
      case CpfAgeCategory.above65:
        return const CpfRates(
            employeeRate: 0.05, employerRate: 0.075); // 5% + 7.5%
    }
  }

  /// Get CPF rates for new Singapore PRs (first 2 years)
  static CpfRates _getNewPrRates(CpfAgeCategory ageCategory) {
    switch (ageCategory) {
      case CpfAgeCategory.below55:
        return const CpfRates(
            employeeRate: 0.05, employerRate: 0.04); // 5% + 4%
      case CpfAgeCategory.age55to60:
        return const CpfRates(
            employeeRate: 0.035, employerRate: 0.035); // 3.5% + 3.5%
      case CpfAgeCategory.age60to65:
        return const CpfRates(
            employeeRate: 0.025, employerRate: 0.025); // 2.5% + 2.5%
      case CpfAgeCategory.above65:
        return const CpfRates(
            employeeRate: 0.025, employerRate: 0.025); // 2.5% + 2.5%
    }
  }

  /// Calculate CPF account allocation breakdown
  static CpfBreakdown _calculateAccountBreakdown(
    double employeeContribution,
    double employerContribution,
    CpfAgeCategory ageCategory,
  ) {
    final totalContribution = employeeContribution + employerContribution;

    // CPF allocation rates as of 2024
    CpfAllocation allocation;
    switch (ageCategory) {
      case CpfAgeCategory.below55:
        allocation = const CpfAllocation(
          ordinaryAccount: 0.6216, // 62.16%
          specialAccount: 0.1622, // 16.22%
          medisaveAccount: 0.2162, // 21.62%
        );
        break;
      case CpfAgeCategory.age55to60:
        allocation = const CpfAllocation(
          ordinaryAccount: 0.6154, // 61.54%
          specialAccount: 0.1538, // 15.38%
          medisaveAccount: 0.2308, // 23.08%
        );
        break;
      case CpfAgeCategory.age60to65:
        allocation = const CpfAllocation(
          ordinaryAccount: 0.3125, // 31.25%
          specialAccount: 0.1875, // 18.75%
          medisaveAccount: 0.5000, // 50.00%
        );
        break;
      case CpfAgeCategory.above65:
        allocation = const CpfAllocation(
          ordinaryAccount: 0.3000, // 30.00%
          specialAccount: 0.0000, // 0.00%
          medisaveAccount: 0.7000, // 70.00%
        );
        break;
    }

    return CpfBreakdown(
      ordinaryAccount: totalContribution * allocation.ordinaryAccount,
      specialAccount: totalContribution * allocation.specialAccount,
      medisaveAccount: totalContribution * allocation.medisaveAccount,
      totalContribution: totalContribution,
    );
  }

  /// Check if employee is eligible for CPF
  static bool _isEligibleForCpf(String residencyStatus, int age) {
    // Age limit: CPF contributions stop at 70
    if (age >= 70) return false;

    // Residency eligibility
    const eligibleStatuses = [
      'citizen',
      'pr',
      'pr_first_2_years',
    ];

    return eligibleStatuses.contains(residencyStatus);
  }

  /// Get reason for CPF ineligibility
  static String _getIneligibilityReason(String residencyStatus, int age) {
    if (age >= 70) {
      return 'Employee is 70 years or older - not subject to CPF';
    }

    if (!['citizen', 'pr', 'pr_first_2_years'].contains(residencyStatus)) {
      return 'Non-resident employees are not subject to CPF';
    }

    return 'Not eligible for CPF contributions';
  }

  /// Calculate age from date of birth
  static int _calculateAge(DateTime dateOfBirth, DateTime asOf) {
    int age = asOf.year - dateOfBirth.year;

    // Adjust for birthday not yet reached this year
    if (asOf.month < dateOfBirth.month ||
        (asOf.month == dateOfBirth.month && asOf.day < dateOfBirth.day)) {
      age--;
    }

    return age;
  }

  /// Get CPF age category
  static CpfAgeCategory _getAgeCategory(int age) {
    if (age < 55) return CpfAgeCategory.below55;
    if (age >= 55 && age < 60) return CpfAgeCategory.age55to60;
    if (age >= 60 && age < 65) return CpfAgeCategory.age60to65;
    return CpfAgeCategory.above65;
  }

  /// Get CPF wage ceiling information
  static Map<String, dynamic> getCpfLimits() {
    return {
      'ordinary_wage_ceiling_monthly': _ordinaryWageCeiling,
      'additional_wage_ceiling_annual': _additionalWageCeiling,
      'max_monthly_contribution_below_55':
          _ordinaryWageCeiling * 0.37, // 20% + 17%
      'cpf_minimum_sum_2024': 198800, // Basic Retirement Sum
      'enhanced_retirement_sum_2024': 298200,
      'full_retirement_sum_2024': 397600,
      'medisave_minimum_sum_2024': 71500,
    };
  }

  /// Calculate annual CPF projections
  static CpfAnnualProjection calculateAnnualProjection({
    required double monthlyOrdinaryWage,
    required double estimatedAnnualBonus,
    required DateTime dateOfBirth,
    required String residencyStatus,
    int projectionYear = 2024,
  }) {
    final projectionDate = DateTime(projectionYear, 12, 31);

    // Calculate monthly contributions
    final monthlyResult = calculateCpfContributions(
      dateOfBirth: dateOfBirth,
      residencyStatus: residencyStatus,
      ordinaryWage: monthlyOrdinaryWage,
      additionalWage: 0.0,
      calculationDate: projectionDate,
    );

    // Calculate bonus contribution
    final bonusResult = calculateCpfContributions(
      dateOfBirth: dateOfBirth,
      residencyStatus: residencyStatus,
      ordinaryWage: 0.0,
      additionalWage: estimatedAnnualBonus,
      calculationDate: projectionDate,
      existingCpfForYear: monthlyResult.totalContribution * 12,
    );

    final annualEmployeeContribution =
        (monthlyResult.employeeContribution * 12) +
            bonusResult.employeeContribution;
    final annualEmployerContribution =
        (monthlyResult.employerContribution * 12) +
            bonusResult.employerContribution;
    final annualTotalContribution =
        annualEmployeeContribution + annualEmployerContribution;

    return CpfAnnualProjection(
      projectionYear: projectionYear,
      monthlyContribution: monthlyResult.totalContribution,
      bonusContribution: bonusResult.totalContribution,
      annualEmployeeContribution: annualEmployeeContribution,
      annualEmployerContribution: annualEmployerContribution,
      annualTotalContribution: annualTotalContribution,
      accountBreakdown: CpfBreakdown(
        ordinaryAccount: annualTotalContribution * 0.6216,
        specialAccount: annualTotalContribution * 0.1622,
        medisaveAccount: annualTotalContribution * 0.2162,
        totalContribution: annualTotalContribution,
      ),
    );
  }
}

/// CPF calculation result
class CpfCalculationResult {
  final double ordinaryWage;
  final double additionalWage;
  final double employeeContribution;
  final double employerContribution;
  final double totalContribution;
  final double employeeRate;
  final double employerRate;
  final CpfAgeCategory ageCategory;
  final String residencyStatus;
  final String reasoning;
  final CpfBreakdown breakdown;
  final bool isEligible;
  final double? cappedOrdinaryWage;
  final double? cappedAdditionalWage;
  final Map<String, dynamic>? additionalInfo;

  const CpfCalculationResult({
    required this.ordinaryWage,
    required this.additionalWage,
    required this.employeeContribution,
    required this.employerContribution,
    required this.totalContribution,
    required this.employeeRate,
    required this.employerRate,
    required this.ageCategory,
    required this.residencyStatus,
    required this.reasoning,
    required this.breakdown,
    required this.isEligible,
    this.cappedOrdinaryWage,
    this.cappedAdditionalWage,
    this.additionalInfo,
  });

  Map<String, dynamic> toJson() => {
        'ordinary_wage': ordinaryWage,
        'additional_wage': additionalWage,
        'employee_contribution': employeeContribution,
        'employer_contribution': employerContribution,
        'total_contribution': totalContribution,
        'employee_rate': employeeRate,
        'employer_rate': employerRate,
        'age_category': ageCategory.name,
        'residency_status': residencyStatus,
        'reasoning': reasoning,
        'breakdown': breakdown.toJson(),
        'is_eligible': isEligible,
        'capped_ordinary_wage': cappedOrdinaryWage,
        'capped_additional_wage': cappedAdditionalWage,
        'additional_info': additionalInfo,
      };
}

/// CPF contribution rates
class CpfRates {
  final double employeeRate;
  final double employerRate;

  const CpfRates({
    required this.employeeRate,
    required this.employerRate,
  });

  double get totalRate => employeeRate + employerRate;
}

/// CPF account breakdown
class CpfBreakdown {
  final double ordinaryAccount;
  final double specialAccount;
  final double medisaveAccount;
  final double totalContribution;

  const CpfBreakdown({
    required this.ordinaryAccount,
    required this.specialAccount,
    required this.medisaveAccount,
    required this.totalContribution,
  });

  const CpfBreakdown.empty()
      : ordinaryAccount = 0.0,
        specialAccount = 0.0,
        medisaveAccount = 0.0,
        totalContribution = 0.0;

  Map<String, dynamic> toJson() => {
        'ordinary_account': ordinaryAccount,
        'special_account': specialAccount,
        'medisave_account': medisaveAccount,
        'total_contribution': totalContribution,
      };
}

/// CPF allocation percentages
class CpfAllocation {
  final double ordinaryAccount;
  final double specialAccount;
  final double medisaveAccount;

  const CpfAllocation({
    required this.ordinaryAccount,
    required this.specialAccount,
    required this.medisaveAccount,
  });
}

/// CPF age categories for contribution rates
enum CpfAgeCategory {
  below55,
  age55to60,
  age60to65,
  above65,
}

extension CpfAgeCategoryExtension on CpfAgeCategory {
  String get displayName {
    switch (this) {
      case CpfAgeCategory.below55:
        return 'Below 55';
      case CpfAgeCategory.age55to60:
        return '55 to 60';
      case CpfAgeCategory.age60to65:
        return '60 to 65';
      case CpfAgeCategory.above65:
        return 'Above 65';
    }
  }

  String get rateDescription {
    switch (this) {
      case CpfAgeCategory.below55:
        return 'Employee: 20%, Employer: 17%';
      case CpfAgeCategory.age55to60:
        return 'Employee: 13%, Employer: 13%';
      case CpfAgeCategory.age60to65:
        return 'Employee: 7.5%, Employer: 9%';
      case CpfAgeCategory.above65:
        return 'Employee: 5%, Employer: 7.5%';
    }
  }
}

/// Annual CPF projection
class CpfAnnualProjection {
  final int projectionYear;
  final double monthlyContribution;
  final double bonusContribution;
  final double annualEmployeeContribution;
  final double annualEmployerContribution;
  final double annualTotalContribution;
  final CpfBreakdown accountBreakdown;

  const CpfAnnualProjection({
    required this.projectionYear,
    required this.monthlyContribution,
    required this.bonusContribution,
    required this.annualEmployeeContribution,
    required this.annualEmployerContribution,
    required this.annualTotalContribution,
    required this.accountBreakdown,
  });
}
