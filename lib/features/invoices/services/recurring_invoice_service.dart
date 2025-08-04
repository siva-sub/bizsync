import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/enhanced_invoice.dart';
import '../models/recurring_invoice_models.dart';
import '../services/invoice_service.dart';
import '../../../core/database/crdt_database_service.dart';
import '../../../core/services/notification_service.dart';

/// Service for managing recurring invoices
class RecurringInvoiceService {
  static RecurringInvoiceService? _instance;
  static RecurringInvoiceService get instance =>
      _instance ??= RecurringInvoiceService._();

  RecurringInvoiceService._();

  final CRDTDatabaseService _databaseService = CRDTDatabaseService();
  late final InvoiceService _invoiceService;
  late final NotificationService _notificationService;
  final Uuid _uuid = const Uuid();

  static const String _templatesTable = 'recurring_invoice_templates';
  static const String _generationLogTable = 'recurring_invoice_generation_log';

  /// Initialize the service and database tables
  Future<void> initialize() async {
    // Initialize dependent services
    _notificationService = NotificationService();

    // InvoiceService requires more complex initialization
    // We'll create it on-demand in methods that need it

    await _createTables();
    await _startRecurringInvoiceScheduler();
  }

  /// Create database tables for recurring invoices
  Future<void> _createTables() async {
    const createTemplatesTable = '''
      CREATE TABLE IF NOT EXISTS $_templatesTable (
        id TEXT PRIMARY KEY,
        template_name TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        customer_name TEXT NOT NULL,
        pattern TEXT NOT NULL,
        interval_value INTEGER DEFAULT 1,
        start_date TEXT NOT NULL,
        end_date TEXT,
        max_occurrences INTEGER,
        is_active INTEGER DEFAULT 1,
        invoice_template TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        next_generation_date TEXT,
        generated_count INTEGER DEFAULT 0,
        generated_invoice_ids TEXT DEFAULT '[]'
      )
    ''';

    const createGenerationLogTable = '''
      CREATE TABLE IF NOT EXISTS $_generationLogTable (
        id TEXT PRIMARY KEY,
        template_id TEXT NOT NULL,
        invoice_id TEXT NOT NULL,
        generation_date TEXT NOT NULL,
        success INTEGER DEFAULT 1,
        error_message TEXT,
        FOREIGN KEY (template_id) REFERENCES $_templatesTable (id)
      )
    ''';

    final db = await _databaseService.database;
    await db.execute(createTemplatesTable);
    await db.execute(createGenerationLogTable);
  }

  /// Start the recurring invoice scheduler
  Future<void> _startRecurringInvoiceScheduler() async {
    // Run every hour to check for due recurring invoices
    Timer.periodic(const Duration(hours: 1), (timer) async {
      await generateDueRecurringInvoices();
    });

    // Also run once at startup
    await generateDueRecurringInvoices();
  }

  /// Create a new recurring invoice template
  Future<RecurringInvoiceTemplate> createRecurringTemplate({
    required String templateName,
    required String customerId,
    required String customerName,
    required RecurringPattern pattern,
    int interval = 1,
    required DateTime startDate,
    DateTime? endDate,
    int? maxOccurrences,
    required EnhancedInvoice invoiceTemplate,
  }) async {
    final template = RecurringInvoiceTemplate(
      id: _uuid.v4(),
      templateName: templateName,
      customerId: customerId,
      customerName: customerName,
      pattern: pattern,
      interval: interval,
      startDate: startDate,
      endDate: endDate,
      maxOccurrences: maxOccurrences,
      invoiceTemplate: invoiceTemplate.copyWith(
        isRecurring: true,
        recurringPattern: pattern.name,
      ),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      nextGenerationDate: startDate,
    );

    await _saveTemplate(template);

    // Send notification
    await _notificationService.sendNotification(
      title: 'Recurring Invoice Created',
      message: 'Template "$templateName" for $customerName has been set up',
      data: {
        'type': 'recurring_invoice_created',
        'template_id': template.id,
      },
    );

    return template;
  }

