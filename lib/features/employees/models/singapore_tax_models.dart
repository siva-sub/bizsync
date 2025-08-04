import 'dart:convert';
import '../../../core/crdt/hybrid_logical_clock.dart';
import '../../../core/crdt/vector_clock.dart';
import '../../../core/crdt/crdt_types.dart';
import '../../../core/crdt/lww_register.dart';
import '../../../core/crdt/pn_counter.dart';
import '../../../core/crdt/or_set.dart';
import '../../../core/database/crdt_models.dart';

/// Singapore CPF age categories (2024 rates)
enum CpfAgeCategory {
  below55, // Below 55 years
  age55to60, // 55 to 60 years
  age60to65, // 60 to 65 years
  age65to70, // 65 to 70 years
  above70 // Above 70 years
}

/// Singapore residency status for CPF purposes
enum SgResidencyStatus {
  citizen, // Singapore citizen
  pr, // Permanent resident (3rd year onwards)
  prFirstYear, // PR in first year
  prSecondYear, // PR in second year
  nonResident // Non-resident
}

/// Work pass types in Singapore
enum WorkPassType {
  // No levy work passes
  employmentPass, // Employment Pass (EP)
  personalizedEmploymentPass, // Personalised Employment Pass (PEP)
  techPass, // Tech.Pass
  onePass, // ONE Pass
  entrePass, // EntrePass

  // Levy applicable work passes
  sPass, // S Pass
  workPermit, // Work Permit (WP)
  trainingWorkPermit, // Training Work Permit

  // Special cases
  studentPassPartTime, // Student Pass (part-time work)
  dependentPassLoc, // Dependent Pass with LOC
  ltvpLoc // Long Term Visit Pass with LOC
}

/// Industry sectors for FWL calculation
enum IndustrySector { construction, manufacturing, services, marine, process }

/// Skill levels for work permit holders
enum SkillLevel {
  basic, // Basic skilled
  higher // Higher skilled
}

/// Self-Help Group (SHG) types
enum SelfHelpGroupType {
  cdac, // Chinese Development Assistance Council
  ecf, // Eurasian Community Fund
  mbmf, // Mosque Building and Mendaki Fund
  sinda // Singapore Indian Development Association
}

/// CPF contribution rates for 2024
class CpfContributionRates {
  static const double ordinaryWageCeiling = 6800.0; // Monthly ceiling
  static const double additionalWageCeiling = 102000.0; // Annual ceiling

  /// Get CPF rates based on age and residency status
  static Map<String, double> getCpfRates(
      CpfAgeCategory ageCategory, SgResidencyStatus residencyStatus) {
    // Citizens and PRs (3rd year onwards)
    if (residencyStatus == SgResidencyStatus.citizen ||
        residencyStatus == SgResidencyStatus.pr) {
      switch (ageCategory) {
        case CpfAgeCategory.below55:
          return {'employee': 0.20, 'employer': 0.17, 'total': 0.37};
        case CpfAgeCategory.age55to60:
          return {'employee': 0.20, 'employer': 0.13, 'total': 0.33};
        case CpfAgeCategory.age60to65:
          return {'employee': 0.20, 'employer': 0.09, 'total': 0.29};
        case CpfAgeCategory.age65to70:
          return {'employee': 0.05, 'employer': 0.075, 'total': 0.125};
        case CpfAgeCategory.above70:
          return {'employee': 0.05, 'employer': 0.05, 'total': 0.10};
      }
    }

    // PRs in first year
    if (residencyStatus == SgResidencyStatus.prFirstYear) {
      switch (ageCategory) {
        case CpfAgeCategory.below55:
          return {'employee': 0.05, 'employer': 0.04, 'total': 0.09};
        case CpfAgeCategory.age55to60:
          return {'employee': 0.05, 'employer': 0.035, 'total': 0.085};
        case CpfAgeCategory.age60to65:
          return {'employee': 0.05, 'employer': 0.025, 'total': 0.075};
        case CpfAgeCategory.age65to70:
          return {'employee': 0.05, 'employer': 0.075, 'total': 0.125};
        case CpfAgeCategory.above70:
          return {'employee': 0.05, 'employer': 0.05, 'total': 0.10};
      }
    }

    // PRs in second year
    if (residencyStatus == SgResidencyStatus.prSecondYear) {
      switch (ageCategory) {
        case CpfAgeCategory.below55:
          return {'employee': 0.15, 'employer': 0.06, 'total': 0.21};
        case CpfAgeCategory.age55to60:
          return {'employee': 0.15, 'employer': 0.055, 'total': 0.205};
        case CpfAgeCategory.age60to65:
          return {'employee': 0.15, 'employer': 0.04, 'total': 0.19};
        case CpfAgeCategory.age65to70:
          return {'employee': 0.05, 'employer': 0.075, 'total': 0.125};
        case CpfAgeCategory.above70:
          return {'employee': 0.05, 'employer': 0.05, 'total': 0.10};
      }
    }

    // Non-residents (no CPF)
    return {'employee': 0.0, 'employer': 0.0, 'total': 0.0};
  }
}

