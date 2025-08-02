import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/iras/gst_models.dart';
import 'iras_client.dart';
import 'iras_config.dart';
import 'iras_auth_service.dart';
import 'iras_exceptions.dart';
import 'iras_audit_service.dart';

/// IRAS GST services for submission and filing
class IrasGstService {
  final IrasApiClient _client;
  final IrasAuthService _authService;
  final IrasAuditService _auditService;
  static IrasGstService? _instance;
  
  IrasGstService._({
    IrasApiClient? client,
    IrasAuthService? authService,
    IrasAuditService? auditService,
  }) : _client = client ?? IrasApiClient.instance,
       _authService = authService ?? IrasAuthService.instance,
       _auditService = auditService ?? IrasAuditService.instance;
  
  /// Singleton instance
  static IrasGstService get instance {
    _instance ??= IrasGstService._();
    return _instance!;
  }
  
  /// Submit GST F5 Return
  Future<GstF5SubmissionResponse> submitF5Return(
    GstF5SubmissionRequest request,
  ) async {
    const operation = 'GST_F5_SUBMISSION';
    
    try {
      // Validate request
      _validateF5Request(request);
      
      // Log audit entry
      await _auditService.logOperation(
        operation: operation,
        entityType: 'GST_RETURN',
        entityId: request.filingInfo.taxRefNo,
        details: {
          'form_type': request.filingInfo.formType,
          'period_start': request.filingInfo.dtPeriodStart,
          'period_end': request.filingInfo.dtPeriodEnd,
          'total_standard_supply': request.supplies.totStdSupply,
          'net_gst_amount': request.taxes.outputTaxDue - request.taxes.inputTaxRefund,
        },
      );
      
      // Execute authenticated request
      final responseData = await _authService.executeAuthenticatedRequest(
        (token) => _client.post(
          IrasConfig.gstF5SubmissionUrl,
          request.toJson(),
          accessToken: token,
        ),
      );
      
      final response = GstF5SubmissionResponse.fromJson(responseData);
      
      // Log successful submission
      if (response.isSuccess) {
        await _auditService.logSuccess(
          operation: operation,
          entityType: 'GST_RETURN',
          entityId: request.filingInfo.taxRefNo,
          details: {
            'acknowledgment_number': response.data?.filingInfo.ackNo,
            'submission_date': response.data?.filingInfo.dtSubmission,
            'company_name': response.data?.filingInfo.companyName,
          },
        );
        
        if (kDebugMode) {
          print('✅ GST F5 Return submitted successfully');
          print('📄 Acknowledgment: ${response.data?.filingInfo.ackNo}');
        }
      } else {
        await _auditService.logFailure(
          operation: operation,
          entityType: 'GST_RETURN',
          entityId: request.filingInfo.taxRefNo,
          error: 'IRAS API returned error code: ${response.returnCode}',
          details: response.info?.toJson(),
        );
      }
      
      return response;
      
    } on IrasException catch (e) {
      await _auditService.logFailure(
        operation: operation,
        entityType: 'GST_RETURN',
        entityId: request.filingInfo.taxRefNo,
        error: e.message,
        details: {'exception_type': e.runtimeType.toString()},
      );
      rethrow;
    } catch (e) {
      await _auditService.logFailure(
        operation: operation,
        entityType: 'GST_RETURN',
        entityId: request.filingInfo.taxRefNo,
        error: 'Unexpected error: $e',
      );
      throw IrasUnknownException('Failed to submit GST F5 return: $e');
    }
  }
  
  /// Submit GST F8 Return (Annual Return)
  Future<Map<String, dynamic>> submitF8Return(
    Map<String, dynamic> request,
  ) async {
    const operation = 'GST_F8_SUBMISSION';
    
    try {
      final taxRefNo = request['filingInfo']?['taxRefNo'] as String?;
      
      await _auditService.logOperation(
        operation: operation,
        entityType: 'GST_ANNUAL_RETURN',
        entityId: taxRefNo ?? 'unknown',
        details: request,
      );
      
      final responseData = await _authService.executeAuthenticatedRequest(
        (token) => _client.post(
          IrasConfig.gstF8SubmissionUrl,
          request,
          accessToken: token,
        ),
      );
      
      await _auditService.logSuccess(
        operation: operation,
        entityType: 'GST_ANNUAL_RETURN',
        entityId: taxRefNo ?? 'unknown',
        details: responseData,
      );
      
      return responseData;
      
    } catch (e) {
      await _auditService.logFailure(
        operation: operation,
        entityType: 'GST_ANNUAL_RETURN',
        entityId: request['filingInfo']?['taxRefNo'] as String? ?? 'unknown',
        error: 'Failed to submit F8 return: $e',
      );
      rethrow;
    }
  }
  
