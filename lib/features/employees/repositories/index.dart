// Employee Repositories Index
//
// This file provides a central export point for all employee-related repositories
// providing database operations with CRDT support for offline-first functionality.

export 'employee_repository.dart';
export 'payroll_repository.dart';
export 'leave_attendance_repository.dart';

// Repository interfaces
abstract class IEmployeeRepository {
  Future<void> saveEmployee(CRDTEmployee employee);
  Future<CRDTEmployee?> getEmployee(String employeeId);
  Future<List<CRDTEmployee>> getAllEmployees(
      {String? department, String? status});
  Future<List<CRDTEmployee>> searchEmployees(String query);
  Future<void> updateEmployee(CRDTEmployee employee);
  Future<void> deleteEmployee(String employeeId);
}

abstract class IPayrollRepository {
  Future<void> savePayrollRecord(CRDTPayrollRecord payrollRecord);
  Future<CRDTPayrollRecord?> getPayrollRecord(String payrollRecordId);
  Future<List<CRDTPayrollRecord>> getPayrollRecordsForEmployee(
      String employeeId);
  Future<void> updatePayrollRecord(CRDTPayrollRecord payrollRecord);
}

abstract class ILeaveAttendanceRepository {
  Future<void> saveLeaveRequest(CRDTLeaveRequest leaveRequest);
  Future<CRDTLeaveRequest?> getLeaveRequest(String leaveRequestId);
  Future<List<CRDTLeaveRequest>> getLeaveRequestsForEmployee(String employeeId);
  Future<void> saveAttendanceRecord(CRDTAttendanceRecord attendanceRecord);
  Future<CRDTAttendanceRecord?> getAttendanceRecordForDate(
      String employeeId, DateTime date);
}

// Repository factory for dependency injection
class EmployeeRepositoryFactory {
  static EmployeeRepository createEmployeeRepository(
      CRDTDatabaseService database) {
    return EmployeeRepository(database);
  }

  static PayrollRepository createPayrollRepository(
      CRDTDatabaseService database) {
    return PayrollRepository(database);
  }

  static LeaveAttendanceRepository createLeaveAttendanceRepository(
      CRDTDatabaseService database) {
    return LeaveAttendanceRepository(database);
  }
}

// Database schema for employee module
class EmployeeDatabaseSchema {
  static const String createEmployeesTable = '''
    CREATE TABLE IF NOT EXISTS employees (
      id TEXT PRIMARY KEY,
      data TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      node_id TEXT NOT NULL,
      version TEXT NOT NULL,
      is_deleted INTEGER NOT NULL DEFAULT 0
    )
  ''';

  static const String createPayrollRecordsTable = '''
    CREATE TABLE IF NOT EXISTS payroll_records (
      id TEXT PRIMARY KEY,
      data TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      node_id TEXT NOT NULL,
      version TEXT NOT NULL,
      is_deleted INTEGER NOT NULL DEFAULT 0
    )
  ''';

  static const String createLeaveRequestsTable = '''
    CREATE TABLE IF NOT EXISTS leave_requests (
      id TEXT PRIMARY KEY,
      data TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      node_id TEXT NOT NULL,
      version TEXT NOT NULL,
      is_deleted INTEGER NOT NULL DEFAULT 0
    )
  ''';

  static const String createAttendanceRecordsTable = '''
    CREATE TABLE IF NOT EXISTS attendance_records (
      id TEXT PRIMARY KEY,
      data TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      node_id TEXT NOT NULL,
      version TEXT NOT NULL,
      is_deleted INTEGER NOT NULL DEFAULT 0
    )
  ''';

  static const String createPerformanceRecordsTable = '''
    CREATE TABLE IF NOT EXISTS performance_records (
      id TEXT PRIMARY KEY,
      data TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      node_id TEXT NOT NULL,
      version TEXT NOT NULL,
      is_deleted INTEGER NOT NULL DEFAULT 0
    )
  ''';

  static const String createEmployeeGoalsTable = '''
    CREATE TABLE IF NOT EXISTS employee_goals (
      id TEXT PRIMARY KEY,
      data TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      node_id TEXT NOT NULL,
      version TEXT NOT NULL,
      is_deleted INTEGER NOT NULL DEFAULT 0
    )
  ''';

  static const String createCpfCalculationsTable = '''
    CREATE TABLE IF NOT EXISTS cpf_calculations (
      id TEXT PRIMARY KEY,
      data TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      node_id TEXT NOT NULL,
      version TEXT NOT NULL,
      is_deleted INTEGER NOT NULL DEFAULT 0
    )
  ''';

  static const String createIr8aTaxFormsTable = '''
    CREATE TABLE IF NOT EXISTS ir8a_tax_forms (
      id TEXT PRIMARY KEY,
      data TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      node_id TEXT NOT NULL,
      version TEXT NOT NULL,
      is_deleted INTEGER NOT NULL DEFAULT 0
    )
  ''';

  static const String createPayComponentsTable = '''
    CREATE TABLE IF NOT EXISTS pay_components (
      id TEXT PRIMARY KEY,
      data TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      node_id TEXT NOT NULL,
      version TEXT NOT NULL,
      is_deleted INTEGER NOT NULL DEFAULT 0
    )
  ''';

