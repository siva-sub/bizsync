// Employee Services Index
//
// This file provides a central export point for all employee-related services
// including core CRUD operations, payroll processing, leave management,
// attendance tracking, and Singapore-specific compliance features.

// Core services
export 'employee_service.dart';
export 'singapore_payroll_service.dart';
export 'leave_management_service.dart';
export 'attendance_service.dart';

// Service interfaces and contracts
abstract class IEmployeeService {
  Future<CRDTEmployee> createEmployee(Map<String, dynamic> employeeData);
  Future<CRDTEmployee> updateEmployee(
      String employeeId, Map<String, dynamic> updates);
  Future<void> deactivateEmployee(String employeeId, String reason);
  CRDTEmployee? getEmployee(String employeeId);
  List<CRDTEmployee> getAllEmployees({String? department, String? status});
  List<CRDTEmployee> searchEmployees(String query);
}

abstract class IPayrollService {
  Future<CRDTPayrollRecord> processPayroll(Map<String, dynamic> payrollData);
  Future<CRDTSingaporeCpfCalculation> calculateCpfContributions(
      Map<String, dynamic> cpfData);
  Map<String, dynamic> generatePayslipData(
      CRDTPayrollRecord payroll, CRDTEmployee employee);
  String generateBankPaymentFile(List<CRDTPayrollRecord> payrollRecords,
      Map<String, CRDTEmployee> employees);
}

abstract class ILeaveManagementService {
  Future<CRDTLeaveRequest> createLeaveRequest(Map<String, dynamic> leaveData);
  Future<void> approveLeaveRequest(String leaveRequestId, String approverId,
      {String? comments});
  Future<void> rejectLeaveRequest(String leaveRequestId, String approverId,
      {String? comments});
  List<CRDTLeaveRequest> getPendingLeaveRequests({String? managerId});
  Map<String, dynamic> getLeaveBalanceSummary(CRDTEmployee employee);
}

abstract class IAttendanceService {
  Future<CRDTAttendanceRecord> clockIn(Map<String, dynamic> clockInData);
  Future<CRDTAttendanceRecord> clockOut(Map<String, dynamic> clockOutData);
  Future<void> markAbsent(Map<String, dynamic> absentData);
  Map<String, dynamic> getAttendanceSummary(Map<String, dynamic> summaryParams);
  Map<String, dynamic> generateAttendanceReport(
      Map<String, dynamic> reportParams);
}

// Service factory for dependency injection
class EmployeeServiceFactory {
  static EmployeeService createEmployeeService(
      NotificationService notificationService) {
    return EmployeeService(notificationService);
  }

  static SingaporePayrollService createPayrollService() {
    return SingaporePayrollService();
  }

  static LeaveManagementService createLeaveManagementService(
      NotificationService notificationService) {
    return LeaveManagementService(notificationService);
  }

  static AttendanceService createAttendanceService(
      NotificationService notificationService) {
    return AttendanceService(notificationService);
  }
}

// Composite service for coordinated operations
class EmployeeManagementFacade {
  final EmployeeService _employeeService;
  final SingaporePayrollService _payrollService;
  final LeaveManagementService _leaveService;
  final AttendanceService _attendanceService;

  EmployeeManagementFacade({
    required EmployeeService employeeService,
    required SingaporePayrollService payrollService,
    required LeaveManagementService leaveService,
    required AttendanceService attendanceService,
  })  : _employeeService = employeeService,
        _payrollService = payrollService,
        _leaveService = leaveService,
        _attendanceService = attendanceService;

  /// Get comprehensive employee dashboard data
  Future<Map<String, dynamic>> getEmployeeDashboard(String employeeId) async {
    final employee = _employeeService.getEmployee(employeeId);
    if (employee == null) {
      throw Exception('Employee not found: $employeeId');
    }

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);

