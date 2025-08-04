import 'package:flutter_test/flutter_test.dart';
import 'package:bizsync/features/tax/services/singapore_gst_service.dart';
import 'package:bizsync/features/payments/services/paynow_sgqr_service.dart';
import '../test_factories.dart';

/// Unit tests for core business logic validation
/// These tests validate the business logic without UI dependencies
void main() {
  group('Core Business Logic Validation', () {
    group('GST Calculation Tests', () {
      test('should calculate 9% GST correctly', () {
        final result = SingaporeGstService.calculateGst(
          amount: 1000.0,
          calculationDate: DateTime.now(),
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: true,
          customerIsGstRegistered: true,
        );

        expect(result.netAmount, equals(1000.0));
        expect(result.gstRate, equals(0.09));
        expect(result.gstAmount, equals(90.0));
        expect(result.totalAmount, equals(1090.0));
        expect(result.isGstApplicable, isTrue);
      });

      test('should handle export transactions with zero GST', () {
        final result = SingaporeGstService.calculateGst(
          amount: 1000.0,
          calculationDate: DateTime.now(),
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: true,
          customerIsGstRegistered: false,
          isExport: true,
          customerCountry: 'US',
        );

        expect(result.isGstApplicable, isFalse);
        expect(result.gstAmount, equals(0.0));
        expect(result.totalAmount, equals(1000.0));
        expect(result.reasoning, contains('export'));
      });

      test('should apply historical GST rates correctly', () {
        // Test 8% rate for 2022
        final result2022 = SingaporeGstService.calculateGst(
          amount: 1000.0,
          calculationDate: DateTime(2022, 6, 15),
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: true,
          customerIsGstRegistered: true,
        );

        expect(result2022.gstRate, equals(0.08));
        expect(result2022.gstAmount, equals(80.0));

        // Test 7% rate for 2020
        final result2020 = SingaporeGstService.calculateGst(
          amount: 1000.0,
          calculationDate: DateTime(2020, 6, 15),
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: true,
          customerIsGstRegistered: true,
        );

        expect(result2020.gstRate, equals(0.07));
        expect(result2020.gstAmount, equals(70.0));
      });

      test('should handle tax-inclusive calculations', () {
        final result = SingaporeGstService.calculateGstInclusive(
          totalAmount: 1090.0,
          calculationDate: DateTime.now(),
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: true,
          customerIsGstRegistered: true,
        );

        expect(result.netAmount, closeTo(1000.0, 0.01));
        expect(result.gstAmount, closeTo(90.0, 0.01));
        expect(result.totalAmount, equals(1090.0));
      });
    });

    group('PayNow QR Code Tests', () {
      test('should generate valid PayNow QR code', () {
        final qrString = PayNowSGQRService.generatePayNowQR(
          amount: 100.0,
          merchantName: 'Test Merchant',
          uenNumber: '202012345A',
          reference: 'TEST-001',
        );

        expect(qrString, isNotEmpty);
        expect(qrString, contains('SG.PAYNOW'));
        expect(PayNowSGQRService.isValidSGQR(qrString), isTrue);
      });

      test('should generate QR with mobile number', () {
        final qrString = PayNowSGQRService.generatePayNowQR(
          amount: 50.0,
          merchantName: 'Individual Merchant',
          mobileNumber: '+65 91234567',
        );

        expect(qrString, isNotEmpty);
        expect(PayNowSGQRService.isValidSGQR(qrString), isTrue);
        expect(qrString, contains('091234567')); // Formatted mobile
      });

      test('should validate QR checksum correctly', () {
        final validQr = PayNowSGQRService.generatePayNowQR(
          amount: 25.0,
          merchantName: 'Checksum Test',
          uenNumber: '202012345A',
        );

        expect(PayNowSGQRService.isValidSGQR(validQr), isTrue);

        // Corrupt the checksum
        final corruptedQr = validQr.substring(0, validQr.length - 4) + '0000';
        expect(PayNowSGQRService.isValidSGQR(corruptedQr), isFalse);
      });
    });

    group('Invoice Calculation Tests', () {
      test('should validate invoice calculations', () {
        final invoiceData = TestFactories.createInvoiceData();

        expect(TestValidators.validateInvoiceCalculations(invoiceData), isTrue);

        // Test subtotal calculation
        final lineItems =
            invoiceData['line_items'] as List<Map<String, dynamic>>;
        final expectedSubtotal = lineItems.fold<double>(
          0.0,
          (sum, item) => sum + (item['line_total'] as double),
        );

        expect(invoiceData['subtotal'], equals(expectedSubtotal));
      });

      test('should handle discounted invoices correctly', () {
        final invoiceData = TestFactories.createDiscountedInvoice(
          discountPercentage: 0.10, // 10% discount
        );

        expect(TestValidators.validateInvoiceCalculations(invoiceData), isTrue);

        final subtotal = invoiceData['subtotal'] as double;
        final discount = invoiceData['discount_amount'] as double;
        final expectedDiscount = subtotal * 0.10;

        expect(discount, closeTo(expectedDiscount, 0.01));
      });
    });

    group('Customer and Product Validation Tests', () {
      test('should validate GST registration numbers', () {
        final validNumbers = [
          '200012345M',
          '123456789A',
          '999999999Z',
        ];

        for (final number in validNumbers) {
          expect(TestValidators.validateGstNumber(number), isTrue,
              reason: '$number should be valid');
        }

        final invalidNumbers = [
          'INVALID123',
          '20001234', // Missing letter
          '200012345m', // Lowercase
        ];

        for (final number in invalidNumbers) {
          expect(TestValidators.validateGstNumber(number), isFalse,
              reason: '$number should be invalid');
        }
      });

      test('should validate email formats', () {
        final validEmails = [
          'test@example.com',
          'user.name@company.co.uk',
          'first+last@domain.org',
        ];

        for (final email in validEmails) {
          expect(TestValidators.validateEmail(email), isTrue,
              reason: '$email should be valid');
        }

        final invalidEmails = [
          'invalid-email',
          '@domain.com',
          'user@',
        ];

        for (final email in invalidEmails) {
          expect(TestValidators.validateEmail(email), isFalse,
              reason: '$email should be invalid');
        }
      });

      test('should calculate product profit margins', () {
        final product = TestFactories.createProduct(
          price: 120.0,
          cost: 80.0,
        );

        expect(product.profitMarginPercentage, equals(50.0));
        expect(product.profitAmount, equals(40.0));
        expect(product.isInStock, isTrue);
      });

      test('should identify low stock products', () {
        final lowStockProduct = TestFactories.createLowStockProduct(
          stockQuantity: 5,
          minStockLevel: 10,
        );

        expect(lowStockProduct.isLowStock, isTrue);
        expect(lowStockProduct.isInStock, isTrue);

        final outOfStockProduct = TestFactories.createOutOfStockProduct();
        expect(outOfStockProduct.isInStock, isFalse);
        expect(outOfStockProduct.isLowStock,
            isFalse); // Not low stock, it's out of stock
      });
    });

    group('Business Rule Validation Tests', () {
      test('should identify export customers correctly', () {
        final localCustomer = TestFactories.createCustomer(countryCode: 'SG');
        final exportCustomer =
            TestFactories.createExportCustomer(countryCode: 'US');

        expect(localCustomer.isExportCustomer, isFalse);
        expect(exportCustomer.isExportCustomer, isTrue);
      });

      test('should validate customer GST status display', () {
        final gstCustomer = TestFactories.createSingaporeGstCustomer(
          gstNumber: '200012345M',
        );

        expect(gstCustomer.gstRegistered, isTrue);
        expect(gstCustomer.hasValidGstNumber, isTrue);
        expect(gstCustomer.gstStatusDisplay,
            equals('GST Registered (200012345M)'));

        final nonGstCustomer =
            TestFactories.createCustomer(gstRegistered: false);
        expect(nonGstCustomer.gstStatusDisplay, equals('Not GST Registered'));
      });

      test('should handle import GST calculations', () {
        final result = SingaporeGstService.calculateImportGst(
          cif: 1000.0,
          dutyAmount: 100.0,
          calculationDate: DateTime.now(),
        );

        // GST = (CIF + Duty) * 9% = 1100 * 0.09 = 99
        expect(result.gstAmount, equals(99.0));
        expect(result.totalAmount, equals(1199.0)); // CIF + Duty + GST
        expect(result.reasoning, contains('Import GST'));
      });
    });

    group('Edge Case Tests', () {
      test('should handle zero amounts', () {
        final result = SingaporeGstService.calculateGst(
          amount: 0.0,
          calculationDate: DateTime.now(),
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: true,
          customerIsGstRegistered: true,
        );

        expect(result.netAmount, equals(0.0));
        expect(result.gstAmount, equals(0.0));
        expect(result.totalAmount, equals(0.0));
      });

      test('should handle very small amounts with precision', () {
        final result = SingaporeGstService.calculateGst(
          amount: 0.01,
          calculationDate: DateTime.now(),
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: true,
          customerIsGstRegistered: true,
        );

        expect(result.gstAmount, closeTo(0.0009, 0.000001));
        expect(result.totalAmount, closeTo(0.0109, 0.000001));
      });

      test('should handle large amounts', () {
        final result = SingaporeGstService.calculateGst(
          amount: 999999.99,
          calculationDate: DateTime.now(),
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: true,
          customerIsGstRegistered: true,
        );

        expect(result.gstAmount, closeTo(89999.999, 0.01));
        expect(result.totalAmount, closeTo(1089999.989, 0.01));
      });

      test('should handle non-GST registered company', () {
        final result = SingaporeGstService.calculateGst(
          amount: 1000.0,
          calculationDate: DateTime.now(),
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: false,
          customerIsGstRegistered: true,
        );

        expect(result.isGstApplicable, isFalse);
        expect(result.gstAmount, equals(0.0));
        expect(result.reasoning, contains('not GST registered'));
      });
    });

    group('GST Registration Information Tests', () {
      test('should provide correct registration information', () {
        final info = SingaporeGstService.getGstRegistrationInfo();

        expect(info['mandatory_threshold'], equals(1000000)); // S$1 million
        expect(info['voluntary_threshold'], equals(0));
        expect(info['registration_period'], equals(30)); // 30 days
        expect(info['benefits'], isA<List>());
        expect(info['obligations'], isA<List>());
        expect((info['benefits'] as List).isNotEmpty, isTrue);
        expect((info['obligations'] as List).isNotEmpty, isTrue);
      });
    });
  });
}
