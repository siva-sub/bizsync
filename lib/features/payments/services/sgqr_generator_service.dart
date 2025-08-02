import 'package:qr_flutter/qr_flutter.dart';
import 'package:qr/qr.dart';
import 'package:flutter/material.dart';

import '../models/sgqr_models.dart';
import '../utils/crc16_calculator.dart';
import '../utils/emvco_formatter.dart';

/// Result of SGQR generation
class SGQRGenerationResult {
  final bool success;
  final String? sgqrString;
  final String? qrImageData;
  final List<String> errors;
  final Map<String, dynamic>? metadata;

  const SGQRGenerationResult({
    required this.success,
    this.sgqrString,
    this.qrImageData,
    this.errors = const [],
    this.metadata,
  });

  factory SGQRGenerationResult.success({
    required String sgqrString,
    String? qrImageData,
    Map<String, dynamic>? metadata,
  }) {
    return SGQRGenerationResult(
      success: true,
      sgqrString: sgqrString,
      qrImageData: qrImageData,
      metadata: metadata,
    );
  }

  factory SGQRGenerationResult.failure({
    required List<String> errors,
  }) {
    return SGQRGenerationResult(
      success: false,
      errors: errors,
    );
  }
}

/// SGQR generation options
class SGQRGenerationOptions {
  final bool includeQRImage;
  final int qrImageSize;
  final Color qrColor;
  final Color backgroundColor;
  final bool embedLogo;
  final String? logoPath;
  final int errorCorrectionLevel;

  const SGQRGenerationOptions({
    this.includeQRImage = true,
    this.qrImageSize = 512,
    this.qrColor = Colors.black,
    this.backgroundColor = Colors.white,
    this.embedLogo = false,
    this.logoPath,
    this.errorCorrectionLevel = QrErrorCorrectLevel.M,
  });
}

/// Main SGQR Generator Service
/// 
/// This service handles the generation of SGQR/PayNow QR codes according to
/// Singapore's SGQR specification and EMVCo standards.
class SGQRGeneratorService {
  // Default merchant category code (0000 = General use)
  static const String _defaultMerchantCategory = '0000';

  /// Generate SGQR string and optionally QR image
  static Future<SGQRGenerationResult> generateSGQR({
    required SGQRPaymentRequest request,
    SGQRGenerationOptions options = const SGQRGenerationOptions(),
  }) async {
    try {
      // Validate the request
      final List<String> validationErrors = request.validate();
      if (validationErrors.isNotEmpty) {
        return SGQRGenerationResult.failure(errors: validationErrors);
      }

      // Generate SGQR string
      final String sgqrString = _generateSGQRString(request);
      
      // Validate generated SGQR
      if (!CRC16Calculator.validate(sgqrString)) {
        return SGQRGenerationResult.failure(
          errors: ['Generated SGQR has invalid checksum'],
        );
      }

      String? qrImageData;
      if (options.includeQRImage) {
        // Generate QR image data would go here
        // For now, we'll return the string data
        qrImageData = sgqrString;
      }

      return SGQRGenerationResult.success(
        sgqrString: sgqrString,
        qrImageData: qrImageData,
        metadata: {
          'type': request.isDynamic ? 'dynamic' : 'static',
          'paymentMethod': 'PayNow',
          'currency': request.config.currency.value,
          'amount': request.amount,
          'generated_at': DateTime.now().toIso8601String(),
        },
      );

    } catch (e) {
      return SGQRGenerationResult.failure(
        errors: ['Failed to generate SGQR: $e'],
      );
    }
  }

  /// Generate SGQR string only (without QR image)
  static String generateSGQRString(SGQRPaymentRequest request) {
    final List<String> validationErrors = request.validate();
    if (validationErrors.isNotEmpty) {
      throw ArgumentError('Invalid request: ${validationErrors.join(', ')}');
    }

    return _generateSGQRString(request);
  }

