import 'dart:convert';
import 'dart:math' as math;
import '../../../core/crdt/hybrid_logical_clock.dart';
import '../../../core/crdt/vector_clock.dart';
import '../../../core/crdt/crdt_types.dart';
import '../../../core/crdt/lww_register.dart';
import '../../../core/crdt/pn_counter.dart';
import '../../../core/crdt/or_set.dart';
import '../../../core/database/crdt_models.dart';

/// Employment status enumeration
enum EmploymentStatus {
  active,
  onLeave,
  suspended,
  terminated,
  retired
}

/// Employee type enumeration
enum EmployeeType {
  fullTime,
  partTime,
  contract,
  intern,
  freelancer
}

/// Work permit type for Singapore
enum WorkPermitType {
  citizen,
  pr,           // Permanent Resident
  prFirst2Years, // PR (first 2 years) - different CPF rates
  ep,           // Employment Pass
  sp,           // S Pass
  wp,           // Work Permit
  twr,          // Training Work Permit
  pep,          // Personalised Employment Pass
  onePass,      // Tech.Pass/ONE Pass
  studentPass,  // Student Pass (part-time work)
  dependentPass // Dependent Pass (with LOC)
}

/// Singapore residency status for CPF and tax purposes
enum SingaporeResidencyStatus {
  citizen,
  pr,
  prFirst2Years,
  nonResident,
}

/// CPF eligibility status
enum CpfEligibilityStatus {
  eligible,
  ineligibleAge,
  ineligibleResidency,
  exempt,
}

/// CRDT-enabled Employee model with Singapore-specific features
class CRDTEmployee implements CRDTModel {
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
  
  // Personal Information
  late LWWRegister<String> employeeId;
  late LWWRegister<String> firstName;
  late LWWRegister<String> lastName;
  late LWWRegister<String?> preferredName;
  late LWWRegister<String> email;
  late LWWRegister<String?> phone;
  late LWWRegister<String?> address;
  late LWWRegister<DateTime?> dateOfBirth;
  late LWWRegister<String?> nationality;
  late LWWRegister<String?> nricFinNumber;
  
  // Employment Details
  late LWWRegister<String> jobTitle;
  late LWWRegister<String?> department;
  late LWWRegister<String?> managerId;
  late LWWRegister<DateTime> startDate;
  late LWWRegister<DateTime?> endDate;
  late LWWRegister<String> employmentStatus; // active, on_leave, suspended, terminated
  late LWWRegister<String> employmentType; // full_time, part_time, contract, intern
  
  // Singapore Work Authorization
  late LWWRegister<String> workPermitType; // citizen, pr, ep, sp, wp, etc.
  late LWWRegister<String?> workPermitNumber;
  late LWWRegister<DateTime?> workPermitExpiry;
  late LWWRegister<bool> isLocalEmployee;
  
  // Salary Information
  late LWWRegister<double> basicSalary;
  late LWWRegister<double> allowances;
  late LWWRegister<String> payFrequency; // monthly, bi_weekly, weekly
  late LWWRegister<String?> bankAccount;
  late LWWRegister<String?> bankCode;
  
  // CPF Information (Singapore specific)
  late LWWRegister<String?> cpfNumber;
  late LWWRegister<bool> isCpfMember;
  late LWWRegister<double> cpfContributionRate;
  late LWWRegister<double> cpfOrdinaryWage;
  late LWWRegister<double> cpfAdditionalWage;
  
  // Leave Balances as G-Counters (can only increase/decrease)
  late PNCounter annualLeaveBalance;
  late PNCounter sickLeaveBalance;
  late PNCounter maternitylLeaveBalance;
  late PNCounter paternitylLeaveBalance;
  late PNCounter compassionateLeaveBalance;
  
  // Skills and Tags as OR-Set
  late ORSet<String> skills;
  late ORSet<String> certifications;
  late ORSet<String> tags;
  
  // Emergency Contact
  late LWWRegister<String?> emergencyContactName;
  late LWWRegister<String?> emergencyContactPhone;
  late LWWRegister<String?> emergencyContactRelationship;
  
  // Additional Information
  late LWWRegister<Map<String, dynamic>?> metadata;
  late LWWRegister<String?> profilePicture;
  
