import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/iras/corporate_tax_models.dart';
import 'iras_client.dart';
import 'iras_config.dart';
import 'iras_auth_service.dart';
import 'iras_exceptions.dart';
import 'iras_audit_service.dart';

/// IRAS Corporate Income Tax (CIT) services
class IrasCorporateTaxService {
  final IrasApiClient _client;
  final IrasAuthService _authService;
  final IrasAuditService _auditService;
  static IrasCorporateTaxService? _instance;

  IrasCorporateTaxService._({
    IrasApiClient? client,
    IrasAuthService? authService,
    IrasAuditService? auditService,
  })  : _client = client ?? IrasApiClient.instance,
        _authService = authService ?? IrasAuthService.instance,
        _auditService = auditService ?? IrasAuditService.instance;

  /// Singleton instance
  static IrasCorporateTaxService get instance {
    _instance ??= IrasCorporateTaxService._();
    return _instance!;
  }

  /// Convert accounting data to Form C-S using CIT Conversion API
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
        entityId: request.clientId,
        details: {
          'year_of_assessment': request.filingInfo.ya,
          'total_revenue': request.data.totalRevenue,
          'qualified_for_form_cs':
              request.declaration.isQualifiedToUseConvFormCS,
        },
      );

      // Execute request (CIT API doesn't require authentication in some cases)
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
          entityId: request.clientId,
          details: {
            'conversion_successful': true,
            'year_of_assessment': request.filingInfo.ya,
            'tax_computation_generated': response.data?.taxComputation != null,
            'form_cs_generated': response.data?.formCS != null,
          },
        );

        if (kDebugMode) {
          print('✅ CIT conversion completed successfully');
          print('💰 Tax payable: \$${response.data?.formCS.taxPayable ?? 0}');
        }
      } else {
        await _auditService.logFailure(
          operation: operation,
          entityType: 'CORPORATE_TAX',
          entityId: request.clientId,
          error:
              'CIT conversion failed with return code: ${response.returnCode}',
          details: response.info?.toJson(),
        );
      }

      return response;
    } on IrasException catch (e) {
      await _auditService.logFailure(
        operation: operation,
        entityType: 'CORPORATE_TAX',
        entityId: request.clientId,
        error: e.message,
        details: {'exception_type': e.runtimeType.toString()},
      );
      rethrow;
    } catch (e) {
      await _auditService.logFailure(
        operation: operation,
        entityType: 'CORPORATE_TAX',
        entityId: request.clientId,
        error: 'Unexpected error: $e',
      );
      throw IrasUnknownException('Failed to convert CIT data: $e');
    }
  }

  /// Generate tax computation from financial data
  Future<CitTaxComputation> generateTaxComputation(
    CitFinancialData financialData, {
    required String yearOfAssessment,
    String? clientId,
  }) async {
    final request = CitConversionRequest(
      declaration: const CitDeclaration(isQualifiedToUseConvFormCS: 'Y'),
      clientId: clientId ?? 'default_client',
      filingInfo: CitFilingInfo(ya: yearOfAssessment),
      data: financialData,
    );

    final response = await convertToFormCS(request);

    if (response.isSuccess && response.data?.taxComputation != null) {
      return response.data!.taxComputation;
    } else {
      throw IrasApiException(
        'Failed to generate tax computation',
        response.returnCode,
        response.info?.toJson(),
      );
    }
  }

  /// Generate profit & loss statement
  Future<CitProfitLossStatement> generateProfitLossStatement(
    CitFinancialData financialData, {
    required String yearOfAssessment,
    String? clientId,
  }) async {
    final request = CitConversionRequest(
      declaration: const CitDeclaration(isQualifiedToUseConvFormCS: 'Y'),
      clientId: clientId ?? 'default_client',
      filingInfo: CitFilingInfo(ya: yearOfAssessment),
      data: financialData,
    );

    final response = await convertToFormCS(request);

    if (response.isSuccess && response.data?.profitLossStatement != null) {
      return response.data!.profitLossStatement;
    } else {
      throw IrasApiException(
        'Failed to generate profit & loss statement',
        response.returnCode,
        response.info?.toJson(),
      );
    }
  }

  /// Generate draft Form C-S
  Future<CitFormCS> generateFormCS(
    CitFinancialData financialData, {
    required String yearOfAssessment,
    String? clientId,
  }) async {
    final request = CitConversionRequest(
      declaration: const CitDeclaration(isQualifiedToUseConvFormCS: 'Y'),
      clientId: clientId ?? 'default_client',
      filingInfo: CitFilingInfo(ya: yearOfAssessment),
      data: financialData,
    );

    final response = await convertToFormCS(request);

    if (response.isSuccess && response.data?.formCS != null) {
      return response.data!.formCS;
    } else {
      throw IrasApiException(
        'Failed to generate Form C-S',
        response.returnCode,
        response.info?.toJson(),
      );
    }
  }

  /// Check eligibility for Form C-S
  Future<bool> checkFormCSEligibility(CitFinancialData financialData) async {
    try {
      // Parse revenue to check against S$5 million threshold
      final revenue = double.tryParse(financialData.totalRevenue) ?? 0;

      // Companies with revenue ≤ S$5 million are eligible for Form C-S
      const eligibilityThreshold = 5000000; // S$5 million

      return revenue <= eligibilityThreshold;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking Form C-S eligibility: $e');
      }
      return false;
    }
  }

  /// Calculate estimated corporate tax
  Future<double> calculateEstimatedTax(
    CitFinancialData financialData, {
    required String yearOfAssessment,
  }) async {
    try {
      final taxComputation = await generateTaxComputation(
        financialData,
        yearOfAssessment: yearOfAssessment,
      );
      return taxComputation.corporateIncomeTax;
    } catch (e) {
      if (kDebugMode) {
        print('Error calculating estimated tax: $e');
      }
      return 0.0;
    }
  }

  /// Validate CIT conversion request
  void _validateCitRequest(CitConversionRequest request) {
    final errors = <String, List<String>>{};

    // Validate year of assessment
    final ya = int.tryParse(request.filingInfo.ya);
    if (ya == null || ya < 2000 || ya > DateTime.now().year + 1) {
      errors['ya'] = ['Invalid year of assessment'];
    }

    // Validate client ID
    if (request.clientId.isEmpty) {
      errors['clientId'] = ['Client ID is required'];
    }

    // Validate qualification
    if (request.declaration.isQualifiedToUseConvFormCS != 'Y' &&
        request.declaration.isQualifiedToUseConvFormCS != 'N') {
      errors['isQualifiedToUseConvFormCS'] = ['Must be Y or N'];
    }

    // Validate financial data
    _validateFinancialData(request.data, errors);

    if (errors.isNotEmpty) {
      throw IrasValidationException('CIT conversion validation failed', errors);
    }
  }

  /// Validate financial data
  void _validateFinancialData(
      CitFinancialData data, Map<String, List<String>> errors) {
    // Validate numeric fields
    final numericFields = {
      'totalRevenue': data.totalRevenue,
      'sgIntDisc': data.sgIntDisc,
      'oneTierTaxDividendIncome': data.oneTierTaxDividendIncome,
      'costOfGoodsSold': data.costOfGoodsSold,
      'directorsFees': data.directorsFees,
      'cpfContribution': data.cpfContribution,
      'salariesWages': data.salariesWages,
    };

    for (final entry in numericFields.entries) {
      if (double.tryParse(entry.value) == null) {
        errors[entry.key] = ['Must be a valid number'];
      } else {
        final value = double.parse(entry.value);
        if (value < 0) {
          errors[entry.key] = ['Cannot be negative'];
        }
      }
    }

    // Validate total revenue is not zero for active businesses
    final totalRevenue = double.tryParse(data.totalRevenue) ?? 0;
    if (totalRevenue == 0) {
      errors['totalRevenue'] = [
        'Total revenue should not be zero for active businesses'
      ];
    }
  }

  /// Create sample CIT request for testing
  static CitConversionRequest createSampleCitRequest() {
    return CitConversionRequest(
      declaration: const CitDeclaration(
        isQualifiedToUseConvFormCS: 'Y',
      ),
      clientId: 'sample_client_123',
      filingInfo: CitFilingInfo(
        ya: DateTime.now().year.toString(),
      ),
      data: const CitFinancialData(
        totalRevenue: '1000000.00',
        sgIntDisc: '5000.00',
        oneTierTaxDividendIncome: '0.00',
        c1GrossRent: '0.00',
        sgOtherI: '2000.00',
        otherNonTaxableIncome: '0.00',
        totalOtherIncome: '7000.00',
        costOfGoodsSold: '400000.00',
        bankCharges: '2000.00',
        commissionOther: '5000.00',
        depreciationExpense: '20000.00',
        directorsFees: '60000.00',
        directorsRemunerationExcludingDirectorsFees: '120000.00',
        donations: '5000.00',
        cpfContribution: '25000.00',
        employeeBenefits: '15000.00',
        foreignExchangeLoss: '1000.00',
        insurance: '8000.00',
        interestExpense: '12000.00',
        legalProfessionalFees: '15000.00',
        maintenanceRepairs: '10000.00',
        marketingAdvertising: '20000.00',
        officePremisesExpense: '30000.00',
        otherOperatingExpenses: '25000.00',
        rentExpense: '60000.00',
        salariesWages: '200000.00',
        travellingEntertainment: '8000.00',
        utilitiesTelephone: '12000.00',
        capitalAllowanceClaimed: '15000.00',
        capitalAllowanceClawback: '0.00',
        badDebtProvision: '2000.00',
        goodwillWriteOff: '0.00',
        otherAdjustments: '0.00',
      ),
    );
  }
}
