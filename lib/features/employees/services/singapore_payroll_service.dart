import 'dart:async';
import 'dart:math';
import '../../../core/crdt/hybrid_logical_clock.dart';
import '../../../core/crdt/vector_clock.dart';
import '../../../core/utils/uuid_generator.dart';
import '../models/index.dart';
import '../models/enhanced_payroll_models.dart';
import '../models/singapore_tax_models.dart';

/// Enhanced Singapore Payroll Calculation Service
/// Handles comprehensive CPF, SDL, FWL, SHG calculations according to 2024 Singapore regulations
class SingaporePayrollService {
  final String _nodeId = UuidGenerator.generateId();

  // In-memory storage for demo
  final Map<String, CRDTSingaporeCpfCalculation> _cpfCalculations = {};
  final Map<String, CRDTWorkPassManagement> _workPassRecords = {};
  final Map<String, CRDTEnhancedPayrollCalculation> _enhancedPayrolls = {};

  /// Calculate CPF contributions for an employee
  Future<CRDTSingaporeCpfCalculation> calculateCpfContributions({
    required String employeeId,
    required String payrollRecordId,
    required DateTime dateOfBirth,
    required String residencyStatus,
    required double ordinaryWage,
    required double additionalWage,
    DateTime? calculationDate,
  }) async {
    final calcDate = calculationDate ?? DateTime.now();
    final ageCategory = EmployeeUtils.getCpfAgeCategory(dateOfBirth);
    final rates = EmployeeUtils.getCpfRates(dateOfBirth, residencyStatus);

    final calculation = CRDTSingaporeCpfCalculation(
      id: UuidGenerator.generateId(),
      nodeId: _nodeId,
      createdAt: HLCTimestamp.now(_nodeId),
      updatedAt: HLCTimestamp.now(_nodeId),
      version: VectorClock(_nodeId),
      empId: employeeId,
      payrollId: payrollRecordId,
      calcDate: calcDate,
      age: ageCategory,
      residency: residencyStatus,
      ordinaryWage: ordinaryWage,
      additionalWage: additionalWage,
      empRate: rates['employee_rate'] ?? 0.0,
      emplerRate: rates['employer_rate'] ?? 0.0,
      cpfSubject: _isSubjectToCpf(residencyStatus, dateOfBirth),
    );

    // Calculate contributions
    calculation.calculateCpfContributions(HLCTimestamp.now(_nodeId));

    _cpfCalculations[calculation.id] = calculation;
    return calculation;
  }

  /// Calculate Skills Development Levy (SDL)
  double calculateSdl(double monthlyWage) {
    // SDL is 0.25% of monthly wages, capped at $4,500
    final cappedWage = min(monthlyWage, EmployeeConstants.sdlCeiling);
    return cappedWage * EmployeeConstants.sdlRate;
  }

  /// Calculate Foreign Worker Levy (FWL) using enhanced 2024 rates
  double calculateFwl({
    required String workPassType,
    required String sector,
    required String skillLevel,
  }) {
    try {
      final workPass = WorkPassType.values.firstWhere(
          (e) => e.toString().split('.').last == workPassType.toLowerCase());
      final industrySector = IndustrySector.values.firstWhere(
          (e) => e.toString().split('.').last == sector.toLowerCase());
      final skill = SkillLevel.values.firstWhere(
          (e) => e.toString().split('.').last == skillLevel.toLowerCase());

      return ForeignWorkerLevyRates.getFwlRate(industrySector, skill, workPass);
    } catch (e) {
      return 0.0; // Invalid parameters
    }
  }

