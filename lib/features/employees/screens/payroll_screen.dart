import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/crdt/hybrid_logical_clock.dart';
import '../models/employee_models.dart';
import '../models/payroll_models.dart';
import '../../../core/services/notification_service.dart';
import '../services/employee_service.dart';
import '../services/singapore_payroll_service.dart';

class PayrollScreen extends ConsumerStatefulWidget {
  const PayrollScreen({super.key});

  @override
  ConsumerState<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends ConsumerState<PayrollScreen>
    with TickerProviderStateMixin {
  final _employeeService = EmployeeService(NotificationService());
  final _payrollService = SingaporePayrollService();

  late TabController _tabController;

  // State variables
  List<CRDTEmployee> _employees = [];
  List<CRDTPayrollRecord> _payrollRecords = [];
  List<CRDTEmployee> _selectedEmployees = [];
  bool _isLoading = false;
  bool _isProcessing = false;

  // Payroll period
  DateTime _payPeriodStart =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _payPeriodEnd =
      DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

  // Filters
  String _statusFilter = 'all';
  String _departmentFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadEmployees();
    _loadPayrollRecords();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _employees = await _employeeService.getAllEmployees();
      // Filter only active employees
      _employees = _employees
          .where((emp) => emp.employmentStatus.value == 'active')
          .toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading employees: $e')),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadPayrollRecords() async {
    try {
      // This would typically load from database
      // For now, we'll initialize with empty list
      _payrollRecords = [];
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading payroll records: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payroll Management'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Process Payroll', icon: Icon(Icons.play_arrow)),
            Tab(text: 'Payroll History', icon: Icon(Icons.history)),
            Tab(text: 'Reports', icon: Icon(Icons.analytics)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadEmployees();
              _loadPayrollRecords();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProcessPayrollTab(),
          _buildPayrollHistoryTab(),
          _buildReportsTab(),
        ],
      ),
    );
  }

  Widget _buildProcessPayrollTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPayrollPeriodCard(),
          const SizedBox(height: 16),
          _buildEmployeeSelectionCard(),
          const SizedBox(height: 16),
          if (_selectedEmployees.isNotEmpty) _buildPayrollSummaryCard(),
          const SizedBox(height: 16),
          _buildProcessActionsCard(),
        ],
      ),
    );
  }

  Widget _buildPayrollPeriodCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payroll Period',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectPayrollDate(context, 'start'),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Period Start',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        '${_payPeriodStart.day}/${_payPeriodStart.month}/${_payPeriodStart.year}',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectPayrollDate(context, 'end'),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Period End',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.event),
                      ),
                      child: Text(
                        '${_payPeriodEnd.day}/${_payPeriodEnd.month}/${_payPeriodEnd.year}',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Working days: ${_calculateWorkingDays()} | Total employees: ${_employees.length}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeSelectionCard() {
    final filteredEmployees = _getFilteredEmployees();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Employees',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedEmployees = List.from(filteredEmployees);
                        });
                      },
                      child: const Text('Select All'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedEmployees.clear();
                        });
                      },
                      child: const Text('Clear All'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _departmentFilter,
                    decoration: const InputDecoration(
                      labelText: 'Filter by Department',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                    items: _getDepartmentOptions(),
                    onChanged: (value) {
                      setState(() {
                        _departmentFilter = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _showEmployeeSelectionDialog,
                  icon: const Icon(Icons.filter_list),
                  label: Text('Filter (${_selectedEmployees.length})'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedEmployees.isNotEmpty) ...[
              Text(
                'Selected Employees (${_selectedEmployees.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: _selectedEmployees.length,
                  itemBuilder: (context, index) {
                    final employee = _selectedEmployees[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                            employee.displayName.substring(0, 1).toUpperCase()),
                      ),
                      title: Text(employee.fullName),
                      subtitle: Text(
                          '${employee.jobTitle.value} • \$${employee.totalCompensation.toStringAsFixed(0)}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          setState(() {
                            _selectedEmployees.removeAt(index);
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              Container(
                height: 100,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.people_outline,
                        size: 32, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text(
                      'No employees selected',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPayrollSummaryCard() {
    final totalBasicSalary = _selectedEmployees.fold<double>(
      0.0,
      (sum, emp) => sum + emp.basicSalary.value,
    );
    final totalAllowances = _selectedEmployees.fold<double>(
      0.0,
      (sum, emp) => sum + emp.allowances.value,
    );
    final estimatedCpfEmployee = _selectedEmployees.fold<double>(
      0.0,
      (sum, emp) =>
          sum +
          (emp.isCpfMember.value
              ? emp.totalCompensation * emp.cpfContributionRate.value
              : 0.0),
    );
    final estimatedCpfEmployer = _selectedEmployees.fold<double>(
      0.0,
      (sum, emp) =>
          sum +
          (emp.isCpfMember.value
              ? emp.totalCompensation * 0.17
              : 0.0), // Employer rate
    );
    final estimatedNetPay =
        totalBasicSalary + totalAllowances - estimatedCpfEmployee;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payroll Summary',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('Total Basic Salary', totalBasicSalary),
            _buildSummaryRow('Total Allowances', totalAllowances),
            _buildSummaryRow('Est. Employee CPF', estimatedCpfEmployee,
                isDeduction: true),
            const Divider(),
            _buildSummaryRow('Est. Net Pay', estimatedNetPay, isTotal: true),
            const SizedBox(height: 8),
            _buildSummaryRow('Est. Employer CPF', estimatedCpfEmployer,
                isEmployerCost: true),
            _buildSummaryRow(
                'Est. Total Cost', estimatedNetPay + estimatedCpfEmployer,
                isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount,
      {bool isDeduction = false,
      bool isTotal = false,
      bool isEmployerCost = false}) {
    Color? textColor;
    if (isDeduction) textColor = Colors.red;
    if (isEmployerCost) textColor = Colors.orange;
    if (isTotal) textColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : null,
              color: textColor,
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Process Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _selectedEmployees.isEmpty ? null : _previewPayroll,
                    icon: const Icon(Icons.preview),
                    label: const Text('Preview Payroll'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectedEmployees.isEmpty || _isProcessing
                        ? null
                        : _processPayroll,
                    icon: _isProcessing
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(
                        _isProcessing ? 'Processing...' : 'Process Payroll'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Selected ${_selectedEmployees.length} employees for payroll processing',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayrollHistoryTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _statusFilter,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Status')),
                    DropdownMenuItem(value: 'draft', child: Text('Draft')),
                    DropdownMenuItem(
                        value: 'approved', child: Text('Approved')),
                    DropdownMenuItem(value: 'paid', child: Text('Paid')),
                    DropdownMenuItem(
                        value: 'cancelled', child: Text('Cancelled')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _statusFilter = value!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _exportPayrollData,
                icon: const Icon(Icons.download),
                label: const Text('Export'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _payrollRecords.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No payroll records found'),
                      Text('Process your first payroll to see records here'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: _payrollRecords.length,
                  itemBuilder: (context, index) {
                    final payroll = _payrollRecords[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              _getPayrollStatusColor(payroll.status.value)
                                  .withOpacity(0.1),
                          child: Icon(
                            _getPayrollStatusIcon(payroll.status.value),
                            color: _getPayrollStatusColor(payroll.status.value),
                          ),
                        ),
                        title: Text(payroll.payrollNumber.value),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Period: ${_formatDate(payroll.payPeriodStart.value)} - ${_formatDate(payroll.payPeriodEnd.value)}'),
                            Text(
                                'Net Pay: \$${payroll.netPay.toStringAsFixed(2)}'),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    _getPayrollStatusColor(payroll.status.value)
                                        .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                payroll.status.value.toUpperCase(),
                                style: TextStyle(
                                  color: _getPayrollStatusColor(
                                      payroll.status.value),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(payroll.payDate.value),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        onTap: () => _showPayrollDetails(payroll),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildReportsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReportCard(
            'Monthly Payroll Summary',
            'View comprehensive monthly payroll statistics',
            Icons.summarize,
            () => _generateReport('monthly'),
          ),
          const SizedBox(height: 12),
          _buildReportCard(
            'CPF Contributions Report',
            'Export CPF contributions for submission',
            Icons.account_balance,
            () => _generateReport('cpf'),
          ),
          const SizedBox(height: 12),
          _buildReportCard(
            'Bank Payment File',
            'Generate GIRO file for bank transfer',
            Icons.account_balance_wallet,
            () => _generateReport('bank'),
          ),
          const SizedBox(height: 12),
          _buildReportCard(
            'IR8A Tax Forms',
            'Generate annual tax forms for employees',
            Icons.description,
            () => _generateReport('ir8a'),
          ),
          const SizedBox(height: 12),
          _buildReportCard(
            'Payroll Analytics',
            'View trends and analytics',
            Icons.analytics,
            () => _generateReport('analytics'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(
      String title, String description, IconData icon, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Future<void> _selectPayrollDate(BuildContext context, String dateType) async {
    DateTime initialDate;
    DateTime firstDate;
    DateTime lastDate;

    if (dateType == 'start') {
      initialDate = _payPeriodStart;
      firstDate = DateTime.now().subtract(const Duration(days: 365));
      lastDate = DateTime.now().add(const Duration(days: 30));
    } else {
      initialDate = _payPeriodEnd;
      firstDate = _payPeriodStart;
      lastDate = DateTime.now().add(const Duration(days: 365));
    }

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (pickedDate != null) {
      setState(() {
        if (dateType == 'start') {
          _payPeriodStart = pickedDate;
          // Adjust end date if it's before start date
          if (_payPeriodEnd.isBefore(_payPeriodStart)) {
            _payPeriodEnd =
                DateTime(_payPeriodStart.year, _payPeriodStart.month + 1, 0);
          }
        } else {
          _payPeriodEnd = pickedDate;
        }
      });
    }
  }

  int _calculateWorkingDays() {
    int workingDays = 0;
    DateTime current = _payPeriodStart;

    while (current.isBefore(_payPeriodEnd) ||
        current.isAtSameMomentAs(_payPeriodEnd)) {
      if (current.weekday != DateTime.saturday &&
          current.weekday != DateTime.sunday) {
        workingDays++;
      }
      current = current.add(const Duration(days: 1));
    }

    return workingDays;
  }

  List<CRDTEmployee> _getFilteredEmployees() {
    return _employees.where((emp) {
      if (_departmentFilter != 'all' &&
          emp.department.value != _departmentFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  List<DropdownMenuItem<String>> _getDepartmentOptions() {
    final departments = <String>{'all'};
    for (final emp in _employees) {
      if (emp.department.value != null && emp.department.value!.isNotEmpty) {
        departments.add(emp.department.value!);
      }
    }

    return departments.map((dept) {
      return DropdownMenuItem(
        value: dept,
        child: Text(dept == 'all' ? 'All Departments' : dept),
      );
    }).toList();
  }

  void _showEmployeeSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Employees'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final filteredEmployees = _getFilteredEmployees();
              return ListView.builder(
                itemCount: filteredEmployees.length,
                itemBuilder: (context, index) {
                  final employee = filteredEmployees[index];
                  final isSelected = _selectedEmployees.contains(employee);

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (value) {
                      setDialogState(() {
                        if (value == true) {
                          _selectedEmployees.add(employee);
                        } else {
                          _selectedEmployees.remove(employee);
                        }
                      });
                    },
                    title: Text(employee.fullName),
                    subtitle: Text(
                        '${employee.jobTitle.value} • \$${employee.totalCompensation.toStringAsFixed(0)}'),
                    secondary: CircleAvatar(
                      child: Text(
                          employee.displayName.substring(0, 1).toUpperCase()),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {}); // Refresh main UI
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _previewPayroll() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payroll Preview'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Period: ${_formatDate(_payPeriodStart)} - ${_formatDate(_payPeriodEnd)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'Employees (${_selectedEmployees.length})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ...(_selectedEmployees.map((emp) => ListTile(
                      dense: true,
                      title: Text(emp.fullName),
                      subtitle: Text(emp.jobTitle.value),
                      trailing:
                          Text('\$${emp.totalCompensation.toStringAsFixed(0)}'),
                    ))),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processPayroll();
            },
            child: const Text('Process'),
          ),
        ],
      ),
    );
  }

  Future<void> _processPayroll() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final newPayrollRecords = <CRDTPayrollRecord>[];

      for (final employee in _selectedEmployees) {
        final payroll = await _payrollService.processPayroll(
          employeeId: employee.id,
          employee: employee,
          payPeriodStart: _payPeriodStart,
          payPeriodEnd: _payPeriodEnd,
          // Additional parameters can be added here for overtime, bonuses, etc.
        );

        newPayrollRecords.add(payroll);
      }

      setState(() {
        _payrollRecords.addAll(newPayrollRecords);
        _selectedEmployees.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Payroll processed successfully for ${newPayrollRecords.length} employees'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                _tabController.animateTo(1); // Switch to History tab
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing payroll: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() {
      _isProcessing = false;
    });
  }

  void _showPayrollDetails(CRDTPayrollRecord payroll) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Payroll Details - ${payroll.payrollNumber.value}'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Employee ID', payroll.employeeId.value),
                _buildDetailRow('Period',
                    '${_formatDate(payroll.payPeriodStart.value)} - ${_formatDate(payroll.payPeriodEnd.value)}'),
                _buildDetailRow('Pay Date', _formatDate(payroll.payDate.value)),
                _buildDetailRow('Status', payroll.status.value.toUpperCase()),
                const Divider(),
                const Text('Earnings',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                _buildDetailRow('Basic Salary',
                    '\$${(payroll.basicSalaryCents.value / 100).toStringAsFixed(2)}'),
                _buildDetailRow('Allowances',
                    '\$${(payroll.allowancesCents.value / 100).toStringAsFixed(2)}'),
                _buildDetailRow('Overtime',
                    '\$${(payroll.overtimeCents.value / 100).toStringAsFixed(2)}'),
                _buildDetailRow('Bonus',
                    '\$${(payroll.bonusCents.value / 100).toStringAsFixed(2)}'),
                _buildDetailRow(
                    'Gross Pay', '\$${payroll.grossPay.toStringAsFixed(2)}',
                    isTotal: true),
                const Divider(),
                const Text('Deductions',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                _buildDetailRow('Employee CPF',
                    '\$${(payroll.cpfEmployeeCents.value / 100).toStringAsFixed(2)}'),
                _buildDetailRow('Tax',
                    '\$${(payroll.taxDeductionCents.value / 100).toStringAsFixed(2)}'),
                _buildDetailRow('Other',
                    '\$${(payroll.otherDeductionsCents.value / 100).toStringAsFixed(2)}'),
                _buildDetailRow('Total Deductions',
                    '\$${payroll.totalDeductions.toStringAsFixed(2)}',
                    isTotal: true),
                const Divider(),
                _buildDetailRow(
                    'Net Pay', '\$${payroll.netPay.toStringAsFixed(2)}',
                    isTotal: true, isHighlight: true),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () => _generatePayslip(payroll),
            child: const Text('Generate Payslip'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool isTotal = false, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal || isHighlight ? FontWeight.bold : null,
              color: isHighlight ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight:
                  isTotal || isHighlight ? FontWeight.bold : FontWeight.w500,
              color: isHighlight ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePayslip(CRDTPayrollRecord payroll) async {
    try {
      // Find the employee
      final employee =
          _employees.firstWhere((emp) => emp.id == payroll.employeeId.value);

      // Generate payslip data
      final payslipData =
          _payrollService.generatePayslipData(payroll, employee);

      // Convert to readable format
      final payslipText = _formatPayslipText(payslipData);

      // Save to temporary file
      final directory = await getTemporaryDirectory();
      final file =
          File('${directory.path}/payslip_${payroll.payrollNumber.value}.txt');
      await file.writeAsString(payslipText);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Payslip for ${employee.fullName}',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payslip generated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating payslip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatPayslipText(Map<String, dynamic> payslipData) {
    final employee = payslipData['employee'];
    final payroll = payslipData['payroll'];
    final earnings = payslipData['earnings'];
    final deductions = payslipData['deductions'];
    final employerContrib = payslipData['employer_contributions'];

    return '''
PAYSLIP
=======

Employee Details:
ID: ${employee['id']}
Name: ${employee['name']}
Department: ${employee['department']}
Designation: ${employee['designation']}

Payroll Details:
Number: ${payroll['number']}
Period: ${_formatDate(DateTime.fromMillisecondsSinceEpoch(payroll['period_start']))} - ${_formatDate(DateTime.fromMillisecondsSinceEpoch(payroll['period_end']))}
Pay Date: ${_formatDate(DateTime.fromMillisecondsSinceEpoch(payroll['pay_date']))}

EARNINGS:
Basic Salary: \$${earnings['basic_salary'].toStringAsFixed(2)}
Allowances: \$${earnings['allowances'].toStringAsFixed(2)}
Overtime: \$${earnings['overtime'].toStringAsFixed(2)}
Bonus: \$${earnings['bonus'].toStringAsFixed(2)}
Commission: \$${earnings['commission'].toStringAsFixed(2)}
Reimbursement: \$${earnings['reimbursement'].toStringAsFixed(2)}
---
Gross Pay: \$${earnings['gross_pay'].toStringAsFixed(2)}

DEDUCTIONS:
Employee CPF: \$${deductions['cpf_employee'].toStringAsFixed(2)}
Tax: \$${deductions['tax_deduction'].toStringAsFixed(2)}
Insurance: \$${deductions['insurance'].toStringAsFixed(2)}
Other: \$${deductions['other_deductions'].toStringAsFixed(2)}
---
Total Deductions: \$${deductions['total_deductions'].toStringAsFixed(2)}

NET PAY: \$${payslipData['net_pay'].toStringAsFixed(2)}

EMPLOYER CONTRIBUTIONS:
CPF: \$${employerContrib['cpf_employer'].toStringAsFixed(2)}
SDL: \$${employerContrib['sdl'].toStringAsFixed(2)}
FWL: \$${employerContrib['fwl'].toStringAsFixed(2)}

Generated by BizSync Payroll System
''';
  }

  Future<void> _exportPayrollData() async {
    try {
      final csvData = _generatePayrollCSV();

      final directory = await getTemporaryDirectory();
      final file = File(
          '${directory.path}/payroll_export_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvData);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Payroll Export',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payroll data exported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _generatePayrollCSV() {
    final buffer = StringBuffer();
    buffer.writeln(
        'Payroll Number,Employee ID,Period Start,Period End,Basic Salary,Allowances,Overtime,Bonus,Gross Pay,Employee CPF,Total Deductions,Net Pay,Status');

    for (final payroll in _payrollRecords) {
      buffer.writeln([
        payroll.payrollNumber.value,
        payroll.employeeId.value,
        _formatDate(payroll.payPeriodStart.value),
        _formatDate(payroll.payPeriodEnd.value),
        (payroll.basicSalaryCents.value / 100).toStringAsFixed(2),
        (payroll.allowancesCents.value / 100).toStringAsFixed(2),
        (payroll.overtimeCents.value / 100).toStringAsFixed(2),
        (payroll.bonusCents.value / 100).toStringAsFixed(2),
        payroll.grossPay.toStringAsFixed(2),
        (payroll.cpfEmployeeCents.value / 100).toStringAsFixed(2),
        payroll.totalDeductions.toStringAsFixed(2),
        payroll.netPay.toStringAsFixed(2),
        payroll.status.value,
      ].join(','));
    }

    return buffer.toString();
  }

  Future<void> _generateReport(String reportType) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Generate ${reportType.toUpperCase()} Report'),
        content: const Text(
            'This feature will generate the selected report. Implementation depends on specific business requirements.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        '${reportType.toUpperCase()} report generation started')),
              );
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }

  Color _getPayrollStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return Colors.grey;
      case 'approved':
        return Colors.blue;
      case 'paid':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getPayrollStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return Icons.drafts;
      case 'approved':
        return Icons.check_circle;
      case 'paid':
        return Icons.payment;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