/// Foreign Worker Levy (FWL) rates for 2024
class ForeignWorkerLevyRates {
  /// Get FWL rate based on sector, skill level, and work pass type
  static double getFwlRate(
      IndustrySector sector, SkillLevel skillLevel, WorkPassType workPassType) {
    // No levy for certain work passes
    if ([
      WorkPassType.employmentPass,
      WorkPassType.personalizedEmploymentPass,
      WorkPassType.techPass,
      WorkPassType.onePass,
      WorkPassType.entrePass
    ].contains(workPassType)) {
      return 0.0;
    }

    // S Pass levy rates (monthly)
    if (workPassType == WorkPassType.sPass) {
      switch (sector) {
        case IndustrySector.construction:
        case IndustrySector.manufacturing:
        case IndustrySector.marine:
        case IndustrySector.process:
          return 330.0;
        case IndustrySector.services:
          return 650.0;
      }
    }

    // Work Permit levy rates (monthly)
    if (workPassType == WorkPassType.workPermit ||
        workPassType == WorkPassType.trainingWorkPermit) {
      switch (sector) {
        case IndustrySector.construction:
          return skillLevel == SkillLevel.higher ? 300.0 : 950.0;
        case IndustrySector.manufacturing:
          return skillLevel == SkillLevel.higher ? 350.0 : 800.0;
        case IndustrySector.marine:
          return skillLevel == SkillLevel.higher ? 300.0 : 800.0;
        case IndustrySector.process:
          return skillLevel == SkillLevel.higher ? 350.0 : 800.0;
        case IndustrySector.services:
          return skillLevel == SkillLevel.higher ? 650.0 : 950.0;
      }
    }

    // Special work passes with reduced rates
    if ([
      WorkPassType.studentPassPartTime,
      WorkPassType.dependentPassLoc,
      WorkPassType.ltvpLoc
    ].contains(workPassType)) {
      return 50.0; // Minimal levy
    }

    return 0.0;
  }

  /// Get sector quota percentages
  static Map<String, double> getSectorQuota(IndustrySector sector) {
    switch (sector) {
      case IndustrySector.construction:
        return {'workPermit': 87.5, 'sPass': 20.0}; // As % of total workforce
      case IndustrySector.manufacturing:
        return {'workPermit': 60.0, 'sPass': 25.0};
      case IndustrySector.marine:
        return {'workPermit': 80.0, 'sPass': 20.0};
      case IndustrySector.process:
        return {'workPermit': 60.0, 'sPass': 25.0};
      case IndustrySector.services:
        return {'workPermit': 35.0, 'sPass': 15.0};
    }
  }
}

/// Self-Help Group contribution rates (monthly)
class SelfHelpGroupRates {
  static const Map<SelfHelpGroupType, double> monthlyRates = {
    SelfHelpGroupType.cdac: 2.00,
    SelfHelpGroupType.ecf: 2.00,
    SelfHelpGroupType.mbmf: 2.00,
    SelfHelpGroupType.sinda: 2.00,
  };

  /// Check if employee is eligible for SHG contribution based on ethnicity
  static List<SelfHelpGroupType> getEligibleSHG(String ethnicity) {
    final ethnic = ethnicity.toLowerCase();

    if (ethnic.contains('chinese')) {
      return [SelfHelpGroupType.cdac];
    } else if (ethnic.contains('malay')) {
      return [SelfHelpGroupType.mbmf];
    } else if (ethnic.contains('indian')) {
      return [SelfHelpGroupType.sinda];
    } else if (ethnic.contains('eurasian')) {
      return [SelfHelpGroupType.ecf];
    }

    return []; // Others not eligible
  }
}

/// CRDT-enabled Singapore CPF Calculation model
class CRDTSingaporeCpfCalculation implements CRDTModel {
  @override
  final String id;

  @override
  final String nodeId;

  @override
  final HLCTimestamp createdAt;

  @override
  HLCTimestamp updatedAt;

  @override
  VectorClock version;

  @override
  bool isDeleted;

  // Basic information
  late LWWRegister<String> employeeId;
  late LWWRegister<String> payrollRecordId;
  late LWWRegister<DateTime> calculationDate;
  late LWWRegister<String>
      ageCategory; // below_55, age_55_to_60, age_60_to_65, above_65
  late LWWRegister<String>
      residencyStatus; // citizen, pr, pr_first_2_years, non_resident

  // Wage components (in cents)
  late PNCounter ordinaryWageCents;
  late PNCounter additionalWageCents;
  late PNCounter totalWageCents;

  // CPF rates
  late LWWRegister<double> employeeRate;
  late LWWRegister<double> employerRate;
  late LWWRegister<double> totalRate;

  // CPF contributions (in cents)
  late PNCounter employeeContributionCents;
  late PNCounter employerContributionCents;
  late PNCounter totalContributionCents;

  // CPF ceilings and limits
  late LWWRegister<double> ordinaryWageCeiling;
  late LWWRegister<double> additionalWageCeiling;
  late LWWRegister<bool> isSubjectToCpf;

  // Additional information
  late LWWRegister<Map<String, dynamic>?> metadata;

  CRDTSingaporeCpfCalculation({
    required this.id,
    required this.nodeId,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required String empId,
    required String payrollId,
    required DateTime calcDate,
    required String age,
    required String residency,
    double ordinaryWage = 0.0,
    double additionalWage = 0.0,
    double empRate = 0.0,
    double emplerRate = 0.0,
    double owCeiling = 6000.0,
    double awCeiling = 102000.0,
    bool cpfSubject = true,
    Map<String, dynamic>? cpfMetadata,
    this.isDeleted = false,
  }) {
    // Initialize basic information
    employeeId = LWWRegister(empId, createdAt);
    payrollRecordId = LWWRegister(payrollId, createdAt);
    calculationDate = LWWRegister(calcDate, createdAt);
    ageCategory = LWWRegister(age, createdAt);
    residencyStatus = LWWRegister(residency, createdAt);

    // Initialize wage components
    ordinaryWageCents = PNCounter(nodeId);
    additionalWageCents = PNCounter(nodeId);
    totalWageCents = PNCounter(nodeId);

    if (ordinaryWage > 0)
      ordinaryWageCents.increment((ordinaryWage * 100).round());
    if (additionalWage > 0)
      additionalWageCents.increment((additionalWage * 100).round());
    totalWageCents.increment(((ordinaryWage + additionalWage) * 100).round());

    // Initialize rates
    employeeRate = LWWRegister(empRate, createdAt);
    employerRate = LWWRegister(emplerRate, createdAt);
    totalRate = LWWRegister(empRate + emplerRate, createdAt);

    // Initialize contributions
    employeeContributionCents = PNCounter(nodeId);
    employerContributionCents = PNCounter(nodeId);
    totalContributionCents = PNCounter(nodeId);

    // Initialize ceilings
    ordinaryWageCeiling = LWWRegister(owCeiling, createdAt);
    additionalWageCeiling = LWWRegister(awCeiling, createdAt);
    isSubjectToCpf = LWWRegister(cpfSubject, createdAt);

    // Initialize additional information
    metadata = LWWRegister(cpfMetadata, createdAt);
  }

