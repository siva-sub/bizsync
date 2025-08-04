import 'dart:async';
import '../../../core/crdt/hybrid_logical_clock.dart';
import '../../../core/utils/uuid_generator.dart';
import '../../../core/services/notification_service.dart';
import '../models/index.dart';

/// Leave Management Service for handling leave requests and approvals
class LeaveManagementService {
  final NotificationService _notificationService;
  final String _nodeId = UuidGenerator.generateId();

  // In-memory storage for demo
  final Map<String, CRDTLeaveRequest> _leaveRequests = {};
  int _leaveSequence = 1;

  LeaveManagementService(this._notificationService);

  /// Create a new leave request
  Future<CRDTLeaveRequest> createLeaveRequest({
    required String employeeId,
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required double daysRequested,
    double hoursRequested = 0.0,
    String? reason,
    String? description,
    bool isHalfDay = false,
    String? halfDayPeriod,
    bool isEmergency = false,
    String? medicalCertificateNumber,
    String? doctorName,
    String? clinicName,
    DateTime? mcStartDate,
    String? contactNumber,
    String? contactAddress,
    String? emergencyContact,
    String? handoverTo,
    String? handoverNotes,
    Map<String, dynamic>? metadata,
  }) async {
    final requestNumber =
        EmployeeUtils.generateLeaveRequestNumber(_leaveSequence++);
    final timestamp = HLCTimestamp.now(_nodeId);

    final leaveRequest = CRDTLeaveRequest(
      id: UuidGenerator.generateId(),
      nodeId: _nodeId,
      createdAt: timestamp,
      updatedAt: timestamp,
      version: VectorClock(_nodeId),
      empId: employeeId,
      requestNumber: requestNumber,
      type: leaveType,
      start: startDate,
      end: endDate,
      days: daysRequested,
      hours: hoursRequested,
      leaveReason: reason,
      leaveDescription: description,
      halfDay: isHalfDay,
      halfDayTime: halfDayPeriod,
      emergency: isEmergency,
      mcNumber: medicalCertificateNumber,
      doctor: doctorName,
      clinic: clinicName,
      mcStart: mcStartDate,
      contact: contactNumber,
      contactAddr: contactAddress,
      emergencyContactInfo: emergencyContact,
      handover: handoverTo,
      handoverNote: handoverNotes,
      leaveMetadata: metadata,
    );

    _leaveRequests[leaveRequest.id] = leaveRequest;

    // Send notification to manager (if not emergency leave)
    if (!isEmergency) {
      await _notificationService.sendNotification(
        title: 'New Leave Request',
        message: 'Leave request ${requestNumber} submitted for approval',
        type: 'leave_request_submitted',
        data: {
          'leave_request_id': leaveRequest.id,
          'employee_id': employeeId,
          'leave_type': leaveType,
          'days_requested': daysRequested,
        },
      );
    }

    return leaveRequest;
  }

  /// Get leave request by ID
  CRDTLeaveRequest? getLeaveRequest(String leaveRequestId) {
    return _leaveRequests[leaveRequestId];
  }

