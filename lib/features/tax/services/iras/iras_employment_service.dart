import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../models/iras/employment_models.dart';
import 'iras_client.dart';
import 'iras_config.dart';
import 'iras_auth_service.dart';
import 'iras_exceptions.dart';
import 'iras_audit_service.dart';

/// IRAS Employment Income Records service
/// Handles IR8A, IR8S, Appendix 8A, and Appendix 8B submissions
class IrasEmploymentService {
  final IrasApiClient _client;
  final IrasAuthService _authService;
  final IrasAuditService _auditService;
  static IrasEmploymentService? _instance;
  
  IrasEmploymentService._({
    IrasApiClient? client,
    IrasAuthService? authService,
    IrasAuditService? auditService,
  }) : _client = client ?? IrasApiClient.instance,
       _authService = authService ?? IrasAuthService.instance,
       _auditService = auditService ?? IrasAuditService.instance;
  
  /// Singleton instance
  static IrasEmploymentService get instance {
    _instance ??= IrasEmploymentService._();
    return _instance!;
  }
  
  /// Submit employment income records
  Future<EmploymentIncomeSubmissionResponse> submitEmploymentRecords(
    EmploymentIncomeSubmissionRequest request,
  ) async {
    const operation = 'EMPLOYMENT_INCOME_SUBMISSION';
    
    try {
      // Validate request
      _validateEmploymentRequest(request);
      
      // Log audit entry
      await _auditService.logOperation(
        operation: operation,
        entityType: 'EMPLOYMENT_RECORDS',
        entityId: 'bulk_submission',
        details: {
          'input_type': request.inputType,
          'validate_only': request.validateOnly,
          'bypass': request.bypass,
          'has_ir8a': request.ir8aInput != null,
          'has_ir8s': request.ir8sInput != null,
          'has_a8a': request.a8aInput != null,
          'has_a8b': request.a8bInput != null,
        },
      );
      
      // Execute authenticated request
      final responseData = await _authService.executeAuthenticatedRequest(
        (token) => _client.post(
          IrasConfig.employmentSubmissionUrl,
          request.toJson(),
          accessToken: token,
        ),
      );
      
      final response = EmploymentIncomeSubmissionResponse.fromJson(responseData);
      
      // Log result
      if (response.isSuccess) {
        await _auditService.logSuccess(
          operation: operation,
          entityType: 'EMPLOYMENT_RECORDS',
          entityId: response.data?.submissionId ?? 'unknown',
          details: {
            'submission_id': response.data?.submissionId,
            'submission_status': response.data?.submissionStatus,
            'total_records': response.data?.summary.totalRecords,
            'successful_records': response.data?.summary.successfulRecords,
            'error_records': response.data?.summary.errorRecords,
          },
        );
        
        if (kDebugMode) {
          print('✅ Employment income records submitted successfully');
          print('📋 Submission ID: ${response.data?.submissionId}');
          print('📊 Summary: ${response.data?.summary.successfulRecords}/${response.data?.summary.totalRecords} successful');
        }
      } else {
        await _auditService.logFailure(
          operation: operation,
          entityType: 'EMPLOYMENT_RECORDS',
          entityId: 'bulk_submission',
          error: 'Employment submission failed with return code: ${response.returnCode}',
          details: response.info?.toJson(),
        );
      }
      
      return response;
      
    } on IrasException catch (e) {
      await _auditService.logFailure(
        operation: operation,
        entityType: 'EMPLOYMENT_RECORDS',
        entityId: 'bulk_submission',
        error: e.message,
        details: {'exception_type': e.runtimeType.toString()},
      );
      rethrow;
    } catch (e) {
      await _auditService.logFailure(
        operation: operation,
        entityType: 'EMPLOYMENT_RECORDS',
        entityId: 'bulk_submission',
        error: 'Unexpected error: $e',
      );
      throw IrasUnknownException('Failed to submit employment records: $e');
    }
  }
  
  /// Submit IR8A records (Employee income)
  Future<EmploymentIncomeSubmissionResponse> submitIr8aRecords(
    List<Ir8aFormData> records,
    {bool validateOnly = false}
  ) async {
    final csvData = _convertIr8aToCsv(records);
    
    final request = EmploymentIncomeSubmissionRequest(
      inputType: 'CSV',
      ir8aInput: csvData,
      validateOnly: validateOnly,
    );
    
    return await submitEmploymentRecords(request);
  }
  
  /// Submit IR8S records (Director/shareholder income)
  Future<EmploymentIncomeSubmissionResponse> submitIr8sRecords(
    List<Ir8sFormData> records,
    {bool validateOnly = false}
  ) async {
    final csvData = _convertIr8sToCsv(records);
    
    final request = EmploymentIncomeSubmissionRequest(
      inputType: 'CSV',
      ir8sInput: csvData,
      validateOnly: validateOnly,
    );
    
    return await submitEmploymentRecords(request);
  }
  
