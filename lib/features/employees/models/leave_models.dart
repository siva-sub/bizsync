import 'dart:convert';
import '../../../core/crdt/hybrid_logical_clock.dart';
import '../../../core/crdt/vector_clock.dart';
import '../../../core/crdt/crdt_types.dart';
import '../../../core/crdt/lww_register.dart';
import '../../../core/crdt/or_set.dart';
import '../../../core/database/crdt_models.dart';

/// Leave type enumeration (Singapore-specific)
enum LeaveType {
  annual,         // Annual leave
  sick,           // Sick leave
  maternity,      // Maternity leave (16 weeks)
  paternity,      // Paternity leave (2 weeks)
  adoption,       // Adoption leave
  infantCare,     // Infant care leave
  childCare,      // Childcare leave (6 days per year)
  compassionate,  // Compassionate leave
  hospitalisation, // Hospitalisation leave
  unpaid,         // Unpaid leave
  study,          // Study leave
  emergency,      // Emergency leave
  other           // Other types
}

/// Leave status enumeration
enum LeaveStatus {
  draft,      // Draft application
  submitted,  // Submitted for approval
  approved,   // Approved by manager
  rejected,   // Rejected by manager
  cancelled,  // Cancelled by employee
  taken       // Leave taken
}

/// CRDT-enabled Leave Request model
class CRDTLeaveRequest implements CRDTModel {
  @override
  final String id;
  
  @override
  final String nodeId;
  
  @override
  final HLCTimestamp createdAt;
  
  @override
  HLCTimestamp updatedAt;
  
  @override
  CRDTVectorClock version;
  
  @override
  bool isDeleted;
  
  // Basic leave information
  late LWWRegister<String> employeeId;
  late LWWRegister<String> leaveRequestNumber;
  late LWWRegister<String> leaveType; // annual, sick, maternity, etc.
  late LWWRegister<DateTime> startDate;
  late LWWRegister<DateTime> endDate;
  late LWWRegister<double> daysRequested;
  late LWWRegister<double> hoursRequested;
  late LWWRegister<String> status; // draft, submitted, approved, rejected, cancelled, taken
  
  // Approval workflow
  late LWWRegister<String?> managerId;
  late LWWRegister<String?> hrId;
  late LWWRegister<DateTime?> managerApprovalDate;
  late LWWRegister<DateTime?> hrApprovalDate;
  late LWWRegister<String?> managerComments;
  late LWWRegister<String?> hrComments;
  
  // Leave details
  late LWWRegister<String?> reason;
  late LWWRegister<String?> description;
  late LWWRegister<bool> isHalfDay;
  late LWWRegister<String?> halfDayPeriod; // morning, afternoon
  late LWWRegister<bool> isEmergency;
  
  // Medical certificate (for sick leave)
  late LWWRegister<String?> medicalCertificateNumber;
  late LWWRegister<String?> doctorName;
  late LWWRegister<String?> clinicName;
  late LWWRegister<DateTime?> mcStartDate;
  late LWWRegister<DateTime?> mcEndDate;
  
  // Contact information during leave
  late LWWRegister<String?> contactNumber;
  late LWWRegister<String?> contactAddress;
  late LWWRegister<String?> emergencyContact;
  
  // Handover information
  late LWWRegister<String?> handoverTo;
  late LWWRegister<String?> handoverNotes;
  
  // Attachments as OR-Set
  late ORSet<String> attachmentIds;
  
  // Additional information
  late LWWRegister<Map<String, dynamic>?> metadata;
  
