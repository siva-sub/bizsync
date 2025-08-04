import 'package:json_annotation/json_annotation.dart';

part 'sgqr_models.g.dart';

/// SGQR Payload Format Indicator
enum PayloadFormatIndicator {
  cpv01('01'),
  cpv02('02');

  const PayloadFormatIndicator(this.value);
  final String value;
}

/// Point of Initiation Method
enum PointOfInitiationMethod {
  static('11'),
  dynamic('12');

  const PointOfInitiationMethod(this.value);
  final String value;
}

/// Currency codes supported in Singapore
enum CurrencyCode {
  sgd('702'), // Singapore Dollar
  usd('840'), // US Dollar
  eur('978'), // Euro
  jpy('392'), // Japanese Yen
  gbp('826'), // British Pound
  aud('036'), // Australian Dollar
  cad('124'), // Canadian Dollar
  hkd('344'), // Hong Kong Dollar
  myr('458'), // Malaysian Ringgit
  thb('764'), // Thai Baht
  cny('156'), // Chinese Yuan
  inr('356'); // Indian Rupee

  const CurrencyCode(this.value);
  final String value;
}

/// PayNow identifier types
enum PayNowIdentifierType {
  mobile('0'),
  uen('2'),
  nric('3');

  const PayNowIdentifierType(this.value);
  final String value;
}

/// Payment networks supported in SGQR
enum PaymentNetwork {
  payNow('PayNow'),
  nets('NETS'),
  visa('Visa'),
  mastercard('Mastercard'),
  americanExpress('AMEX'),
  discoverCard('Discover'),
  jcb('JCB'),
  unionPay('UnionPay');

  const PaymentNetwork(this.value);
  final String value;
}

/// SGQR Data Object
@JsonSerializable()
class SGQRDataObject {
  final String tag;
  final String length;
  final String value;

  const SGQRDataObject({
    required this.tag,
    required this.length,
    required this.value,
  });

  factory SGQRDataObject.fromJson(Map<String, dynamic> json) =>
      _$SGQRDataObjectFromJson(json);

  Map<String, dynamic> toJson() => _$SGQRDataObjectToJson(this);

  /// Creates a properly formatted TLV (Tag-Length-Value) string
  String toTLV() {
    final lengthStr = value.length.toString().padLeft(2, '0');
    return '$tag$lengthStr$value';
  }

  @override
  String toString() => toTLV();
}

/// PayNow QR Data
@JsonSerializable()
class PayNowQRData {
  final PayNowIdentifierType identifierType;
  final String identifier;
  final bool editable;
  final DateTime? expiryDate;
  final String? referenceId;

  const PayNowQRData({
    required this.identifierType,
    required this.identifier,
    this.editable = true,
    this.expiryDate,
    this.referenceId,
  });

  factory PayNowQRData.fromJson(Map<String, dynamic> json) =>
      _$PayNowQRDataFromJson(json);

  Map<String, dynamic> toJson() => _$PayNowQRDataToJson(this);

  /// Create PayNow QR data for mobile number
  factory PayNowQRData.mobile({
    required String mobileNumber,
    bool editable = true,
    DateTime? expiryDate,
    String? referenceId,
  }) {
    // Remove country code if present and format
    String cleanMobile = mobileNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanMobile.startsWith('65')) {
      cleanMobile = cleanMobile.substring(2);
    }

    return PayNowQRData(
      identifierType: PayNowIdentifierType.mobile,
      identifier: cleanMobile,
      editable: editable,
      expiryDate: expiryDate,
      referenceId: referenceId,
    );
  }

  /// Create PayNow QR data for UEN
  factory PayNowQRData.uen({
    required String uen,
    bool editable = true,
    DateTime? expiryDate,
    String? referenceId,
  }) {
    return PayNowQRData(
      identifierType: PayNowIdentifierType.uen,
      identifier: uen.toUpperCase(),
      editable: editable,
      expiryDate: expiryDate,
      referenceId: referenceId,
    );
  }

  /// Create PayNow QR data for NRIC
  factory PayNowQRData.nric({
    required String nric,
    bool editable = true,
    DateTime? expiryDate,
    String? referenceId,
  }) {
    return PayNowQRData(
      identifierType: PayNowIdentifierType.nric,
      identifier: nric.toUpperCase(),
      editable: editable,
      expiryDate: expiryDate,
      referenceId: referenceId,
    );
  }
}

/// Merchant Account Information
@JsonSerializable()
class MerchantInfo {
  final String? merchantId;
  final String? merchantName;
  final String? merchantCity;
  final String? merchantCategory;
  final String? postalCode;
  final String? countryCode;
  final Map<String, dynamic>? additionalData;

  const MerchantInfo({
    this.merchantId,
    this.merchantName,
    this.merchantCity,
    this.merchantCategory = '0000', // Default category
    this.postalCode,
    this.countryCode = 'SG',
    this.additionalData,
  });

  factory MerchantInfo.fromJson(Map<String, dynamic> json) =>
      _$MerchantInfoFromJson(json);

  Map<String, dynamic> toJson() => _$MerchantInfoToJson(this);
}

/// Additional Consumer Data Request
@JsonSerializable()
class AdditionalConsumerData {
  final bool billNumber;
  final bool mobileNumber;
  final bool storeLabel;
  final bool loyaltyNumber;
  final bool referenceLabel;
  final bool customerLabel;
  final bool terminalLabel;
  final bool purposeOfTransaction;
  final bool additionalConsumerDataRequest;