  CRDTEmployee({
    required this.id,
    required this.nodeId,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required String empId,
    required String fname,
    required String lname,
    String? prefName,
    required String empEmail,
    String? empPhone,
    String? empAddress,
    DateTime? dob,
    String? empNationality,
    String? nricFin,
    required String title,
    String? dept,
    String? manager,
    required DateTime start,
    DateTime? end,
    String status = 'active',
    String type = 'full_time',
    String permitType = 'citizen',
    String? permitNumber,
    DateTime? permitExpiry,
    bool localEmployee = true,
    double salary = 0.0,
    double empAllowances = 0.0,
    String frequency = 'monthly',
    String? account,
    String? bank,
    String? cpf,
    bool cpfMember = true,
    double cpfRate = 0.2,
    double ordinaryWage = 0.0,
    double additionalWage = 0.0,
    int annualLeave = 0,
    int sickLeave = 0,
    int maternityLeave = 0,
    int paternityLeave = 0,
    int compassionateLeave = 0,
    String? emergencyName,
    String? emergencyPhone,
    String? emergencyRelation,
    Map<String, dynamic>? empMetadata,
    String? picture,
    this.isDeleted = false,
  }) {
    // Initialize personal information
    employeeId = LWWRegister(empId, createdAt);
    firstName = LWWRegister(fname, createdAt);
    lastName = LWWRegister(lname, createdAt);
    preferredName = LWWRegister(prefName, createdAt);
    email = LWWRegister(empEmail, createdAt);
    phone = LWWRegister(empPhone, createdAt);
    address = LWWRegister(empAddress, createdAt);
    dateOfBirth = LWWRegister(dob, createdAt);
    nationality = LWWRegister(empNationality, createdAt);
    nricFinNumber = LWWRegister(nricFin, createdAt);
    
    // Initialize employment details
    jobTitle = LWWRegister(title, createdAt);
    department = LWWRegister(dept, createdAt);
    managerId = LWWRegister(manager, createdAt);
    startDate = LWWRegister(start, createdAt);
    endDate = LWWRegister(end, createdAt);
    employmentStatus = LWWRegister(status, createdAt);
    employmentType = LWWRegister(type, createdAt);
    
    // Initialize work authorization
    workPermitType = LWWRegister(permitType, createdAt);
    workPermitNumber = LWWRegister(permitNumber, createdAt);
    workPermitExpiry = LWWRegister(permitExpiry, createdAt);
    isLocalEmployee = LWWRegister(localEmployee, createdAt);
    
    // Initialize salary information
    basicSalary = LWWRegister(salary, createdAt);
    allowances = LWWRegister(empAllowances, createdAt);
    payFrequency = LWWRegister(frequency, createdAt);
    bankAccount = LWWRegister(account, createdAt);
    bankCode = LWWRegister(bank, createdAt);
    
    // Initialize CPF information
    cpfNumber = LWWRegister(cpf, createdAt);
    isCpfMember = LWWRegister(cpfMember, createdAt);
    cpfContributionRate = LWWRegister(cpfRate, createdAt);
    cpfOrdinaryWage = LWWRegister(ordinaryWage, createdAt);
    cpfAdditionalWage = LWWRegister(additionalWage, createdAt);
    
    // Initialize leave balances
    annualLeaveBalance = PNCounter(nodeId);
    sickLeaveBalance = PNCounter(nodeId);
    maternitylLeaveBalance = PNCounter(nodeId);
    paternitylLeaveBalance = PNCounter(nodeId);
    compassionateLeaveBalance = PNCounter(nodeId);
    
    // Set initial leave balances
    if (annualLeave > 0) annualLeaveBalance.increment(annualLeave);
    if (sickLeave > 0) sickLeaveBalance.increment(sickLeave);
    if (maternityLeave > 0) maternitylLeaveBalance.increment(maternityLeave);
    if (paternityLeave > 0) paternitylLeaveBalance.increment(paternityLeave);
    if (compassionateLeave > 0) compassionateLeaveBalance.increment(compassionateLeave);
    
    // Initialize sets
    skills = ORSet(nodeId);
    certifications = ORSet(nodeId);
    tags = ORSet(nodeId);
    
    // Initialize emergency contact
    emergencyContactName = LWWRegister(emergencyName, createdAt);
    emergencyContactPhone = LWWRegister(emergencyPhone, createdAt);
    emergencyContactRelationship = LWWRegister(emergencyRelation, createdAt);
    
    // Initialize additional information
    metadata = LWWRegister(empMetadata, createdAt);
    profilePicture = LWWRegister(picture, createdAt);
  }
  