  /// Create or update work pass record
  Future<CRDTWorkPassManagement> manageWorkPass({
    required String employeeId,
    required String workPassNumber,
    required String workPassType,
    required String industrySector,
    required String skillLevel,
    required DateTime passStartDate,
    required DateTime passExpiryDate,
    required String companyUen,
    required String companyName,
    required String jobDesignation,
    double basicSalary = 0.0,
    int totalEmployees = 0,
    int foreignEmployees = 0,
    Map<String, dynamic>? metadata,
  }) async {
    final timestamp = HLCTimestamp.now(_nodeId);

    final workPass = CRDTWorkPassManagement(
      id: UuidGenerator.generateId(),
      nodeId: _nodeId,
      createdAt: timestamp,
      updatedAt: timestamp,
      version: VectorClock(_nodeId),
      empId: employeeId,
      passNumber: workPassNumber,
      passType: workPassType,
      sector: industrySector,
      skill: skillLevel,
      startDate: passStartDate,
      expiryDate: passExpiryDate,
      compUen: companyUen,
      compName: companyName,
      designation: jobDesignation,
      salary: basicSalary,
      totalEmployees: totalEmployees,
      foreignEmployees: foreignEmployees,
      passMetadata: metadata,
    );

    // Calculate monthly levy
    workPass.calculateMonthlyLevy(timestamp);

    _workPassRecords[workPass.id] = workPass;
    return workPass;
  }

  /// Calculate comprehensive enhanced payroll
  Future<CRDTEnhancedPayrollCalculation> calculateEnhancedPayroll({
    required String employeeId,
    required String payrollPeriod,
    required DateTime dateOfBirth,
    required String residencyStatus,
    required String? ethnicity,
    String? workPassType,
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
    Map<String, dynamic>? metadata,
  }) async {
    final timestamp = HLCTimestamp.now(_nodeId);

    // Determine age category
    final ageCategory = _getAgeCategoryFromBirthDate(dateOfBirth);

    final payroll = CRDTEnhancedPayrollCalculation(
      id: UuidGenerator.generateId(),
      nodeId: _nodeId,
      createdAt: timestamp,
      updatedAt: timestamp,
      version: VectorClock(_nodeId),
      empId: employeeId,
      period: payrollPeriod,
      calcDate: DateTime.now(),
      ageCategory: ageCategory,
      residencyStatus: residencyStatus,
      workPass: workPassType,
      empEthnicity: ethnicity,
      basicSalary: basicSalary,
      overtime: overtime,
      allowances: allowances,
      commission: commission,
      bonus: bonus,
      benefitsInKind: benefitsInKind,
      incomeTax: incomeTax,
      fwl: fwl,
      sdl: sdl,
      otherDeductions: otherDeductions,
      status: 'draft',
      payrollMetadata: metadata,
    );

    // Calculate comprehensive payroll
    payroll.calculatePayroll(timestamp);

    _enhancedPayrolls[payroll.id] = payroll;
    return payroll;
  }

  /// Calculate Self-Help Group contributions
  Map<String, double> calculateShgContributions(String? ethnicity) {
    if (ethnicity == null) return {};

    final eligibleSHG = SelfHelpGroupRates.getEligibleSHG(ethnicity);
    final contributions = <String, double>{};

    for (final shg in eligibleSHG) {
      final rate = SelfHelpGroupRates.monthlyRates[shg] ?? 0.0;
      contributions[shg.toString().split('.').last] = rate;
    }

    return contributions;
  }

  /// Check work pass validity and quota compliance
  Map<String, dynamic> validateWorkPassCompliance({
    required String workPassType,
    required String industrySector,
    required int totalEmployees,
    required int foreignEmployees,
  }) {
    try {
      final workPass = WorkPassType.values.firstWhere(
          (e) => e.toString().split('.').last == workPassType.toLowerCase());
      final sector = IndustrySector.values.firstWhere(
          (e) => e.toString().split('.').last == industrySector.toLowerCase());

      final quotas = ForeignWorkerLevyRates.getSectorQuota(sector);
      final currentUsage =
          totalEmployees > 0 ? (foreignEmployees / totalEmployees * 100) : 0.0;

      // Check if work pass type has quota restrictions
      bool hasQuotaRestriction =
          [WorkPassType.workPermit, WorkPassType.sPass].contains(workPass);

      if (!hasQuotaRestriction) {
        return {
          'is_compliant': true,
          'has_quota_restriction': false,
          'current_usage': 0.0,
          'allowed_quota': 0.0,
          'message': 'No quota restrictions apply to this work pass type'
        };
      }

      final quotaKey =
          workPass == WorkPassType.workPermit ? 'workPermit' : 'sPass';
      final allowedQuota = quotas[quotaKey] ?? 0.0;
      final isCompliant = currentUsage <= allowedQuota;

      return {
        'is_compliant': isCompliant,
        'has_quota_restriction': true,
        'current_usage': currentUsage,
        'allowed_quota': allowedQuota,
        'quota_available': allowedQuota - currentUsage,
        'message': isCompliant
            ? 'Quota compliant'
            : 'Quota exceeded by ${(currentUsage - allowedQuota).toStringAsFixed(1)}%'
      };
    } catch (e) {
      return {
        'is_compliant': false,
        'has_quota_restriction': false,
        'current_usage': 0.0,
        'allowed_quota': 0.0,
        'message': 'Invalid work pass type or sector'
      };
    }
  }

