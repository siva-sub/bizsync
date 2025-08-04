import 'dart:async';
import '../../../core/database/crdt_database_service.dart';
import '../../../core/crdt/hybrid_logical_clock.dart';
import '../models/index.dart';

/// Repository for Leave and Attendance data operations with CRDT support
class LeaveAttendanceRepository {
  final CRDTDatabaseService _database;

  LeaveAttendanceRepository(this._database);

  // ============================================================================
  // LEAVE REQUEST OPERATIONS
  // ============================================================================

  /// Save leave request to database
  Future<void> saveLeaveRequest(CRDTLeaveRequest leaveRequest) async {
    await _database.insert(
      table: 'leave_requests',
      data: leaveRequest.toCRDTJson(),
      id: leaveRequest.id,
    );
  }

  /// Get leave request by ID
  Future<CRDTLeaveRequest?> getLeaveRequest(String leaveRequestId) async {
    final data = await _database.get('leave_requests', leaveRequestId);
    if (data == null) return null;

    return CRDTLeaveRequest.fromCRDTJson(data);
  }

  /// Get leave requests for an employee
  Future<List<CRDTLeaveRequest>> getLeaveRequestsForEmployee(
    String employeeId, {
    String? status,
    String? leaveType,
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
    int? offset,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];

    conditions.add('JSON_EXTRACT(data, "\$.employee_id.value") = ?');
    args.add(employeeId);

    conditions.add('JSON_EXTRACT(data, "\$.is_deleted") = ?');
    args.add(false);

    if (status != null) {
      conditions.add('JSON_EXTRACT(data, "\$.status.value") = ?');
      args.add(status);
    }

    if (leaveType != null) {
      conditions.add('JSON_EXTRACT(data, "\$.leave_type.value") = ?');
      args.add(leaveType);
    }

    if (fromDate != null) {
      conditions.add(
          'datetime(JSON_EXTRACT(data, "\$.start_date.value") / 1000, \'unixepoch\') >= datetime(?)');
      args.add(fromDate.toIso8601String());
    }

    if (toDate != null) {
      conditions.add(
          'datetime(JSON_EXTRACT(data, "\$.end_date.value") / 1000, \'unixepoch\') <= datetime(?)');
      args.add(toDate.toIso8601String());
    }

    final results = await _database.query(
      table: 'leave_requests',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'JSON_EXTRACT(data, "\$.created_at") DESC',
      limit: limit,
      offset: offset,
    );

    return results.map((data) => CRDTLeaveRequest.fromCRDTJson(data)).toList();
  }

  /// Get pending leave requests for approval
  Future<List<CRDTLeaveRequest>> getPendingLeaveRequests({
    String? managerId,
    int? limit,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];

    conditions.add('JSON_EXTRACT(data, "\$.status.value") = ?');
    args.add('submitted');

    conditions.add('JSON_EXTRACT(data, "\$.is_deleted") = ?');
    args.add(false);

    if (managerId != null) {
      conditions.add('JSON_EXTRACT(data, "\$.manager_id.value") = ?');
      args.add(managerId);
    }

    final results = await _database.query(
      table: 'leave_requests',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'JSON_EXTRACT(data, "\$.start_date.value")',
      limit: limit,
    );

    return results.map((data) => CRDTLeaveRequest.fromCRDTJson(data)).toList();
  }

  /// Get leave requests within date range
  Future<List<CRDTLeaveRequest>> getLeaveRequestsInDateRange(
    DateTime startDate,
    DateTime endDate, {
    List<String>? employeeIds,
    String? status,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];

    conditions.add('JSON_EXTRACT(data, "\$.is_deleted") = ?');
    args.add(false);

    // Check for date overlap
    conditions.add('''
      (datetime(JSON_EXTRACT(data, "\$.start_date.value") / 1000, 'unixepoch') <= datetime(?) AND
       datetime(JSON_EXTRACT(data, "\$.end_date.value") / 1000, 'unixepoch') >= datetime(?))
    ''');
    args.add(endDate.toIso8601String());
    args.add(startDate.toIso8601String());

    if (employeeIds != null && employeeIds.isNotEmpty) {
      final placeholders = employeeIds.map((_) => '?').join(',');
      conditions
          .add('JSON_EXTRACT(data, "\$.employee_id.value") IN ($placeholders)');
      args.addAll(employeeIds);
    }

    if (status != null) {
      conditions.add('JSON_EXTRACT(data, "\$.status.value") = ?');
      args.add(status);
    }

    final results = await _database.query(
      table: 'leave_requests',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'JSON_EXTRACT(data, "\$.start_date.value")',
    );

    return results.map((data) => CRDTLeaveRequest.fromCRDTJson(data)).toList();
  }

