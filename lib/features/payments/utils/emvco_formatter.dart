import '../models/sgqr_models.dart';

/// EMVCo QR Code data object formatter for SGQR/PayNow
///
/// This utility class handles the formatting of data according to the
/// EMVCo QR Code Specification for Payment Systems Root Document Version 1.1
class EMVCoFormatter {
  // EMVCo QR Code Data Object Tags
  static const String _payloadFormatIndicatorTag = '00';
  static const String _pointOfInitiationTag = '01';
  static const String _merchantAccountInfoTag = '26'; // PayNow uses tag 26
  static const String _merchantCategoryCodeTag = '52';
  static const String _transactionCurrencyTag = '53';
  static const String _transactionAmountTag = '54';
  static const String _tipOrConvenienceIndicatorTag = '55';
  static const String _valueOfConvenienceFeeFixedTag = '56';
  static const String _valueOfConvenienceFeePercentageTag = '57';
  static const String _countryCodeTag = '58';
  static const String _merchantNameTag = '59';
  static const String _merchantCityTag = '60';
  static const String _postalCodeTag = '61';
  static const String _additionalDataFieldTemplateTag = '62';
  static const String _merchantInfoLanguageTemplateTag = '64';
  static const String _crcTag = '63';

  // PayNow specific sub-tags (under tag 26)
  static const String _payNowGuidTag = '00';
  static const String _payNowProxyTypeTag = '01';
  static const String _payNowProxyValueTag = '02';
  static const String _payNowEditableTag = '03';
  static const String _payNowExpiryDateTag = '04';

  // PayNow GUID (Singapore's PayNow identifier)
  static const String _payNowGuid = 'SG.PAYNOW';

  /// Format a data object as TLV (Tag-Length-Value)
  static String formatTLV(String tag, String value) {
    if (value.isEmpty) return '';

    final String length = value.length.toString().padLeft(2, '0');
    return '$tag$length$value';
  }

  /// Create SGQRDataObject from tag and value
  static SGQRDataObject createDataObject(String tag, String value) {
    if (value.isEmpty) {
      throw ArgumentError('Value cannot be empty for tag $tag');
    }

    return SGQRDataObject(
      tag: tag,
      length: value.length.toString().padLeft(2, '0'),
      value: value,
    );
  }

  /// Format PayNow merchant account information (Tag 26)
  static String formatPayNowMerchantInfo(PayNowQRData payNowData) {
    final buffer = StringBuffer();

    // PayNow GUID (Tag 00)
    buffer.write(formatTLV(_payNowGuidTag, _payNowGuid));

    // Proxy Type (Tag 01)
    buffer
        .write(formatTLV(_payNowProxyTypeTag, payNowData.identifierType.value));

    // Proxy Value (Tag 02)
    buffer.write(formatTLV(_payNowProxyValueTag, payNowData.identifier));

    // Editable amount indicator (Tag 03)
    if (payNowData.editable) {
      buffer.write(formatTLV(_payNowEditableTag, '1'));
    } else {
      buffer.write(formatTLV(_payNowEditableTag, '0'));
    }

    // Expiry date (Tag 04) - Format: YYYYMMDD
    if (payNowData.expiryDate != null) {
      final String expiryStr = _formatDate(payNowData.expiryDate!);
      buffer.write(formatTLV(_payNowExpiryDateTag, expiryStr));
    }

    final String merchantInfoValue = buffer.toString();
    return formatTLV(_merchantAccountInfoTag, merchantInfoValue);
  }

