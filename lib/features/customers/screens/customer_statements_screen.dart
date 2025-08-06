import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/customer_statement_models.dart';
import '../services/customer_statement_service.dart';

/// Screen for viewing customer statements and balances
class CustomerStatementsScreen extends StatefulWidget {
  const CustomerStatementsScreen({super.key});

  @override
  State<CustomerStatementsScreen> createState() =>
      _CustomerStatementsScreenState();
}

class _CustomerStatementsScreenState extends State<CustomerStatementsScreen> {
  final CustomerStatementService _statementService =
      CustomerStatementService.instance;

  List<CustomerBalanceSummary> _customerBalances = [];
  bool _isLoading = true;
  String _filter = 'all'; // all, outstanding, overdue
  String _sortBy = 'name'; // name, balance, overdue

  @override
  void initState() {
    super.initState();
    _loadCustomerBalances();
  }

  Future<void> _loadCustomerBalances() async {
    setState(() => _isLoading = true);

    try {
      final balances = await _statementService.getAllCustomerBalances();
      setState(() {
        _customerBalances = balances;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading customer balances: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<CustomerBalanceSummary> get _filteredAndSortedBalances {
    var filtered = _customerBalances;

    // Apply filter
    switch (_filter) {
      case 'outstanding':
        filtered = filtered.where((b) => b.currentBalance > 0).toList();
        break;
      case 'overdue':
        filtered = filtered.where((b) => b.overdueBalance > 0).toList();
        break;
    }

    // Apply sorting
    switch (_sortBy) {
      case 'name':
        filtered.sort((a, b) => a.customerName.compareTo(b.customerName));
        break;
      case 'balance':
        filtered.sort((a, b) => b.currentBalance.compareTo(a.currentBalance));
        break;
      case 'overdue':
        filtered.sort((a, b) => b.overdueBalance.compareTo(a.overdueBalance));
        break;
    }

    return filtered;
  }

  Future<void> _generateBulkStatements() async {
    try {
      final options = await _showStatementOptionsDialog();
      if (options == null) return;

      setState(() => _isLoading = true);

      final statements =
          await _statementService.generateBulkStatements(options: options);

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Generated ${statements.length} statements successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating statements: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<StatementGenerationOptions?> _showStatementOptionsDialog() async {
    return await showDialog<StatementGenerationOptions>(
      context: context,
      builder: (context) => const StatementOptionsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Statements'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _filter = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Customers')),
              const PopupMenuItem(
                  value: 'outstanding', child: Text('Outstanding Balances')),
              const PopupMenuItem(
                  value: 'overdue', child: Text('Overdue Only')),
            ],
            child: const Icon(Icons.filter_list),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _sortBy = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'name', child: Text('Sort by Name')),
              const PopupMenuItem(
                  value: 'balance', child: Text('Sort by Balance')),
              const PopupMenuItem(
                  value: 'overdue', child: Text('Sort by Overdue')),
            ],
            child: const Icon(Icons.sort),
          ),
          IconButton(
            onPressed: _generateBulkStatements,
            icon: const Icon(Icons.assignment),
            tooltip: 'Generate Bulk Statements',
          ),
          IconButton(
            onPressed: _loadCustomerBalances,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCustomerBalances,
              child: _customerBalances.isEmpty
                  ? _buildEmptyState()
                  : _buildCustomersList(),
            ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No Customer Data',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Create some invoices first to see\ncustomer statements and balances',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomersList() {
    final filteredBalances = _filteredAndSortedBalances;

    return Column(
      children: [
        _buildSummaryCards(),
        Expanded(
          child: ListView.builder(
            itemCount: filteredBalances.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final balance = filteredBalances[index];
              return _buildCustomerBalanceCard(balance);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    final totalBalance =
        _customerBalances.fold(0.0, (sum, b) => sum + b.currentBalance);
    final totalOverdue =
        _customerBalances.fold(0.0, (sum, b) => sum + b.overdueBalance);
    final overdueCustomers =
        _customerBalances.where((b) => b.overdueBalance > 0).length;
    final highRiskCustomers =
        _customerBalances.where((b) => b.isHighRisk).length;

    return Container(
      height: 120,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Total Outstanding',
              '\$${NumberFormat('#,##0.00').format(totalBalance)}',
              Icons.account_balance_wallet,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'Total Overdue',
              '\$${NumberFormat('#,##0.00').format(totalOverdue)}',
              Icons.warning,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'Overdue Customers',
              '$overdueCustomers',
              Icons.people,
              Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'High Risk',
              '$highRiskCustomers',
              Icons.error,
              Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerBalanceCard(CustomerBalanceSummary balance) {
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getRiskColor(balance.riskLevel).withValues(alpha: 0.1),
          child: Icon(
            _getRiskIcon(balance.riskLevel),
            color: _getRiskColor(balance.riskLevel),
          ),
        ),
        title: Text(
          balance.customerName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Balance: ${currencyFormat.format(balance.currentBalance)}'),
            if (balance.overdueBalance > 0)
              Text(
                'Overdue: ${currencyFormat.format(balance.overdueBalance)}',
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.w500),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getRiskColor(balance.riskLevel).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getRiskText(balance.riskLevel),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getRiskColor(balance.riskLevel),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${balance.unpaidInvoices} unpaid',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'statement',
                  child: const Text('Generate Statement'),
                ),
                PopupMenuItem(
                  value: 'payment',
                  child: const Text('Record Payment'),
                ),
                PopupMenuItem(
                  value: 'details',
                  child: const Text('View Details'),
                ),
              ],
              onSelected: (value) async {
                switch (value) {
                  case 'statement':
                    await _generateCustomerStatement(balance);
                    break;
                  case 'payment':
                    await _showRecordPaymentDialog(balance);
                    break;
                  case 'details':
                    await _showCustomerDetails(balance);
                    break;
                }
              },
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Total Invoices', '${balance.totalInvoices}'),
                _buildDetailRow('Unpaid Invoices', '${balance.unpaidInvoices}'),
                _buildDetailRow(
                    'Last Invoice', dateFormat.format(balance.lastInvoiceDate)),
                if (balance.lastPaymentDate != null)
                  _buildDetailRow('Last Payment',
                      dateFormat.format(balance.lastPaymentDate!))
                else
                  _buildDetailRow('Last Payment', 'No payments recorded'),
                if (balance.daysSinceLastPayment > 0)
                  _buildDetailRow('Days Since Payment',
                      '${balance.daysSinceLastPayment} days'),
                if (balance.creditLimit > 0) ...[
                  _buildDetailRow('Credit Limit',
                      currencyFormat.format(balance.creditLimit)),
                  _buildDetailRow('Credit Utilization',
                      '${balance.creditUtilization.toStringAsFixed(1)}%'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _generateCustomerStatement(
      CustomerBalanceSummary balance) async {
    try {
      final options = await _showStatementOptionsDialog();
      if (options == null) return;

      final statement = await _statementService.generateCustomerStatement(
        customerId: balance.customerId,
        customerName: balance.customerName,
        options: options,
      );

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                CustomerStatementDetailScreen(statement: statement),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating statement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showRecordPaymentDialog(CustomerBalanceSummary balance) async {
    // TODO: Implement payment recording dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment recording feature coming soon!')),
    );
  }

  Future<void> _showCustomerDetails(CustomerBalanceSummary balance) async {
    // TODO: Implement customer details dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Customer details view coming soon!')),
    );
  }

  Color _getRiskColor(CustomerRiskLevel level) {
    switch (level) {
      case CustomerRiskLevel.low:
        return Colors.green;
      case CustomerRiskLevel.medium:
        return Colors.orange;
      case CustomerRiskLevel.high:
        return Colors.red;
    }
  }

  IconData _getRiskIcon(CustomerRiskLevel level) {
    switch (level) {
      case CustomerRiskLevel.low:
        return Icons.check_circle;
      case CustomerRiskLevel.medium:
        return Icons.warning;
      case CustomerRiskLevel.high:
        return Icons.error;
    }
  }

  String _getRiskText(CustomerRiskLevel level) {
    switch (level) {
      case CustomerRiskLevel.low:
        return 'LOW RISK';
      case CustomerRiskLevel.medium:
        return 'MEDIUM';
      case CustomerRiskLevel.high:
        return 'HIGH RISK';
    }
  }
}

/// Dialog for selecting statement generation options
class StatementOptionsDialog extends StatefulWidget {
  const StatementOptionsDialog({super.key});

  @override
  State<StatementOptionsDialog> createState() => _StatementOptionsDialogState();
}

class _StatementOptionsDialogState extends State<StatementOptionsDialog> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _includeZeroBalance = false;
  bool _includePaidInvoices = true;
  StatementFormat _format = StatementFormat.detailed;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Statement Options'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime.now()
                            .subtract(const Duration(days: 365 * 2)),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _startDate = date);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start Date',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(DateFormat('dd/MM/yyyy').format(_startDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _endDate,
                        firstDate: _startDate,
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _endDate = date);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'End Date',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(DateFormat('dd/MM/yyyy').format(_endDate)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    final options = StatementGenerationOptions.currentMonth();
                    setState(() {
                      _startDate = options.startDate;
                      _endDate = options.endDate;
                    });
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('This Month'),
                ),
                TextButton.icon(
                  onPressed: () {
                    final options = StatementGenerationOptions.lastMonth();
                    setState(() {
                      _startDate = options.startDate;
                      _endDate = options.endDate;
                    });
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Last Month'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Include Zero Balance Customers'),
              value: _includeZeroBalance,
              onChanged: (value) =>
                  setState(() => _includeZeroBalance = value!),
            ),
            CheckboxListTile(
              title: const Text('Include Paid Invoices'),
              value: _includePaidInvoices,
              onChanged: (value) =>
                  setState(() => _includePaidInvoices = value!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<StatementFormat>(
              value: _format,
              decoration: const InputDecoration(
                labelText: 'Statement Format',
                border: OutlineInputBorder(),
              ),
              items: StatementFormat.values.map((format) {
                return DropdownMenuItem<StatementFormat>(
                  value: format,
                  child: Text(_getFormatDisplayName(format)),
                );
              }).toList(),
              onChanged: (value) => setState(() => _format = value!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final options = StatementGenerationOptions(
              startDate: _startDate,
              endDate: _endDate,
              includeZeroBalanceCustomers: _includeZeroBalance,
              includePaidInvoices: _includePaidInvoices,
              format: _format,
            );
            Navigator.of(context).pop(options);
          },
          child: const Text('Generate'),
        ),
      ],
    );
  }

  String _getFormatDisplayName(StatementFormat format) {
    switch (format) {
      case StatementFormat.summary:
        return 'Summary Only';
      case StatementFormat.detailed:
        return 'Detailed';
      case StatementFormat.compact:
        return 'Compact';
    }
  }
}

/// Screen to show detailed customer statement
class CustomerStatementDetailScreen extends StatelessWidget {
  final CustomerStatement statement;

  const CustomerStatementDetailScreen({
    super.key,
    required this.statement,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text('${statement.summary.customerName} Statement'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: () {
              // TODO: Export to PDF
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDF export coming soon!')),
              );
            },
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export to PDF',
          ),
          IconButton(
            onPressed: () {
              // TODO: Email statement
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Email statement coming soon!')),
              );
            },
            icon: const Icon(Icons.email),
            tooltip: 'Email Statement',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statement header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statement Summary',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Customer: ${statement.summary.customerName}'),
                              Text(
                                  'Statement Date: ${dateFormat.format(statement.summary.statementDate)}'),
                              Text(
                                  'Period: ${dateFormat.format(statement.summary.periodStart)} - ${dateFormat.format(statement.summary.periodEnd)}'),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Current Balance',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              currencyFormat
                                  .format(statement.summary.currentBalance),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: statement.summary.currentBalance > 0
                                    ? Colors.red
                                    : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Aging analysis
            if (statement.summary.overdue30Days > 0 ||
                statement.summary.overdue60Days > 0 ||
                statement.summary.overdue90Days > 0) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aging Analysis',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                              child: _buildAgingCard(
                                  '30 Days',
                                  statement.summary.overdue30Days,
                                  Colors.orange)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _buildAgingCard(
                                  '60 Days',
                                  statement.summary.overdue60Days,
                                  Colors.deepOrange)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _buildAgingCard('90+ Days',
                                  statement.summary.overdue90Days, Colors.red)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Transactions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transaction History',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    ...statement.transactions.map((transaction) {
                      return _buildTransactionRow(
                          transaction, currencyFormat, dateFormat);
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgingCard(String title, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            NumberFormat.currency(symbol: '\$').format(amount),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(
    StatementTransaction transaction,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              dateFormat.format(transaction.date),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (transaction.reference != null)
                  Text(
                    transaction.reference!,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              transaction.debit > 0
                  ? currencyFormat.format(transaction.debit)
                  : '',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              transaction.credit > 0
                  ? currencyFormat.format(transaction.credit)
                  : '',
              style: const TextStyle(color: Colors.green),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              currencyFormat.format(transaction.balance),
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
