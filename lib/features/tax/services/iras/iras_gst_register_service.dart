import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/iras/gst_register_models.dart';
import 'iras_client.dart';
import 'iras_config.dart';
import 'iras_exceptions.dart';
import 'iras_audit_service.dart';

/// IRAS GST Register Check Service
/// Based on Check_GST_Register-1.0.7.yaml specification
/// Enables checking whether businesses are GST-registered based on their GST registration number, UEN or NRIC
class IrasGstRegisterService {
  final IrasApiClient _client;
  final IrasAuditService _auditService;
  static IrasGstRegisterService? _instance;
  
  IrasGstRegisterService._({
    IrasApiClient? client,
    IrasAuditService? auditService,
  }) : _client = client ?? IrasApiClient.instance,
       _auditService = auditService ?? IrasAuditService.instance;
  
  /// Singleton instance
  static IrasGstRegisterService get instance {
    _instance ??= IrasGstRegisterService._();
    return _instance!;
  }
  
  /// Check GST Registration Status based on Check_GST_Register-1.0.7.yaml
  /// Checks whether businesses are GST-registered based on their GST registration number, UEN or NRIC
  Future<GstRegisterCheckResponse> checkGstRegister(
    String registrationId, {
    String? clientId,
  }) async {
    const operation = 'GST_REGISTER_CHECK';
    
    try {
      // Validate registration ID format
      if (!_isValidRegistrationId(registrationId)) {
        throw const IrasValidationException(
          'Invalid registration ID format',
          {'regID': ['Must be a valid GST registration number (MXXXXXXXX), UEN (XXXXXXXXXXX), or NRIC (SXXXXXXXX/TXXXXXXXX)']},
        );
      }
      
      await _auditService.logOperation(
        operation: operation,
        entityType: 'GST_REGISTER',
        entityId: registrationId,
        details: {
          'registration_type': _getRegistrationType(registrationId),
          'client_id': clientId ?? IrasConfig.clientId,
        },
      );
      
      final request = GstRegisterCheckRequest(
        clientID: clientId ?? IrasConfig.clientId,
        regID: registrationId,
      );
      
      // GST register check uses Client ID/Secret headers (no authentication token required)
      final responseData = await _client.post(
        IrasConfig.gstRegisterCheckUrl,
        request.toJson(),
      );
      
      final response = GstRegisterCheckResponse.fromJson(responseData);
      
      if (response.isSuccess) {
        await _auditService.logSuccess(
          operation: operation,
          entityType: 'GST_REGISTER',
          entityId: registrationId,
          details: {
            'found_registration': response.data != null,
            'gst_reg_number': response.data?.gstRegistrationNumber,
            'organization_name': response.data?.name,
            'status': response.data?.status,
            'is_active': response.data?.isActiveRegistration ?? false,
            'registered_from': response.data?.registeredFrom,
            'registered_to': response.data?.registeredTo,
            'remarks': response.data?.remarks,
          },
        );
        
        if (kDebugMode) {
          print('✅ GST register check completed successfully');
          if (response.data != null) {
            final data = response.data!;
            print('🏢 Organization: ${data.name ?? "N/A"}');
            print('🆔 GST Number: ${data.gstRegistrationNumber ?? "N/A"}');
            print('📊 Status: ${data.status ?? "N/A"}');
            print('🔄 Active: ${data.isActiveRegistration}');
            print('📅 Registered From: ${data.registeredFrom ?? "N/A"}');
            print('📅 Registered To: ${data.registeredTo ?? "Ongoing"}');
            if (data.remarks != null && data.remarks!.isNotEmpty) {
              print('💬 Remarks: ${data.remarks}');
            }
          } else {
            print('ℹ️ No GST registration found for: $registrationId');
          }
        }
      } else {
        await _auditService.logFailure(
          operation: operation,
          entityType: 'GST_REGISTER',
          entityId: registrationId,
          error: 'GST register check failed with return code: ${response.returnCode}',
          details: {
            'return_code': response.returnCode,
            'error_info': response.info?.toJson(),
            'field_errors': response.info?.fieldInfoList?.map((f) => {
              'field': f.field,
              'message': f.message,
            }).toList(),
          },
        );
      }
      
      return response;
      
    } catch (e) {
      await _auditService.logFailure(
        operation: operation,
        entityType: 'GST_REGISTER',
        entityId: registrationId,
        error: 'Failed to check GST register: $e',
      );
      rethrow;
    }
  }
  
