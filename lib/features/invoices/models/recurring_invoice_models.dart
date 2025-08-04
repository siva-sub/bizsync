import 'package:json_annotation/json_annotation.dart';
import 'enhanced_invoice.dart';

part 'recurring_invoice_models.g.dart';

/// Recurring patterns for invoice generation
enum RecurringPattern {
  weekly,
  biweekly,
  monthly,
  quarterly,
  halfYearly,
  yearly,
  custom,
}

/// Recurring invoice template and configuration
@JsonSerializable()
class RecurringInvoiceTemplate {
  final String id;
  final String templateName;
  final String customerId;
  final String customerName;
  final RecurringPattern pattern;
  final int interval; // For custom patterns (e.g., every N days)
  final DateTime startDate;
  final DateTime? endDate;
  final int? maxOccurrences;
  final bool isActive;
  final EnhancedInvoice invoiceTemplate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? nextGenerationDate;
  final int generatedCount;
  final List<String> generatedInvoiceIds;

  const RecurringInvoiceTemplate({
    required this.id,
    required this.templateName,
    required this.customerId,
    required this.customerName,
    required this.pattern,
    this.interval = 1,
    required this.startDate,
    this.endDate,
    this.maxOccurrences,
    this.isActive = true,
    required this.invoiceTemplate,
    required this.createdAt,
    required this.updatedAt,
    this.nextGenerationDate,
    this.generatedCount = 0,
    this.generatedInvoiceIds = const [],
  });

  factory RecurringInvoiceTemplate.fromJson(Map<String, dynamic> json) =>
      _$RecurringInvoiceTemplateFromJson(json);

  Map<String, dynamic> toJson() => _$RecurringInvoiceTemplateToJson(this);

  RecurringInvoiceTemplate copyWith({
    String? id,
    String? templateName,
    String? customerId,
    String? customerName,
    RecurringPattern? pattern,
    int? interval,
    DateTime? startDate,
    DateTime? endDate,
    int? maxOccurrences,
    bool? isActive,
    EnhancedInvoice? invoiceTemplate,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? nextGenerationDate,
    int? generatedCount,
    List<String>? generatedInvoiceIds,
  }) {
    return RecurringInvoiceTemplate(
      id: id ?? this.id,
      templateName: templateName ?? this.templateName,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      pattern: pattern ?? this.pattern,
      interval: interval ?? this.interval,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      maxOccurrences: maxOccurrences ?? this.maxOccurrences,
      isActive: isActive ?? this.isActive,
      invoiceTemplate: invoiceTemplate ?? this.invoiceTemplate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      nextGenerationDate: nextGenerationDate ?? this.nextGenerationDate,
      generatedCount: generatedCount ?? this.generatedCount,
      generatedInvoiceIds: generatedInvoiceIds ?? this.generatedInvoiceIds,
    );
  }

  /// Calculate the next generation date based on pattern
  DateTime calculateNextGenerationDate() {
    final baseDate = nextGenerationDate ?? startDate;
    
    switch (pattern) {
      case RecurringPattern.weekly:
        return baseDate.add(Duration(days: 7 * interval));
      case RecurringPattern.biweekly:
        return baseDate.add(Duration(days: 14 * interval));
      case RecurringPattern.monthly:
        return DateTime(baseDate.year, baseDate.month + interval, baseDate.day);
      case RecurringPattern.quarterly:
        return DateTime(baseDate.year, baseDate.month + (3 * interval), baseDate.day);
      case RecurringPattern.halfYearly:
        return DateTime(baseDate.year, baseDate.month + (6 * interval), baseDate.day);
      case RecurringPattern.yearly:
        return DateTime(baseDate.year + interval, baseDate.month, baseDate.day);
      case RecurringPattern.custom:
        return baseDate.add(Duration(days: interval));
    }
  }

  /// Check if this template should generate a new invoice
  bool shouldGenerateInvoice() {
    if (!isActive) return false;
    
    final now = DateTime.now();
    final nextDate = nextGenerationDate ?? startDate;
    
    // Check if it's time to generate
    if (now.isBefore(nextDate)) return false;
    
    // Check if we've reached the end date
    if (endDate != null && now.isAfter(endDate!)) return false;
    
    // Check if we've reached max occurrences
    if (maxOccurrences != null && generatedCount >= maxOccurrences!) return false;
    
    return true;
  }

  /// Get a human-readable description of the recurring pattern
  String getPatternDescription() {
    switch (pattern) {
      case RecurringPattern.weekly:
        return interval == 1 ? 'Weekly' : 'Every $interval weeks';
      case RecurringPattern.biweekly:
        return interval == 1 ? 'Bi-weekly' : 'Every ${interval * 2} weeks';
      case RecurringPattern.monthly:
        return interval == 1 ? 'Monthly' : 'Every $interval months';
      case RecurringPattern.quarterly:
        return interval == 1 ? 'Quarterly' : 'Every ${interval * 3} months';
      case RecurringPattern.halfYearly:
        return interval == 1 ? 'Half-yearly' : 'Every ${interval * 6} months';
      case RecurringPattern.yearly:
        return interval == 1 ? 'Yearly' : 'Every $interval years';
      case RecurringPattern.custom:
        return 'Every $interval days';
    }
  }
}

/// Recurring invoice generation result
@JsonSerializable()
class RecurringInvoiceGenerationResult {
  final bool success;
  final List<String> generatedInvoiceIds;
  final List<String> errors;
  final DateTime generatedAt;

  const RecurringInvoiceGenerationResult({
    required this.success,
    required this.generatedInvoiceIds,
    required this.errors,
    required this.generatedAt,
  });

  factory RecurringInvoiceGenerationResult.fromJson(Map<String, dynamic> json) =>
      _$RecurringInvoiceGenerationResultFromJson(json);

  Map<String, dynamic> toJson() => _$RecurringInvoiceGenerationResultToJson(this);
}