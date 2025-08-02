import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/rates/tax_rate_model.dart';
import '../models/company/company_tax_profile.dart';
import '../widgets/tax_overview_card.dart';
import '../widgets/tax_rate_chart.dart';
import '../widgets/recent_calculations_list.dart';

class TaxDashboardScreen extends ConsumerStatefulWidget {
  const TaxDashboardScreen({super.key});

  @override
  ConsumerState<TaxDashboardScreen> createState() => _TaxDashboardScreenState();
}

class _TaxDashboardScreenState extends ConsumerState<TaxDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax Management Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.calculate), text: 'Calculators'),
            Tab(icon: Icon(Icons.settings), text: 'Configuration'),
            Tab(icon: Icon(Icons.assessment), text: 'Compliance'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Refresh tax data
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              context.go('/notifications');
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildCalculatorsTab(),
          _buildConfigurationTab(),
          _buildComplianceTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuickActionsMenu(context),
        label: const Text('Quick Actions'),
        icon: const Icon(Icons.flash_on),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: TaxOverviewCard(
                  title: 'Current GST Rate',
                  value: '9%',
                  subtitle: 'Effective since Jan 2023',
                  icon: Icons.percent,
                  color: Colors.blue,
                  onTap: () => context.go('/tax/calculator'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TaxOverviewCard(
                  title: 'Corporate Tax',
                  value: '17%',
                  subtitle: 'Standard rate',
                  icon: Icons.business,
                  color: Colors.green,
                  onTap: () => context.go('/tax/calculator'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: TaxOverviewCard(
                  title: 'Tax Savings',
                  value: 'S\$15,240',
                  subtitle: 'This year',
                  icon: Icons.savings,
                  color: Colors.orange,
                  onTap: () => context.go('/reports/tax'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TaxOverviewCard(
                  title: 'Compliance Score',
                  value: '95%',
                  subtitle: 'Excellent',
                  icon: Icons.verified,
                  color: Colors.purple,
                  onTap: () => context.go('/reports/tax'),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Tax Rate History Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'GST Rate History',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      TextButton(
                        onPressed: () => context.go('/reports/tax'),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const TaxRateChart(),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Recent Calculations
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Calculations',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      TextButton(
                        onPressed: () => context.go('/tax/calculator'),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const RecentCalculationsList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculatorsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _buildCalculatorCard(
            'GST Calculator',
            'Calculate GST for transactions',
            Icons.receipt_long,
            Colors.blue,
            () => context.go('/tax/calculator'),
          ),
          _buildCalculatorCard(
            'Corporate Tax',
            'Calculate corporate income tax',
            Icons.business_center,
            Colors.green,
            () => context.go('/tax/calculator'),
          ),
          _buildCalculatorCard(
            'Withholding Tax',
            'Calculate withholding tax rates',
            Icons.account_balance,
            Colors.orange,
            () => context.go('/tax/calculator'),
          ),
          _buildCalculatorCard(
            'Import Duty',
            'Calculate import duties and GST',
            Icons.local_shipping,
            Colors.purple,
            () => context.go('/tax/calculator'),
          ),
          _buildCalculatorCard(
            'Stamp Duty',
            'Calculate stamp duty on documents',
            Icons.description,
            Colors.teal,
            () => context.go('/tax/calculator'),
          ),
          _buildCalculatorCard(
            'FX Impact',
            'Calculate foreign exchange impact',
            Icons.currency_exchange,
            Colors.indigo,
            () => context.go('/tax/calculator'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.business),
            title: const Text('Company Tax Profile'),
            subtitle: const Text('Configure company tax settings and classifications'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => context.go('/settings'),
          ),
        ),
        
        Card(
          child: ListTile(
            leading: const Icon(Icons.percent),
            title: const Text('Tax Rates Management'),
            subtitle: const Text('View and manage historical tax rates'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => context.go('/tax/calculator'),
          ),
        ),
        
        Card(
          child: ListTile(
            leading: const Icon(Icons.savings),
            title: const Text('Tax Reliefs & Exemptions'),
            subtitle: const Text('Configure available tax reliefs and exemptions'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => context.go('/settings'),
          ),
        ),
        
        Card(
          child: ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: const Text('FX Rates Configuration'),
            subtitle: const Text('Manage foreign exchange rates and sources'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => context.go('/settings'),
          ),
        ),
        
        Card(
          child: ListTile(
            leading: const Icon(Icons.public),
            title: const Text('International Tax Treaties'),
            subtitle: const Text('Configure tax treaties and withholding rates'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => context.go('/settings'),
          ),
        ),
        
        Card(
          child: ListTile(
            leading: const Icon(Icons.local_shipping),
            title: const Text('Trade Duty Configuration'),
            subtitle: const Text('Configure import/export duty rates and classifications'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => context.go('/settings'),
          ),
        ),
        
        Card(
          child: ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Data Import/Export'),
            subtitle: const Text('Import tax data from IRAS or export for compliance'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => context.go('/backup'),
          ),
        ),
      ],
    );
  }

  Widget _buildComplianceTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Compliance Status Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified, color: Colors.green),
                    const SizedBox(width: 8),
                    Text('Compliance Status', style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: 0.95,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation(Colors.green),
                ),
                const SizedBox(height: 8),
                Text('95% - Excellent compliance score'),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Filing Requirements
        Card(
          child: ExpansionTile(
            leading: const Icon(Icons.assignment),
            title: const Text('Filing Requirements'),
            subtitle: const Text('Upcoming tax filing deadlines'),
            children: [
              ListTile(
                title: const Text('GST F5 Return'),
                subtitle: const Text('Due: 30 Jan 2025'),
                trailing: Chip(label: Text('Due Soon'), backgroundColor: Colors.orange[100]),
              ),
              ListTile(
                title: const Text('Corporate Tax Return (Form C-S)'),
                subtitle: const Text('Due: 30 Nov 2024'),
                trailing: Chip(label: Text('Completed'), backgroundColor: Colors.green[100]),
              ),
              ListTile(
                title: const Text('Estimated Chargeable Income'),
                subtitle: const Text('Due: 30 Nov 2024'),
                trailing: Chip(label: Text('Pending'), backgroundColor: Colors.yellow[100]),
              ),
            ],
          ),
        ),
        
        // Audit Trail
        Card(
          child: ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Audit Trail'),
            subtitle: const Text('View tax calculation audit logs'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => context.go('/reports'),
          ),
        ),
        
        // IRAS Integration
        Card(
          child: ListTile(
            leading: const Icon(Icons.cloud_sync),
            title: const Text('IRAS Integration'),
            subtitle: const Text('Sync with IRAS systems and download forms'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => context.go('/sync'),
          ),
        ),
        
        // Compliance Reports
        Card(
          child: ListTile(
            leading: const Icon(Icons.assessment),
            title: const Text('Compliance Reports'),
            subtitle: const Text('Generate tax compliance and analysis reports'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => context.go('/reports/tax'),
          ),
        ),
        
        // Document Management
        Card(
          child: ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Document Management'),
            subtitle: const Text('Manage tax-related documents and certificates'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => context.go('/backup'),
          ),
        ),
      ],
    );
  }

  Widget _buildCalculatorCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickActionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.calculate),
              title: const Text('Quick GST Calculation'),
              onTap: () {
                Navigator.pop(context);
                _showQuickGstCalculator(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.currency_exchange),
              title: const Text('Currency Converter'),
              onTap: () {
                Navigator.pop(context);
                context.go('/tax/calculator');
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('View Tax Rate for Date'),
              onTap: () {
                Navigator.pop(context);
                _showDateRateQuery(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.backup),
              title: const Text('Export Tax Data'),
              onTap: () {
                Navigator.pop(context);
                context.go('/backup');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickGstCalculator(BuildContext context) {
    final amountController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quick GST Calculator'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount (S\$)',
                prefixText: 'S\$ ',
              ),
            ),
            const SizedBox(height: 16),
            Text('Current GST Rate: 9%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text) ?? 0;
              final gst = amount * 0.09;
              final total = amount + gst;
              
              Navigator.pop(context);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Amount: S\$${amount.toStringAsFixed(2)}\n'
                              'GST (9%): S\$${gst.toStringAsFixed(2)}\n'
                              'Total: S\$${total.toStringAsFixed(2)}'),
                  duration: const Duration(seconds: 5),
                ),
              );
            },
            child: const Text('Calculate'),
          ),
        ],
      ),
    );
  }

  void _showDateRateQuery(BuildContext context) {
    DateTime selectedDate = DateTime.now();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Tax Rate for Date'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Selected Date: ${selectedDate.toString().split(' ')[0]}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(1990),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => selectedDate = date);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/tax/calculator');
              },
              child: const Text('View Rates'),
            ),
          ],
        ),
      ),
    );
  }
}