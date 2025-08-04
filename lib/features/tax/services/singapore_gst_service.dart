import 'dart:math' as math;

/// Singapore GST calculation service with real 2024 rates and regulations
class SingaporeGstService {
  // Current GST rate as of 2024
  static const double currentGstRate = 0.09; // 9%
  static final DateTime gst9PercentEffectiveDate = DateTime(2023, 1, 1);
  static final DateTime gst8PercentEffectiveDate = DateTime(2022, 1, 1);
  static final DateTime gst7PercentEffectiveDate = DateTime(2016, 1, 1);

  /// Calculate GST for a given amount based on the calculation date
  static GstCalculationResult calculateGst({
    required double amount,
    required DateTime calculationDate,
    required GstTaxCategory taxCategory,
    required bool isGstRegistered,
    required bool customerIsGstRegistered,
    bool isExport = false,
    String? customerCountry,
  }) {
    // If company is not GST registered, no GST is charged
    if (!isGstRegistered) {
      return GstCalculationResult(
        netAmount: amount,
        gstRate: 0.0,
        gstAmount: 0.0,
        totalAmount: amount,
        taxCategory: taxCategory,
        reasoning: 'Company not GST registered',
        isGstApplicable: false,
      );
    }

    // Get the applicable GST rate for the calculation date
    final gstRate = _getGstRateForDate(calculationDate);

    // Determine if GST should be applied based on category and circumstances
    final gstApplicable = _isGstApplicable(
      taxCategory: taxCategory,
      isExport: isExport,
      customerCountry: customerCountry,
      customerIsGstRegistered: customerIsGstRegistered,
    );

    if (!gstApplicable.applicable) {
      return GstCalculationResult(
        netAmount: amount,
        gstRate: 0.0,
        gstAmount: 0.0,
        totalAmount: amount,
        taxCategory: taxCategory,
        reasoning: gstApplicable.reason,
        isGstApplicable: false,
      );
    }

    // Calculate GST amount
    double effectiveRate = gstRate;
    if (taxCategory == GstTaxCategory.reducedRate) {
      effectiveRate = 0.0; // Some specific items may have reduced rates
    }

    final gstAmount = amount * effectiveRate;
    final totalAmount = amount + gstAmount;

    return GstCalculationResult(
      netAmount: amount,
      gstRate: effectiveRate,
      gstAmount: gstAmount,
      totalAmount: totalAmount,
      taxCategory: taxCategory,
      reasoning:
          'Standard GST applied at ${(effectiveRate * 100).toStringAsFixed(1)}%',
      isGstApplicable: true,
    );
  }

  /// Calculate GST when the total amount is tax-inclusive
  static GstCalculationResult calculateGstInclusive({
    required double totalAmount,
    required DateTime calculationDate,
    required GstTaxCategory taxCategory,
    required bool isGstRegistered,
    required bool customerIsGstRegistered,
    bool isExport = false,
    String? customerCountry,
  }) {
    if (!isGstRegistered) {
      return GstCalculationResult(
        netAmount: totalAmount,
        gstRate: 0.0,
        gstAmount: 0.0,
        totalAmount: totalAmount,
        taxCategory: taxCategory,
        reasoning: 'Company not GST registered',
        isGstApplicable: false,
      );
    }

    final gstRate = _getGstRateForDate(calculationDate);
    final gstApplicable = _isGstApplicable(
      taxCategory: taxCategory,
      isExport: isExport,
      customerCountry: customerCountry,
      customerIsGstRegistered: customerIsGstRegistered,
    );

    if (!gstApplicable.applicable) {
      return GstCalculationResult(
        netAmount: totalAmount,
        gstRate: 0.0,
        gstAmount: 0.0,
        totalAmount: totalAmount,
        taxCategory: taxCategory,
        reasoning: gstApplicable.reason,
        isGstApplicable: false,
      );
    }

    double effectiveRate = gstRate;
    if (taxCategory == GstTaxCategory.reducedRate) {
      effectiveRate = 0.0;
    }

    // Calculate net amount when GST is included in the total
    final netAmount = totalAmount / (1 + effectiveRate);
    final gstAmount = totalAmount - netAmount;

    return GstCalculationResult(
      netAmount: netAmount,
      gstRate: effectiveRate,
      gstAmount: gstAmount,
      totalAmount: totalAmount,
      taxCategory: taxCategory,
      reasoning:
          'GST inclusive calculation at ${(effectiveRate * 100).toStringAsFixed(1)}%',
      isGstApplicable: true,
    );
  }