  /// Get full name with preferred name if available
  String get fullName {
    final preferred = preferredName.value;
    if (preferred != null && preferred.isNotEmpty) {
      return '$preferred ${lastName.value}';
    }
    return '${firstName.value} ${lastName.value}';
  }
  
  /// Get display name for UI
  String get displayName {
    return preferredName.value?.isNotEmpty == true 
        ? preferredName.value! 
        : firstName.value;
  }
  
  /// Calculate total compensation
  double get totalCompensation => basicSalary.value + allowances.value;
  
  /// Check if work permit is expiring soon (within 90 days)
  bool get isWorkPermitExpiringSoon {
    final expiry = workPermitExpiry.value;
    if (expiry == null) return false;
    final daysUntilExpiry = expiry.difference(DateTime.now()).inDays;
    return daysUntilExpiry <= 90 && daysUntilExpiry >= 0;
  }
  
  /// Check if employee is a foreign worker
  bool get isForeignWorker => !isLocalEmployee.value;
  
  /// Get total leave balance
  int get totalLeaveBalance {
    return annualLeaveBalance.value + 
           sickLeaveBalance.value + 
           maternitylLeaveBalance.value + 
           paternitylLeaveBalance.value + 
           compassionateLeaveBalance.value;
  }
  
  /// Update personal information
  void updatePersonalInfo({
    String? newFirstName,
    String? newLastName,
    String? newPreferredName,
    String? newEmail,
    String? newPhone,
    String? newAddress,
    DateTime? newDateOfBirth,
    String? newNationality,
    String? newNricFin,
    required HLCTimestamp timestamp,
  }) {
    if (newFirstName != null) firstName.setValue(newFirstName, timestamp);
    if (newLastName != null) lastName.setValue(newLastName, timestamp);
    if (newPreferredName != null) preferredName.setValue(newPreferredName, timestamp);
    if (newEmail != null) email.setValue(newEmail, timestamp);
    if (newPhone != null) phone.setValue(newPhone, timestamp);
    if (newAddress != null) address.setValue(newAddress, timestamp);
    if (newDateOfBirth != null) dateOfBirth.setValue(newDateOfBirth, timestamp);
    if (newNationality != null) nationality.setValue(newNationality, timestamp);
    if (newNricFin != null) nricFinNumber.setValue(newNricFin, timestamp);
    _updateTimestamp(timestamp);
  }
  
  /// Update employment details
  void updateEmploymentDetails({
    String? newJobTitle,
    String? newDepartment,
    String? newManagerId,
    DateTime? newEndDate,
    String? newStatus,
    String? newType,
    required HLCTimestamp timestamp,
  }) {
    if (newJobTitle != null) jobTitle.setValue(newJobTitle, timestamp);
    if (newDepartment != null) department.setValue(newDepartment, timestamp);
    if (newManagerId != null) managerId.setValue(newManagerId, timestamp);
    if (newEndDate != null) endDate.setValue(newEndDate, timestamp);
    if (newStatus != null) employmentStatus.setValue(newStatus, timestamp);
    if (newType != null) employmentType.setValue(newType, timestamp);
    _updateTimestamp(timestamp);
  }
  
  /// Update salary information
  void updateSalary({
    double? newBasicSalary,
    double? newAllowances,
    String? newPayFrequency,
    String? newBankAccount,
    String? newBankCode,
    required HLCTimestamp timestamp,
  }) {
    if (newBasicSalary != null) basicSalary.setValue(newBasicSalary, timestamp);
    if (newAllowances != null) allowances.setValue(newAllowances, timestamp);
    if (newPayFrequency != null) payFrequency.setValue(newPayFrequency, timestamp);
    if (newBankAccount != null) bankAccount.setValue(newBankAccount, timestamp);
    if (newBankCode != null) bankCode.setValue(newBankCode, timestamp);
    _updateTimestamp(timestamp);
  }
  
  /// Update work permit information
  void updateWorkPermit({
    String? newPermitType,
    String? newPermitNumber,
    DateTime? newPermitExpiry,
    bool? newIsLocal,
    required HLCTimestamp timestamp,
  }) {
    if (newPermitType != null) workPermitType.setValue(newPermitType, timestamp);
    if (newPermitNumber != null) workPermitNumber.setValue(newPermitNumber, timestamp);
    if (newPermitExpiry != null) workPermitExpiry.setValue(newPermitExpiry, timestamp);
    if (newIsLocal != null) isLocalEmployee.setValue(newIsLocal, timestamp);
    _updateTimestamp(timestamp);
  }
  
