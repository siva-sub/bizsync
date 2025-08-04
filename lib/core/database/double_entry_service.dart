import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../crdt/hybrid_logical_clock.dart';
import '../utils/uuid_generator.dart';
import '../error/exceptions.dart' as app_exceptions;
import 'crdt_database_service.dart';
import 'transaction_manager.dart';
import 'audit_service.dart';

/// Account types following standard accounting principles
enum AccountType {
  asset,
  liability,
  equity,
  revenue,
  expense,
}

/// Balance types for accounts
enum BalanceType {
  debit,  // Assets, Expenses
  credit, // Liabilities, Equity, Revenue
}

/// Journal entry line item
class JournalEntry {
  final String id;
  final String transactionId;
  final String accountId;
  final double debitAmount;
  final double creditAmount;
  final String? description;
  final String? reference;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;
  
  const JournalEntry({
    required this.id,
    required this.transactionId,
    required this.accountId,
    this.debitAmount = 0.0,
    this.creditAmount = 0.0,
    this.description,
    this.reference,
    required this.createdAt,
    this.metadata,
  });
  
  /// Validate that entry has either debit or credit (not both, not neither)
  bool get isValid => 
    (debitAmount > 0 && creditAmount == 0) || 
    (creditAmount > 0 && debitAmount == 0);
  
  double get amount => debitAmount > 0 ? debitAmount : creditAmount;
  bool get isDebit => debitAmount > 0;
  bool get isCredit => creditAmount > 0;
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'account_id': accountId,
      'debit_amount': debitAmount,
      'credit_amount': creditAmount,
      'description': description,
      'reference': reference,
      'created_at': createdAt.millisecondsSinceEpoch,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
    };
  }
  
  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      transactionId: json['transaction_id'] as String,
      accountId: json['account_id'] as String,
      debitAmount: (json['debit_amount'] as num?)?.toDouble() ?? 0.0,
      creditAmount: (json['credit_amount'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String?,
      reference: json['reference'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      metadata: json['metadata'] != null 
          ? jsonDecode(json['metadata'] as String) as Map<String, dynamic>
          : null,
    );
  }
}

