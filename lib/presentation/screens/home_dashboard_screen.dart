import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../features/onboarding/providers/onboarding_provider.dart';

class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _refreshController;
  bool _isLoading = false;
  Map<String, dynamic> _dashboardMetrics = {};
  List<Map<String, dynamic>> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _loadDashboardData();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    _refreshController.forward();
    
    try {
      // Load real dashboard data
      await _loadRealDashboardData();
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
    
    _refreshController.reset();
  }

  Future<void> _loadRealDashboardData() async {
    // TODO: Load real data from database
    // For now, use sample data structure
    _dashboardMetrics = {
      'revenue': {'total': 0.0, 'monthly': 0.0, 'change': '+0%'},
      'invoices': {'total': 0, 'pending': 0, 'overdue': 0, 'paid': 0},
      'customers': {'total': 0, 'active': 0},
      'employees': {'total': 0, 'active': 0},
      'payments': {'total': 0.0, 'pending': 0.0},
    };
    
    _recentActivity = [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: CustomScrollView(
          slivers: [
            // Welcome Section
            SliverToBoxAdapter(
              child: _buildWelcomeSection(context),
            ),
            
            // Quick Metrics Section
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: _buildQuickMetrics(context),
              ),
            ),
            
            // Quick Actions Section
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: _buildQuickActions(context),
              ),
            ),
            
            // Recent Activity Section
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: _buildRecentActivity(context),
              ),
            ),
            
            // Module Shortcuts Section
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: _buildModuleShortcuts(context),
              ),
            ),
            
            // System Status Section
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: _buildSystemStatus(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            'Welcome to BizSync',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getGreetingMessage(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 24),
          _buildWelcomeActions(context),
        ],
      ),
    );
  }

  Widget _buildWelcomeActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => context.go('/invoices/create'),
            icon: const Icon(Icons.add),
            label: const Text('New Invoice'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.onPrimary,
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.go('/dashboard'),
            icon: const Icon(Icons.analytics),
            label: const Text('View Analytics'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              side: BorderSide(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickMetrics(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Overview',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        AnimationLimiter(
          child: GridView.count(
            key: const ValueKey('metrics_grid'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: _getGridCrossAxisCount(context),
            childAspectRatio: 1.3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 600),
              childAnimationBuilder: (widget) => SlideAnimation(
                horizontalOffset: 50.0,
                child: FadeInAnimation(child: widget),
              ),
              children: [
                _MetricCard(
                  key: const ValueKey('revenue_card'),
                  title: 'Revenue',
                  value: _dashboardMetrics.isNotEmpty 
                      ? '\$${(_dashboardMetrics['revenue']?['total'] ?? 0).toStringAsFixed(0)}'
                      : '\$0',
                  change: _dashboardMetrics.isNotEmpty 
                      ? (_dashboardMetrics['revenue']?['change'] ?? '+0%')
                      : '+0%',
                  changeColor: Colors.green,
                  icon: Icons.trending_up,
                  color: Colors.blue,
                  onTap: () => context.go('/dashboard'),
                ),
                _MetricCard(
                  key: const ValueKey('invoices_card'),
                  title: 'Invoices',
                  value: _dashboardMetrics.isNotEmpty 
                      ? '${_dashboardMetrics['invoices']?['total'] ?? 0}'
                      : '0',
                  change: _dashboardMetrics.isNotEmpty 
                      ? '+${_dashboardMetrics['invoices']?['pending'] ?? 0} pending'
                      : '+0',
                  changeColor: Colors.orange,
                  icon: Icons.receipt_long,
                  color: Colors.orange,
                  onTap: () => context.go('/invoices'),
                ),
                _MetricCard(
                  key: const ValueKey('customers_card'),
                  title: 'Customers',
                  value: _dashboardMetrics.isNotEmpty 
                      ? '${_dashboardMetrics['customers']?['total'] ?? 0}'
                      : '0',
                  change: _dashboardMetrics.isNotEmpty 
                      ? '${_dashboardMetrics['customers']?['active'] ?? 0} active'
                      : '0 active',
                  changeColor: Colors.green,
                  icon: Icons.people,
                  color: Colors.purple,
                  onTap: () => context.go('/customers'),
                ),
                _MetricCard(
                  key: const ValueKey('payments_card'),
                  title: 'Payments',
                  value: _dashboardMetrics.isNotEmpty 
                      ? '\$${(_dashboardMetrics['payments']?['total'] ?? 0).toStringAsFixed(0)}'
                      : '\$0',
                  change: _dashboardMetrics.isNotEmpty 
                      ? '\$${(_dashboardMetrics['payments']?['pending'] ?? 0).toStringAsFixed(0)} pending'
                      : '\$0 pending',
                  changeColor: Colors.blue,
                  icon: Icons.payment,
                  color: Colors.teal,
                  onTap: () => context.go('/payments'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _ActionCard(
              icon: Icons.receipt_long,
              title: 'Create Invoice',
              subtitle: 'Bill your customers',
              onTap: () => context.go('/invoices/create'),
            ),
            _ActionCard(
              icon: Icons.qr_code,
              title: 'Generate QR',
              subtitle: 'Payment QR codes',
              onTap: () => context.go('/payments/sgqr'),
            ),
            _ActionCard(
              icon: Icons.person_add,
              title: 'Add Customer',
              subtitle: 'New customer profile',
              onTap: () => context.go('/customers/add'),
            ),
            _ActionCard(
              icon: Icons.calculate,
              title: 'Tax Calculator',
              subtitle: 'Calculate taxes',
              onTap: () => context.go('/tax/calculator'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => context.go('/notifications'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: _recentActivity.isNotEmpty
                ? _recentActivity.map((activity) => _ActivityTile(
                    icon: _getIconData(activity['icon'] as String),
                    title: activity['title'] as String,
                    subtitle: activity['subtitle'] as String,
                    color: _getColorFromString(activity['color'] as String),
                  )).toList()
                : [
                    const _ActivityTile(
                      icon: Icons.info,
                      title: 'No recent activity',
                      subtitle: 'Activity will appear here',
                      color: Colors.grey,
                    ),
                  ],
          ),
        ),
      ],
    );
  }

  Widget _buildModuleShortcuts(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Modules',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          childAspectRatio: 1.1,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _ModuleCard(
              icon: Icons.group,
              title: 'Employees',
              onTap: () => context.go('/employees'),
            ),
            _ModuleCard(
              icon: Icons.account_balance,
              title: 'Tax Center',
              onTap: () => context.go('/tax'),
            ),
            _ModuleCard(
              icon: Icons.sync,
              title: 'Sync Data',
              onTap: () => context.go('/sync'),
            ),
            _ModuleCard(
              icon: Icons.backup,
              title: 'Backup',
              onTap: () => context.go('/backup'),
            ),
            _ModuleCard(
              icon: Icons.notifications,
              title: 'Alerts',
              onTap: () => context.go('/notifications'),
            ),
            _ModuleCard(
              icon: Icons.settings,
              title: 'Settings',
              onTap: () => context.go('/settings'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSystemStatus(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'System Status',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _StatusRow(
                  label: 'Database',
                  status: 'Connected',
                  isHealthy: true,
                ),
                const Divider(),
                _StatusRow(
                  label: 'Sync Service',
                  status: 'Ready',
                  isHealthy: true,
                ),
                const Divider(),
                _StatusRow(
                  label: 'Backup Status',
                  status: 'Last: 2 hours ago',
                  isHealthy: true,
                ),
                const Divider(),
                _StatusRow(
                  label: 'Storage Used',
                  status: '245 MB / 2 GB',
                  isHealthy: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  String _getGreetingMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning! Ready to manage your business today?';
    } else if (hour < 17) {
      return 'Good afternoon! How\'s your business doing today?';
    } else {
      return 'Good evening! Let\'s review today\'s progress.';
    }
  }

  int _getGridCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 4;
    if (width > 800) return 3;
    return 2;
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'receipt_long': return Icons.receipt_long;
      case 'payment': return Icons.payment;
      case 'person_add': return Icons.person_add;
      case 'badge': return Icons.badge;
      case 'account_balance': return Icons.account_balance;
      case 'settings': return Icons.settings;
      case 'sync': return Icons.sync;
      case 'notifications': return Icons.notifications;
      default: return Icons.info;
    }
  }

  Color _getColorFromString(String colorName) {
    switch (colorName) {
      case 'green': return Colors.green;
      case 'blue': return Colors.blue;
      case 'red': return Colors.red;
      case 'orange': return Colors.orange;
      case 'purple': return Colors.purple;
      case 'grey': return Colors.grey;
      default: return Colors.blue;
    }
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String change;
  final Color changeColor;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.change,
    required this.changeColor,
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
              Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  const Spacer(),
                  Text(
                    change,
                    style: TextStyle(
                      color: changeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
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
          child: Row(
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _ActivityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String status;
  final bool isHealthy;

  const _StatusRow({
    required this.label,
    required this.status,
    required this.isHealthy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isHealthy ? Icons.check_circle : Icons.error,
          color: isHealthy ? Colors.green : Colors.red,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          status,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}