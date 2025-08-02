import 'dart:convert';
import '../../../core/crdt/hybrid_logical_clock.dart';
import '../../../core/crdt/vector_clock.dart';
import '../../../core/crdt/crdt_types.dart';
import '../../../core/crdt/lww_register.dart';
import '../../../core/crdt/pn_counter.dart';
import '../../../core/crdt/or_set.dart';
import '../../../core/database/crdt_models.dart';
import 'singapore_tax_models.dart';

/// CRDT-enabled Enhanced Payroll Calculation model
class CRDTEnhancedPayrollCalculation implements CRDTModel {
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
  late LWWRegister<String> payrollPeriod; // YYYY-MM format
  late LWWRegister<DateTime> calculationDate;
  late LWWRegister<String> calculationStatus; // draft, calculated, approved, paid
  
  // Employee classification
  late LWWRegister<String> ageCategory;
  late LWWRegister<String> residencyStatus;
  late LWWRegister<String?> workPassType;
  late LWWRegister<String?> ethnicity;
  
  // Wage components (in cents)
  late PNCounter basicSalaryCents;
  late PNCounter overtimeCents;
  late PNCounter allowancesCents;
  late PNCounter commissionCents;
  late PNCounter bonusCents;
  late PNCounter benefitsInKindCents;
  
  // Total wages
  late PNCounter ordinaryWageCents;
  late PNCounter additionalWageCents;
  late PNCounter grossWageCents;
  
  // CPF calculations (in cents)
  late PNCounter employeeCpfCents;
  late PNCounter employerCpfCents;
  late PNCounter totalCpfCents;
  late PNCounter cpfRefundCents; // For excess contributions
  
  // SHG contributions (in cents)
  late PNCounter cdacCents;
  late PNCounter ecfCents;
  late PNCounter mbmfCents;
  late PNCounter sindaCents;
  late PNCounter totalShgCents;
  
  // Other deductions (in cents)
  late PNCounter incomeTaxCents;
  late PNCounter fwlCents;
  late PNCounter sdlCents; // Skills Development Levy
  late PNCounter otherDeductionsCents;
  
  // Net calculations (in cents)
  late PNCounter totalDeductionsCents;
  late PNCounter netPayCents;
  
  // CPF account allocations (in cents)
  late PNCounter ordinaryAccountCents;
  late PNCounter specialAccountCents;
  late PNCounter medisaveAccountCents;
  
  // Make-up contributions tracking
  late PNCounter makeupContributionsCents;
  late LWWRegister<DateTime?> lastMakeupDate;
  
  // CPF interest calculations
  late LWWRegister<double> cpfInterestRate;
  late PNCounter cpfInterestEarnedCents;
  
  // Metadata
  late LWWRegister<Map<String, dynamic>?> metadata;
  