  /// Edit Past GST Return (F7)
  Future<Map<String, dynamic>> editPastGstReturn(
    Map<String, dynamic> request,
  ) async {
    const operation = 'GST_F7_EDIT';
    
    try {
      final taxRefNo = request['filingInfo']?['taxRefNo'] as String?;
      
      await _auditService.logOperation(
        operation: operation,
        entityType: 'GST_RETURN_EDIT',
        entityId: taxRefNo ?? 'unknown',
        details: request,
      );
      
      final responseData = await _authService.executeAuthenticatedRequest(
        (token) => _client.post(
          IrasConfig.gstF7EditUrl,
          request,
          accessToken: token,
        ),
      );
      
      await _auditService.logSuccess(
        operation: operation,
        entityType: 'GST_RETURN_EDIT',
        entityId: taxRefNo ?? 'unknown',
        details: responseData,
      );
      
      return responseData;
      
    } catch (e) {
      await _auditService.logFailure(
        operation: operation,
        entityType: 'GST_RETURN_EDIT',
        entityId: request['filingInfo']?['taxRefNo'] as String? ?? 'unknown',
        error: 'Failed to edit GST return: $e',
      );
      rethrow;
    }
  }
  
  /// Submit GST Transaction Listings
  Future<Map<String, dynamic>> submitGstTransactionListing(
    Map<String, dynamic> request,
  ) async {
    const operation = 'GST_TRANSACTION_LISTING';
    
    try {
      final taxRefNo = request['filingInfo']?['taxRefNo'] as String?;
      
      await _auditService.logOperation(
        operation: operation,
        entityType: 'GST_TRANSACTION_LISTING',
        entityId: taxRefNo ?? 'unknown',
        details: request,
      );
      
      final responseData = await _authService.executeAuthenticatedRequest(
        (token) => _client.post(
          IrasConfig.gstTransactionListingUrl,
          request,
          accessToken: token,
        ),
      );
      
      await _auditService.logSuccess(
        operation: operation,
        entityType: 'GST_TRANSACTION_LISTING',
        entityId: taxRefNo ?? 'unknown',
        details: responseData,
      );
      
      return responseData;
      
    } catch (e) {
      await _auditService.logFailure(
        operation: operation,
        entityType: 'GST_TRANSACTION_LISTING',
        entityId: request['filingInfo']?['taxRefNo'] as String? ?? 'unknown',
        error: 'Failed to submit transaction listing: $e',
      );
      rethrow;
    }
  }
  
  /// Check GST Registration Status
  Future<GstRegisterCheckResponse> checkGstRegister(
    String gstRegNo,
  ) async {
    const operation = 'GST_REGISTER_CHECK';
    
    try {
      // Validate GST registration number format
      if (!_isValidGstRegNo(gstRegNo)) {
        throw const IrasValidationException(
          'Invalid GST registration number format',
          {'gstRegNo': ['Must be in format MXXXXXXXX (M + 8 digits + check character)']},
        );
      }
      
      await _auditService.logOperation(
        operation: operation,
        entityType: 'GST_REGISTER',
        entityId: gstRegNo,
      );
      
      final request = GstRegisterCheckRequest(gstRegNo: gstRegNo);
      
      // GST register check doesn't require authentication
      final responseData = await _client.post(
        IrasConfig.gstRegisterCheckUrl,
        request.toJson(),
      );
      
      final response = GstRegisterCheckResponse.fromJson(responseData);
      
      if (response.isSuccess) {
        await _auditService.logSuccess(
          operation: operation,
          entityType: 'GST_REGISTER',
          entityId: gstRegNo,
          details: response.data?.toJson(),
        );
      } else {
        await _auditService.logFailure(
          operation: operation,
          entityType: 'GST_REGISTER',
          entityId: gstRegNo,
          error: 'GST register check failed',
          details: response.info?.toJson(),
        );
      }
      
      return response;
      
    } catch (e) {
      await _auditService.logFailure(
        operation: operation,
        entityType: 'GST_REGISTER',
        entityId: gstRegNo,
        error: 'Failed to check GST register: $e',
      );
      rethrow;
    }
  }
  
