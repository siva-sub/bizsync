import '../models/sgqr_models.dart';

/// Simple PayNow QR Code Service
/// 
/// This service generates PayNow QR codes using the simple PAYNOW:// URL format
/// instead of the complex EMVCo SGQR format. This follows the actual PayNow
/// specification used by Singapore banking apps.
/// 
/// PayNow URL Format:
/// - Mobile: PAYNOW://0/[MOBILE_NUMBER]?amount=[AMOUNT]&message=[MESSAGE]
/// - UEN: PAYNOW://2/[UEN]?amount=[AMOUNT]&message=[MESSAGE]
/// - NRIC: PAYNOW://3/[NRIC]?amount=[AMOUNT]&message=[MESSAGE]
class PayNowService {
  /// PayNow proxy types
  static const String _mobileProxyType = '0';
  static const String _uenProxyType = '2';
  static const String _nricProxyType = '3';
  
  /// Validate Singapore mobile number (8-digit, starts with 8 or 9)
  static bool isValidSingaporeMobileNumber(String mobile) {
    final String cleanMobile = mobile.replaceAll(RegExp(r'[^\d]'), '');
    
    // Handle country code
    String localMobile;
    if (cleanMobile.startsWith('65')) {
      localMobile = cleanMobile.substring(2);
    } else {
      localMobile = cleanMobile;
    }
    
    // Singapore mobile: 8-digit, starts with 8 or 9
    return RegExp(r'^[89]\d{7}$').hasMatch(localMobile);
  }
  
  /// Format Singapore mobile number (remove country code, keep 8 digits)
  static String formatMobileNumber(String mobile) {
    final String cleanMobile = mobile.replaceAll(RegExp(r'[^\d]'), '');
    
    if (cleanMobile.startsWith('65')) {
      return cleanMobile.substring(2);
    }
    
    return cleanMobile;
  }
  
  /// Validate UEN (Unique Entity Number)
  static bool isValidUEN(String uen) {
    final String cleanUEN = uen.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
    
    // UEN should be 9-12 characters, alphanumeric
    if (cleanUEN.length < 9 || cleanUEN.length > 12) {
      return false;
    }
    
    // UEN must contain at least one letter (not all numbers)
    // Valid UEN formats: 201234567Z, 53012345A, T08GB0001A, etc.
    return RegExp(r'^[A-Z0-9]+$').hasMatch(cleanUEN) && 
           RegExp(r'[A-Z]').hasMatch(cleanUEN);
  }
  
  /// Format UEN
  static String formatUEN(String uen) {
    return uen.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
  }
  
  /// Validate NRIC/FIN
  static bool isValidNRIC(String nric) {
    final String cleanNRIC = nric.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
    
    // NRIC format: Letter + 7 digits + Letter
    return RegExp(r'^[STFG]\d{7}[A-Z]$').hasMatch(cleanNRIC);
  }
  
  /// Format NRIC
  static String formatNRIC(String nric) {
    return nric.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
  }
  
  /// Create PayNow QR for mobile number
  static PayNowResult createMobilePayNowQR({
    required String mobileNumber,
    double? amount,
    String? message,
  }) {
    // Validate mobile number
    if (!isValidSingaporeMobileNumber(mobileNumber)) {
      return PayNowResult.failure('Invalid Singapore mobile number: $mobileNumber');
    }

    final String formattedMobile = formatMobileNumber(mobileNumber);
    
    // Build PayNow string in Singapore bank-compatible format
    // Format: NETS~$PAYNOW$[proxy_type]~[proxy_value]~[amount]~[currency]~[reference]
    final StringBuffer payNowString = StringBuffer();
    payNowString.write('NETS~\$PAYNOW\$');
    payNowString.write(_mobileProxyType);
    payNowString.write('~');
    payNowString.write(formattedMobile);
    
    // Add amount and currency if provided
    if (amount != null && amount > 0) {
      payNowString.write('~');
      payNowString.write(amount.toStringAsFixed(2));
      payNowString.write('~SGD');
      
      // Add reference/message if provided
      if (message != null && message.isNotEmpty) {
        payNowString.write('~');
        payNowString.write(message);
      }
    }
    
    return PayNowResult.success(
      payNowString: payNowString.toString(),
      proxyType: 'mobile',
      proxyValue: formattedMobile,
      amount: amount,
      message: message,
    );
  }
  