  CRDTEnhancedPayrollCalculation({
    required this.id,
    required this.nodeId,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required String empId,
    required String period,
    required DateTime calcDate,
    required String ageCategory,
    required String residencyStatus,
    String? workPass,
    String? empEthnicity,
    double basicSalary = 0.0,
    double overtime = 0.0,
    double allowances = 0.0,
    double commission = 0.0,
    double bonus = 0.0,
    double benefitsInKind = 0.0,
    double incomeTax = 0.0,
    double fwl = 0.0,
    double sdl = 0.0,
    double otherDeductions = 0.0,
    String status = 'draft',
    Map<String, dynamic>? payrollMetadata,
    this.isDeleted = false,
  }) {
    // Initialize basic information
    employeeId = LWWRegister(empId, createdAt);
    payrollPeriod = LWWRegister(period, createdAt);
    calculationDate = LWWRegister(calcDate, createdAt);
    calculationStatus = LWWRegister(status, createdAt);
    
    // Initialize employee classification
    this.ageCategory = LWWRegister(ageCategory, createdAt);
    this.residencyStatus = LWWRegister(residencyStatus, createdAt);
    workPassType = LWWRegister(workPass, createdAt);
    ethnicity = LWWRegister(empEthnicity, createdAt);
    
    // Initialize wage components
    basicSalaryCents = PNCounter(nodeId);
    overtimeCents = PNCounter(nodeId);
    allowancesCents = PNCounter(nodeId);
    commissionCents = PNCounter(nodeId);
    bonusCents = PNCounter(nodeId);
    benefitsInKindCents = PNCounter(nodeId);
    
    if (basicSalary > 0) basicSalaryCents.increment((basicSalary * 100).round());
    if (overtime > 0) overtimeCents.increment((overtime * 100).round());
    if (allowances > 0) allowancesCents.increment((allowances * 100).round());
    if (commission > 0) commissionCents.increment((commission * 100).round());
    if (bonus > 0) bonusCents.increment((bonus * 100).round());
    if (benefitsInKind > 0) benefitsInKindCents.increment((benefitsInKind * 100).round());
    
    // Initialize total wages
    ordinaryWageCents = PNCounter(nodeId);
    additionalWageCents = PNCounter(nodeId);
    grossWageCents = PNCounter(nodeId);
    
    // Initialize CPF calculations
    employeeCpfCents = PNCounter(nodeId);
    employerCpfCents = PNCounter(nodeId);
    totalCpfCents = PNCounter(nodeId);
    cpfRefundCents = PNCounter(nodeId);
    
    // Initialize SHG contributions
    cdacCents = PNCounter(nodeId);
    ecfCents = PNCounter(nodeId);
    mbmfCents = PNCounter(nodeId);
    sindaCents = PNCounter(nodeId);
    totalShgCents = PNCounter(nodeId);
    
    // Initialize other deductions
    incomeTaxCents = PNCounter(nodeId);
    fwlCents = PNCounter(nodeId);
    sdlCents = PNCounter(nodeId);
    otherDeductionsCents = PNCounter(nodeId);
    
    if (incomeTax > 0) incomeTaxCents.increment((incomeTax * 100).round());
    if (fwl > 0) fwlCents.increment((fwl * 100).round());
    if (sdl > 0) sdlCents.increment((sdl * 100).round());
    if (otherDeductions > 0) otherDeductionsCents.increment((otherDeductions * 100).round());
    
    // Initialize net calculations
    totalDeductionsCents = PNCounter(nodeId);
    netPayCents = PNCounter(nodeId);
    
    // Initialize CPF account allocations
    ordinaryAccountCents = PNCounter(nodeId);
    specialAccountCents = PNCounter(nodeId);
    medisaveAccountCents = PNCounter(nodeId);
    
    // Initialize make-up contributions
    makeupContributionsCents = PNCounter(nodeId);
    lastMakeupDate = LWWRegister(null, createdAt);
    
    // Initialize CPF interest
    cpfInterestRate = LWWRegister(0.025, createdAt); // Default 2.5%
    cpfInterestEarnedCents = PNCounter(nodeId);
    
    // Initialize metadata
    metadata = LWWRegister(payrollMetadata, createdAt);
  }
  
  /// Get gross wage in dollars
  double get grossWage => grossWageCents.value / 100.0;
  
  /// Get net pay in dollars
  double get netPay => netPayCents.value / 100.0;
  
  /// Get total CPF in dollars
  double get totalCpf => totalCpfCents.value / 100.0;
  
  /// Get total SHG in dollars
  double get totalShg => totalShgCents.value / 100.0;
  
  /// Calculate comprehensive payroll
  void calculatePayroll(HLCTimestamp timestamp) {
    // Reset all calculated values
    _resetCalculatedValues();
    
    // Calculate wage totals
    _calculateWageTotals();
    
    // Calculate CPF contributions
    _calculateCpfContributions();
    
    // Calculate SHG contributions
    _calculateShgContributions();
    
    // Calculate total deductions
    _calculateTotalDeductions();
    
    // Calculate net pay
    _calculateNetPay();
    
    // Allocate CPF to accounts
    _allocateCpfToAccounts();
    
    calculationStatus.setValue('calculated', timestamp);
    _updateTimestamp(timestamp);
  }
  
  void _resetCalculatedValues() {
    ordinaryWageCents.reset();
    additionalWageCents.reset();
    grossWageCents.reset();
    
    employeeCpfCents.reset();
    employerCpfCents.reset();
    totalCpfCents.reset();
    
    cdacCents.reset();
    ecfCents.reset();
    mbmfCents.reset();
    sindaCents.reset();
    totalShgCents.reset();
    
    totalDeductionsCents.reset();
    netPayCents.reset();
    
    ordinaryAccountCents.reset();
    specialAccountCents.reset();
    medisaveAccountCents.reset();
  }
  