  /// Get ordinary wage in dollars
  double get ordinaryWage => ordinaryWageCents.value / 100.0;

  /// Get additional wage in dollars
  double get additionalWage => additionalWageCents.value / 100.0;

  /// Get total wage in dollars
  double get totalWage => totalWageCents.value / 100.0;

  /// Get employee contribution in dollars
  double get employeeContribution => employeeContributionCents.value / 100.0;

  /// Get employer contribution in dollars
  double get employerContribution => employerContributionCents.value / 100.0;

  /// Get total contribution in dollars
  double get totalContribution => totalContributionCents.value / 100.0;

  /// Calculate CPF contributions based on Singapore rules
  void calculateCpfContributions(HLCTimestamp timestamp) {
    if (!isSubjectToCpf.value) {
      _resetContributions();
      _updateTimestamp(timestamp);
      return;
    }

    // Apply OW ceiling
    final cappedOW = ordinaryWage > ordinaryWageCeiling.value
        ? ordinaryWageCeiling.value
        : ordinaryWage;

    // Calculate contributions on capped OW
    final empContrib = cappedOW * employeeRate.value;
    final emplerContrib = cappedOW * employerRate.value;

    // Reset and set new contributions
    _resetContributions();
    if (empContrib > 0)
      employeeContributionCents.increment((empContrib * 100).round());
    if (emplerContrib > 0)
      employerContributionCents.increment((emplerContrib * 100).round());
    if (empContrib + emplerContrib > 0) {
      totalContributionCents
          .increment(((empContrib + emplerContrib) * 100).round());
    }

    _updateTimestamp(timestamp);
  }

  /// Update wage components
  void updateWages({
    double? newOrdinaryWage,
    double? newAdditionalWage,
    required HLCTimestamp timestamp,
  }) {
    if (newOrdinaryWage != null) {
      ordinaryWageCents.reset();
      if (newOrdinaryWage > 0) {
        ordinaryWageCents.increment((newOrdinaryWage * 100).round());
      }
    }

    if (newAdditionalWage != null) {
      additionalWageCents.reset();
      if (newAdditionalWage > 0) {
        additionalWageCents.increment((newAdditionalWage * 100).round());
      }
    }

    // Update total wage
    totalWageCents.reset();
    final total = ordinaryWage + additionalWage;
    if (total > 0) {
      totalWageCents.increment((total * 100).round());
    }

    _updateTimestamp(timestamp);
  }

  /// Update CPF rates
  void updateCpfRates({
    double? newEmployeeRate,
    double? newEmployerRate,
    required HLCTimestamp timestamp,
  }) {
    if (newEmployeeRate != null)
      employeeRate.setValue(newEmployeeRate, timestamp);
    if (newEmployerRate != null)
      employerRate.setValue(newEmployerRate, timestamp);

    totalRate.setValue(employeeRate.value + employerRate.value, timestamp);
    _updateTimestamp(timestamp);
  }

  void _resetContributions() {
    employeeContributionCents.reset();
    employerContributionCents.reset();
    totalContributionCents.reset();
  }

  void _updateTimestamp(HLCTimestamp timestamp) {
    if (timestamp.happensAfter(updatedAt)) {
      updatedAt = timestamp;
      version = version.tick();
    }
  }

