import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/iras/cit_conversion_models.dart';
import 'iras_client.dart';
import 'iras_config.dart';
import 'iras_exceptions.dart';
import 'iras_audit_service.dart';

/// IRAS CIT Conversion API Service
/// Based on CIT_Conversion-1.0.8.yaml specification
/// Provides conversion of accounting data to Form C-S with supporting schedules
class IrasCitConversionService {
  final IrasApiClient _client;
  final IrasAuditService _auditService;
  static IrasCitConversionService? _instance;

  IrasCitConversionService._({
    IrasApiClient? client,
    IrasAuditService? auditService,
  })  : _client = client ?? IrasApiClient.instance,
        _auditService = auditService ?? IrasAuditService.instance;

  /// Singleton instance
  static IrasCitConversionService get instance {
    _instance ??= IrasCitConversionService._();
    return _instance!;
  }

  /// Convert accounting data to Form C-S using CIT Conversion API
  /// Generates: Profit & Loss Statement, Tax Computation, Form C-S, and 4 supporting schedules
  Future<CitConversionResponse> convertToFormCS(
    CitConversionRequest request,
  ) async {
    const operation = 'CIT_CONVERSION';

    try {
      // Validate request
      _validateCitRequest(request);

      // Log audit entry
      await _auditService.logOperation(
        operation: operation,
        entityType: 'CORPORATE_TAX',
        entityId: request.clientID,
        details: {
          'year_of_assessment': request.filingInfo.ya,
          'total_revenue': request.data.totalRevenue,
          'qualified_for_form_cs':
              request.declaration.isQualifiedToUseConvFormCS,
          'has_assets': {
            'non_hp_equipment':
                request.nonHPCompCommEquipment?.isNotEmpty ?? false,
            'non_hp_ppe': request.nonHpOtherPPE?.isNotEmpty ?? false,
            'low_value_assets':
                request.nonHpOtherPPE_LowValueAsset?.isNotEmpty ?? false,
            'hp_assets': request.hpOtherPPE?.isNotEmpty ?? false,
          },
        },
      );

      // Execute request (CIT API uses X-IBM-Client-Id and X-IBM-Client-Secret headers)
      final responseData = await _client.post(
        IrasConfig.citConversionUrl,
        request.toJson(),
      );

      final response = CitConversionResponse.fromJson(responseData);

      // Log result
      if (response.isSuccess) {
        await _auditService.logSuccess(
          operation: operation,
          entityType: 'CORPORATE_TAX',
          entityId: request.clientID,
          details: {
            'conversion_successful': true,
            'return_code': response.returnCode,
            'year_of_assessment': request.filingInfo.ya,
            'generated_documents': {
              'profit_loss_statement': response.data?.dataDtlPNL != null,
              'tax_computation': response.data?.dataTCSch != null,
              'form_cs': response.data?.dataFormCS != null,
              'capital_allowance_schedule': response.data?.dataCASch != null,
              'medical_expense_schedule': response.data?.dataMedExpSch != null,
              'rental_schedule': response.data?.dataRentalSch != null,
              'renovation_schedule': response.data?.dataRRSch != null,
            },
          },
        );

        if (kDebugMode) {
          print(
              '✅ CIT conversion completed successfully (Return Code: ${response.returnCode})');
          print('📊 Generated documents:');
          print(
              '   • Profit & Loss Statement: ${response.data?.dataDtlPNL != null ? "✓" : "✗"}');
          print(
              '   • Tax Computation: ${response.data?.dataTCSch != null ? "✓" : "✗"}');
          print(
              '   • Form C-S: ${response.data?.dataFormCS != null ? "✓" : "✗"}');
          print(
              '   • Capital Allowance Schedule: ${response.data?.dataCASch != null ? "✓" : "✗"}');
          print(
              '   • Medical Expense Schedule: ${response.data?.dataMedExpSch != null ? "✓" : "✗"}');
          print(
              '   • Rental Schedule: ${response.data?.dataRentalSch != null ? "✓" : "✗"}');
          print(
              '   • Renovation & Refurbishment Schedule: ${response.data?.dataRRSch != null ? "✓" : "✗"}');
        }
      } else {
        await _auditService.logFailure(
          operation: operation,
          entityType: 'CORPORATE_TAX',
          entityId: request.clientID,
          error:
              'CIT conversion failed with return code: ${response.returnCode}',
          details: {
            'return_code': response.returnCode,
            'error_info': response.info?.toJson(),
            'field_errors': response.info?.fieldInfoList
                ?.map((f) => {
                      'field': f.field,
                      'message': f.message,
                      'record_id': f.recordID,
                    })
                .toList(),
          },
        );
      }

      return response;
    } on IrasException catch (e) {
      await _auditService.logFailure(
        operation: operation,
        entityType: 'CORPORATE_TAX',
        entityId: request.clientID,
        error: e.message,
        details: {'exception_type': e.runtimeType.toString()},
      );
      rethrow;
    } catch (e) {
      await _auditService.logFailure(
        operation: operation,
        entityType: 'CORPORATE_TAX',
        entityId: request.clientID,
        error: 'Unexpected error: $e',
      );
      throw IrasUnknownException('Failed to convert CIT data: $e');
    }
  }

