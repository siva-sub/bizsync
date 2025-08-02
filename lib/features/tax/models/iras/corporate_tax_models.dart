import 'package:json_annotation/json_annotation.dart';

part 'corporate_tax_models.g.dart';

/// Corporate Income Tax (CIT) Conversion request model
@JsonSerializable()
class CitConversionRequest {
  final CitDeclaration declaration;
  final String clientId;
  final CitFilingInfo filingInfo;
  final CitFinancialData data;

  const CitConversionRequest({
    required this.declaration,
    required this.clientId,
    required this.filingInfo,
    required this.data,
  });

  factory CitConversionRequest.fromJson(Map<String, dynamic> json) =>
      _$CitConversionRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CitConversionRequestToJson(this);
}

/// CIT Declaration
@JsonSerializable()
class CitDeclaration {
  final String isQualifiedToUseConvFormCS;

  const CitDeclaration({
    required this.isQualifiedToUseConvFormCS,
  });

  factory CitDeclaration.fromJson(Map<String, dynamic> json) =>
      _$CitDeclarationFromJson(json);

  Map<String, dynamic> toJson() => _$CitDeclarationToJson(this);
}

/// CIT Filing Information
@JsonSerializable()
class CitFilingInfo {
  final String ya; // Year of Assessment

  const CitFilingInfo({
    required this.ya,
  });

  factory CitFilingInfo.fromJson(Map<String, dynamic> json) =>
      _$CitFilingInfoFromJson(json);

  Map<String, dynamic> toJson() => _$CitFilingInfoToJson(this);
}

/// CIT Financial Data
@JsonSerializable()
class CitFinancialData {
  // Revenue and Income
  final String totalRevenue;
  final String sgIntDisc; // Singapore Interest/Discount
  final String oneTierTaxDividendIncome;
  final String c1GrossRent;
  final String sgOtherI; // Singapore Other Income
  final String otherNonTaxableIncome;
  final String totalOtherIncome;

  // Expenses
  final String costOfGoodsSold;
  final String bankCharges;
  final String commissionOther;
  final String depreciationExpense;
  final String directorsFees;
  final String directorsRemunerationExcludingDirectorsFees;
  final String donations;
  final String cpfContribution;
  final String employeeBenefits;
  final String foreignExchangeLoss;
  final String insurance;
  final String interestExpense;
  final String legalProfessionalFees;
  final String maintenanceRepairs;
  final String marketingAdvertising;
  final String officePremisesExpense;
  final String otherOperatingExpenses;
  final String rentExpense;
  final String salariesWages;
  final String travellingEntertainment;
  final String utilitiesTelephone;

  // Capital Allowances
  final String capitalAllowanceClaimed;
  final String capitalAllowanceClawback;

  // Other adjustments
  final String badDebtProvision;
  final String goodwillWriteOff;
  final String otherAdjustments;

  const CitFinancialData({
    required this.totalRevenue,
    required this.sgIntDisc,
    required this.oneTierTaxDividendIncome,
    required this.c1GrossRent,
    required this.sgOtherI,
    required this.otherNonTaxableIncome,
    required this.totalOtherIncome,
    required this.costOfGoodsSold,
    required this.bankCharges,
    required this.commissionOther,
    required this.depreciationExpense,
    required this.directorsFees,
    required this.directorsRemunerationExcludingDirectorsFees,
    required this.donations,
    required this.cpfContribution,
    required this.employeeBenefits,
    required this.foreignExchangeLoss,
    required this.insurance,
    required this.interestExpense,
    required this.legalProfessionalFees,
    required this.maintenanceRepairs,
    required this.marketingAdvertising,
    required this.officePremisesExpense,
    required this.otherOperatingExpenses,
    required this.rentExpense,
    required this.salariesWages,
    required this.travellingEntertainment,
    required this.utilitiesTelephone,
    required this.capitalAllowanceClaimed,
    required this.capitalAllowanceClawback,
    required this.badDebtProvision,
    required this.goodwillWriteOff,
    required this.otherAdjustments,
  });

  factory CitFinancialData.fromJson(Map<String, dynamic> json) =>
      _$CitFinancialDataFromJson(json);

  Map<String, dynamic> toJson() => _$CitFinancialDataToJson(this);
}

/// CIT Conversion Response
@JsonSerializable()
class CitConversionResponse {
  final int returnCode;
  final CitConversionData? data;
  final CitApiInfo? info;