  CRDTLeaveRequest({
    required this.id,
    required this.nodeId,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required String empId,
    required String requestNumber,
    required String type,
    required DateTime start,
    required DateTime end,
    required double days,
    double hours = 0.0,
    String requestStatus = 'draft',
    String? manager,
    String? hr,
    DateTime? managerApproval,
    DateTime? hrApproval,
    String? managerComment,
    String? hrComment,
    String? leaveReason,
    String? leaveDescription,
    bool halfDay = false,
    String? halfDayTime,
    bool emergency = false,
    String? mcNumber,
    String? doctor,
    String? clinic,
    DateTime? mcStart,
    String? contact,
    String? contactAddr,
    String? emergencyContactInfo,
    String? handover,
    String? handoverNote,
    Map<String, dynamic>? leaveMetadata,
    this.isDeleted = false,
  }) {
    // Initialize basic information
    employeeId = LWWRegister(empId, createdAt);
    leaveRequestNumber = LWWRegister(requestNumber, createdAt);
    leaveType = LWWRegister(type, createdAt);
    startDate = LWWRegister(start, createdAt);
    endDate = LWWRegister(end, createdAt);
    daysRequested = LWWRegister(days, createdAt);
    hoursRequested = LWWRegister(hours, createdAt);
    status = LWWRegister(requestStatus, createdAt);
    
    // Initialize approval workflow
    managerId = LWWRegister(manager, createdAt);
    hrId = LWWRegister(hr, createdAt);
    managerApprovalDate = LWWRegister(managerApproval, createdAt);
    hrApprovalDate = LWWRegister(hrApproval, createdAt);
    managerComments = LWWRegister(managerComment, createdAt);
    hrComments = LWWRegister(hrComment, createdAt);
    
    // Initialize leave details
    reason = LWWRegister(leaveReason, createdAt);
    description = LWWRegister(leaveDescription, createdAt);
    isHalfDay = LWWRegister(halfDay, createdAt);
    halfDayPeriod = LWWRegister(halfDayTime, createdAt);
    isEmergency = LWWRegister(emergency, createdAt);
    
    // Initialize medical certificate
    medicalCertificateNumber = LWWRegister(mcNumber, createdAt);
    doctorName = LWWRegister(doctor, createdAt);
    clinicName = LWWRegister(clinic, createdAt);
    mcStartDate = LWWRegister(mcStart, createdAt);
    mcEndDate = LWWRegister(end, createdAt);
    
    // Initialize contact information
    contactNumber = LWWRegister(contact, createdAt);
    contactAddress = LWWRegister(contactAddr, createdAt);
    emergencyContact = LWWRegister(emergencyContactInfo, createdAt);
    
    // Initialize handover information
    handoverTo = LWWRegister(handover, createdAt);
    handoverNotes = LWWRegister(handoverNote, createdAt);
    
    // Initialize attachments
    attachmentIds = ORSet(nodeId);
    
    // Initialize additional information
    metadata = LWWRegister(leaveMetadata, createdAt);
  }
  
  /// Check if leave is pending approval
  bool get isPendingApproval => status.value == 'submitted';
  
  /// Check if leave is approved
  bool get isApproved => status.value == 'approved';
  
  /// Check if leave requires medical certificate
  bool get requiresMedicalCertificate => 
      leaveType.value == 'sick' || 
      leaveType.value == 'hospitalisation';
  
  /// Get leave duration in working days
  double get leaveDuration => isHalfDay.value ? 0.5 : daysRequested.value;
  
  /// Update leave status
  void updateStatus(String newStatus, HLCTimestamp timestamp) {
    status.setValue(newStatus, timestamp);
    _updateTimestamp(timestamp);
  }
  
  /// Submit for approval
  void submitForApproval(String managerId, HLCTimestamp timestamp) {
    status.setValue('submitted', timestamp);
    this.managerId.setValue(managerId, timestamp);
    _updateTimestamp(timestamp);
  }
  
  /// Approve by manager
  void approveByManager({
    required String approverId,
    String? comments,
    required HLCTimestamp timestamp,
  }) {
    status.setValue('approved', timestamp);
    managerId.setValue(approverId, timestamp);
    managerApprovalDate.setValue(DateTime.now(), timestamp);
    if (comments != null) {
      managerComments.setValue(comments, timestamp);
    }
    _updateTimestamp(timestamp);
  }
  
  /// Reject by manager
  void rejectByManager({
    required String approverId,
    String? comments,
    required HLCTimestamp timestamp,
  }) {
    status.setValue('rejected', timestamp);
    managerId.setValue(approverId, timestamp);
    managerApprovalDate.setValue(DateTime.now(), timestamp);
    if (comments != null) {
      managerComments.setValue(comments, timestamp);
    }
    _updateTimestamp(timestamp);
  }
  
