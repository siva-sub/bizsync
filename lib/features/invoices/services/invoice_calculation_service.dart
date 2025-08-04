import 'dart:math';
import '../../../core/database/crdt_database_service.dart';
import '../models/invoice_models.dart';
import '../models/enhanced_invoice_model.dart';

/// Tax calculation result
class TaxCalculationResult {
  final double taxableAmount;
  final double taxAmount;
  final double totalAmount;
  final List<TaxBreakdown> breakdown;

  const TaxCalculationResult({
    required this.taxableAmount,
    required this.taxAmount,
    required this.totalAmount,
    required this.breakdown,
  });

  Map<String, dynamic> toJson() {
    return {
      'taxable_amount': taxableAmount,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'breakdown': breakdown.map((b) => b.toJson()).toList(),
    };
  }
}

/// Tax breakdown for detailed reporting
class TaxBreakdown {
  final String taxName;
  final double rate;
  final double taxableAmount;
  final double taxAmount;
  final TaxCalculationMethod method;

  const TaxBreakdown({
    required this.taxName,
    required this.rate,
    required this.taxableAmount,
    required this.taxAmount,
    required this.method,
  });

  Map<String, dynamic> toJson() {
    return {
      'tax_name': taxName,
      'rate': rate,
      'taxable_amount': taxableAmount,
      'tax_amount': taxAmount,
      'method': method.value,
    };
  }
}

/// Line item calculation result
class LineItemCalculationResult {
  final double subtotal;
  final double discount;
  final double taxableAmount;
  final double taxAmount;
  final double lineTotal;
  final List<TaxBreakdown> taxBreakdown;

  const LineItemCalculationResult({
    required this.subtotal,
    required this.discount,
    required this.taxableAmount,
    required this.taxAmount,
    required this.lineTotal,
    required this.taxBreakdown,
  });

  Map<String, dynamic> toJson() {
    return {
      'subtotal': subtotal,
      'discount': discount,
      'taxable_amount': taxableAmount,
      'tax_amount': taxAmount,
      'line_total': lineTotal,
      'tax_breakdown': taxBreakdown.map((b) => b.toJson()).toList(),
    };
  }
}

/// Invoice calculation result
class InvoiceCalculationResult {
  final bool success;
  final Map<String, dynamic>? data;
  final String? errorMessage;

  const InvoiceCalculationResult({
    required this.success,
    this.data,
    this.errorMessage,
  });

  factory InvoiceCalculationResult.success(Map<String, dynamic> data) {
    return InvoiceCalculationResult(success: true, data: data);
  }

  factory InvoiceCalculationResult.failure(String errorMessage) {
    return InvoiceCalculationResult(success: false, errorMessage: errorMessage);
  }
}

/// Discount calculation methods
enum DiscountType {
  percentage,
  fixedAmount,
  buyXGetY,
  tiered,
}

/// Discount configuration
class DiscountConfig {
  final DiscountType type;
  final double value;
  final Map<String, dynamic>? parameters;

  const DiscountConfig({
    required this.type,
    required this.value,
    this.parameters,
  });
}

/// Tax jurisdiction and rules
class TaxJurisdiction {
  final String code;
  final String name;
  final List<TaxRule> rules;
  final bool isDefault;

  const TaxJurisdiction({
    required this.code,
    required this.name,
    required this.rules,
    this.isDefault = false,
  });
}

/// Tax rule definition
class TaxRule {
  final String name;
  final double rate;
  final TaxCalculationMethod method;
  final List<String>? applicableItemTypes;
  final double? minimumAmount;
  final double? maximumAmount;
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;

  const TaxRule({
    required this.name,
    required this.rate,
    required this.method,
    this.applicableItemTypes,
    this.minimumAmount,
    this.maximumAmount,
    this.effectiveFrom,
    this.effectiveTo,
  });

  bool isApplicable(LineItemType itemType, double amount, DateTime date) {
    // Check item type applicability
    if (applicableItemTypes != null &&
        !applicableItemTypes!.contains(itemType.value)) {
      return false;
    }

    // Check amount range
    if (minimumAmount != null && amount < minimumAmount!) {
      return false;
    }
    if (maximumAmount != null && amount > maximumAmount!) {
      return false;
    }

    // Check date range
    if (effectiveFrom != null && date.isBefore(effectiveFrom!)) {
      return false;
    }
    if (effectiveTo != null && date.isAfter(effectiveTo!)) {
      return false;
    }

    return true;
  }
}

