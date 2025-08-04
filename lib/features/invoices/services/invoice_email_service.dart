import 'dart:io';
import 'dart:typed_data';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/enhanced_invoice.dart';
import '../models/email_models.dart';
import '../../../core/database/crdt_database_service.dart';
import '../../../core/services/notification_service.dart';

/// Service for sending invoice-related emails
class InvoiceEmailService {
  static InvoiceEmailService? _instance;
  static InvoiceEmailService get instance => _instance ??= InvoiceEmailService._();
  
  InvoiceEmailService._();

  final CRDTDatabaseService _databaseService = CRDTDatabaseService();
  final NotificationService _notificationService = NotificationService();
  final Uuid _uuid = const Uuid();

  static const String _configurationsTable = 'email_configurations';
  static const String _templatesTable = 'email_templates';
  static const String _emailLogTable = 'email_log';

  /// Initialize the email service and database tables
  Future<void> initialize() async {
    await _createTables();
    await _createDefaultTemplates();
  }

  /// Create database tables for email functionality
  Future<void> _createTables() async {
    const createConfigurationsTable = '''
      CREATE TABLE IF NOT EXISTS $_configurationsTable (
        id TEXT PRIMARY KEY,
        provider_name TEXT NOT NULL,
        smtp_host TEXT NOT NULL,
        smtp_port INTEGER NOT NULL,
        use_ssl INTEGER DEFAULT 1,
        use_tls INTEGER DEFAULT 0,
        username TEXT NOT NULL,
        password TEXT NOT NULL,
        from_email TEXT NOT NULL,
        from_name TEXT NOT NULL,
        is_default INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''';

    const createTemplatesTable = '''
      CREATE TABLE IF NOT EXISTS $_templatesTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        subject TEXT NOT NULL,
        html_body TEXT NOT NULL,
        plain_text_body TEXT NOT NULL,
        variables TEXT NOT NULL,
        is_default INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''';

    const createEmailLogTable = '''
      CREATE TABLE IF NOT EXISTS $_emailLogTable (
        id TEXT PRIMARY KEY,
        invoice_id TEXT NOT NULL,
        recipient_email TEXT NOT NULL,
        subject TEXT NOT NULL,
        template_type TEXT NOT NULL,
        success INTEGER DEFAULT 0,
        error_message TEXT,
        message_id TEXT,
        sent_at TEXT NOT NULL,
        metadata TEXT DEFAULT '{}'
      )
    ''';

    final db = await _databaseService.database;
    await db.execute(createConfigurationsTable);
    await db.execute(createTemplatesTable);
    await db.execute(createEmailLogTable);
  }

  /// Create default email templates
  Future<void> _createDefaultTemplates() async {
    final templates = [
      InvoiceEmailTemplate.defaultInvoiceSent(),
      InvoiceEmailTemplate.defaultPaymentReminder(),
    ];

    for (final template in templates) {
      await _saveTemplate(template);
    }
  }

  /// Save email configuration
  Future<void> saveEmailConfiguration(EmailConfiguration config) async {
    // If this is set as default, remove default from others
    if (config.isDefault) {
      final db = await _databaseService.database;
      await db.execute(
        'UPDATE $_configurationsTable SET is_default = 0',
      );
    }

    const sql = '''
      INSERT OR REPLACE INTO $_configurationsTable (
        id, provider_name, smtp_host, smtp_port, use_ssl, use_tls,
        username, password, from_email, from_name, is_default,
        created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''';

    final db = await _databaseService.database;
    await db.execute(sql, [
      config.id,
      config.providerName,
      config.smtpHost,
      config.smtpPort,
      config.useSSL ? 1 : 0,
      config.useTLS ? 1 : 0,
      config.username,
      config.password, // In production, this should be encrypted
      config.fromEmail,
      config.fromName,
      config.isDefault ? 1 : 0,
      config.createdAt.toIso8601String(),
      config.updatedAt.toIso8601String(),
    ]);
  }

  /// Get the default email configuration
  Future<EmailConfiguration?> getDefaultEmailConfiguration() async {
    const sql = 'SELECT * FROM $_configurationsTable WHERE is_default = 1 LIMIT 1';
    final db = await _databaseService.database;
    final results = await db.rawQuery(sql);
    
    if (results.isEmpty) return null;
    
    return _configurationFromRow(results.first);
  }

