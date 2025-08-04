import 'package:json_annotation/json_annotation.dart';
import '../../invoices/models/enhanced_invoice.dart';

part 'customer_statement_models.g.dart';

/// Customer payment transaction
@JsonSerializable()
class CustomerPayment {
  final String id;
  final String customerId;
  final String invoiceId;
  final String? invoiceNumber;
  final double amount;
  final DateTime paymentDate;
  final PaymentMethod method;
  final String? reference;
  final String? notes;
  final DateTime createdAt;

  const CustomerPayment({
    required this.id,
    required this.customerId,
    required this.invoiceId,
    this.invoiceNumber,
    required this.amount,
    required this.paymentDate,
    required this.method,
    this.reference,
    this.notes,
    required this.createdAt,
  });

  factory CustomerPayment.fromJson(Map<String, dynamic> json) =>
      _$CustomerPaymentFromJson(json);

  Map<String, dynamic> toJson() => _$CustomerPaymentToJson(this);

  CustomerPayment copyWith({
    String? id,
    String? customerId,
    String? invoiceId,
    String? invoiceNumber,
    double? amount,
    DateTime? paymentDate,
    PaymentMethod? method,
    String? reference,
    String? notes,
    DateTime? createdAt,
  }) {
    return CustomerPayment(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      invoiceId: invoiceId ?? this.invoiceId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      method: method ?? this.method,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Payment methods
enum PaymentMethod {
  cash,
  bankTransfer,
  paynow,
  sgqr,
  cheque,
  creditCard,
  debitCard,
  other,
}

/// Customer statement summary
@JsonSerializable()
class CustomerStatementSummary {
  final String customerId;
  final String customerName;
  final DateTime statementDate;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double openingBalance;
  final double totalInvoiced;
  final double totalPaid;
  final double closingBalance;
  final double currentBalance;
  final double overdue30Days;
  final double overdue60Days;
  final double overdue90Days;
  final int totalInvoices;
  final int paidInvoices;
  final int unpaidInvoices;

  const CustomerStatementSummary({
    required this.customerId,
    required this.customerName,
    required this.statementDate,
    required this.periodStart,
    required this.periodEnd,
    required this.openingBalance,
    required this.totalInvoiced,
    required this.totalPaid,
    required this.closingBalance,
    required this.currentBalance,
    required this.overdue30Days,
    required this.overdue60Days,
    required this.overdue90Days,
    required this.totalInvoices,
    required this.paidInvoices,
    required this.unpaidInvoices,
  });

  factory CustomerStatementSummary.fromJson(Map<String, dynamic> json) =>
      _$CustomerStatementSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$CustomerStatementSummaryToJson(this);

  /// Calculate aging analysis
  Map<String, double> get agingAnalysis => {
        'current':
            currentBalance - overdue30Days - overdue60Days - overdue90Days,
        '30_days': overdue30Days,
        '60_days': overdue60Days,
        '90_days': overdue90Days,
      };
}

/// Customer statement transaction entry
@JsonSerializable()
class StatementTransaction {
  final String id;
  final DateTime date;
  final StatementTransactionType type;
  final String description;
  final String? reference;
  final double debit;
  final double credit;
  final double balance;
  final String? invoiceId;
  final String? paymentId;

  const StatementTransaction({
    required this.id,
    required this.date,
    required this.type,
    required this.description,
    this.reference,
    required this.debit,
    required this.credit,
    required this.balance,
    this.invoiceId,
    this.paymentId,
  });

  factory StatementTransaction.fromJson(Map<String, dynamic> json) =>
      _$StatementTransactionFromJson(json);

  Map<String, dynamic> toJson() => _$StatementTransactionToJson(this);

  /// Create transaction from invoice
  factory StatementTransaction.fromInvoice({
    required String id,
    required EnhancedInvoice invoice,
    required double balance,
  }) {
    return StatementTransaction(
      id: id,
      date: invoice.issueDate,
      type: StatementTransactionType.invoice,
      description: 'Invoice ${invoice.invoiceNumber}',
      reference: invoice.invoiceNumber,
      debit: invoice.totalAmount,
      credit: 0.0,
      balance: balance,
      invoiceId: invoice.id,
    );
  }

  /// Create transaction from payment
  factory StatementTransaction.fromPayment({
    required String id,
    required CustomerPayment payment,
    required double balance,
  }) {
    return StatementTransaction(
      id: id,
      date: payment.paymentDate,
      type: StatementTransactionType.payment,
      description:
          'Payment for Invoice ${payment.invoiceNumber ?? payment.invoiceId}',
      reference: payment.reference,
      debit: 0.0,
      credit: payment.amount,
      balance: balance,
      paymentId: payment.id,
    );
  }
}

/// Statement transaction types
enum StatementTransactionType {
  invoice,
  payment,
  creditNote,
  adjustment,
  openingBalance,
}

/// Complete customer statement
@JsonSerializable()
class CustomerStatement {
  final CustomerStatementSummary summary;
  final List<StatementTransaction> transactions;
  final DateTime generatedAt;
  final String generatedBy;

  const CustomerStatement({
    required this.summary,
    required this.transactions,
    required this.generatedAt,
    required this.generatedBy,
  });

  factory CustomerStatement.fromJson(Map<String, dynamic> json) =>
      _$CustomerStatementFromJson(json);

  Map<String, dynamic> toJson() => _$CustomerStatementToJson(this);
}

/// Statement generation options
@JsonSerializable()
class StatementGenerationOptions {
  final DateTime startDate;
  final DateTime endDate;
  final bool includeZeroBalanceCustomers;
  final bool includePaidInvoices;
  final bool groupByInvoice;
  final String currency;
  final StatementFormat format;

  const StatementGenerationOptions({
    required this.startDate,
    required this.endDate,
    this.includeZeroBalanceCustomers = false,
    this.includePaidInvoices = true,
    this.groupByInvoice = false,
    this.currency = 'SGD',
    this.format = StatementFormat.detailed,
  });

  factory StatementGenerationOptions.fromJson(Map<String, dynamic> json) =>
      _$StatementGenerationOptionsFromJson(json);

  Map<String, dynamic> toJson() => _$StatementGenerationOptionsToJson(this);

  /// Generate options for current month
  factory StatementGenerationOptions.currentMonth() {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, 1);
    final endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return StatementGenerationOptions(
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Generate options for last month
  factory StatementGenerationOptions.lastMonth() {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);
    final startDate = DateTime(lastMonth.year, lastMonth.month, 1);
    final endDate = DateTime(now.year, now.month, 0, 23, 59, 59);

    return StatementGenerationOptions(
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Generate options for current quarter
  factory StatementGenerationOptions.currentQuarter() {
    final now = DateTime.now();
    final quarter = ((now.month - 1) ~/ 3) + 1;
    final startMonth = (quarter - 1) * 3 + 1;
    final startDate = DateTime(now.year, startMonth, 1);
    final endDate = DateTime(now.year, startMonth + 3, 0, 23, 59, 59);

    return StatementGenerationOptions(
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Generate options for current year
  factory StatementGenerationOptions.currentYear() {
    final now = DateTime.now();
    final startDate = DateTime(now.year, 1, 1);
    final endDate = DateTime(now.year, 12, 31, 23, 59, 59);

    return StatementGenerationOptions(
      startDate: startDate,
      endDate: endDate,
    );
  }
}

/// Statement format options
enum StatementFormat {
  summary,
  detailed,
  compact,
}

/// Customer balance summary
@JsonSerializable()
class CustomerBalanceSummary {
  final String customerId;
  final String customerName;
  final double currentBalance;
  final double overdueBalance;
  final DateTime lastInvoiceDate;
  final DateTime? lastPaymentDate;
  final int totalInvoices;
  final int unpaidInvoices;
  final double creditLimit;
  final bool isOverLimit;
  final int daysSinceLastPayment;

  const CustomerBalanceSummary({
    required this.customerId,
    required this.customerName,
    required this.currentBalance,
    required this.overdueBalance,
    required this.lastInvoiceDate,
    this.lastPaymentDate,
    required this.totalInvoices,
    required this.unpaidInvoices,
    this.creditLimit = 0.0,
    this.isOverLimit = false,
    this.daysSinceLastPayment = 0,
  });

  factory CustomerBalanceSummary.fromJson(Map<String, dynamic> json) =>
      _$CustomerBalanceSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$CustomerBalanceSummaryToJson(this);

  /// Calculate credit utilization percentage
  double get creditUtilization {
    if (creditLimit <= 0) return 0.0;
    return (currentBalance / creditLimit * 100).clamp(0.0, 100.0);
  }

  /// Check if customer is high risk
  bool get isHighRisk {
    return overdueBalance > 0 || isOverLimit || daysSinceLastPayment > 90;
  }

  /// Get risk level
  CustomerRiskLevel get riskLevel {
    if (isHighRisk) return CustomerRiskLevel.high;
    if (overdueBalance > 0 || daysSinceLastPayment > 60) {
      return CustomerRiskLevel.medium;
    }
    return CustomerRiskLevel.low;
  }
}

/// Customer risk levels
enum CustomerRiskLevel {
  low,
  medium,
  high,
}
