import 'dart:convert';
import 'dart:typed_data';
import '../../models/company/company_tax_profile.dart';

enum GstReturnPeriod {
  monthly,
  quarterly,
  annually,
}

enum GstReturnStatus {
  draft,
  pending,
  submitted,
  accepted,
  rejected,
}

class GstTransaction {
  final String id;
  final DateTime transactionDate;
  final String description;
  final double amount;
  final double gstAmount;
  final String gstRate;
  final String
      transactionType; // 'standard', 'zero-rated', 'exempt', 'out-of-scope'
  final String customerSupplier;
  final String? invoiceNumber;
  final String? scheme; // 'standard', 'retail', 'margin'

  GstTransaction({
    required this.id,
    required this.transactionDate,
    required this.description,
    required this.amount,
    required this.gstAmount,
    required this.gstRate,
    required this.transactionType,
    required this.customerSupplier,
    this.invoiceNumber,
    this.scheme,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'transactionDate': transactionDate.toIso8601String(),
        'description': description,
        'amount': amount,
        'gstAmount': gstAmount,
        'gstRate': gstRate,
        'transactionType': transactionType,
        'customerSupplier': customerSupplier,
        'invoiceNumber': invoiceNumber,
        'scheme': scheme,
      };

  factory GstTransaction.fromJson(Map<String, dynamic> json) => GstTransaction(
        id: json['id'],
        transactionDate: DateTime.parse(json['transactionDate']),
        description: json['description'],
        amount: json['amount'],
        gstAmount: json['gstAmount'],
        gstRate: json['gstRate'],
        transactionType: json['transactionType'],
        customerSupplier: json['customerSupplier'],
        invoiceNumber: json['invoiceNumber'],
        scheme: json['scheme'],
      );
}

class GstF5Data {
  final String returnPeriod;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime dueDate;

  // Box 1: Total value of standard-rated supplies
  final double box1StandardRatedSupplies;

  // Box 2: Total value of zero-rated supplies
  final double box2ZeroRatedSupplies;

  // Box 3: Total value of exempt supplies
  final double box3ExemptSupplies;

  // Box 4: Total value of supplies (Box 1 + 2 + 3)
  final double box4TotalSupplies;

  // Box 5: Total GST charged on supplies (output tax)
  final double box5OutputTax;

  // Box 6: Total value of standard-rated purchases
  final double box6StandardRatedPurchases;

  // Box 7: Total value of zero-rated purchases
  final double box7ZeroRatedPurchases;

  // Box 8: Total value of exempt purchases
  final double box8ExemptPurchases;

  // Box 9: Total value of purchases (Box 6 + 7 + 8)
  final double box9TotalPurchases;

  // Box 10: Total GST charged on purchases (input tax)
  final double box10InputTax;

  // Box 11: Bad debt relief claimed
  final double box11BadDebtRelief;

  // Box 12: Net GST due/(refundable) (Box 5 - Box 10 - Box 11)
  final double box12NetGst;

  GstF5Data({
    required this.returnPeriod,
    required this.periodStart,
    required this.periodEnd,
    required this.dueDate,
    required this.box1StandardRatedSupplies,
    required this.box2ZeroRatedSupplies,
    required this.box3ExemptSupplies,
    required this.box4TotalSupplies,
    required this.box5OutputTax,
    required this.box6StandardRatedPurchases,
    required this.box7ZeroRatedPurchases,
    required this.box8ExemptPurchases,
    required this.box9TotalPurchases,
    required this.box10InputTax,
    required this.box11BadDebtRelief,
    required this.box12NetGst,
  });

  Map<String, dynamic> toJson() => {
        'returnPeriod': returnPeriod,
        'periodStart': periodStart.toIso8601String(),
        'periodEnd': periodEnd.toIso8601String(),
        'dueDate': dueDate.toIso8601String(),
        'box1StandardRatedSupplies': box1StandardRatedSupplies,
        'box2ZeroRatedSupplies': box2ZeroRatedSupplies,
        'box3ExemptSupplies': box3ExemptSupplies,
        'box4TotalSupplies': box4TotalSupplies,
        'box5OutputTax': box5OutputTax,
        'box6StandardRatedPurchases': box6StandardRatedPurchases,
        'box7ZeroRatedPurchases': box7ZeroRatedPurchases,
        'box8ExemptPurchases': box8ExemptPurchases,
        'box9TotalPurchases': box9TotalPurchases,
        'box10InputTax': box10InputTax,
        'box11BadDebtRelief': box11BadDebtRelief,
        'box12NetGst': box12NetGst,
      };
}

class GstF5Return {
  final String id;
  final String gstNumber;
  final String companyName;
  final GstF5Data data;
  final GstReturnStatus status;
  final DateTime createdDate;
  final DateTime? submittedDate;
  final String? acknowledgmentNumber;
  final List<String> validationErrors;
  final Map<String, dynamic> metadata;

