import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';

class EmployeeReportsScreen extends ConsumerStatefulWidget {
  const EmployeeReportsScreen({super.key});

  @override
  ConsumerState<EmployeeReportsScreen> createState() =>
      _EmployeeReportsScreenState();
}

class _EmployeeReportsScreenState extends ConsumerState<EmployeeReportsScreen> {
  String _selectedReportType = 'attendance';
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    // Default to current month
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Reports'),
        backgroundColor: theme.colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            onSelected: _exportReport,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'pdf',
                child: ListTile(
                  leading: Icon(Icons.picture_as_pdf),
                  title: Text('Export as PDF'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'excel',
                child: ListTile(
                  leading: Icon(Icons.table_chart),
                  title: Text('Export as Excel'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Report Type Selector
          Container(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report Type',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildReportTypeChip(
                            'attendance', 'Attendance', Icons.schedule),
                        _buildReportTypeChip(
                            'payroll', 'Payroll', Icons.payments),
                        _buildReportTypeChip(
                            'leave', 'Leave Management', Icons.calendar_today),
                        _buildReportTypeChip(
                            'performance', 'Performance', Icons.trending_up),
                        _buildReportTypeChip(
                            'overtime', 'Overtime', Icons.access_time),
                      ],
                    ),
                    if (_selectedDateRange != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.date_range,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            'Period: ${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Report Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildReportContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTypeChip(String value, String label, IconData icon) {
    final isSelected = _selectedReportType == value;

    return FilterChip(
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedReportType = value;
        });
      },
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
      checkmarkColor: Theme.of(context).colorScheme.primary,
    );
  }

  Widget _buildReportContent() {
    switch (_selectedReportType) {
      case 'attendance':
        return _buildAttendanceReport();
      case 'payroll':
        return _buildPayrollReport();
      case 'leave':
        return _buildLeaveReport();
      case 'performance':
        return _buildPerformanceReport();
      case 'overtime':
        return _buildOvertimeReport();
      default:
        return _buildAttendanceReport();
    }
  }

  Widget _buildAttendanceReport() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                  child: _buildSummaryCard('Total Present Days', '22',
                      Icons.check_circle, Colors.green)),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildSummaryCard(
                      'Absent Days', '3', Icons.cancel, Colors.red)),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildSummaryCard(
                      'Late Arrivals', '5', Icons.schedule, Colors.orange)),
            ],
          ),
          const SizedBox(height: 24),

          // Attendance Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Attendance Overview',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _buildMockAttendanceChart(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Employee List
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Employee Attendance Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _buildMockEmployeeAttendanceList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollReport() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                  child: _buildSummaryCard('Total Payroll', '\$45,600',
                      Icons.payments, Colors.blue)),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildSummaryCard('Total CPF', '\$8,208',
                      Icons.account_balance, Colors.green)),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildSummaryCard('Net Pay', '\$37,392',
                      Icons.account_balance_wallet, Colors.purple)),
            ],
          ),
          const SizedBox(height: 24),

          // Payroll Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payroll Breakdown',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _buildMockPayrollChart(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Payroll Details
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Employee Payroll Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _buildMockPayrollList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveReport() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Leave Management Report',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Coming soon - detailed leave analytics and reports',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceReport() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.trending_up, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Performance Report',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Coming soon - employee performance analytics',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildOvertimeReport() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.access_time, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Overtime Report',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Coming soon - overtime tracking and analysis',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMockAttendanceChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 15,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
                if (value.toInt() < days.length) {
                  return Text(days[value.toInt()]);
                }
                return const Text('');
              },
            ),
          ),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          BarChartGroupData(
              x: 0, barRods: [BarChartRodData(toY: 12, color: Colors.green)]),
          BarChartGroupData(
              x: 1, barRods: [BarChartRodData(toY: 11, color: Colors.green)]),
          BarChartGroupData(
              x: 2, barRods: [BarChartRodData(toY: 13, color: Colors.green)]),
          BarChartGroupData(
              x: 3, barRods: [BarChartRodData(toY: 10, color: Colors.orange)]),
          BarChartGroupData(
              x: 4, barRods: [BarChartRodData(toY: 14, color: Colors.green)]),
        ],
      ),
    );
  }

  Widget _buildMockPayrollChart() {
    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            color: Colors.blue,
            value: 37392,
            title: 'Net Pay\n\$37,392',
            radius: 80,
            titleStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          PieChartSectionData(
            color: Colors.green,
            value: 8208,
            title: 'CPF\n\$8,208',
            radius: 80,
            titleStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
        centerSpaceRadius: 0,
      ),
    );
  }

  Widget _buildMockEmployeeAttendanceList() {
    final employees = [
      {'name': 'Alice Johnson', 'present': 20, 'absent': 2, 'late': 1},
      {'name': 'Bob Smith', 'present': 22, 'absent': 0, 'late': 3},
      {'name': 'Carol Lee', 'present': 21, 'absent': 1, 'late': 0},
      {'name': 'David Brown', 'present': 19, 'absent': 3, 'late': 2},
    ];

    return Column(
      children: employees
          .map((emp) => ListTile(
                title: Text(emp['name'] as String),
                subtitle: Text(
                    'Present: ${emp['present']}, Absent: ${emp['absent']}, Late: ${emp['late']}'),
                trailing: CircleAvatar(
                  backgroundColor: (emp['absent'] as int) <= 1
                      ? Colors.green
                      : Colors.orange,
                  child: Text('${emp['present']}'),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildMockPayrollList() {
    final payroll = [
      {'name': 'Alice Johnson', 'gross': 4500, 'cpf': 810, 'net': 3690},
      {'name': 'Bob Smith', 'gross': 5200, 'cpf': 936, 'net': 4264},
      {'name': 'Carol Lee', 'gross': 3800, 'cpf': 684, 'net': 3116},
      {'name': 'David Brown', 'gross': 4100, 'cpf': 738, 'net': 3362},
    ];

    return Column(
      children: payroll
          .map((emp) => ListTile(
                title: Text(emp['name'] as String),
                subtitle:
                    Text('Gross: \$${emp['gross']}, CPF: \$${emp['cpf']}'),
                trailing: Text(
                  '\$${emp['net']}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ))
          .toList(),
    );
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  void _exportReport(String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Exporting ${_selectedReportType} report as ${format.toUpperCase()}...'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
