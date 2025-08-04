import 'package:flutter_test/flutter_test.dart';
import 'package:bizsync/features/tax/services/singapore_gst_service.dart';
import 'package:bizsync/features/tax/services/calculation/tax_calculation_service.dart';
import '../test_factories.dart';

/// Comprehensive integration tests for tax calculations
/// Tests GST rates, exemptions, export scenarios, historical rates, and edge cases
void main() {
  group('Tax Calculations Integration Tests', () {
    setUp(() {
      TestFactories.reset();
    });

    group('Current GST Rate (9%) Tests', () {
      test('should calculate 9% GST for standard transactions', () async {
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
        expect(result.reasoning, contains('9%'));
      });

      test('should handle tax-inclusive calculations at 9%', () async {
        // Total amount includes GST: SGD 1090 = SGD 1000 + 9% GST
        final result = SingaporeGstService.calculateGstInclusive(
          totalAmount: 1090.0,
          calculationDate: DateTime.now(),
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: true,
          customerIsGstRegistered: true,
        );

        expect(result.netAmount, closeTo(1000.0, 0.01));
        expect(result.gstRate, equals(0.09));
        expect(result.gstAmount, closeTo(90.0, 0.01));
        expect(result.totalAmount, equals(1090.0));
      });

      test('should calculate GST on different amounts with precision',
          () async {
        final testAmounts = [
          {'amount': 0.01, 'expectedGst': 0.0009},
          {'amount': 1.00, 'expectedGst': 0.09},
          {'amount': 10.50, 'expectedGst': 0.945},
          {'amount': 123.45, 'expectedGst': 11.1105},
          {'amount': 999999.99, 'expectedGst': 89999.9991},
        ];

        for (final testCase in testAmounts) {
          final amount = testCase['amount'] as double;
          final expectedGst = testCase['expectedGst'] as double;

          final result = SingaporeGstService.calculateGst(
            amount: amount,
            calculationDate: DateTime.now(),
            taxCategory: GstTaxCategory.standard,
            isGstRegistered: true,
            customerIsGstRegistered: true,
          );

          expect(result.gstAmount, closeTo(expectedGst, 0.0001),
              reason: 'GST calculation incorrect for amount $amount');
        }
      });
    });

    group('Historical GST Rates', () {
      test('should apply 8% GST for 2022 transactions', () async {
        final result = SingaporeGstService.calculateGst(
          amount: 1000.0,
          calculationDate: DateTime(2022, 6, 15),
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: true,
          customerIsGstRegistered: true,
        );

        expect(result.gstRate, equals(0.08));
        expect(result.gstAmount, equals(80.0));
        expect(result.totalAmount, equals(1080.0));
      });

      test('should apply 7% GST for 2020 transactions', () async {
        final result = SingaporeGstService.calculateGst(
          amount: 1000.0,
          calculationDate: DateTime(2020, 6, 15),
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: true,
          customerIsGstRegistered: true,
        );

        expect(result.gstRate, equals(0.07));
        expect(result.gstAmount, equals(70.0));
        expect(result.totalAmount, equals(1070.0));
      });

      test('should apply 5% GST for pre-2016 transactions', () async {
        final result = SingaporeGstService.calculateGst(
          amount: 1000.0,
          calculationDate: DateTime(2015, 6, 15),
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: true,
          customerIsGstRegistered: true,
        );

        expect(result.gstRate, equals(0.05));
        expect(result.gstAmount, equals(50.0));
        expect(result.totalAmount, equals(1050.0));
      });

      test('should handle transition dates correctly', () async {
        // Day before 9% rate effective (should be 8%)
        final before9Percent = SingaporeGstService.calculateGst(
          amount: 1000.0,
          calculationDate: DateTime(2022, 12, 31),
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: true,
          customerIsGstRegistered: true,
        );

        expect(before9Percent.gstRate, equals(0.08));

        // Day of 9% rate effective
        final day9Percent = SingaporeGstService.calculateGst(
          amount: 1000.0,
          calculationDate: DateTime(2023, 1, 1),
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: true,
          customerIsGstRegistered: true,
        );

        expect(day9Percent.gstRate, equals(0.09));
      });
    });

    group('GST Registration Status Scenarios', () {
      test('should apply no GST when company is not registered', () async {
        final result = SingaporeGstService.calculateGst(
          amount: 1000.0,
          calculationDate: DateTime.now(),
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: false, // Company not GST registered
          customerIsGstRegistered: true,
        );

        expect(result.isGstApplicable, isFalse);
        expect(result.gstRate, equals(0.0));
        expect(result.gstAmount, equals(0.0));
        expect(result.totalAmount, equals(1000.0));
        expect(result.reasoning, contains('not GST registered'));
      });

      test('should apply GST regardless of customer registration status',
          () async {
        // B2B (both registered)
        final b2bResult = SingaporeGstService.calculateGst(
          amount: 1000.0,
          calculationDate: DateTime.now(),
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: true,
          customerIsGstRegistered: true,
        );

        // B2C (customer not registered)
        final b2cResult = SingaporeGstService.calculateGst(
          amount: 1000.0,
          calculationDate: DateTime.now(),
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: true,
          customerIsGstRegistered: false,
        );

        // Both should have same GST calculation
        expect(b2bResult.gstAmount, equals(b2cResult.gstAmount));
        expect(b2bResult.totalAmount, equals(b2cResult.totalAmount));
      });
    });

    group('Export and Zero-Rated Transactions', () {
      test('should apply zero rate for export transactions', () async {
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
        expect(result.gstRate, equals(0.0));
        expect(result.gstAmount, equals(0.0));
        expect(result.totalAmount, equals(1000.0));
        expect(result.reasoning, contains('export'));
      });

      test('should apply zero rate for non-Singapore customers', () async {
        final countries = ['US', 'MY', 'IN', 'UK', 'AU'];

        for (final country in countries) {
          final result = SingaporeGstService.calculateGst(
            amount: 1000.0,
            calculationDate: DateTime.now(),
            taxCategory: GstTaxCategory.standard,
            isGstRegistered: true,
            customerIsGstRegistered: false,
            customerCountry: country,
          );

          expect(result.isGstApplicable, isFalse,
              reason: 'Export to $country should be zero-rated');
          expect(result.reasoning, contains('export'));
        }
      });

      test('should handle zero-rated domestic supplies', () async {
        final result = SingaporeGstService.calculateGst(
          amount: 1000.0,
          calculationDate: DateTime.now(),
          taxCategory: GstTaxCategory.zeroRated,
          isGstRegistered: true,
          customerIsGstRegistered: true,
        );

        expect(result.isGstApplicable, isFalse);
        expect(result.gstAmount, equals(0.0));
        expect(result.reasoning, contains('Zero-rated'));
      });
    });

    group('Exempt Transactions', () {
      test('should handle exempt supplies correctly', () async {
        final result = SingaporeGstService.calculateGst(
          amount: 1000.0,
          calculationDate: DateTime.now(),
          taxCategory: GstTaxCategory.exempt,
          isGstRegistered: true,
          customerIsGstRegistered: true,
        );

        expect(result.isGstApplicable, isFalse);
        expect(result.gstAmount, equals(0.0));
        expect(result.reasoning, contains('Exempt'));
      });

      test('should identify exempt categories correctly', () async {
        final exemptCategories = [
          'Financial services',
          'Insurance services',
          'Residential property sales',
          'Education services',
          'Healthcare services',
        ];

        for (final category in exemptCategories) {
          expect(SingaporeGstExemptions.isCategoryExempt(category), isTrue,
              reason: '$category should be exempt');
        }

        final taxableCategories = [
          'Electronics',
          'Furniture',
          'Food and beverage',
          'Consulting services',
        ];

        for (final category in taxableCategories) {
          expect(SingaporeGstExemptions.isCategoryExempt(category), isFalse,
              reason: '$category should be taxable');
        }
      });
    });

    group('Import GST Calculations', () {
      test('should calculate import GST on CIF plus duty', () async {
        final result = SingaporeGstService.calculateImportGst(
          cif: 5000.0, // Cost, Insurance, Freight
          dutyAmount: 500.0, // 10% customs duty
          calculationDate: DateTime.now(),
        );

        // GST base = CIF + Duty = 5000 + 500 = 5500
        // GST = 5500 * 9% = 495
        // Total = 5000 + 500 + 495 = 5995

        expect(result.netAmount, equals(5500.0)); // Taxable value
        expect(result.gstAmount, equals(495.0));
        expect(result.totalAmount, equals(5995.0));
        expect(result.reasoning, contains('Import GST'));
        expect(result.additionalInfo!['cif_value'], equals(5000.0));
        expect(result.additionalInfo!['duty_amount'], equals(500.0));
      });

      test('should handle zero duty imports', () async {
        final result = SingaporeGstService.calculateImportGst(
          cif: 1000.0,
          dutyAmount: 0.0, // No duty
          calculationDate: DateTime.now(),
        );

        // GST = 1000 * 9% = 90
        expect(result.netAmount, equals(1000.0));
        expect(result.gstAmount, equals(90.0));
        expect(result.totalAmount, equals(1090.0));
      });

      test('should apply historical rates for import GST', () async {
        final result2022 = SingaporeGstService.calculateImportGst(
          cif: 1000.0,
          dutyAmount: 100.0,
          calculationDate: DateTime(2022, 6, 15),
        );

        // Should use 8% rate for 2022
        expect(result2022.gstAmount, equals(88.0)); // 1100 * 8%
      });
    });

    group('GST Invoice Validation', () {
      test('should validate correct GST invoice', () async {
        final validation = SingaporeGstService.validateGstInvoice(
          invoiceNumber: 'INV-2024-001',
          invoiceDate: DateTime.now(),
          supplierName: 'Test Company Pte Ltd',
          supplierGstNumber: '200012345M',
          customerName: 'Customer Company Ltd',
          netAmount: 1000.0,
          gstAmount: 90.0,
          totalAmount: 1090.0,
        );

        expect(validation.isValid, isTrue);
        expect(validation.errors, isEmpty);
        expect(validation.warnings, isEmpty);
      });

      test('should detect invalid GST number formats', () async {
        final invalidGstNumbers = [
          'INVALID123',
          '20001234', // Missing letter
          '20001234MM', // Two letters
          '200012345m', // Lowercase
        ];

        for (final gstNumber in invalidGstNumbers) {
          final validation = SingaporeGstService.validateGstInvoice(
            invoiceNumber: 'INV-001',
            invoiceDate: DateTime.now(),
            supplierName: 'Test Company',
            supplierGstNumber: gstNumber,
            customerName: 'Customer',
            netAmount: 1000.0,
            gstAmount: 90.0,
            totalAmount: 1090.0,
          );

          expect(validation.isValid, isFalse,
              reason: '$gstNumber should be invalid');
          expect(validation.errors,
              contains('Invalid GST registration number format'));
        }
      });

      test('should detect calculation errors', () async {
        final validation = SingaporeGstService.validateGstInvoice(
          invoiceNumber: 'INV-001',
          invoiceDate: DateTime.now(),
          supplierName: 'Test Company',
          supplierGstNumber: '200012345M',
          customerName: 'Customer',
          netAmount: 1000.0,
          gstAmount: 90.0,
          totalAmount: 1095.0, // Incorrect total (should be 1090)
        );

        expect(validation.isValid, isFalse);
        expect(validation.errors,
            contains('Amount calculation inconsistency detected'));
      });

      test('should warn about high-value transactions without GST', () async {
        final validation = SingaporeGstService.validateGstInvoice(
          invoiceNumber: 'INV-001',
          invoiceDate: DateTime.now(),
          supplierName: 'Test Company',
          supplierGstNumber: '200012345M',
          customerName: 'Customer',
          netAmount: 2000.0,
          gstAmount: 0.0, // No GST on high-value transaction
          totalAmount: 2000.0,
        );

        expect(validation.isValid, isTrue); // Still valid
        expect(validation.warnings, isNotEmpty);
        expect(validation.warnings.first,
            contains('High-value transaction without GST'));
      });
    });

    group('Multi-tier Tax Scenarios', () {
      test('should handle mixed tax categories in single transaction',
          () async {
        final lineItems = [
          {
            'description': 'Standard Rated Item',
            'amount': 1000.0,
            'category': GstTaxCategory.standard,
          },
          {
            'description': 'Zero-Rated Export Item',
            'amount': 500.0,
            'category': GstTaxCategory.zeroRated,
          },
          {
            'description': 'Exempt Financial Service',
            'amount': 200.0,
            'category': GstTaxCategory.exempt,
          },
        ];

        double totalGst = 0.0;
        double totalAmount = 0.0;

        for (final item in lineItems) {
          final result = SingaporeGstService.calculateGst(
            amount: item['amount'] as double,
            calculationDate: DateTime.now(),
            taxCategory: item['category'] as GstTaxCategory,
            isGstRegistered: true,
            customerIsGstRegistered: true,
          );

          totalGst += result.gstAmount;
          totalAmount += result.totalAmount;
        }

        // Only standard item should have GST: 1000 * 9% = 90
        expect(totalGst, equals(90.0));

        // Total: 1090 (standard) + 500 (zero-rated) + 200 (exempt) = 1790
        expect(totalAmount, equals(1790.0));
      });

      test('should calculate compound tax scenarios', () async {
        // Scenario: Import with duty, then add local services
        final importResult = SingaporeGstService.calculateImportGst(
          cif: 1000.0,
          dutyAmount: 100.0,
          calculationDate: DateTime.now(),
        );

        // Add local service (installation) - standard rated
        final serviceResult = SingaporeGstService.calculateGst(
          amount: 200.0,
          calculationDate: DateTime.now(),
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: true,
          customerIsGstRegistered: true,
        );

        final totalGst = importResult.gstAmount + serviceResult.gstAmount;
        final grandTotal = importResult.totalAmount + serviceResult.totalAmount;

        // Import GST: (1000 + 100) * 9% = 99
        // Service GST: 200 * 9% = 18
        // Total GST: 99 + 18 = 117
        expect(totalGst, equals(117.0));

        // Grand total: 1199 (import) + 218 (service) = 1417
        expect(grandTotal, equals(1417.0));
      });
    });

    group('Edge Cases and Error Handling', () {
      test('should handle zero amounts', () async {
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

      test('should handle very large amounts', () async {
        final result = SingaporeGstService.calculateGst(
          amount: 999999999.99,
          calculationDate: DateTime.now(),
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: true,
          customerIsGstRegistered: true,
        );

        expect(result.gstAmount, closeTo(89999999.999, 0.01));
        expect(result.totalAmount, closeTo(1089999999.989, 0.01));
      });

      test('should handle very small amounts with rounding', () async {
        final result = SingaporeGstService.calculateGst(
          amount: 0.001,
          calculationDate: DateTime.now(),
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: true,
          customerIsGstRegistered: true,
        );

        expect(result.gstAmount, closeTo(0.00009, 0.000001));
        expect(result.totalAmount, closeTo(0.00109, 0.000001));
      });

      test('should handle future dates with current rate', () async {
        final futureDate = DateTime.now().add(Duration(days: 365));

        final result = SingaporeGstService.calculateGst(
          amount: 1000.0,
          calculationDate: futureDate,
          taxCategory: GstTaxCategory.standard,
          isGstRegistered: true,
          customerIsGstRegistered: true,
        );

        // Should use current rate (9%) for future dates
        expect(result.gstRate, equals(0.09));
      });
    });

    group('Comprehensive Tax Scenarios', () {
      test('should run all predefined tax scenarios', () async {
        final scenarios = TestFactories.createTaxScenarios();

        for (final scenario in scenarios) {
          final result = SingaporeGstService.calculateGst(
            amount: scenario['amount'],
            calculationDate: scenario['calculation_date'],
            taxCategory: GstTaxCategory.standard,
            isGstRegistered: scenario['is_gst_registered'],
            customerIsGstRegistered: scenario['customer_is_gst_registered'],
            isExport: scenario['is_export'],
            customerCountry: scenario['customer_country'],
          );

          // Verify result is consistent with scenario expectations
          print('Scenario: ${scenario['scenario_name']}');
          print('  Amount: ${scenario['amount']}');
          print('  GST: ${result.gstAmount}');
          print('  Total: ${result.totalAmount}');
          print('  Reasoning: ${result.reasoning}');
          print('---');

          // Basic validation
          expect(result.netAmount, equals(scenario['amount']));
          expect(result.gstAmount, greaterThanOrEqualTo(0.0));
          expect(result.totalAmount, greaterThanOrEqualTo(result.netAmount));
        }
      });

      test('should maintain calculation consistency across multiple runs',
          () async {
        // Run the same calculation multiple times to ensure consistency
        final amount = 1234.56;
        final calculationDate = DateTime.now();

        final results = <GstCalculationResult>[];
        for (int i = 0; i < 10; i++) {
          final result = SingaporeGstService.calculateGst(
            amount: amount,
            calculationDate: calculationDate,
            taxCategory: GstTaxCategory.standard,
            isGstRegistered: true,
            customerIsGstRegistered: true,
          );
          results.add(result);
        }

        // All results should be identical
        final firstResult = results.first;
        for (final result in results.skip(1)) {
          expect(result.netAmount, equals(firstResult.netAmount));
          expect(result.gstAmount, equals(firstResult.gstAmount));
          expect(result.totalAmount, equals(firstResult.totalAmount));
          expect(result.gstRate, equals(firstResult.gstRate));
        }
      });
    });

    group('GST Registration Information', () {
      test('should provide correct GST registration thresholds', () async {
        final info = SingaporeGstService.getGstRegistrationInfo();

        expect(info['mandatory_threshold'], equals(1000000)); // S$1 million
        expect(info['voluntary_threshold'], equals(0));
        expect(info['registration_period'], equals(30)); // 30 days
        expect(info['benefits'], isA<List>());
        expect(info['obligations'], isA<List>());

        // Verify benefits and obligations are not empty
        expect((info['benefits'] as List).isNotEmpty, isTrue);
        expect((info['obligations'] as List).isNotEmpty, isTrue);
      });
    });
  });
}