/// Main invoice calculation service
class InvoiceCalculationService {
  final Map<String, TaxJurisdiction> _taxJurisdictions = {};

  InvoiceCalculationService() {
    _initializeDefaultTaxRules();
  }

  /// Calculate totals for an entire invoice
  Future<InvoiceCalculationResult> calculateInvoiceTotals(
      String invoiceId) async {
    try {
      // Get invoice and line items
      final invoice = await _getInvoiceById(invoiceId);
      if (invoice == null) {
        return InvoiceCalculationResult.failure('Invoice not found');
      }

      final lineItems = await _getInvoiceLineItems(invoiceId);

      double subtotal = 0.0;
      double totalDiscount = 0.0;
      double totalTax = 0.0;
      double shippingAmount = invoice.shippingAmount.value;
      final taxBreakdown = <TaxBreakdown>[];

      // Calculate each line item
      for (final item in lineItems) {
        final itemCalc = calculateLineItemTotals(item);

        subtotal += itemCalc.subtotal;
        totalDiscount += itemCalc.discount;
        totalTax += itemCalc.taxAmount;
        taxBreakdown.addAll(itemCalc.taxBreakdown);
      }

      // Apply invoice-level discounts
      final invoiceDiscountAmount = invoice.discountAmount.value;
      if (invoiceDiscountAmount > 0) {
        totalDiscount += invoiceDiscountAmount;
        subtotal -= invoiceDiscountAmount;
      }

      // Calculate tax on shipping if applicable
      final shippingTax = _calculateShippingTax(shippingAmount, invoice);
      if (shippingTax > 0) {
        totalTax += shippingTax;
        taxBreakdown.add(TaxBreakdown(
          taxName: 'Shipping Tax',
          rate: _getShippingTaxRate(invoice),
          taxableAmount: shippingAmount,
          taxAmount: shippingTax,
          method: TaxCalculationMethod.exclusive,
        ));
      }

      final totalAmount = subtotal + totalTax + shippingAmount;

      return InvoiceCalculationResult.success({
        'subtotal': _roundCurrency(subtotal),
        'discount_amount': _roundCurrency(totalDiscount),
        'tax_amount': _roundCurrency(totalTax),
        'shipping_amount': _roundCurrency(shippingAmount),
        'total_amount': _roundCurrency(totalAmount),
        'tax_breakdown': taxBreakdown.map((b) => b.toJson()).toList(),
      });
    } catch (e) {
      return InvoiceCalculationResult.failure(
          'Failed to calculate invoice totals: $e');
    }
  }

  /// Calculate totals for a single line item
  LineItemCalculationResult calculateLineItemTotals(CRDTInvoiceItem item) {
    final quantity = item.quantity.value;
    final unitPrice = item.unitPrice.value;
    final discountValue = item.discount.value;
    final taxRate = item.taxRate.value;
    final taxMethod = item.taxMethod.value;

    // Calculate subtotal
    double subtotal = quantity * unitPrice;

    // Apply discount
    double discountAmount = 0.0;
    if (discountValue > 0) {
      if (discountValue <= 1.0) {
        // Percentage discount
        discountAmount = subtotal * discountValue;
      } else {
        // Fixed amount discount
        discountAmount = min(discountValue, subtotal);
      }
    }

    final discountedAmount = subtotal - discountAmount;

    // Calculate tax
    double taxableAmount = discountedAmount;
    double taxAmount = 0.0;
    final taxBreakdown = <TaxBreakdown>[];

    if (taxRate > 0) {
      switch (taxMethod) {
        case TaxCalculationMethod.exclusive:
          taxAmount = taxableAmount * (taxRate / 100);
          break;
        case TaxCalculationMethod.inclusive:
          // Tax is included in the price
          taxAmount = taxableAmount * (taxRate / (100 + taxRate));
          taxableAmount = discountedAmount - taxAmount;
          break;
        case TaxCalculationMethod.compound:
          // For compound tax, apply each tax rate sequentially
          taxAmount = _calculateCompoundTax(taxableAmount, [taxRate]);
          break;
      }

      taxBreakdown.add(TaxBreakdown(
        taxName: 'Tax',
        rate: taxRate,
        taxableAmount: taxableAmount,
        taxAmount: taxAmount,
        method: taxMethod,
      ));
    }

    final lineTotal = taxMethod == TaxCalculationMethod.inclusive
        ? discountedAmount
        : discountedAmount + taxAmount;

    return LineItemCalculationResult(
      subtotal: _roundCurrency(subtotal),
      discount: _roundCurrency(discountAmount),
      taxableAmount: _roundCurrency(taxableAmount),
      taxAmount: _roundCurrency(taxAmount),
      lineTotal: _roundCurrency(lineTotal),
      taxBreakdown: taxBreakdown,
    );
  }