  const CitConversionResponse({
    required this.returnCode,
    this.data,
    this.info,
  });

  factory CitConversionResponse.fromJson(Map<String, dynamic> json) =>
      _$CitConversionResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CitConversionResponseToJson(this);

  bool get isSuccess => returnCode == 10 || returnCode == 30;
}

/// CIT Conversion Data
@JsonSerializable()
class CitConversionData {
  final CitProfitLossStatement profitLossStatement;
  final CitTaxComputation taxComputation;
  final CitFormCS formCS;
  final CitSchedules schedules;

  const CitConversionData({
    required this.profitLossStatement,
    required this.taxComputation,
    required this.formCS,
    required this.schedules,
  });

  factory CitConversionData.fromJson(Map<String, dynamic> json) =>
      _$CitConversionDataFromJson(json);

  Map<String, dynamic> toJson() => _$CitConversionDataToJson(this);
}

/// CIT Profit & Loss Statement
@JsonSerializable()
class CitProfitLossStatement {
  final double totalRevenue;
  final double totalExpenses;
  final double netProfit;
  final double adjustmentsForTax;
  final double adjustedProfit;

  const CitProfitLossStatement({
    required this.totalRevenue,
    required this.totalExpenses,
    required this.netProfit,
    required this.adjustmentsForTax,
    required this.adjustedProfit,
  });

  factory CitProfitLossStatement.fromJson(Map<String, dynamic> json) =>
      _$CitProfitLossStatementFromJson(json);

  Map<String, dynamic> toJson() => _$CitProfitLossStatementToJson(this);
}

/// CIT Tax Computation
@JsonSerializable()
class CitTaxComputation {
  final double adjustedProfit;
  final double exemptions;
  final double taxableIncome;
  final double corporateIncomeTax;
  final double effectiveTaxRate;

  const CitTaxComputation({
    required this.adjustedProfit,
    required this.exemptions,
    required this.taxableIncome,
    required this.corporateIncomeTax,
    required this.effectiveTaxRate,
  });

  factory CitTaxComputation.fromJson(Map<String, dynamic> json) =>
      _$CitTaxComputationFromJson(json);

  Map<String, dynamic> toJson() => _$CitTaxComputationToJson(this);
}

/// CIT Form C-S
@JsonSerializable()
class CitFormCS {
  final String companyName;
  final String companyRegistrationNumber;
  final String yearOfAssessment;
  final double totalIncome;
  final double totalDeductions;
  final double chargeableIncome;
  final double taxPayable;

  const CitFormCS({
    required this.companyName,
    required this.companyRegistrationNumber,
    required this.yearOfAssessment,
    required this.totalIncome,
    required this.totalDeductions,
    required this.chargeableIncome,
    required this.taxPayable,
  });

  factory CitFormCS.fromJson(Map<String, dynamic> json) =>
      _$CitFormCSFromJson(json);

  Map<String, dynamic> toJson() => _$CitFormCSToJson(this);
}

/// CIT Schedules
@JsonSerializable()
class CitSchedules {
  final CitCapitalAllowanceSchedule capitalAllowance;
  final CitMedicalExpenseSchedule medicalExpense;
  final CitRenovationSchedule renovation;
  final CitRentalSchedule rental;

  const CitSchedules({
    required this.capitalAllowance,
    required this.medicalExpense,
    required this.renovation,
    required this.rental,
  });

  factory CitSchedules.fromJson(Map<String, dynamic> json) =>
      _$CitSchedulesFromJson(json);

  Map<String, dynamic> toJson() => _$CitSchedulesToJson(this);
}

/// Capital Allowance Schedule
@JsonSerializable()
class CitCapitalAllowanceSchedule {
  final List<CitCapitalAllowanceItem> items;
  final double totalCapitalAllowance;

  const CitCapitalAllowanceSchedule({
    required this.items,
    required this.totalCapitalAllowance,
  });

  factory CitCapitalAllowanceSchedule.fromJson(Map<String, dynamic> json) =>
      _$CitCapitalAllowanceScheduleFromJson(json);

  Map<String, dynamic> toJson() => _$CitCapitalAllowanceScheduleToJson(this);
}

@JsonSerializable()
class CitCapitalAllowanceItem {
  final String assetDescription;
  final String assetType;
  final double cost;
  final double accumulatedAllowance;
  final double currentYearAllowance;

