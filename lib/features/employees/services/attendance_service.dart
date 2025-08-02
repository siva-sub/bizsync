import 'dart:async';
import '../../../core/crdt/hybrid_logical_clock.dart';
import '../../../core/utils/uuid_generator.dart';
import '../../../core/services/notification_service.dart';
import '../models/index.dart';

/// Attendance Management Service for tracking employee attendance
class AttendanceService {
  final NotificationService _notificationService;
  final String _nodeId = UuidGenerator.generateId();
  
  // In-memory storage for demo
  final Map<String, CRDTAttendanceRecord> _attendanceRecords = {};
  
  // Standard work schedule
  static const Duration standardWorkDay = Duration(hours: 8);
  static const Duration lunchBreak = Duration(hours: 1);
  static const int standardWorkStartHour = 9; // 9 AM
  static const int standardWorkEndHour = 18; // 6 PM
  
  AttendanceService(this._notificationService);
  
  /// Clock in employee
  Future<CRDTAttendanceRecord> clockIn({
    required String employeeId,
    DateTime? clockInTime,
    String? location,
    double? latitude,
    double? longitude,
    String? deviceId,
    Map<String, dynamic>? metadata,
  }) async {
    final now = clockInTime ?? DateTime.now();
    final date = DateTime(now.year, now.month, now.day);
    
    // Check if already clocked in for today
    final existingRecord = getAttendanceRecord(employeeId, date);
    if (existingRecord != null && existingRecord.clockInTime.value != null) {
      throw Exception('Employee already clocked in for today');
    }
    
    final timestamp = HLCTimestamp.now(_nodeId);
    
    CRDTAttendanceRecord record;
    if (existingRecord != null) {
      // Update existing record
      record = existingRecord;
    } else {
      // Create new record
      record = CRDTAttendanceRecord(
        id: UuidGenerator.generateId(),
        nodeId: _nodeId,
        createdAt: timestamp,
        updatedAt: timestamp,
        version: VectorClock(_nodeId),
        empId: employeeId,
        attendanceDate: date,
        scheduled: 8.0, // Standard 8-hour day
      );
      _attendanceRecords[record.id] = record;
    }
    
    record.clockIn(
      time: now,
      location: location,
      latitude: latitude,
      longitude: longitude,
      device: deviceId,
      timestamp: timestamp,
    );
    
    // Check if late
    final standardStartTime = DateTime(date.year, date.month, date.day, standardWorkStartHour);
    final isLate = now.isAfter(standardStartTime.add(const Duration(minutes: 15))); // 15 min grace period
    
    if (isLate) {
      record.isLate.setValue(true, timestamp);
      
      // Send late notification
      await _notificationService.sendNotification(
        title: 'Late Clock-in',
        message: 'Employee clocked in late at ${_formatTime(now)}',
        type: 'late_clock_in',
        data: {
          'employee_id': employeeId,
          'clock_in_time': now.toIso8601String(),
          'minutes_late': now.difference(standardStartTime).inMinutes,
        },
      );
    }
    
    return record;
  }
  
  /// Clock out employee
  Future<CRDTAttendanceRecord> clockOut({
    required String employeeId,
    DateTime? clockOutTime,
    String? location,
    double? latitude,
    double? longitude,
    Map<String, dynamic>? metadata,
  }) async {
    final now = clockOutTime ?? DateTime.now();
    final date = DateTime(now.year, now.month, now.day);
    
    final record = getAttendanceRecord(employeeId, date);
    if (record == null) {
      throw Exception('No attendance record found for today. Please clock in first.');
    }
    
    if (record.clockInTime.value == null) {
      throw Exception('Employee has not clocked in yet');
    }
    
    if (record.clockOutTime.value != null) {
      throw Exception('Employee already clocked out for today');
    }
    
    final timestamp = HLCTimestamp.now(_nodeId);
    
    record.clockOut(
      time: now,
      location: location,
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
    );
    
    // Check if early departure
    final standardEndTime = DateTime(date.year, date.month, date.day, standardWorkEndHour);
    final isEarlyDeparture = now.isBefore(standardEndTime.subtract(const Duration(minutes: 15)));
    
    if (isEarlyDeparture) {
      record.isEarlyDeparture.setValue(true, timestamp);
      
      // Send notification
      await _notificationService.sendNotification(
        title: 'Early Departure',
        message: 'Employee clocked out early at ${_formatTime(now)}',
        type: 'early_departure',
        data: {
          'employee_id': employeeId,
          'clock_out_time': now.toIso8601String(),
          'minutes_early': standardEndTime.difference(now).inMinutes,
        },
      );
    }
    
    // Calculate overtime
    final hoursWorked = record.totalHoursWorked;
    if (hoursWorked > 8.0) {
      record.isOvertime.setValue(true, timestamp);
      record.updateWorkingHours(
        regular: 8.0,
        overtime: hoursWorked - 8.0,
        timestamp: timestamp,
      );
    } else {
      record.updateWorkingHours(
        regular: hoursWorked,
        overtime: 0.0,
        timestamp: timestamp,
      );
    }
    
    return record;
  }
  
