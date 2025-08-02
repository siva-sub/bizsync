import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EmployeeDetailsScreen extends ConsumerWidget {
  final String employeeId;
  
  const EmployeeDetailsScreen({super.key, required this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Details'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            const Text('Employee Details', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text('Employee ID: $employeeId'),
            const SizedBox(height: 24),
            const Text('TODO: Implement employee details functionality', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}