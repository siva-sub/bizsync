import 'dart:async';
import '../../../core/crdt/hybrid_logical_clock.dart';
import '../../../core/crdt/vector_clock.dart';
import '../../../core/utils/uuid_generator.dart';
import '../../../core/services/notification_service.dart';
import '../models/index.dart';

/// Core Employee Service for CRUD operations and business logic
class EmployeeService {
  static EmployeeService? _instance;
  final NotificationService _notificationService;

  // In-memory storage for demo - replace with database repository
  final Map<String, CRDTEmployee> _employees = {};
  final Map<String, CRDTPayrollRecord> _payrollRecords = {};
  final Map<String, CRDTLeaveRequest> _leaveRequests = {};
  final Map<String, CRDTAttendanceRecord> _attendanceRecords = {};
  final Map<String, CRDTPerformanceRecord> _performanceRecords = {};
  final Map<String, CRDTEmployeeGoal> _employeeGoals = {};

  // Sequence counters for ID generation
  int _employeeSequence = 1;
  int _payrollSequence = 1;
  int _leaveSequence = 1;

  final String _nodeId = UuidGenerator.generateId();

  EmployeeService(this._notificationService);

  /// Get singleton instance of EmployeeService
  static Future<EmployeeService> getInstance() async {
    if (_instance == null) {
      final notificationService = NotificationService();
      _instance = EmployeeService(notificationService);
    }
    return _instance!;
  }

  // ============================================================================
  // EMPLOYEE CRUD OPERATIONS
  // ============================================================================

  /// Create employee from CRDTEmployee object
  Future<CRDTEmployee> createEmployee(CRDTEmployee employee) async {
    _employees[employee.id] = employee;

    // Send notification
    await _notificationService.sendNotification(
      title: 'New Employee Added',
      message: 'Employee ${employee.fullName} has been added to the system',
      type: 'employee_created',
      data: {'employee_id': employee.id},
    );

    return employee;
  }

  /// Create a new employee with parameters
  Future<CRDTEmployee> createEmployeeWithParams({
    required String firstName,
    required String lastName,
    String? preferredName,
    required String email,
    String? phone,
    String? address,
    DateTime? dateOfBirth,
    String? nationality,
    String? nricFinNumber,
    required String jobTitle,
    String? department,
    String? managerId,
    required DateTime startDate,
    String employmentStatus = 'active',
    String employmentType = 'full_time',
    String workPermitType = 'citizen',
    String? workPermitNumber,
    DateTime? workPermitExpiry,
    bool isLocalEmployee = true,
    double basicSalary = 0.0,
    double allowances = 0.0,
    String payFrequency = 'monthly',
    String? bankAccount,
    String? bankCode,
    String? cpfNumber,
    bool isCpfMember = true,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactRelationship,
    Map<String, dynamic>? metadata,
  }) async {
    final employeeId = EmployeeUtils.generateEmployeeId(_employeeSequence++);
    final timestamp = HLCTimestamp.now(_nodeId);

    // Calculate CPF rate based on age and residency
    double cpfRate = 0.2; // Default for citizens/PRs below 55
    if (dateOfBirth != null) {
      final rates = EmployeeUtils.getCpfRates(dateOfBirth, workPermitType);
      cpfRate = rates['employee_rate'] ?? 0.2;
    }

    final employee = CRDTEmployee(
      id: UuidGenerator.generateId(),
      nodeId: _nodeId,
      createdAt: timestamp,
      updatedAt: timestamp,
      version: VectorClock(_nodeId),
      empId: employeeId,
      fname: firstName,
      lname: lastName,
      prefName: preferredName,
      empEmail: email,
      empPhone: phone,
      empAddress: address,
      dob: dateOfBirth,
      empNationality: nationality,
      nricFin: nricFinNumber,
      title: jobTitle,
      dept: department,
      manager: managerId,
      start: startDate,
      status: employmentStatus,
      type: employmentType,
      permitType: workPermitType,
      permitNumber: workPermitNumber,
      permitExpiry: workPermitExpiry,
      localEmployee: isLocalEmployee,
      salary: basicSalary,
      empAllowances: allowances,
      frequency: payFrequency,
      account: bankAccount,
      bank: bankCode,
      cpf: cpfNumber,
      cpfMember: isCpfMember,
      cpfRate: cpfRate,
      emergencyName: emergencyContactName,
      emergencyPhone: emergencyContactPhone,
      emergencyRelation: emergencyContactRelationship,
      empMetadata: metadata,
    );

    // Set default leave balances based on employment type and years of service
    _setDefaultLeaveBalances(employee);

    _employees[employee.id] = employee;

    // Send notification
    await _notificationService.sendNotification(
      title: 'New Employee Added',
      message: 'Employee ${employee.fullName} has been added to the system',
      type: 'employee_created',
      data: {'employee_id': employee.id},
    );

    return employee;
  }