  /// Approve by HR
  void approveByHR({
    required String hrApproverId,
    String? comments,
    required HLCTimestamp timestamp,
  }) {
    hrId.setValue(hrApproverId, timestamp);
    hrApprovalDate.setValue(DateTime.now(), timestamp);
    if (comments != null) {
      hrComments.setValue(comments, timestamp);
    }
    _updateTimestamp(timestamp);
  }
  
  /// Update medical certificate information
  void updateMedicalCertificate({
    String? mcNumber,
    String? doctor,
    String? clinic,
    DateTime? mcStart,
    DateTime? mcEnd,
    required HLCTimestamp timestamp,
  }) {
    if (mcNumber != null) medicalCertificateNumber.setValue(mcNumber, timestamp);
    if (doctor != null) doctorName.setValue(doctor, timestamp);
    if (clinic != null) clinicName.setValue(clinic, timestamp);
    if (mcStart != null) mcStartDate.setValue(mcStart, timestamp);
    if (mcEnd != null) mcEndDate.setValue(mcEnd, timestamp);
    _updateTimestamp(timestamp);
  }
  
  /// Update contact information
  void updateContactInfo({
    String? contact,
    String? address,
    String? emergency,
    required HLCTimestamp timestamp,
  }) {
    if (contact != null) contactNumber.setValue(contact, timestamp);
    if (address != null) contactAddress.setValue(address, timestamp);
    if (emergency != null) emergencyContact.setValue(emergency, timestamp);
    _updateTimestamp(timestamp);
  }
  
  /// Update handover information
  void updateHandover({
    String? handoverToId,
    String? notes,
    required HLCTimestamp timestamp,
  }) {
    if (handoverToId != null) handoverTo.setValue(handoverToId, timestamp);
    if (notes != null) handoverNotes.setValue(notes, timestamp);
    _updateTimestamp(timestamp);
  }
  
  /// Add attachment
  void addAttachment(String attachmentId) {
    attachmentIds.add(attachmentId);
  }
  
  /// Remove attachment
  void removeAttachment(String attachmentId) {
    attachmentIds.remove(attachmentId);
  }
  
  void _updateTimestamp(HLCTimestamp timestamp) {
    if (timestamp.happensAfter(updatedAt)) {
      updatedAt = timestamp;
      version = version.tick();
    }
  }
  