  /// Update CPF information
  void updateCpfInfo({
    String? newCpfNumber,
    bool? newIsCpfMember,
    double? newCpfRate,
    double? newOrdinaryWage,
    double? newAdditionalWage,
    required HLCTimestamp timestamp,
  }) {
    if (newCpfNumber != null) cpfNumber.setValue(newCpfNumber, timestamp);
    if (newIsCpfMember != null) isCpfMember.setValue(newIsCpfMember, timestamp);
    if (newCpfRate != null) cpfContributionRate.setValue(newCpfRate, timestamp);
    if (newOrdinaryWage != null) cpfOrdinaryWage.setValue(newOrdinaryWage, timestamp);
    if (newAdditionalWage != null) cpfAdditionalWage.setValue(newAdditionalWage, timestamp);
    _updateTimestamp(timestamp);
  }
  
  /// Adjust leave balance
  void adjustLeaveBalance({
    int? annualLeaveAdjustment,
    int? sickLeaveAdjustment,
    int? maternityLeaveAdjustment,
    int? paternityLeaveAdjustment,
    int? compassionateLeaveAdjustment,
  }) {
    if (annualLeaveAdjustment != null) {
      if (annualLeaveAdjustment > 0) {
        annualLeaveBalance.increment(annualLeaveAdjustment);
      } else if (annualLeaveAdjustment < 0) {
        annualLeaveBalance.decrement(-annualLeaveAdjustment);
      }
    }
    
    if (sickLeaveAdjustment != null) {
      if (sickLeaveAdjustment > 0) {
        sickLeaveBalance.increment(sickLeaveAdjustment);
      } else if (sickLeaveAdjustment < 0) {
        sickLeaveBalance.decrement(-sickLeaveAdjustment);
      }
    }
    
    if (maternityLeaveAdjustment != null) {
      if (maternityLeaveAdjustment > 0) {
        maternitylLeaveBalance.increment(maternityLeaveAdjustment);
      } else if (maternityLeaveAdjustment < 0) {
        maternitylLeaveBalance.decrement(-maternityLeaveAdjustment);
      }
    }
    
    if (paternityLeaveAdjustment != null) {
      if (paternityLeaveAdjustment > 0) {
        paternitylLeaveBalance.increment(paternityLeaveAdjustment);
      } else if (paternityLeaveAdjustment < 0) {
        paternitylLeaveBalance.decrement(-paternityLeaveAdjustment);
      }
    }
    
    if (compassionateLeaveAdjustment != null) {
      if (compassionateLeaveAdjustment > 0) {
        compassionateLeaveBalance.increment(compassionateLeaveAdjustment);
      } else if (compassionateLeaveAdjustment < 0) {
        compassionateLeaveBalance.decrement(-compassionateLeaveAdjustment);
      }
    }
  }
  
  /// Add skill
  void addSkill(String skill) {
    skills.add(skill);
  }
  
  /// Remove skill
  void removeSkill(String skill) {
    skills.remove(skill);
  }
  
  /// Add certification
  void addCertification(String certification) {
    certifications.add(certification);
  }
  
  /// Remove certification
  void removeCertification(String certification) {
    certifications.remove(certification);
  }
  
  /// Add tag
  void addTag(String tag) {
    tags.add(tag);
  }
  
  /// Remove tag
  void removeTag(String tag) {
    tags.remove(tag);
  }
  
  /// Update emergency contact
  void updateEmergencyContact({
    String? name,
    String? phone,
    String? relationship,
    required HLCTimestamp timestamp,
  }) {
    if (name != null) emergencyContactName.setValue(name, timestamp);
    if (phone != null) emergencyContactPhone.setValue(phone, timestamp);
    if (relationship != null) emergencyContactRelationship.setValue(relationship, timestamp);
    _updateTimestamp(timestamp);
  }
  
  /// Get Singapore residency status for CPF and tax purposes
  SingaporeResidencyStatus get residencyStatus {
    final permitType = workPermitType.value;
    switch (permitType) {
      case 'citizen':
        return SingaporeResidencyStatus.citizen;
      case 'pr':
        return SingaporeResidencyStatus.pr;
      case 'pr_first_2_years':
        return SingaporeResidencyStatus.prFirst2Years;
      default:
        return SingaporeResidencyStatus.nonResident;
    }
  }

