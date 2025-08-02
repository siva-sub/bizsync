import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PerformanceReviewScreen extends ConsumerWidget {
  const PerformanceReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Review'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text('Performance Review', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text('Review employee performance'),
            SizedBox(height: 24),
            Text('TODO: Implement performance review functionality', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}