  /// Get historical GST rate for a specific date
  static double _getGstRateForDate(DateTime date) {
    if (date.isAfter(gst9PercentEffectiveDate) ||
        date.isAtSameMomentAs(gst9PercentEffectiveDate)) {
      return 0.09; // 9% from 1 Jan 2023
    } else if (date.isAfter(gst8PercentEffectiveDate) ||
        date.isAtSameMomentAs(gst8PercentEffectiveDate)) {
      return 0.08; // 8% from 1 Jan 2022
    } else if (date.isAfter(gst7PercentEffectiveDate) ||
        date.isAtSameMomentAs(gst7PercentEffectiveDate)) {
      return 0.07; // 7% from 1 Jan 2016
    } else {
      return 0.05; // 5% before 2016
    }
  }

  /// Determine if GST is applicable based on various factors
  static _GstApplicabilityResult _isGstApplicable({
    required GstTaxCategory taxCategory,
    required bool isExport,
    required String? customerCountry,
    required bool customerIsGstRegistered,
  }) {
    // Zero-rated supplies (exports)
    if (isExport ||
        (customerCountry != null && customerCountry.toUpperCase() != 'SG')) {
      return _GstApplicabilityResult(
        applicable: false,
        reason: 'Zero-rated export supply - 0% GST',
      );
    }

    // Exempt supplies
    if (taxCategory == GstTaxCategory.exempt) {
      return _GstApplicabilityResult(
        applicable: false,
        reason: 'Exempt supply - no GST applicable',
      );
    }

    // Zero-rated domestic supplies
    if (taxCategory == GstTaxCategory.zeroRated) {
      return _GstApplicabilityResult(
        applicable: false,
        reason: 'Zero-rated supply - 0% GST',
      );
    }

    // Standard rated supplies
    if (taxCategory == GstTaxCategory.standard) {
      return _GstApplicabilityResult(
        applicable: true,
        reason: 'Standard rated supply',
      );
    }

    // Reduced rate (currently not applicable in Singapore)
    if (taxCategory == GstTaxCategory.reducedRate) {
      return _GstApplicabilityResult(
        applicable: false,
        reason: 'Reduced rate supply - 0% GST',
      );
    }

    return _GstApplicabilityResult(
      applicable: true,
      reason: 'Standard GST calculation',
    );
  }

  /// Calculate compound GST (for imported goods)
  static GstCalculationResult calculateImportGst({
    required double cif, // Cost, Insurance, and Freight value
    required double dutyAmount,
    required DateTime calculationDate,
  }) {
    final gstRate = _getGstRateForDate(calculationDate);

    // GST on imports is calculated on CIF + Duty
    final taxableValue = cif + dutyAmount;
    final gstAmount = taxableValue * gstRate;
    final totalCost = cif + dutyAmount + gstAmount;

    return GstCalculationResult(
      netAmount: taxableValue,
      gstRate: gstRate,
      gstAmount: gstAmount,
      totalAmount: totalCost,
      taxCategory: GstTaxCategory.standard,
      reasoning:
          'Import GST calculated on CIF + Duty at ${(gstRate * 100).toStringAsFixed(1)}%',
      isGstApplicable: true,
      additionalInfo: {
        'cif_value': cif,
        'duty_amount': dutyAmount,
        'taxable_value': taxableValue,
      },
    );
  }

  /// Get GST registration threshold and requirements
  static Map<String, dynamic> getGstRegistrationInfo() {
    return {
      'mandatory_threshold': 1000000, // S$1 million annual taxable turnover
      'voluntary_threshold': 0, // Can register voluntarily at any level
      'registration_period': 30, // Must register within 30 days
      'effective_date': 'First day of the month following registration',
      'benefits': [
        'Claim input tax credits',
        'Zero-rate exports',
        'Business credibility',
        'Compliance with regulations',
      ],
      'obligations': [
        'Submit GST returns quarterly or monthly',
        'Maintain proper records',
        'Issue GST-compliant invoices',
        'Pay GST to IRAS on time',
      ],
    };
  }