  /// Check if employee is eligible for CPF
  CpfEligibilityStatus get cpfEligibilityStatus {
    final age = currentAge;
    
    // Age limit: CPF contributions stop at 70
    if (age >= 70) {
      return CpfEligibilityStatus.ineligibleAge;
    }
    
    // Check residency eligibility
    final residency = residencyStatus;
    if (residency == SingaporeResidencyStatus.nonResident) {
      return CpfEligibilityStatus.ineligibleResidency;
    }
    
    return CpfEligibilityStatus.eligible;
  }

  /// Calculate current age
  int get currentAge {
    final birthDate = dateOfBirth.value;
    if (birthDate == null) return 0;
    
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    
    // Adjust for birthday not yet reached this year
    if (now.month < birthDate.month || 
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    
    return age;
  }

  /// Get work permit type display name
  String get workPermitTypeDisplay {
    switch (workPermitType.value) {
      case 'citizen':
        return 'Singapore Citizen';
      case 'pr':
        return 'Permanent Resident';
      case 'pr_first_2_years':
        return 'Permanent Resident (First 2 Years)';
      case 'ep':
        return 'Employment Pass';
      case 'sp':
        return 'S Pass';
      case 'wp':
        return 'Work Permit';
      case 'twr':
        return 'Training Work Permit';
      case 'pep':
        return 'Personalised Employment Pass';
      case 'onePass':
        return 'Tech.Pass/ONE Pass';
      case 'studentPass':
        return 'Student Pass';
      case 'dependentPass':
        return 'Dependent Pass';
      default:
        return 'Unknown';
    }
  }

  /// Check if employee requires work pass renewal
  bool get requiresWorkPassRenewal {
    final permitType = workPermitType.value;
    final expiry = workPermitExpiry.value;
    
    // Citizens and PRs don't need renewal
    if (permitType == 'citizen' || permitType == 'pr') {
      return false;
    }
    
    return expiry != null && expiry.isAfter(DateTime.now());
  }

  /// Get CPF contribution rates based on current age and residency
  Map<String, double> get cpfRates {
    final age = currentAge;
    final residency = residencyStatus;
    
    // Not eligible for CPF
    if (cpfEligibilityStatus != CpfEligibilityStatus.eligible) {
      return {'employee_rate': 0.0, 'employer_rate': 0.0};
    }
    
    // Special rates for new PRs (first 2 years)
    if (residency == SingaporeResidencyStatus.prFirst2Years) {
      if (age < 55) return {'employee_rate': 0.05, 'employer_rate': 0.04};
      if (age >= 55 && age < 60) return {'employee_rate': 0.035, 'employer_rate': 0.035};
      if (age >= 60 && age < 65) return {'employee_rate': 0.025, 'employer_rate': 0.025};
      return {'employee_rate': 0.025, 'employer_rate': 0.025}; // 65+
    }
    
    // Standard rates for citizens and PRs
    if (age < 55) return {'employee_rate': 0.20, 'employer_rate': 0.17};
    if (age >= 55 && age < 60) return {'employee_rate': 0.13, 'employer_rate': 0.13};
    if (age >= 60 && age < 65) return {'employee_rate': 0.075, 'employer_rate': 0.09};
    return {'employee_rate': 0.05, 'employer_rate': 0.075}; // 65+
  }

  /// Get estimated monthly CPF contribution
  double get estimatedMonthlyCpfContribution {
    if (cpfEligibilityStatus != CpfEligibilityStatus.eligible) {
      return 0.0;
    }
    
    final rates = cpfRates;
    final cappedSalary = math.min(totalCompensation, 6000.0); // CPF ceiling
    return cappedSalary * (rates['employee_rate']! + rates['employer_rate']!);
  }

  /// Check if employee is subject to Skills Development Levy (SDL)
  bool get isSubjectToSdl {
    // SDL applies to all employees earning above certain threshold
    return totalCompensation > 500.0; // Simplified threshold
  }

  /// Check if employee is subject to Foreign Worker Levy (FWL)
  bool get isSubjectToFwl {
    final permit = workPermitType.value;
    return ['wp', 'sp'].contains(permit.toString().split('.').last);
  }

  void _updateTimestamp(HLCTimestamp timestamp) {
    if (timestamp.happensAfter(updatedAt)) {
      updatedAt = timestamp;
      version = version.tick();
    }
  }
  
  @override
  void mergeWith(CRDTModel other) {
    if (other is! CRDTEmployee || other.id != id) {
      throw ArgumentError('Cannot merge with different employee');
    }
    
    // Merge all CRDT fields
    employeeId.mergeWith(other.employeeId);
    firstName.mergeWith(other.firstName);
    lastName.mergeWith(other.lastName);
    preferredName.mergeWith(other.preferredName);
    email.mergeWith(other.email);
    phone.mergeWith(other.phone);
    address.mergeWith(other.address);
    dateOfBirth.mergeWith(other.dateOfBirth);
    nationality.mergeWith(other.nationality);
    nricFinNumber.mergeWith(other.nricFinNumber);
    
    jobTitle.mergeWith(other.jobTitle);
    department.mergeWith(other.department);
    managerId.mergeWith(other.managerId);
    startDate.mergeWith(other.startDate);
    endDate.mergeWith(other.endDate);
    employmentStatus.mergeWith(other.employmentStatus);
    employmentType.mergeWith(other.employmentType);
    
    workPermitType.mergeWith(other.workPermitType);
    workPermitNumber.mergeWith(other.workPermitNumber);
    workPermitExpiry.mergeWith(other.workPermitExpiry);
    isLocalEmployee.mergeWith(other.isLocalEmployee);
    
    basicSalary.mergeWith(other.basicSalary);
    allowances.mergeWith(other.allowances);
    payFrequency.mergeWith(other.payFrequency);
    bankAccount.mergeWith(other.bankAccount);
    bankCode.mergeWith(other.bankCode);
    
    cpfNumber.mergeWith(other.cpfNumber);
    isCpfMember.mergeWith(other.isCpfMember);
    cpfContributionRate.mergeWith(other.cpfContributionRate);
    cpfOrdinaryWage.mergeWith(other.cpfOrdinaryWage);
    cpfAdditionalWage.mergeWith(other.cpfAdditionalWage);
    
    annualLeaveBalance.mergeWith(other.annualLeaveBalance);
    sickLeaveBalance.mergeWith(other.sickLeaveBalance);
    maternitylLeaveBalance.mergeWith(other.maternitylLeaveBalance);
    paternitylLeaveBalance.mergeWith(other.paternitylLeaveBalance);
    compassionateLeaveBalance.mergeWith(other.compassionateLeaveBalance);
    
    skills.mergeWith(other.skills);
    certifications.mergeWith(other.certifications);
    tags.mergeWith(other.tags);
    
    emergencyContactName.mergeWith(other.emergencyContactName);
    emergencyContactPhone.mergeWith(other.emergencyContactPhone);
    emergencyContactRelationship.mergeWith(other.emergencyContactRelationship);
    
    metadata.mergeWith(other.metadata);
    profilePicture.mergeWith(other.profilePicture);
    
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
      'first_name': firstName.value,
      'last_name': lastName.value,
      'preferred_name': preferredName.value,
      'full_name': fullName,
      'display_name': displayName,
      'email': email.value,
      'phone': phone.value,
      'address': address.value,
      'date_of_birth': dateOfBirth.value?.millisecondsSinceEpoch,
      'nationality': nationality.value,
      'nric_fin_number': nricFinNumber.value,
      'job_title': jobTitle.value,
      'department': department.value,
      'manager_id': managerId.value,
      'start_date': startDate.value.millisecondsSinceEpoch,
      'end_date': endDate.value?.millisecondsSinceEpoch,
      'employment_status': employmentStatus.value,
      'employment_type': employmentType.value,
      'work_permit_type': workPermitType.value,
      'work_permit_number': workPermitNumber.value,
      'work_permit_expiry': workPermitExpiry.value?.millisecondsSinceEpoch,
      'is_local_employee': isLocalEmployee.value,
      'is_foreign_worker': isForeignWorker,
      'is_work_permit_expiring_soon': isWorkPermitExpiringSoon,
      'basic_salary': basicSalary.value,
      'allowances': allowances.value,
      'total_compensation': totalCompensation,
      'pay_frequency': payFrequency.value,
      'bank_account': bankAccount.value,
      'bank_code': bankCode.value,
      'cpf_number': cpfNumber.value,
      'is_cpf_member': isCpfMember.value,
      'cpf_contribution_rate': cpfContributionRate.value,
      'cpf_ordinary_wage': cpfOrdinaryWage.value,
      'cpf_additional_wage': cpfAdditionalWage.value,
      'annual_leave_balance': annualLeaveBalance.value,
      'sick_leave_balance': sickLeaveBalance.value,
      'maternity_leave_balance': maternitylLeaveBalance.value,
      'paternity_leave_balance': paternitylLeaveBalance.value,
      'compassionate_leave_balance': compassionateLeaveBalance.value,
      'total_leave_balance': totalLeaveBalance,
      'skills': skills.elements.toList(),
      'certifications': certifications.elements.toList(),
      'tags': tags.elements.toList(),
      'emergency_contact_name': emergencyContactName.value,
      'emergency_contact_phone': emergencyContactPhone.value,
      'emergency_contact_relationship': emergencyContactRelationship.value,
      'metadata': metadata.value,
      'profile_picture': profilePicture.value,
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
      'first_name': firstName.toJson(),
      'last_name': lastName.toJson(),
      'preferred_name': preferredName.toJson(),
      'email': email.toJson(),
      'phone': phone.toJson(),
      'address': address.toJson(),
      'date_of_birth': dateOfBirth.toJson(),
      'nationality': nationality.toJson(),
      'nric_fin_number': nricFinNumber.toJson(),
      'job_title': jobTitle.toJson(),
      'department': department.toJson(),
      'manager_id': managerId.toJson(),
      'start_date': startDate.toJson(),
      'end_date': endDate.toJson(),
      'employment_status': employmentStatus.toJson(),
      'employment_type': employmentType.toJson(),
      'work_permit_type': workPermitType.toJson(),
      'work_permit_number': workPermitNumber.toJson(),
      'work_permit_expiry': workPermitExpiry.toJson(),
      'is_local_employee': isLocalEmployee.toJson(),
      'basic_salary': basicSalary.toJson(),
      'allowances': allowances.toJson(),
      'pay_frequency': payFrequency.toJson(),
      'bank_account': bankAccount.toJson(),
      'bank_code': bankCode.toJson(),
      'cpf_number': cpfNumber.toJson(),
      'is_cpf_member': isCpfMember.toJson(),
      'cpf_contribution_rate': cpfContributionRate.toJson(),
      'cpf_ordinary_wage': cpfOrdinaryWage.toJson(),
      'cpf_additional_wage': cpfAdditionalWage.toJson(),
      'annual_leave_balance': annualLeaveBalance.toJson(),
      'sick_leave_balance': sickLeaveBalance.toJson(),
      'maternity_leave_balance': maternitylLeaveBalance.toJson(),
      'paternity_leave_balance': paternitylLeaveBalance.toJson(),
      'compassionate_leave_balance': compassionateLeaveBalance.toJson(),
      'skills': skills.toJson(),
      'certifications': certifications.toJson(),
      'tags': tags.toJson(),
      'emergency_contact_name': emergencyContactName.toJson(),
      'emergency_contact_phone': emergencyContactPhone.toJson(),
      'emergency_contact_relationship': emergencyContactRelationship.toJson(),
      'metadata': metadata.toJson(),
      'profile_picture': profilePicture.toJson(),
    };
  }
  
