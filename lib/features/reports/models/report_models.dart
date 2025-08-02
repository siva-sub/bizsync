import 'package:flutter/material.dart';

enum ReportType {
  sales,
  tax,
  financial,
  customer,
  inventory,
  profit,
}

enum ReportPeriod {
  today,
  thisWeek,
  thisMonth,
  thisQuarter,
  thisYear,
  custom,
}

class ReportData {
  final String id;
  final String title;
  final ReportType type;
  final DateTime generatedAt;
  final ReportPeriod period;
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, dynamic> data;

  const ReportData({
    required this.id,
    required this.title,
    required this.type,
    required this.generatedAt,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.data,
  });
}

class SalesReportData {
  final double totalRevenue;
  final double totalProfit;
  final int totalTransactions;
  final double averageTransactionValue;
  final List<SalesDataPoint> dailySales;
  final List<CategorySales> topCategories;
  final List<CustomerSales> topCustomers;

  const SalesReportData({
    required this.totalRevenue,
    required this.totalProfit,
    required this.totalTransactions,
    required this.averageTransactionValue,
    required this.dailySales,
    required this.topCategories,
    required this.topCustomers,
  });
}

class SalesDataPoint {
  final DateTime date;
  final double revenue;
  final double profit;
  final int transactions;

  const SalesDataPoint({
    required this.date,
    required this.revenue,
    required this.profit,
    required this.transactions,
  });
}

class CategorySales {
  final String category;
  final double revenue;
  final double percentage;
  final Color color;

  const CategorySales({
    required this.category,
    required this.revenue,
    required this.percentage,
    required this.color,
  });
}

class CustomerSales {
  final String customerId;
  final String customerName;
  final double revenue;
  final int transactions;

  const CustomerSales({
    required this.customerId,
    required this.customerName,
    required this.revenue,
    required this.transactions,
  });
}

class TaxReportData {
  final double totalGstCollected;
  final double totalGstPaid;
  final double netGstPayable;
  final List<TaxDataPoint> monthlyGst;
  final List<TaxByRate> gstByRate;
  final double corporateTaxEstimate;

  const TaxReportData({
    required this.totalGstCollected,
    required this.totalGstPaid,
    required this.netGstPayable,
    required this.monthlyGst,
    required this.gstByRate,
    required this.corporateTaxEstimate,
  });
}

class TaxDataPoint {
  final DateTime month;
  final double collected;
  final double paid;
  final double net;

  const TaxDataPoint({
    required this.month,
    required this.collected,
    required this.paid,
    required this.net,
  });
}

class TaxByRate {
  final String rate;
  final double amount;
  final double percentage;

  const TaxByRate({
    required this.rate,
    required this.amount,
    required this.percentage,
  });
}

class FinancialReportData {
  final double totalAssets;
  final double totalLiabilities;
  final double netWorth;
  final double cashFlow;
  final List<IncomeStatementItem> incomeStatement;
  final List<BalanceSheetItem> balanceSheet;
  final List<CashFlowItem> cashFlowStatement;

  const FinancialReportData({
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netWorth,
    required this.cashFlow,
    required this.incomeStatement,
    required this.balanceSheet,
    required this.cashFlowStatement,
  });
}

class IncomeStatementItem {
  final String category;
  final double amount;
  final double percentage;

  const IncomeStatementItem({
    required this.category,
    required this.amount,
    required this.percentage,
  });
}

class BalanceSheetItem {
  final String category;
  final double amount;
  final bool isAsset;

  const BalanceSheetItem({
    required this.category,
    required this.amount,
    required this.isAsset,
  });
}

class CashFlowItem {
  final DateTime date;
  final double inflow;
  final double outflow;
  final double netFlow;

  const CashFlowItem({
    required this.date,
    required this.inflow,
    required this.outflow,
    required this.netFlow,
  });
}