  GstF5Return({
    required this.id,
    required this.gstNumber,
    required this.companyName,
    required this.data,
    required this.status,
    required this.createdDate,
    this.submittedDate,
    this.acknowledgmentNumber,
    this.validationErrors = const [],
    this.metadata = const {},
  });
}

class GstComplianceService {
  Future<GstF5Data> prepareGstF5Return({
    required CompanyTaxProfile companyProfile,
    required DateTime periodStart,
    required DateTime periodEnd,
    required List<GstTransaction> transactions,
  }) async {
    if (!companyProfile.isGstRegistered) {
      throw Exception('Company is not GST registered');
    }

    // Calculate totals for each box
    final supplies =
        transactions.where((t) => _isSupplyTransaction(t)).toList();
    final purchases =
        transactions.where((t) => _isPurchaseTransaction(t)).toList();

    // Box 1: Standard-rated supplies
    final box1 = supplies
        .where((t) => t.transactionType == 'standard')
        .fold<double>(0, (sum, t) => sum + t.amount);

    // Box 2: Zero-rated supplies
    final box2 = supplies
        .where((t) => t.transactionType == 'zero-rated')
        .fold<double>(0, (sum, t) => sum + t.amount);

    // Box 3: Exempt supplies
    final box3 = supplies
        .where((t) => t.transactionType == 'exempt')
        .fold<double>(0, (sum, t) => sum + t.amount);

    // Box 4: Total supplies
    final box4 = box1 + box2 + box3;

    // Box 5: Output tax
    final box5 = supplies
        .where((t) => t.transactionType == 'standard')
        .fold<double>(0, (sum, t) => sum + t.gstAmount);

    // Box 6: Standard-rated purchases
    final box6 = purchases
        .where((t) => t.transactionType == 'standard')
        .fold<double>(0, (sum, t) => sum + t.amount);

    // Box 7: Zero-rated purchases
    final box7 = purchases
        .where((t) => t.transactionType == 'zero-rated')
        .fold<double>(0, (sum, t) => sum + t.amount);

    // Box 8: Exempt purchases
    final box8 = purchases
        .where((t) => t.transactionType == 'exempt')
        .fold<double>(0, (sum, t) => sum + t.amount);

    // Box 9: Total purchases
    final box9 = box6 + box7 + box8;

    // Box 10: Input tax (claimable GST on purchases)
    final box10 = purchases
        .where(
            (t) => t.transactionType == 'standard' && _isClaimableInputTax(t))
        .fold<double>(0, (sum, t) => sum + t.gstAmount);

    // Box 11: Bad debt relief
    final box11 = _calculateBadDebtRelief(transactions, periodStart, periodEnd);

    // Box 12: Net GST
    final box12 = box5 - box10 - box11;

    final dueDate = _calculateDueDate(periodEnd);

    return GstF5Data(
      returnPeriod: _formatReturnPeriod(periodStart, periodEnd),
      periodStart: periodStart,
      periodEnd: periodEnd,
      dueDate: dueDate,
      box1StandardRatedSupplies: box1,
      box2ZeroRatedSupplies: box2,
      box3ExemptSupplies: box3,
      box4TotalSupplies: box4,
      box5OutputTax: box5,
      box6StandardRatedPurchases: box6,
      box7ZeroRatedPurchases: box7,
      box8ExemptPurchases: box8,
      box9TotalPurchases: box9,
      box10InputTax: box10,
      box11BadDebtRelief: box11,
      box12NetGst: box12,
    );
  }

