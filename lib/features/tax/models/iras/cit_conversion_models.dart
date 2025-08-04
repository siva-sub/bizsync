import 'package:json_annotation/json_annotation.dart';

part 'cit_conversion_models.g.dart';

/// CIT Conversion API models based on CIT_Conversion-1.0.8.yaml
/// This implements the exact structure from the IRAS API specification

/// Main CIT Conversion Request
@JsonSerializable()
class CitConversionRequest {
  final CitDeclaration declaration;
  @JsonKey(name: 'ClientID')
  final String clientID;
  final CitFilingInfo filingInfo;
  final CitData data;
  final List<CitAsset>? nonHPCompCommEquipment;
  final List<CitAsset>? nonHpOtherPPE;
  final List<CitAsset>? nonHpOtherPPE_LowValueAsset;
  final List<CitHpAsset>? hpOtherPPE;

  const CitConversionRequest({
    required this.declaration,
    required this.clientID,
    required this.filingInfo,
    required this.data,
    this.nonHPCompCommEquipment,
    this.nonHpOtherPPE,
    this.nonHpOtherPPE_LowValueAsset,
    this.hpOtherPPE,
  });

  factory CitConversionRequest.fromJson(Map<String, dynamic> json) =>
      _$CitConversionRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CitConversionRequestToJson(this);
}

/// Declaration section
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

/// Filing Information
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

/// Main financial data section - matches YAML specification exactly
@JsonSerializable()
class CitData {
  // Revenue and Income
  final String totalRevenue;
  final String sgIntDisc;
  final String oneTierTaxDividendIncome;
  final String c1_GrossRent;
  final String sgOtherI;
  final String otherNonTaxableIncome;
  final String totalOtherIncome;

  // Cost of goods sold
  final String costOfGoodsSold;

  // Operating Expenses
  final String bankCharges;
  final String commissionOther;
  final String depreciationExpense;
  final String directorsFees;
  final String directorsRemunerationExcludingDirectorsFees;
  final String donations;
  final String cpfContribution;
  final String c1_EntertainExp;

  // Rental Income Expenses
  final String commissionExpRentalIncome;
  final String insuranceExpRentalIncome;
  final String interestExpRentalIncome;
  final String propertyTaxExpRentalIncome;
  final String repairMaintenanceExpRentalIncome;
  final String otherExpRentalIncome;

  // Other Expenses
  final String fixedAssetsExpdOff;
  final String amortisationExpense;
  final String insuranceExpOther;
  final String interestExpOther;
  final String impairmentLossReversalOfImpairmentLossForBadDebts;
  final String medicalExpIncludingMedicalInsurance;
  final String netGainsOrLossesOnDisposalOfPPE;
  final String netGainsOrLossesOnForex;
  final String netGainsOrLossesOnOtherItems;
  final String miscExp;
  final String otherPrivateOrCapitalExp;
  final String otherFinanceCost;
  final String penaltiesOrFine;
  final String professionalFees;
  final String propertyTaxOther;
  final String rentExp;
  final String
      repairMaintenanceExcludingUpkeepOfPrivateVehiclesAndExpRentalIncome;
  final String repairsMaintenanceForPrivateVehicles;
  final String salesAndMarketingExpense;
  final String skillsDevelopmentForeignWorkerLevy;
  final String staffRemunerationOtherThanDirectorsRemuneration;
  final String staffWelfare;
  final String telecommunicationOrUtilities;
  final String training;
  final String c1_TransportExp;
  final String upkeepNonPrivateVehicles;
  final String upkeepPrivateVehicles;

  // Profit/Loss
  final String profitLossBeforeTaxation;

  // Deductions and Adjustments
  final String c1_FurtherDed;
  final String unutilCABFNorm;
  final String unutilLossBFNorm;
  final String unutilDonationBFNorm;
  final String cyDonation;
  final String fullTxX;
  final String uCALDChangePrinAct;
  final String sholderChange;
  final String unutilCALDClaimS23S37;