  /// Create PayNow QR for UEN
  static PayNowResult createUENPayNowQR({
    required String uen,
    double? amount,
    String? message,
  }) {
    // Validate UEN
    if (!isValidUEN(uen)) {
      return PayNowResult.failure('Invalid UEN format: $uen');
    }

    final String formattedUEN = formatUEN(uen);
    
    // Build PayNow string in Singapore bank-compatible format
    // Format: NETS~$PAYNOW$[proxy_type]~[proxy_value]~[amount]~[currency]~[reference]
    final StringBuffer payNowString = StringBuffer();
    payNowString.write('NETS~\$PAYNOW\$');
    payNowString.write(_uenProxyType);
    payNowString.write('~');
    payNowString.write(formattedUEN);
    
    // Add amount and currency if provided
    if (amount != null && amount > 0) {
      payNowString.write('~');
      payNowString.write(amount.toStringAsFixed(2));
      payNowString.write('~SGD');
      
      // Add reference/message if provided
      if (message != null && message.isNotEmpty) {
        payNowString.write('~');
        payNowString.write(message);
      }
    }
    
    return PayNowResult.success(
      payNowString: payNowString.toString(),
      proxyType: 'uen',
      proxyValue: formattedUEN,
      amount: amount,
      message: message,
    );
  }
  
  /// Create PayNow QR for NRIC
  static PayNowResult createNRICPayNowQR({
    required String nric,
    double? amount,
    String? message,
  }) {
    // Validate NRIC
    if (!isValidNRIC(nric)) {
      return PayNowResult.failure('Invalid NRIC format: $nric');
    }

    final String formattedNRIC = formatNRIC(nric);
    
    // Build PayNow string in Singapore bank-compatible format
    // Format: NETS~$PAYNOW$[proxy_type]~[proxy_value]~[amount]~[currency]~[reference]
    final StringBuffer payNowString = StringBuffer();
    payNowString.write('NETS~\$PAYNOW\$');
    payNowString.write(_nricProxyType);
    payNowString.write('~');
    payNowString.write(formattedNRIC);
    
    // Add amount and currency if provided
    if (amount != null && amount > 0) {
      payNowString.write('~');
      payNowString.write(amount.toStringAsFixed(2));
      payNowString.write('~SGD');
      
      // Add reference/message if provided
      if (message != null && message.isNotEmpty) {
        payNowString.write('~');
        payNowString.write(message);
      }
    }
    
    return PayNowResult.success(
      payNowString: payNowString.toString(),
      proxyType: 'nric',
      proxyValue: formattedNRIC,
      amount: amount,
      message: message,
    );
  }
  
  /// Auto-detect identifier type and generate PayNow QR
  static PayNowResult createPayNowQR({
    required String identifier,
    double? amount,
    String? message,
  }) {
    // Auto-detect identifier type
    if (isValidSingaporeMobileNumber(identifier)) {
      return createMobilePayNowQR(
        mobileNumber: identifier,
        amount: amount,
        message: message,
      );
    } else if (isValidNRIC(identifier)) {
      return createNRICPayNowQR(
        nric: identifier,
        amount: amount,
        message: message,
      );
    } else if (isValidUEN(identifier)) {
      return createUENPayNowQR(
        uen: identifier,
        amount: amount,
        message: message,
      );
    } else {
      return PayNowResult.failure(
        'Invalid identifier: $identifier. Must be a Singapore mobile number, UEN, or NRIC.',
      );
    }
  }
  
  /// Generate invoice payment QR
  static PayNowResult generateInvoicePaymentQR({
    required String identifier,
    required String invoiceNumber,
    required double amount,
  }) {
    final String message = 'Payment for Invoice $invoiceNumber';
    
    return createPayNowQR(
      identifier: identifier,
      amount: amount,
      message: message,
    );
  }
  
  /// Get identifier type for a given identifier
  static PayNowIdentifierType? getIdentifierType(String identifier) {
    if (isValidSingaporeMobileNumber(identifier)) {
      return PayNowIdentifierType.mobile;
    } else if (isValidNRIC(identifier)) {
      return PayNowIdentifierType.nric;
    } else if (isValidUEN(identifier)) {
      return PayNowIdentifierType.uen;
    }
    return null;
  }
  
