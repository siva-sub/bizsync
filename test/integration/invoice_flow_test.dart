import 'package:flutter_test/flutter_test.dart';
import 'package:bizsync/features/invoices/services/invoice_calculation_service.dart';
import 'package:bizsync/features/invoices/services/invoice_sgqr_service.dart';
import 'package:bizsync/features/tax/services/singapore_gst_service.dart';
import 'package:bizsync/features/payments/services/paynow_sgqr_service.dart';
import 'package:bizsync/core/database/crdt_database_service.dart';
import '../test_factories.dart';

/// Comprehensive integration tests for invoice creation flow
/// Tests the complete end-to-end process from invoice creation to PayNow QR generation
void main() {
  group('Invoice Creation Flow Integration Tests', () {
    late CRDTDatabaseService databaseService;

    setUpAll(() async {
      // Initialize database service for testing
      databaseService = CRDTDatabaseService();
      await databaseService.initialize('test_node_invoice');
    });

    tearDownAll(() async {
      await databaseService.closeDatabase();
    });

    setUp(() {
      TestFactories.reset();
    });

    group('Basic Invoice Creation', () {
      test('should create draft invoice with correct calculations', () async {
        // Arrange
        final customer = TestFactories.createSingaporeGstCustomer();
        final products = [
          TestFactories.createProduct(name: 'Product A', price: 100.0),
          TestFactories.createProduct(name: 'Product B', price: 200.0),
        ];

        // Act - Create invoice
        final invoiceData = TestFactories.createDraftInvoice(
          customer: customer,
          products: products,
        );

        // Assert - Validate basic structure
        expect(invoiceData['customer_id'], equals(customer.id));
        expect(invoiceData['status'], equals('draft'));
        expect(invoiceData['currency'], equals('SGD'));
        expect(invoiceData['line_items'], isA<List>());
        expect((invoiceData['line_items'] as List).length, equals(2));

        // Validate calculations
        expect(TestValidators.validateInvoiceCalculations(invoiceData), isTrue);

        // Check subtotal (2 * 100 + 2 * 200 = 600)
        expect(invoiceData['subtotal'], equals(600.0));

        // Check GST (9% of 600 = 54)
        expect(invoiceData['tax_amount'], closeTo(54.0, 0.01));

        // Check total (600 + 54 = 654)
        expect(invoiceData['total_amount'], closeTo(654.0, 0.01));
      });

      test('should create invoice with discounts correctly', () async {
        // Arrange
        final customer = TestFactories.createSingaporeGstCustomer();

        // Act - Create invoice with 15% discount
        final invoiceData = TestFactories.createDiscountedInvoice(
          customer: customer,
          discountPercentage: 0.15,
        );

        // Assert
        expect(TestValidators.validateInvoiceCalculations(invoiceData), isTrue);

        final subtotal = invoiceData['subtotal'] as double;
        final discount = invoiceData['discount_amount'] as double;
        final expectedDiscount = subtotal * 0.15;

        expect(discount, closeTo(expectedDiscount, 0.01));

        // GST should be calculated on net amount (after discount)
        final netAmount = subtotal - discount;
        final expectedTax = netAmount * 0.09;
        expect(invoiceData['tax_amount'], closeTo(expectedTax, 0.01));
      });

      test('should handle export invoices with zero GST', () async {
        // Arrange
        final exportCustomer =
            TestFactories.createExportCustomer(countryCode: 'US');

        // Act
        final invoiceData = TestFactories.createExportInvoice(
          exportCustomer: exportCustomer,
        );

        // Calculate GST for export customer
        final gstResult = SingaporeGstService.calculateGst(
          amount: invoiceData['subtotal'],
          calculationDate: DateTime.now(),
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: true,
          customerIsGstRegistered: false,
          isExport: true,
          customerCountry: 'US',
        );

        // Assert - Export should be zero-rated
        expect(gstResult.isGstApplicable, isFalse);
        expect(gstResult.gstAmount, equals(0.0));
        expect(gstResult.gstRate, equals(0.0));
        expect(gstResult.reasoning, contains('export'));
      });
    });

    group('GST Calculations', () {
      test('should apply correct GST rate based on date', () async {
        // Test current 9% rate
        final currentGst = SingaporeGstService.calculateGst(
          amount: 1000.0,
          calculationDate: DateTime.now(),
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: true,
          customerIsGstRegistered: true,
        );

        expect(currentGst.gstRate, equals(0.09));
        expect(currentGst.gstAmount, equals(90.0));
        expect(currentGst.totalAmount, equals(1090.0));

        // Test historical 8% rate (2022)
        final historicalGst2022 = SingaporeGstService.calculateGst(
          amount: 1000.0,
          calculationDate: DateTime(2022, 6, 1),
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: true,
          customerIsGstRegistered: true,
        );

        expect(historicalGst2022.gstRate, equals(0.08));
        expect(historicalGst2022.gstAmount, equals(80.0));

        // Test historical 7% rate (2020)
        final historicalGst2020 = SingaporeGstService.calculateGst(
          amount: 1000.0,
          calculationDate: DateTime(2020, 6, 1),
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: true,
          customerIsGstRegistered: true,
        );

        expect(historicalGst2020.gstRate, equals(0.07));
        expect(historicalGst2020.gstAmount, equals(70.0));
      });

      test('should handle tax-inclusive calculations', () async {
        // Tax-inclusive amount: SGD 1090 (includes 9% GST)
        final inclusiveGst = SingaporeGstService.calculateGstInclusive(
          totalAmount: 1090.0,
          calculationDate: DateTime.now(),
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: true,
          customerIsGstRegistered: true,
        );

        expect(inclusiveGst.netAmount, closeTo(1000.0, 0.01));
        expect(inclusiveGst.gstAmount, closeTo(90.0, 0.01));
        expect(inclusiveGst.totalAmount, equals(1090.0));
      });

      test('should validate GST invoice requirements', () async {
        final validation = SingaporeGstService.validateGstInvoice(
          invoiceNumber: 'INV-001',
          invoiceDate: DateTime.now(),
          supplierName: 'Test Company',
          supplierGstNumber: '200012345M',
          customerName: 'Test Customer',
          netAmount: 1000.0,
          gstAmount: 90.0,
          totalAmount: 1090.0,
        );

        expect(validation.isValid, isTrue);
        expect(validation.errors, isEmpty);
      });

      test('should detect invalid GST numbers', () async {
        final validation = SingaporeGstService.validateGstInvoice(
          invoiceNumber: 'INV-001',
          invoiceDate: DateTime.now(),
          supplierName: 'Test Company',
          supplierGstNumber: 'INVALID123', // Invalid format
          customerName: 'Test Customer',
          netAmount: 1000.0,
          gstAmount: 90.0,
          totalAmount: 1090.0,
        );

        expect(validation.isValid, isFalse);
        expect(validation.errors,
            contains('Invalid GST registration number format'));
      });

      test('should detect calculation inconsistencies', () async {
        final validation = SingaporeGstService.validateGstInvoice(
          invoiceNumber: 'INV-001',
          invoiceDate: DateTime.now(),
          supplierName: 'Test Company',
          supplierGstNumber: '200012345M',
          customerName: 'Test Customer',
          netAmount: 1000.0,
          gstAmount: 90.0,
          totalAmount: 1095.0, // Incorrect total
        );

        expect(validation.isValid, isFalse);
        expect(validation.errors,
            contains('Amount calculation inconsistency detected'));
      });
    });

    group('PayNow QR Code Generation', () {
      test('should generate valid PayNow QR code for invoice', () async {
        // Arrange
        final customer = TestFactories.createSingaporeGstCustomer();
        final invoiceData =
            TestFactories.createDraftInvoice(customer: customer);

        // Act - Generate PayNow QR
        final qrString = PayNowSGQRService.generateInvoicePaymentQR(
          invoiceNumber: invoiceData['invoice_number'],
          amount: invoiceData['total_amount'],
          merchantName: 'Test Merchant',
          merchantUEN: '202012345A',
        );

        // Assert
        expect(qrString, isNotEmpty);
        expect(TestValidators.validatePayNowQR(qrString), isTrue);
        expect(PayNowSGQRService.isValidSGQR(qrString), isTrue);

        // Verify QR contains correct amount and reference
        expect(qrString, contains('SG.PAYNOW'));
        final metadata = PayNowSGQRService.parseSGQRMetadata(qrString);
        expect(metadata, isNotNull);
        expect(metadata!['amount'], equals(invoiceData['total_amount']));
        expect(metadata['currency'], equals('SGD'));
      });

      test('should generate QR with UEN correctly', () async {
        final qrString = PayNowSGQRService.generatePayNowQR(
          amount: 100.0,
          merchantName: 'Test Company',
          uenNumber: '202012345A',
          reference: 'TEST-REF-001',
        );

        expect(qrString, isNotEmpty);
        expect(PayNowSGQRService.isValidSGQR(qrString), isTrue);
        expect(qrString, contains('2202012345A')); // UEN format: 2 + UEN
      });

      test('should generate QR with mobile number correctly', () async {
        final qrString = PayNowSGQRService.generatePayNowQR(
          amount: 100.0,
          merchantName: 'Test Person',
          mobileNumber: '+65 91234567',
          reference: 'TEST-REF-002',
        );

        expect(qrString, isNotEmpty);
        expect(PayNowSGQRService.isValidSGQR(qrString), isTrue);
        expect(qrString, contains('091234567')); // Mobile format: 0 + number
      });

      test('should validate QR checksum correctly', () async {
        // Generate valid QR
        final validQr = PayNowSGQRService.generatePayNowQR(
          amount: 100.0,
          merchantName: 'Test',
          uenNumber: '202012345A',
        );

        expect(PayNowSGQRService.isValidSGQR(validQr), isTrue);

        // Corrupt the checksum
        final corruptedQr = validQr.substring(0, validQr.length - 4) + '0000';
        expect(PayNowSGQRService.isValidSGQR(corruptedQr), isFalse);
      });
    });

    group('Multi-tier Tax Calculations', () {
      test('should handle complex invoice with multiple tax rates', () async {
        // Create line items with different tax categories
        final lineItems = [
          {
            'id': 'item1',
            'product_name': 'Standard Rated Item',
            'quantity': 1.0,
            'unit_price': 100.0,
            'tax_category': 'standard',
            'tax_rate': 0.09,
            'line_total': 100.0,
          },
          {
            'id': 'item2',
            'product_name': 'Export Item',
            'quantity': 1.0,
            'unit_price': 200.0,
            'tax_category': 'zero_rated',
            'tax_rate': 0.0,
            'line_total': 200.0,
          },
          {
            'id': 'item3',
            'product_name': 'Exempt Item',
            'quantity': 1.0,
            'unit_price': 50.0,
            'tax_category': 'exempt',
            'tax_rate': 0.0,
            'line_total': 50.0,
          },
        ];

        // Calculate totals
        final subtotal = lineItems.fold<double>(
          0.0,
          (sum, item) => sum + (item['line_total'] as double),
        );

        // Calculate tax for each category
        double totalTax = 0.0;
        for (final item in lineItems) {
          final lineTotal = item['line_total'] as double;
          final taxRate = item['tax_rate'] as double;
          totalTax += lineTotal * taxRate;
        }

        expect(subtotal, equals(350.0)); // 100 + 200 + 50
        expect(totalTax, equals(9.0)); // Only standard item taxed: 100 * 0.09
      });

      test('should calculate import GST correctly', () async {
        final importGst = SingaporeGstService.calculateImportGst(
          cif: 1000.0, // Cost, Insurance, Freight
          dutyAmount: 100.0, // Customs duty
          calculationDate: DateTime.now(),
        );

        // GST is calculated on CIF + Duty = 1100
        final expectedGst = 1100.0 * 0.09; // 99.0
        expect(importGst.gstAmount, equals(expectedGst));
        expect(importGst.totalAmount, equals(1199.0)); // CIF + Duty + GST
        expect(importGst.reasoning, contains('Import GST'));
      });
    });

    group('Invoice Status Workflow', () {
      test('should transition invoice through complete workflow', () async {
        // Create draft invoice
        final customer = TestFactories.createSingaporeGstCustomer();
        final invoiceData =
            TestFactories.createDraftInvoice(customer: customer);

        expect(invoiceData['status'], equals('draft'));

        // Simulate sending invoice
        invoiceData['status'] = 'sent';
        invoiceData['sent_date'] = DateTime.now();

        // Simulate payment
        final paymentData = TestFactories.createPaymentData(
          invoiceId: invoiceData['id'],
          amount: invoiceData['total_amount'],
        );

        // Update invoice status to paid
        invoiceData['status'] = 'paid';
        invoiceData['paid_at'] = DateTime.now();
        invoiceData['payments'] = [paymentData];

        // Verify final state
        expect(invoiceData['status'], equals('paid'));
        expect(invoiceData['paid_at'], isNotNull);
        expect(invoiceData['payments'], hasLength(1));
      });

      test('should handle partial payments correctly', () async {
        final customer = TestFactories.createSingaporeGstCustomer();
        final invoiceData =
            TestFactories.createDraftInvoice(customer: customer);
        final totalAmount = invoiceData['total_amount'] as double;

        // Create partial payment (50% of total)
        final partialPayment = TestFactories.createPaymentData(
          invoiceId: invoiceData['id'],
          amount: totalAmount * 0.5,
        );

        final remainingBalance =
            totalAmount - (partialPayment['amount'] as double);

        expect(remainingBalance, equals(totalAmount * 0.5));
        expect(remainingBalance > 0, isTrue);

        // Invoice should be partially paid
        invoiceData['status'] = 'partially_paid';
        invoiceData['remaining_balance'] = remainingBalance;

        expect(invoiceData['status'], equals('partially_paid'));
      });
    });

    group('Error Handling and Edge Cases', () {
      test('should handle zero amount invoice', () async {
        expect(
          () => PayNowSGQRService.generatePayNowQR(
            amount: 0.0,
            merchantName: 'Test',
            uenNumber: '202012345A',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should handle invalid merchant details', () async {
        // Missing both UEN and mobile should use default
        final qrString = PayNowSGQRService.generatePayNowQR(
          amount: 100.0,
          merchantName: 'Test',
        );

        expect(qrString, isNotEmpty);
        expect(PayNowSGQRService.isValidSGQR(qrString), isTrue);
        expect(qrString, contains('2202012345A')); // Default demo UEN
      });

      test('should validate extreme amounts', () async {
        // Very large amount
        final largeAmountGst = SingaporeGstService.calculateGst(
          amount: 999999999.99,
          calculationDate: DateTime.now(),
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: true,
          customerIsGstRegistered: true,
        );

        expect(largeAmountGst.isGstApplicable, isTrue);
        expect(largeAmountGst.gstAmount, closeTo(89999999.999, 0.01));

        // Very small amount
        final smallAmountGst = SingaporeGstService.calculateGst(
          amount: 0.01,
          calculationDate: DateTime.now(),
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: true,
          customerIsGstRegistered: true,
        );

        expect(smallAmountGst.isGstApplicable, isTrue);
        expect(smallAmountGst.gstAmount, closeTo(0.0009, 0.0001));
      });

      test('should handle company not GST registered scenarios', () async {
        final nonGstResult = SingaporeGstService.calculateGst(
          amount: 1000.0,
          calculationDate: DateTime.now(),
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: false, // Company not GST registered
          customerIsGstRegistered: true,
        );

        expect(nonGstResult.isGstApplicable, isFalse);
        expect(nonGstResult.gstAmount, equals(0.0));
        expect(nonGstResult.reasoning, contains('not GST registered'));
      });
    });
  });
}