  const CitCapitalAllowanceItem({
    required this.assetDescription,
    required this.assetType,
    required this.cost,
    required this.accumulatedAllowance,
    required this.currentYearAllowance,
  });

  factory CitCapitalAllowanceItem.fromJson(Map<String, dynamic> json) =>
      _$CitCapitalAllowanceItemFromJson(json);

  Map<String, dynamic> toJson() => _$CitCapitalAllowanceItemToJson(this);
}

/// Medical Expense Schedule
@JsonSerializable()
class CitMedicalExpenseSchedule {
  final List<CitMedicalExpenseItem> items;
  final double totalMedicalExpense;

  const CitMedicalExpenseSchedule({
    required this.items,
    required this.totalMedicalExpense,
  });

  factory CitMedicalExpenseSchedule.fromJson(Map<String, dynamic> json) =>
      _$CitMedicalExpenseScheduleFromJson(json);

  Map<String, dynamic> toJson() => _$CitMedicalExpenseScheduleToJson(this);
}

@JsonSerializable()
class CitMedicalExpenseItem {
  final String description;
  final double amount;
  final String category;

  const CitMedicalExpenseItem({
    required this.description,
    required this.amount,
    required this.category,
  });

  factory CitMedicalExpenseItem.fromJson(Map<String, dynamic> json) =>
      _$CitMedicalExpenseItemFromJson(json);

  Map<String, dynamic> toJson() => _$CitMedicalExpenseItemToJson(this);
}

/// Renovation Schedule
@JsonSerializable()
class CitRenovationSchedule {
  final List<CitRenovationItem> items;
  final double totalRenovationExpense;

  const CitRenovationSchedule({
    required this.items,
    required this.totalRenovationExpense,
  });

  factory CitRenovationSchedule.fromJson(Map<String, dynamic> json) =>
      _$CitRenovationScheduleFromJson(json);

  Map<String, dynamic> toJson() => _$CitRenovationScheduleToJson(this);
}

@JsonSerializable()
class CitRenovationItem {
  final String description;
  final double amount;
  final String renovationType;
  final String completionDate;

  const CitRenovationItem({
    required this.description,
    required this.amount,
    required this.renovationType,
    required this.completionDate,
  });

  factory CitRenovationItem.fromJson(Map<String, dynamic> json) =>
      _$CitRenovationItemFromJson(json);

  Map<String, dynamic> toJson() => _$CitRenovationItemToJson(this);
}

/// Rental Schedule
@JsonSerializable()
class CitRentalSchedule {
  final List<CitRentalItem> items;
  final double totalRentalIncome;

  const CitRentalSchedule({
    required this.items,
    required this.totalRentalIncome,
  });

  factory CitRentalSchedule.fromJson(Map<String, dynamic> json) =>
      _$CitRentalScheduleFromJson(json);

  Map<String, dynamic> toJson() => _$CitRentalScheduleToJson(this);
}

@JsonSerializable()
class CitRentalItem {
  final String propertyAddress;
  final double rentalIncome;
  final double allowableExpenses;
  final double netRentalIncome;

  const CitRentalItem({
    required this.propertyAddress,
    required this.rentalIncome,
    required this.allowableExpenses,
    required this.netRentalIncome,
  });

  factory CitRentalItem.fromJson(Map<String, dynamic> json) =>
      _$CitRentalItemFromJson(json);

  Map<String, dynamic> toJson() => _$CitRentalItemToJson(this);
}

/// Common API info structure for CIT
@JsonSerializable()
class CitApiInfo {
  final int messageCode;
  final String message;
  final List<CitFieldInfo>? fieldInfoList;

  const CitApiInfo({
    required this.messageCode,
    required this.message,
    this.fieldInfoList,
  });

  factory CitApiInfo.fromJson(Map<String, dynamic> json) =>
      _$CitApiInfoFromJson(json);

  Map<String, dynamic> toJson() => _$CitApiInfoToJson(this);
}

@JsonSerializable()
class CitFieldInfo {
  final String field;
  final String message;

  const CitFieldInfo({
    required this.field,
    required this.message,
  });

  factory CitFieldInfo.fromJson(Map<String, dynamic> json) =>
      _$CitFieldInfoFromJson(json);

  Map<String, dynamic> toJson() => _$CitFieldInfoToJson(this);
}