  @override
  void mergeWith(CRDTModel other) {
    if (other is! CRDTLeaveRequest || other.id != id) {
      throw ArgumentError('Cannot merge with different leave request');
    }
    
    // Merge all CRDT fields
    employeeId.mergeWith(other.employeeId);
    leaveRequestNumber.mergeWith(other.leaveRequestNumber);
    leaveType.mergeWith(other.leaveType);
    startDate.mergeWith(other.startDate);
    endDate.mergeWith(other.endDate);
    daysRequested.mergeWith(other.daysRequested);
    hoursRequested.mergeWith(other.hoursRequested);
    status.mergeWith(other.status);
    
    managerId.mergeWith(other.managerId);
    hrId.mergeWith(other.hrId);
    managerApprovalDate.mergeWith(other.managerApprovalDate);
    hrApprovalDate.mergeWith(other.hrApprovalDate);
    managerComments.mergeWith(other.managerComments);
    hrComments.mergeWith(other.hrComments);
    
    reason.mergeWith(other.reason);
    description.mergeWith(other.description);
    isHalfDay.mergeWith(other.isHalfDay);
    halfDayPeriod.mergeWith(other.halfDayPeriod);
    isEmergency.mergeWith(other.isEmergency);
    
    medicalCertificateNumber.mergeWith(other.medicalCertificateNumber);
    doctorName.mergeWith(other.doctorName);
    clinicName.mergeWith(other.clinicName);
    mcStartDate.mergeWith(other.mcStartDate);
    mcEndDate.mergeWith(other.mcEndDate);
    
    contactNumber.mergeWith(other.contactNumber);
    contactAddress.mergeWith(other.contactAddress);
    emergencyContact.mergeWith(other.emergencyContact);
    
    handoverTo.mergeWith(other.handoverTo);
    handoverNotes.mergeWith(other.handoverNotes);
    
    attachmentIds.mergeWith(other.attachmentIds);
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
      'leave_request_number': leaveRequestNumber.value,
      'leave_type': leaveType.value,
      'start_date': startDate.value.millisecondsSinceEpoch,
      'end_date': endDate.value.millisecondsSinceEpoch,
      'days_requested': daysRequested.value,
      'hours_requested': hoursRequested.value,
      'leave_duration': leaveDuration,
      'status': status.value,
      'is_pending_approval': isPendingApproval,
      'is_approved': isApproved,
      'requires_medical_certificate': requiresMedicalCertificate,
      'manager_id': managerId.value,
      'hr_id': hrId.value,
      'manager_approval_date': managerApprovalDate.value?.millisecondsSinceEpoch,
      'hr_approval_date': hrApprovalDate.value?.millisecondsSinceEpoch,
      'manager_comments': managerComments.value,
      'hr_comments': hrComments.value,
      'reason': reason.value,
      'description': description.value,
      'is_half_day': isHalfDay.value,
      'half_day_period': halfDayPeriod.value,
      'is_emergency': isEmergency.value,
      'medical_certificate_number': medicalCertificateNumber.value,
      'doctor_name': doctorName.value,
      'clinic_name': clinicName.value,
      'mc_start_date': mcStartDate.value?.millisecondsSinceEpoch,
      'mc_end_date': mcEndDate.value?.millisecondsSinceEpoch,
      'contact_number': contactNumber.value,
      'contact_address': contactAddress.value,
      'emergency_contact': emergencyContact.value,
      'handover_to': handoverTo.value,
      'handover_notes': handoverNotes.value,
      'attachment_ids': attachmentIds.elements.toList(),
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
      'leave_request_number': leaveRequestNumber.toJson(),
      'leave_type': leaveType.toJson(),
      'start_date': startDate.toJson(),
      'end_date': endDate.toJson(),
      'days_requested': daysRequested.toJson(),
      'hours_requested': hoursRequested.toJson(),
      'status': status.toJson(),
      'manager_id': managerId.toJson(),
      'hr_id': hrId.toJson(),
      'manager_approval_date': managerApprovalDate.toJson(),
      'hr_approval_date': hrApprovalDate.toJson(),
      'manager_comments': managerComments.toJson(),
      'hr_comments': hrComments.toJson(),
      'reason': reason.toJson(),
      'description': description.toJson(),
      'is_half_day': isHalfDay.toJson(),
      'half_day_period': halfDayPeriod.toJson(),
      'is_emergency': isEmergency.toJson(),
      'medical_certificate_number': medicalCertificateNumber.toJson(),
      'doctor_name': doctorName.toJson(),
      'clinic_name': clinicName.toJson(),
      'mc_start_date': mcStartDate.toJson(),
      'mc_end_date': mcEndDate.toJson(),
      'contact_number': contactNumber.toJson(),
      'contact_address': contactAddress.toJson(),
      'emergency_contact': emergencyContact.toJson(),
      'handover_to': handoverTo.toJson(),
      'handover_notes': handoverNotes.toJson(),
      'attachment_ids': attachmentIds.toJson(),
      'metadata': metadata.toJson(),
    };
  }
}

/// CRDT-enabled Attendance Record model
class CRDTAttendanceRecord implements CRDTModel {
  @override
  final String id;
  
  @override
  final String nodeId;
  
  @override
  final HLCTimestamp createdAt;
  
  @override
  HLCTimestamp updatedAt;
  
  @override
  CRDTVectorClock version;
  
  @override
  bool isDeleted;
  
  // Basic attendance information
  late LWWRegister<String> employeeId;
  late LWWRegister<DateTime> date;
  late LWWRegister<DateTime?> clockInTime;
  late LWWRegister<DateTime?> clockOutTime;
  late LWWRegister<DateTime?> breakStartTime;
  late LWWRegister<DateTime?> breakEndTime;
  
  // Attendance status
  late LWWRegister<String> status; // present, absent, late, half_day, on_leave
  late LWWRegister<bool> isLate;
  late LWWRegister<bool> isEarlyDeparture;
  late LWWRegister<bool> isOvertime;
  