  void _calculateWageTotals() {
    // Ordinary wage = basic + overtime + allowances
    final ordinaryWage = basicSalaryCents.value + overtimeCents.value + allowancesCents.value;
    if (ordinaryWage > 0) ordinaryWageCents.increment(ordinaryWage);
    
    // Additional wage = commission + bonus + benefits in kind
    final additionalWage = commissionCents.value + bonusCents.value + benefitsInKindCents.value;
    if (additionalWage > 0) additionalWageCents.increment(additionalWage);
    
    // Gross wage
    final gross = ordinaryWage + additionalWage;
    if (gross > 0) grossWageCents.increment(gross);
  }
  
  void _calculateCpfContributions() {
    try {
      final ageCat = CpfAgeCategory.values.firstWhere(
        (e) => e.toString().split('.').last == ageCategory.value
      );
      final residency = SgResidencyStatus.values.firstWhere(
        (e) => e.toString().split('.').last == residencyStatus.value
      );
      
      final rates = CpfContributionRates.getCpfRates(ageCat, residency);
      
      // Apply ceiling to ordinary wage
      final owCeiling = CpfContributionRates.ordinaryWageCeiling * 100; // Convert to cents
      final cappedOW = ordinaryWageCents.value > owCeiling ? owCeiling : ordinaryWageCents.value;
      
      // Calculate contributions
      final empContrib = (cappedOW * rates['employee']!).round();
      final emplerContrib = (cappedOW * rates['employer']!).round();
      
      if (empContrib > 0) employeeCpfCents.increment(empContrib);
      if (emplerContrib > 0) employerCpfCents.increment(emplerContrib);
      if (empContrib + emplerContrib > 0) totalCpfCents.increment(empContrib + emplerContrib);
      
    } catch (e) {
      // Handle invalid enum values gracefully
    }
  }
  
  void _calculateShgContributions() {
    if (ethnicity.value == null) return;
    
    final eligibleSHG = SelfHelpGroupRates.getEligibleSHG(ethnicity.value!);
    
    for (final shg in eligibleSHG) {
      final rate = SelfHelpGroupRates.monthlyRates[shg] ?? 0.0;
      final contributionCents = (rate * 100).round();
      
      switch (shg) {
        case SelfHelpGroupType.cdac:
          if (contributionCents > 0) cdacCents.increment(contributionCents);
          break;
        case SelfHelpGroupType.ecf:
          if (contributionCents > 0) ecfCents.increment(contributionCents);
          break;
        case SelfHelpGroupType.mbmf:
          if (contributionCents > 0) mbmfCents.increment(contributionCents);
          break;
        case SelfHelpGroupType.sinda:
          if (contributionCents > 0) sindaCents.increment(contributionCents);
          break;
      }
    }
    
    final totalShg = cdacCents.value + ecfCents.value + mbmfCents.value + sindaCents.value;
    if (totalShg > 0) totalShgCents.increment(totalShg);
  }
  
  void _calculateTotalDeductions() {
    final totalDed = employeeCpfCents.value + totalShgCents.value + 
                    incomeTaxCents.value + otherDeductionsCents.value;
    if (totalDed > 0) totalDeductionsCents.increment(totalDed);
  }
  
  void _calculateNetPay() {
    final net = grossWageCents.value - totalDeductionsCents.value;
    if (net > 0) netPayCents.increment(net);
  }
  
  void _allocateCpfToAccounts() {
    final totalCpf = totalCpfCents.value;
    if (totalCpf <= 0) return;
    
    // Standard allocation percentages (can be customized based on age)
    final ordinatyPercent = 0.6283; // ~62.83%
    final specialPercent = 0.1717;  // ~17.17%
    final medisavePercent = 0.20;   // 20%
    
    final ordinary = (totalCpf * ordinatyPercent).round();
    final special = (totalCpf * specialPercent).round();
    final medisave = (totalCpf * medisavePercent).round();
    
    if (ordinary > 0) ordinaryAccountCents.increment(ordinary);
    if (special > 0) specialAccountCents.increment(special);
    if (medisave > 0) medisaveAccountCents.increment(medisave);
  }
  
