import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as path;

/// Print Layout Options
enum PrintLayout {
  portrait,
  landscape,
  auto,
}

/// Print Quality Options
enum PrintQuality {
  draft,
  normal,
  high,
  photo,
}

/// Print Paper Size
enum PrintPaperSize {
  a4,
  a5,
  letter,
  legal,
  custom,
}

/// Print Configuration
class PrintConfig {
  final String jobName;
  final PrintLayout layout;
  final PrintQuality quality;
  final PrintPaperSize paperSize;
  final PdfPageFormat? customPageFormat;
  final int copies;
  final bool color;
  final bool duplex;
  final String? printerName;
  final Map<String, dynamic> additionalSettings;

  PrintConfig({
    required this.jobName,
    this.layout = PrintLayout.portrait,
    this.quality = PrintQuality.normal,
    this.paperSize = PrintPaperSize.a4,
    this.customPageFormat,
    this.copies = 1,
    this.color = true,
    this.duplex = false,
    this.printerName,
    this.additionalSettings = const {},
  });
}

/// Print Result
class PrintResult {
  final bool success;
  final String? error;
  final String? jobId;
  final Map<String, dynamic>? metadata;

  PrintResult({
    required this.success,
    this.error,
    this.jobId,
    this.metadata,
  });
}

/// Print Service for Linux Desktop
/// 
/// Provides comprehensive printing functionality:
/// - Direct printing of invoices/reports
/// - Print preview with zoom and navigation
/// - Custom print layouts and templates
/// - Multiple printer support
/// - Print queue management
class PrintService {
  static final PrintService _instance = PrintService._internal();
  factory PrintService() => _instance;
  PrintService._internal();

  bool _isInitialized = false;
  List<Printer> _availablePrinters = [];
  Printer? _defaultPrinter;

  /// Initialize the print service
  Future<void> initialize() async {
    if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) {
      debugPrint('Print service not available on this platform');
      return;
    }

