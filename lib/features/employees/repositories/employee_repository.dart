import 'dart:async';
import '../../../core/database/crdt_database_service.dart';
import '../../../core/crdt/hybrid_logical_clock.dart';
import '../models/index.dart';

/// Repository for Employee data operations with CRDT support
class EmployeeRepository {
  final CRDTDatabaseService _database;
  
  EmployeeRepository(this._database);
  
  // ============================================================================
  // EMPLOYEE OPERATIONS
  // ============================================================================
  
  /// Save employee to database
  Future<void> saveEmployee(CRDTEmployee employee) async {
    await _database.insert(
      table: 'employees',
      data: employee.toCRDTJson(),
      id: employee.id,
    );
  }
  
  /// Get employee by ID
  Future<CRDTEmployee?> getEmployee(String employeeId) async {
    final data = await _database.get('employees', employeeId);
    if (data == null) return null;
    
    return CRDTEmployee.fromCRDTJson(data);
  }
  
  /// Get employee by employee number
  Future<CRDTEmployee?> getEmployeeByNumber(String employeeNumber) async {
    final results = await _database.query(
      table: 'employees',
      where: 'JSON_EXTRACT(data, "\$.employee_id.value") = ?',
      whereArgs: [employeeNumber],
      limit: 1,
    );
    
    if (results.isEmpty) return null;
    return CRDTEmployee.fromCRDTJson(results.first);
  }
  
  /// Get all employees with optional filters
  Future<List<CRDTEmployee>> getAllEmployees({
    String? department,
    String? status,
    String? employmentType,
    bool includeDeleted = false,
    int? limit,
    int? offset,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];
    
    if (!includeDeleted) {
      conditions.add('JSON_EXTRACT(data, "\$.is_deleted") = ?');
      args.add(false);
    }
    
    if (department != null) {
      conditions.add('JSON_EXTRACT(data, "\$.department.value") = ?');
      args.add(department);
    }
    
    if (status != null) {
      conditions.add('JSON_EXTRACT(data, "\$.employment_status.value") = ?');
      args.add(status);
    }
    
    if (employmentType != null) {
      conditions.add('JSON_EXTRACT(data, "\$.employment_type.value") = ?');
      args.add(employmentType);
    }
    
    final whereClause = conditions.isNotEmpty ? conditions.join(' AND ') : null;
    
    final results = await _database.query(
      table: 'employees',
      where: whereClause,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'JSON_EXTRACT(data, "\$.employee_id.value")',
      limit: limit,
      offset: offset,
    );
    
    return results.map((data) => CRDTEmployee.fromCRDTJson(data)).toList();
  }
  
  /// Search employees by query
  Future<List<CRDTEmployee>> searchEmployees(
    String query, {
    bool includeDeleted = false,
    int? limit = 50,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];
    
    if (!includeDeleted) {
      conditions.add('JSON_EXTRACT(data, "\$.is_deleted") = ?');
      args.add(false);
    }
    
    // Search in multiple fields
    final searchFields = [
      'JSON_EXTRACT(data, "\$.first_name.value")',
      'JSON_EXTRACT(data, "\$.last_name.value")',
      'JSON_EXTRACT(data, "\$.employee_id.value")',
      'JSON_EXTRACT(data, "\$.email.value")',
      'JSON_EXTRACT(data, "\$.job_title.value")',
      'JSON_EXTRACT(data, "\$.department.value")',
    ];
    
    final searchCondition = searchFields
        .map((field) => '$field LIKE ?')
        .join(' OR ');
    
    conditions.add('($searchCondition)');
    
    // Add search term for each field
    for (int i = 0; i < searchFields.length; i++) {
      args.add('%$query%');
    }
    
    final results = await _database.query(
      table: 'employees',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'JSON_EXTRACT(data, "\$.first_name.value"), JSON_EXTRACT(data, "\$.last_name.value")',
      limit: limit,
    );
    
    return results.map((data) => CRDTEmployee.fromCRDTJson(data)).toList();
  }
  