  // Working hours
  late LWWRegister<double> scheduledHours;
  late LWWRegister<double> actualHours;
  late LWWRegister<double> regularHours;
  late LWWRegister<double> overtimeHours;
  late LWWRegister<double> breakHours;
  
  // Location tracking
  late LWWRegister<String?> clockInLocation;
  late LWWRegister<String?> clockOutLocation;
  late LWWRegister<double?> clockInLatitude;
  late LWWRegister<double?> clockInLongitude;
  late LWWRegister<double?> clockOutLatitude;
  late LWWRegister<double?> clockOutLongitude;
  
  // Approval and comments
  late LWWRegister<String?> managerId;
  late LWWRegister<bool> requiresApproval;
  late LWWRegister<bool> isApproved;
  late LWWRegister<DateTime?> approvalDate;
  late LWWRegister<String?> comments;
  late LWWRegister<String?> managerComments;
  
  // Additional information
  late LWWRegister<String?> workFromHome;
  late LWWRegister<String?> deviceId;
  late LWWRegister<Map<String, dynamic>?> metadata;
  
  CRDTAttendanceRecord({
    required this.id,
    required this.nodeId,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required String empId,
    required DateTime attendanceDate,
    DateTime? clockIn,
    DateTime? clockOut,
    DateTime? breakStart,
    DateTime? breakEnd,
    String attendanceStatus = 'present',
    bool late = false,
    bool earlyDeparture = false,
    bool overtime = false,
    double scheduled = 8.0,
    double actual = 0.0,
    double regular = 0.0,
    double overtimeHrs = 0.0,
    double breakHrs = 0.0,
    String? clockInLoc,
    String? clockOutLoc,
    double? clockInLat,
    double? clockInLng,
    double? clockOutLat,
    double? clockOutLng,
    String? manager,
    bool approval = false,
    bool approved = false,
    DateTime? approvedDate,
    String? attendanceComments,
    String? managerComment,
    String? wfh,
    String? device,
    Map<String, dynamic>? attendanceMetadata,
    this.isDeleted = false,
  }) {
    // Initialize basic information
    employeeId = LWWRegister(empId, createdAt);
    date = LWWRegister(attendanceDate, createdAt);
    clockInTime = LWWRegister(clockIn, createdAt);
    clockOutTime = LWWRegister(clockOut, createdAt);
    breakStartTime = LWWRegister(breakStart, createdAt);
    breakEndTime = LWWRegister(breakEnd, createdAt);
    
    // Initialize status
    status = LWWRegister(attendanceStatus, createdAt);
    isLate = LWWRegister(late, createdAt);
    isEarlyDeparture = LWWRegister(earlyDeparture, createdAt);
    isOvertime = LWWRegister(overtime, createdAt);
    
    // Initialize working hours
    scheduledHours = LWWRegister(scheduled, createdAt);
    actualHours = LWWRegister(actual, createdAt);
    regularHours = LWWRegister(regular, createdAt);
    overtimeHours = LWWRegister(overtimeHrs, createdAt);
    breakHours = LWWRegister(breakHrs, createdAt);
    
    // Initialize location
    clockInLocation = LWWRegister(clockInLoc, createdAt);
    clockOutLocation = LWWRegister(clockOutLoc, createdAt);
    clockInLatitude = LWWRegister(clockInLat, createdAt);
    clockInLongitude = LWWRegister(clockInLng, createdAt);
    clockOutLatitude = LWWRegister(clockOutLat, createdAt);
    clockOutLongitude = LWWRegister(clockOutLng, createdAt);
    
    // Initialize approval
    managerId = LWWRegister(manager, createdAt);
    requiresApproval = LWWRegister(approval, createdAt);
    isApproved = LWWRegister(approved, createdAt);
    approvalDate = LWWRegister(approvedDate, createdAt);
    comments = LWWRegister(attendanceComments, createdAt);
    managerComments = LWWRegister(managerComment, createdAt);
    
    // Initialize additional information
    workFromHome = LWWRegister(wfh, createdAt);
    deviceId = LWWRegister(device, createdAt);
    metadata = LWWRegister(attendanceMetadata, createdAt);
  }
  
  /// Check if employee is present
  bool get isPresent => status.value == 'present';
  
