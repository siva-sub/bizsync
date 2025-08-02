// Employee Models Index
// 
// This file provides a central export point for all employee-related models
// including CRDT-enabled models for offline-first functionality and Singapore-specific
// features for payroll, tax compliance, and HR management.

// Core employee models
export 'employee_models.dart';
export 'payroll_models.dart';
export 'leave_models.dart';
export 'performance_models.dart';
export 'singapore_tax_models.dart';
export 'enhanced_payroll_models.dart';

// Enums and constants for employee management
class EmployeeConstants {
  // Singapore CPF contribution rates (2024) - Legacy format for backward compatibility  
  static const Map<String, Map<String, double>> cpfRates = {
    'citizen_pr_below_55': {
      'employee_rate': 0.20,
      'employer_rate': 0.17,
    },
    'citizen_pr_55_to_60': {
      'employee_rate': 0.20,
      'employer_rate': 0.13,
    },
    'citizen_pr_60_to_65': {
      'employee_rate': 0.20,
      'employer_rate': 0.09,
    },
    'citizen_pr_65_to_70': {
      'employee_rate': 0.05,
      'employer_rate': 0.075,
    },
    'citizen_pr_above_70': {
      'employee_rate': 0.05,
      'employer_rate': 0.05,
    },
    'pr_first_year': {
      'employee_rate': 0.05,
      'employer_rate': 0.04,
    },
    'pr_second_year': {
      'employee_rate': 0.15,
      'employer_rate': 0.06,
    },
  };
  
  // CPF wage ceilings (2024)
  static const double ordinaryWageCeiling = 6800.0; // Monthly
  static const double additionalWageCeiling = 102000.0; // Annual
  
  // Singapore levies
  static const double sdlRate = 0.0025; // 0.25%
  static const double sdlCeiling = 4500.0; // Monthly ceiling for SDL
  
  // Foreign Worker Levy rates (monthly)
  static const Map<String, double> fwlRates = {
    'construction_basic': 300.0,
    'construction_higher': 400.0,
    'manufacturing_basic': 300.0,
    'manufacturing_higher': 400.0,
    'marine_basic': 300.0,
    'marine_higher': 400.0,
    'process_basic': 300.0,
    'process_higher': 400.0,
    'services_basic': 300.0,
    'services_higher': 400.0,
  };
  
  // Standard leave entitlements in Singapore
  static const Map<String, int> standardLeaveEntitlements = {
    'annual_leave_min': 7, // Minimum 7 days annual leave
    'annual_leave_max': 21, // Common maximum 21 days
    'sick_leave': 14, // 14 days paid sick leave
    'maternity_leave': 112, // 16 weeks (112 days)
    'paternity_leave': 14, // 2 weeks (14 days)
    'childcare_leave': 6, // 6 days per year for parents
    'infant_care_leave': 6, // 6 days for first year
  };
  
  // Performance rating scales
  static const Map<String, double> performanceRatingScales = {
    'outstanding': 5.0,
    'exceeds': 4.0,
    'meets': 3.0,
    'developing': 2.0,
    'unsatisfactory': 1.0,
  };
  
  // Work permit types in Singapore
  static const List<String> workPermitTypes = [
    'citizen',
    'pr',
    'ep', // Employment Pass
    'sp', // S Pass
    'wp', // Work Permit
    'twr', // Training Work Permit
    'pep', // Personalised Employment Pass
    'one_pass', // Tech.Pass/ONE Pass
    'student_pass',
    'dependent_pass',
  ];
  
  // Employment statuses
  static const List<String> employmentStatuses = [
    'active',
    'on_leave',
    'suspended',
    'terminated',
    'retired',
  ];
  
  // Employment types
  static const List<String> employmentTypes = [
    'full_time',
    'part_time',
    'contract',
    'intern',
    'freelancer',
  ];
  
  // Leave types
  static const List<String> leaveTypes = [
    'annual',
    'sick',
    'maternity',
    'paternity',
    'adoption',
    'infant_care',
    'child_care',
    'compassionate',
    'hospitalisation',
    'unpaid',
    'study',
    'emergency',
    'other',
  ];
  
  // Payroll frequencies
  static const List<String> payrollFrequencies = [
    'monthly',
    'bi_weekly',
    'weekly',
    'daily',
  ];
  
  // Singapore bank codes (major banks)
  static const Map<String, String> singaporeBankCodes = {
    'DBS': '7171',
    'POSB': '7171',
    'OCBC': '7339',
    'UOB': '7375',
    'SCB': '7144',
    'Citibank': '7214',
    'HSBC': '7232',
    'Maybank': '7302',
    'Bank of China': '7277',
    'ICBC': '7147',
  };
  
