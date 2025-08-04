import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/crdt/hybrid_logical_clock.dart';
import '../../../core/crdt/vector_clock.dart';
import '../../../core/utils/uuid_generator.dart';
import '../../../core/services/notification_service.dart';
import '../models/employee_models.dart';
import '../services/employee_service.dart';

class EmployeeFormScreen extends ConsumerStatefulWidget {
  final CRDTEmployee? employee;

  const EmployeeFormScreen({super.key, this.employee});

  @override
  ConsumerState<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends ConsumerState<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeService = EmployeeService(NotificationService());

  bool _isLoading = false;
  bool _isEditing = false;

  // Form controllers
  final _employeeIdController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _preferredNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _nricFinController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _departmentController = TextEditingController();
  final _basicSalaryController = TextEditingController();
  final _allowancesController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankCodeController = TextEditingController();
  final _cpfNumberController = TextEditingController();
  final _workPermitNumberController = TextEditingController();
  final _emergencyContactNameController = TextEditingController();
  final _emergencyContactPhoneController = TextEditingController();
  final _emergencyContactRelationshipController = TextEditingController();

  // Form values
  DateTime? _dateOfBirth;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  DateTime? _workPermitExpiry;
  String _nationality = 'Singapore';
  EmploymentStatus _employmentStatus = EmploymentStatus.active;
  EmployeeType _employmentType = EmployeeType.fullTime;
  WorkPermitType _workPermitType = WorkPermitType.citizen;
  String _payFrequency = 'monthly';
  bool _isCpfMember = true;
  double _cpfContributionRate = 0.2;