  /// Get employee by ID
  CRDTEmployee? getEmployee(String employeeId) {
    return _employees[employeeId];
  }

  /// Get employee by ID (alias for compatibility)
  CRDTEmployee? getEmployeeById(String employeeId) {
    return getEmployee(employeeId);
  }

  /// Get employee by employee number
  CRDTEmployee? getEmployeeByNumber(String employeeNumber) {
    return _employees.values
        .where((emp) => emp.employeeId.value == employeeNumber)
        .firstOrNull;
  }

  /// Get all employees
  List<CRDTEmployee> getAllEmployees({
    String? department,
    String? status,
    String? employmentType,
    bool includeDeleted = false,
  }) {
    var employees = _employees.values.where((emp) {
      if (!includeDeleted && emp.isDeleted) return false;
      if (department != null && emp.department.value != department)
        return false;
      if (status != null && emp.employmentStatus.value != status) return false;
      if (employmentType != null && emp.employmentType.value != employmentType)
        return false;
      return true;
    }).toList();

    // Sort by employee ID
    employees.sort((a, b) => a.employeeId.value.compareTo(b.employeeId.value));
    return employees;
  }

  /// Search employees
  List<CRDTEmployee> searchEmployees(String query,
      {bool includeDeleted = false}) {
    final lowercaseQuery = query.toLowerCase();

    return _employees.values.where((emp) {
      if (!includeDeleted && emp.isDeleted) return false;

      return emp.firstName.value.toLowerCase().contains(lowercaseQuery) ||
          emp.lastName.value.toLowerCase().contains(lowercaseQuery) ||
          emp.employeeId.value.toLowerCase().contains(lowercaseQuery) ||
          emp.email.value.toLowerCase().contains(lowercaseQuery) ||
          (emp.jobTitle.value.toLowerCase().contains(lowercaseQuery)) ||
          (emp.department.value?.toLowerCase().contains(lowercaseQuery) ??
              false);
    }).toList();
  }

  /// Update employee from CRDTEmployee object
  Future<CRDTEmployee> updateEmployee(CRDTEmployee employee) async {
    _employees[employee.id] = employee;
    return employee;
  }

