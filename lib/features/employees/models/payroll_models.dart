import 'dart:convert';
import '../../../core/crdt/hybrid_logical_clock.dart';
import '../../../core/crdt/vector_clock.dart';
import '../../../core/crdt/crdt_types.dart';
import '../../../core/crdt/lww_register.dart';
import '../../../core/crdt/pn_counter.dart';
import '../../../core/crdt/or_set.dart';
import '../../../core/database/crdt_models.dart';

/// Payroll period enumeration
enum PayrollPeriod {
  monthly,
  biWeekly,
  weekly,
  daily
}

/// Pay component type enumeration
enum PayComponentType {
  basic,          // Basic salary
  allowance,      // Housing, transport, meal allowances
  overtime,       // Overtime pay
  bonus,          // Performance bonus, year-end bonus
  commission,     // Sales commission
  reimbursement,  // Expense reimbursement
  cpfEmployer,    // Employer CPF contribution
  cpfEmployee,    // Employee CPF contribution
  sdl,            // Skills Development Levy
  fwl,            // Foreign Worker Levy
  deduction,      // Other deductions
  tax,            // Income tax
  insurance,      // Insurance premiums
  other           // Other components
}

/// CPF contribution rates for different age groups
class CpfRates {
  static const Map<String, Map<String, double>> rates = {
    'citizen_pr': {
      'employee_rate_50': 0.20,   // Employee rate for age 50 and below
      'employer_rate_50': 0.17,   // Employer rate for age 50 and below
      'employee_rate_55': 0.135,  // Employee rate for age 55-60
      'employer_rate_55': 0.135,  // Employer rate for age 55-60
      'employee_rate_60': 0.075,  // Employee rate for age 60-65
      'employer_rate_60': 0.090,  // Employer rate for age 60-65
      'employee_rate_65': 0.050,  // Employee rate for age 65 and above
      'employer_rate_65': 0.075,  // Employer rate for age 65 and above
    },
    'sph': { // Singapore Permanent Resident first 2 years
      'employee_rate': 0.05,
      'employer_rate': 0.17,
    }
  };
  
  static const double ordinaryWageCeiling = 6000.0;  // Monthly OW ceiling
  static const double additionalWageCeiling = 102000.0; // Annual AW ceiling
  static const double sdlRate = 0.0025; // 0.25% of monthly wages
  static const double sdlCeiling = 4500.0; // SDL ceiling
}

/// CRDT-enabled Payroll Record model
class CRDTPayrollRecord implements CRDTModel {
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
  
  // Basic payroll information
  late LWWRegister<String> employeeId;
  late LWWRegister<String> payrollNumber;
  late LWWRegister<DateTime> payPeriodStart;
  late LWWRegister<DateTime> payPeriodEnd;
  late LWWRegister<DateTime> payDate;
  late LWWRegister<String> status; // draft, approved, paid, cancelled
  late LWWRegister<String> payrollPeriod; // monthly, bi_weekly, weekly
  
  // Salary components as G-Counters (amounts in cents)
  late PNCounter basicSalaryCents;
  late PNCounter allowancesCents;
  late PNCounter overtimeCents;
  late PNCounter bonusCents;
  late PNCounter commissionCents;
  late PNCounter reimbursementCents;
  
  // Singapore-specific contributions
  late PNCounter cpfEmployeeCents;
  late PNCounter cpfEmployerCents;
  late PNCounter sdlCents;
  late PNCounter fwlCents;
  
  // Deductions
  late PNCounter taxDeductionCents;
  late PNCounter insuranceDeductionCents;
  late PNCounter otherDeductionsCents;
  
  // Working hours and overtime
  late LWWRegister<double> regularHours;
  late LWWRegister<double> overtimeHours;
  late LWWRegister<double> doubleTimeHours;
  late LWWRegister<double> hourlyRate;
  late LWWRegister<double> overtimeRate;
  
  // Leave information
  late LWWRegister<int> annualLeaveTaken;
  late LWWRegister<int> sickLeaveTaken;
  late LWWRegister<int> maternityLeaveTaken;
  late LWWRegister<int> paternityLeaveTaken;
  late LWWRegister<int> unpaidLeaveTaken;
  