  // Leave balances
  int _annualLeaveBalance = 14;
  int _sickLeaveBalance = 14;
  int _maternityLeaveBalance = 112; // 16 weeks
  int _paternityLeaveBalance = 14; // 2 weeks
  int _compassionateLeaveBalance = 3;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.employee != null;
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.employee != null) {
      final emp = widget.employee!;
      _employeeIdController.text = emp.employeeId.value;
      _firstNameController.text = emp.firstName.value;
      _lastNameController.text = emp.lastName.value;
      _preferredNameController.text = emp.preferredName.value ?? '';
      _emailController.text = emp.email.value;
      _phoneController.text = emp.phone.value ?? '';
      _addressController.text = emp.address.value ?? '';
      _nricFinController.text = emp.nricFinNumber.value ?? '';
      _jobTitleController.text = emp.jobTitle.value;
      _departmentController.text = emp.department.value ?? '';
      _basicSalaryController.text = emp.basicSalary.value.toString();
      _allowancesController.text = emp.allowances.value.toString();
      _bankAccountController.text = emp.bankAccount.value ?? '';
      _bankCodeController.text = emp.bankCode.value ?? '';
      _cpfNumberController.text = emp.cpfNumber.value ?? '';
      _workPermitNumberController.text = emp.workPermitNumber.value ?? '';
      _emergencyContactNameController.text =
          emp.emergencyContactName.value ?? '';
      _emergencyContactPhoneController.text =
          emp.emergencyContactPhone.value ?? '';
      _emergencyContactRelationshipController.text =
          emp.emergencyContactRelationship.value ?? '';

      _dateOfBirth = emp.dateOfBirth.value;
      _startDate = emp.startDate.value;
      _endDate = emp.endDate.value;
      _workPermitExpiry = emp.workPermitExpiry.value;
      _nationality = emp.nationality.value ?? 'Singapore';

      // Parse enums
      _employmentStatus = EmploymentStatus.values.firstWhere(
        (e) => e.name == emp.employmentStatus.value,
        orElse: () => EmploymentStatus.active,
      );
      _employmentType = EmployeeType.values.firstWhere(
        (e) => e.name == emp.employmentType.value,
        orElse: () => EmployeeType.fullTime,
      );
      _workPermitType = WorkPermitType.values.firstWhere(
        (e) => e.name == emp.workPermitType.value,
        orElse: () => WorkPermitType.citizen,
      );

      _payFrequency = emp.payFrequency.value;
      _isCpfMember = emp.isCpfMember.value;
      _cpfContributionRate = emp.cpfContributionRate.value;

      // Leave balances
      _annualLeaveBalance = emp.annualLeaveBalance.value;
      _sickLeaveBalance = emp.sickLeaveBalance.value;
      _maternityLeaveBalance = emp.maternitylLeaveBalance.value;
      _paternityLeaveBalance = emp.paternitylLeaveBalance.value;
      _compassionateLeaveBalance = emp.compassionateLeaveBalance.value;
    } else {
      // Generate employee ID for new employee
      _employeeIdController.text = _generateEmployeeId();
    }

    // Update CPF settings based on work permit type and age
    _updateCpfSettings();
  }

  String _generateEmployeeId() {
    final now = DateTime.now();
    return 'EMP${now.year}${now.month.toString().padLeft(2, '0')}${(now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}';
  }

  void _updateCpfSettings() {
    setState(() {
      if (_workPermitType == WorkPermitType.citizen ||
          _workPermitType == WorkPermitType.pr) {
        _isCpfMember = true;

        // Calculate CPF rate based on age
        if (_dateOfBirth != null) {
          final age = DateTime.now().year - _dateOfBirth!.year;
          if (age <= 50) {
            _cpfContributionRate = 0.2; // 20%
          } else if (age <= 55) {
            _cpfContributionRate = 0.2;
          } else if (age <= 60) {
            _cpfContributionRate = 0.135; // 13.5%
          } else if (age <= 65) {
            _cpfContributionRate = 0.075; // 7.5%
          } else {
            _cpfContributionRate = 0.05; // 5%
          }
        }
      } else {
        _isCpfMember = false;
        _cpfContributionRate = 0.0;
      }
    });
  }

  @override
  void dispose() {
    _employeeIdController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _preferredNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _nricFinController.dispose();
    _jobTitleController.dispose();
    _departmentController.dispose();
    _basicSalaryController.dispose();
    _allowancesController.dispose();
    _bankAccountController.dispose();
    _bankCodeController.dispose();
    _cpfNumberController.dispose();
    _workPermitNumberController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactPhoneController.dispose();
    _emergencyContactRelationshipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Employee' : 'Add Employee'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _showDeleteConfirmation,
              tooltip: 'Delete Employee',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPersonalDetailsSection(),
                    const SizedBox(height: 24),
                    _buildEmploymentDetailsSection(),
                    const SizedBox(height: 24),
                    _buildWorkPassSection(),
                    const SizedBox(height: 24),
                    _buildSalaryBenefitsSection(),
                    const SizedBox(height: 24),
                    _buildCpfSection(),
                    const SizedBox(height: 24),
                    _buildBankDetailsSection(),
                    const SizedBox(height: 24),
                    _buildLeaveBalancesSection(),
                    const SizedBox(height: 24),
                    _buildEmergencyContactSection(),
                    const SizedBox(height: 32),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPersonalDetailsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personal Details',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _employeeIdController,
              decoration: const InputDecoration(
                labelText: 'Employee ID',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
              readOnly: _isEditing,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter employee ID';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'First Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter first name';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Last Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter last name';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _preferredNameController,
              decoration: const InputDecoration(
                labelText: 'Preferred Name (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter email address';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                    .hasMatch(value)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.home),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, 'dob'),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date of Birth',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.cake),
                      ),
                      child: Text(
                        _dateOfBirth != null
                            ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                            : 'Select date',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _nationality,
                    decoration: const InputDecoration(
                      labelText: 'Nationality',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.flag),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'Singapore', child: Text('Singapore')),
                      DropdownMenuItem(
                          value: 'Malaysia', child: Text('Malaysia')),
                      DropdownMenuItem(value: 'India', child: Text('India')),
                      DropdownMenuItem(value: 'China', child: Text('China')),
                      DropdownMenuItem(
                          value: 'Philippines', child: Text('Philippines')),
                      DropdownMenuItem(
                          value: 'Indonesia', child: Text('Indonesia')),
                      DropdownMenuItem(
                          value: 'Myanmar', child: Text('Myanmar')),
                      DropdownMenuItem(
                          value: 'Bangladesh', child: Text('Bangladesh')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _nationality = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nricFinController,
              decoration: const InputDecoration(
                labelText: 'NRIC/FIN Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.credit_card),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                LengthLimitingTextInputFormatter(9),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmploymentDetailsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Employment Details',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _jobTitleController,
              decoration: const InputDecoration(
                labelText: 'Job Title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.work),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter job title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _departmentController,
              decoration: const InputDecoration(
                labelText: 'Department',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, 'start'),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start Date',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, 'end'),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'End Date (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.event_available),
                      ),
                      child: Text(
                        _endDate != null
                            ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                            : 'Not set',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<EmploymentStatus>(
                    value: _employmentStatus,
                    decoration: const InputDecoration(
                      labelText: 'Employment Status',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.work_outline),
                    ),
                    items: EmploymentStatus.values.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(_getEmploymentStatusDisplayName(status)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _employmentStatus = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<EmployeeType>(
                    value: _employmentType,
                    decoration: const InputDecoration(
                      labelText: 'Employment Type',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: EmployeeType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(_getEmployeeTypeDisplayName(type)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _employmentType = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkPassSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Work Pass Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<WorkPermitType>(
              value: _workPermitType,
              decoration: const InputDecoration(
                labelText: 'Work Pass Type',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.card_membership),
              ),
              items: WorkPermitType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_getWorkPermitTypeDisplayName(type)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _workPermitType = value!;
                  _updateCpfSettings();
                });
              },
            ),
            const SizedBox(height: 16),
            if (_workPermitType != WorkPermitType.citizen) ...[
              TextFormField(
                controller: _workPermitNumberController,
                decoration: const InputDecoration(
                  labelText: 'Work Pass Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.confirmation_number),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectDate(context, 'workPermitExpiry'),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Work Pass Expiry Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.event_busy),
                  ),
                  child: Text(
                    _workPermitExpiry != null
                        ? '${_workPermitExpiry!.day}/${_workPermitExpiry!.month}/${_workPermitExpiry!.year}'
                        : 'Select expiry date',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSalaryBenefitsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Salary & Benefits',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _basicSalaryController,
                    decoration: const InputDecoration(
                      labelText: 'Basic Salary (SGD)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter basic salary';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid amount';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _allowancesController,
                    decoration: const InputDecoration(
                      labelText: 'Allowances (SGD)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.money),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _payFrequency,
              decoration: const InputDecoration(
                labelText: 'Pay Frequency',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.schedule),
              ),
              items: const [
                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                DropdownMenuItem(value: 'bi_weekly', child: Text('Bi-weekly')),
                DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
              ],
              onChanged: (value) {
                setState(() {
                  _payFrequency = value!;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCpfSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CPF Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('CPF Member'),
              subtitle: Text(_isCpfMember
                  ? 'Subject to CPF contributions'
                  : 'Not subject to CPF'),
              value: _isCpfMember,
              onChanged: (_workPermitType == WorkPermitType.citizen ||
                      _workPermitType == WorkPermitType.pr)
                  ? null // Disabled for citizens and PRs
                  : (value) {
                      setState(() {
                        _isCpfMember = value;
                        if (!value) {
                          _cpfContributionRate = 0.0;
                        }
                      });
                    },
            ),
            if (_isCpfMember) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _cpfNumberController,
                decoration: const InputDecoration(
                  labelText: 'CPF Account Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue:
                    '${(_cpfContributionRate * 100).toStringAsFixed(1)}%',
                decoration: const InputDecoration(
                  labelText: 'CPF Contribution Rate',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.percent),
                ),
                readOnly: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBankDetailsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bank Details',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _bankCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Bank Code',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance),
                      hintText: 'e.g., DBS, OCBC, UOB',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _bankAccountController,
                    decoration: const InputDecoration(
                      labelText: 'Bank Account Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance_wallet),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveBalancesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Leave Balances (Days)',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _annualLeaveBalance.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Annual Leave',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.beach_access),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _annualLeaveBalance = int.tryParse(value) ?? 0;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: _sickLeaveBalance.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Sick Leave',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.local_hospital),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _sickLeaveBalance = int.tryParse(value) ?? 0;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _maternityLeaveBalance.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Maternity Leave',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.pregnant_woman),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _maternityLeaveBalance = int.tryParse(value) ?? 0;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: _paternityLeaveBalance.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Paternity Leave',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.family_restroom),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _paternityLeaveBalance = int.tryParse(value) ?? 0;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _compassionateLeaveBalance.toString(),
              decoration: const InputDecoration(
                labelText: 'Compassionate Leave',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.favorite),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                _compassionateLeaveBalance = int.tryParse(value) ?? 0;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyContactSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emergency Contact',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emergencyContactNameController,
              decoration: const InputDecoration(
                labelText: 'Contact Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _emergencyContactPhoneController,
                    decoration: const InputDecoration(
                      labelText: 'Contact Phone',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _emergencyContactRelationshipController,
                    decoration: const InputDecoration(
                      labelText: 'Relationship',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.group),
                      hintText: 'e.g., Spouse, Parent',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveEmployee,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isEditing ? 'Update Employee' : 'Save Employee'),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context, String dateType) async {
    DateTime? initialDate;
    DateTime firstDate;
    DateTime lastDate;

    switch (dateType) {
      case 'dob':
        initialDate = _dateOfBirth ?? DateTime(1990);
        firstDate = DateTime(1920);
        lastDate = DateTime.now();
        break;
      case 'start':
        initialDate = _startDate;
        firstDate = DateTime(2000);
        lastDate = DateTime.now().add(const Duration(days: 365));
        break;
      case 'end':
        initialDate = _endDate ?? DateTime.now();
        firstDate = _startDate;
        lastDate = DateTime.now().add(const Duration(days: 365 * 5));
        break;
      case 'workPermitExpiry':
        initialDate =
            _workPermitExpiry ?? DateTime.now().add(const Duration(days: 365));
        firstDate = DateTime.now();
        lastDate = DateTime.now().add(const Duration(days: 365 * 10));
        break;
      default:
        return;
    }

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (pickedDate != null) {
      setState(() {
        switch (dateType) {
          case 'dob':
            _dateOfBirth = pickedDate;
            _updateCpfSettings();
            break;
          case 'start':
            _startDate = pickedDate;
            break;
          case 'end':
            _endDate = pickedDate;
            break;
          case 'workPermitExpiry':
            _workPermitExpiry = pickedDate;
            break;
        }
      });
    }
  }

  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final nodeId = UuidGenerator.generateId();
      final timestamp = HLCTimestamp.now(nodeId);

      if (_isEditing) {
        // Update existing employee
        final employee = widget.employee!;

        employee.updatePersonalInfo(
          newFirstName: _firstNameController.text,
          newLastName: _lastNameController.text,
          newPreferredName: _preferredNameController.text.isEmpty
              ? null
              : _preferredNameController.text,
          newEmail: _emailController.text,
          newPhone:
              _phoneController.text.isEmpty ? null : _phoneController.text,
          newAddress:
              _addressController.text.isEmpty ? null : _addressController.text,
          newDateOfBirth: _dateOfBirth,
          newNationality: _nationality,
          newNricFin:
              _nricFinController.text.isEmpty ? null : _nricFinController.text,
          timestamp: timestamp,
        );

        employee.updateEmploymentDetails(
          newJobTitle: _jobTitleController.text,
          newDepartment: _departmentController.text.isEmpty
              ? null
              : _departmentController.text,
          newEndDate: _endDate,
          newStatus: _employmentStatus.name,
          newType: _employmentType.name,
          timestamp: timestamp,
        );

        employee.updateSalary(
          newBasicSalary: double.parse(_basicSalaryController.text),
          newAllowances: double.parse(_allowancesController.text.isEmpty
              ? '0'
              : _allowancesController.text),
          newPayFrequency: _payFrequency,
          newBankAccount: _bankAccountController.text.isEmpty
              ? null
              : _bankAccountController.text,
          newBankCode: _bankCodeController.text.isEmpty
              ? null
              : _bankCodeController.text,
          timestamp: timestamp,
        );

        employee.updateWorkPermit(
          newPermitType: _workPermitType.name,
          newPermitNumber: _workPermitNumberController.text.isEmpty
              ? null
              : _workPermitNumberController.text,
          newPermitExpiry: _workPermitExpiry,
          newIsLocal: _workPermitType == WorkPermitType.citizen ||
              _workPermitType == WorkPermitType.pr,
          timestamp: timestamp,
        );

        employee.updateCpfInfo(
          newCpfNumber: _cpfNumberController.text.isEmpty
              ? null
              : _cpfNumberController.text,
          newIsCpfMember: _isCpfMember,
          newCpfRate: _cpfContributionRate,
          timestamp: timestamp,
        );

        employee.updateEmergencyContact(
          name: _emergencyContactNameController.text.isEmpty
              ? null
              : _emergencyContactNameController.text,
          phone: _emergencyContactPhoneController.text.isEmpty
              ? null
              : _emergencyContactPhoneController.text,
          relationship: _emergencyContactRelationshipController.text.isEmpty
              ? null
              : _emergencyContactRelationshipController.text,
          timestamp: timestamp,
        );

        // Update leave balances
        employee.adjustLeaveBalance(
          annualLeaveAdjustment:
              _annualLeaveBalance - employee.annualLeaveBalance.value,
          sickLeaveAdjustment:
              _sickLeaveBalance - employee.sickLeaveBalance.value,
          maternityLeaveAdjustment:
              _maternityLeaveBalance - employee.maternitylLeaveBalance.value,
          paternityLeaveAdjustment:
              _paternityLeaveBalance - employee.paternitylLeaveBalance.value,
          compassionateLeaveAdjustment: _compassionateLeaveBalance -
              employee.compassionateLeaveBalance.value,
        );

        await _employeeService.updateEmployee(employee);
      } else {
        // Create new employee
        final employee = CRDTEmployee(
          id: UuidGenerator.generateId(),
          nodeId: nodeId,
          createdAt: timestamp,
          updatedAt: timestamp,
          version: VectorClock(nodeId),
          empId: _employeeIdController.text,
          fname: _firstNameController.text,
          lname: _lastNameController.text,
          prefName: _preferredNameController.text.isEmpty
              ? null
              : _preferredNameController.text,
          empEmail: _emailController.text,
          empPhone:
              _phoneController.text.isEmpty ? null : _phoneController.text,
          empAddress:
              _addressController.text.isEmpty ? null : _addressController.text,
          dob: _dateOfBirth,
          empNationality: _nationality,
          nricFin:
              _nricFinController.text.isEmpty ? null : _nricFinController.text,
          title: _jobTitleController.text,
          dept: _departmentController.text.isEmpty
              ? null
              : _departmentController.text,
          start: _startDate,
          end: _endDate,
          status: _employmentStatus.name,
          type: _employmentType.name,
          permitType: _workPermitType.name,
          permitNumber: _workPermitNumberController.text.isEmpty
              ? null
              : _workPermitNumberController.text,
          permitExpiry: _workPermitExpiry,
          localEmployee: _workPermitType == WorkPermitType.citizen ||
              _workPermitType == WorkPermitType.pr,
          salary: double.parse(_basicSalaryController.text),
          empAllowances: double.parse(_allowancesController.text.isEmpty
              ? '0'
              : _allowancesController.text),
          frequency: _payFrequency,
          account: _bankAccountController.text.isEmpty
              ? null
              : _bankAccountController.text,
          bank: _bankCodeController.text.isEmpty
              ? null
              : _bankCodeController.text,
          cpf: _cpfNumberController.text.isEmpty
              ? null
              : _cpfNumberController.text,
          cpfMember: _isCpfMember,
          cpfRate: _cpfContributionRate,
          annualLeave: _annualLeaveBalance,
          sickLeave: _sickLeaveBalance,
          maternityLeave: _maternityLeaveBalance,
          paternityLeave: _paternityLeaveBalance,
          compassionateLeave: _compassionateLeaveBalance,
          emergencyName: _emergencyContactNameController.text.isEmpty
              ? null
              : _emergencyContactNameController.text,
          emergencyPhone: _emergencyContactPhoneController.text.isEmpty
              ? null
              : _emergencyContactPhoneController.text,
          emergencyRelation:
              _emergencyContactRelationshipController.text.isEmpty
                  ? null
                  : _emergencyContactRelationshipController.text,
        );

        await _employeeService.createEmployee(employee);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? 'Employee updated successfully'
                : 'Employee created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving employee: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Employee'),
        content: Text(
            'Are you sure you want to delete ${widget.employee!.fullName}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteEmployee();
    }
  }

  Future<void> _deleteEmployee() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _employeeService.deleteEmployee(widget.employee!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Employee deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting employee: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  String _getEmploymentStatusDisplayName(EmploymentStatus status) {
    switch (status) {
      case EmploymentStatus.active:
        return 'Active';
      case EmploymentStatus.onLeave:
        return 'On Leave';
      case EmploymentStatus.suspended:
        return 'Suspended';
      case EmploymentStatus.terminated:
        return 'Terminated';
      case EmploymentStatus.retired:
        return 'Retired';
    }
  }

  String _getEmployeeTypeDisplayName(EmployeeType type) {
    switch (type) {
      case EmployeeType.fullTime:
        return 'Full Time';
      case EmployeeType.partTime:
        return 'Part Time';
      case EmployeeType.contract:
        return 'Contract';
      case EmployeeType.intern:
        return 'Intern';
      case EmployeeType.freelancer:
        return 'Freelancer';
    }
  }

  String _getWorkPermitTypeDisplayName(WorkPermitType type) {
    switch (type) {
      case WorkPermitType.citizen:
        return 'Singapore Citizen';
      case WorkPermitType.pr:
        return 'Permanent Resident';
      case WorkPermitType.prFirst2Years:
        return 'PR (First 2 Years)';
      case WorkPermitType.ep:
        return 'Employment Pass';
      case WorkPermitType.sp:
        return 'S Pass';
      case WorkPermitType.wp:
        return 'Work Permit';
      case WorkPermitType.twr:
        return 'Training Work Permit';
      case WorkPermitType.pep:
        return 'Personalised Employment Pass';
      case WorkPermitType.onePass:
        return 'Tech.Pass/ONE Pass';
      case WorkPermitType.studentPass:
        return 'Student Pass';
      case WorkPermitType.dependentPass:
        return 'Dependant Pass';
    }
  }
}