  /// Process complete payroll for an employee
  Future<CRDTPayrollRecord> processPayroll({
    required String employeeId,
    required CRDTEmployee employee,
    required DateTime payPeriodStart,
    required DateTime payPeriodEnd,
    double overtimeHours = 0.0,
    double bonusAmount = 0.0,
    double commissionAmount = 0.0,
    double reimbursementAmount = 0.0,
    double otherDeductions = 0.0,
    Map<String, dynamic>? metadata,
  }) async {
    final payrollNumber = EmployeeUtils.generatePayrollNumber(
      DateTime.now().millisecondsSinceEpoch % 10000,
      payPeriodStart,
    );

    final timestamp = HLCTimestamp.now(_nodeId);

    // Calculate basic components
    final basicSalary = employee.basicSalary.value;
    final allowances = employee.allowances.value;

    // Calculate overtime pay (1.5x regular rate)
    final regularHours =
        _getRegularHoursForPeriod(payPeriodStart, payPeriodEnd);
    final hourlyRate = basicSalary / regularHours;
    final overtimePay = overtimeHours * hourlyRate * 1.5;

    // Calculate gross pay
    final grossPay = basicSalary +
        allowances +
        overtimePay +
        bonusAmount +
        commissionAmount +
        reimbursementAmount;

    // Calculate CPF contributions
    final cpfCalculation = await calculateCpfContributions(
      employeeId: employeeId,
      payrollRecordId: UuidGenerator.generateId(),
      dateOfBirth: employee.dateOfBirth.value ?? DateTime.now(),
      residencyStatus: employee.workPermitType.value,
      ordinaryWage: basicSalary + allowances, // OW = basic + allowances
      additionalWage: overtimePay +
          bonusAmount +
          commissionAmount, // AW = variable components
    );

    // Calculate SDL (employer cost)
    final sdlAmount = calculateSdl(basicSalary + allowances);

    // Calculate FWL (employer cost, if applicable)
    final fwlAmount = calculateFwl(
      workPassType: employee.workPermitType.value,
      sector: _inferSectorFromDepartment(employee.department.value),
      skillLevel: _inferSkillLevel(employee.jobTitle.value),
    );

    // Create payroll record
    final payroll = CRDTPayrollRecord(
      id: UuidGenerator.generateId(),
      nodeId: _nodeId,
      createdAt: timestamp,
      updatedAt: timestamp,
      version: VectorClock(_nodeId),
      empId: employeeId,
      payrollNum: payrollNumber,
      periodStart: payPeriodStart,
      periodEnd: payPeriodEnd,
      paymentDate: _getPaymentDate(payPeriodEnd),
      basic: basicSalary,
      allowances: allowances,
      overtime: overtimePay,
      bonus: bonusAmount,
      commission: commissionAmount,
      reimbursement: reimbursementAmount,
      cpfEmployee: cpfCalculation.employeeContribution,
      cpfEmployer: cpfCalculation.employerContribution,
      sdl: sdlAmount,
      fwl: fwlAmount,
      otherDeductions: otherDeductions,
      regHours: regularHours,
      otHours: overtimeHours,
      hRate: hourlyRate,
      otRate: hourlyRate * 1.5,
      account: employee.bankAccount.value,
      bank: employee.bankCode.value,
      payrollMetadata: metadata,
    );

    return payroll;
  }