  @override
  void mergeWith(CRDTModel other) {
    if (other is! CRDTSingaporeCpfCalculation || other.id != id) {
      throw ArgumentError('Cannot merge with different CPF calculation');
    }

    // Merge all CRDT fields
    employeeId.mergeWith(other.employeeId);
    payrollRecordId.mergeWith(other.payrollRecordId);
    calculationDate.mergeWith(other.calculationDate);
    ageCategory.mergeWith(other.ageCategory);
    residencyStatus.mergeWith(other.residencyStatus);

    ordinaryWageCents.mergeWith(other.ordinaryWageCents);
    additionalWageCents.mergeWith(other.additionalWageCents);
    totalWageCents.mergeWith(other.totalWageCents);

    employeeRate.mergeWith(other.employeeRate);
    employerRate.mergeWith(other.employerRate);
    totalRate.mergeWith(other.totalRate);

    employeeContributionCents.mergeWith(other.employeeContributionCents);
    employerContributionCents.mergeWith(other.employerContributionCents);
    totalContributionCents.mergeWith(other.totalContributionCents);

    ordinaryWageCeiling.mergeWith(other.ordinaryWageCeiling);
    additionalWageCeiling.mergeWith(other.additionalWageCeiling);
    isSubjectToCpf.mergeWith(other.isSubjectToCpf);

    metadata.mergeWith(other.metadata);

    // Update version and timestamp
    version = version.update(other.version);
    if (other.updatedAt.happensAfter(updatedAt)) {
      updatedAt = other.updatedAt;
    }

    // Handle deletion
    isDeleted = isDeleted || other.isDeleted;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId.value,
      'payroll_record_id': payrollRecordId.value,
      'calculation_date': calculationDate.value.millisecondsSinceEpoch,
      'age_category': ageCategory.value,
      'residency_status': residencyStatus.value,
      'ordinary_wage': ordinaryWage,
      'additional_wage': additionalWage,
      'total_wage': totalWage,
      'employee_rate': employeeRate.value,
      'employer_rate': employerRate.value,
      'total_rate': totalRate.value,
      'employee_contribution': employeeContribution,
      'employer_contribution': employerContribution,
      'total_contribution': totalContribution,
      'ordinary_wage_ceiling': ordinaryWageCeiling.value,
      'additional_wage_ceiling': additionalWageCeiling.value,
      'is_subject_to_cpf': isSubjectToCpf.value,
      'metadata': metadata.value,
      'is_deleted': isDeleted,
      'created_at': createdAt.physicalTime,
      'updated_at': updatedAt.physicalTime,
    };
  }

  @override
  Map<String, dynamic> toCRDTJson() {
    return {
      'id': id,
      'node_id': nodeId,
      'created_at': createdAt.toString(),
      'updated_at': updatedAt.toString(),
      'version': version.toString(),
      'is_deleted': isDeleted,
      'employee_id': employeeId.toJson(),
      'payroll_record_id': payrollRecordId.toJson(),
      'calculation_date': calculationDate.toJson(),
      'age_category': ageCategory.toJson(),
      'residency_status': residencyStatus.toJson(),
      'ordinary_wage_cents': ordinaryWageCents.toJson(),
      'additional_wage_cents': additionalWageCents.toJson(),
      'total_wage_cents': totalWageCents.toJson(),
      'employee_rate': employeeRate.toJson(),
      'employer_rate': employerRate.toJson(),
      'total_rate': totalRate.toJson(),
      'employee_contribution_cents': employeeContributionCents.toJson(),
      'employer_contribution_cents': employerContributionCents.toJson(),
      'total_contribution_cents': totalContributionCents.toJson(),
      'ordinary_wage_ceiling': ordinaryWageCeiling.toJson(),
      'additional_wage_ceiling': additionalWageCeiling.toJson(),
      'is_subject_to_cpf': isSubjectToCpf.toJson(),
      'metadata': metadata.toJson(),
    };
  }
}

/// CRDT-enabled IR8A Tax Form model (Annual tax form)
class CRDTIR8ATaxForm implements CRDTModel {
  @override
  final String id;

  @override
  final String nodeId;

  @override
  final HLCTimestamp createdAt;

  @override
  HLCTimestamp updatedAt;

  @override
  VectorClock version;

  @override
  bool isDeleted;

  // Basic information
  late LWWRegister<String> employeeId;
  late LWWRegister<int> taxYear;
  late LWWRegister<String> formStatus; // draft, submitted, approved
  late LWWRegister<DateTime?> submissionDate;

  // Employee details
  late LWWRegister<String> employeeName;
  late LWWRegister<String?> nricFinNumber;
  late LWWRegister<String?> passportNumber;
  late LWWRegister<String> nationality;
  late LWWRegister<String> residencyStatus;

  // Employment details
  late LWWRegister<String> employerName;
  late LWWRegister<String> employerUen;
  late LWWRegister<DateTime> employmentStartDate;
  late LWWRegister<DateTime?> employmentEndDate;
  late LWWRegister<String> designation;

  // Income components (in cents)
  late PNCounter grossSalaryCents;
  late PNCounter directorsFeesCents;
  late PNCounter bonusCents;
  late PNCounter commissionCents;
  late PNCounter allowancesCents;
  late PNCounter benefitsInKindCents;
  late PNCounter stockOptionsCents;
  late PNCounter otherIncomeCents;
  late PNCounter totalIncomeCents;

  // CPF contributions (in cents)
  late PNCounter employeeCpfCents;
  late PNCounter employerCpfCents;
  late PNCounter totalCpfCents;

  // Tax deductions (in cents)
  late PNCounter taxDeductedCents;
  late PNCounter sdlCents;
  late PNCounter fwlCents;

  // Additional information
  late LWWRegister<bool> hasStockOptions;
  late LWWRegister<bool> hasBenefitsInKind;
  late LWWRegister<String?> remarks;
  late LWWRegister<Map<String, dynamic>?> metadata;