  /// Extract profit & loss statement from conversion response
  Map<String, dynamic>? extractProfitLossStatement(
      CitConversionResponse response) {
    if (!response.isSuccess) return null;
    return response.data?.dataDtlPNL;
  }

  /// Extract tax computation from conversion response
  Map<String, dynamic>? extractTaxComputation(CitConversionResponse response) {
    if (!response.isSuccess) return null;
    return response.data?.dataTCSch;
  }

  /// Extract Form C-S from conversion response
  Map<String, dynamic>? extractFormCS(CitConversionResponse response) {
    if (!response.isSuccess) return null;
    return response.data?.dataFormCS;
  }

  /// Extract capital allowance schedule from conversion response
  Map<String, dynamic>? extractCapitalAllowanceSchedule(
      CitConversionResponse response) {
    if (!response.isSuccess) return null;
    return response.data?.dataCASch;
  }

  /// Extract medical expense schedule from conversion response
  Map<String, dynamic>? extractMedicalExpenseSchedule(
      CitConversionResponse response) {
    if (!response.isSuccess) return null;
    return response.data?.dataMedExpSch;
  }

  /// Extract rental schedule from conversion response
  Map<String, dynamic>? extractRentalSchedule(CitConversionResponse response) {
    if (!response.isSuccess) return null;
    return response.data?.dataRentalSch;
  }

  /// Extract renovation & refurbishment schedule from conversion response
  Map<String, dynamic>? extractRenovationSchedule(
      CitConversionResponse response) {
    if (!response.isSuccess) return null;
    return response.data?.dataRRSch;
  }

  /// Extract tax payable amount from Form C-S
  double? extractTaxPayable(CitConversionResponse response) {
    final formCS = extractFormCS(response);
    if (formCS != null && formCS.containsKey('netTaxPayable')) {
      return double.tryParse(formCS['netTaxPayable'].toString());
    }
    return null;
  }

  /// Extract chargeable income from tax computation
  double? extractChargeableIncome(CitConversionResponse response) {
    final taxComp = extractTaxComputation(response);
    if (taxComp != null &&
        taxComp.containsKey('chargeableIncomeAftTaxExemptAmt')) {
      return double.tryParse(
          taxComp['chargeableIncomeAftTaxExemptAmt'].toString());
    }
    return null;
  }