  // Common job departments
  static const List<String> commonDepartments = [
    'Administration',
    'Finance',
    'Human Resources',
    'Information Technology',
    'Marketing',
    'Sales',
    'Operations',
    'Customer Service',
    'Legal',
    'Research & Development',
    'Quality Assurance',
    'Supply Chain',
    'Business Development',
    'Product Management',
    'Engineering',
  ];
  
  // Skills categories
  static const List<String> skillCategories = [
    'Technical',
    'Leadership',
    'Communication',
    'Project Management',
    'Data Analysis',
    'Customer Service',
    'Sales',
    'Marketing',
    'Finance',
    'Operations',
    'Strategy',
    'Design',
    'Languages',
    'Certifications',
  ];
}

// Utility functions for employee management
class EmployeeUtils {
  /// Calculate age from date of birth
  static int calculateAge(DateTime dateOfBirth) {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }
  
  /// Determine CPF age category
  static String getCpfAgeCategory(DateTime dateOfBirth) {
    final age = calculateAge(dateOfBirth);
    if (age < 55) return 'below_55';
    if (age < 60) return 'age_55_to_60';
    if (age < 65) return 'age_60_to_65';
    return 'above_65';
  }
  
  /// Get CPF rates based on age and residency
  static Map<String, double> getCpfRates(DateTime dateOfBirth, String residencyStatus) {
    final ageCategory = getCpfAgeCategory(dateOfBirth);
    
    if (residencyStatus == 'pr_first_2_years') {
      return EmployeeConstants.cpfRates['spr_first_2_years']!;
    }
    
    return EmployeeConstants.cpfRates['citizen_pr_$ageCategory']!;
  }
  
  /// Calculate working days between two dates (excluding weekends)
  static int calculateWorkingDays(DateTime startDate, DateTime endDate) {
    int workingDays = 0;
    DateTime current = startDate;
    
    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      if (current.weekday != DateTime.saturday && current.weekday != DateTime.sunday) {
        workingDays++;
      }
      current = current.add(const Duration(days: 1));
    }
    
    return workingDays;
  }
  
  /// Generate employee ID with format: EMP-YYYY-NNNN
  static String generateEmployeeId(int sequenceNumber) {
    final year = DateTime.now().year;
    final paddedNumber = sequenceNumber.toString().padLeft(4, '0');
    return 'EMP-$year-$paddedNumber';
  }
  
  /// Generate payroll number with format: PAY-YYYY-MM-NNNN
  static String generatePayrollNumber(int sequenceNumber, DateTime payPeriod) {
    final year = payPeriod.year;
    final month = payPeriod.month.toString().padLeft(2, '0');
    final paddedNumber = sequenceNumber.toString().padLeft(4, '0');
    return 'PAY-$year-$month-$paddedNumber';
  }
  
  /// Generate leave request number with format: LV-YYYY-NNNN
  static String generateLeaveRequestNumber(int sequenceNumber) {
    final year = DateTime.now().year;
    final paddedNumber = sequenceNumber.toString().padLeft(4, '0');
    return 'LV-$year-$paddedNumber';
  }
  
  /// Validate Singapore NRIC/FIN format
  static bool isValidNricFin(String nricFin) {
    final regex = RegExp(r'^[STFG]\d{7}[A-Z]$');
    return regex.hasMatch(nricFin.toUpperCase());
  }
  
  /// Validate Singapore work permit number format
  static bool isValidWorkPermitNumber(String permitNumber, String permitType) {
    switch (permitType.toLowerCase()) {
      case 'ep':
        return RegExp(r'^\d{8}[A-Z]$').hasMatch(permitNumber);
      case 'sp':
        return RegExp(r'^S\d{7}[A-Z]$').hasMatch(permitNumber);
      case 'wp':
        return RegExp(r'^WP\d{7}[A-Z]$').hasMatch(permitNumber);
      default:
        return permitNumber.isNotEmpty; // Basic validation for other types
    }
  }
  
  /// Calculate months of service
  static int calculateMonthsOfService(DateTime startDate, [DateTime? endDate]) {
    final end = endDate ?? DateTime.now();
    int months = (end.year - startDate.year) * 12 + (end.month - startDate.month);
    
    // Adjust for partial months
    if (end.day < startDate.day) {
      months--;
    }
    
    return months;
  }
  
  /// Calculate years of service
  static double calculateYearsOfService(DateTime startDate, [DateTime? endDate]) {
    final months = calculateMonthsOfService(startDate, endDate);
    return months / 12.0;
  }
  
  /// Get standard leave entitlement based on years of service
  static int getAnnualLeaveEntitlement(double yearsOfService) {
    if (yearsOfService < 1) return 7; // Minimum 7 days
    if (yearsOfService < 2) return 14; // 14 days after 1 year
    if (yearsOfService < 5) return 18; // 18 days after 2 years
    return 21; // 21 days after 5 years (common maximum)
  }
}