  /// Update leave request
  Future<void> updateLeaveRequest(CRDTLeaveRequest leaveRequest) async {
    await _database.update(
      table: 'leave_requests',
      id: leaveRequest.id,
      data: leaveRequest.toCRDTJson(),
    );
  }

  /// Delete leave request (soft delete)
  Future<void> deleteLeaveRequest(String leaveRequestId) async {
    final leaveRequest = await getLeaveRequest(leaveRequestId);
    if (leaveRequest == null) return;

    leaveRequest.isDeleted = true;
    leaveRequest.updatedAt = HLCTimestamp.now(_database.nodeId);

    await updateLeaveRequest(leaveRequest);
  }

  /// Get leave statistics for an employee
  Future<Map<String, dynamic>> getLeaveStatisticsForEmployee(
    String employeeId,
    int year,
  ) async {
    final yearStart = DateTime(year, 1, 1);
    final yearEnd = DateTime(year, 12, 31);

    final leaveRequests = await getLeaveRequestsForEmployee(
      employeeId,
      status: 'taken',
      fromDate: yearStart,
      toDate: yearEnd,
    );

    final leaveByType = <String, double>{};
    double totalLeaveTaken = 0.0;

    for (final request in leaveRequests) {
      final type = request.leaveType.value;
      final days = request.leaveDuration;

      leaveByType[type] = (leaveByType[type] ?? 0.0) + days;
      totalLeaveTaken += days;
    }

    return {
      'year': year,
      'total_leave_taken': totalLeaveTaken,
      'leave_by_type': leaveByType,
      'total_requests': leaveRequests.length,
    };
  }

  // ============================================================================
  // ATTENDANCE RECORD OPERATIONS
  // ============================================================================

  /// Save attendance record to database
  Future<void> saveAttendanceRecord(
      CRDTAttendanceRecord attendanceRecord) async {
    await _database.insert(
      table: 'attendance_records',
      data: attendanceRecord.toCRDTJson(),
      id: attendanceRecord.id,
    );
  }

  /// Get attendance record by ID
  Future<CRDTAttendanceRecord?> getAttendanceRecord(
      String attendanceRecordId) async {
    final data = await _database.get('attendance_records', attendanceRecordId);
    if (data == null) return null;

    return CRDTAttendanceRecord.fromCRDTJson(data);
  }