  /// Validate GST invoice requirements
  static GstInvoiceValidation validateGstInvoice({
    required String invoiceNumber,
    required DateTime invoiceDate,
    required String supplierName,
    required String supplierGstNumber,
    required String customerName,
    required double netAmount,
    required double gstAmount,
    required double totalAmount,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    // Check invoice number format
    if (invoiceNumber.isEmpty) {
      errors.add('Invoice number is required');
    }

    // Check GST number format (should be like 200012345M)
    if (!RegExp(r'^\d{9}[A-Z]$').hasMatch(supplierGstNumber)) {
      errors.add('Invalid GST registration number format');
    }

    // Check amounts consistency
    if ((netAmount + gstAmount - totalAmount).abs() > 0.01) {
      errors.add('Amount calculation inconsistency detected');
    }

    // Check minimum GST invoice amount (S$1,000)
    if (totalAmount >= 1000 && gstAmount == 0) {
      warnings.add('High-value transaction without GST - verify tax category');
    }

    return GstInvoiceValidation(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }
}

/// Represents the result of a GST calculation
class GstCalculationResult {
  final double netAmount;
  final double gstRate;
  final double gstAmount;
  final double totalAmount;
  final GstTaxCategory taxCategory;
  final String reasoning;
  final bool isGstApplicable;
  final Map<String, dynamic>? additionalInfo;

  const GstCalculationResult({
    required this.netAmount,
    required this.gstRate,
    required this.gstAmount,
    required this.totalAmount,
    required this.taxCategory,
    required this.reasoning,
    required this.isGstApplicable,
    this.additionalInfo,
  });

  Map<String, dynamic> toJson() => {
        'net_amount': netAmount,
        'gst_rate': gstRate,
        'gst_amount': gstAmount,
        'total_amount': totalAmount,
        'tax_category': taxCategory.name,
        'reasoning': reasoning,
        'is_gst_applicable': isGstApplicable,
        'additional_info': additionalInfo,
      };

  @override
  String toString() =>
      'GST Calculation: Net: \$${netAmount.toStringAsFixed(2)}, '
      'GST (${(gstRate * 100).toStringAsFixed(1)}%): \$${gstAmount.toStringAsFixed(2)}, '
      'Total: \$${totalAmount.toStringAsFixed(2)}';
}

/// GST tax categories as per Singapore regulations
enum GstTaxCategory {
  standard, // Standard-rated at current GST rate
  zeroRated, // Zero-rated (0% GST but can claim input tax)
  exempt, // Exempt (0% GST and cannot claim input tax)
  reducedRate, // Currently not used in Singapore
}

extension GstTaxCategoryExtension on GstTaxCategory {
  String get displayName {
    switch (this) {
      case GstTaxCategory.standard:
        return 'Standard Rated (9%)';
      case GstTaxCategory.zeroRated:
        return 'Zero-Rated (0%)';
      case GstTaxCategory.exempt:
        return 'Exempt';
      case GstTaxCategory.reducedRate:
        return 'Reduced Rate';
    }
  }

  String get description {
    switch (this) {
      case GstTaxCategory.standard:
        return 'Standard rate applies to most goods and services';
      case GstTaxCategory.zeroRated:
        return 'Exports and specific domestic supplies';
      case GstTaxCategory.exempt:
        return 'Financial services, residential properties, etc.';
      case GstTaxCategory.reducedRate:
        return 'Currently not applicable in Singapore';
    }
  }
}

/// Internal class for GST applicability determination
class _GstApplicabilityResult {
  final bool applicable;
  final String reason;

  const _GstApplicabilityResult({
    required this.applicable,
    required this.reason,
  });
}

/// GST invoice validation result
class GstInvoiceValidation {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const GstInvoiceValidation({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });
}

/// Common GST-exempt categories in Singapore
class SingaporeGstExemptions {
  static const List<String> exemptCategories = [
    'Financial services',
    'Insurance services',
    'Investment precious metals',
    'Residential property sales',
    'Residential property rentals',
    'Digital payment tokens',
    'Education services (approved institutions)',
    'Healthcare services (registered practitioners)',
    'Charity services',
  ];

  static const List<String> zeroRatedCategories = [
    'Exports of goods',
    'International services',
    'International transport',
    'Goods in transit',
    'Investment precious metals (specific conditions)',
    'Medical devices and drugs (specific)',
    'Qualifying ships and aircraft',
  ];

  static bool isCategoryExempt(String category) {
    return exemptCategories
        .any((exempt) => category.toLowerCase().contains(exempt.toLowerCase()));
  }

  static bool isCategoryZeroRated(String category) {
    return zeroRatedCategories.any((zeroRated) =>
        category.toLowerCase().contains(zeroRated.toLowerCase()));
  }
}