  /// Calculate tax based on jurisdiction and item type
  TaxCalculationResult calculateTaxForItem({
    required double amount,
    required LineItemType itemType,
    required String jurisdictionCode,
    DateTime? transactionDate,
  }) {
    final jurisdiction = _taxJurisdictions[jurisdictionCode] ??
        _taxJurisdictions.values.firstWhere(
          (j) => j.isDefault,
          orElse: () => _getDefaultTaxJurisdiction(),
        );

    final date = transactionDate ?? DateTime.now();
    final applicableRules = jurisdiction.rules
        .where(
          (rule) => rule.isApplicable(itemType, amount, date),
        )
        .toList();

    if (applicableRules.isEmpty) {
      return TaxCalculationResult(
        taxableAmount: amount,
        taxAmount: 0.0,
        totalAmount: amount,
        breakdown: [],
      );
    }

    double totalTax = 0.0;
    double taxableAmount = amount;
    final breakdown = <TaxBreakdown>[];

    for (final rule in applicableRules) {
      double ruleTaxAmount = 0.0;
      double ruleTaxableAmount = taxableAmount;

      switch (rule.method) {
        case TaxCalculationMethod.exclusive:
          ruleTaxAmount = taxableAmount * (rule.rate / 100);
          break;
        case TaxCalculationMethod.inclusive:
          ruleTaxAmount = taxableAmount * (rule.rate / (100 + rule.rate));
          ruleTaxableAmount = taxableAmount - ruleTaxAmount;
          break;
        case TaxCalculationMethod.compound:
          ruleTaxAmount = taxableAmount * (rule.rate / 100);
          // For compound tax, next tax is calculated on amount + previous tax
          taxableAmount += ruleTaxAmount;
          break;
      }

      totalTax += ruleTaxAmount;
      breakdown.add(TaxBreakdown(
        taxName: rule.name,
        rate: rule.rate,
        taxableAmount: ruleTaxableAmount,
        taxAmount: ruleTaxAmount,
        method: rule.method,
      ));
    }

    return TaxCalculationResult(
      taxableAmount: amount,
      taxAmount: _roundCurrency(totalTax),
      totalAmount: _roundCurrency(amount + totalTax),
      breakdown: breakdown,
    );
  }

  /// Apply discount to amount
  double applyDiscount(double amount, DiscountConfig discount) {
    switch (discount.type) {
      case DiscountType.percentage:
        return amount * (discount.value / 100);

      case DiscountType.fixedAmount:
        return min(discount.value, amount);

      case DiscountType.buyXGetY:
        final buyQuantity = discount.parameters?['buy_quantity'] ?? 1;
        final getQuantity = discount.parameters?['get_quantity'] ?? 1;
        final itemQuantity = discount.parameters?['item_quantity'] ?? 1;
        final unitPrice = discount.parameters?['unit_price'] ?? amount;

        final freeItems = (itemQuantity / buyQuantity).floor() * getQuantity;
        return freeItems * unitPrice;

      case DiscountType.tiered:
        final tiers =
            discount.parameters?['tiers'] as List<Map<String, dynamic>>? ?? [];
        for (final tier in tiers) {
          final threshold = tier['threshold'] as double;
          final discountRate = tier['discount_rate'] as double;

          if (amount >= threshold) {
            return amount * (discountRate / 100);
          }
        }
        return 0.0;
    }
  }