  // R&D Expenses
  final String expRD;
  final String expRDSG;
  final String enhanceDeductRD;
  final String furtherDeductRD;

  // Balance Sheet Items
  final String tradeReceivables;
  final String inventories;

  // Renovation and Improvements
  final String theLeaseholdImprovementsAndRenoCostDoNotRequireTheApprovalOfCOBC;
  final String firstYAInWhichS14QDeductionClaimed;
  final String leaseholdImprovementsAndRenoCostIncurredInYAMinus4;
  final String leaseholdImprovementsAndRenoCostIncurredInYAMinus3;
  final String leaseholdImprovementsAndRenoCostIncurredInYAMinus2;
  final String leaseholdImprovementsAndRenoCostIncurredInYAMinus1;
  final String leaseholdImprovementsAndRenoCostIncurredInCurrentYA;

  // Prior year data
  final String iaAaPriorSeamlessFiling;
  final String baPriorSeamlessFiling;
  final String bcPriorSeamlessFiling;
  final String appStockConvAsset;

  // Enhanced Investment Scheme
  final String enhancedEISCA;
  final String c1_EnhancedEISDed;
  final String eis_AcqIPRDedAll;
  final String eis_AcqIPRTotCost;
  final String eis_ClaimCashPayout;
  final String eis_ClaimDedAll;
  final String eis_InnoProjDedAll;
  final String eis_InnoProjTotCost;
  final String eis_LicensIPRDedAll;
  final String eis_LicensIPRTotCost;
  final String eis_RDSgDedAll;
  final String eis_RDSgTotCost;
  final String eis_RegIPDedAll;
  final String eis_RegIPTotCost;
  final String eis_TrainDedAll;
  final String eis_TrainTotCost;

  // Foreign source income
  final String ptisDonInd;
  final String foreignSourceSaleNotTax;
  final String foreignAssetsSaleGainLoss;
  final String foreignSourceSaleGainsRemit;

  const CitData({
    required this.totalRevenue,
    required this.sgIntDisc,
    required this.oneTierTaxDividendIncome,
    required this.c1_GrossRent,
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
    required this.c1_EntertainExp,
    required this.commissionExpRentalIncome,
    required this.insuranceExpRentalIncome,
    required this.interestExpRentalIncome,
    required this.propertyTaxExpRentalIncome,
    required this.repairMaintenanceExpRentalIncome,
    required this.otherExpRentalIncome,
    required this.fixedAssetsExpdOff,
    required this.amortisationExpense,
    required this.insuranceExpOther,
    required this.interestExpOther,
    required this.impairmentLossReversalOfImpairmentLossForBadDebts,
    required this.medicalExpIncludingMedicalInsurance,
    required this.netGainsOrLossesOnDisposalOfPPE,
    required this.netGainsOrLossesOnForex,
    required this.netGainsOrLossesOnOtherItems,
    required this.miscExp,
    required this.otherPrivateOrCapitalExp,
    required this.otherFinanceCost,
    required this.penaltiesOrFine,
    required this.professionalFees,
    required this.propertyTaxOther,
    required this.rentExp,
    required this.repairMaintenanceExcludingUpkeepOfPrivateVehiclesAndExpRentalIncome,
    required this.repairsMaintenanceForPrivateVehicles,
    required this.salesAndMarketingExpense,
    required this.skillsDevelopmentForeignWorkerLevy,
    required this.staffRemunerationOtherThanDirectorsRemuneration,
    required this.staffWelfare,
    required this.telecommunicationOrUtilities,
    required this.training,
    required this.c1_TransportExp,
    required this.upkeepNonPrivateVehicles,
    required this.upkeepPrivateVehicles,
    required this.profitLossBeforeTaxation,
    required this.c1_FurtherDed,
    required this.unutilCABFNorm,
    required this.unutilLossBFNorm,
    required this.unutilDonationBFNorm,
    required this.cyDonation,
    required this.fullTxX,
    required this.uCALDChangePrinAct,
    required this.sholderChange,
    required this.unutilCALDClaimS23S37,
    required this.expRD,
    required this.expRDSG,
    required this.enhanceDeductRD,
    required this.furtherDeductRD,
    required this.tradeReceivables,
    required this.inventories,
    required this.theLeaseholdImprovementsAndRenoCostDoNotRequireTheApprovalOfCOBC,
    required this.firstYAInWhichS14QDeductionClaimed,
    required this.leaseholdImprovementsAndRenoCostIncurredInYAMinus4,
    required this.leaseholdImprovementsAndRenoCostIncurredInYAMinus3,
    required this.leaseholdImprovementsAndRenoCostIncurredInYAMinus2,
    required this.leaseholdImprovementsAndRenoCostIncurredInYAMinus1,
    required this.leaseholdImprovementsAndRenoCostIncurredInCurrentYA,
    required this.iaAaPriorSeamlessFiling,
    required this.baPriorSeamlessFiling,
    required this.bcPriorSeamlessFiling,
    required this.appStockConvAsset,
    required this.enhancedEISCA,
    required this.c1_EnhancedEISDed,
    required this.eis_AcqIPRDedAll,
    required this.eis_AcqIPRTotCost,
    required this.eis_ClaimCashPayout,
    required this.eis_ClaimDedAll,
    required this.eis_InnoProjDedAll,
    required this.eis_InnoProjTotCost,
    required this.eis_LicensIPRDedAll,
    required this.eis_LicensIPRTotCost,
    required this.eis_RDSgDedAll,
    required this.eis_RDSgTotCost,
    required this.eis_RegIPDedAll,
    required this.eis_RegIPTotCost,
    required this.eis_TrainDedAll,
    required this.eis_TrainTotCost,
    required this.ptisDonInd,
    required this.foreignSourceSaleNotTax,
    required this.foreignAssetsSaleGainLoss,
    required this.foreignSourceSaleGainsRemit,
  });