  /// Get employees by manager
  Future<List<CRDTEmployee>> getEmployeesByManager(String managerId) async {
    final results = await _database.query(
      table: 'employees',
      where: 'JSON_EXTRACT(data, "\$.manager_id.value") = ? AND JSON_EXTRACT(data, "\$.is_deleted") = ?',
      whereArgs: [managerId, false],
      orderBy: 'JSON_EXTRACT(data, "\$.first_name.value")',
    );
    
    return results.map((data) => CRDTEmployee.fromCRDTJson(data)).toList();
  }
  
  /// Get employees by department
  Future<List<CRDTEmployee>> getEmployeesByDepartment(String department) async {
    final results = await _database.query(
      table: 'employees',
      where: 'JSON_EXTRACT(data, "\$.department.value") = ? AND JSON_EXTRACT(data, "\$.is_deleted") = ?',
      whereArgs: [department, false],
      orderBy: 'JSON_EXTRACT(data, "\$.first_name.value")',
    );
    
    return results.map((data) => CRDTEmployee.fromCRDTJson(data)).toList();
  }
  
  /// Get employees with expiring work permits
  Future<List<CRDTEmployee>> getEmployeesWithExpiringWorkPermits({int daysAhead = 90}) async {
    final cutoffDate = DateTime.now().add(Duration(days: daysAhead));
    
    final results = await _database.query(
      table: 'employees',
      where: '''
        JSON_EXTRACT(data, "\$.is_deleted") = ? AND
        JSON_EXTRACT(data, "\$.work_permit_expiry.value") IS NOT NULL AND
        datetime(JSON_EXTRACT(data, "\$.work_permit_expiry.value") / 1000, 'unixepoch') <= datetime(?)
      ''',
      whereArgs: [false, cutoffDate.toIso8601String()],
      orderBy: 'JSON_EXTRACT(data, "\$.work_permit_expiry.value")',
    );
    
    return results.map((data) => CRDTEmployee.fromCRDTJson(data)).toList();
  }
  
  /// Update employee
  Future<void> updateEmployee(CRDTEmployee employee) async {
    await _database.update(
      table: 'employees',
      id: employee.id,
      data: employee.toCRDTJson(),
    );
  }
  
  /// Delete employee (soft delete)
  Future<void> deleteEmployee(String employeeId) async {
    final employee = await getEmployee(employeeId);
    if (employee == null) return;
    
    employee.isDeleted = true;
    employee.updatedAt = HLCTimestamp.now(_database.nodeId);
    
    await updateEmployee(employee);
  }
  
  /// Get employee statistics
  Future<Map<String, dynamic>> getEmployeeStatistics() async {
    final stats = <String, dynamic>{};
    
    // Total employees
    final totalResult = await _database.rawQuery(
      'SELECT COUNT(*) as count FROM employees WHERE JSON_EXTRACT(data, "\$.is_deleted") = ?',
      [false],
    );
    stats['total_employees'] = totalResult.first['count'];
    
    // Active employees
    final activeResult = await _database.rawQuery(
      'SELECT COUNT(*) as count FROM employees WHERE JSON_EXTRACT(data, "\$.is_deleted") = ? AND JSON_EXTRACT(data, "\$.employment_status.value") = ?',
      [false, 'active'],
    );
    stats['active_employees'] = activeResult.first['count'];
    
    // Foreign workers
    final foreignResult = await _database.rawQuery(
      'SELECT COUNT(*) as count FROM employees WHERE JSON_EXTRACT(data, "\$.is_deleted") = ? AND JSON_EXTRACT(data, "\$.is_local_employee.value") = ?',
      [false, false],
    );
    stats['foreign_workers'] = foreignResult.first['count'];
    
    // Expiring work permits
    final expiringEmployees = await getEmployeesWithExpiringWorkPermits();
    stats['work_permits_expiring'] = expiringEmployees.length;
    
    // Department breakdown
    final deptResult = await _database.rawQuery('''
      SELECT 
        COALESCE(JSON_EXTRACT(data, "\$.department.value"), 'Unassigned') as department,
        COUNT(*) as count
      FROM employees 
      WHERE JSON_EXTRACT(data, "\$.is_deleted") = ? AND JSON_EXTRACT(data, "\$.employment_status.value") = ?
      GROUP BY department
    ''', [false, 'active']);
    
    stats['departments'] = Map.fromEntries(
      deptResult.map((row) => MapEntry(row['department'] as String, row['count'])),
    );
    
    // Employment type breakdown
    final typeResult = await _database.rawQuery('''
      SELECT 
        JSON_EXTRACT(data, "\$.employment_type.value") as employment_type,
        COUNT(*) as count
      FROM employees 
      WHERE JSON_EXTRACT(data, "\$.is_deleted") = ? AND JSON_EXTRACT(data, "\$.employment_status.value") = ?
      GROUP BY employment_type
    ''', [false, 'active']);
    
    stats['employment_types'] = Map.fromEntries(
      typeResult.map((row) => MapEntry(row['employment_type'] as String, row['count'])),
    );
    
    return stats;
  }
  
