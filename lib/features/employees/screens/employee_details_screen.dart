import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/employee_models.dart';
import '../services/employee_service.dart';
import '../../../core/utils/date_utils.dart';

class EmployeeDetailsScreen extends ConsumerStatefulWidget {
  final String employeeId;

  const EmployeeDetailsScreen({super.key, required this.employeeId});

  @override
  ConsumerState<EmployeeDetailsScreen> createState() => _EmployeeDetailsScreenState();
}

class _EmployeeDetailsScreenState extends ConsumerState<EmployeeDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CRDTEmployee? _employee;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadEmployee();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployee() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final employeeService = await EmployeeService.getInstance();
      final employee = await employeeService.getEmployee(widget.employeeId);

      setState(() {
        _employee = employee;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Employee'),
        content: Text(
          'Are you sure you want to delete ${_employee?.firstName.value} ${_employee?.lastName.value}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final employeeService = await EmployeeService.getInstance();
        await employeeService.deleteEmployee(widget.employeeId);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Employee deleted successfully')),
          );
          context.go('/employees');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting employee: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_employee != null 
            ? '${_employee!.firstName.value} ${_employee!.lastName.value}'
            : 'Employee Details'),
        backgroundColor: colorScheme.inversePrimary,
        actions: [
          if (_employee != null) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.go('/employees/${widget.employeeId}/edit'),
              tooltip: 'Edit Employee',
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'delete':
                    _showDeleteConfirmation();
                    break;
                  case 'payroll':
                    context.go('/employees/${widget.employeeId}/payroll');
                    break;
                  case 'leave':
                    context.go('/employees/${widget.employeeId}/leave');
                    break;
                  case 'cpf':
                    context.go('/employees/cpf-calculator');
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'payroll',
                  child: ListTile(
                    leading: Icon(Icons.attach_money),
                    title: Text('View Payroll'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'leave',
                  child: ListTile(
                    leading: Icon(Icons.event_busy),
                    title: Text('Leave Management'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'cpf',
                  child: ListTile(
                    leading: Icon(Icons.calculate),
                    title: Text('CPF Calculator'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Delete Employee', style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ],
        bottom: _employee != null
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.person), text: 'Personal'),
                  Tab(icon: Icon(Icons.work), text: 'Employment'),
                  Tab(icon: Icon(Icons.account_balance_wallet), text: 'Payroll'),
                  Tab(icon: Icon(Icons.event), text: 'Leave'),
                ],
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading employee details...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Employee',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadEmployee,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_employee == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off,
              size: 64,
              color: Colors.grey.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Employee Not Found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'The requested employee could not be found.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/employees'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Employees'),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildPersonalTab(),
        _buildEmploymentTab(),
        _buildPayrollTab(),
        _buildLeaveTab(),
      ],
    );
  }

  Widget _buildPersonalTab() {
    final employee = _employee!;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.blue.withValues(alpha: 0.2),
                    child: employee.profilePicture.value != null
                        ? ClipOval(
                            child: Image.network(
                              employee.profilePicture.value!,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.blue[600],
                                );
                              },
                            ),
                          )
                        : Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.blue[600],
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${employee.firstName.value} ${employee.lastName.value}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (employee.preferredName.value != null)
                          Text(
                            'Preferred: ${employee.preferredName.value}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          employee.jobTitle.value,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.blue[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'ID: ${employee.employeeId.value}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _copyToClipboard(employee.employeeId.value, 'Employee ID'),
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy Employee ID',
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),

          // Contact Information
          _buildSectionCard(
            'Contact Information',
            Icons.contact_phone,
            [
              _buildInfoTile(
                'Email',
                employee.email.value,
                Icons.email,
                onTap: () => _copyToClipboard(employee.email.value, 'Email'),
              ),
              if (employee.phone.value != null)
                _buildInfoTile(
                  'Phone',
                  employee.phone.value!,
                  Icons.phone,
                  onTap: () => _copyToClipboard(employee.phone.value!, 'Phone'),
                ),
              if (employee.address.value != null)
                _buildInfoTile(
                  'Address',
                  employee.address.value!,
                  Icons.location_on,
                  onTap: () => _copyToClipboard(employee.address.value!, 'Address'),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Personal Details
          _buildSectionCard(
            'Personal Details',
            Icons.person_outline,
            [
              if (employee.dateOfBirth.value != null)
                _buildInfoTile(
                  'Date of Birth',
                  AppDateUtils.formatDate(employee.dateOfBirth.value!),
                  Icons.cake,
                ),
              if (employee.nationality.value != null)
                _buildInfoTile(
                  'Nationality',
                  employee.nationality.value!,
                  Icons.flag,
                ),
              if (employee.nricFinNumber.value != null)
                _buildInfoTile(
                  'NRIC/FIN',
                  employee.nricFinNumber.value!,
                  Icons.credit_card,
                  onTap: () => _copyToClipboard(employee.nricFinNumber.value!, 'NRIC/FIN'),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Emergency Contact
          if (employee.emergencyContactName.value != null)
            _buildSectionCard(
              'Emergency Contact',
              Icons.emergency,
              [
                _buildInfoTile(
                  'Name',
                  employee.emergencyContactName.value!,
                  Icons.person,
                ),
                if (employee.emergencyContactPhone.value != null)
                  _buildInfoTile(
                    'Phone',
                    employee.emergencyContactPhone.value!,
                    Icons.phone,
                    onTap: () => _copyToClipboard(employee.emergencyContactPhone.value!, 'Emergency Contact Phone'),
                  ),
                if (employee.emergencyContactRelationship.value != null)
                  _buildInfoTile(
                    'Relationship',
                    employee.emergencyContactRelationship.value!,
                    Icons.family_restroom,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEmploymentTab() {
    final employee = _employee!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Employment Status
          Card(
            color: _getStatusColor(employee.employmentStatus.value).withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(employee.employmentStatus.value),
                    color: _getStatusColor(employee.employmentStatus.value),
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Employment Status',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          _getStatusDisplayName(employee.employmentStatus.value),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(employee.employmentStatus.value),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Job Information
          _buildSectionCard(
            'Job Information',
            Icons.work,
            [
              _buildInfoTile(
                'Job Title',
                employee.jobTitle.value,
                Icons.badge,
              ),
              if (employee.department.value != null)
                _buildInfoTile(
                  'Department',
                  employee.department.value!,
                  Icons.business,
                ),
              _buildInfoTile(
                'Employment Type',
                _getEmploymentTypeDisplayName(employee.employmentType.value),
                Icons.work_outline,
              ),
              _buildInfoTile(
                'Start Date',
                AppDateUtils.formatDate(employee.startDate.value),
                Icons.calendar_today,
              ),
              if (employee.endDate.value != null)
                _buildInfoTile(
                  'End Date',
                  AppDateUtils.formatDate(employee.endDate.value!),
                  Icons.event_busy,
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Work Authorization (Singapore specific)
          _buildSectionCard(
            'Work Authorization',
            Icons.verified_user,
            [
              _buildInfoTile(
                'Work Permit Type',
                _getWorkPermitDisplayName(employee.workPermitType.value),
                Icons.card_membership,
              ),
              if (employee.workPermitNumber.value != null)
                _buildInfoTile(
                  'Permit Number',
                  employee.workPermitNumber.value!,
                  Icons.confirmation_number,
                  onTap: () => _copyToClipboard(employee.workPermitNumber.value!, 'Permit Number'),
                ),
              if (employee.workPermitExpiry.value != null)
                _buildInfoTile(
                  'Permit Expiry',
                  AppDateUtils.formatDate(employee.workPermitExpiry.value!),
                  Icons.schedule,
                  subtitle: _getExpiryStatus(employee.workPermitExpiry.value!),
                ),
              _buildInfoTile(
                'Local Employee',
                employee.isLocalEmployee.value ? 'Yes' : 'No',
                Icons.location_city,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollTab() {
    final employee = _employee!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Salary Information
          _buildSectionCard(
            'Salary Information',
            Icons.attach_money,
            [
              _buildInfoTile(
                'Basic Salary',
                'S\$${employee.basicSalary.value.toStringAsFixed(2)}',
                Icons.payments,
              ),
              _buildInfoTile(
                'Allowances',
                'S\$${employee.allowances.value.toStringAsFixed(2)}',
                Icons.add_circle,
              ),
              _buildInfoTile(
                'Pay Frequency',
                _getPayFrequencyDisplayName(employee.payFrequency.value),
                Icons.schedule,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Bank Information
          _buildSectionCard(
            'Bank Information',
            Icons.account_balance,
            [
              if (employee.bankAccount.value != null)
                _buildInfoTile(
                  'Account Number',
                  employee.bankAccount.value!,
                  Icons.account_balance_wallet,
                  onTap: () => _copyToClipboard(employee.bankAccount.value!, 'Account Number'),
                ),
              if (employee.bankCode.value != null)
                _buildInfoTile(
                  'Bank Code',
                  employee.bankCode.value!,
                  Icons.business,
                ),
            ],
          ),

          const SizedBox(height: 16),

          // CPF Information (Singapore specific)
          _buildSectionCard(
            'CPF Information',
            Icons.savings,
            [
              _buildInfoTile(
                'CPF Member',
                employee.isCpfMember.value ? 'Yes' : 'No',
                Icons.verified,
              ),
              if (employee.cpfNumber.value != null)
                _buildInfoTile(
                  'CPF Number',
                  employee.cpfNumber.value!,
                  Icons.card_membership,
                  onTap: () => _copyToClipboard(employee.cpfNumber.value!, 'CPF Number'),
                ),
              _buildInfoTile(
                'Contribution Rate',
                '${(employee.cpfContributionRate.value * 100).toStringAsFixed(1)}%',
                Icons.percent,
              ),
              _buildInfoTile(
                'Ordinary Wage',
                'S\$${employee.cpfOrdinaryWage.value.toStringAsFixed(2)}',
                Icons.account_balance_wallet,
              ),
              if (employee.cpfAdditionalWage.value > 0)
                _buildInfoTile(
                  'Additional Wage',
                  'S\$${employee.cpfAdditionalWage.value.toStringAsFixed(2)}',
                  Icons.add,
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Quick Actions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payroll Actions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.go('/employees/cpf-calculator'),
                          icon: const Icon(Icons.calculate),
                          label: const Text('CPF Calculator'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.go('/employees/${widget.employeeId}/payroll'),
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('Payslips'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveTab() {
    final employee = _employee!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Leave Balances
          _buildSectionCard(
            'Leave Balances',
            Icons.event_available,
            [
              _buildLeaveBalanceTile(
                'Annual Leave',
                employee.annualLeaveBalance.value,
                Icons.beach_access,
                Colors.blue,
              ),
              _buildLeaveBalanceTile(
                'Sick Leave',
                employee.sickLeaveBalance.value,
                Icons.local_hospital,
                Colors.red,
              ),
              _buildLeaveBalanceTile(
                'Maternity Leave',
                employee.maternitylLeaveBalance.value,
                Icons.child_care,
                Colors.pink,
              ),
              _buildLeaveBalanceTile(
                'Paternity Leave',
                employee.paternitylLeaveBalance.value,
                Icons.family_restroom,
                Colors.green,
              ),
              _buildLeaveBalanceTile(
                'Compassionate Leave',
                employee.compassionateLeaveBalance.value,
                Icons.favorite,
                Colors.purple,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Quick Actions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Leave Actions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.go('/employees/${widget.employeeId}/leave/apply'),
                          icon: const Icon(Icons.add),
                          label: const Text('Apply Leave'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.go('/employees/${widget.employeeId}/leave/history'),
                          icon: const Icon(Icons.history),
                          label: const Text('Leave History'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    String label,
    String value,
    IconData icon, {
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          if (onTap != null)
            IconButton(
              onPressed: onTap,
              icon: const Icon(Icons.copy, size: 16),
              tooltip: 'Copy $label',
            ),
        ],
      ),
    );
  }

  Widget _buildLeaveBalanceTile(String label, int balance, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '$balance days',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              balance.toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'on_leave':
      case 'onleave':
        return Colors.orange;
      case 'suspended':
        return Colors.red;
      case 'terminated':
        return Colors.grey;
      case 'retired':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Icons.check_circle;
      case 'on_leave':
      case 'onleave':
        return Icons.event_busy;
      case 'suspended':
        return Icons.pause_circle;
      case 'terminated':
        return Icons.cancel;
      case 'retired':
        return Icons.cake;
      default:
        return Icons.help;
    }
  }

  String _getStatusDisplayName(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Active';
      case 'on_leave':
      case 'onleave':
        return 'On Leave';
      case 'suspended':
        return 'Suspended';
      case 'terminated':
        return 'Terminated';
      case 'retired':
        return 'Retired';
      default:
        return status;
    }
  }

  String _getEmploymentTypeDisplayName(String type) {
    switch (type.toLowerCase()) {
      case 'full_time':
        return 'Full Time';
      case 'part_time':
        return 'Part Time';
      case 'contract':
        return 'Contract';
      case 'intern':
        return 'Intern';
      case 'freelancer':
        return 'Freelancer';
      default:
        return type;
    }
  }

  String _getWorkPermitDisplayName(String permitType) {
    switch (permitType.toLowerCase()) {
      case 'citizen':
        return 'Singapore Citizen';
      case 'pr':
        return 'Permanent Resident';
      case 'prfirst2years':
        return 'PR (First 2 Years)';
      case 'ep':
        return 'Employment Pass';
      case 'sp':
        return 'S Pass';
      case 'wp':
        return 'Work Permit';
      case 'twr':
        return 'Training Work Permit';
      case 'pep':
        return 'Personalised Employment Pass';
      case 'onepass':
        return 'Tech.Pass/ONE Pass';
      case 'studentpass':
        return 'Student Pass';
      case 'dependentpass':
        return 'Dependent Pass';
      default:
        return permitType;
    }
  }

  String _getPayFrequencyDisplayName(String frequency) {
    switch (frequency.toLowerCase()) {
      case 'monthly':
        return 'Monthly';
      case 'bi_weekly':
        return 'Bi-weekly';
      case 'weekly':
        return 'Weekly';
      default:
        return frequency;
    }
  }

  String _getExpiryStatus(DateTime expiryDate) {
    final now = DateTime.now();
    final difference = expiryDate.difference(now).inDays;
    
    if (difference < 0) {
      return 'Expired';
    } else if (difference <= 30) {
      return 'Expires in $difference days';
    } else {
      return 'Valid';
    }
  }
}