  factory CitData.fromJson(Map<String, dynamic> json) =>
      _$CitDataFromJson(json);

  Map<String, dynamic> toJson() => _$CitDataToJson(this);
}

/// Asset model for non-HP assets
@JsonSerializable()
class CitAsset {
  final String descriptionEachAsset;
  final String yaOfPurchaseEachAsset;
  final String costEachAsset;
  final String? salesProceedEachAsset;
  final String? yaOfDisposalEachAsset;

  const CitAsset({
    required this.descriptionEachAsset,
    required this.yaOfPurchaseEachAsset,
    required this.costEachAsset,
    this.salesProceedEachAsset,
    this.yaOfDisposalEachAsset,
  });

  factory CitAsset.fromJson(Map<String, dynamic> json) =>
      _$CitAssetFromJson(json);

  Map<String, dynamic> toJson() => _$CitAssetToJson(this);
}

/// Hire Purchase asset model
@JsonSerializable()
class CitHpAsset extends CitAsset {
  final String depositOrPrincipalExcludingInterestIncludingDownpaymentEachAsset;
  final String?
      depositOrPrincipalMinus1ExcludingInterestIncludingDownpaymentEachAsset;
  final String?
      depositOrPrincipalMinus2ExcludingInterestIncludingDownpaymentEachAsset;
  final String? totalPrincipalTillDateEachAsset;

  const CitHpAsset({
    required super.descriptionEachAsset,
    required super.yaOfPurchaseEachAsset,
    required super.costEachAsset,
    super.salesProceedEachAsset,
    super.yaOfDisposalEachAsset,
    required this.depositOrPrincipalExcludingInterestIncludingDownpaymentEachAsset,
    this.depositOrPrincipalMinus1ExcludingInterestIncludingDownpaymentEachAsset,
    this.depositOrPrincipalMinus2ExcludingInterestIncludingDownpaymentEachAsset,
    this.totalPrincipalTillDateEachAsset,
  });

  factory CitHpAsset.fromJson(Map<String, dynamic> json) =>
      _$CitHpAssetFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$CitHpAssetToJson(this);
}