  // Additional information
  late LWWRegister<String?> bankAccount;
  late LWWRegister<String?> bankCode;
  late LWWRegister<String?> notes;
  late LWWRegister<Map<String, dynamic>?> metadata;
  
  // Pay components as OR-Set for tracking individual components
  late ORSet<String> payComponentIds;
  
  CRDTPayrollRecord({
    required this.id,
    required this.nodeId,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required String empId,
    required String payrollNum,
    required DateTime periodStart,
    required DateTime periodEnd,
    required DateTime paymentDate,
    String payrollStatus = 'draft',
    String period = 'monthly',
    double basic = 0.0,
    double allowances = 0.0,
    double overtime = 0.0,
    double bonus = 0.0,
    double commission = 0.0,
    double reimbursement = 0.0,
    double cpfEmployee = 0.0,
    double cpfEmployer = 0.0,
    double sdl = 0.0,
    double fwl = 0.0,
    double taxDeduction = 0.0,
    double insuranceDeduction = 0.0,
    double otherDeductions = 0.0,
    double regHours = 0.0,
    double otHours = 0.0,
    double dtHours = 0.0,
    double hRate = 0.0,
    double otRate = 0.0,
    int annualLeave = 0,
    int sickLeave = 0,
    int maternityLeave = 0,
    int paternityLeave = 0,
    int unpaidLeave = 0,
    String? account,
    String? bank,
    String? payrollNotes,
    Map<String, dynamic>? payrollMetadata,
    this.isDeleted = false,
  }) {
    // Initialize basic information
    employeeId = LWWRegister(empId, createdAt);
    payrollNumber = LWWRegister(payrollNum, createdAt);
    payPeriodStart = LWWRegister(periodStart, createdAt);
    payPeriodEnd = LWWRegister(periodEnd, createdAt);
    payDate = LWWRegister(paymentDate, createdAt);
    status = LWWRegister(payrollStatus, createdAt);
    payrollPeriod = LWWRegister(period, createdAt);
    
    // Initialize salary components (convert to cents)
    basicSalaryCents = PNCounter(nodeId);
    allowancesCents = PNCounter(nodeId);
    overtimeCents = PNCounter(nodeId);
    bonusCents = PNCounter(nodeId);
    commissionCents = PNCounter(nodeId);
    reimbursementCents = PNCounter(nodeId);
    
    // Initialize contributions
    cpfEmployeeCents = PNCounter(nodeId);
    cpfEmployerCents = PNCounter(nodeId);
    sdlCents = PNCounter(nodeId);
    fwlCents = PNCounter(nodeId);
    
    // Initialize deductions
    taxDeductionCents = PNCounter(nodeId);
    insuranceDeductionCents = PNCounter(nodeId);
    otherDeductionsCents = PNCounter(nodeId);
    
    // Set initial values (convert to cents)
    if (basic > 0) basicSalaryCents.increment((basic * 100).round());
    if (allowances > 0) allowancesCents.increment((allowances * 100).round());
    if (overtime > 0) overtimeCents.increment((overtime * 100).round());
    if (bonus > 0) bonusCents.increment((bonus * 100).round());
    if (commission > 0) commissionCents.increment((commission * 100).round());
    if (reimbursement > 0) reimbursementCents.increment((reimbursement * 100).round());
    if (cpfEmployee > 0) cpfEmployeeCents.increment((cpfEmployee * 100).round());
    if (cpfEmployer > 0) cpfEmployerCents.increment((cpfEmployer * 100).round());
    if (sdl > 0) sdlCents.increment((sdl * 100).round());
    if (fwl > 0) fwlCents.increment((fwl * 100).round());
    if (taxDeduction > 0) taxDeductionCents.increment((taxDeduction * 100).round());
    if (insuranceDeduction > 0) insuranceDeductionCents.increment((insuranceDeduction * 100).round());
    if (otherDeductions > 0) otherDeductionsCents.increment((otherDeductions * 100).round());
    
    // Initialize working hours
    regularHours = LWWRegister(regHours, createdAt);
    overtimeHours = LWWRegister(otHours, createdAt);
    doubleTimeHours = LWWRegister(dtHours, createdAt);
    hourlyRate = LWWRegister(hRate, createdAt);
    overtimeRate = LWWRegister(otRate, createdAt);
    
    // Initialize leave information
    annualLeaveTaken = LWWRegister(annualLeave, createdAt);
    sickLeaveTaken = LWWRegister(sickLeave, createdAt);
    maternityLeaveTaken = LWWRegister(maternityLeave, createdAt);
    paternityLeaveTaken = LWWRegister(paternityLeave, createdAt);
    unpaidLeaveTaken = LWWRegister(unpaidLeave, createdAt);
    
    // Initialize additional information
    bankAccount = LWWRegister(account, createdAt);
    bankCode = LWWRegister(bank, createdAt);
    notes = LWWRegister(payrollNotes, createdAt);
    metadata = LWWRegister(payrollMetadata, createdAt);
    
    // Initialize pay components
    payComponentIds = ORSet(nodeId);
  }
  