  /// Update employee information with parameters
  Future<CRDTEmployee> updateEmployeeWithParams(
    String employeeId,
    Map<String, dynamic> updates,
  ) async {
    final employee = _employees[employeeId];
    if (employee == null) {
      throw Exception('Employee not found: $employeeId');
    }

    final timestamp = HLCTimestamp.now(_nodeId);

    // Update personal information
    if (updates.containsKey('firstName') ||
        updates.containsKey('lastName') ||
        updates.containsKey('preferredName') ||
        updates.containsKey('email') ||
        updates.containsKey('phone') ||
        updates.containsKey('address') ||
        updates.containsKey('dateOfBirth') ||
        updates.containsKey('nationality') ||
        updates.containsKey('nricFinNumber')) {
      employee.updatePersonalInfo(
        newFirstName: updates['firstName'],
        newLastName: updates['lastName'],
        newPreferredName: updates['preferredName'],
        newEmail: updates['email'],
        newPhone: updates['phone'],
        newAddress: updates['address'],
        newDateOfBirth: updates['dateOfBirth'],
        newNationality: updates['nationality'],
        newNricFin: updates['nricFinNumber'],
        timestamp: timestamp,
      );
    }

    // Update employment details
    if (updates.containsKey('jobTitle') ||
        updates.containsKey('department') ||
        updates.containsKey('managerId') ||
        updates.containsKey('endDate') ||
        updates.containsKey('employmentStatus') ||
        updates.containsKey('employmentType')) {
      employee.updateEmploymentDetails(
        newJobTitle: updates['jobTitle'],
        newDepartment: updates['department'],
        newManagerId: updates['managerId'],
        newEndDate: updates['endDate'],
        newStatus: updates['employmentStatus'],
        newType: updates['employmentType'],
        timestamp: timestamp,
      );
    }

    // Update salary information
    if (updates.containsKey('basicSalary') ||
        updates.containsKey('allowances') ||
        updates.containsKey('payFrequency') ||
        updates.containsKey('bankAccount') ||
        updates.containsKey('bankCode')) {
      employee.updateSalary(
        newBasicSalary: updates['basicSalary'],
        newAllowances: updates['allowances'],
        newPayFrequency: updates['payFrequency'],
        newBankAccount: updates['bankAccount'],
        newBankCode: updates['bankCode'],
        timestamp: timestamp,
      );
    }

    // Update work permit information
    if (updates.containsKey('workPermitType') ||
        updates.containsKey('workPermitNumber') ||
        updates.containsKey('workPermitExpiry') ||
        updates.containsKey('isLocalEmployee')) {
      employee.updateWorkPermit(
        newPermitType: updates['workPermitType'],
        newPermitNumber: updates['workPermitNumber'],
        newPermitExpiry: updates['workPermitExpiry'],
        newIsLocal: updates['isLocalEmployee'],
        timestamp: timestamp,
      );
    }

    // Update CPF information
    if (updates.containsKey('cpfNumber') ||
        updates.containsKey('isCpfMember') ||
        updates.containsKey('cpfContributionRate') ||
        updates.containsKey('cpfOrdinaryWage') ||
        updates.containsKey('cpfAdditionalWage')) {
      employee.updateCpfInfo(
        newCpfNumber: updates['cpfNumber'],
        newIsCpfMember: updates['isCpfMember'],
        newCpfRate: updates['cpfContributionRate'],
        newOrdinaryWage: updates['cpfOrdinaryWage'],
        newAdditionalWage: updates['cpfAdditionalWage'],
        timestamp: timestamp,
      );
    }

    // Update emergency contact
    if (updates.containsKey('emergencyContactName') ||
        updates.containsKey('emergencyContactPhone') ||
        updates.containsKey('emergencyContactRelationship')) {
      employee.updateEmergencyContact(
        name: updates['emergencyContactName'],
        phone: updates['emergencyContactPhone'],
        relationship: updates['emergencyContactRelationship'],
        timestamp: timestamp,
      );
    }

    return employee;
  }

  /// Delete employee (hard delete)
  Future<void> deleteEmployee(String employeeId) async {
    final employee = _employees[employeeId];
    if (employee == null) {
      throw Exception('Employee not found: $employeeId');
    }

    _employees.remove(employeeId);

    // Send notification
    await _notificationService.sendNotification(
      title: 'Employee Deleted',
      message: 'Employee ${employee.fullName} has been permanently deleted',
      type: 'employee_deleted',
      data: {'employee_id': employee.id},
    );
  }

  /// Deactivate employee (soft delete)
  Future<void> deactivateEmployee(String employeeId, String reason) async {
    final employee = _employees[employeeId];
    if (employee == null) {
      throw Exception('Employee not found: $employeeId');
    }

    final timestamp = HLCTimestamp.now(_nodeId);
    employee.updateEmploymentDetails(
      newStatus: 'terminated',
      newEndDate: DateTime.now(),
      timestamp: timestamp,
    );

    // Send notification
    await _notificationService.sendNotification(
      title: 'Employee Deactivated',
      message:
          'Employee ${employee.fullName} has been deactivated. Reason: $reason',
      type: 'employee_deactivated',
      data: {'employee_id': employee.id, 'reason': reason},
    );
  }