  /// Generate payslip data
  Map<String, dynamic> generatePayslipData(
      CRDTPayrollRecord payroll, CRDTEmployee employee) {
    return {
      'employee': {
        'id': employee.employeeId.value,
        'name': employee.fullName,
        'department': employee.department.value,
        'designation': employee.jobTitle.value,
        'bank_account': employee.bankAccount.value,
        'bank_code': employee.bankCode.value,
      },
      'payroll': {
        'number': payroll.payrollNumber.value,
        'period_start': payroll.payPeriodStart.value,
        'period_end': payroll.payPeriodEnd.value,
        'pay_date': payroll.payDate.value,
      },
      'earnings': {
        'basic_salary': payroll.basicSalaryCents.value / 100.0,
        'allowances': payroll.allowancesCents.value / 100.0,
        'overtime': payroll.overtimeCents.value / 100.0,
        'bonus': payroll.bonusCents.value / 100.0,
        'commission': payroll.commissionCents.value / 100.0,
        'reimbursement': payroll.reimbursementCents.value / 100.0,
        'gross_pay': payroll.grossPay,
      },
      'deductions': {
        'cpf_employee': payroll.cpfEmployeeCents.value / 100.0,
        'tax_deduction': payroll.taxDeductionCents.value / 100.0,
        'insurance': payroll.insuranceDeductionCents.value / 100.0,
        'other_deductions': payroll.otherDeductionsCents.value / 100.0,
        'total_deductions': payroll.totalDeductions,
      },
      'employer_contributions': {
        'cpf_employer': payroll.cpfEmployerCents.value / 100.0,
        'sdl': payroll.sdlCents.value / 100.0,
        'fwl': payroll.fwlCents.value / 100.0,
        'total_employer_cost': payroll.employerCosts,
      },
      'net_pay': payroll.netPay,
      'working_hours': {
        'regular_hours': payroll.regularHours.value,
        'overtime_hours': payroll.overtimeHours.value,
        'hourly_rate': payroll.hourlyRate.value,
        'overtime_rate': payroll.overtimeRate.value,
      },
      'leave_taken': {
        'annual_leave': payroll.annualLeaveTaken.value,
        'sick_leave': payroll.sickLeaveTaken.value,
        'maternity_leave': payroll.maternityLeaveTaken.value,
        'paternity_leave': payroll.paternityLeaveTaken.value,
        'unpaid_leave': payroll.unpaidLeaveTaken.value,
        'total_leave': payroll.totalLeaveTaken,
      },
    };
  }

  /// Generate bank payment file (GIRO format for Singapore)
  String generateBankPaymentFile(List<CRDTPayrollRecord> payrollRecords,
      Map<String, CRDTEmployee> employees) {
    final buffer = StringBuffer();
    final now = DateTime.now();

    // Header record
    buffer.writeln(
        'H,${now.toString().substring(0, 10)},${payrollRecords.length}');

    // Detail records
    for (final payroll in payrollRecords) {
      final employee = employees[payroll.employeeId.value];
      if (employee == null || payroll.netPay <= 0) continue;

      final bankCode = employee.bankCode.value ?? '';
      final accountNumber = employee.bankAccount.value ?? '';
      final amount = (payroll.netPay * 100).round(); // Convert to cents
      final name = employee.fullName.padRight(35).substring(0, 35);

      buffer.writeln(
          'D,$bankCode,$accountNumber,$amount,$name,${payroll.payrollNumber.value}');
    }

    // Trailer record
    final totalAmount = payrollRecords.fold<double>(
      0.0,
      (sum, payroll) => sum + payroll.netPay,
    );
    buffer.writeln('T,${(totalAmount * 100).round()}');

    return buffer.toString();
  }