  /// Get gross pay in dollars
  double get grossPay {
    return (basicSalaryCents.value + 
            allowancesCents.value + 
            overtimeCents.value + 
            bonusCents.value + 
            commissionCents.value + 
            reimbursementCents.value) / 100.0;
  }
  
  /// Get total CPF contributions in dollars
  double get totalCpfContributions {
    return (cpfEmployeeCents.value + cpfEmployerCents.value) / 100.0;
  }
  
  /// Get total deductions in dollars
  double get totalDeductions {
    return (cpfEmployeeCents.value + 
            taxDeductionCents.value + 
            insuranceDeductionCents.value + 
            otherDeductionsCents.value) / 100.0;
  }
  
  /// Get net pay in dollars
  double get netPay {
    return grossPay - totalDeductions;
  }
  
  /// Get employer costs in dollars (gross pay + employer contributions)
  double get employerCosts {
    return grossPay + 
           (cpfEmployerCents.value + sdlCents.value + fwlCents.value) / 100.0;
  }
  
  /// Get total leave days taken
  int get totalLeaveTaken {
    return annualLeaveTaken.value + 
           sickLeaveTaken.value + 
           maternityLeaveTaken.value + 
           paternityLeaveTaken.value + 
           unpaidLeaveTaken.value;
  }
  
  /// Update payroll status
  void updateStatus(String newStatus, HLCTimestamp timestamp) {
    status.setValue(newStatus, timestamp);
    _updateTimestamp(timestamp);
  }
  
  /// Update salary components
  void updateSalaryComponents({
    double? basicSalary,
    double? allowances,
    double? overtime,
    double? bonus,
    double? commission,
    double? reimbursement,
    required HLCTimestamp timestamp,
  }) {
    if (basicSalary != null) {
      basicSalaryCents.reset();
      basicSalaryCents.increment((basicSalary * 100).round());
    }
    if (allowances != null) {
      allowancesCents.reset();
      allowancesCents.increment((allowances * 100).round());
    }
    if (overtime != null) {
      overtimeCents.reset();
      overtimeCents.increment((overtime * 100).round());
    }
    if (bonus != null) {
      bonusCents.reset();
      bonusCents.increment((bonus * 100).round());
    }
    if (commission != null) {
      commissionCents.reset();
      commissionCents.increment((commission * 100).round());
    }
    if (reimbursement != null) {
      reimbursementCents.reset();
      reimbursementCents.increment((reimbursement * 100).round());
    }
    _updateTimestamp(timestamp);
  }
  
  /// Update CPF contributions
  void updateCpfContributions({
    double? employeeContribution,
    double? employerContribution,
    required HLCTimestamp timestamp,
  }) {
    if (employeeContribution != null) {
      cpfEmployeeCents.reset();
      cpfEmployeeCents.increment((employeeContribution * 100).round());
    }
    if (employerContribution != null) {
      cpfEmployerCents.reset();
      cpfEmployerCents.increment((employerContribution * 100).round());
    }
    _updateTimestamp(timestamp);
  }
  
  /// Update Singapore levies
  void updateLevies({
    double? sdlAmount,
    double? fwlAmount,
    required HLCTimestamp timestamp,
  }) {
    if (sdlAmount != null) {
      sdlCents.reset();
      sdlCents.increment((sdlAmount * 100).round());
    }
    if (fwlAmount != null) {
      fwlCents.reset();
      fwlCents.increment((fwlAmount * 100).round());
    }
    _updateTimestamp(timestamp);
  }
  