  /// Get all email configurations
  Future<List<EmailConfiguration>> getAllEmailConfigurations() async {
    const sql = 'SELECT * FROM $_configurationsTable ORDER BY is_default DESC, created_at DESC';
    final db = await _databaseService.database;
    final results = await db.rawQuery(sql);
    
    return results.map((row) => _configurationFromRow(row)).toList();
  }

  /// Save email template
  Future<void> _saveTemplate(InvoiceEmailTemplate template) async {
    // If this is set as default for its type, remove default from others of same type
    if (template.isDefault) {
      final db = await _databaseService.database;
      await db.execute(
        'UPDATE $_templatesTable SET is_default = 0 WHERE type = ?',
        [template.type.name],
      );
    }

    const sql = '''
      INSERT OR REPLACE INTO $_templatesTable (
        id, name, type, subject, html_body, plain_text_body,
        variables, is_default, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''';

    final db = await _databaseService.database;
    await db.execute(sql, [
      template.id,
      template.name,
      template.type.name,
      template.subject,
      template.htmlBody,
      template.plainTextBody,
      template.variables.join(','),
      template.isDefault ? 1 : 0,
      template.createdAt.toIso8601String(),
      template.updatedAt.toIso8601String(),
    ]);
  }

  /// Get email template by type
  Future<InvoiceEmailTemplate?> getEmailTemplate(EmailTemplateType type) async {
    const sql = 'SELECT * FROM $_templatesTable WHERE type = ? AND is_default = 1 LIMIT 1';
    final db = await _databaseService.database;
    final results = await db.rawQuery(sql, [type.name]);
    
    if (results.isEmpty) return null;
    
    return _templateFromRow(results.first);
  }

  /// Send invoice email
  Future<EmailSendResult> sendInvoiceEmail({
    required EnhancedInvoice invoice,
    required String recipientEmail,
    EmailTemplateType templateType = EmailTemplateType.invoiceSent,
    List<EmailAttachment> attachments = const [],
    Map<String, String> customVariables = const {},
  }) async {
    try {
      // Get email configuration
      final config = await getDefaultEmailConfiguration();
      if (config == null) {
        return EmailSendResult.failure(
          error: 'No email configuration found. Please set up email settings first.',
        );
      }

      // Get email template
      final template = await getEmailTemplate(templateType);
      if (template == null) {
        return EmailSendResult.failure(
          error: 'No email template found for type: ${templateType.name}',
        );
      }

      // Prepare template variables
      final variables = _prepareTemplateVariables(invoice, customVariables);

      // Process template with variables
      final processedSubject = _processTemplate(template.subject, variables);
      final processedHtmlBody = _processTemplate(template.htmlBody, variables);
      final processedPlainBody = _processTemplate(template.plainTextBody, variables);

      // Create SMTP server configuration
      final smtpServer = SmtpServer(
        config.smtpHost,
        port: config.smtpPort,
        ssl: config.useSSL,
        allowInsecure: !config.useSSL && !config.useTLS,
        username: config.username,
        password: config.password,
      );

      // Create email message
      final message = Message()
        ..from = Address(config.fromEmail, config.fromName)
        ..recipients.add(recipientEmail)
        ..subject = processedSubject
        ..text = processedPlainBody
        ..html = processedHtmlBody;

      // Add attachments
      for (final attachment in attachments) {
        if (File(attachment.filePath).existsSync()) {
          final file = File(attachment.filePath);
          final bytes = await file.readAsBytes();
          message.attachments.add(FileAttachment(
            file,
            fileName: attachment.fileName,
            contentType: attachment.mimeType,
          ));
        }
      }

      // Send email
      final sendReport = await send(message, smtpServer);
      
      // Log the email
      await _logEmail(
        invoiceId: invoice.id,
        recipientEmail: recipientEmail,
        subject: processedSubject,
        templateType: templateType,
        success: true,
        messageId: sendReport.toString(),
      );

      // Send notification
      await _notificationService.sendNotification(
        title: 'Invoice Email Sent',
        message: 'Invoice ${invoice.invoiceNumber} sent to $recipientEmail',
        data: {
          'type': 'invoice_email_sent',
          'invoice_id': invoice.id,
          'recipient': recipientEmail,
        },
      );

      return EmailSendResult.success(
        messageId: sendReport.toString(),
        metadata: {
          'recipient': recipientEmail,
          'template_type': templateType.name,
          'subject': processedSubject,
        },
      );

    } catch (e) {
      // Log the error
      await _logEmail(
        invoiceId: invoice.id,
        recipientEmail: recipientEmail,
        subject: 'Failed to process',
        templateType: templateType,
        success: false,
        errorMessage: e.toString(),
      );

      return EmailSendResult.failure(
        error: 'Failed to send email: $e',
        metadata: {
          'recipient': recipientEmail,
          'template_type': templateType.name,
        },
      );
    }
  }