  /// Internal method to generate SGQR string
  static String _generateSGQRString(SGQRPaymentRequest request) {
    final buffer = StringBuffer();

    // Payload Format Indicator (Tag 00)
    buffer.write(EMVCoFormatter.formatTLV(
      '00',
      request.config.payloadFormat.value,
    ));

    // Point of Initiation Method (Tag 01)
    buffer.write(EMVCoFormatter.formatTLV(
      '01',
      request.config.initiationMethod.value,
    ));

    // Merchant Account Information (Tag 26) - PayNow
    if (request.payNowData != null) {
      buffer.write(EMVCoFormatter.formatPayNowMerchantInfo(request.payNowData!));
    }

    // Merchant Category Code (Tag 52)
    buffer.write(EMVCoFormatter.formatTLV(
      '52',
      request.config.merchantInfo.merchantCategory ?? _defaultMerchantCategory,
    ));

    // Transaction Currency (Tag 53)
    buffer.write(EMVCoFormatter.formatTLV(
      '53',
      request.config.currency.value,
    ));

    // Transaction Amount (Tag 54) - Only for dynamic QR
    if (request.amount != null) {
      final String amountStr = request.amount!.toStringAsFixed(2);
      buffer.write(EMVCoFormatter.formatTLV('54', amountStr));
    }

    // Tip or Convenience Indicator (Tag 55)
    if (request.config.tipOrConvenienceIndicator != null) {
      buffer.write(EMVCoFormatter.formatTLV(
        '55',
        request.config.tipOrConvenienceIndicator!,
      ));
    }

    // Value of Convenience Fee Fixed (Tag 56)
    if (request.config.valueOfConvenienceFeeFixed != null) {
      buffer.write(EMVCoFormatter.formatTLV(
        '56',
        request.config.valueOfConvenienceFeeFixed!,
      ));
    }

    // Value of Convenience Fee Percentage (Tag 57)
    if (request.config.valueOfConvenienceFeePercentage != null) {
      buffer.write(EMVCoFormatter.formatTLV(
        '57',
        request.config.valueOfConvenienceFeePercentage!,
      ));
    }

    // Country Code (Tag 58)
    buffer.write(EMVCoFormatter.formatTLV(
      '58',
      request.config.merchantInfo.countryCode ?? 'SG',
    ));

    // Merchant Name (Tag 59)
    if (request.config.merchantInfo.merchantName != null) {
      buffer.write(EMVCoFormatter.formatTLV(
        '59',
        request.config.merchantInfo.merchantName!,
      ));
    }

    // Merchant City (Tag 60)
    if (request.config.merchantInfo.merchantCity != null) {
      buffer.write(EMVCoFormatter.formatTLV(
        '60',
        request.config.merchantInfo.merchantCity!,
      ));
    }

    // Postal Code (Tag 61)
    if (request.config.merchantInfo.postalCode != null) {
      buffer.write(EMVCoFormatter.formatTLV(
        '61',
        request.config.merchantInfo.postalCode!,
      ));
    }

    // Additional Data Field Template (Tag 62)
    if (request.referenceNumber != null || request.additionalInfo != null) {
      final String additionalData = EMVCoFormatter.formatAdditionalDataTemplate(
        referenceLabel: request.referenceNumber,
        // Add other additional data fields as needed
      );
      if (additionalData.isNotEmpty) {
        buffer.write(additionalData);
      }
    }

    // Add CRC (Tag 63) - placeholder that will be replaced
    buffer.write('6304');

    // Calculate and add CRC16 checksum
    final String dataWithoutCrc = buffer.toString();
    final String crc = CRC16Calculator.calculate(dataWithoutCrc);
    
    return dataWithoutCrc + crc;
  }