/// Chart of accounts entry
class ChartOfAccountsEntry {
  final String id;
  final String accountCode;
  final String accountName;
  final AccountType accountType;
  final BalanceType balanceType;
  final String? parentAccountId;
  final bool isActive;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  const ChartOfAccountsEntry({
    required this.id,
    required this.accountCode,
    required this.accountName,
    required this.accountType,
    required this.balanceType,
    this.parentAccountId,
    this.isActive = true,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_code': accountCode,
      'account_name': accountName,
      'account_type': accountType.name.toUpperCase(),
      'balance_type': balanceType.name.toUpperCase(),
      'parent_account_id': parentAccountId,
      'is_active': isActive,
      'description': description,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }
  
  factory ChartOfAccountsEntry.fromJson(Map<String, dynamic> json) {
    return ChartOfAccountsEntry(
      id: json['id'] as String,
      accountCode: json['account_code'] as String,
      accountName: json['account_name'] as String,
      accountType: AccountType.values.firstWhere(
        (e) => e.name.toUpperCase() == json['account_type'],
      ),
      balanceType: BalanceType.values.firstWhere(
        (e) => e.name.toUpperCase() == json['balance_type'],
      ),
      parentAccountId: json['parent_account_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      description: json['description'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
    );
  }
}

/// Account balance information
class AccountBalance {
  final String accountId;
  final double balance;
  final DateTime lastUpdated;
  final int transactionCount;
  
  const AccountBalance({
    required this.accountId,
    required this.balance,
    required this.lastUpdated,
    this.transactionCount = 0,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'account_id': accountId,
      'balance': balance,
      'last_updated': lastUpdated.millisecondsSinceEpoch,
      'transaction_count': transactionCount,
    };
  }
  
  factory AccountBalance.fromJson(Map<String, dynamic> json) {
    return AccountBalance(
      accountId: json['account_id'] as String,
      balance: (json['balance'] as num).toDouble(),
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(json['last_updated'] as int),
      transactionCount: json['transaction_count'] as int? ?? 0,
    );
  }
}

/// Trial balance entry
class TrialBalanceEntry {
  final String accountId;
  final String accountCode;
  final String accountName;
  final AccountType accountType;
  final double debitBalance;
  final double creditBalance;
  
  const TrialBalanceEntry({
    required this.accountId,
    required this.accountCode,
    required this.accountName,
    required this.accountType,
    this.debitBalance = 0.0,
    this.creditBalance = 0.0,
  });
  
  double get netBalance => debitBalance - creditBalance;
  
  Map<String, dynamic> toJson() {
    return {
      'account_id': accountId,
      'account_code': accountCode,
      'account_name': accountName,
      'account_type': accountType.name.toUpperCase(),
      'debit_balance': debitBalance,
      'credit_balance': creditBalance,
      'net_balance': netBalance,
    };
  }
}

/// Double-entry bookkeeping service
class DoubleEntryService {
  final CRDTDatabaseService _databaseService;
  final AuditService _auditService;
  
  // Standard account codes
  static const Map<String, String> standardAccounts = {
    // Assets
    '1000': 'Cash',
    '1100': 'Accounts Receivable',
    '1200': 'Inventory',
    '1500': 'Equipment',
    '1600': 'Accumulated Depreciation - Equipment',
    
    // Liabilities
    '2000': 'Accounts Payable',
    '2100': 'Notes Payable',
    '2200': 'Accrued Expenses',
    
    // Equity
    '3000': 'Owner\'s Capital',
    '3100': 'Retained Earnings',
    '3200': 'Dividends',
    
    // Revenue
    '4000': 'Sales Revenue',
    '4100': 'Service Revenue',
    '4200': 'Interest Revenue',
    
    // Expenses
    '5000': 'Cost of Goods Sold',
    '5100': 'Salaries Expense',
    '5200': 'Rent Expense',
    '5300': 'Utilities Expense',
    '5400': 'Depreciation Expense',
    '5500': 'Interest Expense',
  };
  
  DoubleEntryService(this._databaseService, this._auditService);
  
  /// Initialize chart of accounts with standard accounts
  Future<void> initializeChartOfAccounts() async {
    final db = await _databaseService.database;
    
    await _databaseService.transactionManager.runInTransaction((transaction) async {
      for (final entry in standardAccounts.entries) {
        final accountCode = entry.key;
        final accountName = entry.value;
        final accountType = _getAccountTypeFromCode(accountCode);
        final balanceType = _getBalanceTypeFromAccountType(accountType);
        
        await db.insert(
          'chart_of_accounts',
          ChartOfAccountsEntry(
            id: UuidGenerator.generateId(),
            accountCode: accountCode,
            accountName: accountName,
            accountType: accountType,
            balanceType: balanceType,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ).toJson(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }
  
  /// Create a new account
  Future<ChartOfAccountsEntry> createAccount({
    required String accountCode,
    required String accountName,
    required AccountType accountType,
    String? parentAccountId,
    String? description,
  }) async {
    final db = await _databaseService.database;
    
    // Check if account code already exists
    final existing = await db.query(
      'chart_of_accounts',
      where: 'account_code = ?',
      whereArgs: [accountCode],
    );
    
    if (existing.isNotEmpty) {
      throw app_exceptions.DatabaseException('Account code $accountCode already exists');
    }
    
    final account = ChartOfAccountsEntry(
      id: UuidGenerator.generateId(),
      accountCode: accountCode,
      accountName: accountName,
      accountType: accountType,
      balanceType: _getBalanceTypeFromAccountType(accountType),
      parentAccountId: parentAccountId,
      description: description,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    await _databaseService.transactionManager.runInTransaction((transaction) async {
      await db.insert('chart_of_accounts', account.toJson());
      
      // Initialize balance
      await db.insert('account_balances', {
        'id': UuidGenerator.generateId(),
        'account_id': account.id,
        'balance': 0.0,
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      });
      
      // Audit log
      await _auditService.logEvent(
        tableName: 'chart_of_accounts',
        recordId: account.id,
        eventType: AuditEventType.create,
        newValues: account.toJson(),
      );
    });
    
    return account;
  }
  
  /// Create a journal entry (must be balanced)
  Future<List<JournalEntry>> createJournalEntry({
    required String transactionId,
    required List<JournalEntryLine> entries,
    String? description,
    String? reference,
  }) async {
    if (entries.isEmpty) {
      throw app_exceptions.DatabaseException('Journal entry must have at least one line');
    }
    
    // Validate that the entry is balanced
    final totalDebits = entries
        .where((e) => e.isDebit)
        .fold(0.0, (sum, e) => sum + e.amount);
    
    final totalCredits = entries
        .where((e) => e.isCredit)
        .fold(0.0, (sum, e) => sum + e.amount);
    
    const tolerance = 0.01; // Allow for small rounding differences
    if ((totalDebits - totalCredits).abs() > tolerance) {
      throw app_exceptions.DatabaseException(
        'Journal entry is not balanced: Debits=$totalDebits, Credits=$totalCredits'
      );
    }
    
    final db = await _databaseService.database;
    final journalEntries = <JournalEntry>[];
    
    await _databaseService.transactionManager.runInTransaction((transaction) async {
      for (final line in entries) {
        // Validate account exists
        final accountExists = await db.query(
          'chart_of_accounts',
          where: 'id = ? AND is_active = 1',
          whereArgs: [line.accountId],
        );
        
        if (accountExists.isEmpty) {
          throw app_exceptions.DatabaseException('Account ${line.accountId} does not exist or is inactive');
        }
        
        final journalEntry = JournalEntry(
          id: UuidGenerator.generateId(),
          transactionId: transactionId,
          accountId: line.accountId,
          debitAmount: line.isDebit ? line.amount : 0.0,
          creditAmount: line.isCredit ? line.amount : 0.0,
          description: line.description ?? description,
          reference: reference,
          createdAt: DateTime.now(),
        );
        
        await db.insert('journal_entries', journalEntry.toJson());
        journalEntries.add(journalEntry);
        
        // Update account balance
        await _updateAccountBalance(line.accountId, line.isDebit ? line.amount : -line.amount);
        
        // Audit log
        await _auditService.logEvent(
          tableName: 'journal_entries',
          recordId: journalEntry.id,
          eventType: AuditEventType.create,
          newValues: journalEntry.toJson(),
        );
      }
    });
    
    return journalEntries;
  }
  
  /// Get account balance
  Future<AccountBalance> getAccountBalance(String accountId) async {
    final db = await _databaseService.database;
    
    final result = await db.query(
      'account_balances',
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
    
    if (result.isEmpty) {
      throw app_exceptions.DatabaseException('Account balance not found for $accountId');
    }
    
    return AccountBalance.fromJson(result.first);
  }
  
  /// Get trial balance
  Future<List<TrialBalanceEntry>> getTrialBalance({
    DateTime? asOfDate,
  }) async {
    final db = await _databaseService.database;
    
    String dateFilter = '';
    List<dynamic> args = [];
    
    if (asOfDate != null) {
      dateFilter = 'AND je.created_at <= ?';
      args.add(asOfDate.millisecondsSinceEpoch);
    }
    
    final result = await db.rawQuery('''
      SELECT 
        coa.id as account_id,
        coa.account_code,
        coa.account_name,
        coa.account_type,
        COALESCE(SUM(je.debit_amount), 0) as total_debits,
        COALESCE(SUM(je.credit_amount), 0) as total_credits
      FROM chart_of_accounts coa
      LEFT JOIN journal_entries je ON coa.id = je.account_id $dateFilter
      WHERE coa.is_active = 1
      GROUP BY coa.id, coa.account_code, coa.account_name, coa.account_type
      ORDER BY coa.account_code
    ''', args);
    
    return result.map((row) {
      final accountType = AccountType.values.firstWhere(
        (e) => e.name.toUpperCase() == row['account_type'],
      );
      
      final totalDebits = (row['total_debits'] as num).toDouble();
      final totalCredits = (row['total_credits'] as num).toDouble();
      
      return TrialBalanceEntry(
        accountId: row['account_id'] as String,
        accountCode: row['account_code'] as String,
        accountName: row['account_name'] as String,
        accountType: accountType,
        debitBalance: totalDebits,
        creditBalance: totalCredits,
      );
    }).toList();
  }
  
  /// Validate trial balance
  Future<Map<String, dynamic>> validateTrialBalance({DateTime? asOfDate}) async {
    final trialBalance = await getTrialBalance(asOfDate: asOfDate);
    
    final totalDebits = trialBalance.fold(0.0, (sum, entry) => sum + entry.debitBalance);
    final totalCredits = trialBalance.fold(0.0, (sum, entry) => sum + entry.creditBalance);
    
    const tolerance = 0.01;
    final isBalanced = (totalDebits - totalCredits).abs() <= tolerance;
    final difference = totalDebits - totalCredits;
    
    return {
      'is_balanced': isBalanced,
      'total_debits': totalDebits,
      'total_credits': totalCredits,
      'difference': difference,
      'tolerance': tolerance,
      'as_of_date': asOfDate?.toIso8601String(),
      'validation_time': DateTime.now().toIso8601String(),
    };
  }
  
  /// Generate financial statements
  Future<Map<String, dynamic>> generateFinancialStatements({
    DateTime? asOfDate,
  }) async {
    final trialBalance = await getTrialBalance(asOfDate: asOfDate);
    
    // Balance Sheet
    final assets = trialBalance
        .where((e) => e.accountType == AccountType.asset)
        .toList();
    final liabilities = trialBalance
        .where((e) => e.accountType == AccountType.liability)
        .toList();
    final equity = trialBalance
        .where((e) => e.accountType == AccountType.equity)
        .toList();
    
    // Income Statement
    final revenue = trialBalance
        .where((e) => e.accountType == AccountType.revenue)
        .toList();
    final expenses = trialBalance
        .where((e) => e.accountType == AccountType.expense)
        .toList();
    
    final totalAssets = assets.fold(0.0, (sum, e) => sum + e.netBalance);
    final totalLiabilities = liabilities.fold(0.0, (sum, e) => sum + e.creditBalance);
    final totalEquity = equity.fold(0.0, (sum, e) => sum + e.creditBalance);
    final totalRevenue = revenue.fold(0.0, (sum, e) => sum + e.creditBalance);
    final totalExpenses = expenses.fold(0.0, (sum, e) => sum + e.debitBalance);
    
    final netIncome = totalRevenue - totalExpenses;
    
    return {
      'as_of_date': asOfDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'balance_sheet': {
        'assets': {
          'accounts': assets.map((e) => e.toJson()).toList(),
          'total': totalAssets,
        },
        'liabilities': {
          'accounts': liabilities.map((e) => e.toJson()).toList(),
          'total': totalLiabilities,
        },
        'equity': {
          'accounts': equity.map((e) => e.toJson()).toList(),
          'total': totalEquity,
        },
        'total_liabilities_and_equity': totalLiabilities + totalEquity,
        'is_balanced': (totalAssets - (totalLiabilities + totalEquity)).abs() <= 0.01,
      },
      'income_statement': {
        'revenue': {
          'accounts': revenue.map((e) => e.toJson()).toList(),
          'total': totalRevenue,
        },
        'expenses': {
          'accounts': expenses.map((e) => e.toJson()).toList(),
          'total': totalExpenses,
        },
        'net_income': netIncome,
      },
    };
  }
  
  /// Update account balance
  Future<void> _updateAccountBalance(String accountId, double amount) async {
    final db = await _databaseService.database;
    
    await db.rawUpdate('''
      UPDATE account_balances 
      SET balance = balance + ?, last_updated = ?
      WHERE account_id = ?
    ''', [amount, DateTime.now().millisecondsSinceEpoch, accountId]);
  }
  
  /// Get account type from account code
  AccountType _getAccountTypeFromCode(String accountCode) {
    final firstDigit = int.tryParse(accountCode.substring(0, 1)) ?? 0;
    
    switch (firstDigit) {
      case 1:
        return AccountType.asset;
      case 2:
        return AccountType.liability;
      case 3:
        return AccountType.equity;
      case 4:
        return AccountType.revenue;
      case 5:
      case 6:
      case 7:
      case 8:
      case 9:
        return AccountType.expense;
      default:
        return AccountType.asset;
    }
  }
  
  /// Get balance type from account type
  BalanceType _getBalanceTypeFromAccountType(AccountType accountType) {
    switch (accountType) {
      case AccountType.asset:
      case AccountType.expense:
        return BalanceType.debit;
      case AccountType.liability:
      case AccountType.equity:
      case AccountType.revenue:
        return BalanceType.credit;
    }
  }
}

/// Journal entry line for creating entries
class JournalEntryLine {
  final String accountId;
  final double amount;
  final bool isDebit;
  final String? description;
  
  const JournalEntryLine({
    required this.accountId,
    required this.amount,
    required this.isDebit,
    this.description,
  });
  
  bool get isCredit => !isDebit;
}