  /// Update deductions
  void updateDeductions({
    double? taxDeduction,
    double? insuranceDeduction,
    double? otherDeductions,
    required HLCTimestamp timestamp,
  }) {
    if (taxDeduction != null) {
      taxDeductionCents.reset();
      taxDeductionCents.increment((taxDeduction * 100).round());
    }
    if (insuranceDeduction != null) {
      insuranceDeductionCents.reset();
      insuranceDeductionCents.increment((insuranceDeduction * 100).round());
    }
    if (otherDeductions != null) {
      otherDeductionsCents.reset();
      otherDeductionsCents.increment((otherDeductions * 100).round());
    }
    _updateTimestamp(timestamp);
  }
  
  /// Update working hours
  void updateWorkingHours({
    double? regular,
    double? overtime,
    double? doubleTime,
    double? hourlyRateAmount,
    double? overtimeRateAmount,
    required HLCTimestamp timestamp,
  }) {
    if (regular != null) regularHours.setValue(regular, timestamp);
    if (overtime != null) overtimeHours.setValue(overtime, timestamp);
    if (doubleTime != null) doubleTimeHours.setValue(doubleTime, timestamp);
    if (hourlyRateAmount != null) hourlyRate.setValue(hourlyRateAmount, timestamp);
    if (overtimeRateAmount != null) overtimeRate.setValue(overtimeRateAmount, timestamp);
    _updateTimestamp(timestamp);
  }
  
  /// Update leave information
  void updateLeaveInformation({
    int? annualLeave,
    int? sickLeave,
    int? maternityLeave,
    int? paternityLeave,
    int? unpaidLeave,
    required HLCTimestamp timestamp,
  }) {
    if (annualLeave != null) annualLeaveTaken.setValue(annualLeave, timestamp);
    if (sickLeave != null) sickLeaveTaken.setValue(sickLeave, timestamp);
    if (maternityLeave != null) maternityLeaveTaken.setValue(maternityLeave, timestamp);
    if (paternityLeave != null) paternityLeaveTaken.setValue(paternityLeave, timestamp);
    if (unpaidLeave != null) unpaidLeaveTaken.setValue(unpaidLeave, timestamp);
    _updateTimestamp(timestamp);
  }
  
  /// Add pay component
  void addPayComponent(String componentId) {
    payComponentIds.add(componentId);
  }
  
  /// Remove pay component
  void removePayComponent(String componentId) {
    payComponentIds.remove(componentId);
  }
  
  void _updateTimestamp(HLCTimestamp timestamp) {
    if (timestamp.happensAfter(updatedAt)) {
      updatedAt = timestamp;
      version = version.tick();
    }
  }
  