  /// Start break
  Future<void> startBreak(String employeeId, {DateTime? breakTime}) async {
    final now = breakTime ?? DateTime.now();
    final date = DateTime(now.year, now.month, now.day);
    
    final record = getAttendanceRecord(employeeId, date);
    if (record == null) {
      throw Exception('No attendance record found for today');
    }
    
    if (record.clockInTime.value == null) {
      throw Exception('Employee has not clocked in yet');
    }
    
    if (record.breakStartTime.value != null && record.breakEndTime.value == null) {
      throw Exception('Break already started');
    }
    
    record.startBreak(now, HLCTimestamp.now(_nodeId));
  }
  
  /// End break
  Future<void> endBreak(String employeeId, {DateTime? breakTime}) async {
    final now = breakTime ?? DateTime.now();
    final date = DateTime(now.year, now.month, now.day);
    
    final record = getAttendanceRecord(employeeId, date);
    if (record == null) {
      throw Exception('No attendance record found for today');
    }
    
    if (record.breakStartTime.value == null) {
      throw Exception('Break not started');
    }
    
    if (record.breakEndTime.value != null) {
      throw Exception('Break already ended');
    }
    
    record.endBreak(now, HLCTimestamp.now(_nodeId));
  }
  
  /// Mark employee as absent
  Future<CRDTAttendanceRecord> markAbsent({
    required String employeeId,
    required DateTime date,
    String? reason,
    bool requiresApproval = true,
    Map<String, dynamic>? metadata,
  }) async {
    final attendanceDate = DateTime(date.year, date.month, date.day);
    
    final existingRecord = getAttendanceRecord(employeeId, attendanceDate);
    if (existingRecord != null && existingRecord.status.value != 'absent') {
      throw Exception('Attendance record already exists for this date');
    }
    
    final timestamp = HLCTimestamp.now(_nodeId);
    
    final record = CRDTAttendanceRecord(
      id: UuidGenerator.generateId(),
      nodeId: _nodeId,
      createdAt: timestamp,
      updatedAt: timestamp,
      version: VectorClock(_nodeId),
      empId: employeeId,
      attendanceDate: attendanceDate,
      attendanceStatus: 'absent',
      approval: requiresApproval,
      attendanceComments: reason,
      attendanceMetadata: metadata,
    );
    
    _attendanceRecords[record.id] = record;
    
    // Send notification
    await _notificationService.sendNotification(
      title: 'Employee Absent',
      message: 'Employee marked as absent${reason != null ? ": $reason" : ""}',
      type: 'employee_absent',
      data: {
        'employee_id': employeeId,
        'date': attendanceDate.toIso8601String(),
        'reason': reason,
      },
    );
    
    return record;
  }
  
  /// Mark employee on leave
  Future<CRDTAttendanceRecord> markOnLeave({
    required String employeeId,
    required DateTime date,
    required String leaveType,
    String? leaveRequestId,
    Map<String, dynamic>? metadata,
  }) async {
    final attendanceDate = DateTime(date.year, date.month, date.day);
    final timestamp = HLCTimestamp.now(_nodeId);
    
    final record = CRDTAttendanceRecord(
      id: UuidGenerator.generateId(),
      nodeId: _nodeId,
      createdAt: timestamp,
      updatedAt: timestamp,
      version: VectorClock(_nodeId),
      empId: employeeId,
      attendanceDate: attendanceDate,
      attendanceStatus: 'on_leave',
      attendanceComments: 'On $leaveType leave',
      attendanceMetadata: {
        'leave_type': leaveType,
        'leave_request_id': leaveRequestId,
        ...?metadata,
      },
    );
    
    _attendanceRecords[record.id] = record;
    return record;
  }
  
  /// Get attendance record for a specific date
  CRDTAttendanceRecord? getAttendanceRecord(String employeeId, DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);
    