  /// Get attendance record for employee on specific date
  Future<CRDTAttendanceRecord?> getAttendanceRecordForDate(
    String employeeId,
    DateTime date,
  ) async {
    final targetDate = DateTime(date.year, date.month, date.day);

    final results = await _database.query(
      table: 'attendance_records',
      where: '''
        JSON_EXTRACT(data, "\$.employee_id.value") = ? AND
        JSON_EXTRACT(data, "\$.is_deleted") = ? AND
        date(JSON_EXTRACT(data, "\$.date.value") / 1000, 'unixepoch') = date(?)
      ''',
      whereArgs: [employeeId, false, targetDate.toIso8601String()],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return CRDTAttendanceRecord.fromCRDTJson(results.first);
  }

  /// Get attendance records for an employee within date range
  Future<List<CRDTAttendanceRecord>> getAttendanceRecordsForEmployee(
    String employeeId, {
    required DateTime startDate,
    required DateTime endDate,
    String? status,
    int? limit,
    int? offset,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];

    conditions.add('JSON_EXTRACT(data, "\$.employee_id.value") = ?');
    args.add(employeeId);

    conditions.add('JSON_EXTRACT(data, "\$.is_deleted") = ?');
    args.add(false);

    conditions.add('''
      datetime(JSON_EXTRACT(data, "\$.date.value") / 1000, 'unixepoch') >= datetime(?) AND
      datetime(JSON_EXTRACT(data, "\$.date.value") / 1000, 'unixepoch') <= datetime(?)
    ''');
    args.add(startDate.toIso8601String());
    args.add(endDate.toIso8601String());

    if (status != null) {
      conditions.add('JSON_EXTRACT(data, "\$.status.value") = ?');
      args.add(status);
    }

    final results = await _database.query(
      table: 'attendance_records',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'JSON_EXTRACT(data, "\$.date.value")',
      limit: limit,
      offset: offset,
    );

    return results
        .map((data) => CRDTAttendanceRecord.fromCRDTJson(data))
        .toList();
  }

  /// Get team attendance for a specific date
  Future<Map<String, CRDTAttendanceRecord?>> getTeamAttendanceForDate(
    List<String> employeeIds,
    DateTime date,
  ) async {
    final result = <String, CRDTAttendanceRecord?>{};

    if (employeeIds.isEmpty) return result;

    final placeholders = employeeIds.map((_) => '?').join(',');
    final targetDate = DateTime(date.year, date.month, date.day);

    final results = await _database.query(
      table: 'attendance_records',
      where: '''
        JSON_EXTRACT(data, "\$.employee_id.value") IN ($placeholders) AND
        JSON_EXTRACT(data, "\$.is_deleted") = ? AND
        date(JSON_EXTRACT(data, "\$.date.value") / 1000, 'unixepoch') = date(?)
      ''',
      whereArgs: [...employeeIds, false, targetDate.toIso8601String()],
    );

    // Initialize all employees as null (no attendance record)
    for (final employeeId in employeeIds) {
      result[employeeId] = null;
    }

    // Fill in actual records
    for (final data in results) {
      final record = CRDTAttendanceRecord.fromCRDTJson(data);
      result[record.employeeId.value] = record;
    }

    return result;
  }

  /// Update attendance record
  Future<void> updateAttendanceRecord(
      CRDTAttendanceRecord attendanceRecord) async {
    await _database.update(
      table: 'attendance_records',
      id: attendanceRecord.id,
      data: attendanceRecord.toCRDTJson(),
    );
  }

  /// Delete attendance record (soft delete)
  Future<void> deleteAttendanceRecord(String attendanceRecordId) async {
    final record = await getAttendanceRecord(attendanceRecordId);
    if (record == null) return;

    record.isDeleted = true;
    record.updatedAt = HLCTimestamp.now(_database.nodeId);

    await updateAttendanceRecord(record);
  }

  /// Get attendance statistics for an employee
  Future<Map<String, dynamic>> getAttendanceStatisticsForEmployee(
    String employeeId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final records = await getAttendanceRecordsForEmployee(
      employeeId,
      startDate: startDate,
      endDate: endDate,
    );

    int presentDays = 0;
    int absentDays = 0;
    int leaveDays = 0;
    int lateDays = 0;
    int earlyDepartureDays = 0;
    int overtimeDays = 0;
    double totalHours = 0.0;
    double overtimeHours = 0.0;

    for (final record in records) {
      switch (record.status.value) {
        case 'present':
          presentDays++;
          if (record.isLate.value) lateDays++;
          if (record.isEarlyDeparture.value) earlyDepartureDays++;
          if (record.isOvertime.value) overtimeDays++;
          totalHours += record.actualHours.value;
          overtimeHours += record.overtimeHours.value;
          break;
        case 'absent':
          absentDays++;
          break;
        case 'on_leave':
          leaveDays++;
          break;
      }
    }

    final workingDays = EmployeeUtils.calculateWorkingDays(startDate, endDate);
    final attendanceRate =
        workingDays > 0 ? (presentDays / workingDays) * 100 : 0.0;

    return {
      'period': {
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'working_days': workingDays,
      },
      'attendance': {
        'present_days': presentDays,
        'absent_days': absentDays,
        'leave_days': leaveDays,
        'attendance_rate': attendanceRate.round(),
      },
      'punctuality': {
        'late_days': lateDays,
        'early_departure_days': earlyDepartureDays,
        'punctuality_rate': presentDays > 0
            ? ((presentDays - lateDays) / presentDays) * 100
            : 0.0,
      },
      'working_hours': {
        'total_hours': totalHours.round(),
        'overtime_hours': overtimeHours.round(),
        'overtime_days': overtimeDays,
        'average_hours_per_day':
            presentDays > 0 ? totalHours / presentDays : 0.0,
      },
    };
  }

  /// Get attendance records requiring approval
  Future<List<CRDTAttendanceRecord>> getAttendanceRecordsRequiringApproval({
    String? managerId,
    int? limit,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];

    conditions.add('JSON_EXTRACT(data, "\$.requires_approval.value") = ?');
    args.add(true);

    conditions.add('JSON_EXTRACT(data, "\$.is_approved.value") = ?');
    args.add(false);

    conditions.add('JSON_EXTRACT(data, "\$.is_deleted") = ?');
    args.add(false);

    if (managerId != null) {
      conditions.add('JSON_EXTRACT(data, "\$.manager_id.value") = ?');
      args.add(managerId);
    }

    final results = await _database.query(
      table: 'attendance_records',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'JSON_EXTRACT(data, "\$.date.value") DESC',
      limit: limit,
    );

    return results
        .map((data) => CRDTAttendanceRecord.fromCRDTJson(data))
        .toList();
  }

  // ============================================================================
  // PERFORMANCE RECORD OPERATIONS
  // ============================================================================

  /// Save performance record
  Future<void> savePerformanceRecord(
      CRDTPerformanceRecord performanceRecord) async {
    await _database.insert(
      table: 'performance_records',
      data: performanceRecord.toCRDTJson(),
      id: performanceRecord.id,
    );
  }

  /// Get performance record by ID
  Future<CRDTPerformanceRecord?> getPerformanceRecord(String recordId) async {
    final data = await _database.get('performance_records', recordId);
    if (data == null) return null;

    return CRDTPerformanceRecord.fromCRDTJson(data);
  }

  /// Get performance records for an employee
  Future<List<CRDTPerformanceRecord>> getPerformanceRecordsForEmployee(
    String employeeId, {
    String? status,
    String? reviewType,
    int? limit,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];

    conditions.add('JSON_EXTRACT(data, "\$.employee_id.value") = ?');
    args.add(employeeId);

    conditions.add('JSON_EXTRACT(data, "\$.is_deleted") = ?');
    args.add(false);

    if (status != null) {
      conditions.add('JSON_EXTRACT(data, "\$.status.value") = ?');
      args.add(status);
    }

    if (reviewType != null) {
      conditions.add('JSON_EXTRACT(data, "\$.review_type.value") = ?');
      args.add(reviewType);
    }

    final results = await _database.query(
      table: 'performance_records',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'JSON_EXTRACT(data, "\$.review_start_date.value") DESC',
      limit: limit,
    );

    return results
        .map((data) => CRDTPerformanceRecord.fromCRDTJson(data))
        .toList();
  }

  /// Update performance record
  Future<void> updatePerformanceRecord(
      CRDTPerformanceRecord performanceRecord) async {
    await _database.update(
      table: 'performance_records',
      id: performanceRecord.id,
      data: performanceRecord.toCRDTJson(),
    );
  }

  /// Save employee goal
  Future<void> saveEmployeeGoal(CRDTEmployeeGoal goal) async {
    await _database.insert(
      table: 'employee_goals',
      data: goal.toCRDTJson(),
      id: goal.id,
    );
  }

  /// Get goals for an employee
  Future<List<CRDTEmployeeGoal>> getGoalsForEmployee(
    String employeeId, {
    String? status,
    String? priority,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];

    conditions.add('JSON_EXTRACT(data, "\$.employee_id.value") = ?');
    args.add(employeeId);

    conditions.add('JSON_EXTRACT(data, "\$.is_deleted") = ?');
    args.add(false);

    if (status != null) {
      conditions.add('JSON_EXTRACT(data, "\$.status.value") = ?');
      args.add(status);
    }

    if (priority != null) {
      conditions.add('JSON_EXTRACT(data, "\$.priority.value") = ?');
      args.add(priority);
    }

    final results = await _database.query(
      table: 'employee_goals',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'JSON_EXTRACT(data, "\$.target_date.value")',
    );

    return results.map((data) => CRDTEmployeeGoal.fromCRDTJson(data)).toList();
  }

  /// Update employee goal
  Future<void> updateEmployeeGoal(CRDTEmployeeGoal goal) async {
    await _database.update(
      table: 'employee_goals',
      id: goal.id,
      data: goal.toCRDTJson(),
    );
  }

  // ============================================================================
  // BATCH OPERATIONS
  // ============================================================================

  /// Batch insert attendance records
  Future<void> batchInsertAttendanceRecords(
      List<CRDTAttendanceRecord> records) async {
    await _database.batchInsert(
      table: 'attendance_records',
      records: records
          .map((record) => {
                'id': record.id,
                'data': record.toCRDTJson(),
              })
          .toList(),
    );
  }

  /// Batch insert leave requests
  Future<void> batchInsertLeaveRequests(List<CRDTLeaveRequest> requests) async {
    await _database.batchInsert(
      table: 'leave_requests',
      records: requests
          .map((request) => {
                'id': request.id,
                'data': request.toCRDTJson(),
              })
          .toList(),
    );
  }
}
