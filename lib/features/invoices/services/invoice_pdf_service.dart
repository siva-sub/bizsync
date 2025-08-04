import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/enhanced_invoice.dart';
import '../../../core/services/notification_service.dart';

/// Service for generating PDF invoices with professional templates
class InvoicePdfService {
  static InvoicePdfService? _instance;
  static InvoicePdfService get instance => _instance ??= InvoicePdfService._();
  
  InvoicePdfService._();

  final NotificationService _notificationService = NotificationService.instance;

  /// PDF template styles
  static const PdfColor primaryColor = PdfColor.fromInt(0xFF2196F3);
  static const PdfColor secondaryColor = PdfColor.fromInt(0xFF757575);
  static const PdfColor accentColor = PdfColor.fromInt(0xFFF5F5F5);
  static const PdfColor darkColor = PdfColor.fromInt(0xFF212121);

  /// Generate PDF invoice with professional template
  Future<Uint8List> generateInvoicePdf({
    required EnhancedInvoice invoice,
    InvoicePdfTemplate template = InvoicePdfTemplate.professional,
    Map<String, String> companyInfo = const {},
  }) async {
    final pdf = pw.Document();

    switch (template) {
      case InvoicePdfTemplate.professional:
        await _addProfessionalTemplate(pdf, invoice, companyInfo);
        break;
      case InvoicePdfTemplate.modern:
        await _addModernTemplate(pdf, invoice, companyInfo);
        break;
      case InvoicePdfTemplate.minimal:
        await _addMinimalTemplate(pdf, invoice, companyInfo);
        break;
      case InvoicePdfTemplate.classic:
        await _addClassicTemplate(pdf, invoice, companyInfo);
        break;
    }

    return await pdf.save();
  }

  /// Save PDF to file and return file path
  Future<String> saveInvoicePdf({
    required EnhancedInvoice invoice,
    InvoicePdfTemplate template = InvoicePdfTemplate.professional,
    Map<String, String> companyInfo = const {},
  }) async {
    final pdfBytes = await generateInvoicePdf(
      invoice: invoice,
      template: template,
      companyInfo: companyInfo,
    );

    final directory = await getApplicationDocumentsDirectory();
    final invoicesDir = Directory('${directory.path}/invoices');
    if (!await invoicesDir.exists()) {
      await invoicesDir.create(recursive: true);
    }

    final fileName = 'invoice_${invoice.invoiceNumber}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${invoicesDir.path}/$fileName');
    await file.writeAsBytes(pdfBytes);

    // Send notification
    await _notificationService.sendNotification(
      title: 'PDF Invoice Generated',
      body: 'Invoice ${invoice.invoiceNumber} PDF saved successfully',
      data: {
        'type': 'pdf_generated',
        'invoice_id': invoice.id,
        'file_path': file.path,
      },
    );