  /// Format additional data field template (Tag 62)
  static String formatAdditionalDataTemplate({
    String? billNumber,
    String? mobileNumber,
    String? storeLabel,
    String? loyaltyNumber,
    String? referenceLabel,
    String? customerLabel,
    String? terminalLabel,
    String? purposeOfTransaction,
    String? additionalConsumerDataRequest,
  }) {
    final buffer = StringBuffer();

    if (billNumber?.isNotEmpty == true) {
      buffer.write(formatTLV('01', billNumber!));
    }
    if (mobileNumber?.isNotEmpty == true) {
      buffer.write(formatTLV('02', mobileNumber!));
    }
    if (storeLabel?.isNotEmpty == true) {
      buffer.write(formatTLV('03', storeLabel!));
    }
    if (loyaltyNumber?.isNotEmpty == true) {
      buffer.write(formatTLV('04', loyaltyNumber!));
    }
    if (referenceLabel?.isNotEmpty == true) {
      buffer.write(formatTLV('05', referenceLabel!));
    }
    if (customerLabel?.isNotEmpty == true) {
      buffer.write(formatTLV('06', customerLabel!));
    }
    if (terminalLabel?.isNotEmpty == true) {
      buffer.write(formatTLV('07', terminalLabel!));
    }
    if (purposeOfTransaction?.isNotEmpty == true) {
      buffer.write(formatTLV('08', purposeOfTransaction!));
    }
    if (additionalConsumerDataRequest?.isNotEmpty == true) {
      buffer.write(formatTLV('09', additionalConsumerDataRequest!));
    }

    final String additionalDataValue = buffer.toString();
    if (additionalDataValue.isEmpty) return '';

    return formatTLV(_additionalDataFieldTemplateTag, additionalDataValue);
  }

  /// Format merchant information language template (Tag 64)
  static String formatMerchantInfoLanguageTemplate({
    required String languagePreference,
    required String merchantName,
    String? merchantCity,
  }) {
    final buffer = StringBuffer();

    // Language preference (Tag 00)
    buffer.write(formatTLV('00', languagePreference));

    // Merchant name in alternate language (Tag 01)
    buffer.write(formatTLV('01', merchantName));

    // Merchant city in alternate language (Tag 02)
    if (merchantCity?.isNotEmpty == true) {
      buffer.write(formatTLV('02', merchantCity!));
    }

    final String languageTemplateValue = buffer.toString();
    return formatTLV(_merchantInfoLanguageTemplateTag, languageTemplateValue);
  }

  /// Parse TLV data into individual components
  static List<SGQRDataObject> parseTLV(String tlvString) {
    final List<SGQRDataObject> objects = [];
    int index = 0;

    while (index < tlvString.length) {
      if (index + 4 > tlvString.length) break;

      final String tag = tlvString.substring(index, index + 2);
      final String lengthStr = tlvString.substring(index + 2, index + 4);

      int length;
      try {
        length = int.parse(lengthStr);
      } catch (e) {
        throw FormatException(
            'Invalid length value: $lengthStr at position $index');
      }

      if (index + 4 + length > tlvString.length) {
        throw FormatException(
            'Data length exceeds string bounds at position $index');
      }

      final String value = tlvString.substring(index + 4, index + 4 + length);

      objects.add(SGQRDataObject(
        tag: tag,
        length: lengthStr,
        value: value,
      ));

      index += 4 + length;
    }

    return objects;
  }