  Future<List<String>> validateGstF5Return(GstF5Data data) async {
    final errors = <String>[];

    // Basic validation rules
    if (data.box4TotalSupplies !=
        (data.box1StandardRatedSupplies +
            data.box2ZeroRatedSupplies +
            data.box3ExemptSupplies)) {
      errors.add(
          'Box 4 (Total Supplies) does not equal sum of Box 1, Box 2, and Box 3');
    }

    if (data.box9TotalPurchases !=
        (data.box6StandardRatedPurchases +
            data.box7ZeroRatedPurchases +
            data.box8ExemptPurchases)) {
      errors.add(
          'Box 9 (Total Purchases) does not equal sum of Box 6, Box 7, and Box 8');
    }

    if (data.box12NetGst !=
        (data.box5OutputTax - data.box10InputTax - data.box11BadDebtRelief)) {
      errors.add('Box 12 (Net GST) calculation is incorrect');
    }

    // Check for unreasonable values
    if (data.box5OutputTax > data.box1StandardRatedSupplies * 0.1) {
      errors.add(
          'Output tax (Box 5) seems unreasonably high compared to standard-rated supplies');
    }

    if (data.box10InputTax > data.box6StandardRatedPurchases * 0.1) {
      errors.add(
          'Input tax (Box 10) seems unreasonably high compared to standard-rated purchases');
    }

    // Due date validation
    if (data.dueDate.isBefore(DateTime.now())) {
      errors.add('Return is past due date');
    }

    return errors;
  }

  Future<String> generateGstF5Csv(GstF5Data data) async {
    final buffer = StringBuffer();

    // CSV header
    buffer.writeln('Box,Description,Amount');

    // Add data rows
    buffer.writeln(
        '1,Standard-rated supplies,${data.box1StandardRatedSupplies.toStringAsFixed(2)}');
    buffer.writeln(
        '2,Zero-rated supplies,${data.box2ZeroRatedSupplies.toStringAsFixed(2)}');
    buffer.writeln(
        '3,Exempt supplies,${data.box3ExemptSupplies.toStringAsFixed(2)}');
    buffer.writeln(
        '4,Total supplies,${data.box4TotalSupplies.toStringAsFixed(2)}');
    buffer.writeln('5,Output tax,${data.box5OutputTax.toStringAsFixed(2)}');
    buffer.writeln(
        '6,Standard-rated purchases,${data.box6StandardRatedPurchases.toStringAsFixed(2)}');
    buffer.writeln(
        '7,Zero-rated purchases,${data.box7ZeroRatedPurchases.toStringAsFixed(2)}');
    buffer.writeln(
        '8,Exempt purchases,${data.box8ExemptPurchases.toStringAsFixed(2)}');
    buffer.writeln(
        '9,Total purchases,${data.box9TotalPurchases.toStringAsFixed(2)}');
    buffer.writeln('10,Input tax,${data.box10InputTax.toStringAsFixed(2)}');
    buffer.writeln(
        '11,Bad debt relief,${data.box11BadDebtRelief.toStringAsFixed(2)}');
    buffer.writeln('12,Net GST,${data.box12NetGst.toStringAsFixed(2)}');

    return buffer.toString();
  }

  Future<Map<String, dynamic>> generateGstF5Json(
      GstF5Data data, CompanyTaxProfile profile) async {
    return {
      'formType': 'GST-F5',
      'version': '1.0',
      'company': {
        'gstNumber': profile.gstNumber,
        'companyName': profile.companyName,
        'registrationNumber': profile.registrationNumber,
      },
      'returnPeriod': {
        'period': data.returnPeriod,
        'startDate': data.periodStart.toIso8601String(),
        'endDate': data.periodEnd.toIso8601String(),
        'dueDate': data.dueDate.toIso8601String(),
      },
      'supplies': {
        'standardRated': data.box1StandardRatedSupplies,
        'zeroRated': data.box2ZeroRatedSupplies,
        'exempt': data.box3ExemptSupplies,
        'total': data.box4TotalSupplies,
        'outputTax': data.box5OutputTax,
      },
      'purchases': {
        'standardRated': data.box6StandardRatedPurchases,
        'zeroRated': data.box7ZeroRatedPurchases,
        'exempt': data.box8ExemptPurchases,
        'total': data.box9TotalPurchases,
        'inputTax': data.box10InputTax,
      },
      'adjustments': {
        'badDebtRelief': data.box11BadDebtRelief,
      },
      'netGst': data.box12NetGst,
      'generatedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<GstF5Return> createGstF5Return({
    required CompanyTaxProfile companyProfile,
    required GstF5Data data,
  }) async {
    final errors = await validateGstF5Return(data);

    return GstF5Return(
      id: 'F5_${DateTime.now().millisecondsSinceEpoch}',
      gstNumber: companyProfile.gstNumber ?? '',
      companyName: companyProfile.companyName,
      data: data,
      status: errors.isEmpty ? GstReturnStatus.pending : GstReturnStatus.draft,
      createdDate: DateTime.now(),
      validationErrors: errors,
      metadata: {
        'createdBy': 'BizSync Tax Engine',
        'softwareVersion': '1.0.0',
      },
    );
  }

