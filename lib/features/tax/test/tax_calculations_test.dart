import 'package:flutter_test/flutter_test.dart';
import '../services/singapore_gst_service.dart';
import '../../employees/services/singapore_cpf_service.dart';

/// Comprehensive test suite for Singapore tax calculations
void main() {
  group('Singapore GST Service Tests', () {
    test('should calculate 9% GST correctly for standard items', () {
      final result = SingaporeGstService.calculateGst(
        amount: 100.0,
        calculationDate: DateTime(2024, 6, 1),
        taxCategory: GstTaxCategory.standard,
        isGstRegistered: true,
        customerIsGstRegistered: false,
      );

      expect(result.netAmount, equals(100.0));
      expect(result.gstRate, equals(0.09));
      expect(result.gstAmount, equals(9.0));
      expect(result.totalAmount, equals(109.0));
      expect(result.isGstApplicable, isTrue);
    });

    test('should calculate 8% GST for 2022-2023 transactions', () {
      final result = SingaporeGstService.calculateGst(
        amount: 100.0,
        calculationDate: DateTime(2022, 6, 1),
        taxCategory: GstTaxCategory.standard,
        isGstRegistered: true,
        customerIsGstRegistered: false,
      );

      expect(result.gstRate, equals(0.08));
      expect(result.gstAmount, equals(8.0));
      expect(result.totalAmount, equals(108.0));
    });

    test('should calculate 7% GST for pre-2022 transactions', () {
      final result = SingaporeGstService.calculateGst(
        amount: 100.0,
        calculationDate: DateTime(2021, 6, 1),
        taxCategory: GstTaxCategory.standard,
        isGstRegistered: true,
        customerIsGstRegistered: false,
      );

      expect(result.gstRate, equals(0.07));
      expect(result.gstAmount, equals(7.0));
      expect(result.totalAmount, equals(107.0));
    });

    test('should not apply GST for exempt items', () {
      final result = SingaporeGstService.calculateGst(
        amount: 100.0,
        calculationDate: DateTime(2024, 6, 1),
        taxCategory: GstTaxCategory.exempt,
        isGstRegistered: true,
        customerIsGstRegistered: false,
      );

      expect(result.gstRate, equals(0.0));
      expect(result.gstAmount, equals(0.0));
      expect(result.totalAmount, equals(100.0));
      expect(result.isGstApplicable, isFalse);
      expect(result.reasoning, contains('Exempt supply'));
    });

    test('should not apply GST for zero-rated items', () {
      final result = SingaporeGstService.calculateGst(
        amount: 100.0,
        calculationDate: DateTime(2024, 6, 1),
        taxCategory: GstTaxCategory.zeroRated,
        isGstRegistered: true,
        customerIsGstRegistered: false,
      );

      expect(result.gstRate, equals(0.0));
      expect(result.gstAmount, equals(0.0));
      expect(result.totalAmount, equals(100.0));
      expect(result.isGstApplicable, isFalse);
      expect(result.reasoning, contains('Zero-rated supply'));
    });

    test('should not apply GST for exports', () {
      final result = SingaporeGstService.calculateGst(
        amount: 100.0,
        calculationDate: DateTime(2024, 6, 1),
        taxCategory: GstTaxCategory.standard,
        isGstRegistered: true,
        customerIsGstRegistered: false,
        isExport: true,
        customerCountry: 'US',
      );

      expect(result.gstRate, equals(0.0));
      expect(result.gstAmount, equals(0.0));
      expect(result.totalAmount, equals(100.0));
      expect(result.isGstApplicable, isFalse);
      expect(result.reasoning, contains('Zero-rated export'));
    });

    test('should not apply GST when company is not GST registered', () {
      final result = SingaporeGstService.calculateGst(
        amount: 100.0,
        calculationDate: DateTime(2024, 6, 1),
        taxCategory: GstTaxCategory.standard,
        isGstRegistered: false,
        customerIsGstRegistered: false,
      );

      expect(result.gstRate, equals(0.0));
      expect(result.gstAmount, equals(0.0));
      expect(result.totalAmount, equals(100.0));
      expect(result.isGstApplicable, isFalse);
      expect(result.reasoning, contains('Company not GST registered'));
    });

    test('should calculate GST inclusive correctly', () {
      final result = SingaporeGstService.calculateGstInclusive(
        totalAmount: 109.0,
        calculationDate: DateTime(2024, 6, 1),
        taxCategory: GstTaxCategory.standard,
        isGstRegistered: true,
        customerIsGstRegistered: false,
      );

      expect(result.netAmount, closeTo(100.0, 0.01));
      expect(result.gstRate, equals(0.09));
      expect(result.gstAmount, closeTo(9.0, 0.01));
      expect(result.totalAmount, equals(109.0));
    });

    test('should calculate import GST with duty', () {
      final result = SingaporeGstService.calculateImportGst(
        cif: 1000.0,
        dutyAmount: 100.0,
        calculationDate: DateTime(2024, 6, 1),
      );

      expect(result.netAmount, equals(1100.0)); // CIF + Duty
      expect(result.gstRate, equals(0.09));
      expect(result.gstAmount, equals(99.0)); // 9% of 1100
      expect(result.totalAmount, equals(1199.0)); // CIF + Duty + GST
      expect(result.reasoning, contains('Import GST'));
    });
  });

  group('Singapore CPF Service Tests', () {
    test('should calculate CPF correctly for employee below 55', () {
      final result = SingaporeCpfService.calculateCpfContributions(
        dateOfBirth: DateTime(1990, 1, 1), // 34 years old
        residencyStatus: 'citizen',
        ordinaryWage: 5000.0,
        additionalWage: 0.0,
        calculationDate: DateTime(2024, 6, 1),
      );

      expect(result.isEligible, isTrue);
      expect(result.employeeRate, equals(0.20)); // 20%
      expect(result.employerRate, equals(0.17)); // 17%
      expect(result.employeeContribution, equals(1000.0)); // 20% of 5000
      expect(result.employerContribution, equals(850.0)); // 17% of 5000
      expect(result.totalContribution, equals(1850.0));
      expect(result.ageCategory, equals(CpfAgeCategory.below55));
    });

    test('should calculate CPF correctly for employee 55-60', () {
      final result = SingaporeCpfService.calculateCpfContributions(
        dateOfBirth: DateTime(1967, 1, 1), // 57 years old
        residencyStatus: 'citizen',
        ordinaryWage: 4000.0,
        additionalWage: 0.0,
        calculationDate: DateTime(2024, 6, 1),
      );

      expect(result.isEligible, isTrue);
      expect(result.employeeRate, equals(0.13)); // 13%
      expect(result.employerRate, equals(0.13)); // 13%
      expect(result.employeeContribution, equals(520.0)); // 13% of 4000
      expect(result.employerContribution, equals(520.0)); // 13% of 4000
      expect(result.totalContribution, equals(1040.0));
      expect(result.ageCategory, equals(CpfAgeCategory.age55to60));
    });

    test('should calculate CPF correctly for employee 60-65', () {
      final result = SingaporeCpfService.calculateCpfContributions(
        dateOfBirth: DateTime(1962, 1, 1), // 62 years old
        residencyStatus: 'citizen',
        ordinaryWage: 3000.0,
        additionalWage: 0.0,
        calculationDate: DateTime(2024, 6, 1),
      );

      expect(result.isEligible, isTrue);
      expect(result.employeeRate, equals(0.075)); // 7.5%
      expect(result.employerRate, equals(0.09)); // 9%
      expect(result.employeeContribution, equals(225.0)); // 7.5% of 3000
      expect(result.employerContribution, equals(270.0)); // 9% of 3000
      expect(result.totalContribution, equals(495.0));
      expect(result.ageCategory, equals(CpfAgeCategory.age60to65));
    });

    test('should calculate CPF correctly for employee above 65', () {
      final result = SingaporeCpfService.calculateCpfContributions(
        dateOfBirth: DateTime(1955, 1, 1), // 69 years old
        residencyStatus: 'citizen',
        ordinaryWage: 2000.0,
        additionalWage: 0.0,
        calculationDate: DateTime(2024, 6, 1),
      );

      expect(result.isEligible, isTrue);
      expect(result.employeeRate, equals(0.05)); // 5%
      expect(result.employerRate, equals(0.075)); // 7.5%
      expect(result.employeeContribution, equals(100.0)); // 5% of 2000
      expect(result.employerContribution, equals(150.0)); // 7.5% of 2000
      expect(result.totalContribution, equals(250.0));
      expect(result.ageCategory, equals(CpfAgeCategory.above65));
    });

    test('should not calculate CPF for employee 70 and above', () {
      final result = SingaporeCpfService.calculateCpfContributions(
        dateOfBirth: DateTime(1950, 1, 1), // 74 years old
        residencyStatus: 'citizen',
        ordinaryWage: 2000.0,
        additionalWage: 0.0,
        calculationDate: DateTime(2024, 6, 1),
      );

      expect(result.isEligible, isFalse);
      expect(result.employeeContribution, equals(0.0));
      expect(result.employerContribution, equals(0.0));
      expect(result.totalContribution, equals(0.0));
      expect(result.reasoning, contains('70 years or older'));
    });

    test('should not calculate CPF for non-residents', () {
      final result = SingaporeCpfService.calculateCpfContributions(
        dateOfBirth: DateTime(1990, 1, 1),
        residencyStatus: 'non_resident',
        ordinaryWage: 5000.0,
        additionalWage: 0.0,
        calculationDate: DateTime(2024, 6, 1),
      );

      expect(result.isEligible, isFalse);
      expect(result.employeeContribution, equals(0.0));
      expect(result.employerContribution, equals(0.0));
      expect(result.totalContribution, equals(0.0));
      expect(result.reasoning, contains('Non-resident'));
    });

    test('should calculate reduced CPF for new PRs (first 2 years)', () {
      final result = SingaporeCpfService.calculateCpfContributions(
        dateOfBirth: DateTime(1990, 1, 1), // 34 years old
        residencyStatus: 'pr_first_2_years',
        ordinaryWage: 5000.0,
        additionalWage: 0.0,
        calculationDate: DateTime(2024, 6, 1),
      );

      expect(result.isEligible, isTrue);
      expect(result.employeeRate, equals(0.05)); // 5%
      expect(result.employerRate, equals(0.04)); // 4%
      expect(result.employeeContribution, equals(250.0)); // 5% of 5000
      expect(result.employerContribution, equals(200.0)); // 4% of 5000
      expect(result.totalContribution, equals(450.0));
    });

    test('should apply CPF ordinary wage ceiling', () {
      final result = SingaporeCpfService.calculateCpfContributions(
        dateOfBirth: DateTime(1990, 1, 1), // 34 years old
        residencyStatus: 'citizen',
        ordinaryWage: 8000.0, // Above S$6,000 ceiling
        additionalWage: 0.0,
        calculationDate: DateTime(2024, 6, 1),
      );

      expect(result.isEligible, isTrue);
      expect(result.cappedOrdinaryWage, equals(6000.0));
      expect(result.employeeContribution, equals(1200.0)); // 20% of 6000
      expect(result.employerContribution, equals(1020.0)); // 17% of 6000
      expect(result.totalContribution, equals(2220.0));
      expect(result.additionalInfo!['ow_ceiling_applied'], isTrue);
    });

    test('should handle additional wage with annual ceiling', () {
      final result = SingaporeCpfService.calculateCpfContributions(
        dateOfBirth: DateTime(1990, 1, 1), // 34 years old
        residencyStatus: 'citizen',
        ordinaryWage: 5000.0,
        additionalWage: 10000.0,
        calculationDate: DateTime(2024, 6, 1),
        existingCpfForYear: 50000.0, // Already contributed S$50k this year
      );

      expect(result.isEligible, isTrue);
      // OW contribution: 20% + 17% of 5000 = 1850
      expect(result.employeeContribution, greaterThan(1000.0));
      expect(result.employerContribution, greaterThan(850.0));

      // Should cap AW based on remaining ceiling
      final remainingCeiling = 102000.0 - 50000.0; // S$52k remaining
      expect(result.cappedAdditionalWage, equals(remainingCeiling));
    });

    test('should calculate account breakdown correctly', () {
      final result = SingaporeCpfService.calculateCpfContributions(
        dateOfBirth: DateTime(1990, 1, 1), // 34 years old
        residencyStatus: 'citizen',
        ordinaryWage: 3000.0,
        additionalWage: 0.0,
        calculationDate: DateTime(2024, 6, 1),
      );

      expect(result.isEligible, isTrue);
      expect(result.totalContribution, equals(1110.0)); // 37% of 3000

      // Check account allocation (below 55 rates)
      expect(
          result.breakdown.ordinaryAccount, closeTo(689.976, 0.01)); // ~62.16%
      expect(
          result.breakdown.specialAccount, closeTo(179.442, 0.01)); // ~16.22%
      expect(
          result.breakdown.medisaveAccount, closeTo(239.982, 0.01)); // ~21.62%
      expect(result.breakdown.totalContribution, equals(1110.0));
    });

    test('should calculate annual projection correctly', () {
      final projection = SingaporeCpfService.calculateAnnualProjection(
        monthlyOrdinaryWage: 4000.0,
        estimatedAnnualBonus: 8000.0,
        dateOfBirth: DateTime(1990, 1, 1), // 34 years old
        residencyStatus: 'citizen',
        projectionYear: 2024,
      );

      expect(projection.projectionYear, equals(2024));
      // Monthly: 37% of 4000 = 1480, Annual: 1480 * 12 = 17760
      expect(projection.monthlyContribution, equals(1480.0));
      // Bonus: 37% of 8000 = 2960
      expect(projection.bonusContribution, equals(2960.0));
      expect(
          projection.annualTotalContribution, equals(20720.0)); // 17760 + 2960
    });
  });

  group('Integration Tests', () {
    test('should calculate complete payroll with GST and CPF', () {
      // Employee earning S$5,000/month, 30 years old, Singapore citizen
      final cpfResult = SingaporeCpfService.calculateCpfContributions(
        dateOfBirth: DateTime(1994, 1, 1),
        residencyStatus: 'citizen',
        ordinaryWage: 5000.0,
        additionalWage: 0.0,
        calculationDate: DateTime(2024, 6, 1),
      );

      // Company providing services to local customer
      final gstResult = SingaporeGstService.calculateGst(
        amount: 10000.0, // Monthly revenue
        calculationDate: DateTime(2024, 6, 1),
        taxCategory: GstTaxCategory.standard,
        isGstRegistered: true,
        customerIsGstRegistered: false,
      );

      // Verify CPF calculations
      expect(cpfResult.isEligible, isTrue);
      expect(cpfResult.totalContribution, equals(1850.0)); // 37% of 5000
      expect(cpfResult.employeeContribution, equals(1000.0)); // 20% of 5000
      expect(cpfResult.employerContribution, equals(850.0)); // 17% of 5000

      // Verify GST calculations
      expect(gstResult.isGstApplicable, isTrue);
      expect(gstResult.gstAmount, equals(900.0)); // 9% of 10000
      expect(gstResult.totalAmount, equals(10900.0));

      // Calculate net payroll impact
      final grossSalary = 5000.0;
      final netSalary = grossSalary - cpfResult.employeeContribution; // 4000
      final employerCost = grossSalary + cpfResult.employerContribution; // 5850

      expect(netSalary, equals(4000.0));
      expect(employerCost, equals(5850.0));
    });

    test('should handle export scenario with CPF but no GST', () {
      // Singaporean employee working for export company
      final cpfResult = SingaporeCpfService.calculateCpfContributions(
        dateOfBirth: DateTime(1985, 1, 1), // 39 years old
        residencyStatus: 'citizen',
        ordinaryWage: 6000.0, // At CPF ceiling
        additionalWage: 0.0,
        calculationDate: DateTime(2024, 6, 1),
      );

      // Company exporting services (zero-rated for GST)
      final gstResult = SingaporeGstService.calculateGst(
        amount: 50000.0,
        calculationDate: DateTime(2024, 6, 1),
        taxCategory: GstTaxCategory.standard,
        isGstRegistered: true,
        customerIsGstRegistered: false,
        isExport: true,
        customerCountry: 'US',
      );

      // CPF should apply normally
      expect(cpfResult.isEligible, isTrue);
      expect(cpfResult.cappedOrdinaryWage, equals(6000.0));
      expect(cpfResult.totalContribution, equals(2220.0)); // 37% of 6000

      // GST should not apply for exports
      expect(gstResult.isGstApplicable, isFalse);
      expect(gstResult.gstAmount, equals(0.0));
      expect(gstResult.totalAmount, equals(50000.0));
      expect(gstResult.reasoning, contains('Zero-rated export'));
    });

    test('should handle foreign worker with work permit', () {
      // Foreign worker on Work Permit (not eligible for CPF)
      final cpfResult = SingaporeCpfService.calculateCpfContributions(
        dateOfBirth: DateTime(1992, 1, 1), // 32 years old
        residencyStatus: 'non_resident',
        ordinaryWage: 3000.0,
        additionalWage: 0.0,
        calculationDate: DateTime(2024, 6, 1),
      );

      // Company providing services (GST applicable)
      final gstResult = SingaporeGstService.calculateGst(
        amount: 5000.0,
        calculationDate: DateTime(2024, 6, 1),
        taxCategory: GstTaxCategory.standard,
        isGstRegistered: true,
        customerIsGstRegistered: false,
      );

      // No CPF for foreign workers
      expect(cpfResult.isEligible, isFalse);
      expect(cpfResult.totalContribution, equals(0.0));
      expect(cpfResult.reasoning, contains('Non-resident'));

      // GST should still apply to business transactions
      expect(gstResult.isGstApplicable, isTrue);
      expect(gstResult.gstAmount, equals(450.0)); // 9% of 5000
      expect(gstResult.totalAmount, equals(5450.0));
    });
  });

  group('Edge Cases and Validation', () {
    test('should handle zero amounts correctly', () {
      final gstResult = SingaporeGstService.calculateGst(
        amount: 0.0,
        calculationDate: DateTime(2024, 6, 1),
        taxCategory: GstTaxCategory.standard,
        isGstRegistered: true,
        customerIsGstRegistered: false,
      );

      expect(gstResult.gstAmount, equals(0.0));
      expect(gstResult.totalAmount, equals(0.0));
    });

    test('should handle negative amounts gracefully', () {
      expect(
          () => SingaporeGstService.calculateGst(
                amount: -100.0,
                calculationDate: DateTime(2024, 6, 1),
                taxCategory: GstTaxCategory.standard,
                isGstRegistered: true,
                customerIsGstRegistered: false,
              ),
          returnsNormally);
    });

    test('should validate GST registration number format', () {
      final validation = SingaporeGstService.validateGstInvoice(
        invoiceNumber: 'INV-001',
        invoiceDate: DateTime(2024, 6, 1),
        supplierName: 'Test Company Pte Ltd',
        supplierGstNumber: '200012345M',
        customerName: 'Customer Pte Ltd',
        netAmount: 100.0,
        gstAmount: 9.0,
        totalAmount: 109.0,
      );

      expect(validation.isValid, isTrue);
      expect(validation.errors, isEmpty);
    });

    test('should reject invalid GST registration number', () {
      final validation = SingaporeGstService.validateGstInvoice(
        invoiceNumber: 'INV-001',
        invoiceDate: DateTime(2024, 6, 1),
        supplierName: 'Test Company Pte Ltd',
        supplierGstNumber: 'INVALID123',
        customerName: 'Customer Pte Ltd',
        netAmount: 100.0,
        gstAmount: 9.0,
        totalAmount: 109.0,
      );

      expect(validation.isValid, isFalse);
      expect(validation.errors,
          contains('Invalid GST registration number format'));
    });

    test('should detect amount calculation inconsistencies', () {
      final validation = SingaporeGstService.validateGstInvoice(
        invoiceNumber: 'INV-001',
        invoiceDate: DateTime(2024, 6, 1),
        supplierName: 'Test Company Pte Ltd',
        supplierGstNumber: '200012345M',
        customerName: 'Customer Pte Ltd',
        netAmount: 100.0,
        gstAmount: 9.0,
        totalAmount: 120.0, // Incorrect total
      );

      expect(validation.isValid, isFalse);
      expect(validation.errors,
          contains('Amount calculation inconsistency detected'));
    });
  });
}