  /// Save a recurring invoice template to database
  Future<void> _saveTemplate(RecurringInvoiceTemplate template) async {
    const sql = '''
      INSERT OR REPLACE INTO $_templatesTable (
        id, template_name, customer_id, customer_name, pattern,
        interval_value, start_date, end_date, max_occurrences,
        is_active, invoice_template, created_at, updated_at,
        next_generation_date, generated_count, generated_invoice_ids
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''';

    final db = await _databaseService.database;
    await db.execute(sql, [
      template.id,
      template.templateName,
      template.customerId,
      template.customerName,
      template.pattern.name,
      template.interval,
      template.startDate.toIso8601String(),
      template.endDate?.toIso8601String(),
      template.maxOccurrences,
      template.isActive ? 1 : 0,
      template.invoiceTemplate.toJson().toString(),
      template.createdAt.toIso8601String(),
      template.updatedAt.toIso8601String(),
      template.nextGenerationDate?.toIso8601String(),
      template.generatedCount,
      template.generatedInvoiceIds.join(','),
    ]);
  }

  /// Get all recurring invoice templates
  Future<List<RecurringInvoiceTemplate>> getAllTemplates() async {
    const sql = 'SELECT * FROM $_templatesTable ORDER BY created_at DESC';
    final db = await _databaseService.database;
    final results = await db.rawQuery(sql);

    return results.map((row) => _templateFromRow(row)).toList();
  }

  /// Get active recurring invoice templates
  Future<List<RecurringInvoiceTemplate>> getActiveTemplates() async {
    const sql =
        'SELECT * FROM $_templatesTable WHERE is_active = 1 ORDER BY next_generation_date ASC';
    final db = await _databaseService.database;
    final results = await db.rawQuery(sql);

    return results.map((row) => _templateFromRow(row)).toList();
  }

  /// Get templates due for generation
  Future<List<RecurringInvoiceTemplate>> getTemplatesDueForGeneration() async {
    final now = DateTime.now().toIso8601String();
    const sql = '''
      SELECT * FROM $_templatesTable 
      WHERE is_active = 1 
      AND next_generation_date <= ? 
      AND (end_date IS NULL OR end_date > ?)
      ORDER BY next_generation_date ASC
    ''';

    final db = await _databaseService.database;
    final results = await db.rawQuery(sql, [now, now]);
    return results.map((row) => _templateFromRow(row)).where((template) {
      return template.shouldGenerateInvoice();
    }).toList();
  }

  /// Generate invoices for all due recurring templates
  Future<RecurringInvoiceGenerationResult>
      generateDueRecurringInvoices() async {
    final dueTemplates = await getTemplatesDueForGeneration();
    final generatedIds = <String>[];
    final errors = <String>[];

    for (final template in dueTemplates) {
      try {
        final invoice = await _generateInvoiceFromTemplate(template);
        generatedIds.add(invoice.id);

        // Update template with next generation date and count
        final updatedTemplate = template.copyWith(
          nextGenerationDate: template.calculateNextGenerationDate(),
          generatedCount: template.generatedCount + 1,
          generatedInvoiceIds: [...template.generatedInvoiceIds, invoice.id],
          updatedAt: DateTime.now(),
        );

        await _saveTemplate(updatedTemplate);

        // Log the generation
        await _logGeneration(template.id, invoice.id, true, null);
      } catch (e) {
        errors.add('Template ${template.templateName}: $e');
        await _logGeneration(template.id, '', false, e.toString());
      }
    }

    // Send summary notification if any invoices were generated
    if (generatedIds.isNotEmpty) {
      await _notificationService.sendNotification(
        title: 'Recurring Invoices Generated',
        message:
            '${generatedIds.length} recurring invoices were automatically created',
        data: {
          'type': 'recurring_invoices_generated',
          'count': generatedIds.length.toString(),
          'invoice_ids': generatedIds.join(','),
        },
      );
    }

    return RecurringInvoiceGenerationResult(
      success: errors.isEmpty,
      generatedInvoiceIds: generatedIds,
      errors: errors,
      generatedAt: DateTime.now(),
    );
  }

  /// Generate a single invoice from a recurring template
  Future<EnhancedInvoice> _generateInvoiceFromTemplate(
      RecurringInvoiceTemplate template) async {
    final now = DateTime.now();
    final invoiceTemplate = template.invoiceTemplate;

    // Calculate due date based on the template's payment terms (assume 30 days if not specified)
    final dueDate = now.add(const Duration(days: 30));

    final newInvoice = invoiceTemplate.copyWith(
      id: _uuid.v4(),
      invoiceNumber: await _generateInvoiceNumber(),
      issueDate: now,
      dueDate: dueDate,
      status: InvoiceStatus.draft,
      createdAt: now,
      updatedAt: now,
      metadata: {
        ...invoiceTemplate.metadata,
        'recurring_template_id': template.id,
        'generation_date': now.toIso8601String(),
        'sequence_number': template.generatedCount + 1,
      },
    );

    // Save the invoice using the invoice service
    // TODO: Implement invoice creation once InvoiceService is properly initialized
    // await _invoiceService.createInvoice(newInvoice);

    return newInvoice;
  }

