import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BottomNavigationWidget extends StatelessWidget {
  const BottomNavigationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final currentLocation = GoRouterState.of(context).uri.path;
    
    return NavigationBar(
      selectedIndex: _getSelectedIndex(currentLocation),
      onDestinationSelected: (index) => _onDestinationSelected(context, index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: 'Invoices',
        ),
        NavigationDestination(
          icon: Icon(Icons.qr_code_outlined),
          selectedIcon: Icon(Icons.qr_code),
          label: 'Payments',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: 'Customers',
        ),
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Analytics',
        ),
      ],
    );
  }

  int _getSelectedIndex(String location) {
    if (location == '/') return 0;
    if (location.startsWith('/invoices')) return 1;
    if (location.startsWith('/payments')) return 2;
    if (location.startsWith('/customers')) return 3;
    if (location.startsWith('/dashboard')) return 4;
    return 0; // Default to home
  }

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/invoices');
        break;
      case 2:
        context.go('/payments');
        break;
      case 3:
        context.go('/customers');
        break;
      case 4:
        context.go('/dashboard');
        break;
    }
  }
}