  /// Calculate payment allocation across line items
  Map<String, double> allocatePayment(
    double paymentAmount,
    List<CRDTInvoiceItem> lineItems,
  ) {
    final allocation = <String, double>{};
    final totalInvoiceAmount = lineItems.fold(
      0.0,
      (sum, item) => sum + item.lineTotal.value,
    );

    if (totalInvoiceAmount == 0) {
      return allocation;
    }

    for (final item in lineItems) {
      final itemTotal = item.lineTotal.value;
      final proportion = itemTotal / totalInvoiceAmount;
      allocation[item.id] = _roundCurrency(paymentAmount * proportion);
    }

    return allocation;
  }

  /// Calculate early payment discount
  double calculateEarlyPaymentDiscount({
    required double invoiceAmount,
    required DateTime invoiceDate,
    required DateTime paymentDate,
    required Map<String, dynamic> discountTerms,
  }) {
    final discountRate = discountTerms['rate'] as double? ?? 0.0;
    final discountDays = discountTerms['days'] as int? ?? 0;

    if (discountRate == 0 || discountDays == 0) {
      return 0.0;
    }

    final daysDifference = paymentDate.difference(invoiceDate).inDays;

    if (daysDifference <= discountDays) {
      return invoiceAmount * (discountRate / 100);
    }

    return 0.0;
  }

  /// Calculate late payment penalty
  double calculateLatePenalty({
    required double invoiceAmount,
    required DateTime dueDate,
    required DateTime currentDate,
    required Map<String, dynamic> penaltyTerms,
  }) {
    if (currentDate.isBefore(dueDate) ||
        currentDate.isAtSameMomentAs(dueDate)) {
      return 0.0;
    }

    final penaltyRate = penaltyTerms['rate'] as double? ?? 0.0;
    final penaltyType = penaltyTerms['type'] as String? ?? 'percentage';
    final compoundDaily = penaltyTerms['compound_daily'] as bool? ?? false;

    if (penaltyRate == 0) {
      return 0.0;
    }

    final daysLate = currentDate.difference(dueDate).inDays;

    switch (penaltyType) {
      case 'percentage':
        if (compoundDaily) {
          final dailyRate = penaltyRate / 365 / 100;
          return invoiceAmount * (pow(1 + dailyRate, daysLate) - 1);
        } else {
          return invoiceAmount * (penaltyRate / 100);
        }

      case 'fixed':
        return penaltyRate;

      case 'daily':
        return penaltyRate * daysLate;

      default:
        return 0.0;
    }
  }

  /// Validate calculation accuracy
  bool validateCalculationAccuracy(Map<String, dynamic> calculation) {
    final subtotal = calculation['subtotal'] as double? ?? 0.0;
    final taxAmount = calculation['tax_amount'] as double? ?? 0.0;
    final discountAmount = calculation['discount_amount'] as double? ?? 0.0;
    final shippingAmount = calculation['shipping_amount'] as double? ?? 0.0;
    final totalAmount = calculation['total_amount'] as double? ?? 0.0;

    final calculatedTotal =
        subtotal + taxAmount + shippingAmount - discountAmount;
    const tolerance = 0.01; // 1 cent tolerance for rounding

    return (calculatedTotal - totalAmount).abs() < tolerance;
  }

  /// Private helper methods

  void _initializeDefaultTaxRules() {
    // Singapore GST
    _taxJurisdictions['SG'] = TaxJurisdiction(
      code: 'SG',
      name: 'Singapore',
      isDefault: true,
      rules: [
        TaxRule(
          name: 'GST',
          rate: 9.0, // Current GST rate as of 2024
          method: TaxCalculationMethod.exclusive,
          effectiveFrom: DateTime(2024, 1, 1),
        ),
      ],
    );

    // Malaysia SST
    _taxJurisdictions['MY'] = TaxJurisdiction(
      code: 'MY',
      name: 'Malaysia',
      rules: [
        TaxRule(
          name: 'SST',
          rate: 6.0,
          method: TaxCalculationMethod.exclusive,
          applicableItemTypes: ['product'],
        ),
        TaxRule(
          name: 'Service Tax',
          rate: 6.0,
          method: TaxCalculationMethod.exclusive,
          applicableItemTypes: ['service'],
        ),
      ],
    );

    // No tax jurisdiction
    _taxJurisdictions['NONE'] = TaxJurisdiction(
      code: 'NONE',
      name: 'No Tax',
      rules: [],
    );
  }