  /// Generate IR8A data for tax reporting
  Map<String, dynamic> generateIR8AData({
    required String employeeId,
    required CRDTEmployee employee,
    required int taxYear,
    required List<CRDTPayrollRecord> yearPayrolls,
  }) {
    // Aggregate annual data
    double totalGrossSalary = 0.0;
    double totalBonus = 0.0;
    double totalCommission = 0.0;
    double totalAllowances = 0.0;
    double totalEmployeeCpf = 0.0;
    double totalEmployerCpf = 0.0;

    for (final payroll in yearPayrolls) {
      totalGrossSalary += payroll.basicSalaryCents.value / 100.0;
      totalBonus += payroll.bonusCents.value / 100.0;
      totalCommission += payroll.commissionCents.value / 100.0;
      totalAllowances += payroll.allowancesCents.value / 100.0;
      totalEmployeeCpf += payroll.cpfEmployeeCents.value / 100.0;
      totalEmployerCpf += payroll.cpfEmployerCents.value / 100.0;
    }

    final totalIncome =
        totalGrossSalary + totalBonus + totalCommission + totalAllowances;

    return {
      'employee_id': employee.employeeId.value,
      'employee_name': employee.fullName,
      'nric_fin': employee.nricFinNumber.value,
      'nationality': employee.nationality.value,
      'tax_year': taxYear,
      'employment_start_date': employee.startDate.value,
      'employment_end_date': employee.endDate.value,
      'designation': employee.jobTitle.value,
      'gross_salary': totalGrossSalary,
      'bonus': totalBonus,
      'commission': totalCommission,
      'allowances': totalAllowances,
      'total_income': totalIncome,
      'employee_cpf': totalEmployeeCpf,
      'employer_cpf': totalEmployerCpf,
      'total_cpf': totalEmployeeCpf + totalEmployerCpf,
      'work_permit_type': employee.workPermitType.value,
      'is_local_employee': employee.isLocalEmployee.value,
    };
  }

  /// Get payroll statistics for a period
  Map<String, dynamic> getPayrollStatistics({
    required DateTime startDate,
    required DateTime endDate,
    String? department,
  }) {
    // This would typically query the database
    // For demo purposes, returning sample statistics
    return {
      'total_employees_paid': 0,
      'total_gross_pay': 0.0,
      'total_net_pay': 0.0,
      'total_cpf_employee': 0.0,
      'total_cpf_employer': 0.0,
      'total_sdl': 0.0,
      'total_fwl': 0.0,
      'average_salary': 0.0,
      'department_breakdown': <String, Map<String, dynamic>>{},
    };
  }

  // ============================================================================
  // PRIVATE HELPER METHODS
  // ============================================================================

  bool _isSubjectToCpf(String residencyStatus, DateTime dateOfBirth) {
    // Non-residents are generally not subject to CPF
    if (residencyStatus == 'non_resident') return false;

    // Citizens, PRs, and SPRs are subject to CPF
    return ['citizen', 'pr', 'pr_first_2_years'].contains(residencyStatus);
  }

  double _getRegularHoursForPeriod(DateTime start, DateTime end) {
    final workingDays = EmployeeUtils.calculateWorkingDays(start, end);
    return workingDays * 8.0; // Assuming 8 hours per working day
  }

  DateTime _getPaymentDate(DateTime periodEnd) {
    // Typically salary is paid on the last working day of the month
    // or first working day of the following month
    final nextMonth = DateTime(periodEnd.year, periodEnd.month + 1, 1);

    // Find first working day of next month
    while (nextMonth.weekday == DateTime.saturday ||
        nextMonth.weekday == DateTime.sunday) {
      nextMonth.add(const Duration(days: 1));
    }

    return nextMonth;
  }

  String _inferSectorFromDepartment(String? department) {
    if (department == null) return 'services';

    final dept = department.toLowerCase();
    if (dept.contains('manufacturing') || dept.contains('production')) {
      return 'manufacturing';
    } else if (dept.contains('construction')) {
      return 'construction';
    } else if (dept.contains('marine') || dept.contains('shipping')) {
      return 'marine';
    } else if (dept.contains('process') || dept.contains('chemical')) {
      return 'process';
    }

    return 'services';
  }

  String _inferSkillLevel(String jobTitle) {
    final title = jobTitle.toLowerCase();

    // Higher skilled positions
    if (title.contains('manager') ||
        title.contains('director') ||
        title.contains('senior') ||
        title.contains('lead') ||
        title.contains('specialist') ||
        title.contains('engineer') ||
        title.contains('analyst')) {
      return 'higher';
    }

    return 'basic';
  }

  String _getAgeCategoryFromBirthDate(DateTime dateOfBirth) {
    final now = DateTime.now();
    final age = now.year -
        dateOfBirth.year -
        (now.month < dateOfBirth.month ||
                (now.month == dateOfBirth.month && now.day < dateOfBirth.day)
            ? 1
            : 0);

    if (age < 55) return 'below55';
    if (age >= 55 && age < 60) return 'age55to60';
    if (age >= 60 && age < 65) return 'age60to65';
    if (age >= 65 && age < 70) return 'age65to70';
    return 'above70';
  }
}