    try {
      // Discover available printers
      await _discoverPrinters();
      
      _isInitialized = true;
      debugPrint('✅ Print service initialized successfully');
      debugPrint('Found ${_availablePrinters.length} printers');
    } catch (e) {
      debugPrint('❌ Failed to initialize print service: $e');
    }
  }

  /// Discover available printers
  Future<void> _discoverPrinters() async {
    try {
      _availablePrinters = await Printing.listPrinters();
      
      // Find default printer
      try {
        _defaultPrinter = _availablePrinters.firstWhere(
          (printer) => printer.isDefault,
        );
      } catch (e) {
        // If no default printer, use first available
        if (_availablePrinters.isNotEmpty) {
          _defaultPrinter = _availablePrinters.first;
        }
      }
      
      debugPrint('Available printers:');
      for (final printer in _availablePrinters) {
        debugPrint('  - ${printer.name} ${printer.isDefault ? '(default)' : ''}');
      }
    } catch (e) {
      debugPrint('Failed to discover printers: $e');
    }
  }

  /// Show print preview dialog
  Future<void> showPrintPreview({
    required pw.Document document,
    String? title,
    PrintConfig? config,
  }) async {
    if (!_isInitialized) {
      debugPrint('Print service not initialized');
      return;
    }

    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) => document.save(),
        name: title ?? config?.jobName ?? 'BizSync Document',
        format: _getPdfPageFormat(config?.paperSize ?? PrintPaperSize.a4),
      );
    } catch (e) {
      debugPrint('Failed to show print preview: $e');
    }
  }

  /// Print document directly
  Future<PrintResult> printDocument({
    required pw.Document document,
    PrintConfig? config,
  }) async {
    if (!_isInitialized) {
      return PrintResult(
        success: false,
        error: 'Print service not initialized',
      );
    }

    try {
      final pdfBytes = await document.save();
      
      final printer = config?.printerName != null
          ? _availablePrinters.firstWhere(
              (p) => p.name == config!.printerName,
              orElse: () => _defaultPrinter!,
            )
          : _defaultPrinter!;

      final printJob = await Printing.directPrintPdf(
        printer: printer,
        onLayout: (format) => pdfBytes,
        name: config?.jobName ?? 'BizSync Document',
        format: _getPdfPageFormat(config?.paperSize ?? PrintPaperSize.a4),
      );

      return PrintResult(
        success: true,
        jobId: printJob.toString(),
        metadata: {
          'printer': printer.name,
          'copies': config?.copies ?? 1,
          'paperSize': config?.paperSize.toString(),
        },
      );
    } catch (e) {
      debugPrint('Failed to print document: $e');
      return PrintResult(
        success: false,
        error: 'Failed to print: $e',
      );
    }
  }

  /// Print invoice with custom layout
  Future<PrintResult> printInvoice({
    required Map<String, dynamic> invoiceData,
    PrintConfig? config,
    String? templateName,
  }) async {
    try {
      final document = await _generateInvoicePdf(invoiceData, templateName);
      
      final printConfig = config ?? PrintConfig(
        jobName: 'Invoice ${invoiceData['number'] ?? 'Unknown'}',
        layout: PrintLayout.portrait,
        paperSize: PrintPaperSize.a4,
      );

      return await printDocument(
        document: document,
        config: printConfig,
      );
    } catch (e) {
      debugPrint('Failed to print invoice: $e');
      return PrintResult(
        success: false,
        error: 'Failed to print invoice: $e',
      );
    }
  }

  /// Print report with custom layout
  Future<PrintResult> printReport({
    required Map<String, dynamic> reportData,
    PrintConfig? config,
    String? templateName,
  }) async {
    try {
      final document = await _generateReportPdf(reportData, templateName);
      
      final printConfig = config ?? PrintConfig(
        jobName: 'Report ${reportData['title'] ?? 'Unknown'}',
        layout: PrintLayout.portrait,
        paperSize: PrintPaperSize.a4,
      );

      return await printDocument(
        document: document,
        config: printConfig,
      );
    } catch (e) {
      debugPrint('Failed to print report: $e');
      return PrintResult(
        success: false,
        error: 'Failed to print report: $e',
      );
    }
  }

  /// Print customer list
  Future<PrintResult> printCustomerList({
    required List<Map<String, dynamic>> customers,
    PrintConfig? config,
  }) async {
    try {
      final document = await _generateCustomerListPdf(customers);
      
      final printConfig = config ?? PrintConfig(
        jobName: 'Customer List',
        layout: PrintLayout.portrait,
        paperSize: PrintPaperSize.a4,
      );

      return await printDocument(
        document: document,
        config: printConfig,
      );
    } catch (e) {
      debugPrint('Failed to print customer list: $e');
      return PrintResult(
        success: false,
        error: 'Failed to print customer list: $e',
      );
    }
  }

  /// Print inventory report
  Future<PrintResult> printInventoryReport({
    required List<Map<String, dynamic>> products,
    PrintConfig? config,
  }) async {
    try {
      final document = await _generateInventoryReportPdf(products);
      
      final printConfig = config ?? PrintConfig(
        jobName: 'Inventory Report',
        layout: PrintLayout.landscape,
        paperSize: PrintPaperSize.a4,
      );

      return await printDocument(
        document: document,
        config: printConfig,
      );
    } catch (e) {
      debugPrint('Failed to print inventory report: $e');
      return PrintResult(
        success: false,
        error: 'Failed to print inventory report: $e',
      );
    }
  }

  /// Generate invoice PDF
  Future<pw.Document> _generateInvoicePdf(
    Map<String, dynamic> invoiceData,
    String? templateName,
  ) async {
    final pdf = pw.Document();

    // Load custom font if available
    pw.Font? regularFont;
    pw.Font? boldFont;
    
    try {
      final regularFontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final boldFontData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      regularFont = pw.Font.ttf(regularFontData);
      boldFont = pw.Font.ttf(boldFontData);
    } catch (e) {
      debugPrint('Custom fonts not available, using default');
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'BizSync',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 24,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.Text(
                        'Business Management System',
                        style: pw.TextStyle(
                          font: regularFont,
                          fontSize: 12,
                          color: PdfColors.grey600,
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
                          font: boldFont,
                          fontSize: 20,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.Text(
                        'Invoice #${invoiceData['number'] ?? 'N/A'}',
                        style: pw.TextStyle(
                          font: regularFont,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              pw.SizedBox(height: 32),
              
              // Invoice details
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Bill To
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Bill To:',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 14,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          invoiceData['customerName'] ?? 'N/A',
                          style: pw.TextStyle(
                            font: regularFont,
                            fontSize: 12,
                          ),
                        ),
                        if (invoiceData['customerAddress'] != null)
                          pw.Text(
                            invoiceData['customerAddress'],
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Invoice info
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        _buildInfoRow('Date:', invoiceData['date'] ?? 'N/A', regularFont, boldFont),
                        _buildInfoRow('Due Date:', invoiceData['dueDate'] ?? 'N/A', regularFont, boldFont),
                        _buildInfoRow('Terms:', invoiceData['terms'] ?? 'Net 30', regularFont, boldFont),
                      ],
                    ),
                  ),
                ],
              ),
              
              pw.SizedBox(height: 32),
              
              // Line items table
              _buildLineItemsTable(invoiceData['lineItems'] ?? [], regularFont, boldFont),
              
              pw.SizedBox(height: 32),
              
              // Totals
              _buildTotalsSection(invoiceData, regularFont, boldFont),
              
              pw.Spacer(),
              
              // Footer
              pw.Text(
                'Thank you for your business!',
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  /// Generate report PDF
  Future<pw.Document> _generateReportPdf(
    Map<String, dynamic> reportData,
    String? templateName,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                reportData['title'] ?? 'Business Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'Generated on: ${DateTime.now().toString().split('.')[0]}',
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 32),
              
              // Report content would go here
              pw.Text(
                reportData['content'] ?? 'Report content not available',
                style: const pw.TextStyle(fontSize: 12),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  /// Generate customer list PDF
  Future<pw.Document> _generateCustomerListPdf(List<Map<String, dynamic>> customers) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Customer List',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 16),
            
            // Customer table
            pw.Table.fromTextArray(
              headers: ['Name', 'Email', 'Phone', 'Company'],
              data: customers.map((customer) => [
                customer['name'] ?? 'N/A',
                customer['email'] ?? 'N/A',
                customer['phone'] ?? 'N/A',
                customer['company'] ?? 'N/A',
              ]).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellPadding: const pw.EdgeInsets.all(8),
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  /// Generate inventory report PDF
  Future<pw.Document> _generateInventoryReportPdf(List<Map<String, dynamic>> products) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Inventory Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 16),
            
            // Inventory table
            pw.Table.fromTextArray(
              headers: ['SKU', 'Name', 'Category', 'Stock', 'Unit Price', 'Total Value'],
              data: products.map((product) => [
                product['sku'] ?? 'N/A',
                product['name'] ?? 'N/A',
                product['category'] ?? 'N/A',
                product['stock']?.toString() ?? '0',
                '\$${product['price']?.toStringAsFixed(2) ?? '0.00'}',
                '\$${((product['stock'] ?? 0) * (product['price'] ?? 0)).toStringAsFixed(2)}',
              ]).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellPadding: const pw.EdgeInsets.all(6),
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  /// Build info row for invoice
  pw.Widget _buildInfoRow(String label, String value, pw.Font? regularFont, pw.Font? boldFont) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 10,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: regularFont,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  /// Build line items table
  pw.Widget _buildLineItemsTable(List<dynamic> lineItems, pw.Font? regularFont, pw.Font? boldFont) {
    return pw.Table.fromTextArray(
      headers: ['Description', 'Qty', 'Unit Price', 'Total'],
      data: lineItems.map((item) => [
        item['description'] ?? 'N/A',
        item['quantity']?.toString() ?? '0',
        '\$${item['unitPrice']?.toStringAsFixed(2) ?? '0.00'}',
        '\$${((item['quantity'] ?? 0) * (item['unitPrice'] ?? 0)).toStringAsFixed(2)}',
      ]).toList(),
      headerStyle: pw.TextStyle(
        font: boldFont,
        fontSize: 12,
      ),
      cellStyle: pw.TextStyle(
        font: regularFont,
        fontSize: 10,
      ),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.grey300,
      ),
      cellPadding: const pw.EdgeInsets.all(8),
    );
  }

  /// Build totals section
  pw.Widget _buildTotalsSection(Map<String, dynamic> invoiceData, pw.Font? regularFont, pw.Font? boldFont) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 200,
        child: pw.Column(
          children: [
            _buildTotalRow('Subtotal:', '\$${invoiceData['subtotal']?.toStringAsFixed(2) ?? '0.00'}', regularFont, boldFont),
            if (invoiceData['tax'] != null && invoiceData['tax'] > 0)
              _buildTotalRow('Tax:', '\$${invoiceData['tax']?.toStringAsFixed(2) ?? '0.00'}', regularFont, boldFont),
            if (invoiceData['discount'] != null && invoiceData['discount'] > 0)
              _buildTotalRow('Discount:', '-\$${invoiceData['discount']?.toStringAsFixed(2) ?? '0.00'}', regularFont, boldFont),
            pw.Divider(),
            _buildTotalRow('Total:', '\$${invoiceData['total']?.toStringAsFixed(2) ?? '0.00'}', boldFont, boldFont),
          ],
        ),
      ),
    );
  }

  /// Build total row
  pw.Widget _buildTotalRow(String label, String value, pw.Font? labelFont, pw.Font? valueFont) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: labelFont,
              fontSize: 12,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: valueFont,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Get PDF page format from paper size enum
  PdfPageFormat _getPdfPageFormat(PrintPaperSize paperSize) {
    switch (paperSize) {
      case PrintPaperSize.a4:
        return PdfPageFormat.a4;
      case PrintPaperSize.a5:
        return PdfPageFormat.a5;
      case PrintPaperSize.letter:
        return PdfPageFormat.letter;
      case PrintPaperSize.legal:
        return PdfPageFormat.legal;
      case PrintPaperSize.custom:
        return PdfPageFormat.a4; // Default fallback
    }
  }

  /// Get available printers
  List<Printer> get availablePrinters => List.unmodifiable(_availablePrinters);

  /// Get default printer
  Printer? get defaultPrinter => _defaultPrinter;

  /// Set default printer
  void setDefaultPrinter(Printer printer) {
    _defaultPrinter = printer;
    debugPrint('Default printer set to: ${printer.name}');
  }

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Refresh printer list
  Future<void> refreshPrinters() async {
    await _discoverPrinters();
  }

  /// Dispose of the print service
  Future<void> dispose() async {
    _availablePrinters.clear();
    _defaultPrinter = null;
    _isInitialized = false;
    debugPrint('Print service disposed');
  }
}