    return {
      'employee': employee.toJson(),
      'leave_summary': _leaveService.getLeaveBalanceSummary(employee),
      'attendance_summary': _attendanceService.getAttendanceSummary({
        'employee_id': employeeId,
        'start_date': monthStart,
        'end_date': monthEnd,
      }),
      'recent_leave_requests': _leaveService
          .getLeaveRequestsForEmployee(employeeId)
          .take(5)
          .map((request) => request.toJson())
          .toList(),
      'today_attendance':
          _attendanceService.getAttendanceRecord(employeeId, now)?.toJson(),
    };
  }

  /// Process end-of-month operations
  Future<Map<String, dynamic>> processEndOfMonth({
    required int year,
    required int month,
    List<String>? employeeIds,
  }) async {
    final employees = employeeIds != null
        ? employeeIds
            .map((id) => _employeeService.getEmployee(id))
            .whereType<CRDTEmployee>()
            .toList()
        : _employeeService.getAllEmployees(status: 'active');

    final results = <String, dynamic>{
      'processed_employees': 0,
      'total_payroll_amount': 0.0,
      'failed_employees': <String>[],
      'payroll_records': <String>[],
    };

    final periodStart = DateTime(year, month, 1);
    final periodEnd = DateTime(year, month + 1, 0);

    for (final employee in employees) {
      try {
        // Process payroll for the month
        final payrollRecord = await _payrollService.processPayroll(
          employeeId: employee.id,
          employee: employee,
          payPeriodStart: periodStart,
          payPeriodEnd: periodEnd,
        );

        results['processed_employees']++;
        results['total_payroll_amount'] += payrollRecord.netPay;
        results['payroll_records'].add(payrollRecord.id);
      } catch (e) {
        results['failed_employees'].add(employee.id);
      }
    }

    return results;
  }

  /// Generate comprehensive HR reports
  Future<Map<String, dynamic>> generateHRReports({
    required DateTime startDate,
    required DateTime endDate,
    String? department,
  }) async {
    final employees = _employeeService.getAllEmployees(
      department: department,
      status: 'active',
    );

    final employeeIds = employees.map((e) => e.id).toList();

    return {
      'employee_statistics': _employeeService.getEmployeeStatistics(),
      'attendance_report': _attendanceService.generateAttendanceReport({
        'employee_ids': employeeIds,
        'start_date': startDate,
        'end_date': endDate,
        'department': department,
      }),
      'leave_overview': _leaveService.getTeamLeaveOverview(
        employeeIds: employeeIds,
        fromDate: startDate,
        toDate: endDate,
      ),
      'payroll_statistics': _payrollService.getPayrollStatistics(
        startDate: startDate,
        endDate: endDate,
        department: department,
      ),
    };
  }

  /// Handle employee resignation workflow
  Future<void> processEmployeeResignation({
    required String employeeId,
    required DateTime lastWorkingDay,
    String? reason,
    bool processFinalPay = true,
  }) async {
    final employee = _employeeService.getEmployee(employeeId);
    if (employee == null) {
      throw Exception('Employee not found: $employeeId');
    }

    // Update employee status
    await _employeeService.updateEmployee(employeeId, {
      'employmentStatus': 'terminated',
      'endDate': lastWorkingDay,
    });

    // Cancel pending leave requests
    final pendingLeaves = _leaveService.getLeaveRequestsForEmployee(
      employeeId,
      status: 'submitted',
    );

    for (final leave in pendingLeaves) {
      await _leaveService.cancelLeaveRequest(
        leave.id,
        'Employee resignation - auto-cancelled',
      );
    }

    // Process final payroll if requested
    if (processFinalPay) {
      final monthStart = DateTime(lastWorkingDay.year, lastWorkingDay.month, 1);
      await _payrollService.processPayroll(
        employeeId: employeeId,
        employee: employee,
        payPeriodStart: monthStart,
        payPeriodEnd: lastWorkingDay,
      );
    }
  }
}