  @override
  void mergeWith(CRDTModel other) {
    if (other is! CRDTPayrollRecord || other.id != id) {
      throw ArgumentError('Cannot merge with different payroll record');
    }
    
    // Merge all CRDT fields
    employeeId.mergeWith(other.employeeId);
    payrollNumber.mergeWith(other.payrollNumber);
    payPeriodStart.mergeWith(other.payPeriodStart);
    payPeriodEnd.mergeWith(other.payPeriodEnd);
    payDate.mergeWith(other.payDate);
    status.mergeWith(other.status);
    payrollPeriod.mergeWith(other.payrollPeriod);
    
    basicSalaryCents.mergeWith(other.basicSalaryCents);
    allowancesCents.mergeWith(other.allowancesCents);
    overtimeCents.mergeWith(other.overtimeCents);
    bonusCents.mergeWith(other.bonusCents);
    commissionCents.mergeWith(other.commissionCents);
    reimbursementCents.mergeWith(other.reimbursementCents);
    
    cpfEmployeeCents.mergeWith(other.cpfEmployeeCents);
    cpfEmployerCents.mergeWith(other.cpfEmployerCents);
    sdlCents.mergeWith(other.sdlCents);
    fwlCents.mergeWith(other.fwlCents);
    
    taxDeductionCents.mergeWith(other.taxDeductionCents);
    insuranceDeductionCents.mergeWith(other.insuranceDeductionCents);
    otherDeductionsCents.mergeWith(other.otherDeductionsCents);
    
    regularHours.mergeWith(other.regularHours);
    overtimeHours.mergeWith(other.overtimeHours);
    doubleTimeHours.mergeWith(other.doubleTimeHours);
    hourlyRate.mergeWith(other.hourlyRate);
    overtimeRate.mergeWith(other.overtimeRate);
    
    annualLeaveTaken.mergeWith(other.annualLeaveTaken);
    sickLeaveTaken.mergeWith(other.sickLeaveTaken);
    maternityLeaveTaken.mergeWith(other.maternityLeaveTaken);
    paternityLeaveTaken.mergeWith(other.paternityLeaveTaken);
    unpaidLeaveTaken.mergeWith(other.unpaidLeaveTaken);
    
    bankAccount.mergeWith(other.bankAccount);
    bankCode.mergeWith(other.bankCode);
    notes.mergeWith(other.notes);
    metadata.mergeWith(other.metadata);
    
    payComponentIds.mergeWith(other.payComponentIds);
    
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
      'payroll_number': payrollNumber.value,
      'pay_period_start': payPeriodStart.value.millisecondsSinceEpoch,
      'pay_period_end': payPeriodEnd.value.millisecondsSinceEpoch,
      'pay_date': payDate.value.millisecondsSinceEpoch,
      'status': status.value,
      'payroll_period': payrollPeriod.value,
      'basic_salary': basicSalaryCents.value / 100.0,
      'allowances': allowancesCents.value / 100.0,
      'overtime': overtimeCents.value / 100.0,
      'bonus': bonusCents.value / 100.0,
      'commission': commissionCents.value / 100.0,
      'reimbursement': reimbursementCents.value / 100.0,
      'gross_pay': grossPay,
      'cpf_employee': cpfEmployeeCents.value / 100.0,
      'cpf_employer': cpfEmployerCents.value / 100.0,
      'total_cpf_contributions': totalCpfContributions,
      'sdl': sdlCents.value / 100.0,
      'fwl': fwlCents.value / 100.0,
      'tax_deduction': taxDeductionCents.value / 100.0,
      'insurance_deduction': insuranceDeductionCents.value / 100.0,
      'other_deductions': otherDeductionsCents.value / 100.0,
      'total_deductions': totalDeductions,
      'net_pay': netPay,
      'employer_costs': employerCosts,
      'regular_hours': regularHours.value,
      'overtime_hours': overtimeHours.value,
      'double_time_hours': doubleTimeHours.value,
      'hourly_rate': hourlyRate.value,
      'overtime_rate': overtimeRate.value,
      'annual_leave_taken': annualLeaveTaken.value,
      'sick_leave_taken': sickLeaveTaken.value,
      'maternity_leave_taken': maternityLeaveTaken.value,
      'paternity_leave_taken': paternityLeaveTaken.value,
      'unpaid_leave_taken': unpaidLeaveTaken.value,
      'total_leave_taken': totalLeaveTaken,
      'bank_account': bankAccount.value,
      'bank_code': bankCode.value,
      'notes': notes.value,
      'metadata': metadata.value,
      'pay_component_ids': payComponentIds.elements.toList(),
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
      'payroll_number': payrollNumber.toJson(),
      'pay_period_start': payPeriodStart.toJson(),
      'pay_period_end': payPeriodEnd.toJson(),
      'pay_date': payDate.toJson(),
      'status': status.toJson(),
      'payroll_period': payrollPeriod.toJson(),
      'basic_salary_cents': basicSalaryCents.toJson(),
      'allowances_cents': allowancesCents.toJson(),
      'overtime_cents': overtimeCents.toJson(),
      'bonus_cents': bonusCents.toJson(),
      'commission_cents': commissionCents.toJson(),
      'reimbursement_cents': reimbursementCents.toJson(),
      'cpf_employee_cents': cpfEmployeeCents.toJson(),
      'cpf_employer_cents': cpfEmployerCents.toJson(),
      'sdl_cents': sdlCents.toJson(),
      'fwl_cents': fwlCents.toJson(),
      'tax_deduction_cents': taxDeductionCents.toJson(),
      'insurance_deduction_cents': insuranceDeductionCents.toJson(),
      'other_deductions_cents': otherDeductionsCents.toJson(),
      'regular_hours': regularHours.toJson(),
      'overtime_hours': overtimeHours.toJson(),
      'double_time_hours': doubleTimeHours.toJson(),
      'hourly_rate': hourlyRate.toJson(),
      'overtime_rate': overtimeRate.toJson(),
      'annual_leave_taken': annualLeaveTaken.toJson(),
      'sick_leave_taken': sickLeaveTaken.toJson(),
      'maternity_leave_taken': maternityLeaveTaken.toJson(),
      'paternity_leave_taken': paternityLeaveTaken.toJson(),
      'unpaid_leave_taken': unpaidLeaveTaken.toJson(),
      'bank_account': bankAccount.toJson(),
      'bank_code': bankCode.toJson(),
      'notes': notes.toJson(),
      'metadata': metadata.toJson(),
      'pay_component_ids': payComponentIds.toJson(),
    };
  }
}

