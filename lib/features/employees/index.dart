// Employee Management Module Index
//
// This is the main export file for the comprehensive employee management module
// providing CRDT-enabled offline-first functionality with Singapore-specific
// payroll, tax compliance, and HR management features.
//
// Features:
// - Complete employee lifecycle management (hire to retire)
// - Singapore payroll processing with CPF, SDL, FWL calculations
// - Leave management system with approval workflows
// - Attendance tracking with location and device support
// - Performance management and goal tracking
// - Tax compliance (IR8A/IR8S preparation)
// - Bank payment file generation (GIRO)
// - Offline-first with CRDT synchronization
// - Multi-device support with conflict resolution

// Models - CRDT-enabled data models
export 'models/index.dart';

// Services - Business logic and processing
export 'services/index.dart';

// Repositories - Database operations
export 'repositories/index.dart';

// UI Components and Screens
export 'screens/index.dart';
export 'widgets/index.dart';

// Providers - State management
export 'providers/index.dart';

// Module configuration and setup
class EmployeeModuleConfig {
  // Singapore-specific settings
  static const String defaultCurrency = 'SGD';
  static const String defaultTimezone = 'Asia/Singapore';
  static const int defaultWorkingHoursPerDay = 8;
  static const int defaultWorkingDaysPerWeek = 5;
  static const double defaultOvertimeMultiplier = 1.5;
  
  // Payroll settings
  static const int payrollProcessingDay = 25; // 25th of each month
  static const int payrollPaymentDay = 1; // 1st of following month
  static const bool autoCalculateCpf = true;
  static const bool autoCalculateSdl = true;
  
  // Leave settings
  static const int defaultAnnualLeaveEntitlement = 14; // Days
  static const int defaultSickLeaveEntitlement = 14; // Days
  static const int defaultMaternityLeaveEntitlement = 112; // Days (16 weeks)
  static const int defaultPaternityLeaveEntitlement = 14; // Days (2 weeks)
  
  // Attendance settings
  static const int lateGracePeriodMinutes = 15;
  static const int earlyDepartureGracePeriodMinutes = 15;
  static const bool requireLocationForClockIn = false;
  static const bool allowWorkFromHome = true;
  
  // Performance settings
  static const String defaultPerformanceReviewCycle = 'annual';
  static const int performanceReviewReminderDays = 30;
  static const double defaultPerformanceRatingScale = 5.0;
  
  // Notification settings
  static const bool sendPayrollNotifications = true;
  static const bool sendLeaveNotifications = true;
  static const bool sendAttendanceNotifications = true;
  static const bool sendPerformanceNotifications = true;
  
  // File export settings
  static const String defaultBankFileFormat = 'giro';
  static const String defaultPayslipFormat = 'pdf';
  static const String defaultReportFormat = 'excel';
}

// Module capabilities and features
class EmployeeModuleCapabilities {
  static const List<String> supportedPayrollFrequencies = [
    'monthly',
    'bi_weekly',
    'weekly',
    'daily',
  ];
  
  static const List<String> supportedLeaveTypes = [
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
  
  static const List<String> supportedWorkPermitTypes = [
    'citizen',
    'pr',
    'ep',           // Employment Pass
    'sp',           // S Pass
    'wp',           // Work Permit
    'twr',          // Training Work Permit
    'pep',          // Personalised Employment Pass
    'one_pass',     // Tech.Pass/ONE Pass
    'student_pass', // Student Pass (part-time work)
    'dependent_pass', // Dependent Pass (with LOC)
  ];
  
  static const List<String> supportedEmploymentTypes = [
    'full_time',
    'part_time',
    'contract',
    'intern',
    'freelancer',
  ];
  
  static const List<String> supportedAttendanceStatuses = [
    'present',
    'absent',
    'late',
    'half_day',
    'on_leave',
  ];
  
  static const List<String> supportedPerformanceRatings = [
    'outstanding',
    'exceeds',
    'meets',
    'developing',
    'unsatisfactory',
  ];
  
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
}

// Module initialization and setup
class EmployeeModule {
  static bool _initialized = false;
  static late CRDTDatabaseService _database;
  static late NotificationService _notificationService;
  