  /// Validate PayNow identifier
  static bool isValidPayNowIdentifier(String identifier) {
    return getIdentifierType(identifier) != null;
  }
  
  /// Format PayNow identifier based on its type
  static String formatPayNowIdentifier(String identifier) {
    final PayNowIdentifierType? type = getIdentifierType(identifier);
    
    switch (type) {
      case PayNowIdentifierType.mobile:
        return formatMobileNumber(identifier);
      case PayNowIdentifierType.uen:
        return formatUEN(identifier);
      case PayNowIdentifierType.nric:
        return formatNRIC(identifier);
      case null:
        return identifier; // Return as-is if invalid
    }
  }
  
  /// Parse PayNow string to extract information
  static PayNowParseResult? parsePayNowURL(String payNowStr) {
    try {
      // Handle new Singapore bank format: NETS~$PAYNOW$[type]~[value]~[amount]~[currency]~[reference]
      if (payNowStr.startsWith('NETS~\$PAYNOW\$')) {
        final String dataStr = payNowStr.substring('NETS~\$PAYNOW\$'.length);
        final List<String> parts = dataStr.split('~');
        
        if (parts.length < 2) {
          return null;
        }
        
        final String proxyType = parts[0];
        final String proxyValue = parts[1];
        
        double? amount;
        String? message;
        
        if (parts.length >= 3) {
          amount = double.tryParse(parts[2]);
        }
        
        if (parts.length >= 5) {
          message = parts[4]; // Reference is at index 4 (after currency)
        }
        
        String proxyTypeName;
        switch (proxyType) {
          case _mobileProxyType:
            proxyTypeName = 'mobile';
            break;
          case _uenProxyType:
            proxyTypeName = 'uen';
            break;
          case _nricProxyType:
            proxyTypeName = 'nric';
            break;
          default:
            return null;
        }
        
        return PayNowParseResult(
          proxyType: proxyTypeName,
          proxyValue: proxyValue,
          amount: amount,
          message: message,
          originalUrl: payNowStr,
        );
      }
      // Handle old URL format for backward compatibility: PAYNOW://[type]/[value]?amount=X&message=Y
      else if (payNowStr.startsWith('PAYNOW://')) {
        final Uri uri = Uri.parse(payNowStr);
        
        // For PAYNOW://0/91234567, URI parser treats:
        // - scheme: "paynow"  
        // - host: "0"
        // - path: "/91234567"
        // 
        // So we need to combine host and path parts
        final String proxyType = uri.host;
        
        // Get proxy value from path (remove leading /)
        final List<String> pathParts = uri.path.split('/').where((part) => part.isNotEmpty).toList();
        
        if (pathParts.isEmpty) {
          return null;
        }
        
        final String proxyValue = pathParts[0];
        
        // Extract query parameters
        final double? amount = uri.queryParameters['amount'] != null 
            ? double.tryParse(uri.queryParameters['amount']!)
            : null;
        final String? message = uri.queryParameters['message'];
        
        String proxyTypeName;
        switch (proxyType) {
          case _mobileProxyType:
            proxyTypeName = 'mobile';
            break;
          case _uenProxyType:
            proxyTypeName = 'uen';
            break;
          case _nricProxyType:
            proxyTypeName = 'nric';
            break;
          default:
            return null;
        }
        
        return PayNowParseResult(
          proxyType: proxyTypeName,
          proxyValue: proxyValue,
          amount: amount,
          message: message,
          originalUrl: payNowStr,
        );
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Validate PayNow URL format
  static bool isValidPayNowURL(String url) {
    return parsePayNowURL(url) != null;
  }
  
  // Convenience methods for common use cases
  
  /// Personal PayNow QR (mobile number based)
  static PayNowResult createPersonalPayNowQR({
    required String mobileNumber,
  }) {
    return createMobilePayNowQR(
      mobileNumber: mobileNumber,
    );
  }
  
  /// Business PayNow QR (UEN based)
  static PayNowResult createBusinessPayNowQR({
    required String uen,
  }) {
    return createUENPayNowQR(
      uen: uen,
    );
  }
  
  /// Payment request PayNow QR (with specific amount)
  static PayNowResult createPaymentRequestQR({
    required String identifier,
    required double amount,
    String? referenceNumber,
  }) {
    return createPayNowQR(
      identifier: identifier,
      amount: amount,
      message: referenceNumber != null ? 'Payment for $referenceNumber' : null,
    );
  }
}


/// Result of PayNow QR generation
class PayNowResult {
  final bool success;
  final String? payNowString;
  final String? proxyType;
  final String? proxyValue;
  final double? amount;
  final String? message;
  final String? error;
  
  const PayNowResult({
    required this.success,
    this.payNowString,
    this.proxyType,
    this.proxyValue,
    this.amount,
    this.message,
    this.error,
  });
  
  factory PayNowResult.success({
    required String payNowString,
    required String proxyType,
    required String proxyValue,
    double? amount,
    String? message,
  }) {
    return PayNowResult(
      success: true,
      payNowString: payNowString,
      proxyType: proxyType,
      proxyValue: proxyValue,
      amount: amount,
      message: message,
    );
  }
  
  factory PayNowResult.failure(String error) {
    return PayNowResult(
      success: false,
      error: error,
    );
  }
}

/// Result of PayNow URL parsing
class PayNowParseResult {
  final String proxyType;
  final String proxyValue;
  final double? amount;
  final String? message;
  final String originalUrl;
  
  const PayNowParseResult({
    required this.proxyType,
    required this.proxyValue,
    this.amount,
    this.message,
    required this.originalUrl,
  });
}

/// PayNow validation result
class PayNowValidationResult {
  final bool isValid;
  final PayNowIdentifierType? identifierType;
  final String? formattedIdentifier;
  final List<String> errors;

  const PayNowValidationResult({
    required this.isValid,
    this.identifierType,
    this.formattedIdentifier,
    this.errors = const [],
  });

  factory PayNowValidationResult.valid({
    required PayNowIdentifierType identifierType,
    required String formattedIdentifier,
  }) {
    return PayNowValidationResult(
      isValid: true,
      identifierType: identifierType,
      formattedIdentifier: formattedIdentifier,
    );
  }

  factory PayNowValidationResult.invalid({
    required List<String> errors,
  }) {
    return PayNowValidationResult(
      isValid: false,
      errors: errors,
    );
  }
}

/// Enhanced PayNow validation service
class PayNowValidator {
  /// Comprehensive validation of PayNow identifier
  static PayNowValidationResult validateIdentifier(String identifier) {
    final List<String> errors = [];

    if (identifier.trim().isEmpty) {
      errors.add('Identifier cannot be empty');
      return PayNowValidationResult.invalid(errors: errors);
    }

    final PayNowIdentifierType? type = PayNowService.getIdentifierType(identifier);
    
    if (type == null) {
      errors.add('Invalid PayNow identifier format');
      return PayNowValidationResult.invalid(errors: errors);
    }

    final String formatted = PayNowService.formatPayNowIdentifier(identifier);

    // Additional specific validations
    switch (type) {
      case PayNowIdentifierType.mobile:
        if (!PayNowService.isValidSingaporeMobileNumber(identifier)) {
          errors.add('Invalid Singapore mobile number format');
        }
        break;
      case PayNowIdentifierType.uen:
        if (!PayNowService.isValidUEN(identifier)) {
          errors.add('Invalid UEN format');
        }
        break;
      case PayNowIdentifierType.nric:
        if (!PayNowService.isValidNRIC(identifier)) {
          errors.add('Invalid NRIC format');
        }
        break;
    }

    if (errors.isNotEmpty) {
      return PayNowValidationResult.invalid(errors: errors);
    }

    return PayNowValidationResult.valid(
      identifierType: type,
      formattedIdentifier: formatted,
    );
  }

  /// Batch validate multiple identifiers
  static Map<String, PayNowValidationResult> batchValidate(List<String> identifiers) {
    final Map<String, PayNowValidationResult> results = {};
    
    for (final String identifier in identifiers) {
      results[identifier] = validateIdentifier(identifier);
    }
    
    return results;
  }
}