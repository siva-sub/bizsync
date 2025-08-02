import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/iras/gst_models.dart';
import '../../models/iras/corporate_tax_models.dart';
import '../../models/iras/employment_models.dart';
import 'iras_auth_service.dart';
import 'iras_gst_service.dart';
import 'iras_corporate_tax_service.dart';
import 'iras_employment_service.dart';
import 'iras_audit_service.dart';
import 'iras_config.dart';
import 'iras_exceptions.dart';

/// Unified IRAS service facade
/// Provides a single entry point for all IRAS API operations
class IrasService {
  final IrasAuthService _authService;
  final IrasGstService _gstService;
  final IrasCorporateTaxService _corporateTaxService;
  final IrasEmploymentService _employmentService;
  final IrasAuditService _auditService;
  
  static IrasService? _instance;
  
  IrasService._({
    IrasAuthService? authService,
    IrasGstService? gstService,
    IrasCorporateTaxService? corporateTaxService,
    IrasEmploymentService? employmentService,
    IrasAuditService? auditService,
  }) : _authService = authService ?? IrasAuthService.instance,
       _gstService = gstService ?? IrasGstService.instance,
       _corporateTaxService = corporateTaxService ?? IrasCorporateTaxService.instance,
       _employmentService = employmentService ?? IrasEmploymentService.instance,
       _auditService = auditService ?? IrasAuditService.instance;
  
  /// Singleton instance
  static IrasService get instance {
    _instance ??= IrasService._();
    return _instance!;
  }
  
  // ==================== AUTHENTICATION ====================
  
  /// Check if currently authenticated with IRAS
  bool get isAuthenticated => _authService.isAuthenticated;
  
  /// Get current access token
  String? get accessToken => _authService.accessToken;
  
  /// Time until token expires
  Duration? get timeUntilExpiry => _authService.timeUntilExpiry;
  
  /// Initiate SingPass authentication
  Future<String> initiateAuthentication({
    required String callbackUrl,
    List<String>? scopes,
    String? state,
  }) async {
    scopes ??= IrasAuthService.commonScopes['full']!;
    
    return await _authService.initiateSingPassAuth(
      callbackUrl: callbackUrl,
      scopes: scopes,
      state: state,
    );
  }
  
  /// Complete authentication with authorization code
  Future<void> completeAuthentication({
    required String code,
    required String state,
    required String callbackUrl,
    List<String>? scopes,
  }) async {
    scopes ??= IrasAuthService.commonScopes['full']!;
    
    await _authService.completeSingPassAuth(
      code: code,
      state: state,
      callbackUrl: callbackUrl,
      scopes: scopes,
    );
  }
  
  /// Logout and clear authentication
  void logout() {
    _authService.clearAuth();
  }
  
  // ==================== GST SERVICES ====================
  
  /// Submit GST F5 Return
  Future<GstF5SubmissionResponse> submitGstF5Return(
    GstF5SubmissionRequest request,
  ) async {
    return await _gstService.submitF5Return(request);
  }
  
  /// Submit GST F8 Return (Annual Return)
  Future<Map<String, dynamic>> submitGstF8Return(
    Map<String, dynamic> request,
  ) async {
    return await _gstService.submitF8Return(request);
  }
  
  /// Edit Past GST Return (F7)
  Future<Map<String, dynamic>> editPastGstReturn(
    Map<String, dynamic> request,
  ) async {
    return await _gstService.editPastGstReturn(request);
  }
  
  /// Submit GST Transaction Listings
  Future<Map<String, dynamic>> submitGstTransactionListing(
    Map<String, dynamic> request,
  ) async {
    return await _gstService.submitGstTransactionListing(request);
  }
  
  /// Check GST Registration Status
  Future<GstRegisterCheckResponse> checkGstRegister(String gstRegNo) async {
    return await _gstService.checkGstRegister(gstRegNo);
  }
  
  // ==================== CORPORATE TAX SERVICES ====================
  