  /// Send payment reminder email
  Future<EmailSendResult> sendPaymentReminder({
    required EnhancedInvoice invoice,
    required String recipientEmail,
    Map<String, String> customVariables = const {},
  }) async {
    return await sendInvoiceEmail(
      invoice: invoice,
      recipientEmail: recipientEmail,
      templateType: EmailTemplateType.invoiceReminder,
      customVariables: customVariables,
    );
  }

  /// Send bulk invoice emails
  Future<List<EmailSendResult>> sendBulkInvoiceEmails({
    required List<EnhancedInvoice> invoices,
    required Map<String, String> recipientEmails, // invoice_id -> email
    EmailTemplateType templateType = EmailTemplateType.invoiceSent,
  }) async {
    final results = <EmailSendResult>[];
    
    for (final invoice in invoices) {
      final recipientEmail = recipientEmails[invoice.id];
      if (recipientEmail != null && recipientEmail.isNotEmpty) {
        final result = await sendInvoiceEmail(
          invoice: invoice,
          recipientEmail: recipientEmail,
          templateType: templateType,
        );
        results.add(result);
        
        // Small delay between emails to avoid overwhelming the SMTP server
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    
    return results;
  }

  /// Prepare template variables from invoice data
  Map<String, String> _prepareTemplateVariables(
    EnhancedInvoice invoice,
    Map<String, String> customVariables,
  ) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(symbol: '');

    final variables = <String, String>{
      'customer_name': invoice.customerName,
      'invoice_number': invoice.invoiceNumber,
      'issue_date': dateFormat.format(invoice.issueDate),
      'due_date': dateFormat.format(invoice.dueDate),
      'total_amount': currencyFormat.format(invoice.totalAmount),
      'subtotal': currencyFormat.format(invoice.subtotal),
      'tax_amount': currencyFormat.format(invoice.taxAmount),
      'currency': invoice.currency,
      'company_name': 'BizSync Corp', // TODO: Get from settings
      'company_email': 'hello@bizsync.com', // TODO: Get from settings
      'company_phone': '+65 1234 5678', // TODO: Get from settings
      'bank_details': 'DBS Bank: 123-456789-0', // TODO: Get from settings
      'paynow_details': '+65 1234 5678', // TODO: Get from settings
    };

    // Add custom variables
    variables.addAll(customVariables);

    return variables;
  }

  /// Process template string with variables
  String _processTemplate(String template, Map<String, String> variables) {
    String processed = template;
    
    for (final entry in variables.entries) {
      processed = processed.replaceAll('{{${entry.key}}}', entry.value);
    }
    
    return processed;
  }

  /// Log email sending attempt
  Future<void> _logEmail({
    required String invoiceId,
    required String recipientEmail,
    required String subject,
    required EmailTemplateType templateType,
    required bool success,
    String? messageId,
    String? errorMessage,
  }) async {
    const sql = '''
      INSERT INTO $_emailLogTable (
        id, invoice_id, recipient_email, subject, template_type,
        success, error_message, message_id, sent_at, metadata
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''';

    final db = await _databaseService.database;
    await db.execute(sql, [
      _uuid.v4(),
      invoiceId,
      recipientEmail,
      subject,
      templateType.name,
      success ? 1 : 0,
      errorMessage,
      messageId,
      DateTime.now().toIso8601String(),
      '{}',
    ]);
  }

  /// Get email history for an invoice
  Future<List<Map<String, dynamic>>> getEmailHistory(String invoiceId) async {
    const sql = '''
      SELECT * FROM $_emailLogTable 
      WHERE invoice_id = ? 
      ORDER BY sent_at DESC
    ''';
    
    final db = await _databaseService.database;
    return await db.rawQuery(sql, [invoiceId]);
  }

  /// Test email configuration
  Future<EmailSendResult> testEmailConfiguration(
    EmailConfiguration config,
    String testRecipientEmail,
  ) async {
    try {
      final smtpServer = SmtpServer(
        config.smtpHost,
        port: config.smtpPort,
        ssl: config.useSSL,
        allowInsecure: !config.useSSL && !config.useTLS,
        username: config.username,
        password: config.password,
      );

      final message = Message()
        ..from = Address(config.fromEmail, config.fromName)
        ..recipients.add(testRecipientEmail)
        ..subject = 'BizSync Email Configuration Test'
        ..text = 'This is a test email to verify your email configuration is working correctly.'
        ..html = '''
          <html>
          <body>
            <h2>Email Configuration Test</h2>
            <p>This is a test email to verify your BizSync email configuration is working correctly.</p>
            <p>If you receive this email, your configuration is set up properly!</p>
            <p>Provider: ${config.providerName}</p>
            <p>From: ${config.fromName} &lt;${config.fromEmail}&gt;</p>
          </body>
          </html>
        ''';

      final sendReport = await send(message, smtpServer);

      return EmailSendResult.success(
        messageId: sendReport.toString(),
        metadata: {
          'test_recipient': testRecipientEmail,
          'provider': config.providerName,
        },
      );

    } catch (e) {
      return EmailSendResult.failure(
        error: 'Email configuration test failed: $e',
        metadata: {
          'test_recipient': testRecipientEmail,
          'provider': config.providerName,
        },
      );
    }
  }

  /// Auto-send invoice emails based on status changes
  Future<void> handleInvoiceStatusChange({
    required EnhancedInvoice invoice,
    required InvoiceStatus oldStatus,
    required InvoiceStatus newStatus,
  }) async {
    // Auto-send email when invoice is sent
    if (oldStatus == InvoiceStatus.draft && newStatus == InvoiceStatus.sent) {
      if (invoice.customerEmail != null && invoice.customerEmail!.isNotEmpty) {
        await sendInvoiceEmail(
          invoice: invoice,
          recipientEmail: invoice.customerEmail!,
          templateType: EmailTemplateType.invoiceSent,
        );
      }
    }
    
    // Auto-send reminder when invoice becomes overdue
    if (newStatus == InvoiceStatus.overdue) {
      if (invoice.customerEmail != null && invoice.customerEmail!.isNotEmpty) {
        await sendPaymentReminder(
          invoice: invoice,
          recipientEmail: invoice.customerEmail!,
        );
      }
    }
  }

  /// Convert database row to EmailConfiguration
  EmailConfiguration _configurationFromRow(Map<String, dynamic> row) {
    return EmailConfiguration(
      id: row['id'],
      providerName: row['provider_name'],
      smtpHost: row['smtp_host'],
      smtpPort: row['smtp_port'],
      useSSL: (row['use_ssl'] ?? 0) == 1,
      useTLS: (row['use_tls'] ?? 0) == 1,
      username: row['username'],
      password: row['password'],
      fromEmail: row['from_email'],
      fromName: row['from_name'],
      isDefault: (row['is_default'] ?? 0) == 1,
      createdAt: DateTime.parse(row['created_at']),
      updatedAt: DateTime.parse(row['updated_at']),
    );
  }

  /// Convert database row to InvoiceEmailTemplate
  InvoiceEmailTemplate _templateFromRow(Map<String, dynamic> row) {
    return InvoiceEmailTemplate(
      id: row['id'],
      name: row['name'],
      type: EmailTemplateType.values.firstWhere(
        (t) => t.name == row['type'],
        orElse: () => EmailTemplateType.custom,
      ),
      subject: row['subject'],
      htmlBody: row['html_body'],
      plainTextBody: row['plain_text_body'],
      variables: (row['variables'] as String).split(','),
      isDefault: (row['is_default'] ?? 0) == 1,
      createdAt: DateTime.parse(row['created_at']),
      updatedAt: DateTime.parse(row['updated_at']),
    );
  }
}