  /// Bulk check multiple registration IDs
  Future<Map<String, GstRegisterCheckResponse>> checkMultipleGstRegisters(
    List<String> registrationIds, {
    String? clientId,
  }) async {
    final results = <String, GstRegisterCheckResponse>{};
    
    for (final regId in registrationIds) {
      try {
        final response = await checkGstRegister(regId, clientId: clientId);
        results[regId] = response;
        
        // Add a small delay between requests to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        if (kDebugMode) {
          print('Error checking $regId: $e');
        }
        // Continue with other registrations even if one fails
      }
    }
    
    return results;
  }
  
  /// Check if a business is currently GST registered
  Future<bool> isGstRegistered(String registrationId, {String? clientId}) async {
    try {
      final response = await checkGstRegister(registrationId, clientId: clientId);
      return response.isSuccess && 
             response.data != null && 
             response.data!.isGstRegistered;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking GST registration status: $e');
      }
      return false;
    }
  }
  
  /// Check if a business has active GST registration
  Future<bool> hasActiveGstRegistration(String registrationId, {String? clientId}) async {
    try {
      final response = await checkGstRegister(registrationId, clientId: clientId);
      return response.isSuccess && 
             response.data != null && 
             response.data!.isActiveRegistration;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking active GST registration: $e');
      }
      return false;
    }
  }
  
  /// Get GST registration details
  Future<GstRegisterData?> getGstRegistrationDetails(
    String registrationId, {
    String? clientId,
  }) async {
    try {
      final response = await checkGstRegister(registrationId, clientId: clientId);
      return response.isSuccess ? response.data : null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting GST registration details: $e');
      }
      return null;
    }
  }
  
  /// Validate registration ID format (GST reg no, UEN, or NRIC)
  bool _isValidRegistrationId(String regId) {
    if (regId.isEmpty) return false;
    
    final upperRegId = regId.toUpperCase().trim();
    
    // GST registration number: MXXXXXXXX (M + 8 digits + check character)
    final gstPattern = RegExp(r'^M\d{8}[A-Z]$');
    if (gstPattern.hasMatch(upperRegId)) return true;
    
    // UEN: Various formats (simplified validation)
    // Format examples: 53012345M, 200012345N, T08LL1234J
    final uenPattern = RegExp(r'^(\d{8}[A-Z]|[A-Z]\d{2}[A-Z]{2}\d{4}[A-Z]|\d{9}[A-Z])$');
    if (uenPattern.hasMatch(upperRegId)) return true;
    
    // NRIC/FIN: SXXXXXXXX or TXXXXXXXX (S/T + 7 digits + check character)
    final nricPattern = RegExp(r'^[ST]\d{7}[A-Z]$');
    if (nricPattern.hasMatch(upperRegId)) return true;
    
    return false;
  }
  
  /// Get registration type for logging and validation
  String _getRegistrationType(String regId) {
    final upperRegId = regId.toUpperCase().trim();
    
    if (RegExp(r'^M\d{8}[A-Z]$').hasMatch(upperRegId)) {
      return 'GST_REGISTRATION_NUMBER';
    } else if (RegExp(r'^[ST]\d{7}[A-Z]$').hasMatch(upperRegId)) {
      return 'NRIC_FIN';
    } else {
      return 'UEN';
    }
  }
  
  /// Validate specific GST registration number format
  bool isValidGstRegistrationNumber(String gstRegNo) {
    if (gstRegNo.isEmpty) return false;
    final pattern = RegExp(r'^M\d{8}[A-Z]$');
    return pattern.hasMatch(gstRegNo.toUpperCase().trim());
  }
  
  /// Validate UEN format
  bool isValidUen(String uen) {
    if (uen.isEmpty) return false;
    final upperUen = uen.toUpperCase().trim();
    final pattern = RegExp(r'^(\d{8}[A-Z]|[A-Z]\d{2}[A-Z]{2}\d{4}[A-Z]|\d{9}[A-Z])$');
    return pattern.hasMatch(upperUen);
  }
  
  /// Validate NRIC/FIN format
  bool isValidNricFin(String nricFin) {
    if (nricFin.isEmpty) return false;
    final pattern = RegExp(r'^[ST]\d{7}[A-Z]$');
    return pattern.hasMatch(nricFin.toUpperCase().trim());
  }
  
  /// Create sample request for testing
  static GstRegisterCheckRequest createSampleRequest() {
    return createSampleGstRegisterRequest();
  }
}