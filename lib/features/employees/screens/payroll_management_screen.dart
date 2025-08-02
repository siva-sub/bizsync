import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PayrollManagementScreen extends ConsumerWidget {
  const PayrollManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payroll Management'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text('Payroll Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text('Manage employee payroll'),
            SizedBox(height: 24),
            Text('TODO: Implement payroll management functionality', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}