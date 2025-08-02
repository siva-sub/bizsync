import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.access_time, size: 64, color: Colors.purple),
            SizedBox(height: 16),
            Text('Attendance', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text('Track employee attendance'),
            SizedBox(height: 24),
            Text('TODO: Implement attendance tracking functionality', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}