/// CRDT-enabled Pay Component model for detailed payroll breakdown
class CRDTPayComponent implements CRDTModel {
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
  
  late LWWRegister<String> payrollRecordId;
  late LWWRegister<String> componentType; // basic, allowance, overtime, etc.
  late LWWRegister<String> componentName;
  late LWWRegister<String?> description;
  late PNCounter amountCents; // Amount in cents
  late LWWRegister<bool> isTaxable;
  late LWWRegister<bool> isCpfable;
  late LWWRegister<String?> reference;
  late LWWRegister<Map<String, dynamic>?> metadata;
  
  CRDTPayComponent({
    required this.id,
    required this.nodeId,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required String payrollId,
    required String type,
    required String name,
    String? desc,
    double amount = 0.0,
    bool taxable = true,
    bool cpfable = true,
    String? ref,
    Map<String, dynamic>? componentMetadata,
    this.isDeleted = false,
  }) {
    payrollRecordId = LWWRegister(payrollId, createdAt);
    componentType = LWWRegister(type, createdAt);
    componentName = LWWRegister(name, createdAt);
    description = LWWRegister(desc, createdAt);
    amountCents = PNCounter(nodeId);
    isTaxable = LWWRegister(taxable, createdAt);
    isCpfable = LWWRegister(cpfable, createdAt);
    reference = LWWRegister(ref, createdAt);
    metadata = LWWRegister(componentMetadata, createdAt);
    
    // Set initial amount
    if (amount > 0) {
      amountCents.increment((amount * 100).round());
    }
  }
  
  /// Get amount in dollars
  double get amount => amountCents.value / 100.0;
  
  /// Update amount
  void updateAmount(double newAmount, HLCTimestamp timestamp) {
    amountCents.reset();
    if (newAmount > 0) {
      amountCents.increment((newAmount * 100).round());
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
    if (other is! CRDTPayComponent || other.id != id) {
      throw ArgumentError('Cannot merge with different pay component');
    }
    
    payrollRecordId.mergeWith(other.payrollRecordId);
    componentType.mergeWith(other.componentType);
    componentName.mergeWith(other.componentName);
    description.mergeWith(other.description);
    amountCents.mergeWith(other.amountCents);
    isTaxable.mergeWith(other.isTaxable);
    isCpfable.mergeWith(other.isCpfable);
    reference.mergeWith(other.reference);
    metadata.mergeWith(other.metadata);
    
    version = version.update(other.version);
    if (other.updatedAt.happensAfter(updatedAt)) {
      updatedAt = other.updatedAt;
    }
    
    isDeleted = isDeleted || other.isDeleted;
  }
  
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'payroll_record_id': payrollRecordId.value,
      'component_type': componentType.value,
      'component_name': componentName.value,
      'description': description.value,
      'amount': amount,
      'is_taxable': isTaxable.value,
      'is_cpfable': isCpfable.value,
      'reference': reference.value,
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
      'payroll_record_id': payrollRecordId.toJson(),
      'component_type': componentType.toJson(),
      'component_name': componentName.toJson(),
      'description': description.toJson(),
      'amount_cents': amountCents.toJson(),
      'is_taxable': isTaxable.toJson(),
      'is_cpfable': isCpfable.toJson(),
      'reference': reference.toJson(),
      'metadata': metadata.toJson(),
    };
  }
}