    return file.path;
  }

  /// Professional template implementation
  Future<void> _addProfessionalTemplate(
    pw.Document pdf,
    EnhancedInvoice invoice,
    Map<String, String> companyInfo,
  ) async {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(symbol: invoice.currency);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            _buildHeader(invoice, companyInfo),
            pw.SizedBox(height: 40),

            // Invoice details and customer info
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Invoice details
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      pw.SizedBox(height: 16),
                      _buildInfoRow('Invoice #:', invoice.invoiceNumber),
                      _buildInfoRow('Issue Date:', dateFormat.format(invoice.issueDate)),
                      _buildInfoRow('Due Date:', dateFormat.format(invoice.dueDate)),
                      _buildInfoRow('Status:', _getStatusText(invoice.status)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 40),
                // Customer info
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      color: accentColor,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'BILL TO:',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: secondaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          invoice.customerName,
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if (invoice.customerEmail != null) ...[
                          pw.SizedBox(height: 4),
                          pw.Text(
                            invoice.customerEmail!,
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                        ],
                        if (invoice.customerAddress != null) ...[
                          pw.SizedBox(height: 4),
                          pw.Text(
                            invoice.customerAddress!,
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 40),

            // Line items table
            _buildLineItemsTable(invoice, currencyFormat),
            pw.SizedBox(height: 30),

            // Totals section
            _buildTotalsSection(invoice, currencyFormat),
            pw.SizedBox(height: 40),

            // Payment information
            _buildPaymentInfo(companyInfo),

            // Notes
            if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
              pw.SizedBox(height: 30),
              _buildNotesSection(invoice.notes!),
            ],

            // Footer
            pw.Spacer(),
            _buildFooter(companyInfo),
          ];
        },
      ),
    );
  }

  /// Modern template implementation
  Future<void> _addModernTemplate(
    pw.Document pdf,
    EnhancedInvoice invoice,
    Map<String, String> companyInfo,
  ) async {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(symbol: invoice.currency);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Modern header with side-by-side layout
            pw.Container(
              padding: const pw.EdgeInsets.all(24),
              decoration: pw.BoxDecoration(
                gradient: const pw.LinearGradient(
                  colors: [primaryColor, PdfColor.fromInt(0xFF1976D2)],
                ),
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        companyInfo['name'] ?? 'BizSync Corp',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        companyInfo['tagline'] ?? 'Professional Business Solutions',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.white70,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.Text(
                        invoice.invoiceNumber,
                        style: pw.TextStyle(
                          fontSize: 16,
                          color: PdfColors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 32),

            // Customer and invoice details in cards
            pw.Row(
              children: [
                pw.Expanded(
                  child: _buildModernCard(
                    'Customer Details',
                    [
                      invoice.customerName,
                      if (invoice.customerEmail != null) invoice.customerEmail!,
                      if (invoice.customerAddress != null) invoice.customerAddress!,
                    ],
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  child: _buildModernCard(
                    'Invoice Details',
                    [
                      'Issue Date: ${dateFormat.format(invoice.issueDate)}',
                      'Due Date: ${dateFormat.format(invoice.dueDate)}',
                      'Status: ${_getStatusText(invoice.status)}',
                      'Currency: ${invoice.currency}',
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 32),

            // Modern line items table
            _buildModernLineItemsTable(invoice, currencyFormat),
            pw.SizedBox(height: 24),

            // Modern totals
            _buildModernTotals(invoice, currencyFormat),
            pw.SizedBox(height: 32),

            // Payment information
            _buildPaymentInfo(companyInfo),

            if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
              pw.SizedBox(height: 24),
              _buildNotesSection(invoice.notes!),
            ],

            pw.Spacer(),
            _buildModernFooter(companyInfo),
          ];
        },
      ),
    );
  }

  /// Minimal template implementation
  Future<void> _addMinimalTemplate(
    pw.Document pdf,
    EnhancedInvoice invoice,
    Map<String, String> companyInfo,
  ) async {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(symbol: invoice.currency);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Minimal header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  companyInfo['name'] ?? 'BizSync Corp',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'INVOICE',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: secondaryColor,
                  ),
                ),
              ],
            ),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 20),

            // Simple details layout
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Invoice Number: ${invoice.invoiceNumber}'),
                    pw.SizedBox(height: 4),
                    pw.Text('Issue Date: ${dateFormat.format(invoice.issueDate)}'),
                    pw.SizedBox(height: 4),
                    pw.Text('Due Date: ${dateFormat.format(invoice.dueDate)}'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Bill To:'),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      invoice.customerName,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    if (invoice.customerEmail != null) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(invoice.customerEmail!),
                    ],
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),

            // Simple table
            _buildSimpleLineItemsTable(invoice, currencyFormat),
            pw.SizedBox(height: 20),

            // Simple totals
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _buildSimpleTotalRow('Subtotal:', currencyFormat.format(invoice.subtotal)),
                    _buildSimpleTotalRow('Tax:', currencyFormat.format(invoice.taxAmount)),
                    pw.Divider(thickness: 1),
                    _buildSimpleTotalRow(
                      'Total:',
                      currencyFormat.format(invoice.totalAmount),
                      isTotal: true,
                    ),
                  ],
                ),
              ],
            ),

            if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
              pw.SizedBox(height: 30),
              pw.Text('Notes:'),
              pw.SizedBox(height: 4),
              pw.Text(invoice.notes!),
            ],

            pw.Spacer(),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'Thank you for your business!',
                style: pw.TextStyle(
                  fontStyle: pw.FontStyle.italic,
                  color: secondaryColor,
                ),
              ),
            ),
          ];
        },
      ),
    );
  }

  /// Classic template implementation
  Future<void> _addClassicTemplate(
    pw.Document pdf,
    EnhancedInvoice invoice,
    Map<String, String> companyInfo,
  ) async {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(symbol: invoice.currency);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Classic header with border
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 2),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    companyInfo['name'] ?? 'BizSync Corp',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    companyInfo['address'] ?? 'Singapore Business District',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.Text(
                    'Phone: ${companyInfo['phone'] ?? '+65 1234 5678'} | Email: ${companyInfo['email'] ?? 'hello@bizsync.com'}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            // Invoice title
            pw.Center(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                ),
                child: pw.Text(
                  'INVOICE',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),
            pw.SizedBox(height: 30),

            // Classic details layout
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Invoice Number:\n${invoice.invoiceNumber}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Date:\n${dateFormat.format(invoice.issueDate)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Due Date:\n${dateFormat.format(invoice.dueDate)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Customer details
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(border: pw.Border.all()),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'BILL TO:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(invoice.customerName),
                  if (invoice.customerEmail != null) pw.Text(invoice.customerEmail!),
                  if (invoice.customerAddress != null) pw.Text(invoice.customerAddress!),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            // Classic line items table
            _buildClassicLineItemsTable(invoice, currencyFormat),
            pw.SizedBox(height: 20),

            // Classic totals
            _buildClassicTotals(invoice, currencyFormat),

            if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
              pw.SizedBox(height: 30),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'NOTES:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(invoice.notes!),
                  ],
                ),
              ),
            ],

            pw.Spacer(),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all()),
              child: pw.Center(
                child: pw.Text(
                  'Thank you for your business!',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
            ),
          ];
        },
      ),
    );
  }

  // Helper methods for building PDF components

  pw.Widget _buildHeader(EnhancedInvoice invoice, Map<String, String> companyInfo) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              companyInfo['name'] ?? 'BizSync Corp',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              companyInfo['address'] ?? 'Singapore Business District',
              style: const pw.TextStyle(fontSize: 12, color: secondaryColor),
            ),
            pw.Text(
              'Phone: ${companyInfo['phone'] ?? '+65 1234 5678'}',
              style: const pw.TextStyle(fontSize: 12, color: secondaryColor),
            ),
            pw.Text(
              'Email: ${companyInfo['email'] ?? 'hello@bizsync.com'}',
              style: const pw.TextStyle(fontSize: 12, color: secondaryColor),
            ),
          ],
        ),
        if (companyInfo['logo'] != null)
          pw.Container(
            width: 80,
            height: 80,
            child: pw.Placeholder(), // Replace with actual logo when available
          ),
      ],
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: secondaryColor,
              ),
            ),
          ),
          pw.Text(value),
        ],
      ),
    );
  }

  pw.Widget _buildLineItemsTable(EnhancedInvoice invoice, NumberFormat currencyFormat) {
    return pw.Table(
      border: pw.TableBorder.all(color: secondaryColor, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: accentColor),
          children: [
            _buildTableCell('Description', isHeader: true),
            _buildTableCell('Qty', isHeader: true, alignment: pw.Alignment.center),
            _buildTableCell('Unit Price', isHeader: true, alignment: pw.Alignment.centerRight),
            _buildTableCell('Total', isHeader: true, alignment: pw.Alignment.centerRight),
          ],
        ),
        // Items
        ...invoice.lineItems.map((item) => pw.TableRow(
          children: [
            _buildTableCell(item.description),
            _buildTableCell(item.quantity.toString(), alignment: pw.Alignment.center),
            _buildTableCell(currencyFormat.format(item.unitPrice), alignment: pw.Alignment.centerRight),
            _buildTableCell(currencyFormat.format(item.total), alignment: pw.Alignment.centerRight),
          ],
        )),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false, pw.Alignment? alignment}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: isHeader ? 12 : 10,
        ),
        textAlign: alignment == pw.Alignment.center ? pw.TextAlign.center :
                  alignment == pw.Alignment.centerRight ? pw.TextAlign.right :
                  pw.TextAlign.left,
      ),
    );
  }

  pw.Widget _buildTotalsSection(EnhancedInvoice invoice, NumberFormat currencyFormat) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 200,
          child: pw.Column(
            children: [
              _buildTotalRow('Subtotal:', currencyFormat.format(invoice.subtotal)),
              if (invoice.discountAmount > 0)
                _buildTotalRow('Discount:', '-${currencyFormat.format(invoice.discountAmount)}'),
              _buildTotalRow('Tax:', currencyFormat.format(invoice.taxAmount)),
              pw.Divider(thickness: 1),
              _buildTotalRow(
                'TOTAL:',
                currencyFormat.format(invoice.totalAmount),
                isTotal: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTotalRow(String label, String value, {bool isTotal = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: isTotal ? 14 : 12,
              color: isTotal ? primaryColor : darkColor,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: isTotal ? 14 : 12,
              color: isTotal ? primaryColor : darkColor,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPaymentInfo(Map<String, String> companyInfo) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: accentColor,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'PAYMENT INFORMATION',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Bank Transfer: ${companyInfo['bank_details'] ?? 'DBS Bank: 123-456789-0'}'),
          pw.Text('PayNow: ${companyInfo['paynow'] ?? '+65 1234 5678'}'),
          pw.Text('SGQR: Scan the QR code for instant payment'),
        ],
      ),
    );
  }

  pw.Widget _buildNotesSection(String notes) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: secondaryColor, width: 0.5),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'NOTES',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(notes, style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(Map<String, String> companyInfo) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 16),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: secondaryColor, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated by BizSync | bizsync.com',
            style: pw.TextStyle(fontSize: 10, color: secondaryColor),
          ),
          pw.Text(
            'Page 1 of 1',
            style: pw.TextStyle(fontSize: 10, color: secondaryColor),
          ),
        ],
      ),
    );
  }

  // Modern template helper methods
  pw.Widget _buildModernCard(String title, List<String> content) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE0E0E0)),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
          ),
          pw.SizedBox(height: 8),
          ...content.map((line) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Text(line, style: const pw.TextStyle(fontSize: 11)),
          )),
        ],
      ),
    );
  }

  pw.Widget _buildModernLineItemsTable(EnhancedInvoice invoice, NumberFormat currencyFormat) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE0E0E0)),
      ),
      child: pw.Table(
        border: pw.TableBorder.symmetric(
          inside: const pw.BorderSide(color: PdfColor.fromInt(0xFFF5F5F5)),
        ),
        columnWidths: {
          0: const pw.FlexColumnWidth(3),
          1: const pw.FlexColumnWidth(1),
          2: const pw.FlexColumnWidth(1.5),
          3: const pw.FlexColumnWidth(1.5),
        },
        children: [
          // Header with gradient background
          pw.TableRow(
            decoration: const pw.BoxDecoration(
              color: primaryColor,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
            children: [
              _buildModernTableCell('Description', isHeader: true, textColor: PdfColors.white),
              _buildModernTableCell('Qty', isHeader: true, textColor: PdfColors.white, alignment: pw.Alignment.center),
              _buildModernTableCell('Unit Price', isHeader: true, textColor: PdfColors.white, alignment: pw.Alignment.centerRight),
              _buildModernTableCell('Total', isHeader: true, textColor: PdfColors.white, alignment: pw.Alignment.centerRight),
            ],
          ),
          // Items
          ...invoice.lineItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isEven = index % 2 == 0;
            
            return pw.TableRow(
              decoration: pw.BoxDecoration(
                color: isEven ? PdfColors.white : const PdfColor.fromInt(0xFFFAFAFA),
              ),
              children: [
                _buildModernTableCell(item.description),
                _buildModernTableCell(item.quantity.toString(), alignment: pw.Alignment.center),
                _buildModernTableCell(currencyFormat.format(item.unitPrice), alignment: pw.Alignment.centerRight),
                _buildModernTableCell(currencyFormat.format(item.total), alignment: pw.Alignment.centerRight),
              ],
            );
          }),
        ],
      ),
    );
  }

  pw.Widget _buildModernTableCell(
    String text, {
    bool isHeader = false,
    pw.Alignment? alignment,
    PdfColor textColor = darkColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: isHeader ? 12 : 10,
          color: textColor,
        ),
        textAlign: alignment == pw.Alignment.center ? pw.TextAlign.center :
                  alignment == pw.Alignment.centerRight ? pw.TextAlign.right :
                  pw.TextAlign.left,
      ),
    );
  }

  pw.Widget _buildModernTotals(EnhancedInvoice invoice, NumberFormat currencyFormat) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 250,
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            gradient: const pw.LinearGradient(
              colors: [PdfColor.fromInt(0xFFF8F9FA), PdfColors.white],
            ),
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: const PdfColor.fromInt(0xFFE0E0E0)),
          ),
          child: pw.Column(
            children: [
              _buildModernTotalRow('Subtotal', currencyFormat.format(invoice.subtotal)),
              if (invoice.discountAmount > 0)
                _buildModernTotalRow('Discount', '-${currencyFormat.format(invoice.discountAmount)}'),
              _buildModernTotalRow('Tax', currencyFormat.format(invoice.taxAmount)),
              pw.Divider(thickness: 1, color: const PdfColor.fromInt(0xFFE0E0E0)),
              _buildModernTotalRow(
                'TOTAL',
                currencyFormat.format(invoice.totalAmount),
                isTotal: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildModernTotalRow(String label, String value, {bool isTotal = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: isTotal ? 16 : 12,
              color: isTotal ? primaryColor : darkColor,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: isTotal ? 16 : 12,
              color: isTotal ? primaryColor : darkColor,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildModernFooter(Map<String, String> companyInfo) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [PdfColor.fromInt(0xFFF8F9FA), PdfColors.white],
        ),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Powered by BizSync - Modern Business Solutions',
            style: pw.TextStyle(fontSize: 10, color: secondaryColor),
          ),
          pw.Text(
            DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
            style: pw.TextStyle(fontSize: 10, color: secondaryColor),
          ),
        ],
      ),
    );
  }

  // Simple template helper methods
  pw.Widget _buildSimpleLineItemsTable(EnhancedInvoice invoice, NumberFormat currencyFormat) {
    return pw.Table(
      border: pw.TableBorder.all(),
      children: [
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),
        ...invoice.lineItems.map((item) => pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(item.description),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(item.quantity.toString()),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(currencyFormat.format(item.unitPrice)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(currencyFormat.format(item.total)),
            ),
          ],
        )),
      ],
    );
  }

  pw.Widget _buildSimpleTotalRow(String label, String value, {bool isTotal = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // Classic template helper methods
  pw.Widget _buildClassicLineItemsTable(EnhancedInvoice invoice, NumberFormat currencyFormat) {
    return pw.Table(
      border: pw.TableBorder.all(width: 2),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF0F0F0)),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('DESCRIPTION', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('QTY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('UNIT PRICE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),
        ...invoice.lineItems.map((item) => pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(item.description),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(item.quantity.toString()),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(currencyFormat.format(item.unitPrice)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(currencyFormat.format(item.total)),
            ),
          ],
        )),
      ],
    );
  }

  pw.Widget _buildClassicTotals(EnhancedInvoice invoice, NumberFormat currencyFormat) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 250,
          child: pw.Table(
            border: pw.TableBorder.all(width: 2),
            children: [
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('SUBTOTAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(currencyFormat.format(invoice.subtotal)),
                  ),
                ],
              ),
              if (invoice.discountAmount > 0)
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('DISCOUNT:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('-${currencyFormat.format(invoice.discountAmount)}'),
                    ),
                  ],
                ),
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('TAX:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(currencyFormat.format(invoice.taxAmount)),
                  ),
                ],
              ),
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF0F0F0)),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('TOTAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      currencyFormat.format(invoice.totalAmount),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getStatusText(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return 'Draft';
      case InvoiceStatus.pending:
        return 'Pending';
      case InvoiceStatus.approved:
        return 'Approved';
      case InvoiceStatus.sent:
        return 'Sent';
      case InvoiceStatus.viewed:
        return 'Viewed';
      case InvoiceStatus.partiallyPaid:
        return 'Partially Paid';
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.overdue:
        return 'Overdue';
      case InvoiceStatus.cancelled:
        return 'Cancelled';
      case InvoiceStatus.disputed:
        return 'Disputed';
      case InvoiceStatus.voided:
        return 'Voided';
      case InvoiceStatus.refunded:
        return 'Refunded';
    }
  }
}

/// Available PDF templates
enum InvoicePdfTemplate {
  professional,
  modern,
  minimal,
  classic,
}