  /// Get employees by manager
  List<CRDTEmployee> getEmployeesByManager(String managerId) {
    return _employees.values
        .where((emp) => emp.managerId.value == managerId && !emp.isDeleted)
        .toList();
  }

  /// Get employees by department
  List<CRDTEmployee> getEmployeesByDepartment(String department) {
    return _employees.values
        .where((emp) => emp.department.value == department && !emp.isDeleted)
        .toList();
  }

  /// Get employees with expiring work permits (within 90 days)
  List<CRDTEmployee> getEmployeesWithExpiringWorkPermits() {
    return _employees.values
        .where((emp) => !emp.isDeleted && emp.isWorkPermitExpiringSoon)
        .toList();
  }

  /// Add skill to employee
  Future<void> addSkillToEmployee(String employeeId, String skill) async {
    final employee = _employees[employeeId];
    if (employee == null) {
      throw Exception('Employee not found: $employeeId');
    }

    employee.addSkill(skill);
  }

  /// Remove skill from employee
  Future<void> removeSkillFromEmployee(String employeeId, String skill) async {
    final employee = _employees[employeeId];
    if (employee == null) {
      throw Exception('Employee not found: $employeeId');
    }

    employee.removeSkill(skill);
  }

  /// Add certification to employee
  Future<void> addCertificationToEmployee(
      String employeeId, String certification) async {
    final employee = _employees[employeeId];
    if (employee == null) {
      throw Exception('Employee not found: $employeeId');
    }

    employee.addCertification(certification);
  }

  /// Get employee statistics
  Map<String, dynamic> getEmployeeStatistics() {
    final allEmployees = getAllEmployees();
    final activeEmployees = getAllEmployees(status: 'active');
    final foreignWorkers =
        allEmployees.where((emp) => emp.isForeignWorker).length;
    final workPermitExpiring = getEmployeesWithExpiringWorkPermits().length;

    final departments = <String, int>{};
    final employmentTypes = <String, int>{};

    for (final emp in activeEmployees) {
      final dept = emp.department.value ?? 'Unassigned';
      departments[dept] = (departments[dept] ?? 0) + 1;

      final type = emp.employmentType.value;
      employmentTypes[type] = (employmentTypes[type] ?? 0) + 1;
    }

    return {
      'total_employees': allEmployees.length,
      'active_employees': activeEmployees.length,
      'foreign_workers': foreignWorkers,
      'work_permits_expiring': workPermitExpiring,
      'departments': departments,
      'employment_types': employmentTypes,
      'average_tenure_months': _calculateAverageTenure(activeEmployees),
    };
  }

  // ============================================================================
  // PRIVATE HELPER METHODS
  // ============================================================================

  void _setDefaultLeaveBalances(CRDTEmployee employee) {
    // Set standard Singapore leave entitlements
    employee.adjustLeaveBalance(
      annualLeaveAdjustment:
          EmployeeConstants.standardLeaveEntitlements['annual_leave_min']!,
      sickLeaveAdjustment:
          EmployeeConstants.standardLeaveEntitlements['sick_leave']!,
    );

    // Additional leave for parents
    if (employee.tags.elements.contains('parent')) {
      employee.adjustLeaveBalance(
        compassionateLeaveAdjustment:
            EmployeeConstants.standardLeaveEntitlements['childcare_leave']!,
      );
    }
  }

  double _calculateAverageTenure(List<CRDTEmployee> employees) {
    if (employees.isEmpty) return 0.0;

    final totalMonths = employees.fold<double>(0.0, (sum, emp) {
      return sum + EmployeeUtils.calculateMonthsOfService(emp.startDate.value);
    });

    return totalMonths / employees.length;
  }
}

/// Extension to add null safety helper
extension on Iterable<CRDTEmployee> {
  CRDTEmployee? get firstOrNull {
    return isEmpty ? null : first;
  }
}