  /// Record make-up contribution
  void recordMakeupContribution(double amount, DateTime contributionDate, HLCTimestamp timestamp) {
    if (amount > 0) {
      makeupContributionsCents.increment((amount * 100).round());
    }
    lastMakeupDate.setValue(contributionDate, timestamp);
    _updateTimestamp(timestamp);
  }
  
  /// Calculate CPF refund for excess contributions
  void calculateCpfRefund(double annualWages, HLCTimestamp timestamp) {
    final annualCeiling = CpfContributionRates.additionalWageCeiling;
    if (annualWages > annualCeiling) {
      final excessWages = annualWages - annualCeiling;
      // Assuming 20% employee rate for excess calculation
      final refund = (excessWages * 0.20 * 100).round();
      
      cpfRefundCents.reset();
      if (refund > 0) cpfRefundCents.increment(refund);
    }
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
    if (other is! CRDTEnhancedPayrollCalculation || other.id != id) {
      throw ArgumentError('Cannot merge with different payroll calculation');
    }
    
    // Merge all CRDT fields - basic info
    employeeId.mergeWith(other.employeeId);
    payrollPeriod.mergeWith(other.payrollPeriod);
    calculationDate.mergeWith(other.calculationDate);
    calculationStatus.mergeWith(other.calculationStatus);
    
    // Employee classification
    ageCategory.mergeWith(other.ageCategory);
    residencyStatus.mergeWith(other.residencyStatus);
    workPassType.mergeWith(other.workPassType);
    ethnicity.mergeWith(other.ethnicity);
    
    // Wage components
    basicSalaryCents.mergeWith(other.basicSalaryCents);
    overtimeCents.mergeWith(other.overtimeCents);
    allowancesCents.mergeWith(other.allowancesCents);
    commissionCents.mergeWith(other.commissionCents);
    bonusCents.mergeWith(other.bonusCents);
    benefitsInKindCents.mergeWith(other.benefitsInKindCents);
    
    // Total wages
    ordinaryWageCents.mergeWith(other.ordinaryWageCents);
    additionalWageCents.mergeWith(other.additionalWageCents);
    grossWageCents.mergeWith(other.grossWageCents);
    
    // CPF calculations
    employeeCpfCents.mergeWith(other.employeeCpfCents);
    employerCpfCents.mergeWith(other.employerCpfCents);
    totalCpfCents.mergeWith(other.totalCpfCents);
    cpfRefundCents.mergeWith(other.cpfRefundCents);
    
    // SHG contributions
    cdacCents.mergeWith(other.cdacCents);
    ecfCents.mergeWith(other.ecfCents);
    mbmfCents.mergeWith(other.mbmfCents);
    sindaCents.mergeWith(other.sindaCents);
    totalShgCents.mergeWith(other.totalShgCents);
    
    // Other deductions
    incomeTaxCents.mergeWith(other.incomeTaxCents);
    fwlCents.mergeWith(other.fwlCents);
    sdlCents.mergeWith(other.sdlCents);
    otherDeductionsCents.mergeWith(other.otherDeductionsCents);
    
    // Net calculations
    totalDeductionsCents.mergeWith(other.totalDeductionsCents);
    netPayCents.mergeWith(other.netPayCents);
    
    // CPF account allocations
    ordinaryAccountCents.mergeWith(other.ordinaryAccountCents);
    specialAccountCents.mergeWith(other.specialAccountCents);
    medisaveAccountCents.mergeWith(other.medisaveAccountCents);
    
    // Make-up contributions
    makeupContributionsCents.mergeWith(other.makeupContributionsCents);
    lastMakeupDate.mergeWith(other.lastMakeupDate);
    
    // CPF interest
    cpfInterestRate.mergeWith(other.cpfInterestRate);
    cpfInterestEarnedCents.mergeWith(other.cpfInterestEarnedCents);
    
    // Metadata
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
      'payroll_period': payrollPeriod.value,
      'calculation_date': calculationDate.value.millisecondsSinceEpoch,
      'calculation_status': calculationStatus.value,
      'age_category': ageCategory.value,
      'residency_status': residencyStatus.value,
      'work_pass_type': workPassType.value,
      'ethnicity': ethnicity.value,
      'basic_salary': basicSalaryCents.value / 100.0,
      'overtime': overtimeCents.value / 100.0,
      'allowances': allowancesCents.value / 100.0,
      'commission': commissionCents.value / 100.0,
      'bonus': bonusCents.value / 100.0,
      'benefits_in_kind': benefitsInKindCents.value / 100.0,
      'ordinary_wage': ordinaryWageCents.value / 100.0,
      'additional_wage': additionalWageCents.value / 100.0,
      'gross_wage': grossWage,
      'employee_cpf': employeeCpfCents.value / 100.0,
      'employer_cpf': employerCpfCents.value / 100.0,
      'total_cpf': totalCpf,
      'cpf_refund': cpfRefundCents.value / 100.0,
      'cdac': cdacCents.value / 100.0,
      'ecf': ecfCents.value / 100.0,
      'mbmf': mbmfCents.value / 100.0,
      'sinda': sindaCents.value / 100.0,
      'total_shg': totalShg,
      'income_tax': incomeTaxCents.value / 100.0,
      'fwl': fwlCents.value / 100.0,
      'sdl': sdlCents.value / 100.0,
      'other_deductions': otherDeductionsCents.value / 100.0,
      'total_deductions': totalDeductionsCents.value / 100.0,
      'net_pay': netPay,
      'ordinary_account': ordinaryAccountCents.value / 100.0,
      'special_account': specialAccountCents.value / 100.0,
      'medisave_account': medisaveAccountCents.value / 100.0,
      'makeup_contributions': makeupContributionsCents.value / 100.0,
      'last_makeup_date': lastMakeupDate.value?.millisecondsSinceEpoch,
      'cpf_interest_rate': cpfInterestRate.value,
      'cpf_interest_earned': cpfInterestEarnedCents.value / 100.0,
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
      'payroll_period': payrollPeriod.toJson(),
      'calculation_date': calculationDate.toJson(),
      'calculation_status': calculationStatus.toJson(),
      'age_category': ageCategory.toJson(),
      'residency_status': residencyStatus.toJson(),
      'work_pass_type': workPassType.toJson(),
      'ethnicity': ethnicity.toJson(),
      'basic_salary_cents': basicSalaryCents.toJson(),
      'overtime_cents': overtimeCents.toJson(),
      'allowances_cents': allowancesCents.toJson(),
      'commission_cents': commissionCents.toJson(),
      'bonus_cents': bonusCents.toJson(),
      'benefits_in_kind_cents': benefitsInKindCents.toJson(),
      'ordinary_wage_cents': ordinaryWageCents.toJson(),
      'additional_wage_cents': additionalWageCents.toJson(),
      'gross_wage_cents': grossWageCents.toJson(),
      'employee_cpf_cents': employeeCpfCents.toJson(),
      'employer_cpf_cents': employerCpfCents.toJson(),
      'total_cpf_cents': totalCpfCents.toJson(),
      'cpf_refund_cents': cpfRefundCents.toJson(),
      'cdac_cents': cdacCents.toJson(),
      'ecf_cents': ecfCents.toJson(),
      'mbmf_cents': mbmfCents.toJson(),
      'sinda_cents': sindaCents.toJson(),
      'total_shg_cents': totalShgCents.toJson(),
      'income_tax_cents': incomeTaxCents.toJson(),
      'fwl_cents': fwlCents.toJson(),
      'sdl_cents': sdlCents.toJson(),
      'other_deductions_cents': otherDeductionsCents.toJson(),
      'total_deductions_cents': totalDeductionsCents.toJson(),
      'net_pay_cents': netPayCents.toJson(),
      'ordinary_account_cents': ordinaryAccountCents.toJson(),
      'special_account_cents': specialAccountCents.toJson(),
      'medisave_account_cents': medisaveAccountCents.toJson(),
      'makeup_contributions_cents': makeupContributionsCents.toJson(),
      'last_makeup_date': lastMakeupDate.toJson(),
      'cpf_interest_rate': cpfInterestRate.toJson(),
      'cpf_interest_earned_cents': cpfInterestEarnedCents.toJson(),
      'metadata': metadata.toJson(),
    };
  }
}