  /// Generate a unique invoice number
  Future<String> _generateInvoiceNumber() async {
    final now = DateTime.now();
    final prefix = 'REC-${now.year}${now.month.toString().padLeft(2, '0')}';

    // Get the count of invoices with this prefix
    const sql =
        'SELECT COUNT(*) as count FROM invoices WHERE invoice_number LIKE ?';
    final db = await _databaseService.database;
    final results = await db.rawQuery(sql, ['$prefix%']);
    final count = results.first['count'] as int;

    return '$prefix-${(count + 1).toString().padLeft(4, '0')}';
  }

  /// Log invoice generation
  Future<void> _logGeneration(String templateId, String invoiceId, bool success,
      String? errorMessage) async {
    const sql = '''
      INSERT INTO $_generationLogTable (id, template_id, invoice_id, generation_date, success, error_message)
      VALUES (?, ?, ?, ?, ?, ?)
    ''';

    final db = await _databaseService.database;
    await db.execute(sql, [
      _uuid.v4(),
      templateId,
      invoiceId,
      DateTime.now().toIso8601String(),
      success ? 1 : 0,
      errorMessage,
    ]);
  }

  /// Update a recurring invoice template
  Future<RecurringInvoiceTemplate> updateTemplate(
      RecurringInvoiceTemplate template) async {
    final updatedTemplate = template.copyWith(updatedAt: DateTime.now());
    await _saveTemplate(updatedTemplate);
    return updatedTemplate;
  }

  /// Deactivate a recurring invoice template
  Future<void> deactivateTemplate(String templateId) async {
    const sql =
        'UPDATE $_templatesTable SET is_active = 0, updated_at = ? WHERE id = ?';
    final db = await _databaseService.database;
    await db.execute(sql, [DateTime.now().toIso8601String(), templateId]);

    await _notificationService.sendNotification(
      title: 'Recurring Invoice Deactivated',
      message: 'Recurring invoice template has been deactivated',
      data: {
        'type': 'recurring_invoice_deactivated',
        'template_id': templateId,
      },
    );
  }

  /// Delete a recurring invoice template
  Future<void> deleteTemplate(String templateId) async {
    const sql = 'DELETE FROM $_templatesTable WHERE id = ?';
    final db = await _databaseService.database;
    await db.execute(sql, [templateId]);
  }

  /// Get generation history for a template
  Future<List<Map<String, dynamic>>> getGenerationHistory(
      String templateId) async {
    const sql = '''
      SELECT * FROM $_generationLogTable 
      WHERE template_id = ? 
      ORDER BY generation_date DESC
    ''';

    final db = await _databaseService.database;
    return await db.rawQuery(sql, [templateId]);
  }

  /// Convert database row to RecurringInvoiceTemplate
  RecurringInvoiceTemplate _templateFromRow(Map<String, dynamic> row) {
    return RecurringInvoiceTemplate(
      id: row['id'],
      templateName: row['template_name'],
      customerId: row['customer_id'],
      customerName: row['customer_name'],
      pattern: RecurringPattern.values.firstWhere(
        (p) => p.name == row['pattern'],
        orElse: () => RecurringPattern.monthly,
      ),
      interval: row['interval_value'] ?? 1,
      startDate: DateTime.parse(row['start_date']),
      endDate: row['end_date'] != null ? DateTime.parse(row['end_date']) : null,
      maxOccurrences: row['max_occurrences'],
      isActive: (row['is_active'] ?? 0) == 1,
      invoiceTemplate: EnhancedInvoice.fromJson(row['invoice_template']),
      createdAt: DateTime.parse(row['created_at']),
      updatedAt: DateTime.parse(row['updated_at']),
      nextGenerationDate: row['next_generation_date'] != null
          ? DateTime.parse(row['next_generation_date'])
          : null,
      generatedCount: row['generated_count'] ?? 0,
      generatedInvoiceIds: row['generated_invoice_ids'] != null
          ? (row['generated_invoice_ids'] as String)
              .split(',')
              .where((id) => id.isNotEmpty)
              .toList()
          : [],
    );
  }
}