  /// Get leave requests for an employee
  List<CRDTLeaveRequest> getLeaveRequestsForEmployee(
    String employeeId, {
    String? status,
    String? leaveType,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    return _leaveRequests.values.where((request) {
      if (request.employeeId.value != employeeId) return false;
      if (request.isDeleted) return false;
      if (status != null && request.status.value != status) return false;
      if (leaveType != null && request.leaveType.value != leaveType)
        return false;
      if (fromDate != null && request.startDate.value.isBefore(fromDate))
        return false;
      if (toDate != null && request.endDate.value.isAfter(toDate)) return false;
      return true;
    }).toList()
      ..sort((a, b) =>
          b.createdAt.physicalTime.compareTo(a.createdAt.physicalTime));
  }

  /// Get pending leave requests for approval
  List<CRDTLeaveRequest> getPendingLeaveRequests({String? managerId}) {
    return _leaveRequests.values.where((request) {
      if (request.isDeleted) return false;
      if (!request.isPendingApproval) return false;
      if (managerId != null && request.managerId.value != managerId)
        return false;
      return true;
    }).toList()
      ..sort((a, b) => a.startDate.value.compareTo(b.startDate.value));
  }

  /// Submit leave request for approval
  Future<void> submitLeaveRequestForApproval(
    String leaveRequestId,
    String managerId,
  ) async {
    final request = _leaveRequests[leaveRequestId];
    if (request == null) {
      throw Exception('Leave request not found: $leaveRequestId');
    }

    if (request.status.value != 'draft') {
      throw Exception(
          'Only draft leave requests can be submitted for approval');
    }

    final timestamp = HLCTimestamp.now(_nodeId);
    request.submitForApproval(managerId, timestamp);

    // Send notification to manager
    await _notificationService.sendNotification(
      title: 'Leave Request Pending Approval',
      message:
          'Leave request ${request.leaveRequestNumber.value} is pending your approval',
      type: 'leave_approval_required',
      data: {
        'leave_request_id': leaveRequestId,
        'employee_id': request.employeeId.value,
        'manager_id': managerId,
        'leave_type': request.leaveType.value,
        'start_date': request.startDate.value.toIso8601String(),
        'end_date': request.endDate.value.toIso8601String(),
        'days_requested': request.daysRequested.value,
      },
    );
  }

  /// Approve leave request
  Future<void> approveLeaveRequest(
    String leaveRequestId,
    String approverId, {
    String? comments,
  }) async {
    final request = _leaveRequests[leaveRequestId];
    if (request == null) {
      throw Exception('Leave request not found: $leaveRequestId');
    }

    if (!request.isPendingApproval) {
      throw Exception('Leave request is not pending approval');
    }

    final timestamp = HLCTimestamp.now(_nodeId);
    request.approveByManager(
      approverId: approverId,
      comments: comments,
      timestamp: timestamp,
    );

    // Send notification to employee
    await _notificationService.sendNotification(
      title: 'Leave Request Approved',
      message:
          'Your leave request ${request.leaveRequestNumber.value} has been approved',
      type: 'leave_approved',
      data: {
        'leave_request_id': leaveRequestId,
        'employee_id': request.employeeId.value,
        'approver_id': approverId,
        'comments': comments,
      },
    );
  }

  /// Reject leave request
  Future<void> rejectLeaveRequest(
    String leaveRequestId,
    String approverId, {
    String? comments,
  }) async {
    final request = _leaveRequests[leaveRequestId];
    if (request == null) {
      throw Exception('Leave request not found: $leaveRequestId');
    }

    if (!request.isPendingApproval) {
      throw Exception('Leave request is not pending approval');
    }

    final timestamp = HLCTimestamp.now(_nodeId);
    request.rejectByManager(
      approverId: approverId,
      comments: comments,
      timestamp: timestamp,
    );

    // Send notification to employee
    await _notificationService.sendNotification(
      title: 'Leave Request Rejected',
      message:
          'Your leave request ${request.leaveRequestNumber.value} has been rejected',
      type: 'leave_rejected',
      data: {
        'leave_request_id': leaveRequestId,
        'employee_id': request.employeeId.value,
        'approver_id': approverId,
        'comments': comments,
      },
    );
  }

  /// Cancel leave request
  Future<void> cancelLeaveRequest(String leaveRequestId, String reason) async {
    final request = _leaveRequests[leaveRequestId];
    if (request == null) {
      throw Exception('Leave request not found: $leaveRequestId');
    }

    if (request.status.value == 'taken' ||
        request.status.value == 'cancelled') {
      throw Exception(
          'Cannot cancel leave request with status: ${request.status.value}');
    }

    final timestamp = HLCTimestamp.now(_nodeId);
    request.updateStatus('cancelled', timestamp);

    // Send notification
    await _notificationService.sendNotification(
      title: 'Leave Request Cancelled',
      message:
          'Leave request ${request.leaveRequestNumber.value} has been cancelled. Reason: $reason',
      type: 'leave_cancelled',
      data: {
        'leave_request_id': leaveRequestId,
        'employee_id': request.employeeId.value,
        'reason': reason,
      },
    );
  }

  /// Check leave balance availability
  bool checkLeaveBalanceAvailability(
    CRDTEmployee employee,
    String leaveType,
    double daysRequested,
  ) {
    switch (leaveType.toLowerCase()) {
      case 'annual':
        return employee.annualLeaveBalance.value >= daysRequested;
      case 'sick':
        return employee.sickLeaveBalance.value >= daysRequested;
      case 'maternity':
        return employee.maternitylLeaveBalance.value >= daysRequested;
      case 'paternity':
        return employee.paternitylLeaveBalance.value >= daysRequested;
      case 'compassionate':
      case 'child_care':
      case 'infant_care':
        return employee.compassionateLeaveBalance.value >= daysRequested;
      case 'unpaid':
        return true; // Unpaid leave doesn't affect balance
      default:
        return false; // Unknown leave type
    }
  }

  /// Deduct leave balance when leave is taken
  Future<void> deductLeaveBalance(
    CRDTEmployee employee,
    String leaveType,
    double daysTaken,
  ) async {
    switch (leaveType.toLowerCase()) {
      case 'annual':
        employee.adjustLeaveBalance(annualLeaveAdjustment: -daysTaken.round());
        break;
      case 'sick':
        employee.adjustLeaveBalance(sickLeaveAdjustment: -daysTaken.round());
        break;
      case 'maternity':
        employee.adjustLeaveBalance(
            maternityLeaveAdjustment: -daysTaken.round());
        break;
      case 'paternity':
        employee.adjustLeaveBalance(
            paternityLeaveAdjustment: -daysTaken.round());
        break;
      case 'compassionate':
      case 'child_care':
      case 'infant_care':
        employee.adjustLeaveBalance(
            compassionateLeaveAdjustment: -daysTaken.round());
        break;
      // Unpaid leave doesn't affect balance
    }
  }

  /// Mark leave as taken
  Future<void> markLeaveAsTaken(String leaveRequestId) async {
    final request = _leaveRequests[leaveRequestId];
    if (request == null) {
      throw Exception('Leave request not found: $leaveRequestId');
    }

    if (!request.isApproved) {
      throw Exception('Only approved leave requests can be marked as taken');
    }

    final timestamp = HLCTimestamp.now(_nodeId);
    request.updateStatus('taken', timestamp);
  }

  /// Get leave calendar for a period
  Map<String, List<Map<String, dynamic>>> getLeaveCalendar({
    required DateTime startDate,
    required DateTime endDate,
    String? department,
    List<String>? employeeIds,
  }) {
    final calendar = <String, List<Map<String, dynamic>>>{};

    final relevantRequests = _leaveRequests.values.where((request) {
      if (request.isDeleted) return false;
      if (request.status.value != 'approved' && request.status.value != 'taken')
        return false;

      // Check date overlap
      if (request.endDate.value.isBefore(startDate) ||
          request.startDate.value.isAfter(endDate)) {
        return false;
      }

      // Filter by employee IDs if specified
      if (employeeIds != null &&
          !employeeIds.contains(request.employeeId.value)) {
        return false;
      }

      return true;
    });

    for (final request in relevantRequests) {
      var currentDate = request.startDate.value;
      final endDate = request.endDate.value;

      while (currentDate.isBefore(endDate) ||
          currentDate.isAtSameMomentAs(endDate)) {
        final dateKey = currentDate.toIso8601String().substring(0, 10);

        calendar[dateKey] ??= [];
        calendar[dateKey]!.add({
          'leave_request_id': request.id,
          'employee_id': request.employeeId.value,
          'leave_type': request.leaveType.value,
          'is_half_day': request.isHalfDay.value,
          'half_day_period': request.halfDayPeriod.value,
          'status': request.status.value,
        });

        currentDate = currentDate.add(const Duration(days: 1));
      }
    }

    return calendar;
  }

  /// Get leave balance summary for an employee
  Map<String, dynamic> getLeaveBalanceSummary(CRDTEmployee employee) {
    // Calculate leave taken this year
    final thisYear = DateTime.now().year;
    final yearStart = DateTime(thisYear, 1, 1);
    final yearEnd = DateTime(thisYear, 12, 31);

    final yearLeaveRequests = getLeaveRequestsForEmployee(
      employee.id,
      status: 'taken',
      fromDate: yearStart,
      toDate: yearEnd,
    );

    final leaveTaken = <String, double>{};
    for (final request in yearLeaveRequests) {
      final type = request.leaveType.value;
      leaveTaken[type] = (leaveTaken[type] ?? 0.0) + request.leaveDuration;
    }

    return {
      'balances': {
        'annual_leave': employee.annualLeaveBalance.value,
        'sick_leave': employee.sickLeaveBalance.value,
        'maternity_leave': employee.maternitylLeaveBalance.value,
        'paternity_leave': employee.paternitylLeaveBalance.value,
        'compassionate_leave': employee.compassionateLeaveBalance.value,
        'total_balance': employee.totalLeaveBalance,
      },
      'taken_this_year': leaveTaken,
      'pending_requests':
          getLeaveRequestsForEmployee(employee.id, status: 'submitted').length,
      'approved_requests':
          getLeaveRequestsForEmployee(employee.id, status: 'approved').length,
      'years_of_service':
          EmployeeUtils.calculateYearsOfService(employee.startDate.value),
      'entitlements': {
        'annual_leave_entitlement': EmployeeUtils.getAnnualLeaveEntitlement(
            EmployeeUtils.calculateYearsOfService(employee.startDate.value)),
        'sick_leave_entitlement':
            EmployeeConstants.standardLeaveEntitlements['sick_leave'],
        'maternity_leave_entitlement':
            EmployeeConstants.standardLeaveEntitlements['maternity_leave'],
        'paternity_leave_entitlement':
            EmployeeConstants.standardLeaveEntitlements['paternity_leave'],
      },
    };
  }

  /// Get team leave overview
  Map<String, dynamic> getTeamLeaveOverview({
    required List<String> employeeIds,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    final from = fromDate ?? DateTime.now().subtract(const Duration(days: 30));
    final to = toDate ?? DateTime.now().add(const Duration(days: 30));

    final teamLeaveRequests = _leaveRequests.values.where((request) {
      return employeeIds.contains(request.employeeId.value) &&
          !request.isDeleted &&
          request.startDate.value.isBefore(to) &&
          request.endDate.value.isAfter(from);
    }).toList();

    final overview = <String, dynamic>{
      'total_requests': teamLeaveRequests.length,
      'pending_approval':
          teamLeaveRequests.where((r) => r.isPendingApproval).length,
      'approved_upcoming': teamLeaveRequests
          .where(
              (r) => r.isApproved && r.startDate.value.isAfter(DateTime.now()))
          .length,
      'currently_on_leave': teamLeaveRequests
          .where((r) =>
              r.status.value == 'taken' &&
              r.startDate.value.isBefore(DateTime.now()) &&
              r.endDate.value.isAfter(DateTime.now()))
          .length,
      'leave_types': <String, int>{},
      'by_employee': <String, int>{},
    };

    for (final request in teamLeaveRequests) {
      final type = request.leaveType.value;
      final empId = request.employeeId.value;

      overview['leave_types'][type] = (overview['leave_types'][type] ?? 0) + 1;
      overview['by_employee'][empId] =
          (overview['by_employee'][empId] ?? 0) + 1;
    }

    return overview;
  }
}
