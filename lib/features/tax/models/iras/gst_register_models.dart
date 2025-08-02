import 'package:json_annotation/json_annotation.dart';

part 'gst_register_models.g.dart';

/// GST Register Check API models based on Check_GST_Register-1.0.7.yaml
/// This implements the exact structure from the IRAS API specification

/// GST Register Check Request
@JsonSerializable()
class GstRegisterCheckRequest {
  final String clientID;
  final String regID; // Registration ID (UEN, NRIC, or GST registration number)

  const GstRegisterCheckRequest({
    required this.clientID,
    required this.regID,
  });

  factory GstRegisterCheckRequest.fromJson(Map<String, dynamic> json) =>
      _$GstRegisterCheckRequestFromJson(json);

  Map<String, dynamic> toJson() => _$GstRegisterCheckRequestToJson(this);
}

/// GST Register Check Response
@JsonSerializable()
class GstRegisterCheckResponse {
  final int returnCode;
  final GstRegisterData? data;
  final GstRegisterInfo? info;

  const GstRegisterCheckResponse({
    required this.returnCode,
    this.data,
    this.info,
  });

  /// Check if the response indicates success
  bool get isSuccess => returnCode == 10;

  factory GstRegisterCheckResponse.fromJson(Map<String, dynamic> json) =>
      _$GstRegisterCheckResponseFromJson(json);

  Map<String, dynamic> toJson() => _$GstRegisterCheckResponseToJson(this);
}

/// GST Registration Data
@JsonSerializable()
class GstRegisterData {
  final String? name;
  final String? gstRegistrationNumber;
  final String? registrationId;
  @JsonKey(name: 'RegisteredFrom')
  final String? registeredFrom;
  @JsonKey(name: 'RegisteredTo')
  final String? registeredTo;
  @JsonKey(name: 'Remarks')
  final String? remarks;
  @JsonKey(name: 'Status')
  final String? status;

  const GstRegisterData({
    this.name,
    this.gstRegistrationNumber,
    this.registrationId,
    this.registeredFrom,
    this.registeredTo,
    this.remarks,
    this.status,
  });

  /// Check if the entity is currently GST registered
  bool get isGstRegistered => status?.toLowerCase() == 'registered';

  /// Check if GST registration is active (no end date or end date in future)
  bool get isActiveRegistration {
    if (!isGstRegistered) return false;
    
    if (registeredTo == null || registeredTo!.isEmpty) return true;
    
    try {
      // Parse the date (format appears to be DD/MM/YYYY from example)
      final parts = registeredTo!.split('/');
      if (parts.length != 3) return false;
      
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      final endDate = DateTime(year, month, day);
      
      return endDate.isAfter(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  factory GstRegisterData.fromJson(Map<String, dynamic> json) =>
      _$GstRegisterDataFromJson(json);

  Map<String, dynamic> toJson() => _$GstRegisterDataToJson(this);
}

/// Error information
@JsonSerializable()
class GstRegisterInfo {
  final String? message;
  final int? messageCode;
  final List<GstRegisterFieldInfo>? fieldInfoList;

  const GstRegisterInfo({
    this.message,
    this.messageCode,
    this.fieldInfoList,
  });

  factory GstRegisterInfo.fromJson(Map<String, dynamic> json) =>
      _$GstRegisterInfoFromJson(json);

  Map<String, dynamic> toJson() => _$GstRegisterInfoToJson(this);
}

/// Field-level error information
@JsonSerializable()
class GstRegisterFieldInfo {
  final String? field;
  final String? message;

  const GstRegisterFieldInfo({
    this.field,
    this.message,
  });

  factory GstRegisterFieldInfo.fromJson(Map<String, dynamic> json) =>
      _$GstRegisterFieldInfoFromJson(json);

  Map<String, dynamic> toJson() => _$GstRegisterFieldInfoToJson(this);
}

/// GST Registration Status enum
enum GstRegistrationStatus {
  registered,
  deregistered,
  unknown;

  static GstRegistrationStatus fromString(String? status) {
    if (status == null) return unknown;
    
    switch (status.toLowerCase()) {
      case 'registered':
        return registered;
      case 'deregistered':
        return deregistered;
      default:
        return unknown;
    }
  }
}

/// Factory method to create sample request
GstRegisterCheckRequest createSampleGstRegisterRequest() {
  return const GstRegisterCheckRequest(
    clientID: '123456',
    regID: '199202892R', // Example GST registration number from YAML
  );
}