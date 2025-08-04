import '../models/sgqr_models.dart';
import '../utils/crc16_calculator.dart';
import '../utils/emvco_formatter.dart';
import 'sgqr_generator_service.dart';
import 'paynow_service.dart';

/// Multi-payment method configuration
class MultiPaymentConfig {
  final List<PaymentNetwork> supportedNetworks;
  final PaymentNetwork primaryNetwork;
  final Map<PaymentNetwork, Map<String, dynamic>> networkConfigs;

  const MultiPaymentConfig({
    required this.supportedNetworks,
    required this.primaryNetwork,
    this.networkConfigs = const {},
  });

  /// Default Singapore configuration with PayNow primary
  factory MultiPaymentConfig.singaporeDefault() {
    return const MultiPaymentConfig(
      supportedNetworks: [
        PaymentNetwork.payNow,
        PaymentNetwork.nets,
        PaymentNetwork.visa,
        PaymentNetwork.mastercard,
      ],
      primaryNetwork: PaymentNetwork.payNow,
    );
  }

  /// PayNow only configuration
  factory MultiPaymentConfig.payNowOnly() {
    return const MultiPaymentConfig(
      supportedNetworks: [PaymentNetwork.payNow],
      primaryNetwork: PaymentNetwork.payNow,
    );
  }

  /// Cards only configuration
  factory MultiPaymentConfig.cardsOnly() {
    return const MultiPaymentConfig(
      supportedNetworks: [
        PaymentNetwork.visa,
        PaymentNetwork.mastercard,
        PaymentNetwork.americanExpress,
      ],
      primaryNetwork: PaymentNetwork.visa,
    );
  }
}

/// NETS payment data (Singapore's local payment network)
class NETSPaymentData {
  final String merchantId;
  final String terminalId;
  final String? acquirerId;
  final bool supportContactless;
  final bool supportChip;
  final bool supportMagstripe;

  const NETSPaymentData({
    required this.merchantId,
    required this.terminalId,
    this.acquirerId,
    this.supportContactless = true,
    this.supportChip = true,
    this.supportMagstripe = false,
  });
}

/// Card payment data for international cards
class CardPaymentData {
  final String merchantId;
  final String acquirerBIN;
  final List<PaymentNetwork> supportedCards;
  final String? terminalId;

  const CardPaymentData({
    required this.merchantId,
    required this.acquirerBIN,
    required this.supportedCards,
    this.terminalId,
  });
}

/// Multi-payment QR generation result
class MultiPaymentQRResult {
  final bool success;
  final String? sgqrString;
  final Map<PaymentNetwork, String> networkQRs;
  final List<String> errors;
  final Map<String, dynamic>? metadata;

  const MultiPaymentQRResult({
    required this.success,
    this.sgqrString,
    this.networkQRs = const {},
    this.errors = const [],
    this.metadata,
  });

  factory MultiPaymentQRResult.success({
    required String sgqrString,
    required Map<PaymentNetwork, String> networkQRs,
    Map<String, dynamic>? metadata,
  }) {
    return MultiPaymentQRResult(
      success: true,
      sgqrString: sgqrString,
      networkQRs: networkQRs,
      metadata: metadata,
    );
  }

  factory MultiPaymentQRResult.failure({
    required List<String> errors,
  }) {
    return MultiPaymentQRResult(
      success: false,
      errors: errors,
    );
  }
}

/// Multi-payment method service for SGQR
///
/// This service handles the generation of SGQR codes that support multiple
/// payment networks including PayNow, NETS, and international card networks.
class MultiPaymentService {
  // EMVCo merchant account information tags for different networks
  static const Map<PaymentNetwork, String> _networkTags = {
    PaymentNetwork.payNow: '26',
    PaymentNetwork.nets: '27',
    PaymentNetwork.visa: '02',
    PaymentNetwork.mastercard: '04',
    PaymentNetwork.americanExpress: '03',
    PaymentNetwork.discoverCard: '05',
    PaymentNetwork.jcb: '06',
    PaymentNetwork.unionPay: '07',
  };