  /// Check if employee is absent
  bool get isAbsent => status.value == 'absent';
  
  /// Check if employee is on leave
  bool get isOnLeave => status.value == 'on_leave';
  
  /// Calculate total hours worked
  double get totalHoursWorked {
    if (clockInTime.value == null || clockOutTime.value == null) return 0.0;
    
    final duration = clockOutTime.value!.difference(clockInTime.value!);
    double hours = duration.inMinutes / 60.0;
    
    // Subtract break time
    if (breakStartTime.value != null && breakEndTime.value != null) {
      final breakDuration = breakEndTime.value!.difference(breakStartTime.value!);
      hours -= breakDuration.inMinutes / 60.0;
    }
    
    return hours;
  }
  
  /// Clock in
  void clockIn({
    required DateTime time,
    String? location,
    double? latitude,
    double? longitude,
    String? device,
    required HLCTimestamp timestamp,
  }) {
    clockInTime.setValue(time, timestamp);
    status.setValue('present', timestamp);
    if (location != null) clockInLocation.setValue(location, timestamp);
    if (latitude != null) clockInLatitude.setValue(latitude, timestamp);
    if (longitude != null) clockInLongitude.setValue(longitude, timestamp);
    if (device != null) deviceId.setValue(device, timestamp);
    _updateTimestamp(timestamp);
  }
  
  /// Clock out
  void clockOut({
    required DateTime time,
    String? location,
    double? latitude,
    double? longitude,
    required HLCTimestamp timestamp,
  }) {
    clockOutTime.setValue(time, timestamp);
    if (location != null) clockOutLocation.setValue(location, timestamp);
    if (latitude != null) clockOutLatitude.setValue(latitude, timestamp);
    if (longitude != null) clockOutLongitude.setValue(longitude, timestamp);
    
    // Calculate actual hours
    actualHours.setValue(totalHoursWorked, timestamp);
    _updateTimestamp(timestamp);
  }
  
  /// Start break
  void startBreak(DateTime time, HLCTimestamp timestamp) {
    breakStartTime.setValue(time, timestamp);
    _updateTimestamp(timestamp);
  }
  
  /// End break
  void endBreak(DateTime time, HLCTimestamp timestamp) {
    breakEndTime.setValue(time, timestamp);
    
    // Calculate break hours
    if (breakStartTime.value != null) {
      final duration = time.difference(breakStartTime.value!);
      breakHours.setValue(duration.inMinutes / 60.0, timestamp);
    }
    _updateTimestamp(timestamp);
  }
  
  /// Update working hours
  void updateWorkingHours({
    double? scheduled,
    double? actual,
    double? regular,
    double? overtime,
    required HLCTimestamp timestamp,
  }) {
    if (scheduled != null) scheduledHours.setValue(scheduled, timestamp);
    if (actual != null) actualHours.setValue(actual, timestamp);
    if (regular != null) regularHours.setValue(regular, timestamp);
    if (overtime != null) overtimeHours.setValue(overtime, timestamp);
    _updateTimestamp(timestamp);
  }
  
