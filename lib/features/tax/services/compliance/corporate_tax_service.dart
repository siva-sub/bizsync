import '../../models/company/company_tax_profile.dart';
import '../../models/relief/tax_relief_model.dart';

enum TaxFormType {
  formC, // For companies with revenue > S$5M
  formCS, // For small companies with revenue ≤ S$5M
  formCSlite, // Simplified form for eligible small companies
}

enum AssessmentStatus {
  draft,
  submitted,
  accepted,
  underReview,
  amended,
  objected,
  finalized,
}

class TaxableIncome {
  final double revenue;
  final double costOfSales;
  final double grossProfit;
  final double operatingExpenses;
  final double ebitda;
  final double depreciation;
  final double ebit;
  final double interestExpense;
  final double profitBeforeTax;
  final double taxAdjustments;
  final double chargeableIncome;

  TaxableIncome({
    required this.revenue,
    required this.costOfSales,
    required this.grossProfit,
    required this.operatingExpenses,
    required this.ebitda,
    required this.depreciation,
    required this.ebit,
    required this.interestExpense,
    required this.profitBeforeTax,
    required this.taxAdjustments,
    required this.chargeableIncome,
  });

  Map<String, dynamic> toJson() => {
    'revenue': revenue,
    'costOfSales': costOfSales,
    'grossProfit': grossProfit,
    'operatingExpenses': operatingExpenses,
    'ebitda': ebitda,
    'depreciation': depreciation,
    'ebit': ebit,
    'interestExpense': interestExpense,
    'profitBeforeTax': profitBeforeTax,
    'taxAdjustments': taxAdjustments,
    'chargeableIncome': chargeableIncome,
  };
}

class TaxAdjustment {
  final String id;
  final String description;
  final double amount;
  final String type; // 'addition', 'deduction'
  final String category; // 'disallowed_expense', 'non_taxable_income', etc.
  final String? legislation;
  final String? remarks;

  TaxAdjustment({
    required this.id,
    required this.description,
    required this.amount,
    required this.type,
    required this.category,
    this.legislation,
    this.remarks,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'amount': amount,
    'type': type,
    'category': category,
    'legislation': legislation,
    'remarks': remarks,
  };
}

class CorporateTaxComputation {
  final String assessmentYear;
  final TaxableIncome income;
  final List<TaxAdjustment> adjustments;
  final List<TaxRelief> reliefs;
  final double chargeableIncome;
  final List<TaxBracket> taxBrackets;
  final double totalTax;
  final double effectiveTaxRate;
  final double estimatedPayments;
  final double balanceDue;

  CorporateTaxComputation({
    required this.assessmentYear,
    required this.income,
    required this.adjustments,
    required this.reliefs,
    required this.chargeableIncome,
    required this.taxBrackets,
    required this.totalTax,
    required this.effectiveTaxRate,
    required this.estimatedPayments,
    required this.balanceDue,
  });
}

class TaxBracket {
  final String description;
  final double lowerBound;
  final double upperBound;
  final double rate;
  final double taxableAmount;
  final double taxAmount;

  TaxBracket({
    required this.description,
    required this.lowerBound,
    required this.upperBound,
    required this.rate,
    required this.taxableAmount,
    required this.taxAmount,
  });

  Map<String, dynamic> toJson() => {
    'description': description,
    'lowerBound': lowerBound,
    'upperBound': upperBound,
    'rate': rate,
    'taxableAmount': taxableAmount,
    'taxAmount': taxAmount,
  };
}

class CorporateTaxReturn {
  final String id;
  final String assessmentYear;
  final CompanyTaxProfile companyProfile;
  final TaxFormType formType;
  final CorporateTaxComputation computation;
  final AssessmentStatus status;
  final DateTime createdDate;
  final DateTime? submittedDate;
  final DateTime dueDate;
  final List<String> supportingDocuments;
  final Map<String, dynamic> irasData;

