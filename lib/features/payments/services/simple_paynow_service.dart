/// Simple PayNow QR Code Generator
///
/// This service generates PayNow QR codes using the simple PAYNOW:// URL format
/// instead of the complex EMVCo SGQR format. This is the correct approach for
/// basic PayNow transactions in Singapore.
///
/// PayNow URL Format:
/// - Mobile: PAYNOW://0/[MOBILE_NUMBER]?amount=[AMOUNT]&message=[MESSAGE]
/// - UEN: PAYNOW://2/[UEN]?amount=[AMOUNT]&message=[MESSAGE]
/// - NRIC: PAYNOW://3/[NRIC]?amount=[AMOUNT]&message=[MESSAGE]
class SimplePayNowService {
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
    final String cleanUEN =
        uen.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();

    // UEN should be 9-12 characters, alphanumeric
    if (cleanUEN.length < 9 || cleanUEN.length > 12) {
      return false;
    }

    return RegExp(r'^[A-Z0-9]+$').hasMatch(cleanUEN);
  }

  /// Format UEN
  static String formatUEN(String uen) {
    return uen.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
  }

  /// Validate NRIC/FIN
  static bool isValidNRIC(String nric) {
    final String cleanNRIC =
        nric.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();

    // NRIC format: Letter + 7 digits + Letter
    return RegExp(r'^[STFG]\d{7}[A-Z]$').hasMatch(cleanNRIC);
  }

  /// Format NRIC
  static String formatNRIC(String nric) {
    return nric.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
  }

  /// Generate PayNow QR for mobile number
  static PayNowResult generateMobilePayNowQR({
    required String mobileNumber,
    double? amount,
    String? message,
  }) {
    // Validate mobile number
    if (!isValidSingaporeMobileNumber(mobileNumber)) {
      return PayNowResult.failure(
          'Invalid Singapore mobile number: $mobileNumber');
    }

    final String formattedMobile = formatMobileNumber(mobileNumber);

    // Build PayNow URL
    final StringBuffer url = StringBuffer();
    url.write('PAYNOW://');
    url.write(_mobileProxyType);
    url.write('/');
    url.write(formattedMobile);

    // Add query parameters
    final List<String> params = [];
    if (amount != null && amount > 0) {
      params.add('amount=${amount.toStringAsFixed(2)}');
    }
    if (message != null && message.isNotEmpty) {
      params.add('message=${Uri.encodeComponent(message)}');
    }

    if (params.isNotEmpty) {
      url.write('?');
      url.write(params.join('&'));
    }

    return PayNowResult.success(
      payNowString: url.toString(),
      proxyType: 'mobile',
      proxyValue: formattedMobile,
      amount: amount,
      message: message,
    );
  }

  /// Generate PayNow QR for UEN
  static PayNowResult generateUENPayNowQR({
    required String uen,
    double? amount,
    String? message,
  }) {
    // Validate UEN
    if (!isValidUEN(uen)) {
      return PayNowResult.failure('Invalid UEN format: $uen');
    }

    final String formattedUEN = formatUEN(uen);

    // Build PayNow URL
    final StringBuffer url = StringBuffer();
    url.write('PAYNOW://');
    url.write(_uenProxyType);
    url.write('/');
    url.write(formattedUEN);

    // Add query parameters
    final List<String> params = [];
    if (amount != null && amount > 0) {
      params.add('amount=${amount.toStringAsFixed(2)}');
    }
    if (message != null && message.isNotEmpty) {
      params.add('message=${Uri.encodeComponent(message)}');
    }

    if (params.isNotEmpty) {
      url.write('?');
      url.write(params.join('&'));
    }

    return PayNowResult.success(
      payNowString: url.toString(),
      proxyType: 'uen',
      proxyValue: formattedUEN,
      amount: amount,
      message: message,
    );
  }

  /// Generate PayNow QR for NRIC
  static PayNowResult generateNRICPayNowQR({
    required String nric,
    double? amount,
    String? message,
  }) {
    // Validate NRIC
    if (!isValidNRIC(nric)) {
      return PayNowResult.failure('Invalid NRIC format: $nric');
    }

    final String formattedNRIC = formatNRIC(nric);

    // Build PayNow URL
    final StringBuffer url = StringBuffer();
    url.write('PAYNOW://');
    url.write(_nricProxyType);
    url.write('/');
    url.write(formattedNRIC);

    // Add query parameters
    final List<String> params = [];
    if (amount != null && amount > 0) {
      params.add('amount=${amount.toStringAsFixed(2)}');
    }
    if (message != null && message.isNotEmpty) {
      params.add('message=${Uri.encodeComponent(message)}');
    }

    if (params.isNotEmpty) {
      url.write('?');
      url.write(params.join('&'));
    }

    return PayNowResult.success(
      payNowString: url.toString(),
      proxyType: 'nric',
      proxyValue: formattedNRIC,
      amount: amount,
      message: message,
    );
  }

  /// Auto-detect identifier type and generate PayNow QR
  static PayNowResult generatePayNowQR({
    required String identifier,
    double? amount,
    String? message,
  }) {
    // Auto-detect identifier type
    if (isValidSingaporeMobileNumber(identifier)) {
      return generateMobilePayNowQR(
        mobileNumber: identifier,
        amount: amount,
        message: message,
      );
    } else if (isValidUEN(identifier)) {
      return generateUENPayNowQR(
        uen: identifier,
        amount: amount,
        message: message,
      );
    } else if (isValidNRIC(identifier)) {
      return generateNRICPayNowQR(
        nric: identifier,
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

    return generatePayNowQR(
      identifier: identifier,
      amount: amount,
      message: message,
    );
  }

  /// Parse PayNow URL to extract information
  static PayNowParseResult? parsePayNowURL(String url) {
    try {
      if (!url.startsWith('PAYNOW://')) {
        return null;
      }

      final Uri uri = Uri.parse(url);
      final String path = uri.path;

      // Extract proxy type and value from path
      final List<String> pathParts = path.split('/');
      if (pathParts.length < 2) {
        return null;
      }

      final String proxyType = pathParts[0];
      final String proxyValue = pathParts[1];

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
        originalUrl: url,
      );
    } catch (e) {
      return null;
    }
  }

  /// Validate PayNow URL format
  static bool isValidPayNowURL(String url) {
    return parsePayNowURL(url) != null;
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