  const AdditionalConsumerData({
    this.billNumber = false,
    this.mobileNumber = false,
    this.storeLabel = false,
    this.loyaltyNumber = false,
    this.referenceLabel = false,
    this.customerLabel = false,
    this.terminalLabel = false,
    this.purposeOfTransaction = false,
    this.additionalConsumerDataRequest = false,
  });

  factory AdditionalConsumerData.fromJson(Map<String, dynamic> json) =>
      _$AdditionalConsumerDataFromJson(json);

  Map<String, dynamic> toJson() => _$AdditionalConsumerDataToJson(this);

  /// Convert to SGQR format string
  String toSGQRFormat() {
    final buffer = StringBuffer();

    if (billNumber) buffer.write('01');
    if (mobileNumber) buffer.write('02');
    if (storeLabel) buffer.write('03');
    if (loyaltyNumber) buffer.write('04');
    if (referenceLabel) buffer.write('05');
    if (customerLabel) buffer.write('06');
    if (terminalLabel) buffer.write('07');
    if (purposeOfTransaction) buffer.write('08');
    if (additionalConsumerDataRequest) buffer.write('09');

    return buffer.toString();
  }
}

/// SGQR Payment Configuration
@JsonSerializable()
class SGQRConfig {
  final PayloadFormatIndicator payloadFormat;
  final PointOfInitiationMethod initiationMethod;
  final List<PaymentNetwork> supportedNetworks;
  final CurrencyCode currency;
  final MerchantInfo merchantInfo;
  final AdditionalConsumerData? additionalData;
  final String? tipOrConvenienceIndicator;
  final String? valueOfConvenienceFeeFixed;
  final String? valueOfConvenienceFeePercentage;

  const SGQRConfig({
    this.payloadFormat = PayloadFormatIndicator.cpv01,
    this.initiationMethod = PointOfInitiationMethod.dynamic,
    this.supportedNetworks = const [PaymentNetwork.payNow],
    this.currency = CurrencyCode.sgd,
    required this.merchantInfo,
    this.additionalData,
    this.tipOrConvenienceIndicator,
    this.valueOfConvenienceFeeFixed,
    this.valueOfConvenienceFeePercentage,
  });

  factory SGQRConfig.fromJson(Map<String, dynamic> json) =>
      _$SGQRConfigFromJson(json);

  Map<String, dynamic> toJson() => _$SGQRConfigToJson(this);

  /// Create a basic PayNow configuration
  factory SGQRConfig.payNowBasic({
    required MerchantInfo merchantInfo,
    PointOfInitiationMethod initiationMethod = PointOfInitiationMethod.dynamic,
    CurrencyCode currency = CurrencyCode.sgd,
  }) {
    return SGQRConfig(
      initiationMethod: initiationMethod,
      supportedNetworks: const [PaymentNetwork.payNow],
      currency: currency,
      merchantInfo: merchantInfo,
    );
  }
}

/// SGQR Payment Request
@JsonSerializable()
class SGQRPaymentRequest {
  final SGQRConfig config;
  final PayNowQRData? payNowData;
  final double? amount;
  final String? referenceNumber;
  final DateTime? expiryDate;
  final Map<String, String>? additionalInfo;

  const SGQRPaymentRequest({
    required this.config,
    this.payNowData,
    this.amount,
    this.referenceNumber,
    this.expiryDate,
    this.additionalInfo,
  });

  factory SGQRPaymentRequest.fromJson(Map<String, dynamic> json) =>
      _$SGQRPaymentRequestFromJson(json);

  Map<String, dynamic> toJson() => _$SGQRPaymentRequestToJson(this);

  /// Create a static PayNow QR request (no amount specified)
  factory SGQRPaymentRequest.staticPayNow({
    required PayNowQRData payNowData,
    required MerchantInfo merchantInfo,
    CurrencyCode currency = CurrencyCode.sgd,
    Map<String, String>? additionalInfo,
  }) {
    return SGQRPaymentRequest(
      config: SGQRConfig.payNowBasic(
        merchantInfo: merchantInfo,
        initiationMethod: PointOfInitiationMethod.static,
        currency: currency,
      ),
      payNowData: payNowData,
      additionalInfo: additionalInfo,
    );
  }

  /// Create a dynamic PayNow QR request (with amount)
  factory SGQRPaymentRequest.dynamicPayNow({
    required PayNowQRData payNowData,
    required MerchantInfo merchantInfo,
    required double amount,
    String? referenceNumber,
    DateTime? expiryDate,
    CurrencyCode currency = CurrencyCode.sgd,
    Map<String, String>? additionalInfo,
  }) {
    return SGQRPaymentRequest(
      config: SGQRConfig.payNowBasic(
        merchantInfo: merchantInfo,
        initiationMethod: PointOfInitiationMethod.dynamic,
        currency: currency,
      ),
      payNowData: payNowData,
      amount: amount,
      referenceNumber: referenceNumber,
      expiryDate: expiryDate,
      additionalInfo: additionalInfo,
    );
  }

  /// Check if this is a dynamic QR (has amount)
  bool get isDynamic => amount != null;

  /// Check if this is a static QR (no amount)
  bool get isStatic => amount == null;

  /// Validate the payment request
  List<String> validate() {
    final errors = <String>[];

    if (payNowData == null) {
      errors.add('PayNow data is required');
    }

    if (config.merchantInfo.merchantName?.isEmpty == true) {
      errors.add('Merchant name is required');
    }

    if (amount != null && amount! <= 0) {
      errors.add('Amount must be positive');
    }

    if (amount != null && amount! > 999999.99) {
      errors.add('Amount exceeds maximum limit');
    }

    if (expiryDate != null && expiryDate!.isBefore(DateTime.now())) {
      errors.add('Expiry date cannot be in the past');
    }

    return errors;
  }
}
