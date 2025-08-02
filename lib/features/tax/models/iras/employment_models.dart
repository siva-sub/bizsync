import 'package:json_annotation/json_annotation.dart';

part 'employment_models.g.dart';

/// Employment Income Records submission request
@JsonSerializable()
class EmploymentIncomeSubmissionRequest {
  final String inputType;
  final String? ir8aInput;
  final String? ir8sInput;
  final String? a8aInput;
  final String? a8bInput;
  final bool bypass;
  final bool validateOnly;

  const EmploymentIncomeSubmissionRequest({
    required this.inputType,
    this.ir8aInput,
    this.ir8sInput,
    this.a8aInput,
    this.a8bInput,
    this.bypass = false,
    this.validateOnly = false,
  });

  factory EmploymentIncomeSubmissionRequest.fromJson(Map<String, dynamic> json) =>
      _$EmploymentIncomeSubmissionRequestFromJson(json);

  Map<String, dynamic> toJson() => _$EmploymentIncomeSubmissionRequestToJson(this);
}

/// Employment Income Records submission response
@JsonSerializable()
class EmploymentIncomeSubmissionResponse {
  final int returnCode;
  final EmploymentIncomeData? data;
  final EmploymentApiInfo? info;

  const EmploymentIncomeSubmissionResponse({
    required this.returnCode,
    this.data,
    this.info,
  });

  factory EmploymentIncomeSubmissionResponse.fromJson(Map<String, dynamic> json) =>
      _$EmploymentIncomeSubmissionResponseFromJson(json);

  Map<String, dynamic> toJson() => _$EmploymentIncomeSubmissionResponseToJson(this);

  bool get isSuccess => returnCode == 10 || returnCode == 30;
}

/// Employment Income Data
@JsonSerializable()
class EmploymentIncomeData {
  final String submissionId;
  final String submissionStatus;
  final DateTime submissionDate;
  final List<EmploymentRecord> processedRecords;
  final EmploymentSummary summary;

  const EmploymentIncomeData({
    required this.submissionId,
    required this.submissionStatus,
    required this.submissionDate,
    required this.processedRecords,
    required this.summary,
  });

  factory EmploymentIncomeData.fromJson(Map<String, dynamic> json) =>
      _$EmploymentIncomeDataFromJson(json);

  Map<String, dynamic> toJson() => _$EmploymentIncomeDataToJson(this);
}

/// Individual Employment Record
@JsonSerializable()
class EmploymentRecord {
  final String recordType; // IR8A, IR8S, A8A, A8B
  final String employeeId;
  final String employeeName;
  final String employeeNric;
  final String status; // SUCCESS, ERROR, WARNING
  final List<String>? errors;
  final List<String>? warnings;

  const EmploymentRecord({
    required this.recordType,
    required this.employeeId,
    required this.employeeName,
    required this.employeeNric,
    required this.status,
    this.errors,
    this.warnings,
  });

  factory EmploymentRecord.fromJson(Map<String, dynamic> json) =>
      _$EmploymentRecordFromJson(json);

  Map<String, dynamic> toJson() => _$EmploymentRecordToJson(this);
}

/// Employment Submission Summary
@JsonSerializable()
class EmploymentSummary {
  final int totalRecords;
  final int successfulRecords;
  final int errorRecords;
  final int warningRecords;
  final Map<String, int> recordTypeCounts;

  const EmploymentSummary({
    required this.totalRecords,
    required this.successfulRecords,
    required this.errorRecords,
    required this.warningRecords,
    required this.recordTypeCounts,
  });

  factory EmploymentSummary.fromJson(Map<String, dynamic> json) =>
      _$EmploymentSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$EmploymentSummaryToJson(this);
}

/// IR8A Form Data
@JsonSerializable()
class Ir8aFormData {
  final String employerUen;
  final String employerName;
  final String yearOfAssessment;
  final String employeeNric;
  final String employeeName;
  final String employeeAddress;
  final String designation;
  final DateTime? employmentStartDate;
  final DateTime? employmentEndDate;
  final double grossIncome;
  final double employeeCpfContribution;
  final double employerCpfContribution;
  final double bonuses;
  final double benefitsInKind;
  final double director;
  final double overseasIncome;
  final double exemptIncome;
  final double totalIncome;