  // Services
  static late EmployeeService employeeService;
  static late SingaporePayrollService payrollService;
  static late LeaveManagementService leaveService;
  static late AttendanceService attendanceService;
  
  // Repositories
  static late EmployeeRepository employeeRepository;
  static late PayrollRepository payrollRepository;
  static late LeaveAttendanceRepository leaveAttendanceRepository;
  
  // Facade
  static late EmployeeManagementFacade managementFacade;
  
  /// Initialize the employee module
  static Future<void> initialize({
    required CRDTDatabaseService database,
    required NotificationService notificationService,
  }) async {
    if (_initialized) return;
    
    _database = database;
    _notificationService = notificationService;
    
    // Initialize database schema
    await EmployeeDatabaseSchema.initializeSchema(database);
    
    // Initialize repositories
    employeeRepository = EmployeeRepository(database);
    payrollRepository = PayrollRepository(database);
    leaveAttendanceRepository = LeaveAttendanceRepository(database);
    
    // Initialize services
    employeeService = EmployeeService(notificationService);
    payrollService = SingaporePayrollService();
    leaveService = LeaveManagementService(notificationService);
    attendanceService = AttendanceService(notificationService);
    
    // Initialize facade
    managementFacade = EmployeeManagementFacade(
      employeeService: employeeService,
      payrollService: payrollService,
      leaveService: leaveService,
      attendanceService: attendanceService,
    );
    
    _initialized = true;
  }
  
  /// Get module initialization status
  static bool get isInitialized => _initialized;
  
  /// Get module version
  static String get version => '1.0.0';
  
  /// Get module features
  static List<String> get features => [
    'Employee CRUD Operations',
    'Singapore Payroll Processing',
    'CPF/SDL/FWL Calculations',
    'Leave Management',
    'Attendance Tracking',
    'Performance Management',
    'Tax Compliance (IR8A/IR8S)',
    'Bank File Generation',
    'Offline-first CRDT Support',
    'Multi-device Synchronization',
    'Real-time Notifications',
    'Comprehensive Reporting',
  ];
  
  /// Get module statistics
  static Future<Map<String, dynamic>> getModuleStatistics() async {
    if (!_initialized) {
      throw StateError('Employee module not initialized');
    }
    
    return {
      'version': version,
      'features': features,
      'employee_statistics': await employeeRepository.getEmployeeStatistics(),
      'capabilities': {
        'payroll_frequencies': EmployeeModuleCapabilities.supportedPayrollFrequencies,
        'leave_types': EmployeeModuleCapabilities.supportedLeaveTypes,
        'work_permit_types': EmployeeModuleCapabilities.supportedWorkPermitTypes,
        'employment_types': EmployeeModuleCapabilities.supportedEmploymentTypes,
      },
      'configuration': {
        'default_currency': EmployeeModuleConfig.defaultCurrency,
        'default_timezone': EmployeeModuleConfig.defaultTimezone,
        'working_hours_per_day': EmployeeModuleConfig.defaultWorkingHoursPerDay,
        'working_days_per_week': EmployeeModuleConfig.defaultWorkingDaysPerWeek,
        'payroll_processing_day': EmployeeModuleConfig.payrollProcessingDay,
        'auto_calculate_cpf': EmployeeModuleConfig.autoCalculateCpf,
      },
    };
  }
  
  /// Validate module dependencies
  static bool validateDependencies() {
    try {
      // Check if required services are available
      return _database != null && _notificationService != null;
    } catch (e) {
      return false;
    }
  }
  
  /// Reset module (for testing)
  static void reset() {
    _initialized = false;
  }
}