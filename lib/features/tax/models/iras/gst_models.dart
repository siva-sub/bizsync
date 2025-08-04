import 'package:json_annotation/json_annotation.dart';

part 'gst_models.g.dart';

/// GST F5 Return submission request model
@JsonSerializable()
class GstF5SubmissionRequest {
  final GstFilingInfo filingInfo;
  final GstSupplies supplies;
  final GstPurchases purchases;
  final GstTaxes taxes;
  final GstSchemes schemes;
  final GstRevenue revenue;
  final GstIgdScheme igdScheme;
  final GstDeclaration declaration;
  final GstReasons reasons;

  const GstF5SubmissionRequest({
    required this.filingInfo,
    required this.supplies,
    required this.purchases,
    required this.taxes,
    required this.schemes,
    required this.revenue,
    required this.igdScheme,
    required this.declaration,
    required this.reasons,
  });

  factory GstF5SubmissionRequest.fromJson(Map<String, dynamic> json) =>
      _$GstF5SubmissionRequestFromJson(json);

  Map<String, dynamic> toJson() => _$GstF5SubmissionRequestToJson(this);
}

/// GST F5 Return submission response model
@JsonSerializable()
class GstF5SubmissionResponse {
  final int returnCode;
  final GstF5SubmissionData? data;
  final GstApiInfo? info;

  const GstF5SubmissionResponse({
    required this.returnCode,
    this.data,
    this.info,
  });

  factory GstF5SubmissionResponse.fromJson(Map<String, dynamic> json) =>
      _$GstF5SubmissionResponseFromJson(json);

  Map<String, dynamic> toJson() => _$GstF5SubmissionResponseToJson(this);

  bool get isSuccess => returnCode == 10 || returnCode == 30;
}

@JsonSerializable()
class GstF5SubmissionData {
  final GstFilingInfoResponse filingInfo;
  final GstSuppliesResponse supplies;
  final GstPurchasesResponse purchases;
  final GstTaxesResponse taxes;
  final GstSchemesResponse schemes;
  final GstRevenueResponse revenue;
  final GstIgdSchemeResponse igdScheme;
  final GstDeclarationResponse declaration;
  final GstReasonsResponse reasons;

  const GstF5SubmissionData({
    required this.filingInfo,
    required this.supplies,
    required this.purchases,
    required this.taxes,
    required this.schemes,
    required this.revenue,
    required this.igdScheme,
    required this.declaration,
    required this.reasons,
  });

  factory GstF5SubmissionData.fromJson(Map<String, dynamic> json) =>
      _$GstF5SubmissionDataFromJson(json);

  Map<String, dynamic> toJson() => _$GstF5SubmissionDataToJson(this);
}

/// GST Filing Information
@JsonSerializable()
class GstFilingInfo {
  final String taxRefNo;
  final String formType;
  final String dtPeriodStart;
  final String dtPeriodEnd;

  const GstFilingInfo({
    required this.taxRefNo,
    required this.formType,
    required this.dtPeriodStart,
    required this.dtPeriodEnd,
  });

  factory GstFilingInfo.fromJson(Map<String, dynamic> json) =>
      _$GstFilingInfoFromJson(json);

  Map<String, dynamic> toJson() => _$GstFilingInfoToJson(this);
}

@JsonSerializable()
class GstFilingInfoResponse extends GstFilingInfo {
  final String? gstRegNo;
  final String? ackNo;
  final String? pymtRefNo;
  final String? companyName;
  final String? dtSubmission;

  const GstFilingInfoResponse({
    required super.taxRefNo,
    required super.formType,
    required super.dtPeriodStart,
    required super.dtPeriodEnd,
    this.gstRegNo,
    this.ackNo,
    this.pymtRefNo,
    this.companyName,
    this.dtSubmission,
  });

  factory GstFilingInfoResponse.fromJson(Map<String, dynamic> json) =>
      _$GstFilingInfoResponseFromJson(json);

  Map<String, dynamic> toJson() => _$GstFilingInfoResponseToJson(this);
}

/// GST Supplies
@JsonSerializable()
class GstSupplies {
  final double totStdSupply;
  final double totZeroSupply;
  final double totExemptSupply;

  const GstSupplies({
    required this.totStdSupply,
    required this.totZeroSupply,
    required this.totExemptSupply,
  });

  factory GstSupplies.fromJson(Map<String, dynamic> json) =>
      _$GstSuppliesFromJson(json);

  Map<String, dynamic> toJson() => _$GstSuppliesToJson(this);
}

@JsonSerializable()
class GstSuppliesResponse extends GstSupplies {
  final double? totValueSupply;

  const GstSuppliesResponse({
    required super.totStdSupply,
    required super.totZeroSupply,
    required super.totExemptSupply,
    this.totValueSupply,
  });

  factory GstSuppliesResponse.fromJson(Map<String, dynamic> json) =>
      _$GstSuppliesResponseFromJson(json);

  Map<String, dynamic> toJson() => _$GstSuppliesResponseToJson(this);
}

/// GST Purchases
@JsonSerializable()
class GstPurchases {
  final double totTaxPurchase;