  /// Approve attendance
  void approve({
    required String approverId,
    String? approverComments,
    required HLCTimestamp timestamp,
  }) {
    isApproved.setValue(true, timestamp);
    managerId.setValue(approverId, timestamp);
    approvalDate.setValue(DateTime.now(), timestamp);
    if (approverComments != null) {
      managerComments.setValue(approverComments, timestamp);
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
    if (other is! CRDTAttendanceRecord || other.id != id) {
      throw ArgumentError('Cannot merge with different attendance record');
    }
    
    // Merge all CRDT fields
    employeeId.mergeWith(other.employeeId);
    date.mergeWith(other.date);
    clockInTime.mergeWith(other.clockInTime);
    clockOutTime.mergeWith(other.clockOutTime);
    breakStartTime.mergeWith(other.breakStartTime);
    breakEndTime.mergeWith(other.breakEndTime);
    
    status.mergeWith(other.status);
    isLate.mergeWith(other.isLate);
    isEarlyDeparture.mergeWith(other.isEarlyDeparture);
    isOvertime.mergeWith(other.isOvertime);
    
    scheduledHours.mergeWith(other.scheduledHours);
    actualHours.mergeWith(other.actualHours);
    regularHours.mergeWith(other.regularHours);
    overtimeHours.mergeWith(other.overtimeHours);
    breakHours.mergeWith(other.breakHours);
    
    clockInLocation.mergeWith(other.clockInLocation);
    clockOutLocation.mergeWith(other.clockOutLocation);
    clockInLatitude.mergeWith(other.clockInLatitude);
    clockInLongitude.mergeWith(other.clockInLongitude);
    clockOutLatitude.mergeWith(other.clockOutLatitude);
    clockOutLongitude.mergeWith(other.clockOutLongitude);
    
    managerId.mergeWith(other.managerId);
    requiresApproval.mergeWith(other.requiresApproval);
    isApproved.mergeWith(other.isApproved);
    approvalDate.mergeWith(other.approvalDate);
    comments.mergeWith(other.comments);
    managerComments.mergeWith(other.managerComments);
    
    workFromHome.mergeWith(other.workFromHome);
    deviceId.mergeWith(other.deviceId);
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
      'date': date.value.millisecondsSinceEpoch,
      'clock_in_time': clockInTime.value?.millisecondsSinceEpoch,
      'clock_out_time': clockOutTime.value?.millisecondsSinceEpoch,
      'break_start_time': breakStartTime.value?.millisecondsSinceEpoch,
      'break_end_time': breakEndTime.value?.millisecondsSinceEpoch,
      'status': status.value,
      'is_present': isPresent,
      'is_absent': isAbsent,
      'is_on_leave': isOnLeave,
      'is_late': isLate.value,
      'is_early_departure': isEarlyDeparture.value,
      'is_overtime': isOvertime.value,
      'scheduled_hours': scheduledHours.value,
      'actual_hours': actualHours.value,
      'regular_hours': regularHours.value,
      'overtime_hours': overtimeHours.value,
      'break_hours': breakHours.value,
      'total_hours_worked': totalHoursWorked,
      'clock_in_location': clockInLocation.value,
      'clock_out_location': clockOutLocation.value,
      'clock_in_latitude': clockInLatitude.value,
      'clock_in_longitude': clockInLongitude.value,
      'clock_out_latitude': clockOutLatitude.value,
      'clock_out_longitude': clockOutLongitude.value,
      'manager_id': managerId.value,
      'requires_approval': requiresApproval.value,
      'is_approved': isApproved.value,
      'approval_date': approvalDate.value?.millisecondsSinceEpoch,
      'comments': comments.value,
      'manager_comments': managerComments.value,
      'work_from_home': workFromHome.value,
      'device_id': deviceId.value,
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
      'date': date.toJson(),
      'clock_in_time': clockInTime.toJson(),
      'clock_out_time': clockOutTime.toJson(),
      'break_start_time': breakStartTime.toJson(),
      'break_end_time': breakEndTime.toJson(),
      'status': status.toJson(),
      'is_late': isLate.toJson(),
      'is_early_departure': isEarlyDeparture.toJson(),
      'is_overtime': isOvertime.toJson(),
      'scheduled_hours': scheduledHours.toJson(),
      'actual_hours': actualHours.toJson(),
      'regular_hours': regularHours.toJson(),
      'overtime_hours': overtimeHours.toJson(),
      'break_hours': breakHours.toJson(),
      'clock_in_location': clockInLocation.toJson(),
      'clock_out_location': clockOutLocation.toJson(),
      'clock_in_latitude': clockInLatitude.toJson(),
      'clock_in_longitude': clockInLongitude.toJson(),
      'clock_out_latitude': clockOutLatitude.toJson(),
      'clock_out_longitude': clockOutLongitude.toJson(),
      'manager_id': managerId.toJson(),
      'requires_approval': requiresApproval.toJson(),
      'is_approved': isApproved.toJson(),
      'approval_date': approvalDate.toJson(),
      'comments': comments.toJson(),
      'manager_comments': managerComments.toJson(),
      'work_from_home': workFromHome.toJson(),
      'device_id': deviceId.toJson(),
      'metadata': metadata.toJson(),
    };
  }
}