import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/report_models.dart';

abstract class ReportService {
  Future<SalesReportData> generateSalesReport(DateTime startDate, DateTime endDate);
  Future<TaxReportData> generateTaxReport(DateTime startDate, DateTime endDate);
  Future<FinancialReportData> generateFinancialReport(DateTime startDate, DateTime endDate);
  Future<List<ReportData>> getRecentReports();
}

class ReportServiceImpl implements ReportService {
  @override
  Future<SalesReportData> generateSalesReport(DateTime startDate, DateTime endDate) async {
    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Generate mock data
    final dailySales = <SalesDataPoint>[];
    final current = startDate;
    final random = DateTime.now().millisecondsSinceEpoch % 1000;
    
    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      final dayRevenue = 1000 + (random * current.day) % 5000;
      final dayProfit = dayRevenue * 0.3;
      final dayTransactions = 5 + (random * current.day) % 20;
      
      dailySales.add(SalesDataPoint(
        date: DateTime(current.year, current.month, current.day),
        revenue: dayRevenue.toDouble(),
        profit: dayProfit,
        transactions: dayTransactions,
      ));
      
      current.add(const Duration(days: 1));
    }
    
    final totalRevenue = dailySales.fold(0.0, (sum, point) => sum + point.revenue);
    final totalProfit = dailySales.fold(0.0, (sum, point) => sum + point.profit);
    final totalTransactions = dailySales.fold(0, (sum, point) => sum + point.transactions);
    
    return SalesReportData(
      totalRevenue: totalRevenue,
      totalProfit: totalProfit,
      totalTransactions: totalTransactions,
      averageTransactionValue: totalRevenue / totalTransactions,
      dailySales: dailySales,
      topCategories: [
        const CategorySales(category: 'Consulting', revenue: 15000, percentage: 40, color: Colors.blue),
        const CategorySales(category: 'Products', revenue: 11250, percentage: 30, color: Colors.green),
        const CategorySales(category: 'Services', revenue: 7500, percentage: 20, color: Colors.orange),
        const CategorySales(category: 'Other', revenue: 3750, percentage: 10, color: Colors.purple),
      ],
      topCustomers: [
        const CustomerSales(customerId: '1', customerName: 'Tech Solutions Pte Ltd', revenue: 8500, transactions: 12),
        const CustomerSales(customerId: '2', customerName: 'Marketing Agency Pte Ltd', revenue: 6200, transactions: 8),
        const CustomerSales(customerId: '3', customerName: 'Startup Pte Ltd', revenue: 4800, transactions: 6),
      ],
    );
  }

  @override
  Future<TaxReportData> generateTaxReport(DateTime startDate, DateTime endDate) async {
    await Future.delayed(const Duration(milliseconds: 600));
    
    final monthlyGst = <TaxDataPoint>[];
    var current = DateTime(startDate.year, startDate.month, 1);
    
    while (current.isBefore(endDate)) {
      final collected = 800 + (current.month * 150);
      final paid = 300 + (current.month * 50);
      
      monthlyGst.add(TaxDataPoint(
        month: current,
        collected: collected.toDouble(),
        paid: paid.toDouble(),
        net: collected - paid.toDouble(),
      ));
      
      current = DateTime(current.year, current.month + 1, 1);
    }
    
    final totalGstCollected = monthlyGst.fold(0.0, (sum, point) => sum + point.collected);
    final totalGstPaid = monthlyGst.fold(0.0, (sum, point) => sum + point.paid);
    
    return TaxReportData(
      totalGstCollected: totalGstCollected,
      totalGstPaid: totalGstPaid,
      netGstPayable: totalGstCollected - totalGstPaid,
      monthlyGst: monthlyGst,
      gstByRate: const [
        TaxByRate(rate: '9%', amount: 5400, percentage: 85),
        TaxByRate(rate: '0%', amount: 900, percentage: 15),
      ],
      corporateTaxEstimate: 8500,
    );
  }

  @override
  Future<FinancialReportData> generateFinancialReport(DateTime startDate, DateTime endDate) async {
    await Future.delayed(const Duration(milliseconds: 700));
    
    const incomeStatement = [
      IncomeStatementItem(category: 'Revenue', amount: 45000, percentage: 100),
      IncomeStatementItem(category: 'Cost of Goods Sold', amount: -18000, percentage: -40),
      IncomeStatementItem(category: 'Gross Profit', amount: 27000, percentage: 60),
      IncomeStatementItem(category: 'Operating Expenses', amount: -15000, percentage: -33),
      IncomeStatementItem(category: 'Net Income', amount: 12000, percentage: 27),
    ];
    
    const balanceSheet = [
      BalanceSheetItem(category: 'Cash & Bank', amount: 25000, isAsset: true),
      BalanceSheetItem(category: 'Accounts Receivable', amount: 8500, isAsset: true),
      BalanceSheetItem(category: 'Inventory', amount: 12000, isAsset: true),
      BalanceSheetItem(category: 'Equipment', amount: 15000, isAsset: true),
      BalanceSheetItem(category: 'Accounts Payable', amount: 6500, isAsset: false),
      BalanceSheetItem(category: 'Loans', amount: 20000, isAsset: false),
    ];
    
    final cashFlowStatement = <CashFlowItem>[];
    var current = startDate;
    
    while (current.isBefore(endDate)) {
      final inflow = 3000 + (current.day * 100);
      final outflow = 2200 + (current.day * 80);
      
      cashFlowStatement.add(CashFlowItem(
        date: current,
        inflow: inflow.toDouble(),
        outflow: outflow.toDouble(),
        netFlow: inflow - outflow.toDouble(),
      ));
      
      current = current.add(const Duration(days: 7));
    }
    
    const totalAssets = 60500;
    const totalLiabilities = 26500;
    
    return FinancialReportData(
      totalAssets: totalAssets.toDouble(),
      totalLiabilities: totalLiabilities.toDouble(),
      netWorth: (totalAssets - totalLiabilities).toDouble(),
      cashFlow: cashFlowStatement.fold(0.0, (sum, item) => sum + item.netFlow),
      incomeStatement: incomeStatement,
      balanceSheet: balanceSheet,
      cashFlowStatement: cashFlowStatement,
    );
  }

  @override
  Future<List<ReportData>> getRecentReports() async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    final now = DateTime.now();
    return [
      ReportData(
        id: '1',
        title: 'Monthly Sales Report',
        type: ReportType.sales,
        generatedAt: now.subtract(const Duration(hours: 2)),
        period: ReportPeriod.thisMonth,
        startDate: DateTime(now.year, now.month, 1),
        endDate: now,
        data: {},
      ),
      ReportData(
        id: '2',
        title: 'Q4 Tax Report',
        type: ReportType.tax,
        generatedAt: now.subtract(const Duration(days: 1)),
        period: ReportPeriod.thisQuarter,
        startDate: DateTime(now.year, 10, 1),
        endDate: DateTime(now.year, 12, 31),
        data: {},
      ),
      ReportData(
        id: '3',
        title: 'Financial Summary',
        type: ReportType.financial,
        generatedAt: now.subtract(const Duration(days: 3)),
        period: ReportPeriod.thisYear,
        startDate: DateTime(now.year, 1, 1),
        endDate: now,
        data: {},
      ),
    ];
  }
}

final reportServiceProvider = Provider<ReportService>((ref) {
  return ReportServiceImpl();
});