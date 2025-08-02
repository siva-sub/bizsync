import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/crdt/hybrid_logical_clock.dart';
import '../../../core/utils/uuid_generator.dart';
import '../models/employee_models.dart';
import '../services/employee_service.dart';
import 'employee_form_screen.dart';
import 'employee_details_screen.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/notification_service.dart';

class EmployeeListScreen extends ConsumerStatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  ConsumerState<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends ConsumerState<EmployeeListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  EmploymentStatus? _statusFilter;
  WorkPermitType? _workPermitFilter;
  String? _departmentFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Management'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            onPressed: () => _navigateToPayrollManagement(context),
            tooltip: 'Payroll Management',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter Employees',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          Expanded(
            child: _buildEmployeeDataTable(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddEmployee(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Employee'),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search employees by name, ID, or email...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          if (_hasActiveFilters()) ...[
            const SizedBox(height: 8),
            _buildActiveFiltersChips(),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveFiltersChips() {
    return Wrap(
      spacing: 8.0,
      children: [
        if (_statusFilter != null)
          Chip(
            label: Text('Status: ${_statusFilter!.name}'),
            onDeleted: () => setState(() => _statusFilter = null),
          ),
        if (_workPermitFilter != null)
          Chip(
            label: Text('Work Pass: ${_workPermitFilter!.name}'),
            onDeleted: () => setState(() => _workPermitFilter = null),
          ),
        if (_departmentFilter != null)
          Chip(
            label: Text('Dept: $_departmentFilter'),
            onDeleted: () => setState(() => _departmentFilter = null),
          ),
      ],
    );
  }

  Widget _buildEmployeeDataTable() {
    return FutureBuilder<List<CRDTEmployee>>(
      future: _getFilteredEmployees(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final employees = snapshot.data ?? [];

        if (employees.isEmpty) {
          return _buildEmptyState();
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Employee ID')),
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Department')),
                DataColumn(label: Text('Position')),
                DataColumn(label: Text('Work Pass')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Salary'), numeric: true),
                DataColumn(label: Text('Leave Balance'), numeric: true),
                DataColumn(label: Text('Actions')),
              ],
              rows: employees.map((employee) => _buildEmployeeRow(employee)).toList(),
            ),
          ),
        );
      },
    );
  }

  DataRow _buildEmployeeRow(CRDTEmployee employee) {
    return DataRow(
      cells: [
        DataCell(Text(employee.employeeId.value)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: _getStatusColor(employee.employmentStatus.value),
                child: Text(
                  employee.displayName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(employee.fullName, style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text(employee.email.value, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
        DataCell(Text(employee.department.value ?? 'Not assigned')),
        DataCell(Text(employee.jobTitle.value)),
        DataCell(_buildWorkPassChip(employee.workPermitType.value)),
        DataCell(_buildStatusChip(employee.employmentStatus.value)),
        DataCell(Text('\$${employee.totalCompensation.toStringAsFixed(0)}')),
        DataCell(Text('${employee.totalLeaveBalance} days')),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility, size: 20),
                onPressed: () => _navigateToEmployeeDetails(context, employee),
                tooltip: 'View Details',
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => _navigateToEditEmployee(context, employee),
                tooltip: 'Edit Employee',
              ),
              IconButton(
                icon: const Icon(Icons.receipt, size: 20),
                onPressed: () => _generatePayslip(employee),
                tooltip: 'Generate Payslip',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorkPassChip(String workPassType) {
    final color = _getWorkPassColor(workPassType);
    return Chip(
      label: Text(
        workPassType.toUpperCase(),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color),
    );
  }

  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);
    return Chip(
      label: Text(
        status.toUpperCase(),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No employees found',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            _hasActiveFilters() 
                ? 'Try adjusting your filters or search terms'
                : 'Add your first employee to get started',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navigateToAddEmployee(context),
            icon: const Icon(Icons.person_add),
            label: const Text('Add Employee'),
          ),
        ],
      ),
    );
  }

  Future<List<CRDTEmployee>> _getFilteredEmployees() async {
    final employeeService = EmployeeService(NotificationService());
    List<CRDTEmployee> employees = await employeeService.getAllEmployees();

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      employees = employees.where((employee) {
        return employee.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               employee.employeeId.value.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               employee.email.value.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Apply status filter
    if (_statusFilter != null) {
      employees = employees.where((employee) {
        return employee.employmentStatus.value == _statusFilter!.name;
      }).toList();
    }

    // Apply work permit filter
    if (_workPermitFilter != null) {
      employees = employees.where((employee) {
        return employee.workPermitType.value == _workPermitFilter!.name;
      }).toList();
    }

    // Apply department filter
    if (_departmentFilter != null) {
      employees = employees.where((employee) {
        return employee.department.value == _departmentFilter;
      }).toList();
    }

    // Sort by name
    employees.sort((a, b) => a.fullName.compareTo(b.fullName));

    return employees;
  }

  bool _hasActiveFilters() {
    return _statusFilter != null || _workPermitFilter != null || _departmentFilter != null;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'onleave':
        return Colors.orange;
      case 'suspended':
        return Colors.red;
      case 'terminated':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  Color _getWorkPassColor(String workPassType) {
    switch (workPassType.toLowerCase()) {
      case 'citizen':
        return Colors.blue;
      case 'pr':
        return Colors.green;
      case 'ep':
        return Colors.purple;
      case 'sp':
        return Colors.orange;
      case 'wp':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Employees'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<EmploymentStatus>(
                value: _statusFilter,
                decoration: const InputDecoration(labelText: 'Employment Status'),
                items: EmploymentStatus.values.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(status.name),
                  );
                }).toList(),
                onChanged: (value) => setDialogState(() => _statusFilter = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<WorkPermitType>(
                value: _workPermitFilter,
                decoration: const InputDecoration(labelText: 'Work Pass Type'),
                items: WorkPermitType.values.map((workPass) {
                  return DropdownMenuItem(
                    value: workPass,
                    child: Text(workPass.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) => setDialogState(() => _workPermitFilter = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _statusFilter = null;
                _workPermitFilter = null;
                _departmentFilter = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Clear All'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {}); // Refresh the list
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _navigateToAddEmployee(BuildContext context) {
    context.go('/employees/create');
  }

  void _navigateToEditEmployee(BuildContext context, CRDTEmployee employee) {
    context.go('/employees/${employee.id}/edit');
  }

  void _navigateToEmployeeDetails(BuildContext context, CRDTEmployee employee) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmployeeDetailsScreen(employeeId: employee.id),
      ),
    );
  }

  void _navigateToPayrollManagement(BuildContext context) {
    context.go('/payroll');
  }

  void _generatePayslip(CRDTEmployee employee) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generating payslip for ${employee.fullName}...'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            // Navigate to payslip view
          },
        ),
      ),
    );
  }
}