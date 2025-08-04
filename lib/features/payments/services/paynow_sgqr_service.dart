import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Simplified SGQR PayNow service for generating QR codes
class PayNowSGQRService {
  static const String _defaultMerchantCategory = '0000';
  static const String _countryCode = 'SG';
  static const String _currency = '702'; // SGD currency code

  /// Generate PayNow QR string
  static String generatePayNowQR({
    required double amount,
    required String merchantName,
    String? uenNumber,
    String? mobileNumber,
    String? reference,
    String? description,
    int expiryMinutes = 60,
  }) {
    final buffer = StringBuffer();

    // Payload Format Indicator (Tag 00)
    buffer.write(_formatTLV('00', '01'));

    // Point of Initiation Method (Tag 01)
    buffer.write(_formatTLV('01', '12')); // Dynamic QR

    // Merchant Account Information (Tag 26) - PayNow
    final payNowData = _buildPayNowData(
      uenNumber: uenNumber,
      mobileNumber: mobileNumber,
      amount: amount,
      reference: reference,
    );
    buffer.write(_formatTLV('26', payNowData));

    // Merchant Category Code (Tag 52)
    buffer.write(_formatTLV('52', _defaultMerchantCategory));

    // Transaction Currency (Tag 53)
    buffer.write(_formatTLV('53', _currency));

    // Transaction Amount (Tag 54)
    buffer.write(_formatTLV('54', amount.toStringAsFixed(2)));

    // Country Code (Tag 58)
    buffer.write(_formatTLV('58', _countryCode));

    // Merchant Name (Tag 59)
    buffer.write(_formatTLV('59', merchantName));

    // Merchant City (Tag 60)
    buffer.write(_formatTLV('60', 'Singapore'));

    // Additional Data Field Template (Tag 62)
    if (reference != null || description != null) {
      final additionalData = _buildAdditionalDataTemplate(
        reference: reference,
        description: description,
      );
      if (additionalData.isNotEmpty) {
        buffer.write(_formatTLV('62', additionalData));
      }
    }

    // Add CRC placeholder
    buffer.write('6304');

    // Calculate and append CRC
    final dataWithoutCrc = buffer.toString();
    final crc = _calculateCRC16(dataWithoutCrc);

    return dataWithoutCrc + crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  /// Build PayNow merchant account information
  static String _buildPayNowData({
    String? uenNumber,
    String? mobileNumber,
    required double amount,
    String? reference,
  }) {
    final buffer = StringBuffer();

    // Globally Unique Identifier (Tag 00)
    buffer.write(_formatTLV('00', 'SG.PAYNOW'));

    // PayNow Proxy Type and Value (Tag 01)
    if (uenNumber != null && uenNumber.isNotEmpty) {
      // UEN format: 2 (UEN) + UEN number
      buffer.write(_formatTLV('01', '2$uenNumber'));
    } else if (mobileNumber != null && mobileNumber.isNotEmpty) {
      // Mobile format: 0 (Mobile) + mobile number without country code
      final cleanMobile = mobileNumber.replaceAll(RegExp(r'[^\d]'), '');
      final mobile =
          cleanMobile.startsWith('65') ? cleanMobile.substring(2) : cleanMobile;
      buffer.write(_formatTLV('01', '0$mobile'));
    } else {
      // Default to a demo UEN
      buffer.write(_formatTLV('01', '2202012345A'));
    }

    // Editable Amount (Tag 02) - 1 means amount is editable
    buffer.write(_formatTLV('02', '1'));

    // Expiry Date (Tag 03) - Optional
    final expiry = DateTime.now().add(Duration(minutes: 60));
    final expiryStr =
        '${expiry.year}${expiry.month.toString().padLeft(2, '0')}${expiry.day.toString().padLeft(2, '0')}';
    buffer.write(_formatTLV('03', expiryStr));

    return buffer.toString();
  }

  /// Build additional data template
  static String _buildAdditionalDataTemplate({
    String? reference,
    String? description,
  }) {
    final buffer = StringBuffer();

    // Reference Label (Tag 01)
    if (reference != null && reference.isNotEmpty) {
      buffer.write(
          _formatTLV('01', reference.substring(0, min(reference.length, 25))));
    }

    // Customer Label (Tag 02) - Optional
    if (description != null && description.isNotEmpty) {
      buffer.write(_formatTLV(
          '02', description.substring(0, min(description.length, 25))));
    }

    // Terminal Label (Tag 03) - Optional
    buffer.write(_formatTLV('03', 'BizSync'));

    return buffer.toString();
  }

  /// Format Tag-Length-Value
  static String _formatTLV(String tag, String value) {
    final length = value.length.toString().padLeft(2, '0');
    return tag + length + value;
  }

  /// Calculate CRC16 checksum
  static int _calculateCRC16(String data) {
    const int polynomial = 0x1021;
    int crc = 0xFFFF;

    for (int i = 0; i < data.length; i++) {
      crc ^= (data.codeUnitAt(i) << 8);

      for (int j = 0; j < 8; j++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ polynomial) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }

    return crc & 0xFFFF;
  }

  /// Validate SGQR string
  static bool isValidSGQR(String sgqrString) {
    if (sgqrString.length < 10) return false;

    try {
      // Extract CRC from the end
      final dataWithoutCrc = sgqrString.substring(0, sgqrString.length - 4);
      final providedCrc =
          int.parse(sgqrString.substring(sgqrString.length - 4), radix: 16);

      // Calculate expected CRC
      final calculatedCrc = _calculateCRC16(dataWithoutCrc + '6304');

      return providedCrc == calculatedCrc;
    } catch (e) {
      return false;
    }
  }

  /// Generate QR for invoice payment
  static String generateInvoicePaymentQR({
    required String invoiceNumber,
    required double amount,
    required String merchantName,
    String? merchantUEN,
    String? merchantMobile,
  }) {
    return generatePayNowQR(
      amount: amount,
      merchantName: merchantName,
      uenNumber: merchantUEN,
      mobileNumber: merchantMobile,
      reference: invoiceNumber,
      description: 'Payment for Invoice $invoiceNumber',
    );
  }

  /// Parse SGQR metadata
  static Map<String, dynamic>? parseSGQRMetadata(String sgqrString) {
    if (!isValidSGQR(sgqrString)) return null;

    try {
      final metadata = <String, dynamic>{};
      metadata['is_valid'] = true;
      metadata['currency'] = 'SGD';
      metadata['payment_method'] = 'PayNow';

      // Extract amount if present
      final amountMatch = RegExp(r'54\d{2}(\d+\.\d{2})').firstMatch(sgqrString);
      if (amountMatch != null) {
        metadata['amount'] =
            double.tryParse(amountMatch.group(1) ?? '0') ?? 0.0;
      }

      // Extract merchant name
      final merchantMatch =
          RegExp(r'59\d{2}([^6]{1,25})').firstMatch(sgqrString);
      if (merchantMatch != null) {
        metadata['merchant_name'] = merchantMatch.group(1);
      }

      return metadata;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to parse SGQR metadata: $e');
      }
      return null;
    }
  }
}