  const GstPurchases({
    required this.totTaxPurchase,
  });

  factory GstPurchases.fromJson(Map<String, dynamic> json) =>
      _$GstPurchasesFromJson(json);

  Map<String, dynamic> toJson() => _$GstPurchasesToJson(this);
}

@JsonSerializable()
class GstPurchasesResponse extends GstPurchases {
  const GstPurchasesResponse({
    required super.totTaxPurchase,
  });

  factory GstPurchasesResponse.fromJson(Map<String, dynamic> json) =>
      _$GstPurchasesResponseFromJson(json);

  Map<String, dynamic> toJson() => _$GstPurchasesResponseToJson(this);
}

/// GST Taxes
@JsonSerializable()
class GstTaxes {
  final double outputTaxDue;
  final double inputTaxRefund;

  const GstTaxes({
    required this.outputTaxDue,
    required this.inputTaxRefund,
  });

  factory GstTaxes.fromJson(Map<String, dynamic> json) =>
      _$GstTaxesFromJson(json);

  Map<String, dynamic> toJson() => _$GstTaxesToJson(this);
}

@JsonSerializable()
class GstTaxesResponse extends GstTaxes {
  final double? netGSTPaid;

  const GstTaxesResponse({
    required super.outputTaxDue,
    required super.inputTaxRefund,
    this.netGSTPaid,
  });

  factory GstTaxesResponse.fromJson(Map<String, dynamic> json) =>
      _$GstTaxesResponseFromJson(json);

  Map<String, dynamic> toJson() => _$GstTaxesResponseToJson(this);
}

/// GST Schemes
@JsonSerializable()
class GstSchemes {
  final double totValueScheme;
  final bool touristRefundChk;
  final double touristRefundAmt;
  final bool badDebtChk;
  final double badDebtReliefClaimAmt;
  final bool preRegistrationChk;
  final double preRegistrationClaimAmt;

  const GstSchemes({
    required this.totValueScheme,
    required this.touristRefundChk,
    required this.touristRefundAmt,
    required this.badDebtChk,
    required this.badDebtReliefClaimAmt,
    required this.preRegistrationChk,
    required this.preRegistrationClaimAmt,
  });

  factory GstSchemes.fromJson(Map<String, dynamic> json) =>
      _$GstSchemesFromJson(json);

  Map<String, dynamic> toJson() => _$GstSchemesToJson(this);
}

@JsonSerializable()
class GstSchemesResponse extends GstSchemes {
  const GstSchemesResponse({
    required super.totValueScheme,
    required super.touristRefundChk,
    required super.touristRefundAmt,
    required super.badDebtChk,
    required super.badDebtReliefClaimAmt,
    required super.preRegistrationChk,
    required super.preRegistrationClaimAmt,
  });

  factory GstSchemesResponse.fromJson(Map<String, dynamic> json) =>
      _$GstSchemesResponseFromJson(json);

  Map<String, dynamic> toJson() => _$GstSchemesResponseToJson(this);
}

/// GST Revenue
@JsonSerializable()
class GstRevenue {
  final double revenue;

  const GstRevenue({
    required this.revenue,
  });

  factory GstRevenue.fromJson(Map<String, dynamic> json) =>
      _$GstRevenueFromJson(json);

  Map<String, dynamic> toJson() => _$GstRevenueToJson(this);
}

@JsonSerializable()
class GstRevenueResponse extends GstRevenue {
  const GstRevenueResponse({
    required super.revenue,
  });

  factory GstRevenueResponse.fromJson(Map<String, dynamic> json) =>
      _$GstRevenueResponseFromJson(json);

  Map<String, dynamic> toJson() => _$GstRevenueResponseToJson(this);
}

/// GST IGD Scheme
@JsonSerializable()
class GstIgdScheme {
  final double defImpPayableAmt;
  final double defTotalGoodsImp;

  const GstIgdScheme({
    required this.defImpPayableAmt,
    required this.defTotalGoodsImp,
  });

  factory GstIgdScheme.fromJson(Map<String, dynamic> json) =>
      _$GstIgdSchemeFromJson(json);

  Map<String, dynamic> toJson() => _$GstIgdSchemeToJson(this);
}

@JsonSerializable()
class GstIgdSchemeResponse extends GstIgdScheme {
  final double? defNetGst;
  final double? defTotalTaxAmt;

  const GstIgdSchemeResponse({
    required super.defImpPayableAmt,
    required super.defTotalGoodsImp,
    this.defNetGst,
    this.defTotalTaxAmt,
  });

  factory GstIgdSchemeResponse.fromJson(Map<String, dynamic> json) =>
      _$GstIgdSchemeResponseFromJson(json);

  Map<String, dynamic> toJson() => _$GstIgdSchemeResponseToJson(this);
}

/// GST Declaration
@JsonSerializable()
class GstDeclaration {
  final String declarantDesgtn;
  final String contactPerson;
  final String contactNumber;
  final String contactEmail;

  const GstDeclaration({
    required this.declarantDesgtn,
    required this.contactPerson,
    required this.contactNumber,
    required this.contactEmail,
  });