  factory CRDTEmployee.fromCRDTJson(Map<String, dynamic> json) {
    final employee = CRDTEmployee(
      id: json['id'] as String,
      nodeId: json['node_id'] as String,
      createdAt: HLCTimestamp.fromString(json['created_at'] as String),
      updatedAt: HLCTimestamp.fromString(json['updated_at'] as String),
      version: VectorClock.fromString(json['version'] as String, json['node_id'] as String),
      empId: '', // Will be overwritten
      fname: '', // Will be overwritten
      lname: '', // Will be overwritten
      empEmail: '', // Will be overwritten
      title: '', // Will be overwritten
      start: DateTime.now(), // Will be overwritten
      isDeleted: json['is_deleted'] as bool? ?? false,
    );
    
    // Restore CRDT states
    employee.employeeId = LWWRegister.fromJson(json['employee_id'] as Map<String, dynamic>);
    employee.firstName = LWWRegister.fromJson(json['first_name'] as Map<String, dynamic>);
    employee.lastName = LWWRegister.fromJson(json['last_name'] as Map<String, dynamic>);
    employee.preferredName = LWWRegister.fromJson(json['preferred_name'] as Map<String, dynamic>);
    employee.email = LWWRegister.fromJson(json['email'] as Map<String, dynamic>);
    employee.phone = LWWRegister.fromJson(json['phone'] as Map<String, dynamic>);
    employee.address = LWWRegister.fromJson(json['address'] as Map<String, dynamic>);
    employee.dateOfBirth = LWWRegister.fromJson(json['date_of_birth'] as Map<String, dynamic>);
    employee.nationality = LWWRegister.fromJson(json['nationality'] as Map<String, dynamic>);
    employee.nricFinNumber = LWWRegister.fromJson(json['nric_fin_number'] as Map<String, dynamic>);
    
    employee.jobTitle = LWWRegister.fromJson(json['job_title'] as Map<String, dynamic>);
    employee.department = LWWRegister.fromJson(json['department'] as Map<String, dynamic>);
    employee.managerId = LWWRegister.fromJson(json['manager_id'] as Map<String, dynamic>);
    employee.startDate = LWWRegister.fromJson(json['start_date'] as Map<String, dynamic>);
    employee.endDate = LWWRegister.fromJson(json['end_date'] as Map<String, dynamic>);
    employee.employmentStatus = LWWRegister.fromJson(json['employment_status'] as Map<String, dynamic>);
    employee.employmentType = LWWRegister.fromJson(json['employment_type'] as Map<String, dynamic>);
    
    employee.workPermitType = LWWRegister.fromJson(json['work_permit_type'] as Map<String, dynamic>);
    employee.workPermitNumber = LWWRegister.fromJson(json['work_permit_number'] as Map<String, dynamic>);
    employee.workPermitExpiry = LWWRegister.fromJson(json['work_permit_expiry'] as Map<String, dynamic>);
    employee.isLocalEmployee = LWWRegister.fromJson(json['is_local_employee'] as Map<String, dynamic>);
    
    employee.basicSalary = LWWRegister.fromJson(json['basic_salary'] as Map<String, dynamic>);
    employee.allowances = LWWRegister.fromJson(json['allowances'] as Map<String, dynamic>);
    employee.payFrequency = LWWRegister.fromJson(json['pay_frequency'] as Map<String, dynamic>);
    employee.bankAccount = LWWRegister.fromJson(json['bank_account'] as Map<String, dynamic>);
    employee.bankCode = LWWRegister.fromJson(json['bank_code'] as Map<String, dynamic>);
    
    employee.cpfNumber = LWWRegister.fromJson(json['cpf_number'] as Map<String, dynamic>);
    employee.isCpfMember = LWWRegister.fromJson(json['is_cpf_member'] as Map<String, dynamic>);
    employee.cpfContributionRate = LWWRegister.fromJson(json['cpf_contribution_rate'] as Map<String, dynamic>);
    employee.cpfOrdinaryWage = LWWRegister.fromJson(json['cpf_ordinary_wage'] as Map<String, dynamic>);
    employee.cpfAdditionalWage = LWWRegister.fromJson(json['cpf_additional_wage'] as Map<String, dynamic>);
    
    employee.annualLeaveBalance = PNCounter.fromJson(json['annual_leave_balance'] as Map<String, dynamic>);
    employee.sickLeaveBalance = PNCounter.fromJson(json['sick_leave_balance'] as Map<String, dynamic>);
    employee.maternitylLeaveBalance = PNCounter.fromJson(json['maternity_leave_balance'] as Map<String, dynamic>);
    employee.paternitylLeaveBalance = PNCounter.fromJson(json['paternity_leave_balance'] as Map<String, dynamic>);
    employee.compassionateLeaveBalance = PNCounter.fromJson(json['compassionate_leave_balance'] as Map<String, dynamic>);
    
    employee.skills = ORSet.fromJson(json['skills'] as Map<String, dynamic>);
    employee.certifications = ORSet.fromJson(json['certifications'] as Map<String, dynamic>);
    employee.tags = ORSet.fromJson(json['tags'] as Map<String, dynamic>);
    
    employee.emergencyContactName = LWWRegister.fromJson(json['emergency_contact_name'] as Map<String, dynamic>);
    employee.emergencyContactPhone = LWWRegister.fromJson(json['emergency_contact_phone'] as Map<String, dynamic>);
    employee.emergencyContactRelationship = LWWRegister.fromJson(json['emergency_contact_relationship'] as Map<String, dynamic>);
    
    employee.metadata = LWWRegister.fromJson(json['metadata'] as Map<String, dynamic>);
    employee.profilePicture = LWWRegister.fromJson(json['profile_picture'] as Map<String, dynamic>);
    
    return employee;
  }
}