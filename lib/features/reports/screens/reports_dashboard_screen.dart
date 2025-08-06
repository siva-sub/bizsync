import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/report_models.dart';
import '../services/report_service.dart';

class ReportsDashboardScreen extends ConsumerStatefulWidget {
  const ReportsDashboardScreen({super.key});

  @override
  ConsumerState<ReportsDashboardScreen> createState() =>
      _ReportsDashboardScreenState();
}

class _ReportsDashboardScreenState
    extends ConsumerState<ReportsDashboardScreen> {
  List<ReportData>? _recentReports;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentReports();
  }

  Future<void> _loadRecentReports() async {
    setState(() => _isLoading = true);

    try {
      final reportService = ref.read(reportServiceProvider);
      _recentReports = await reportService.getRecentReports();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reports: $e')),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  'Reports & Analytics',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _showGenerateReportDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Generate Report'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Quick Stats Cards
            _buildQuickStatsSection(),

            const SizedBox(height: 24),

            // Report Type Cards
            _buildReportTypesSection(),

            const SizedBox(height: 24),

            // Recent Reports
            _buildRecentReportsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Overview',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Total Revenue',
                value: '\$45,230',
                subtitle: 'This month',
                icon: Icons.trending_up,
                color: Colors.green,
                trend: '+12.5%',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                title: 'Net Profit',
                value: '\$12,870',
                subtitle: 'This month',
                icon: Icons.account_balance_wallet,
                color: Colors.blue,
                trend: '+8.3%',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                title: 'GST Payable',
                value: '\$3,420',
                subtitle: 'This quarter',
                icon: Icons.receipt,
                color: Colors.orange,
                trend: '+15.2%',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReportTypesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Generate Reports',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: [
            _ReportTypeCard(
              title: 'Sales Report',
              subtitle: 'Revenue, transactions, top customers',
              icon: Icons.show_chart,
              color: Colors.blue,
              onTap: () => context.go('/reports/sales'),
            ),
            _ReportTypeCard(
              title: 'Tax Report',
              subtitle: 'GST, corporate tax, compliance',
              icon: Icons.receipt_long,
              color: Colors.green,
              onTap: () => context.go('/reports/tax'),
            ),
            _ReportTypeCard(
              title: 'Financial Report',
              subtitle: 'P&L, balance sheet, cash flow',
              icon: Icons.account_balance,
              color: Colors.purple,
              onTap: () => context.go('/reports/financial'),
            ),
            _ReportTypeCard(
              title: 'Customer Report',
              subtitle: 'Customer insights and analytics',
              icon: Icons.people,
              color: Colors.teal,
              onTap: () => _showComingSoonDialog('Customer Report'),
            ),
            _ReportTypeCard(
              title: 'Inventory Report',
              subtitle: 'Stock levels, product performance',
              icon: Icons.inventory,
              color: Colors.orange,
              onTap: () => _showComingSoonDialog('Inventory Report'),
            ),
            _ReportTypeCard(
              title: 'Profit Analysis',
              subtitle: 'Margins, profitability trends',
              icon: Icons.analytics,
              color: Colors.red,
              onTap: () => _showComingSoonDialog('Profit Analysis'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentReportsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Recent Reports',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => _showComingSoonDialog('Report History'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_recentReports?.isEmpty ?? true)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.assessment,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No reports generated yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Generate your first report to see insights',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            child: Column(
              children: _recentReports!
                  .map((report) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              _getReportTypeColor(report.type).withValues(alpha: 0.1),
                          child: Icon(
                            _getReportTypeIcon(report.type),
                            color: _getReportTypeColor(report.type),
                          ),
                        ),
                        title: Text(report.title),
                        subtitle: Text(
                          'Generated ${_formatRelativeDate(report.generatedAt)} • ${_getReportPeriodText(report.period)}',
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'view',
                              child: Row(
                                children: [
                                  Icon(Icons.visibility),
                                  SizedBox(width: 8),
                                  Text('View Report'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'download',
                              child: Row(
                                children: [
                                  Icon(Icons.download),
                                  SizedBox(width: 8),
                                  Text('Download PDF'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'share',
                              child: Row(
                                children: [
                                  Icon(Icons.share),
                                  SizedBox(width: 8),
                                  Text('Share'),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) =>
                              _handleReportAction(value, report),
                        ),
                        onTap: () => _viewReport(report),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }

  void _showGenerateReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate New Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.show_chart, color: Colors.blue),
              title: const Text('Sales Report'),
              onTap: () {
                Navigator.pop(context);
                context.go('/reports/sales');
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long, color: Colors.green),
              title: const Text('Tax Report'),
              onTap: () {
                Navigator.pop(context);
                context.go('/reports/tax');
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance, color: Colors.purple),
              title: const Text('Financial Report'),
              onTap: () {
                Navigator.pop(context);
                context.go('/reports/financial');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feature),
        content: Text('$feature functionality is coming soon!'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Color _getReportTypeColor(ReportType type) {
    switch (type) {
      case ReportType.sales:
        return Colors.blue;
      case ReportType.tax:
        return Colors.green;
      case ReportType.financial:
        return Colors.purple;
      case ReportType.customer:
        return Colors.teal;
      case ReportType.inventory:
        return Colors.orange;
      case ReportType.profit:
        return Colors.red;
    }
  }

  IconData _getReportTypeIcon(ReportType type) {
    switch (type) {
      case ReportType.sales:
        return Icons.show_chart;
      case ReportType.tax:
        return Icons.receipt_long;
      case ReportType.financial:
        return Icons.account_balance;
      case ReportType.customer:
        return Icons.people;
      case ReportType.inventory:
        return Icons.inventory;
      case ReportType.profit:
        return Icons.analytics;
    }
  }

  String _getReportPeriodText(ReportPeriod period) {
    switch (period) {
      case ReportPeriod.today:
        return 'Today';
      case ReportPeriod.thisWeek:
        return 'This Week';
      case ReportPeriod.thisMonth:
        return 'This Month';
      case ReportPeriod.thisQuarter:
        return 'This Quarter';
      case ReportPeriod.thisYear:
        return 'This Year';
      case ReportPeriod.custom:
        return 'Custom Period';
    }
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _handleReportAction(String action, ReportData report) {
    switch (action) {
      case 'view':
        _viewReport(report);
        break;
      case 'download':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF download coming soon!')),
        );
        break;
      case 'share':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Share functionality coming soon!')),
        );
        break;
    }
  }

  void _viewReport(ReportData report) {
    switch (report.type) {
      case ReportType.sales:
        context.go('/reports/sales');
        break;
      case ReportType.tax:
        context.go('/reports/tax');
        break;
      case ReportType.financial:
        context.go('/reports/financial');
        break;
      default:
        _showComingSoonDialog('${report.title} View');
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String trend;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    trend,
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ReportTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