  CRDTIR8ATaxForm({
    required this.id,
    required this.nodeId,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required String empId,
    required int year,
    String status = 'draft',
    DateTime? submitted,
    required String empName,
    String? nricFin,
    String? passport,
    required String empNationality,
    required String residency,
    required String employer,
    required String uen,
    required DateTime empStart,
    DateTime? empEnd,
    required String jobDesignation,
    double grossSalary = 0.0,
    double directorsFees = 0.0,
    double bonus = 0.0,
    double commission = 0.0,
    double allowances = 0.0,
    double benefitsInKind = 0.0,
    double stockOptions = 0.0,
    double otherIncome = 0.0,
    double employeeCpf = 0.0,
    double employerCpf = 0.0,
    double taxDeducted = 0.0,
    double sdl = 0.0,
    double fwl = 0.0,
    bool stockOpt = false,
    bool benefits = false,
    String? formRemarks,
    Map<String, dynamic>? formMetadata,
    this.isDeleted = false,
  }) {
    // Initialize basic information
    employeeId = LWWRegister(empId, createdAt);
    taxYear = LWWRegister(year, createdAt);
    formStatus = LWWRegister(status, createdAt);
    submissionDate = LWWRegister(submitted, createdAt);

    // Initialize employee details
    employeeName = LWWRegister(empName, createdAt);
    nricFinNumber = LWWRegister(nricFin, createdAt);
    passportNumber = LWWRegister(passport, createdAt);
    nationality = LWWRegister(empNationality, createdAt);
    residencyStatus = LWWRegister(residency, createdAt);

    // Initialize employment details
    employerName = LWWRegister(employer, createdAt);
    employerUen = LWWRegister(uen, createdAt);
    employmentStartDate = LWWRegister(empStart, createdAt);
    employmentEndDate = LWWRegister(empEnd, createdAt);
    designation = LWWRegister(jobDesignation, createdAt);

    // Initialize income components
    grossSalaryCents = PNCounter(nodeId);
    directorsFeesCents = PNCounter(nodeId);
    bonusCents = PNCounter(nodeId);
    commissionCents = PNCounter(nodeId);
    allowancesCents = PNCounter(nodeId);
    benefitsInKindCents = PNCounter(nodeId);
    stockOptionsCents = PNCounter(nodeId);
    otherIncomeCents = PNCounter(nodeId);
    totalIncomeCents = PNCounter(nodeId);

    // Set initial income values
    if (grossSalary > 0)
      grossSalaryCents.increment((grossSalary * 100).round());
    if (directorsFees > 0)
      directorsFeesCents.increment((directorsFees * 100).round());
    if (bonus > 0) bonusCents.increment((bonus * 100).round());
    if (commission > 0) commissionCents.increment((commission * 100).round());
    if (allowances > 0) allowancesCents.increment((allowances * 100).round());
    if (benefitsInKind > 0)
      benefitsInKindCents.increment((benefitsInKind * 100).round());
    if (stockOptions > 0)
      stockOptionsCents.increment((stockOptions * 100).round());
    if (otherIncome > 0)
      otherIncomeCents.increment((otherIncome * 100).round());

    // Calculate total income
    final total = grossSalary +
        directorsFees +
        bonus +
        commission +
        allowances +
        benefitsInKind +
        stockOptions +
        otherIncome;
    if (total > 0) totalIncomeCents.increment((total * 100).round());

    // Initialize CPF contributions
    employeeCpfCents = PNCounter(nodeId);
    employerCpfCents = PNCounter(nodeId);
    totalCpfCents = PNCounter(nodeId);

    if (employeeCpf > 0)
      employeeCpfCents.increment((employeeCpf * 100).round());
    if (employerCpf > 0)
      employerCpfCents.increment((employerCpf * 100).round());
    if (employeeCpf + employerCpf > 0) {
      totalCpfCents.increment(((employeeCpf + employerCpf) * 100).round());
    }

    // Initialize tax deductions
    taxDeductedCents = PNCounter(nodeId);
    sdlCents = PNCounter(nodeId);
    fwlCents = PNCounter(nodeId);

    if (taxDeducted > 0)
      taxDeductedCents.increment((taxDeducted * 100).round());
    if (sdl > 0) sdlCents.increment((sdl * 100).round());
    if (fwl > 0) fwlCents.increment((fwl * 100).round());

    // Initialize additional information
    hasStockOptions = LWWRegister(stockOpt, createdAt);
    hasBenefitsInKind = LWWRegister(benefits, createdAt);
    remarks = LWWRegister(formRemarks, createdAt);
    metadata = LWWRegister(formMetadata, createdAt);
  }

  /// Get gross salary in dollars
  double get grossSalary => grossSalaryCents.value / 100.0;

  /// Get total income in dollars
  double get totalIncome => totalIncomeCents.value / 100.0;

  /// Get total CPF in dollars
  double get totalCpf => totalCpfCents.value / 100.0;

  /// Get tax deducted in dollars
  double get taxDeducted => taxDeductedCents.value / 100.0;

  /// Update income components
  void updateIncomeComponents({
    double? newGrossSalary,
    double? newDirectorsFees,
    double? newBonus,
    double? newCommission,
    double? newAllowances,
    double? newBenefitsInKind,
    double? newStockOptions,
    double? newOtherIncome,
    required HLCTimestamp timestamp,
  }) {
    if (newGrossSalary != null) {
      grossSalaryCents.reset();
      if (newGrossSalary > 0)
        grossSalaryCents.increment((newGrossSalary * 100).round());
    }

    if (newDirectorsFees != null) {
      directorsFeesCents.reset();
      if (newDirectorsFees > 0)
        directorsFeesCents.increment((newDirectorsFees * 100).round());
    }

    if (newBonus != null) {
      bonusCents.reset();
      if (newBonus > 0) bonusCents.increment((newBonus * 100).round());
    }

    if (newCommission != null) {
      commissionCents.reset();
      if (newCommission > 0)
        commissionCents.increment((newCommission * 100).round());
    }

    if (newAllowances != null) {
      allowancesCents.reset();
      if (newAllowances > 0)
        allowancesCents.increment((newAllowances * 100).round());
    }

    if (newBenefitsInKind != null) {
      benefitsInKindCents.reset();
      if (newBenefitsInKind > 0)
        benefitsInKindCents.increment((newBenefitsInKind * 100).round());
    }

    if (newStockOptions != null) {
      stockOptionsCents.reset();
      if (newStockOptions > 0)
        stockOptionsCents.increment((newStockOptions * 100).round());
    }

    if (newOtherIncome != null) {
      otherIncomeCents.reset();
      if (newOtherIncome > 0)
        otherIncomeCents.increment((newOtherIncome * 100).round());
    }

    // Recalculate total income
    _recalculateTotalIncome();
    _updateTimestamp(timestamp);
  }

  /// Submit form
  void submitForm(HLCTimestamp timestamp) {
    formStatus.setValue('submitted', timestamp);
    submissionDate.setValue(DateTime.now(), timestamp);
    _updateTimestamp(timestamp);
  }

  void _recalculateTotalIncome() {
    totalIncomeCents.reset();
    final total = (grossSalaryCents.value +
        directorsFeesCents.value +
        bonusCents.value +
        commissionCents.value +
        allowancesCents.value +
        benefitsInKindCents.value +
        stockOptionsCents.value +
        otherIncomeCents.value);
    if (total > 0) totalIncomeCents.increment(total);
  }

  void _updateTimestamp(HLCTimestamp timestamp) {
    if (timestamp.happensAfter(updatedAt)) {
      updatedAt = timestamp;
      version = version.tick();
    }
  }