  /// Parse SGQR string back to payment request
  static SGQRPaymentRequest? parseSGQRString(String sgqrString) {
    try {
      // Validate CRC first
      if (!CRC16Calculator.validate(sgqrString)) {
        return null;
      }

      // Remove CRC for parsing
      final String dataWithoutCrc = CRC16Calculator.removeChecksum(sgqrString);
      
      // Parse TLV data objects
      final List<SGQRDataObject> objects = EMVCoFormatter.parseTLV(dataWithoutCrc);

      // Extract required fields
      PayloadFormatIndicator? payloadFormat;
      PointOfInitiationMethod? initiationMethod;
      PayNowQRData? payNowData;
      CurrencyCode? currency;
      double? amount;
      MerchantInfo? merchantInfo;

      for (final SGQRDataObject obj in objects) {
        switch (obj.tag) {
          case '00': // Payload Format Indicator
            payloadFormat = PayloadFormatIndicator.values
                .where((e) => e.value == obj.value)
                .firstOrNull;
            break;
          case '01': // Point of Initiation Method
            initiationMethod = PointOfInitiationMethod.values
                .where((e) => e.value == obj.value)
                .firstOrNull;
            break;
          case '26': // Merchant Account Information (PayNow)
            payNowData = EMVCoFormatter.extractPayNowData(obj.value);
            break;
          case '53': // Transaction Currency
            currency = CurrencyCode.values
                .where((e) => e.value == obj.value)
                .firstOrNull;
            break;
          case '54': // Transaction Amount
            amount = double.tryParse(obj.value);
            break;
          case '59': // Merchant Name
            merchantInfo = MerchantInfo(merchantName: obj.value);
            break;
        }
      }

      if (payloadFormat == null || initiationMethod == null || payNowData == null) {
        return null;
      }

      final SGQRConfig config = SGQRConfig(
        payloadFormat: payloadFormat,
        initiationMethod: initiationMethod,
        currency: currency ?? CurrencyCode.sgd,
        merchantInfo: merchantInfo ?? const MerchantInfo(),
      );

      return SGQRPaymentRequest(
        config: config,
        payNowData: payNowData,
        amount: amount,
      );

    } catch (e) {
      return null;
    }
  }

  /// Generate multiple SGQR codes in batch
  static Future<List<SGQRGenerationResult>> batchGenerate({
    required List<SGQRPaymentRequest> requests,
    SGQRGenerationOptions options = const SGQRGenerationOptions(),
  }) async {
    final List<SGQRGenerationResult> results = [];

    for (final SGQRPaymentRequest request in requests) {
      final SGQRGenerationResult result = await generateSGQR(
        request: request,
        options: options,
      );
      results.add(result);
    }

    return results;
  }

  /// Validate SGQR string structure and content
  static List<String> validateSGQRString(String sgqrString) {
    final List<String> errors = [];

    // Check minimum length
    if (sgqrString.length < 10) {
      errors.add('SGQR string too short');
      return errors;
    }

    // Validate CRC
    if (!CRC16Calculator.validate(sgqrString)) {
      errors.add('Invalid CRC checksum');
    }

    try {
      // Parse and validate structure
      final String dataWithoutCrc = CRC16Calculator.removeChecksum(sgqrString);
      final List<SGQRDataObject> objects = EMVCoFormatter.parseTLV(dataWithoutCrc);
      
      // Validate EMVCo structure
      final List<String> structureErrors = EMVCoFormatter.validateDataObjects(objects);
      errors.addAll(structureErrors);

      // Check for required fields
      final Set<String> requiredTags = {'00', '01', '26', '52', '53', '58', '59'};
      final Set<String> presentTags = objects.map((obj) => obj.tag).toSet();
      
      for (final String requiredTag in requiredTags) {
        if (!presentTags.contains(requiredTag)) {
          errors.add('Missing required tag: $requiredTag');
        }
      }

    } catch (e) {
      errors.add('Failed to parse SGQR structure: $e');
    }

    return errors;
  }

  /// Get SGQR metadata from string
  static Map<String, dynamic>? getSGQRMetadata(String sgqrString) {
    try {
      final SGQRPaymentRequest? request = parseSGQRString(sgqrString);
      if (request == null) return null;

      return {
        'is_dynamic': request.isDynamic,
        'is_static': request.isStatic,
        'payment_method': 'PayNow',
        'currency': request.config.currency.value,
        'amount': request.amount,
        'merchant_name': request.config.merchantInfo.merchantName,
        'paynow_identifier_type': request.payNowData?.identifierType.value,
        'paynow_identifier': request.payNowData?.identifier,
        'editable_amount': request.payNowData?.editable,
      };
    } catch (e) {
      return null;
    }
  }
}

/// Extension methods for convenient SGQR generation
extension SGQRPaymentRequestExtension on SGQRPaymentRequest {
  /// Generate SGQR string for this request
  String toSGQRString() {
    return SGQRGeneratorService.generateSGQRString(this);
  }

  /// Generate SGQR with options
  Future<SGQRGenerationResult> generateSGQR({
    SGQRGenerationOptions options = const SGQRGenerationOptions(),
  }) {
    return SGQRGeneratorService.generateSGQR(
      request: this,
      options: options,
    );
  }
}