/// CIT Conversion Response model
@JsonSerializable()
class CitConversionResponse {
  final int returnCode;
  final CitResponseData? data;
  final CitResponseInfo? info;

  const CitConversionResponse({
    required this.returnCode,
    this.data,
    this.info,
  });

  /// Check if the response indicates success
  bool get isSuccess => returnCode == 10 || returnCode == 30;

  factory CitConversionResponse.fromJson(Map<String, dynamic> json) =>
      _$CitConversionResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CitConversionResponseToJson(this);
}

/// Response data containing all generated documents
@JsonSerializable()
class CitResponseData {
  @JsonKey(name: 'DataDtlPNL')
  final Map<String, dynamic>? dataDtlPNL;
  @JsonKey(name: 'DataMedExpSch')
  final Map<String, dynamic>? dataMedExpSch;
  @JsonKey(name: 'DataRentalSch')
  final Map<String, dynamic>? dataRentalSch;
  @JsonKey(name: 'DataCASch')
  final Map<String, dynamic>? dataCASch;
  @JsonKey(name: 'DataRRSch')
  final Map<String, dynamic>? dataRRSch;
  @JsonKey(name: 'DataTCSch')
  final Map<String, dynamic>? dataTCSch;
  @JsonKey(name: 'DataFormCS')
  final Map<String, dynamic>? dataFormCS;

  const CitResponseData({
    this.dataDtlPNL,
    this.dataMedExpSch,
    this.dataRentalSch,
    this.dataCASch,
    this.dataRRSch,
    this.dataTCSch,
    this.dataFormCS,
  });

  factory CitResponseData.fromJson(Map<String, dynamic> json) =>
      _$CitResponseDataFromJson(json);

  Map<String, dynamic> toJson() => _$CitResponseDataToJson(this);
}

/// Response information for errors
@JsonSerializable()
class CitResponseInfo {
  final String? message;
  final String? messageCode;
  final List<CitFieldInfo>? fieldInfoList;

  const CitResponseInfo({
    this.message,
    this.messageCode,
    this.fieldInfoList,
  });

  factory CitResponseInfo.fromJson(Map<String, dynamic> json) =>
      _$CitResponseInfoFromJson(json);

  Map<String, dynamic> toJson() => _$CitResponseInfoToJson(this);
}

/// Field-level error information
@JsonSerializable()
class CitFieldInfo {
  final String? field;
  final String? message;
  @JsonKey(name: 'RecordID')
  final int? recordID;

  const CitFieldInfo({
    this.field,
    this.message,
    this.recordID,
  });

  factory CitFieldInfo.fromJson(Map<String, dynamic> json) =>
      _$CitFieldInfoFromJson(json);

  Map<String, dynamic> toJson() => _$CitFieldInfoToJson(this);
}