  @override
  void mergeWith(CRDTModel other) {
    if (other is! CRDTIR8ATaxForm || other.id != id) {
      throw ArgumentError('Cannot merge with different IR8A form');
    }

    // Merge all CRDT fields
    employeeId.mergeWith(other.employeeId);
    taxYear.mergeWith(other.taxYear);
    formStatus.mergeWith(other.formStatus);
    submissionDate.mergeWith(other.submissionDate);

    employeeName.mergeWith(other.employeeName);
    nricFinNumber.mergeWith(other.nricFinNumber);
    passportNumber.mergeWith(other.passportNumber);
    nationality.mergeWith(other.nationality);
    residencyStatus.mergeWith(other.residencyStatus);

    employerName.mergeWith(other.employerName);
    employerUen.mergeWith(other.employerUen);
    employmentStartDate.mergeWith(other.employmentStartDate);
    employmentEndDate.mergeWith(other.employmentEndDate);
    designation.mergeWith(other.designation);

    grossSalaryCents.mergeWith(other.grossSalaryCents);
    directorsFeesCents.mergeWith(other.directorsFeesCents);
    bonusCents.mergeWith(other.bonusCents);
    commissionCents.mergeWith(other.commissionCents);
    allowancesCents.mergeWith(other.allowancesCents);
    benefitsInKindCents.mergeWith(other.benefitsInKindCents);
    stockOptionsCents.mergeWith(other.stockOptionsCents);
    otherIncomeCents.mergeWith(other.otherIncomeCents);
    totalIncomeCents.mergeWith(other.totalIncomeCents);

    employeeCpfCents.mergeWith(other.employeeCpfCents);
    employerCpfCents.mergeWith(other.employerCpfCents);
    totalCpfCents.mergeWith(other.totalCpfCents);

    taxDeductedCents.mergeWith(other.taxDeductedCents);
    sdlCents.mergeWith(other.sdlCents);
    fwlCents.mergeWith(other.fwlCents);

    hasStockOptions.mergeWith(other.hasStockOptions);
    hasBenefitsInKind.mergeWith(other.hasBenefitsInKind);
    remarks.mergeWith(other.remarks);
    metadata.mergeWith(other.metadata);

    // Update version and timestamp
    version = version.update(other.version);
    if (other.updatedAt.happensAfter(updatedAt)) {
      updatedAt = other.updatedAt;
    }

    // Handle deletion
    isDeleted = isDeleted || other.isDeleted;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId.value,
      'tax_year': taxYear.value,
      'form_status': formStatus.value,
      'submission_date': submissionDate.value?.millisecondsSinceEpoch,
      'employee_name': employeeName.value,
      'nric_fin_number': nricFinNumber.value,
      'passport_number': passportNumber.value,
      'nationality': nationality.value,
      'residency_status': residencyStatus.value,
      'employer_name': employerName.value,
      'employer_uen': employerUen.value,
      'employment_start_date': employmentStartDate.value.millisecondsSinceEpoch,
      'employment_end_date': employmentEndDate.value?.millisecondsSinceEpoch,
      'designation': designation.value,
      'gross_salary': grossSalary,
      'directors_fees': directorsFeesCents.value / 100.0,
      'bonus': bonusCents.value / 100.0,
      'commission': commissionCents.value / 100.0,
      'allowances': allowancesCents.value / 100.0,
      'benefits_in_kind': benefitsInKindCents.value / 100.0,
      'stock_options': stockOptionsCents.value / 100.0,
      'other_income': otherIncomeCents.value / 100.0,
      'total_income': totalIncome,
      'employee_cpf': employeeCpfCents.value / 100.0,
      'employer_cpf': employerCpfCents.value / 100.0,
      'total_cpf': totalCpf,
      'tax_deducted': taxDeducted,
      'sdl': sdlCents.value / 100.0,
      'fwl': fwlCents.value / 100.0,
      'has_stock_options': hasStockOptions.value,
      'has_benefits_in_kind': hasBenefitsInKind.value,
      'remarks': remarks.value,
      'metadata': metadata.value,
      'is_deleted': isDeleted,
      'created_at': createdAt.physicalTime,
      'updated_at': updatedAt.physicalTime,
    };
  }

  @override
  Map<String, dynamic> toCRDTJson() {
    return {
      'id': id,
      'node_id': nodeId,
      'created_at': createdAt.toString(),
      'updated_at': updatedAt.toString(),
      'version': version.toString(),
      'is_deleted': isDeleted,
      'employee_id': employeeId.toJson(),
      'tax_year': taxYear.toJson(),
      'form_status': formStatus.toJson(),
      'submission_date': submissionDate.toJson(),
      'employee_name': employeeName.toJson(),
      'nric_fin_number': nricFinNumber.toJson(),
      'passport_number': passportNumber.toJson(),
      'nationality': nationality.toJson(),
      'residency_status': residencyStatus.toJson(),
      'employer_name': employerName.toJson(),
      'employer_uen': employerUen.toJson(),
      'employment_start_date': employmentStartDate.toJson(),
      'employment_end_date': employmentEndDate.toJson(),
      'designation': designation.toJson(),
      'gross_salary_cents': grossSalaryCents.toJson(),
      'directors_fees_cents': directorsFeesCents.toJson(),
      'bonus_cents': bonusCents.toJson(),
      'commission_cents': commissionCents.toJson(),
      'allowances_cents': allowancesCents.toJson(),
      'benefits_in_kind_cents': benefitsInKindCents.toJson(),
      'stock_options_cents': stockOptionsCents.toJson(),
      'other_income_cents': otherIncomeCents.toJson(),
      'total_income_cents': totalIncomeCents.toJson(),
      'employee_cpf_cents': employeeCpfCents.toJson(),
      'employer_cpf_cents': employerCpfCents.toJson(),
      'total_cpf_cents': totalCpfCents.toJson(),
      'tax_deducted_cents': taxDeductedCents.toJson(),
      'sdl_cents': sdlCents.toJson(),
      'fwl_cents': fwlCents.toJson(),
      'has_stock_options': hasStockOptions.toJson(),
      'has_benefits_in_kind': hasBenefitsInKind.toJson(),
      'remarks': remarks.toJson(),
      'metadata': metadata.toJson(),
    };
  }
}