  /// Submit Appendix 8A records (Benefits in Kind)
  Future<EmploymentIncomeSubmissionResponse> submitA8aRecords(
    List<A8aFormData> records,
    {bool validateOnly = false}
  ) async {
    final csvData = _convertA8aToCsv(records);
    
    final request = EmploymentIncomeSubmissionRequest(
      inputType: 'CSV',
      a8aInput: csvData,
      validateOnly: validateOnly,
    );
    
    return await submitEmploymentRecords(request);
  }
  
  /// Submit Appendix 8B records (Stock Options)
  Future<EmploymentIncomeSubmissionResponse> submitA8bRecords(
    List<A8bFormData> records,
    {bool validateOnly = false}
  ) async {
    final csvData = _convertA8bToCsv(records);
    
    final request = EmploymentIncomeSubmissionRequest(
      inputType: 'CSV',
      a8bInput: csvData,
      validateOnly: validateOnly,
    );
    
    return await submitEmploymentRecords(request);
  }
  
  /// Submit bulk employment records
  Future<EmploymentIncomeSubmissionResponse> submitBulkRecords(
    BulkEmploymentRecords bulkRecords,
    {bool validateOnly = false}
  ) async {
    final csvFormats = bulkRecords.toCsvFormat();
    
    final request = EmploymentIncomeSubmissionRequest(
      inputType: 'CSV',
      ir8aInput: csvFormats['IR8A'],
      ir8sInput: csvFormats['IR8S'],
      a8aInput: csvFormats['A8A'],
      a8bInput: csvFormats['A8B'],
      validateOnly: validateOnly,
    );
    
    return await submitEmploymentRecords(request);
  }
  
  /// Validate employment records before submission
  Future<EmploymentIncomeSubmissionResponse> validateEmploymentRecords(
    EmploymentIncomeSubmissionRequest request,
  ) async {
    final validationRequest = EmploymentIncomeSubmissionRequest(
      inputType: request.inputType,
      ir8aInput: request.ir8aInput,
      ir8sInput: request.ir8sInput,
      a8aInput: request.a8aInput,
      a8bInput: request.a8bInput,
      bypass: request.bypass,
      validateOnly: true, // Force validation only
    );
    
    return await submitEmploymentRecords(validationRequest);
  }
  
  /// Create IR8A record from employee data
  Ir8aFormData createIr8aRecord({
    required String employerUen,
    required String employerName,
    required String yearOfAssessment,
    required String employeeNric,
    required String employeeName,
    required String employeeAddress,
    required String designation,
    DateTime? employmentStartDate,
    DateTime? employmentEndDate,
    required double grossIncome,
    required double employeeCpf,
    required double employerCpf,
    double bonuses = 0,
    double benefitsInKind = 0,
    double director = 0,
    double overseasIncome = 0,
    double exemptIncome = 0,
  }) {
    final totalIncome = grossIncome + bonuses + benefitsInKind + director + overseasIncome + exemptIncome;
    
    return Ir8aFormData(
      employerUen: employerUen,
      employerName: employerName,
      yearOfAssessment: yearOfAssessment,
      employeeNric: employeeNric,
      employeeName: employeeName,
      employeeAddress: employeeAddress,
      designation: designation,
      employmentStartDate: employmentStartDate,
      employmentEndDate: employmentEndDate,
      grossIncome: grossIncome,
      employeeCpfContribution: employeeCpf,
      employerCpfContribution: employerCpf,
      bonuses: bonuses,
      benefitsInKind: benefitsInKind,
      director: director,
      overseasIncome: overseasIncome,
      exemptIncome: exemptIncome,
      totalIncome: totalIncome,
    );
  }
  
  /// Validate employment submission request
  void _validateEmploymentRequest(EmploymentIncomeSubmissionRequest request) {
    final errors = <String, List<String>>{};
    
    // Validate input type
    if (request.inputType != 'CSV' && request.inputType != 'XML') {
      errors['inputType'] = ['Input type must be CSV or XML'];
    }
    
    // Check that at least one input is provided
    if (request.ir8aInput == null &&
        request.ir8sInput == null &&
        request.a8aInput == null &&
        request.a8bInput == null) {
      errors['inputs'] = ['At least one input (IR8A, IR8S, A8A, or A8B) must be provided'];
    }
    
    // Validate CSV format if provided
    if (request.ir8aInput != null && !_isValidCsvFormat(request.ir8aInput!)) {
      errors['ir8aInput'] = ['Invalid CSV format for IR8A data'];
    }
    
    if (request.ir8sInput != null && !_isValidCsvFormat(request.ir8sInput!)) {
      errors['ir8sInput'] = ['Invalid CSV format for IR8S data'];
    }
    
    if (errors.isNotEmpty) {
      throw IrasValidationException('Employment submission validation failed', errors);
    }
  }
  