/// Factory method to create sample request matching YAML example
CitConversionRequest createSampleCitRequest() {
  return CitConversionRequest(
    declaration: const CitDeclaration(
      isQualifiedToUseConvFormCS: 'false',
    ),
    clientID: '123456',
    filingInfo: const CitFilingInfo(ya: '2019'),
    data: const CitData(
      totalRevenue: '300000',
      sgIntDisc: '1000',
      oneTierTaxDividendIncome: '20000',
      c1_GrossRent: '50000',
      sgOtherI: '2000',
      otherNonTaxableIncome: '3000',
      totalOtherIncome: '76000',
      costOfGoodsSold: '49000',
      bankCharges: '1000',
      commissionOther: '1000',
      depreciationExpense: '1000',
      directorsFees: '1000',
      directorsRemunerationExcludingDirectorsFees: '50000',
      donations: '500',
      cpfContribution: '1000',
      c1_EntertainExp: '1000',
      commissionExpRentalIncome: '1000',
      insuranceExpRentalIncome: '1000',
      interestExpRentalIncome: '1000',
      propertyTaxExpRentalIncome: '1000',
      repairMaintenanceExpRentalIncome: '1000',
      otherExpRentalIncome: '1000',
      fixedAssetsExpdOff: '1000',
      amortisationExpense: '1000',
      insuranceExpOther: '1000',
      interestExpOther: '1000',
      impairmentLossReversalOfImpairmentLossForBadDebts: '1000',
      medicalExpIncludingMedicalInsurance: '150',
      netGainsOrLossesOnDisposalOfPPE: '200',
      netGainsOrLossesOnForex: '400',
      netGainsOrLossesOnOtherItems: '-100',
      miscExp: '1000',
      otherPrivateOrCapitalExp: '6000',
      otherFinanceCost: '1000',
      penaltiesOrFine: '700',
      professionalFees: '1000',
      propertyTaxOther: '1000',
      rentExp: '1000',
      repairMaintenanceExcludingUpkeepOfPrivateVehiclesAndExpRentalIncome:
          '1000',
      repairsMaintenanceForPrivateVehicles: '2000',
      salesAndMarketingExpense: '1000',
      skillsDevelopmentForeignWorkerLevy: '1000',
      staffRemunerationOtherThanDirectorsRemuneration: '1000',
      staffWelfare: '1000',
      telecommunicationOrUtilities: '1000',
      training: '1000',
      c1_TransportExp: '1000',
      upkeepNonPrivateVehicles: '1000',
      upkeepPrivateVehicles: '5000',
      profitLossBeforeTaxation: '231150',
      c1_FurtherDed: '400',
      unutilCABFNorm: '10000',
      unutilLossBFNorm: '5000',
      unutilDonationBFNorm: '2000',
      cyDonation: '1250',
      fullTxX: '1',
      uCALDChangePrinAct: '2',
      sholderChange: '2',
      unutilCALDClaimS23S37: '0',
      expRD: '0',
      expRDSG: '0',
      enhanceDeductRD: '0',
      furtherDeductRD: '0',
      tradeReceivables: '55000',
      inventories: '60000',
      theLeaseholdImprovementsAndRenoCostDoNotRequireTheApprovalOfCOBC: '2',
      firstYAInWhichS14QDeductionClaimed: '2017',
      leaseholdImprovementsAndRenoCostIncurredInYAMinus4: '0',
      leaseholdImprovementsAndRenoCostIncurredInYAMinus3: '0',
      leaseholdImprovementsAndRenoCostIncurredInYAMinus2: '90000',
      leaseholdImprovementsAndRenoCostIncurredInYAMinus1: '30000',
      leaseholdImprovementsAndRenoCostIncurredInCurrentYA: '90000',
      iaAaPriorSeamlessFiling: '0',
      baPriorSeamlessFiling: '0',
      bcPriorSeamlessFiling: '0',
      appStockConvAsset: '2',
      enhancedEISCA: '0',
      c1_EnhancedEISDed: '0',
      eis_AcqIPRDedAll: '0',
      eis_AcqIPRTotCost: '0',
      eis_ClaimCashPayout: '0',
      eis_ClaimDedAll: '0',
      eis_InnoProjDedAll: '0',
      eis_InnoProjTotCost: '0',
      eis_LicensIPRDedAll: '0',
      eis_LicensIPRTotCost: '0',
      eis_RDSgDedAll: '0',
      eis_RDSgTotCost: '0',
      eis_RegIPDedAll: '0',
      eis_RegIPTotCost: '0',
      eis_TrainDedAll: '0',
      eis_TrainTotCost: '0',
      ptisDonInd: '0',
      foreignSourceSaleNotTax: '0',
      foreignAssetsSaleGainLoss: '0',
      foreignSourceSaleGainsRemit: '0',
    ),
    nonHPCompCommEquipment: [
      const CitAsset(
        descriptionEachAsset: 'Computer',
        yaOfPurchaseEachAsset: '2019',
        costEachAsset: '12000',
        salesProceedEachAsset: '',
        yaOfDisposalEachAsset: '',
      ),
    ],
  );
}