  CorporateTaxReturn({
    required this.id,
    required this.assessmentYear,
    required this.companyProfile,
    required this.formType,
    required this.computation,
    required this.status,
    required this.createdDate,
    this.submittedDate,
    required this.dueDate,
    this.supportingDocuments = const [],
    this.irasData = const {},
  });
}

class CorporateTaxService {
  Future<CorporateTaxComputation> computeCorporateTax({
    required CompanyTaxProfile companyProfile,
    required String assessmentYear,
    required Map<String, double> financialData,
    required List<TaxAdjustment> adjustments,
    double estimatedPayments = 0,
  }) async {
    // Calculate taxable income
    final income = _calculateTaxableIncome(financialData, adjustments);
    
    // Get applicable reliefs
    final reliefs = await _getApplicableReliefs(companyProfile, assessmentYear);
    
    // Apply reliefs to get chargeable income
    final chargeableIncome = _applyReliefs(income.chargeableIncome, reliefs);
    
    // Calculate tax brackets
    final taxBrackets = _calculateTaxBrackets(chargeableIncome, companyProfile);
    
    // Calculate total tax
    final totalTax = taxBrackets.fold<double>(0, (sum, bracket) => sum + bracket.taxAmount);
    
    // Calculate effective tax rate
    final effectiveTaxRate = income.chargeableIncome > 0 ? totalTax / income.chargeableIncome : 0;
    
    // Calculate balance due
    final balanceDue = totalTax - estimatedPayments;

    return CorporateTaxComputation(
      assessmentYear: assessmentYear,
      income: income,
      adjustments: adjustments,
      reliefs: reliefs,
      chargeableIncome: chargeableIncome,
      taxBrackets: taxBrackets,
      totalTax: totalTax,
      effectiveTaxRate: effectiveTaxRate,
      estimatedPayments: estimatedPayments,
      balanceDue: balanceDue,
    );
  }

  Future<TaxFormType> determineFormType(CompanyTaxProfile profile, double revenue) async {
    // Form C-S Lite: Eligible small companies
    if (revenue <= 200000 && _isEligibleForFormCSLite(profile)) {
      return TaxFormType.formCSlite;
    }
    
    // Form C-S: Small companies
    if (revenue <= 5000000) {
      return TaxFormType.formCS;
    }
    
    // Form C: Large companies
    return TaxFormType.formC;
  }