  /// Convert accounting data to Form C-S
  Future<CitConversionResponse> convertToFormCS(
    CitConversionRequest request,
  ) async {
    return await _corporateTaxService.convertToFormCS(request);
  }
  
  /// Generate tax computation
  Future<CitTaxComputation> generateTaxComputation(
    CitFinancialData financialData, {
    required String yearOfAssessment,
    String? clientId,
  }) async {
    return await _corporateTaxService.generateTaxComputation(
      financialData,
      yearOfAssessment: yearOfAssessment,
      clientId: clientId,
    );
  }
  
  /// Generate profit & loss statement
  Future<CitProfitLossStatement> generateProfitLossStatement(
    CitFinancialData financialData, {
    required String yearOfAssessment,
    String? clientId,
  }) async {
    return await _corporateTaxService.generateProfitLossStatement(
      financialData,
      yearOfAssessment: yearOfAssessment,
      clientId: clientId,
    );
  }
  
  /// Check eligibility for Form C-S
  Future<bool> checkFormCSEligibility(CitFinancialData financialData) async {
    return await _corporateTaxService.checkFormCSEligibility(financialData);
  }
  
  /// Calculate estimated corporate tax
  Future<double> calculateEstimatedTax(
    CitFinancialData financialData, {
    required String yearOfAssessment,
  }) async {
    return await _corporateTaxService.calculateEstimatedTax(
      financialData,
      yearOfAssessment: yearOfAssessment,
    );
  }
  
  // ==================== EMPLOYMENT SERVICES ====================
  
  /// Submit employment income records
  Future<EmploymentIncomeSubmissionResponse> submitEmploymentRecords(
    EmploymentIncomeSubmissionRequest request,
  ) async {
    return await _employmentService.submitEmploymentRecords(request);
  }
  
  /// Submit IR8A records (Employee income)
  Future<EmploymentIncomeSubmissionResponse> submitIr8aRecords(
    List<Ir8aFormData> records, {
    bool validateOnly = false,
  }) async {
    return await _employmentService.submitIr8aRecords(
      records,
      validateOnly: validateOnly,
    );
  }
  
  /// Submit IR8S records (Director/shareholder income)
  Future<EmploymentIncomeSubmissionResponse> submitIr8sRecords(
    List<Ir8sFormData> records, {
    bool validateOnly = false,
  }) async {
    return await _employmentService.submitIr8sRecords(
      records,
      validateOnly: validateOnly,
    );
  }
  
  /// Submit bulk employment records
  Future<EmploymentIncomeSubmissionResponse> submitBulkEmploymentRecords(
    BulkEmploymentRecords bulkRecords, {
    bool validateOnly = false,
  }) async {
    return await _employmentService.submitBulkRecords(
      bulkRecords,
      validateOnly: validateOnly,
    );
  }
  
  /// Validate employment records
  Future<EmploymentIncomeSubmissionResponse> validateEmploymentRecords(
    EmploymentIncomeSubmissionRequest request,
  ) async {
    return await _employmentService.validateEmploymentRecords(request);
  }
  
  // ==================== AUDIT & COMPLIANCE ====================
  
  /// Get audit logs
  Future<List<Map<String, dynamic>>> getAuditLogs({
    String? entityType,
    String? entityId,
    String? operation,
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
  }) async {
    return await _auditService.getAuditLogs(
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      fromDate: fromDate,
      toDate: toDate,
      limit: limit,
    );
  }
  