  /// Check if company is eligible for Form C-S based on revenue
  bool checkFormCSEligibility(CitData data) {
    try {
      final revenue = double.tryParse(data.totalRevenue) ?? 0;
      // Companies with revenue ≤ S$5 million are eligible for Form C-S
      const eligibilityThreshold = 5000000;
      return revenue <= eligibilityThreshold;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking Form C-S eligibility: $e');
      }
      return false;
    }
  }

  /// Get summary of generated documents
  Map<String, bool> getGeneratedDocumentsSummary(
      CitConversionResponse response) {
    return {
      'profit_loss_statement': response.data?.dataDtlPNL != null,
      'tax_computation': response.data?.dataTCSch != null,
      'form_cs': response.data?.dataFormCS != null,
      'capital_allowance_schedule': response.data?.dataCASch != null,
      'medical_expense_schedule': response.data?.dataMedExpSch != null,
      'rental_schedule': response.data?.dataRentalSch != null,
      'renovation_schedule': response.data?.dataRRSch != null,
    };
  }

  /// Validate CIT conversion request based on YAML specification
  void _validateCitRequest(CitConversionRequest request) {
    final errors = <String, List<String>>{};

    // Validate ClientID
    if (request.clientID.isEmpty) {
      errors['ClientID'] = ['Client ID is required'];
    }

    // Validate year of assessment
    final ya = int.tryParse(request.filingInfo.ya);
    if (ya == null || ya < 2000 || ya > DateTime.now().year + 1) {
      errors['ya'] = [
        'Invalid year of assessment (must be between 2000 and ${DateTime.now().year + 1})'
      ];
    }

    // Validate qualification (must be "true" or "false" as string per YAML spec)
    if (request.declaration.isQualifiedToUseConvFormCS != 'true' &&
        request.declaration.isQualifiedToUseConvFormCS != 'false') {
      errors['isQualifiedToUseConvFormCS'] = [
        'Must be "true" or "false" (as string)'
      ];
    }

    // Validate financial data
    _validateFinancialData(request.data, errors);

    // Validate assets if provided
    _validateAssets(request, errors);

    if (errors.isNotEmpty) {
      throw IrasValidationException('CIT conversion validation failed', errors);
    }
  }

  /// Validate financial data based on YAML specification
  void _validateFinancialData(CitData data, Map<String, List<String>> errors) {
    // Key numeric fields to validate (all fields are strings in YAML spec)
    final keyFields = {
      'totalRevenue': data.totalRevenue,
      'sgIntDisc': data.sgIntDisc,
      'oneTierTaxDividendIncome': data.oneTierTaxDividendIncome,
      'costOfGoodsSold': data.costOfGoodsSold,
      'profitLossBeforeTaxation': data.profitLossBeforeTaxation,
      'tradeReceivables': data.tradeReceivables,
      'inventories': data.inventories,
    };

    for (final entry in keyFields.entries) {
      // Check if it's a valid number (can be negative for some fields like losses)
      if (double.tryParse(entry.value) == null) {
        errors[entry.key] = ['Must be a valid number (as string)'];
      }
    }

    // Validate total revenue for active businesses
    final totalRevenue = double.tryParse(data.totalRevenue) ?? 0;
    if (totalRevenue < 0) {
      errors['totalRevenue'] = ['Total revenue cannot be negative'];
    }

    // Validate year fields
    if (data.firstYAInWhichS14QDeductionClaimed.isNotEmpty) {
      final ya = int.tryParse(data.firstYAInWhichS14QDeductionClaimed);
      if (ya == null || ya < 2000 || ya > DateTime.now().year) {
        errors['firstYAInWhichS14QDeductionClaimed'] = [
          'Invalid year of assessment'
        ];
      }
    }
  }

  /// Validate asset data
  void _validateAssets(
      CitConversionRequest request, Map<String, List<String>> errors) {
    // Validate non-HP computer/communication equipment
    if (request.nonHPCompCommEquipment != null) {
      for (int i = 0; i < request.nonHPCompCommEquipment!.length; i++) {
        final asset = request.nonHPCompCommEquipment![i];
        _validateAsset(asset, 'nonHPCompCommEquipment[$i]', errors);
      }
    }

    // Validate non-HP other PPE
    if (request.nonHpOtherPPE != null) {
      for (int i = 0; i < request.nonHpOtherPPE!.length; i++) {
        final asset = request.nonHpOtherPPE![i];
        _validateAsset(asset, 'nonHpOtherPPE[$i]', errors);
      }
    }

    // Validate low value assets
    if (request.nonHpOtherPPE_LowValueAsset != null) {
      for (int i = 0; i < request.nonHpOtherPPE_LowValueAsset!.length; i++) {
        final asset = request.nonHpOtherPPE_LowValueAsset![i];
        _validateAsset(asset, 'nonHpOtherPPE_LowValueAsset[$i]', errors);
      }
    }

    // Validate HP assets
    if (request.hpOtherPPE != null) {
      for (int i = 0; i < request.hpOtherPPE!.length; i++) {
        final asset = request.hpOtherPPE![i];
        _validateAsset(asset, 'hpOtherPPE[$i]', errors);

        // Additional validation for HP-specific fields
        if (double.tryParse(asset
                .depositOrPrincipalExcludingInterestIncludingDownpaymentEachAsset) ==
            null) {
          errors['${asset.runtimeType}[$i].depositOrPrincipal'] = [
            'Must be a valid number'
          ];
        }
      }
    }
  }

  /// Validate individual asset
  void _validateAsset(
      CitAsset asset, String fieldPrefix, Map<String, List<String>> errors) {
    if (asset.descriptionEachAsset.isEmpty) {
      errors['$fieldPrefix.description'] = ['Asset description is required'];
    }

    if (asset.yaOfPurchaseEachAsset.isEmpty) {
      errors['$fieldPrefix.yaOfPurchase'] = ['Year of purchase is required'];
    } else {
      final ya = int.tryParse(asset.yaOfPurchaseEachAsset);
      if (ya == null || ya < 1900 || ya > DateTime.now().year) {
        errors['$fieldPrefix.yaOfPurchase'] = ['Invalid year of purchase'];
      }
    }

    if (double.tryParse(asset.costEachAsset) == null) {
      errors['$fieldPrefix.cost'] = ['Asset cost must be a valid number'];
    } else {
      final cost = double.parse(asset.costEachAsset);
      if (cost < 0) {
        errors['$fieldPrefix.cost'] = ['Asset cost cannot be negative'];
      }
    }

    // Validate disposal data if provided
    if (asset.yaOfDisposalEachAsset != null &&
        asset.yaOfDisposalEachAsset!.isNotEmpty) {
      final disposalYa = int.tryParse(asset.yaOfDisposalEachAsset!);
      if (disposalYa == null ||
          disposalYa < 1900 ||
          disposalYa > DateTime.now().year) {
        errors['$fieldPrefix.yaOfDisposal'] = ['Invalid year of disposal'];
      }

      if (asset.salesProceedEachAsset != null &&
          asset.salesProceedEachAsset!.isNotEmpty) {
        if (double.tryParse(asset.salesProceedEachAsset!) == null) {
          errors['$fieldPrefix.salesProceed'] = [
            'Sales proceed must be a valid number'
          ];
        }
      }
    }
  }

  /// Create sample CIT request for testing (matches YAML example)
  static CitConversionRequest createSampleRequest() {
    return createSampleCitRequest();
  }
}