  /// Validate TLV structure
  static bool validateTLVStructure(String tlvString) {
    try {
      parseTLV(tlvString);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Find data object by tag
  static SGQRDataObject? findDataObjectByTag(
    List<SGQRDataObject> objects,
    String tag,
  ) {
    try {
      return objects.firstWhere((obj) => obj.tag == tag);
    } catch (e) {
      return null;
    }
  }

  /// Extract PayNow information from merchant account info
  static PayNowQRData? extractPayNowData(String merchantAccountInfo) {
    final List<SGQRDataObject> subObjects = parseTLV(merchantAccountInfo);

    final SGQRDataObject? guidObj =
        findDataObjectByTag(subObjects, _payNowGuidTag);
    if (guidObj?.value != _payNowGuid) {
      return null; // Not a PayNow QR
    }

    final SGQRDataObject? typeObj =
        findDataObjectByTag(subObjects, _payNowProxyTypeTag);
    final SGQRDataObject? valueObj =
        findDataObjectByTag(subObjects, _payNowProxyValueTag);
    final SGQRDataObject? editableObj =
        findDataObjectByTag(subObjects, _payNowEditableTag);
    final SGQRDataObject? expiryObj =
        findDataObjectByTag(subObjects, _payNowExpiryDateTag);

    if (typeObj == null || valueObj == null) {
      return null;
    }

    PayNowIdentifierType? identifierType;
    switch (typeObj.value) {
      case '0':
        identifierType = PayNowIdentifierType.mobile;
        break;
      case '2':
        identifierType = PayNowIdentifierType.uen;
        break;
      case '3':
        identifierType = PayNowIdentifierType.nric;
        break;
      default:
        return null;
    }

    final bool editable = editableObj?.value == '1';
    DateTime? expiryDate;

    if (expiryObj != null) {
      expiryDate = _parseDate(expiryObj.value);
    }

    return PayNowQRData(
      identifierType: identifierType,
      identifier: valueObj.value,
      editable: editable,
      expiryDate: expiryDate,
    );
  }

  /// Format date as YYYYMMDD
  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Parse date from YYYYMMDD format
  static DateTime? _parseDate(String dateStr) {
    if (dateStr.length != 8) return null;

    try {
      final int year = int.parse(dateStr.substring(0, 4));
      final int month = int.parse(dateStr.substring(4, 6));
      final int day = int.parse(dateStr.substring(6, 8));

      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }

  /// Validate EMVCo data object structure
  static List<String> validateDataObjects(List<SGQRDataObject> objects) {
    final List<String> errors = [];
    final Set<String> seenTags = <String>{};

    for (final SGQRDataObject obj in objects) {
      // Check for duplicate tags (except for merchant account info which can have multiple)
      if (seenTags.contains(obj.tag) && obj.tag != '26') {
        errors.add('Duplicate tag found: ${obj.tag}');
      }
      seenTags.add(obj.tag);

      // Validate tag format (2 digits)
      if (obj.tag.length != 2 || !RegExp(r'^\d{2}$').hasMatch(obj.tag)) {
        errors.add('Invalid tag format: ${obj.tag}');
      }

      // Validate length format (2 digits)
      if (obj.length.length != 2 || !RegExp(r'^\d{2}$').hasMatch(obj.length)) {
        errors.add('Invalid length format: ${obj.length} for tag ${obj.tag}');
      }

      // Validate length matches value
      final int expectedLength = int.tryParse(obj.length) ?? -1;
      if (expectedLength != obj.value.length) {
        errors.add('Length mismatch for tag ${obj.tag}: '
            'expected $expectedLength, got ${obj.value.length}');
      }

      // Validate value content based on tag
      _validateTagValue(obj.tag, obj.value, errors);
    }

    return errors;
  }

  /// Validate specific tag values
  static void _validateTagValue(String tag, String value, List<String> errors) {
    switch (tag) {
      case '00': // Payload Format Indicator
        if (value != '01' && value != '02') {
          errors.add('Invalid Payload Format Indicator: $value');
        }
        break;
      case '01': // Point of Initiation Method
        if (value != '11' && value != '12') {
          errors.add('Invalid Point of Initiation Method: $value');
        }
        break;
      case '52': // Merchant Category Code
        if (value.length != 4 || !RegExp(r'^\d{4}$').hasMatch(value)) {
          errors.add('Invalid Merchant Category Code: $value');
        }
        break;
      case '53': // Transaction Currency
        if (value.length != 3 || !RegExp(r'^\d{3}$').hasMatch(value)) {
          errors.add('Invalid Transaction Currency: $value');
        }
        break;
      case '54': // Transaction Amount
        if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) {
          errors.add('Invalid Transaction Amount format: $value');
        }
        break;
      case '58': // Country Code
        if (value.length != 2 || !RegExp(r'^[A-Z]{2}$').hasMatch(value)) {
          errors.add('Invalid Country Code: $value');
        }
        break;
      case '59': // Merchant Name
        if (value.isEmpty || value.length > 25) {
          errors.add('Invalid Merchant Name length: ${value.length}');
        }
        break;
      case '60': // Merchant City
        if (value.isEmpty || value.length > 15) {
          errors.add('Invalid Merchant City length: ${value.length}');
        }
        break;
    }
  }

  /// Get EMVCo tag description for debugging
  static String getTagDescription(String tag) {
    const Map<String, String> tagDescriptions = {
      '00': 'Payload Format Indicator',
      '01': 'Point of Initiation Method',
      '26': 'Merchant Account Information (PayNow)',
      '52': 'Merchant Category Code',
      '53': 'Transaction Currency',
      '54': 'Transaction Amount',
      '55': 'Tip or Convenience Indicator',
      '56': 'Value of Convenience Fee Fixed',
      '57': 'Value of Convenience Fee Percentage',
      '58': 'Country Code',
      '59': 'Merchant Name',
      '60': 'Merchant City',
      '61': 'Postal Code',
      '62': 'Additional Data Field Template',
      '63': 'CRC',
      '64': 'Merchant Information - Language Template',
    };

    return tagDescriptions[tag] ?? 'Unknown Tag';
  }
}
