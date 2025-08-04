import 'package:json_annotation/json_annotation.dart';

part 'email_models.g.dart';

/// Email template types for different invoice scenarios
enum EmailTemplateType {
  invoiceSent,
  invoiceReminder,
  invoiceOverdue,
  invoicePaid,
  recurringInvoice,
  custom,
}

/// Email configuration for SMTP settings
@JsonSerializable()
class EmailConfiguration {
  final String id;
  final String providerName;
  final String smtpHost;
  final int smtpPort;
  final bool useSSL;
  final bool useTLS;
  final String username;
  final String password; // Should be encrypted in production
  final String fromEmail;
  final String fromName;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EmailConfiguration({
    required this.id,
    required this.providerName,
    required this.smtpHost,
    required this.smtpPort,
    this.useSSL = true,
    this.useTLS = false,
    required this.username,
    required this.password,
    required this.fromEmail,
    required this.fromName,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EmailConfiguration.fromJson(Map<String, dynamic> json) =>
      _$EmailConfigurationFromJson(json);

  Map<String, dynamic> toJson() => _$EmailConfigurationToJson(this);

  EmailConfiguration copyWith({
    String? id,
    String? providerName,
    String? smtpHost,
    int? smtpPort,
    bool? useSSL,
    bool? useTLS,
    String? username,
    String? password,
    String? fromEmail,
    String? fromName,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmailConfiguration(
      id: id ?? this.id,
      providerName: providerName ?? this.providerName,
      smtpHost: smtpHost ?? this.smtpHost,
      smtpPort: smtpPort ?? this.smtpPort,
      useSSL: useSSL ?? this.useSSL,
      useTLS: useTLS ?? this.useTLS,
      username: username ?? this.username,
      password: password ?? this.password,
      fromEmail: fromEmail ?? this.fromEmail,
      fromName: fromName ?? this.fromName,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Predefined email configurations for popular providers
  static EmailConfiguration gmail({
    required String email,
    required String password,
    required String displayName,
  }) {
    return EmailConfiguration(
      id: 'gmail-${DateTime.now().millisecondsSinceEpoch}',
      providerName: 'Gmail',
      smtpHost: 'smtp.gmail.com',
      smtpPort: 587,
      useSSL: false,
      useTLS: true,
      username: email,
      password: password,
      fromEmail: email,
      fromName: displayName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static EmailConfiguration outlook({
    required String email,
    required String password,
    required String displayName,
  }) {
    return EmailConfiguration(
      id: 'outlook-${DateTime.now().millisecondsSinceEpoch}',
      providerName: 'Outlook',
      smtpHost: 'smtp-mail.outlook.com',
      smtpPort: 587,
      useSSL: false,
      useTLS: true,
      username: email,
      password: password,
      fromEmail: email,
      fromName: displayName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

/// Email template for invoice-related communications
@JsonSerializable()
class InvoiceEmailTemplate {
  final String id;
  final String name;
  final EmailTemplateType type;
  final String subject;
  final String htmlBody;
  final String plainTextBody;
  final List<String> variables; // Available template variables
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InvoiceEmailTemplate({
    required this.id,
    required this.name,
    required this.type,
    required this.subject,
    required this.htmlBody,
    required this.plainTextBody,
    required this.variables,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InvoiceEmailTemplate.fromJson(Map<String, dynamic> json) =>
      _$InvoiceEmailTemplateFromJson(json);

  Map<String, dynamic> toJson() => _$InvoiceEmailTemplateToJson(this);

  InvoiceEmailTemplate copyWith({
    String? id,
    String? name,
    EmailTemplateType? type,
    String? subject,
    String? htmlBody,
    String? plainTextBody,
    List<String>? variables,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InvoiceEmailTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      subject: subject ?? this.subject,
      htmlBody: htmlBody ?? this.htmlBody,
      plainTextBody: plainTextBody ?? this.plainTextBody,
      variables: variables ?? this.variables,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Default template for invoice sent notification
  static InvoiceEmailTemplate defaultInvoiceSent() {
    return InvoiceEmailTemplate(
      id: 'default-invoice-sent',
      name: 'Default Invoice Sent',
      type: EmailTemplateType.invoiceSent,
      subject: 'Invoice {{invoice_number}} from {{company_name}}',
      htmlBody: '''
        <html>
        <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background-color: #f8f9fa; padding: 20px; border-radius: 8px;">
            <h2 style="color: #2196F3; margin-bottom: 20px;">New Invoice</h2>
            
            <p>Dear {{customer_name}},</p>
            
            <p>Thank you for your business! Please find your invoice details below:</p>
            
            <div style="background-color: white; padding: 20px; border-radius: 8px; margin: 20px 0;">
              <table style="width: 100%; border-collapse: collapse;">
                <tr>
                  <td style="padding: 8px 0; border-bottom: 1px solid #eee;"><strong>Invoice Number:</strong></td>
                  <td style="padding: 8px 0; border-bottom: 1px solid #eee; text-align: right;">{{invoice_number}}</td>
                </tr>
                <tr>
                  <td style="padding: 8px 0; border-bottom: 1px solid #eee;"><strong>Issue Date:</strong></td>
                  <td style="padding: 8px 0; border-bottom: 1px solid #eee; text-align: right;">{{issue_date}}</td>
                </tr>
                <tr>
                  <td style="padding: 8px 0; border-bottom: 1px solid #eee;"><strong>Due Date:</strong></td>
                  <td style="padding: 8px 0; border-bottom: 1px solid #eee; text-align: right;">{{due_date}}</td>
                </tr>
                <tr>
                  <td style="padding: 8px 0; font-size: 18px;"><strong>Total Amount:</strong></td>
                  <td style="padding: 8px 0; text-align: right; font-size: 18px; color: #2196F3;"><strong>{{currency}}{{total_amount}}</strong></td>
                </tr>
              </table>
            </div>
            
            <p>Payment can be made via the following methods:</p>
            <ul>
              <li>Bank transfer to: {{bank_details}}</li>
              <li>PayNow to: {{paynow_details}}</li>
              <li>SGQR code (attached)</li>
            </ul>
            
            <p>If you have any questions about this invoice, please don't hesitate to contact us.</p>
            
            <p>Best regards,<br>
            {{company_name}}<br>
            {{company_email}}<br>
            {{company_phone}}</p>
          </div>
        </body>
        </html>
      ''',
      plainTextBody: '''
        Dear {{customer_name}},

        Thank you for your business! Please find your invoice details below:

        Invoice Number: {{invoice_number}}
        Issue Date: {{issue_date}}
        Due Date: {{due_date}}
        Total Amount: {{currency}}{{total_amount}}

        Payment can be made via bank transfer or PayNow.

        If you have any questions about this invoice, please contact us.

        Best regards,
        {{company_name}}
        {{company_email}}
        {{company_phone}}
      ''',
      variables: [
        'customer_name',
        'invoice_number',
        'issue_date',
        'due_date',
        'total_amount',
        'currency',
        'company_name',
        'company_email',
        'company_phone',
        'bank_details',
        'paynow_details',
      ],
      isDefault: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Default template for payment reminder
  static InvoiceEmailTemplate defaultPaymentReminder() {
    return InvoiceEmailTemplate(
      id: 'default-payment-reminder',
      name: 'Default Payment Reminder',
      type: EmailTemplateType.invoiceReminder,
      subject: 'Payment Reminder - Invoice {{invoice_number}}',
      htmlBody: '''
        <html>
        <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background-color: #fff3cd; padding: 20px; border-radius: 8px; border-left: 4px solid #ffc107;">
            <h2 style="color: #856404; margin-bottom: 20px;">Payment Reminder</h2>
            
            <p>Dear {{customer_name}},</p>
            
            <p>This is a friendly reminder that payment for the following invoice is due:</p>
            
            <div style="background-color: white; padding: 20px; border-radius: 8px; margin: 20px 0;">
              <table style="width: 100%; border-collapse: collapse;">
                <tr>
                  <td style="padding: 8px 0; border-bottom: 1px solid #eee;"><strong>Invoice Number:</strong></td>
                  <td style="padding: 8px 0; border-bottom: 1px solid #eee; text-align: right;">{{invoice_number}}</td>
                </tr>
                <tr>
                  <td style="padding: 8px 0; border-bottom: 1px solid #eee;"><strong>Due Date:</strong></td>
                  <td style="padding: 8px 0; border-bottom: 1px solid #eee; text-align: right;">{{due_date}}</td>
                </tr>
                <tr>
                  <td style="padding: 8px 0; font-size: 18px;"><strong>Amount Due:</strong></td>
                  <td style="padding: 8px 0; text-align: right; font-size: 18px; color: #ffc107;"><strong>{{currency}}{{total_amount}}</strong></td>
                </tr>
              </table>
            </div>
            
            <p>Please arrange payment at your earliest convenience to avoid any late fees.</p>
            
            <p>If you have already made this payment, please disregard this reminder.</p>
            
            <p>Thank you for your prompt attention to this matter.</p>
            
            <p>Best regards,<br>
            {{company_name}}<br>
            {{company_email}}<br>
            {{company_phone}}</p>
          </div>
        </body>
        </html>
      ''',
      plainTextBody: '''
        Dear {{customer_name}},

        PAYMENT REMINDER

        This is a friendly reminder that payment for Invoice {{invoice_number}} is due on {{due_date}}.

        Amount Due: {{currency}}{{total_amount}}

        Please arrange payment at your earliest convenience.

        If you have already made this payment, please disregard this reminder.

        Best regards,
        {{company_name}}
        {{company_email}}
        {{company_phone}}
      ''',
      variables: [
        'customer_name',
        'invoice_number',
        'due_date',
        'total_amount',
        'currency',
        'company_name',
        'company_email',
        'company_phone',
      ],
      isDefault: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

/// Email sending result
@JsonSerializable()
class EmailSendResult {
  final bool success;
  final String? messageId;
  final String? error;
  final DateTime sentAt;
  final Map<String, dynamic> metadata;

  const EmailSendResult({
    required this.success,
    this.messageId,
    this.error,
    required this.sentAt,
    this.metadata = const {},
  });

  factory EmailSendResult.fromJson(Map<String, dynamic> json) =>
      _$EmailSendResultFromJson(json);

  Map<String, dynamic> toJson() => _$EmailSendResultToJson(this);

  factory EmailSendResult.success({
    required String messageId,
    Map<String, dynamic> metadata = const {},
  }) {
    return EmailSendResult(
      success: true,
      messageId: messageId,
      sentAt: DateTime.now(),
      metadata: metadata,
    );
  }

  factory EmailSendResult.failure({
    required String error,
    Map<String, dynamic> metadata = const {},
  }) {
    return EmailSendResult(
      success: false,
      error: error,
      sentAt: DateTime.now(),
      metadata: metadata,
    );
  }
}

/// Email attachment for invoices (PDFs, images, etc.)
@JsonSerializable()
class EmailAttachment {
  final String fileName;
  final String mimeType;
  final String filePath;
  final int sizeBytes;

  const EmailAttachment({
    required this.fileName,
    required this.mimeType,
    required this.filePath,
    required this.sizeBytes,
  });

  factory EmailAttachment.fromJson(Map<String, dynamic> json) =>
      _$EmailAttachmentFromJson(json);

  Map<String, dynamic> toJson() => _$EmailAttachmentToJson(this);
}