  Future<Map<String, dynamic>> generateTaxReturnData({
    required CorporateTaxReturn taxReturn,
  }) async {
    final computation = taxReturn.computation;
    
    return {
      'formType': taxReturn.formType.name.toUpperCase(),
      'assessmentYear': taxReturn.assessmentYear,
      'company': {
        'name': taxReturn.companyProfile.companyName,
        'registrationNumber': taxReturn.companyProfile.registrationNumber,
        'gstNumber': taxReturn.companyProfile.gstNumber,
        'companyType': taxReturn.companyProfile.companyType.name,
        'incorporationDate': taxReturn.companyProfile.incorporationDate.toIso8601String(),
        'financialYearEnd': taxReturn.companyProfile.financialYearEnd.toIso8601String(),
      },
      'income': computation.income.toJson(),
      'adjustments': computation.adjustments.map((adj) => adj.toJson()).toList(),
      'reliefs': computation.reliefs.map((relief) => {
        'name': relief.name,
        'type': relief.reliefType.name,
        'amount': relief.reliefAmount,
        'legislation': relief.legislation,
      }).toList(),
      'computation': {
        'chargeableIncome': computation.chargeableIncome,
        'taxBrackets': computation.taxBrackets.map((bracket) => bracket.toJson()).toList(),
        'totalTax': computation.totalTax,
        'effectiveTaxRate': computation.effectiveTaxRate,
        'estimatedPayments': computation.estimatedPayments,
        'balanceDue': computation.balanceDue,
      },
      'dueDate': taxReturn.dueDate.toIso8601String(),
      'generatedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<List<String>> validateTaxReturn(CorporateTaxReturn taxReturn) async {
    final errors = <String>[];
    final computation = taxReturn.computation;
    
    // Basic validation
    if (computation.chargeableIncome < 0) {
      errors.add('Chargeable income cannot be negative');
    }
    
    if (computation.totalTax < 0) {
      errors.add('Total tax cannot be negative');
    }
    
    // Check if tax computation is reasonable
    if (computation.effectiveTaxRate > 0.20) {
      errors.add('Effective tax rate seems unusually high (>${computation.effectiveTaxRate * 100}%)');
    }
    
    // Check due date
    if (taxReturn.dueDate.isBefore(DateTime.now())) {
      errors.add('Tax return is past due date');
    }
    
    // Validate adjustments
    for (final adjustment in computation.adjustments) {
      if (adjustment.amount == 0) {
        errors.add('Tax adjustment "${adjustment.description}" has zero amount');
      }
    }
    
    // Check for required documents based on form type
    final requiredDocs = _getRequiredDocuments(taxReturn.formType, computation.income.revenue);
    for (final doc in requiredDocs) {
      if (!taxReturn.supportingDocuments.contains(doc)) {
        errors.add('Missing required document: $doc');
      }
    }
    
    return errors;
  }

  Future<Map<String, dynamic>> generateIrasSubmissionFormat(CorporateTaxReturn taxReturn) async {
    // Generate data in IRAS-compatible format
    final computation = taxReturn.computation;
    
    return {
      'CorpPassId': taxReturn.companyProfile.registrationNumber,
      'AssessmentYear': taxReturn.assessmentYear,
      'FormType': taxReturn.formType.name.toUpperCase(),
      'CompanyName': taxReturn.companyProfile.companyName,
      'Revenue': computation.income.revenue,
      'ProfitBeforeTax': computation.income.profitBeforeTax,
      'TaxAdjustments': computation.income.taxAdjustments,
      'ChargeableIncome': computation.chargeableIncome,
      'TotalTax': computation.totalTax,
      'EstimatedPayments': computation.estimatedPayments,
      'BalanceDue': computation.balanceDue,
      'TaxBrackets': computation.taxBrackets.map((bracket) => {
        'Rate': bracket.rate,
        'TaxableAmount': bracket.taxableAmount,
        'TaxAmount': bracket.taxAmount,
      }).toList(),
      'Reliefs': computation.reliefs.map((relief) => {
        'ReliefCode': _getReliefCode(relief.reliefType),
        'Amount': relief.reliefAmount,
      }).toList(),
      'SubmissionDate': DateTime.now().toIso8601String(),
    };
  }

  TaxableIncome _calculateTaxableIncome(Map<String, double> financialData, List<TaxAdjustment> adjustments) {
    final revenue = financialData['revenue'] ?? 0;
    final costOfSales = financialData['costOfSales'] ?? 0;
    final grossProfit = revenue - costOfSales;
    final operatingExpenses = financialData['operatingExpenses'] ?? 0;
    final ebitda = grossProfit - operatingExpenses;
    final depreciation = financialData['depreciation'] ?? 0;
    final ebit = ebitda - depreciation;
    final interestExpense = financialData['interestExpense'] ?? 0;
    final profitBeforeTax = ebit - interestExpense;
    
    // Apply tax adjustments
    final additions = adjustments
        .where((adj) => adj.type == 'addition')
        .fold<double>(0, (sum, adj) => sum + adj.amount);
    
    final deductions = adjustments
        .where((adj) => adj.type == 'deduction')
        .fold<double>(0, (sum, adj) => sum + adj.amount);
    
    final taxAdjustments = additions - deductions;
    final chargeableIncome = profitBeforeTax + taxAdjustments;

    return TaxableIncome(
      revenue: revenue,
      costOfSales: costOfSales,
      grossProfit: grossProfit,
      operatingExpenses: operatingExpenses,
      ebitda: ebitda,
      depreciation: depreciation,
      ebit: ebit,
      interestExpense: interestExpense,
      profitBeforeTax: profitBeforeTax,
      taxAdjustments: taxAdjustments,
      chargeableIncome: chargeableIncome,
    );
  }

  Future<List<TaxRelief>> _getApplicableReliefs(CompanyTaxProfile profile, String assessmentYear) async {
    final reliefs = <TaxRelief>[];
    
    // Startup exemption
    if (profile.companyType == CompanyType.startup && profile.isEligibleForStartupExemption()) {
      reliefs.add(TaxRelief(
        id: 'startup_exemption',
        name: 'Startup Tax Exemption',
        reliefType: ReliefType.startupExemption,
        description: 'Tax exemption for qualifying new companies',
        reliefAmount: 100000,
        applicableTaxType: TaxType.corporateTax,
        effectiveFrom: DateTime.now(),
        legislation: 'Income Tax Act Section 43A',
      ));
    }
    
    // Partial exemption
    if (profile.isQualifiedForPartialExemption()) {
      reliefs.add(TaxRelief(
        id: 'partial_exemption',
        name: 'Partial Tax Exemption',
        reliefType: ReliefType.partialExemption,
        description: 'Partial exemption for qualifying companies',
        reliefAmount: 200000,
        applicableTaxType: TaxType.corporateTax,
        effectiveFrom: DateTime.now(),
        legislation: 'Income Tax Act Section 43B',
      ));
    }
    
    return reliefs;
  }

  double _applyReliefs(double chargeableIncome, List<TaxRelief> reliefs) {
    double adjustedIncome = chargeableIncome;
    
    for (final relief in reliefs) {
      switch (relief.reliefType) {
        case ReliefType.startupExemption:
          if (adjustedIncome > 100000) {
            adjustedIncome -= 100000; // First S$100k exempt
          } else {
            adjustedIncome = 0;
          }
          break;
        case ReliefType.partialExemption:
          // Already handled in tax bracket calculation
          break;
        default:
          break;
      }
    }
    
    return adjustedIncome;
  }

  List<TaxBracket> _calculateTaxBrackets(double chargeableIncome, CompanyTaxProfile profile) {
    final brackets = <TaxBracket>[];
    double remainingIncome = chargeableIncome;
    
    if (profile.companyType == CompanyType.startup && profile.isEligibleForStartupExemption()) {
      // Startup exemption brackets
      if (remainingIncome > 0) {
        final exemptAmount = remainingIncome > 100000 ? 100000 : remainingIncome;
        brackets.add(TaxBracket(
          description: 'Startup Exemption - First S\$100,000',
          lowerBound: 0,
          upperBound: 100000,
          rate: 0,
          taxableAmount: exemptAmount,
          taxAmount: 0,
        ));
        remainingIncome -= exemptAmount;
      }
      
      if (remainingIncome > 0) {
        final partialAmount = remainingIncome > 200000 ? 200000 : remainingIncome;
        brackets.add(TaxBracket(
          description: 'Startup Partial Exemption - Next S\$200,000 at 8.5%',
          lowerBound: 100000,
          upperBound: 300000,
          rate: 0.085,
          taxableAmount: partialAmount,
          taxAmount: partialAmount * 0.085,
        ));
        remainingIncome -= partialAmount;
      }
    } else if (profile.isQualifiedForPartialExemption()) {
      // Partial exemption brackets
      if (remainingIncome > 0) {
        final exemptAmount = remainingIncome > 10000 ? 10000 : remainingIncome;
        brackets.add(TaxBracket(
          description: 'Partial Exemption - First S\$10,000',
          lowerBound: 0,
          upperBound: 10000,
          rate: 0,
          taxableAmount: exemptAmount,
          taxAmount: 0,
        ));
        remainingIncome -= exemptAmount;
      }
      
      if (remainingIncome > 0) {
        final partialAmount = remainingIncome > 190000 ? 190000 : remainingIncome;
        brackets.add(TaxBracket(
          description: 'Partial Exemption - Next S\$190,000 at 8.5%',
          lowerBound: 10000,
          upperBound: 200000,
          rate: 0.085,
          taxableAmount: partialAmount,
          taxAmount: partialAmount * 0.085,
        ));
        remainingIncome -= partialAmount;
      }
    }
    
    // Standard rate for remaining income
    if (remainingIncome > 0) {
      brackets.add(TaxBracket(
        description: 'Standard Corporate Tax Rate 17%',
        lowerBound: chargeableIncome - remainingIncome,
        upperBound: double.infinity,
        rate: 0.17,
        taxableAmount: remainingIncome,
        taxAmount: remainingIncome * 0.17,
      ));
    }
    
    return brackets;
  }

  bool _isEligibleForFormCSLite(CompanyTaxProfile profile) {
    // Eligibility criteria for Form C-S Lite
    return profile.companyType == CompanyType.privateLimited &&
           profile.status == CompanyStatus.active &&
           !profile.isGstRegistered; // Simplified criteria
  }

  List<String> _getRequiredDocuments(TaxFormType formType, double revenue) {
    final docs = <String>[];
    
    switch (formType) {
      case TaxFormType.formC:
        docs.addAll([
          'Audited Financial Statements',
          'Director\'s Report',
          'Tax Computation',
          'Supporting Schedules',
        ]);
        break;
      case TaxFormType.formCS:
        docs.addAll([
          'Unaudited Financial Statements',
          'Tax Computation',
        ]);
        if (revenue > 1000000) {
          docs.add('Review Report by Public Accountant');
        }
        break;
      case TaxFormType.formCSlite:
        docs.addAll([
          'Basic Financial Information',
          'Bank Statements',
        ]);
        break;
    }
    
    return docs;
  }

  String _getReliefCode(ReliefType reliefType) {
    switch (reliefType) {
      case ReliefType.startupExemption:
        return 'SE';
      case ReliefType.partialExemption:
        return 'PE';
      case ReliefType.researchDevelopmentRelief:
        return 'RD';
      case ReliefType.doubleDeductionRelief:
        return 'DD';
      default:
        return 'OT'; // Other
    }
  }

  Future<DateTime> calculateFilingDueDate(DateTime financialYearEnd) async {
    // Corporate tax return is due 3 months after financial year end
    return DateTime(
      financialYearEnd.year,
      financialYearEnd.month + 3,
      financialYearEnd.day,
    );
  }

  Future<Map<String, dynamic>> getTaxProjection({
    required CompanyTaxProfile profile,
    required double projectedIncome,
    required String assessmentYear,
  }) async {
    final computation = await computeCorporateTax(
      companyProfile: profile,
      assessmentYear: assessmentYear,
      financialData: {'revenue': projectedIncome, 'profitBeforeTax': projectedIncome},
      adjustments: [],
    );
    
    return {
      'projectedIncome': projectedIncome,
      'projectedTax': computation.totalTax,
      'effectiveRate': computation.effectiveTaxRate,
      'taxBrackets': computation.taxBrackets.map((b) => b.toJson()).toList(),
      'recommendations': _generateTaxRecommendations(profile, computation),
    };
  }

  List<String> _generateTaxRecommendations(CompanyTaxProfile profile, CorporateTaxComputation computation) {
    final recommendations = <String>[];
    
    if (computation.effectiveTaxRate > 0.15) {
      recommendations.add('Consider tax planning strategies to optimize effective tax rate');
    }
    
    if (profile.companyType != CompanyType.startup && computation.chargeableIncome < 300000) {
      recommendations.add('Consider startup status if eligible to benefit from startup exemptions');
    }
    
    if (!profile.isGstRegistered && computation.income.revenue > 800000) {
      recommendations.add('Consider voluntary GST registration as revenue approaches S\$1M threshold');
    }
    
    recommendations.add('Ensure proper documentation of all deductible expenses');
    recommendations.add('Consider timing of income and expenses for tax optimization');
    
    return recommendations;
  }
}