  // Indexes for better query performance
  static const List<String> createIndexes = [
    'CREATE INDEX IF NOT EXISTS idx_employees_employee_id ON employees(JSON_EXTRACT(data, "\$.employee_id.value"))',
    'CREATE INDEX IF NOT EXISTS idx_employees_department ON employees(JSON_EXTRACT(data, "\$.department.value"))',
    'CREATE INDEX IF NOT EXISTS idx_employees_status ON employees(JSON_EXTRACT(data, "\$.employment_status.value"))',
    'CREATE INDEX IF NOT EXISTS idx_employees_manager ON employees(JSON_EXTRACT(data, "\$.manager_id.value"))',
    'CREATE INDEX IF NOT EXISTS idx_employees_work_permit_expiry ON employees(JSON_EXTRACT(data, "\$.work_permit_expiry.value"))',
    'CREATE INDEX IF NOT EXISTS idx_payroll_employee ON payroll_records(JSON_EXTRACT(data, "\$.employee_id.value"))',
    'CREATE INDEX IF NOT EXISTS idx_payroll_period ON payroll_records(JSON_EXTRACT(data, "\$.pay_period_start.value"), JSON_EXTRACT(data, "\$.pay_period_end.value"))',
    'CREATE INDEX IF NOT EXISTS idx_payroll_status ON payroll_records(JSON_EXTRACT(data, "\$.status.value"))',
    'CREATE INDEX IF NOT EXISTS idx_payroll_pay_date ON payroll_records(JSON_EXTRACT(data, "\$.pay_date.value"))',
    'CREATE INDEX IF NOT EXISTS idx_leave_employee ON leave_requests(JSON_EXTRACT(data, "\$.employee_id.value"))',
    'CREATE INDEX IF NOT EXISTS idx_leave_status ON leave_requests(JSON_EXTRACT(data, "\$.status.value"))',
    'CREATE INDEX IF NOT EXISTS idx_leave_dates ON leave_requests(JSON_EXTRACT(data, "\$.start_date.value"), JSON_EXTRACT(data, "\$.end_date.value"))',
    'CREATE INDEX IF NOT EXISTS idx_leave_manager ON leave_requests(JSON_EXTRACT(data, "\$.manager_id.value"))',
    'CREATE INDEX IF NOT EXISTS idx_attendance_employee ON attendance_records(JSON_EXTRACT(data, "\$.employee_id.value"))',
    'CREATE INDEX IF NOT EXISTS idx_attendance_date ON attendance_records(JSON_EXTRACT(data, "\$.date.value"))',
    'CREATE INDEX IF NOT EXISTS idx_attendance_status ON attendance_records(JSON_EXTRACT(data, "\$.status.value"))',
    'CREATE INDEX IF NOT EXISTS idx_attendance_approval ON attendance_records(JSON_EXTRACT(data, "\$.requires_approval.value"), JSON_EXTRACT(data, "\$.is_approved.value"))',
    'CREATE INDEX IF NOT EXISTS idx_performance_employee ON performance_records(JSON_EXTRACT(data, "\$.employee_id.value"))',
    'CREATE INDEX IF NOT EXISTS idx_performance_status ON performance_records(JSON_EXTRACT(data, "\$.status.value"))',
    'CREATE INDEX IF NOT EXISTS idx_performance_reviewer ON performance_records(JSON_EXTRACT(data, "\$.reviewer_id.value"))',
    'CREATE INDEX IF NOT EXISTS idx_goals_employee ON employee_goals(JSON_EXTRACT(data, "\$.employee_id.value"))',
    'CREATE INDEX IF NOT EXISTS idx_goals_status ON employee_goals(JSON_EXTRACT(data, "\$.status.value"))',
    'CREATE INDEX IF NOT EXISTS idx_goals_priority ON employee_goals(JSON_EXTRACT(data, "\$.priority.value"))',
    'CREATE INDEX IF NOT EXISTS idx_cpf_employee ON cpf_calculations(JSON_EXTRACT(data, "\$.employee_id.value"))',
    'CREATE INDEX IF NOT EXISTS idx_cpf_payroll ON cpf_calculations(JSON_EXTRACT(data, "\$.payroll_record_id.value"))',
    'CREATE INDEX IF NOT EXISTS idx_ir8a_employee ON ir8a_tax_forms(JSON_EXTRACT(data, "\$.employee_id.value"))',
    'CREATE INDEX IF NOT EXISTS idx_ir8a_year ON ir8a_tax_forms(JSON_EXTRACT(data, "\$.tax_year.value"))',
    'CREATE INDEX IF NOT EXISTS idx_pay_components_payroll ON pay_components(JSON_EXTRACT(data, "\$.payroll_record_id.value"))',
  ];

  static const List<String> allTables = [
    createEmployeesTable,
    createPayrollRecordsTable,
    createLeaveRequestsTable,
    createAttendanceRecordsTable,
    createPerformanceRecordsTable,
    createEmployeeGoalsTable,
    createCpfCalculationsTable,
    createIr8aTaxFormsTable,
    createPayComponentsTable,
  ];

  /// Initialize all employee module tables
  static Future<void> initializeSchema(CRDTDatabaseService database) async {
    // Create tables
    for (final tableSQL in allTables) {
      await database.execute(tableSQL);
    }

    // Create indexes
    for (final indexSQL in createIndexes) {
      await database.execute(indexSQL);
    }
  }
}