  /// Validate CSV format
  bool _isValidCsvFormat(String csvData) {
    try {
      final lines = csvData.split('\n');
      if (lines.isEmpty) return false;
      
      // Check header exists
      final header = lines.first;
      if (header.isEmpty) return false;
      
      // Check data rows exist
      final dataRows = lines.skip(1).where((line) => line.trim().isNotEmpty);
      return dataRows.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Convert IR8A records to CSV format
  String _convertIr8aToCsv(List<Ir8aFormData> records) {
    if (records.isEmpty) return '';
    
    const header = 'UEN,Employer Name,YA,NRIC,Employee Name,Address,Designation,Start Date,End Date,Gross Income,Employee CPF,Employer CPF,Bonuses,Benefits,Director,Overseas,Exempt,Total';
    final rows = records.map((record) => record.toCsvRow()).join('\n');
    
    return '$header\n$rows';
  }
  
  /// Convert IR8S records to CSV format
  String _convertIr8sToCsv(List<Ir8sFormData> records) {
    if (records.isEmpty) return '';
    
    const header = 'UEN,Employer Name,YA,NRIC,Employee Name,Designation,Shares Held,Percentage,Director Fees,Benefits,Total';
    final rows = records.map((record) => record.toCsvRow()).join('\n');
    
    return '$header\n$rows';
  }
  
  /// Convert A8A records to CSV format
  String _convertA8aToCsv(List<A8aFormData> records) {
    if (records.isEmpty) return '';
    
    const header = 'UEN,YA,NRIC,Employee Name,Benefit Type,Description,Value,Period';
    final rows = <String>[];
    
    for (final record in records) {
      for (final benefit in record.benefits) {
        rows.add([
          record.employerUen,
          record.yearOfAssessment,
          record.employeeNric,
          record.employeeName,
          benefit.benefitType,
          benefit.description.replaceAll(',', ';'),
          benefit.value.toStringAsFixed(2),
          benefit.period,
        ].join(','));
      }
    }
    
    return '$header\n${rows.join('\n')}';
  }
  
  /// Convert A8B records to CSV format
  String _convertA8bToCsv(List<A8bFormData> records) {
    if (records.isEmpty) return '';
    
    const header = 'UEN,YA,NRIC,Employee Name,Grant Date,Exercise Date,Shares,Exercise Price,Market Price,Benefit Value';
    final rows = <String>[];
    
    for (final record in records) {
      for (final option in record.stockOptions) {
        rows.add([
          record.employerUen,
          record.yearOfAssessment,
          record.employeeNric,
          record.employeeName,
          option.grantDate,
          option.exerciseDate,
          option.numberOfShares.toString(),
          option.exercisePrice.toStringAsFixed(2),
          option.marketPrice.toStringAsFixed(2),
          option.benefitValue.toStringAsFixed(2),
        ].join(','));
      }
    }
    
    return '$header\n${rows.join('\n')}';
  }
  
  /// Create sample employment records for testing
  static BulkEmploymentRecords createSampleRecords() {
    final currentYear = DateTime.now().year.toString();
    
    return BulkEmploymentRecords(
      employerUen: '200012345A',
      yearOfAssessment: currentYear,
      ir8aRecords: [
        Ir8aFormData(
          employerUen: '200012345A',
          employerName: 'Sample Company Pte Ltd',
          yearOfAssessment: currentYear,
          employeeNric: 'S1234567A',
          employeeName: 'John Doe',
          employeeAddress: '123 Sample Street, Singapore 123456',
          designation: 'Software Engineer',
          employmentStartDate: DateTime(int.parse(currentYear) - 1, 1, 1),
          employmentEndDate: DateTime(int.parse(currentYear) - 1, 12, 31),
          grossIncome: 60000.00,
          employeeCpfContribution: 12000.00,
          employerCpfContribution: 10200.00,
          bonuses: 8000.00,
          benefitsInKind: 2400.00,
          director: 0.00,
          overseasIncome: 0.00,
          exemptIncome: 0.00,
          totalIncome: 70400.00,
        ),
      ],
      ir8sRecords: [
        Ir8sFormData(
          employerUen: '200012345A',
          employerName: 'Sample Company Pte Ltd',
          yearOfAssessment: currentYear,
          employeeNric: 'S7654321B',
          employeeName: 'Jane Smith',
          designation: 'Director',
          sharesHeld: 100000,
          percentageOwnership: 25.00,
          directorFees: 24000.00,
          benefitsInKind: 3600.00,
          totalIncome: 27600.00,
        ),
      ],
    );
  }
}