/// CRDT-enabled Work Pass Management model
class CRDTWorkPassManagement implements CRDTModel {
  @override
  final String id;

  @override
  final String nodeId;

  @override
  final HLCTimestamp createdAt;

  @override
  HLCTimestamp updatedAt;

  @override
  VectorClock version;

  @override
  bool isDeleted;

  // Basic information
  late LWWRegister<String> employeeId;
  late LWWRegister<String> workPassNumber;
  late LWWRegister<String>
      workPassType; // Stored as string for CRDT compatibility
  late LWWRegister<String> industrySector;
  late LWWRegister<String> skillLevel;

  // Pass validity
  late LWWRegister<DateTime> passStartDate;
  late LWWRegister<DateTime> passExpiryDate;
  late LWWRegister<bool> isActive;
  late LWWRegister<String> passStatus; // active, expired, cancelled, pending

  // Company information
  late LWWRegister<String> companyUen;
  late LWWRegister<String> companyName;
  late LWWRegister<String> jobDesignation;
  late LWWRegister<double> basicSalary;

  // Levy information (in cents)
  late PNCounter monthlyLevyCents;
  late PNCounter totalLevyPaidCents;
  late LWWRegister<DateTime?> lastLevyPaymentDate;

  // Quota tracking
  late LWWRegister<int> sectorTotalEmployees;
  late LWWRegister<int> sectorForeignEmployees;
  late LWWRegister<double> currentQuotaUsage;

  // Metadata
  late LWWRegister<Map<String, dynamic>?> metadata;

  CRDTWorkPassManagement({
    required this.id,
    required this.nodeId,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required String empId,
    required String passNumber,
    required String passType,
    required String sector,
    required String skill,
    required DateTime startDate,
    required DateTime expiryDate,
    required String compUen,
    required String compName,
    required String designation,
    double salary = 0.0,
    bool active = true,
    String status = 'active',
    double monthlyLevy = 0.0,
    int totalEmployees = 0,
    int foreignEmployees = 0,
    Map<String, dynamic>? passMetadata,
    this.isDeleted = false,
  }) {
    // Initialize basic information
    employeeId = LWWRegister(empId, createdAt);
    workPassNumber = LWWRegister(passNumber, createdAt);
    workPassType = LWWRegister(passType, createdAt);
    industrySector = LWWRegister(sector, createdAt);
    skillLevel = LWWRegister(skill, createdAt);

    // Initialize pass validity
    passStartDate = LWWRegister(startDate, createdAt);
    passExpiryDate = LWWRegister(expiryDate, createdAt);
    isActive = LWWRegister(active, createdAt);
    passStatus = LWWRegister(status, createdAt);

    // Initialize company information
    companyUen = LWWRegister(compUen, createdAt);
    companyName = LWWRegister(compName, createdAt);
    jobDesignation = LWWRegister(designation, createdAt);
    basicSalary = LWWRegister(salary, createdAt);

    // Initialize levy information
    monthlyLevyCents = PNCounter(nodeId);
    totalLevyPaidCents = PNCounter(nodeId);
    lastLevyPaymentDate = LWWRegister(null, createdAt);

    if (monthlyLevy > 0)
      monthlyLevyCents.increment((monthlyLevy * 100).round());

    // Initialize quota tracking
    sectorTotalEmployees = LWWRegister(totalEmployees, createdAt);
    sectorForeignEmployees = LWWRegister(foreignEmployees, createdAt);
    currentQuotaUsage = LWWRegister(
        totalEmployees > 0 ? (foreignEmployees / totalEmployees * 100) : 0.0,
        createdAt);

    // Initialize metadata
    metadata = LWWRegister(passMetadata, createdAt);
  }

  /// Get monthly levy in dollars
  double get monthlyLevy => monthlyLevyCents.value / 100.0;

  /// Get total levy paid in dollars
  double get totalLevyPaid => totalLevyPaidCents.value / 100.0;

  /// Check if pass is valid
  bool get isValidPass {
    final now = DateTime.now();
    return isActive.value &&
        passStatus.value == 'active' &&
        now.isAfter(passStartDate.value) &&
        now.isBefore(passExpiryDate.value);
  }

  /// Calculate monthly levy based on current rates
  void calculateMonthlyLevy(HLCTimestamp timestamp) {
    try {
      final workPass = WorkPassType.values.firstWhere(
          (e) => e.toString().split('.').last == workPassType.value);
      final sector = IndustrySector.values.firstWhere(
          (e) => e.toString().split('.').last == industrySector.value);
      final skill = SkillLevel.values
          .firstWhere((e) => e.toString().split('.').last == skillLevel.value);

      final levy = ForeignWorkerLevyRates.getFwlRate(sector, skill, workPass);

      monthlyLevyCents.reset();
      if (levy > 0) {
        monthlyLevyCents.increment((levy * 100).round());
      }

      _updateTimestamp(timestamp);
    } catch (e) {
      // Handle invalid enum values gracefully
      monthlyLevyCents.reset();
      _updateTimestamp(timestamp);
    }
  }

  /// Record levy payment
  void recordLevyPayment(
      double amount, DateTime paymentDate, HLCTimestamp timestamp) {
    if (amount > 0) {
      totalLevyPaidCents.increment((amount * 100).round());
    }
    lastLevyPaymentDate.setValue(paymentDate, timestamp);
    _updateTimestamp(timestamp);
  }