  TaxJurisdiction _getDefaultTaxJurisdiction() {
    return _taxJurisdictions['SG']!;
  }

  double _calculateCompoundTax(double amount, List<double> taxRates) {
    double currentAmount = amount;
    double totalTax = 0.0;

    for (final rate in taxRates) {
      final tax = currentAmount * (rate / 100);
      totalTax += tax;
      currentAmount += tax; // Compound for next tax calculation
    }

    return totalTax;
  }

  double _calculateShippingTax(
      double shippingAmount, CRDTInvoiceEnhanced invoice) {
    if (shippingAmount == 0) return 0.0;

    // Apply default tax rate to shipping (typically same as goods)
    final defaultTaxRate = _getShippingTaxRate(invoice);
    return shippingAmount * (defaultTaxRate / 100);
  }

  double _getShippingTaxRate(CRDTInvoiceEnhanced invoice) {
    // This would typically look up tax configuration
    // For now, return default GST rate
    return 9.0;
  }

  double _roundCurrency(double amount, {int decimals = 2}) {
    final factor = pow(10, decimals);
    return (amount * factor).round() / factor;
  }

  Future<CRDTInvoiceEnhanced?> _getInvoiceById(String invoiceId) async {
    // TODO: Implement database access - for now return null
    return null;
  }

  Future<List<CRDTInvoiceItem>> _getInvoiceLineItems(String invoiceId) async {
    // This would query the database for line items
    // For now, return empty list
    return [];
  }

  /// Get calculation summary for reporting
  Map<String, dynamic> getCalculationSummary(
      List<CRDTInvoiceEnhanced> invoices) {
    double totalSubtotal = 0.0;
    double totalTax = 0.0;
    double totalDiscount = 0.0;
    double totalShipping = 0.0;
    double totalAmount = 0.0;

    final currencyTotals = <String, Map<String, double>>{};
    final taxBreakdown = <String, double>{};

    for (final invoice in invoices) {
      final currency = invoice.currency.value;

      totalSubtotal += invoice.subtotal.value;
      totalTax += invoice.taxAmount.value;
      totalDiscount += invoice.discountAmount.value;
      totalShipping += invoice.shippingAmount.value;
      totalAmount += invoice.totalAmount.value;

      // Track by currency
      currencyTotals.putIfAbsent(
          currency,
          () => {
                'subtotal': 0.0,
                'tax': 0.0,
                'discount': 0.0,
                'shipping': 0.0,
                'total': 0.0,
              });

      currencyTotals[currency]!['subtotal'] =
          (currencyTotals[currency]!['subtotal']! + invoice.subtotal.value);
      currencyTotals[currency]!['tax'] =
          (currencyTotals[currency]!['tax']! + invoice.taxAmount.value);
      currencyTotals[currency]!['discount'] =
          (currencyTotals[currency]!['discount']! +
              invoice.discountAmount.value);
      currencyTotals[currency]!['shipping'] =
          (currencyTotals[currency]!['shipping']! +
              invoice.shippingAmount.value);
      currencyTotals[currency]!['total'] =
          (currencyTotals[currency]!['total']! + invoice.totalAmount.value);
    }

    return {
      'invoice_count': invoices.length,
      'total_subtotal': _roundCurrency(totalSubtotal),
      'total_tax': _roundCurrency(totalTax),
      'total_discount': _roundCurrency(totalDiscount),
      'total_shipping': _roundCurrency(totalShipping),
      'total_amount': _roundCurrency(totalAmount),
      'average_invoice_value': invoices.isEmpty
          ? 0.0
          : _roundCurrency(totalAmount / invoices.length),
      'currency_breakdown': currencyTotals,
      'tax_breakdown': taxBreakdown,
    };
  }
}