  Future<Map<String, dynamic>> getGstComplianceStatus(
      CompanyTaxProfile profile) async {
    if (!profile.isGstRegistered) {
      return {
        'isCompliant': false,
        'reason': 'Company is not GST registered',
        'requirements': [],
      };
    }

    final now = DateTime.now();
    final requirements = <String>[];
    bool isCompliant = true;

    // Check GST registration status
    if (profile.gstNumber == null || profile.gstNumber!.isEmpty) {
      requirements.add('GST registration number is required');
      isCompliant = false;
    }

    // Check if GST return is due
    final lastQuarterEnd =
        DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 3, 0);
    final dueDate = lastQuarterEnd
        .add(const Duration(days: 30)); // 30 days after quarter end

    if (now.isAfter(dueDate)) {
      requirements.add(
          'GST F5 return may be overdue for period ending ${lastQuarterEnd.toString().split(' ')[0]}');
      isCompliant = false;
    }

    // Check record keeping requirements
    final gstRegistrationDate = profile.gstRegistrationDate;
    if (gstRegistrationDate != null) {
      final daysSinceRegistration = now.difference(gstRegistrationDate).inDays;
      if (daysSinceRegistration > 0) {
        requirements.add('Maintain proper GST records for at least 5 years');
        requirements.add('Issue proper tax invoices for taxable supplies');
        requirements.add('Keep records of all business transactions');
      }
    }

    return {
      'isCompliant': isCompliant,
      'complianceScore': isCompliant ? 100 : 60,
      'requirements': requirements,
      'nextReturnDue': _getNextReturnDueDate(),
      'registrationStatus': 'Active',
      'registrationDate': profile.gstRegistrationDate?.toIso8601String(),
    };
  }

  DateTime _getNextReturnDueDate() {
    final now = DateTime.now();
    final currentQuarter = ((now.month - 1) ~/ 3) + 1;

    DateTime quarterEnd;
    if (currentQuarter == 4) {
      quarterEnd = DateTime(now.year + 1, 3, 31);
    } else {
      quarterEnd = DateTime(now.year, (currentQuarter + 1) * 3, 0);
      if (quarterEnd.month == 2) {
        quarterEnd = DateTime(now.year, 3, 31);
      } else if (quarterEnd.month == 5) {
        quarterEnd = DateTime(now.year, 6, 30);
      } else if (quarterEnd.month == 8) {
        quarterEnd = DateTime(now.year, 9, 30);
      } else {
        quarterEnd = DateTime(now.year, 12, 31);
      }
    }

    return quarterEnd
        .add(const Duration(days: 30)); // 30 days after quarter end
  }

  bool _isSupplyTransaction(GstTransaction transaction) {
    // Determine if transaction is a supply (sale) based on amount sign or type
    return transaction.amount > 0; // Simplified logic
  }

  bool _isPurchaseTransaction(GstTransaction transaction) {
    // Determine if transaction is a purchase based on amount sign or type
    return transaction.amount < 0; // Simplified logic
  }

  bool _isClaimableInputTax(GstTransaction transaction) {
    // Check if input tax is claimable based on business use
    // Simplified - in real implementation would check detailed rules
    return true;
  }

  double _calculateBadDebtRelief(
      List<GstTransaction> transactions, DateTime start, DateTime end) {
    // Calculate bad debt relief for the period
    // This would involve checking for bad debts written off that are at least 6 months overdue
    return 0.0; // Simplified
  }

  DateTime _calculateDueDate(DateTime periodEnd) {
    // GST return is due 30 days after the end of the taxable period
    return DateTime(periodEnd.year, periodEnd.month + 1, 30);
  }

  String _formatReturnPeriod(DateTime start, DateTime end) {
    final formatter = 'Q${((start.month - 1) ~/ 3) + 1} ${start.year}';
    return formatter;
  }
}