  /// Generate multi-payment SGQR
  static Future<MultiPaymentQRResult> generateMultiPaymentQR({
    required MultiPaymentConfig config,
    required MerchantInfo merchantInfo,
    PayNowQRData? payNowData,
    NETSPaymentData? netsData,
    CardPaymentData? cardData,
    double? amount,
    String? referenceNumber,
    DateTime? expiryDate,
    CurrencyCode currency = CurrencyCode.sgd,
    SGQRGenerationOptions options = const SGQRGenerationOptions(),
  }) async {
    try {
      final List<String> errors = [];

      // Validate that we have data for supported networks
      if (config.supportedNetworks.contains(PaymentNetwork.payNow) &&
          payNowData == null) {
        errors.add('PayNow data required for PayNow support');
      }

      if (config.supportedNetworks.contains(PaymentNetwork.nets) &&
          netsData == null) {
        errors.add('NETS data required for NETS support');
      }

      final List<PaymentNetwork> cardNetworks = config.supportedNetworks
          .where((network) => _isCardNetwork(network))
          .toList();

      if (cardNetworks.isNotEmpty && cardData == null) {
        errors.add('Card data required for card network support');
      }

      if (errors.isNotEmpty) {
        return Future.value(MultiPaymentQRResult.failure(errors: errors));
      }

      // Generate SGQR string with multiple payment methods
      final String sgqrString = _generateMultiPaymentSGQR(
        config: config,
        merchantInfo: merchantInfo,
        payNowData: payNowData,
        netsData: netsData,
        cardData: cardData,
        amount: amount,
        referenceNumber: referenceNumber,
        expiryDate: expiryDate,
        currency: currency,
      );

      // Generate individual network QRs for reference
      final Map<PaymentNetwork, String> networkQRs = {};

      // Generate PayNow QR if supported
      if (payNowData != null &&
          config.supportedNetworks.contains(PaymentNetwork.payNow)) {
        final PayNowResult payNowResult = PayNowService.createPayNowQR(
          identifier: payNowData.identifier,
          amount: amount,
          message: referenceNumber ?? 'Payment',
        );

        if (payNowResult.success && payNowResult.payNowString != null) {
          networkQRs[PaymentNetwork.payNow] = payNowResult.payNowString!;
        }
      }

      return MultiPaymentQRResult.success(
        sgqrString: sgqrString,
        networkQRs: networkQRs,
        metadata: {
          'supported_networks':
              config.supportedNetworks.map((n) => n.value).toList(),
          'primary_network': config.primaryNetwork.value,
          'amount': amount,
          'currency': currency.value,
          'generated_at': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      return Future.value(MultiPaymentQRResult.failure(
        errors: ['Failed to generate multi-payment QR: $e'],
      ));
    }
  }

  /// Generate SGQR string with multiple payment methods
  static String _generateMultiPaymentSGQR({
    required MultiPaymentConfig config,
    required MerchantInfo merchantInfo,
    PayNowQRData? payNowData,
    NETSPaymentData? netsData,
    CardPaymentData? cardData,
    double? amount,
    String? referenceNumber,
    DateTime? expiryDate,
    CurrencyCode currency = CurrencyCode.sgd,
  }) {
    final buffer = StringBuffer();

    // Payload Format Indicator (Tag 00)
    buffer.write(_formatTLV('00', '01'));

    // Point of Initiation Method (Tag 01)
    final String initiationMethod = amount != null ? '12' : '11';
    buffer.write(_formatTLV('01', initiationMethod));

    // Add merchant account information for each supported network
    for (final PaymentNetwork network in config.supportedNetworks) {
      final String? tag = _networkTags[network];
      if (tag == null) continue;

      String? merchantAccountInfo;

      switch (network) {
        case PaymentNetwork.payNow:
          if (payNowData != null) {
            merchantAccountInfo = _formatPayNowMerchantInfo(payNowData);
          }
          break;
        case PaymentNetwork.nets:
          if (netsData != null) {
            merchantAccountInfo = _formatNETSMerchantInfo(netsData);
          }
          break;
        default:
          if (cardData != null && _isCardNetwork(network)) {
            merchantAccountInfo = _formatCardMerchantInfo(cardData, network);
          }
          break;
      }

      if (merchantAccountInfo != null) {
        buffer.write(_formatTLV(tag, merchantAccountInfo));
      }
    }

    // Merchant Category Code (Tag 52)
    buffer.write(_formatTLV('52', merchantInfo.merchantCategory ?? '0000'));

    // Transaction Currency (Tag 53)
    buffer.write(_formatTLV('53', currency.value));

    // Transaction Amount (Tag 54) - Only for dynamic QR
    if (amount != null) {
      buffer.write(_formatTLV('54', amount.toStringAsFixed(2)));
    }

    // Country Code (Tag 58)
    buffer.write(_formatTLV('58', merchantInfo.countryCode ?? 'SG'));

    // Merchant Name (Tag 59)
    if (merchantInfo.merchantName != null) {
      buffer.write(_formatTLV('59', merchantInfo.merchantName!));
    }

    // Merchant City (Tag 60)
    if (merchantInfo.merchantCity != null) {
      buffer.write(_formatTLV('60', merchantInfo.merchantCity!));
    }

    // Postal Code (Tag 61)
    if (merchantInfo.postalCode != null) {
      buffer.write(_formatTLV('61', merchantInfo.postalCode!));
    }

    // Additional Data Field Template (Tag 62)
    if (referenceNumber != null) {
      final String additionalData = _formatAdditionalData(referenceNumber);
      buffer.write(_formatTLV('62', additionalData));
    }

    // Add CRC placeholder
    buffer.write('6304');

    // Calculate and add CRC16 checksum
    final String dataWithoutCrc = buffer.toString();
    final String crc = CRC16Calculator.calculate(dataWithoutCrc);

    return dataWithoutCrc + crc;
  }

  /// Format PayNow merchant information for multi-payment QR
  static String _formatPayNowMerchantInfo(PayNowQRData payNowData) {
    final buffer = StringBuffer();

    // PayNow GUID (Tag 00)
    buffer.write(_formatTLV('00', 'SG.PAYNOW'));

    // Proxy Type (Tag 01)
    buffer.write(_formatTLV('01', payNowData.identifierType.value));

    // Proxy Value (Tag 02)
    buffer.write(_formatTLV('02', payNowData.identifier));

    // Editable amount indicator (Tag 03)
    buffer.write(_formatTLV('03', payNowData.editable ? '1' : '0'));

    // Expiry date (Tag 04)
    if (payNowData.expiryDate != null) {
      final String expiryStr = _formatDate(payNowData.expiryDate!);
      buffer.write(_formatTLV('04', expiryStr));
    }

    return buffer.toString();
  }

  /// Format NETS merchant information
  static String _formatNETSMerchantInfo(NETSPaymentData netsData) {
    final buffer = StringBuffer();

    // NETS GUID (Tag 00)
    buffer.write(_formatTLV('00', 'SG.NETS'));

    // Merchant ID (Tag 01)
    buffer.write(_formatTLV('01', netsData.merchantId));

    // Terminal ID (Tag 02)
    buffer.write(_formatTLV('02', netsData.terminalId));

    // Acquirer ID (Tag 03)
    if (netsData.acquirerId != null) {
      buffer.write(_formatTLV('03', netsData.acquirerId!));
    }

    return buffer.toString();
  }

  /// Format card network merchant information
  static String _formatCardMerchantInfo(
      CardPaymentData cardData, PaymentNetwork network) {
    final buffer = StringBuffer();

    // Network GUID (Tag 00)
    buffer.write(_formatTLV('00', _getNetworkGUID(network)));

    // Merchant ID (Tag 01)
    buffer.write(_formatTLV('01', cardData.merchantId));

    // Acquirer BIN (Tag 02)
    buffer.write(_formatTLV('02', cardData.acquirerBIN));

    // Terminal ID (Tag 03)
    if (cardData.terminalId != null) {
      buffer.write(_formatTLV('03', cardData.terminalId!));
    }

    return buffer.toString();
  }

  /// Get network GUID for card networks
  static String _getNetworkGUID(PaymentNetwork network) {
    switch (network) {
      case PaymentNetwork.visa:
        return 'com.visa';
      case PaymentNetwork.mastercard:
        return 'com.mastercard';
      case PaymentNetwork.americanExpress:
        return 'com.americanexpress';
      case PaymentNetwork.discoverCard:
        return 'com.discover';
      case PaymentNetwork.jcb:
        return 'com.jcb';
      case PaymentNetwork.unionPay:
        return 'com.unionpay';
      default:
        return 'unknown';
    }
  }

  /// Check if payment network is a card network
  static bool _isCardNetwork(PaymentNetwork network) {
    return [
      PaymentNetwork.visa,
      PaymentNetwork.mastercard,
      PaymentNetwork.americanExpress,
      PaymentNetwork.discoverCard,
      PaymentNetwork.jcb,
      PaymentNetwork.unionPay,
    ].contains(network);
  }

  /// Format TLV (Tag-Length-Value)
  static String _formatTLV(String tag, String value) {
    if (value.isEmpty) return '';
    final String length = value.length.toString().padLeft(2, '0');
    return '$tag$length$value';
  }

  /// Format additional data
  static String _formatAdditionalData(String referenceNumber) {
    return _formatTLV('05', referenceNumber);
  }

  /// Format date as YYYYMMDD
  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Generate PayNow + NETS QR (common Singapore combination)
  static Future<MultiPaymentQRResult> generatePayNowNETSQR({
    required PayNowQRData payNowData,
    required NETSPaymentData netsData,
    required MerchantInfo merchantInfo,
    double? amount,
    String? referenceNumber,
    DateTime? expiryDate,
    CurrencyCode currency = CurrencyCode.sgd,
    SGQRGenerationOptions options = const SGQRGenerationOptions(),
  }) {
    final MultiPaymentConfig config = const MultiPaymentConfig(
      supportedNetworks: [PaymentNetwork.payNow, PaymentNetwork.nets],
      primaryNetwork: PaymentNetwork.payNow,
    );

    return generateMultiPaymentQR(
      config: config,
      merchantInfo: merchantInfo,
      payNowData: payNowData,
      netsData: netsData,
      amount: amount,
      referenceNumber: referenceNumber,
      expiryDate: expiryDate,
      currency: currency,
      options: options,
    );
  }

  /// Generate comprehensive SGQR with all supported payment methods
  static Future<MultiPaymentQRResult> generateComprehensiveSGQR({
    required MerchantInfo merchantInfo,
    PayNowQRData? payNowData,
    NETSPaymentData? netsData,
    CardPaymentData? cardData,
    double? amount,
    String? referenceNumber,
    DateTime? expiryDate,
    CurrencyCode currency = CurrencyCode.sgd,
    SGQRGenerationOptions options = const SGQRGenerationOptions(),
  }) {
    // Determine supported networks based on provided data
    final List<PaymentNetwork> supportedNetworks = [];

    if (payNowData != null) {
      supportedNetworks.add(PaymentNetwork.payNow);
    }

    if (netsData != null) {
      supportedNetworks.add(PaymentNetwork.nets);
    }

    if (cardData != null) {
      supportedNetworks.addAll(cardData.supportedCards);
    }

    if (supportedNetworks.isEmpty) {
      return Future.value(MultiPaymentQRResult.failure(
        errors: ['No payment method data provided'],
      ));
    }

    final MultiPaymentConfig config = MultiPaymentConfig(
      supportedNetworks: supportedNetworks,
      primaryNetwork: supportedNetworks.first,
    );

    return generateMultiPaymentQR(
      config: config,
      merchantInfo: merchantInfo,
      payNowData: payNowData,
      netsData: netsData,
      cardData: cardData,
      amount: amount,
      referenceNumber: referenceNumber,
      expiryDate: expiryDate,
      currency: currency,
      options: options,
    );
  }

  /// Parse multi-payment SGQR to extract supported networks
  static List<PaymentNetwork> getSupportedNetworks(String sgqrString) {
    try {
      // Remove CRC and parse TLV
      final String dataWithoutCrc =
          sgqrString.substring(0, sgqrString.length - 4);
      final List<SGQRDataObject> objects =
          EMVCoFormatter.parseTLV(dataWithoutCrc);

      final List<PaymentNetwork> networks = [];

      for (final SGQRDataObject obj in objects) {
        final PaymentNetwork? network = _getNetworkFromTag(obj.tag);
        if (network != null) {
          networks.add(network);
        }
      }

      return networks;
    } catch (e) {
      return [];
    }
  }

  /// Get payment network from EMVCo tag
  static PaymentNetwork? _getNetworkFromTag(String tag) {
    for (final MapEntry<PaymentNetwork, String> entry in _networkTags.entries) {
      if (entry.value == tag) {
        return entry.key;
      }
    }
    return null;
  }
}