  const Ir8aFormData({
    required this.employerUen,
    required this.employerName,
    required this.yearOfAssessment,
    required this.employeeNric,
    required this.employeeName,
    required this.employeeAddress,
    required this.designation,
    this.employmentStartDate,
    this.employmentEndDate,
    required this.grossIncome,
    required this.employeeCpfContribution,
    required this.employerCpfContribution,
    required this.bonuses,
    required this.benefitsInKind,
    required this.director,
    required this.overseasIncome,
    required this.exemptIncome,
    required this.totalIncome,
  });

  factory Ir8aFormData.fromJson(Map<String, dynamic> json) =>
      _$Ir8aFormDataFromJson(json);

  Map<String, dynamic> toJson() => _$Ir8aFormDataToJson(this);

  /// Convert to CSV format for IRAS submission
  String toCsvRow() {
    return [
      employerUen,
      employerName,
      yearOfAssessment,
      employeeNric,
      employeeName,
      employeeAddress.replaceAll(',', ';'), // Escape commas
      designation,
      _formatDate(employmentStartDate),
      _formatDate(employmentEndDate),
      grossIncome.toStringAsFixed(2),
      employeeCpfContribution.toStringAsFixed(2),
      employerCpfContribution.toStringAsFixed(2),
      bonuses.toStringAsFixed(2),
      benefitsInKind.toStringAsFixed(2),
      director.toStringAsFixed(2),
      overseasIncome.toStringAsFixed(2),
      exemptIncome.toStringAsFixed(2),
      totalIncome.toStringAsFixed(2),
    ].join(',');
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

/// IR8S Form Data (Summary for directors/shareholders)
@JsonSerializable()
class Ir8sFormData {
  final String employerUen;
  final String employerName;
  final String yearOfAssessment;
  final String employeeNric;
  final String employeeName;
  final String designation;
  final double sharesHeld;
  final double percentageOwnership;
  final double directorFees;
  final double benefitsInKind;
  final double totalIncome;

  const Ir8sFormData({
    required this.employerUen,
    required this.employerName,
    required this.yearOfAssessment,
    required this.employeeNric,
    required this.employeeName,
    required this.designation,
    required this.sharesHeld,
    required this.percentageOwnership,
    required this.directorFees,
    required this.benefitsInKind,
    required this.totalIncome,
  });

  factory Ir8sFormData.fromJson(Map<String, dynamic> json) =>
      _$Ir8sFormDataFromJson(json);

  Map<String, dynamic> toJson() => _$Ir8sFormDataToJson(this);

  /// Convert to CSV format for IRAS submission
  String toCsvRow() {
    return [
      employerUen,
      employerName,
      yearOfAssessment,
      employeeNric,
      employeeName,
      designation,
      sharesHeld.toStringAsFixed(0),
      percentageOwnership.toStringAsFixed(2),
      directorFees.toStringAsFixed(2),
      benefitsInKind.toStringAsFixed(2),
      totalIncome.toStringAsFixed(2),
    ].join(',');
  }
}

/// Appendix 8A Form Data (Benefits in Kind)
@JsonSerializable()
class A8aFormData {
  final String employerUen;
  final String yearOfAssessment;
  final String employeeNric;
  final String employeeName;
  final List<BenefitInKindItem> benefits;
  final double totalBenefitsValue;

  const A8aFormData({
    required this.employerUen,
    required this.yearOfAssessment,
    required this.employeeNric,
    required this.employeeName,
    required this.benefits,
    required this.totalBenefitsValue,
  });

  factory A8aFormData.fromJson(Map<String, dynamic> json) =>
      _$A8aFormDataFromJson(json);

  Map<String, dynamic> toJson() => _$A8aFormDataToJson(this);
}

/// Benefit in Kind Item
@JsonSerializable()
class BenefitInKindItem {
  final String benefitType;
  final String description;
  final double value;
  final String period; // Monthly, Annual, etc.

  const BenefitInKindItem({
    required this.benefitType,
    required this.description,
    required this.value,
    required this.period,
  });

  factory BenefitInKindItem.fromJson(Map<String, dynamic> json) =>
      _$BenefitInKindItemFromJson(json);

  Map<String, dynamic> toJson() => _$BenefitInKindItemToJson(this);
}

/// Appendix 8B Form Data (Stock Options/ESOP)
@JsonSerializable()
class A8bFormData {
  final String employerUen;
  final String yearOfAssessment;
  final String employeeNric;
  final String employeeName;
  final List<StockOptionItem> stockOptions;
  final double totalStockOptionValue;

  const A8bFormData({
    required this.employerUen,
    required this.yearOfAssessment,
    required this.employeeNric,
    required this.employeeName,
    required this.stockOptions,
    required this.totalStockOptionValue,
  });

  factory A8bFormData.fromJson(Map<String, dynamic> json) =>
      _$A8bFormDataFromJson(json);

  Map<String, dynamic> toJson() => _$A8bFormDataToJson(this);
}

/// Stock Option Item
@JsonSerializable()
class StockOptionItem {
  final String grantDate;
  final String exerciseDate;
  final int numberOfShares;
  final double exercisePrice;
  final double marketPrice;
  final double benefitValue;

  const StockOptionItem({
    required this.grantDate,
    required this.exerciseDate,
    required this.numberOfShares,
    required this.exercisePrice,
    required this.marketPrice,
    required this.benefitValue,
  });

  factory StockOptionItem.fromJson(Map<String, dynamic> json) =>
      _$StockOptionItemFromJson(json);

  Map<String, dynamic> toJson() => _$StockOptionItemToJson(this);
}

/// Employment API Info
@JsonSerializable()
class EmploymentApiInfo {
  final int messageCode;
  final String message;
  final List<EmploymentFieldInfo>? fieldInfoList;

  const EmploymentApiInfo({
    required this.messageCode,
    required this.message,
    this.fieldInfoList,
  });

  factory EmploymentApiInfo.fromJson(Map<String, dynamic> json) =>
      _$EmploymentApiInfoFromJson(json);

  Map<String, dynamic> toJson() => _$EmploymentApiInfoToJson(this);
}

@JsonSerializable()
class EmploymentFieldInfo {
  final String field;
  final String message;

  const EmploymentFieldInfo({
    required this.field,
    required this.message,
  });

  factory EmploymentFieldInfo.fromJson(Map<String, dynamic> json) =>
      _$EmploymentFieldInfoFromJson(json);

  Map<String, dynamic> toJson() => _$EmploymentFieldInfoToJson(this);
}

/// Bulk Employment Records for submission
@JsonSerializable()
class BulkEmploymentRecords {
  final String employerUen;
  final String yearOfAssessment;
  final List<Ir8aFormData> ir8aRecords;
  final List<Ir8sFormData> ir8sRecords;
  final List<A8aFormData> a8aRecords;
  final List<A8bFormData> a8bRecords;

  const BulkEmploymentRecords({
    required this.employerUen,
    required this.yearOfAssessment,
    this.ir8aRecords = const [],
    this.ir8sRecords = const [],
    this.a8aRecords = const [],
    this.a8bRecords = const [],
  });

  factory BulkEmploymentRecords.fromJson(Map<String, dynamic> json) =>
      _$BulkEmploymentRecordsFromJson(json);

  Map<String, dynamic> toJson() => _$BulkEmploymentRecordsToJson(this);

  int get totalRecords => 
      ir8aRecords.length + 
      ir8sRecords.length + 
      a8aRecords.length + 
      a8bRecords.length;

  /// Convert to CSV format for IRAS submission
  Map<String, String> toCsvFormat() {
    final result = <String, String>{};

    if (ir8aRecords.isNotEmpty) {
      final header = 'UEN,Employer Name,YA,NRIC,Employee Name,Address,Designation,Start Date,End Date,Gross Income,Employee CPF,Employer CPF,Bonuses,Benefits,Director,Overseas,Exempt,Total';
      final rows = ir8aRecords.map((record) => record.toCsvRow()).join('\n');
      result['IR8A'] = '$header\n$rows';
    }

    if (ir8sRecords.isNotEmpty) {
      final header = 'UEN,Employer Name,YA,NRIC,Employee Name,Designation,Shares Held,Percentage,Director Fees,Benefits,Total';
      final rows = ir8sRecords.map((record) => record.toCsvRow()).join('\n');
      result['IR8S'] = '$header\n$rows';
    }

    return result;
  }
}