  /// Get audit summary for compliance reporting
  Future<Map<String, dynamic>> getAuditSummary({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    return await _auditService.getAuditSummary(
      fromDate: fromDate,
      toDate: toDate,
    );
  }
  
  /// Export audit logs for compliance
  Future<List<Map<String, dynamic>>> exportAuditLogs({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    return await _auditService.exportAuditLogs(
      fromDate: fromDate,
      toDate: toDate,
    );
  }
  
  // ==================== UTILITY METHODS ====================
  
  /// Get IRAS service status
  Map<String, dynamic> getServiceStatus() {
    return {
      'is_configured': IrasConfig.isConfigured,
      'is_authenticated': isAuthenticated,
      'token_expires_in': timeUntilExpiry?.inMinutes,
      'services': {
        'gst': 'available',
        'corporate_tax': 'available',
        'employment': 'available',
        'audit': 'available',
      },
      'endpoints': {
        'auth': IrasConfig.authBaseUrl,
        'gst': IrasConfig.gstBaseUrl,
        'corporate_tax': IrasConfig.corporateTaxBaseUrl,
        'employment': IrasConfig.employmentBaseUrl,
      },
    };
  }
  
  /// Test IRAS connectivity
  Future<Map<String, dynamic>> testConnectivity() async {
    final results = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'overall_status': 'unknown',
      'tests': <String, dynamic>{},
    };
    
    try {
      // Test GST register check (no auth required)
      final testGstResult = await checkGstRegister('M12345678A');
      results['tests']['gst_register_check'] = {
        'status': 'success',
        'message': 'GST register check endpoint accessible',
      };
    } catch (e) {
      results['tests']['gst_register_check'] = {
        'status': 'error',
        'message': 'GST register check failed: $e',
      };
    }
    
    // Test authentication if available
    if (isAuthenticated) {
      results['tests']['authentication'] = {
        'status': 'success',
        'message': 'Currently authenticated',
        'expires_in_minutes': timeUntilExpiry?.inMinutes,
      };
    } else {
      results['tests']['authentication'] = {
        'status': 'warning',
        'message': 'Not authenticated - some services may not be available',
      };
    }
    
    // Determine overall status
    final testResults = results['tests'] as Map<String, dynamic>;
    final hasErrors = testResults.values.any((test) => test['status'] == 'error');
    final hasWarnings = testResults.values.any((test) => test['status'] == 'warning');
    
    if (hasErrors) {
      results['overall_status'] = 'error';
    } else if (hasWarnings) {
      results['overall_status'] = 'warning';
    } else {
      results['overall_status'] = 'success';
    }
    
    return results;
  }
  
  /// Create sample data for testing
  Map<String, dynamic> createSampleData() {
    return {
      'gst_f5_request': IrasGstService.createSampleF5Request(),
      'cit_request': IrasCorporateTaxService.createSampleCitRequest(),
      'employment_records': IrasEmploymentService.createSampleRecords(),
    };
  }
  
  /// Get integration guide
  Map<String, dynamic> getIntegrationGuide() {
    return {
      'overview': 'IRAS API Integration for BizSync',
      'authentication': {
        'method': 'SingPass/CorpPass OAuth 2.0',
        'scopes': IrasAuthService.commonScopes,
        'callback_url_required': true,
      },
      'available_services': {
        'gst': {
          'description': 'GST return submission and filing',
          'forms_supported': ['F5', 'F7', 'F8'],
          'additional_features': ['Transaction listings', 'Register check'],
        },
        'corporate_tax': {
          'description': 'Corporate Income Tax computation and Form C-S generation',
          'features': ['CIT conversion', 'Tax computation', 'P&L generation'],
        },
        'employment': {
          'description': 'Employment income records submission',
          'forms_supported': ['IR8A', 'IR8S', 'Appendix 8A', 'Appendix 8B'],
        },
      },
      'compliance_features': {
        'audit_logging': 'All operations are logged for compliance',
        'error_handling': 'Comprehensive error handling and retry logic',
        'data_validation': 'Pre-submission validation to prevent errors',
      },
      'getting_started': [
        '1. Configure IRAS API credentials in IrasConfig',
        '2. Initiate authentication with initiateAuthentication()',
        '3. Complete authentication flow with completeAuthentication()',
        '4. Use service methods to submit returns and records',
        '5. Monitor operations through audit logs',
      ],
    };
  }
}