  /// Batch insert employees
  Future<void> batchInsertEmployees(List<CRDTEmployee> employees) async {
    await _database.batchInsert(
      table: 'employees',
      records: employees.map((emp) => {
        'id': emp.id,
        'data': emp.toCRDTJson(),
      }).toList(),
    );
  }
  
  /// Sync employees (for CRDT merge operations)
  Future<List<CRDTEmployee>> getEmployeesModifiedAfter(DateTime timestamp) async {
    final results = await _database.query(
      table: 'employees',
      where: 'JSON_EXTRACT(data, "\$.updated_at") > ?',
      whereArgs: [timestamp.toIso8601String()],
      orderBy: 'JSON_EXTRACT(data, "\$.updated_at")',
    );
    
    return results.map((data) => CRDTEmployee.fromCRDTJson(data)).toList();
  }
  
  /// Get employees by skills
  Future<List<CRDTEmployee>> getEmployeesBySkills(List<String> skills) async {
    if (skills.isEmpty) return [];
    
    final skillConditions = skills.map((skill) => 
      'JSON_EXTRACT(data, "\$.skills") LIKE ?'
    ).join(' OR ');
    
    final args = skills.map((skill) => '%"$skill"%').toList();
    args.add(false); // for is_deleted condition
    
    final results = await _database.query(
      table: 'employees',
      where: '($skillConditions) AND JSON_EXTRACT(data, "\$.is_deleted") = ?',
      whereArgs: args,
      orderBy: 'JSON_EXTRACT(data, "\$.first_name.value")',
    );
    
    return results.map((data) => CRDTEmployee.fromCRDTJson(data)).toList();
  }
  
  /// Get employees hired within date range
  Future<List<CRDTEmployee>> getEmployeesHiredBetween(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final results = await _database.query(
      table: 'employees',
      where: '''
        JSON_EXTRACT(data, "\$.is_deleted") = ? AND
        datetime(JSON_EXTRACT(data, "\$.start_date.value") / 1000, 'unixepoch') >= datetime(?) AND
        datetime(JSON_EXTRACT(data, "\$.start_date.value") / 1000, 'unixepoch') <= datetime(?)
      ''',
      whereArgs: [false, startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'JSON_EXTRACT(data, "\$.start_date.value") DESC',
    );
    
    return results.map((data) => CRDTEmployee.fromCRDTJson(data)).toList();
  }
  
  /// Get employees by salary range
  Future<List<CRDTEmployee>> getEmployeesBySalaryRange(
    double minSalary,
    double maxSalary,
  ) async {
    final results = await _database.query(
      table: 'employees',
      where: '''
        JSON_EXTRACT(data, "\$.is_deleted") = ? AND
        JSON_EXTRACT(data, "\$.basic_salary.value") >= ? AND
        JSON_EXTRACT(data, "\$.basic_salary.value") <= ?
      ''',
      whereArgs: [false, minSalary, maxSalary],
      orderBy: 'JSON_EXTRACT(data, "\$.basic_salary.value") DESC',
    );
    
    return results.map((data) => CRDTEmployee.fromCRDTJson(data)).toList();
  }
}