import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../providers/app_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(currentTabProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // TODO: Navigate to notifications
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Navigate to settings
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: currentTab,
        children: const [
          _DashboardHomeTab(),
          _CustomersTab(),
          _InventoryTab(),
          _SalesTab(),
          _ReportsTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentTab,
        onTap: (index) {
          ref.read(currentTabProvider.notifier).state = index;
        },
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Customers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale),
            label: 'Sales',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Reports',
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(context, currentTab),
    );
  }
  
  Widget? _buildFloatingActionButton(BuildContext context, int currentTab) {
    switch (currentTab) {
      case 1: // Customers
        return FloatingActionButton(
          onPressed: () {
            // TODO: Navigate to add customer
          },
          child: const Icon(Icons.person_add),
        );
      case 2: // Inventory
        return FloatingActionButton(
          onPressed: () {
            // TODO: Navigate to add product
          },
          child: const Icon(Icons.add_box),
        );
      case 3: // Sales
        return FloatingActionButton(
          onPressed: () {
            // TODO: Navigate to new sale
          },
          child: const Icon(Icons.add_shopping_cart),
        );
      default:
        return null;
    }
  }
}

class _DashboardHomeTab extends StatelessWidget {
  const _DashboardHomeTab();
  
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: AppConstants.largePadding),
          
          // Quick stats cards
          Row(
            children: [
              Expanded(
                child: _StatsCard(
                  title: 'Today\'s Sales',
                  value: '\$0.00',
                  icon: Icons.attach_money,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: AppConstants.defaultPadding),
              Expanded(
                child: _StatsCard(
                  title: 'Total Customers',
                  value: '0',
                  icon: Icons.people,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppConstants.defaultPadding),
          
          Row(
            children: [
              Expanded(
                child: _StatsCard(
                  title: 'Products',
                  value: '0',
                  icon: Icons.inventory,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: AppConstants.defaultPadding),
              Expanded(
                child: _StatsCard(
                  title: 'Low Stock',
                  value: '0',
                  icon: Icons.warning,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppConstants.largePadding),
          
          // Quick actions
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: AppConstants.defaultPadding),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: AppConstants.defaultPadding,
            mainAxisSpacing: AppConstants.defaultPadding,
            childAspectRatio: 1.5,
            children: [
              _QuickActionCard(
                title: 'New Sale',
                icon: Icons.point_of_sale,
                color: Colors.green,
                onTap: () {
                  // TODO: Navigate to new sale
                },
              ),
              _QuickActionCard(
                title: 'Add Product',
                icon: Icons.add_box,
                color: Colors.blue,
                onTap: () {
                  // TODO: Navigate to add product
                },
              ),
              _QuickActionCard(
                title: 'Add Customer',
                icon: Icons.person_add,
                color: Colors.purple,
                onTap: () {
                  // TODO: Navigate to add customer
                },
              ),
              _QuickActionCard(
                title: 'View Reports',
                icon: Icons.analytics,
                color: Colors.orange,
                onTap: () {
                  // TODO: Navigate to reports
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  
  const _StatsCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const Spacer(),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.smallPadding),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  
  const _QuickActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: color,
              ),
              const SizedBox(height: AppConstants.smallPadding),
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

class _CustomersTab extends StatelessWidget {
  const _CustomersTab();
  
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Customers - Coming Soon'),
    );
  }
}

class _InventoryTab extends StatelessWidget {
  const _InventoryTab();
  
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Inventory - Coming Soon'),
    );
  }
}

class _SalesTab extends StatelessWidget {
  const _SalesTab();
  
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Sales - Coming Soon'),
    );
  }
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab();
  
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Reports - Coming Soon'),
    );
  }
}