  /// Validate GST F5 submission request
  void _validateF5Request(GstF5SubmissionRequest request) {
    final errors = <String, List<String>>{};
    
    // Validate tax reference number
    if (request.filingInfo.taxRefNo.isEmpty) {
      errors['taxRefNo'] = ['Tax reference number is required'];
    }
    
    // Validate form type
    if (request.filingInfo.formType != 'F5') {
      errors['formType'] = ['Form type must be F5'];
    }
    
    // Validate period dates
    try {
      DateTime.parse(request.filingInfo.dtPeriodStart);
      DateTime.parse(request.filingInfo.dtPeriodEnd);
    } catch (e) {
      errors['period'] = ['Invalid date format - use YYYY-MM-DD'];
    }
    
    // Validate amounts are non-negative
    if (request.supplies.totStdSupply < 0 ||
        request.supplies.totZeroSupply < 0 ||
        request.supplies.totExemptSupply < 0) {
      errors['supplies'] = ['Supply amounts cannot be negative'];
    }
    
    if (request.purchases.totTaxPurchase < 0) {
      errors['purchases'] = ['Purchase amounts cannot be negative'];
    }
    
    if (request.taxes.outputTaxDue < 0 ||
        request.taxes.inputTaxRefund < 0) {
      errors['taxes'] = ['Tax amounts cannot be negative'];
    }
    
    // Validate contact information
    if (request.declaration.contactPerson.isEmpty) {
      errors['contactPerson'] = ['Contact person is required'];
    }
    
    if (request.declaration.contactEmail.isEmpty) {
      errors['contactEmail'] = ['Contact email is required'];
    } else if (!_isValidEmail(request.declaration.contactEmail)) {
      errors['contactEmail'] = ['Invalid email format'];
    }
    
    if (request.declaration.contactNumber.isEmpty) {
      errors['contactNumber'] = ['Contact number is required'];
    }
    
    if (errors.isNotEmpty) {
      throw IrasValidationException('GST F5 validation failed', errors);
    }
  }
  
  /// Validate GST registration number format
  bool _isValidGstRegNo(String gstRegNo) {
    // GST reg no format: MXXXXXXXX (M + 8 digits + check character)
    final pattern = RegExp(r'^M\d{8}[A-Z]$');
    return pattern.hasMatch(gstRegNo.toUpperCase());
  }
  
  /// Validate email format
  bool _isValidEmail(String email) {
    final pattern = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return pattern.hasMatch(email);
  }
  
  /// Create a sample GST F5 request for testing
  static GstF5SubmissionRequest createSampleF5Request() {
    return GstF5SubmissionRequest(
      filingInfo: const GstFilingInfo(
        taxRefNo: '190000000A',
        formType: 'F5',
        dtPeriodStart: '2024-01-01',
        dtPeriodEnd: '2024-03-31',
      ),
      supplies: const GstSupplies(
        totStdSupply: 50303.00,
        totZeroSupply: 454533.00,
        totExemptSupply: 326723.00,
      ),
      purchases: const GstPurchases(
        totTaxPurchase: 700824.00,
      ),
      taxes: const GstTaxes(
        outputTaxDue: 3521.21,
        inputTaxRefund: 14468.90,
      ),
      schemes: const GstSchemes(
        totValueScheme: 345887.00,
        touristRefundChk: false,
        touristRefundAmt: 0.00,
        badDebtChk: true,
        badDebtReliefClaimAmt: 1.00,
        preRegistrationChk: false,
        preRegistrationClaimAmt: 0.00,
      ),
      revenue: const GstRevenue(
        revenue: 831600.00,
      ),
      igdScheme: const GstIgdScheme(
        defImpPayableAmt: 0.00,
        defTotalGoodsImp: 0.00,
      ),
      declaration: const GstDeclaration(
        declarantDesgtn: 'DIRECTOR',
        contactPerson: 'Jane Lee',
        contactNumber: '91231234',
        contactEmail: 'jane.lee@company.com.sg',
      ),
      reasons: const GstReasons(
        grp1BadDebtRecoveryChk: true,
        grp1PriorToRegChk: false,
        grp1OtherReasonChk: false,
        grp1OtherReasons: '',
        grp2TouristRefundChk: false,
        grp2AppvBadDebtReliefChk: false,
        grp2CreditNotesChk: false,
        grp2OtherReasonsChk: true,
        grp2OtherReasons: 'Sample reason',
        grp3CreditNotesChk: false,
        grp3OtherReasonsChk: false,
        grp3OtherReasons: '',
      ),
    );
  }
}