    return _attendanceRecords.values
        .where((record) => 
            record.employeeId.value == employeeId &&
            !record.isDeleted &&
            _isSameDate(record.date.value, targetDate))
        .firstOrNull;
  }
  
  /// Get attendance records for an employee within a date range
  List<CRDTAttendanceRecord> getAttendanceRecords({
    required String employeeId,
    required DateTime startDate,
    required DateTime endDate,
    String? status,
  }) {
    return _attendanceRecords.values.where((record) {
      if (record.employeeId.value != employeeId) return false;
      if (record.isDeleted) return false;
      if (record.date.value.isBefore(startDate)) return false;
      if (record.date.value.isAfter(endDate)) return false;
      if (status != null && record.status.value != status) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.date.value.compareTo(b.date.value));
  }
  
  /// Get team attendance for a specific date
  Map<String, CRDTAttendanceRecord?> getTeamAttendance({
    required List<String> employeeIds,
    required DateTime date,
  }) {
    final result = <String, CRDTAttendanceRecord?>{};
    
    for (final employeeId in employeeIds) {
      result[employeeId] = getAttendanceRecord(employeeId, date);
    }
    
    return result;
  }
  
  /// Get attendance summary for an employee
  Map<String, dynamic> getAttendanceSummary({
    required String employeeId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final records = getAttendanceRecords(
      employeeId: employeeId,
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
    final attendanceRate = workingDays > 0 ? (presentDays / workingDays) * 100 : 0.0;
    
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
        'punctuality_rate': presentDays > 0 ? ((presentDays - lateDays) / presentDays) * 100 : 0.0,
      },
      'working_hours': {
        'total_hours': totalHours.round(),
        'overtime_hours': overtimeHours.round(),
        'overtime_days': overtimeDays,
        'average_hours_per_day': presentDays > 0 ? totalHours / presentDays : 0.0,
      },
    };
  }
  
  /// Get team attendance summary
  Map<String, dynamic> getTeamAttendanceSummary({
    required List<String> employeeIds,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final teamSummary = <String, dynamic>{
      'total_employees': employeeIds.length,
      'present_today': 0,
      'absent_today': 0,
      'on_leave_today': 0,
      'late_today': 0,
      'overtime_today': 0,
      'average_attendance_rate': 0.0,
      'employee_summaries': <String, Map<String, dynamic>>{},
    };
    
    double totalAttendanceRate = 0.0;
    final today = DateTime.now();
    
    for (final employeeId in employeeIds) {
      final summary = getAttendanceSummary(
        employeeId: employeeId,
        startDate: startDate,
        endDate: endDate,
      );
      
      teamSummary['employee_summaries'][employeeId] = summary;
      totalAttendanceRate += summary['attendance']['attendance_rate'];
      
      // Today's attendance
      final todayRecord = getAttendanceRecord(employeeId, today);
      if (todayRecord != null) {
        switch (todayRecord.status.value) {
          case 'present':
            teamSummary['present_today']++;
            if (todayRecord.isLate.value) teamSummary['late_today']++;
            if (todayRecord.isOvertime.value) teamSummary['overtime_today']++;
            break;
          case 'absent':
            teamSummary['absent_today']++;
            break;
          case 'on_leave':
            teamSummary['on_leave_today']++;
            break;
        }
      }
    }
    
    teamSummary['average_attendance_rate'] = 
        employeeIds.isNotEmpty ? totalAttendanceRate / employeeIds.length : 0.0;
    
    return teamSummary;
  }
  
  /// Approve attendance record
  Future<void> approveAttendance({
    required String attendanceRecordId,
    required String approverId,
    String? comments,
  }) async {
    final record = _attendanceRecords[attendanceRecordId];
    if (record == null) {
      throw Exception('Attendance record not found');
    }
    
    record.approve(
      approverId: approverId,
      approverComments: comments,
      timestamp: HLCTimestamp.now(_nodeId),
    );
    
    await _notificationService.sendNotification(
      title: 'Attendance Approved',
      message: 'Attendance record has been approved',
      type: 'attendance_approved',
      data: {
        'attendance_record_id': attendanceRecordId,
        'employee_id': record.employeeId.value,
        'approver_id': approverId,
      },
    );
  }
  
  /// Generate attendance report
  Map<String, dynamic> generateAttendanceReport({
    required List<String> employeeIds,
    required DateTime startDate,
    required DateTime endDate,
    String? department,
  }) {
    final report = <String, dynamic>{
      'report_info': {
        'generated_at': DateTime.now().toIso8601String(),
        'period_start': startDate.toIso8601String(),
        'period_end': endDate.toIso8601String(),
        'department': department,
        'employee_count': employeeIds.length,
      },
      'summary': getTeamAttendanceSummary(
        employeeIds: employeeIds,
        startDate: startDate,
        endDate: endDate,
      ),
      'detailed_records': <String, List<Map<String, dynamic>>>{},
    };
    
    for (final employeeId in employeeIds) {
      final records = getAttendanceRecords(
        employeeId: employeeId,
        startDate: startDate,
        endDate: endDate,
      );
      
      report['detailed_records'][employeeId] = records
          .map((record) => record.toJson())
          .toList();
    }
    
    return report;
  }
  
  // ============================================================================
  // PRIVATE HELPER METHODS
  // ============================================================================
  
  bool _isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }
  
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// Extension to add null safety helper
extension on Iterable<CRDTAttendanceRecord> {
  CRDTAttendanceRecord? get firstOrNull {
    return isEmpty ? null : first;
  }
}