import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LeaveApplicationScreen extends ConsumerWidget {
  const LeaveApplicationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Application'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.orange),
            SizedBox(height: 16),
            Text('Leave Application',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text('Apply for leave'),
            SizedBox(height: 24),
            Text('TODO: Implement leave application functionality',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