/// Result class for SGQR generation
class SGQRResult {
  final bool isSuccess;
  final String? qrString;
  final String? errorMessage;
  final Map<String, dynamic>? metadata;

  const SGQRResult({
    required this.isSuccess,
    this.qrString,
    this.errorMessage,
    this.metadata,
  });

  factory SGQRResult.success({
    required String qrString,
    Map<String, dynamic>? metadata,
  }) {
    return SGQRResult(
      isSuccess: true,
      qrString: qrString,
      metadata: metadata,
    );
  }

  factory SGQRResult.failure(String errorMessage) {
    return SGQRResult(
      isSuccess: false,
      errorMessage: errorMessage,
    );
  }
}

/// Simplified PayNow service interface
class PayNowService {
  /// Generate PayNow QR code for payment
  static Future<SGQRResult> generateSGQR({
    required double amount,
    required String currency,
    required String merchantName,
    String? merchantUEN,
    String? merchantMobile,
    String? reference,
    String? description,
    int expiryMinutes = 60,
  }) async {
    try {
      if (amount <= 0) {
        return SGQRResult.failure('Amount must be greater than 0');
      }

      if (currency != 'SGD') {
        return SGQRResult.failure('Only SGD currency is supported');
      }

      final qrString = PayNowSGQRService.generatePayNowQR(
        amount: amount,
        merchantName: merchantName,
        uenNumber: merchantUEN,
        mobileNumber: merchantMobile,
        reference: reference,
        description: description,
        expiryMinutes: expiryMinutes,
      );

      final metadata = {
        'amount': amount,
        'currency': currency,
        'merchant_name': merchantName,
        'reference': reference,
        'description': description,
        'expiry_minutes': expiryMinutes,
        'generated_at': DateTime.now().toIso8601String(),
      };

      return SGQRResult.success(
        qrString: qrString,
        metadata: metadata,
      );
    } catch (e) {
      return SGQRResult.failure('Failed to generate SGQR: $e');
    }
  }
}