  factory GstDeclaration.fromJson(Map<String, dynamic> json) =>
      _$GstDeclarationFromJson(json);

  Map<String, dynamic> toJson() => _$GstDeclarationToJson(this);
}

@JsonSerializable()
class GstDeclarationResponse extends GstDeclaration {
  final String? declarantID;
  final String? declarantName;

  const GstDeclarationResponse({
    required super.declarantDesgtn,
    required super.contactPerson,
    required super.contactNumber,
    required super.contactEmail,
    this.declarantID,
    this.declarantName,
  });

  factory GstDeclarationResponse.fromJson(Map<String, dynamic> json) =>
      _$GstDeclarationResponseFromJson(json);

  Map<String, dynamic> toJson() => _$GstDeclarationResponseToJson(this);
}

/// GST Reasons
@JsonSerializable()
class GstReasons {
  final bool grp1BadDebtRecoveryChk;
  final bool grp1PriorToRegChk;
  final bool grp1OtherReasonChk;
  final String grp1OtherReasons;
  final bool grp2TouristRefundChk;
  final bool grp2AppvBadDebtReliefChk;
  final bool grp2CreditNotesChk;
  final bool grp2OtherReasonsChk;
  final String grp2OtherReasons;
  final bool grp3CreditNotesChk;
  final bool grp3OtherReasonsChk;
  final String grp3OtherReasons;

  const GstReasons({
    required this.grp1BadDebtRecoveryChk,
    required this.grp1PriorToRegChk,
    required this.grp1OtherReasonChk,
    required this.grp1OtherReasons,
    required this.grp2TouristRefundChk,
    required this.grp2AppvBadDebtReliefChk,
    required this.grp2CreditNotesChk,
    required this.grp2OtherReasonsChk,
    required this.grp2OtherReasons,
    required this.grp3CreditNotesChk,
    required this.grp3OtherReasonsChk,
    required this.grp3OtherReasons,
  });

  factory GstReasons.fromJson(Map<String, dynamic> json) =>
      _$GstReasonsFromJson(json);

  Map<String, dynamic> toJson() => _$GstReasonsToJson(this);
}

@JsonSerializable()
class GstReasonsResponse extends GstReasons {
  const GstReasonsResponse({
    required super.grp1BadDebtRecoveryChk,
    required super.grp1PriorToRegChk,
    required super.grp1OtherReasonChk,
    required super.grp1OtherReasons,
    required super.grp2TouristRefundChk,
    required super.grp2AppvBadDebtReliefChk,
    required super.grp2CreditNotesChk,
    required super.grp2OtherReasonsChk,
    required super.grp2OtherReasons,
    required super.grp3CreditNotesChk,
    required super.grp3OtherReasonsChk,
    required super.grp3OtherReasons,
  });

  factory GstReasonsResponse.fromJson(Map<String, dynamic> json) =>
      _$GstReasonsResponseFromJson(json);

  Map<String, dynamic> toJson() => _$GstReasonsResponseToJson(this);
}

/// Common API info structure
@JsonSerializable()
class GstApiInfo {
  final int messageCode;
  final String message;
  final List<GstFieldInfo>? fieldInfoList;

  const GstApiInfo({
    required this.messageCode,
    required this.message,
    this.fieldInfoList,
  });

  factory GstApiInfo.fromJson(Map<String, dynamic> json) =>
      _$GstApiInfoFromJson(json);

  Map<String, dynamic> toJson() => _$GstApiInfoToJson(this);
}

@JsonSerializable()
class GstFieldInfo {
  final String field;
  final String message;

  const GstFieldInfo({
    required this.field,
    required this.message,
  });

  factory GstFieldInfo.fromJson(Map<String, dynamic> json) =>
      _$GstFieldInfoFromJson(json);

  Map<String, dynamic> toJson() => _$GstFieldInfoToJson(this);
}

/// GST Register Check Request
@JsonSerializable()
class GstRegisterCheckRequest {
  final String gstRegNo;

  const GstRegisterCheckRequest({
    required this.gstRegNo,
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
  final GstApiInfo? info;

  const GstRegisterCheckResponse({
    required this.returnCode,
    this.data,
    this.info,
  });

  factory GstRegisterCheckResponse.fromJson(Map<String, dynamic> json) =>
      _$GstRegisterCheckResponseFromJson(json);

  Map<String, dynamic> toJson() => _$GstRegisterCheckResponseToJson(this);

  bool get isSuccess => returnCode == 10 || returnCode == 30;
}

@JsonSerializable()
class GstRegisterData {
  final String gstRegNo;
  final String companyName;
  final String registrationStatus;
  final String? effectiveDate;
  final String? cancellationDate;

  const GstRegisterData({
    required this.gstRegNo,
    required this.companyName,
    required this.registrationStatus,
    this.effectiveDate,
    this.cancellationDate,
  });

  factory GstRegisterData.fromJson(Map<String, dynamic> json) =>
      _$GstRegisterDataFromJson(json);

  Map<String, dynamic> toJson() => _$GstRegisterDataToJson(this);
}