  /// Update quota information
  void updateQuotaInfo(int totalEmps, int foreignEmps, HLCTimestamp timestamp) {
    sectorTotalEmployees.setValue(totalEmps, timestamp);
    sectorForeignEmployees.setValue(foreignEmps, timestamp);

    final usage = totalEmps > 0 ? (foreignEmps / totalEmps * 100) : 0.0;
    currentQuotaUsage.setValue(usage, timestamp);

    _updateTimestamp(timestamp);
  }

  /// Renew work pass
  void renewWorkPass(DateTime newExpiryDate, HLCTimestamp timestamp) {
    passExpiryDate.setValue(newExpiryDate, timestamp);
    passStatus.setValue('active', timestamp);
    isActive.setValue(true, timestamp);
    _updateTimestamp(timestamp);
  }

  /// Cancel work pass
  void cancelWorkPass(String reason, HLCTimestamp timestamp) {
    passStatus.setValue('cancelled', timestamp);
    isActive.setValue(false, timestamp);

    // Add cancellation reason to metadata
    final currentMeta = metadata.value ?? <String, dynamic>{};
    currentMeta['cancellation_reason'] = reason;
    currentMeta['cancellation_date'] = DateTime.now().toIso8601String();
    metadata.setValue(currentMeta, timestamp);

    _updateTimestamp(timestamp);
  }

  void _updateTimestamp(HLCTimestamp timestamp) {
    if (timestamp.happensAfter(updatedAt)) {
      updatedAt = timestamp;
      version = version.tick();
    }
  }

  @override
  void mergeWith(CRDTModel other) {
    if (other is! CRDTWorkPassManagement || other.id != id) {
      throw ArgumentError('Cannot merge with different work pass record');
    }

    // Merge all CRDT fields
    employeeId.mergeWith(other.employeeId);
    workPassNumber.mergeWith(other.workPassNumber);
    workPassType.mergeWith(other.workPassType);
    industrySector.mergeWith(other.industrySector);
    skillLevel.mergeWith(other.skillLevel);

    passStartDate.mergeWith(other.passStartDate);
    passExpiryDate.mergeWith(other.passExpiryDate);
    isActive.mergeWith(other.isActive);
    passStatus.mergeWith(other.passStatus);

    companyUen.mergeWith(other.companyUen);
    companyName.mergeWith(other.companyName);
    jobDesignation.mergeWith(other.jobDesignation);
    basicSalary.mergeWith(other.basicSalary);

    monthlyLevyCents.mergeWith(other.monthlyLevyCents);
    totalLevyPaidCents.mergeWith(other.totalLevyPaidCents);
    lastLevyPaymentDate.mergeWith(other.lastLevyPaymentDate);

    sectorTotalEmployees.mergeWith(other.sectorTotalEmployees);
    sectorForeignEmployees.mergeWith(other.sectorForeignEmployees);
    currentQuotaUsage.mergeWith(other.currentQuotaUsage);

    metadata.mergeWith(other.metadata);

    // Update version and timestamp
    version = version.update(other.version);
    if (other.updatedAt.happensAfter(updatedAt)) {
      updatedAt = other.updatedAt;
    }

    // Handle deletion
    isDeleted = isDeleted || other.isDeleted;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId.value,
      'work_pass_number': workPassNumber.value,
      'work_pass_type': workPassType.value,
      'industry_sector': industrySector.value,
      'skill_level': skillLevel.value,
      'pass_start_date': passStartDate.value.millisecondsSinceEpoch,
      'pass_expiry_date': passExpiryDate.value.millisecondsSinceEpoch,
      'is_active': isActive.value,
      'pass_status': passStatus.value,
      'company_uen': companyUen.value,
      'company_name': companyName.value,
      'job_designation': jobDesignation.value,
      'basic_salary': basicSalary.value,
      'monthly_levy': monthlyLevy,
      'total_levy_paid': totalLevyPaid,
      'last_levy_payment_date':
          lastLevyPaymentDate.value?.millisecondsSinceEpoch,
      'sector_total_employees': sectorTotalEmployees.value,
      'sector_foreign_employees': sectorForeignEmployees.value,
      'current_quota_usage': currentQuotaUsage.value,
      'is_valid_pass': isValidPass,
      'metadata': metadata.value,
      'is_deleted': isDeleted,
      'created_at': createdAt.physicalTime,
      'updated_at': updatedAt.physicalTime,
    };
  }

  @override
  Map<String, dynamic> toCRDTJson() {
    return {
      'id': id,
      'node_id': nodeId,
      'created_at': createdAt.toString(),
      'updated_at': updatedAt.toString(),
      'version': version.toString(),
      'is_deleted': isDeleted,
      'employee_id': employeeId.toJson(),
      'work_pass_number': workPassNumber.toJson(),
      'work_pass_type': workPassType.toJson(),
      'industry_sector': industrySector.toJson(),
      'skill_level': skillLevel.toJson(),
      'pass_start_date': passStartDate.toJson(),
      'pass_expiry_date': passExpiryDate.toJson(),
      'is_active': isActive.toJson(),
      'pass_status': passStatus.toJson(),
      'company_uen': companyUen.toJson(),
      'company_name': companyName.toJson(),
      'job_designation': jobDesignation.toJson(),
      'basic_salary': basicSalary.toJson(),
      'monthly_levy_cents': monthlyLevyCents.toJson(),
      'total_levy_paid_cents': totalLevyPaidCents.toJson(),
      'last_levy_payment_date': lastLevyPaymentDate.toJson(),
      'sector_total_employees': sectorTotalEmployees.toJson(),
      'sector_foreign_employees': sectorForeignEmployees.toJson(),
      'current_quota_usage': currentQuotaUsage.toJson(),
      'metadata': metadata.toJson(),
    };
  }
}
