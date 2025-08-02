import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MinimalBizSyncApp()));
}

class MinimalBizSyncApp extends ConsumerWidget {
  const MinimalBizSyncApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'BizSync (Minimal)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.light,
        ),
      ),
      routerConfig: MinimalAppRouter.router,
    );
  }
}

class MinimalAppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const MinimalSplashScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const MinimalHomeScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const MinimalDashboardScreen(),
      ),
      GoRoute(
        path: '/invoices',
        builder: (context, state) => const MinimalInvoicesScreen(),
      ),
      GoRoute(
        path: '/payments',
        builder: (context, state) => const MinimalPaymentsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const MinimalSettingsScreen(),
      ),
    ],
  );
}

class MinimalSplashScreen extends StatefulWidget {
  const MinimalSplashScreen({super.key});

  @override
  State<MinimalSplashScreen> createState() => _MinimalSplashScreenState();
}

class _MinimalSplashScreenState extends State<MinimalSplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate to home after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        context.go('/');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business_center,
              size: 120,
              color: Colors.white,
            ),
            SizedBox(height: 24),
            Text(
              'BizSync',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Offline-First Business Management',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: 48),
            CircularProgressIndicator(
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class MinimalHomeScreen extends StatelessWidget {
  const MinimalHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BizSync Home'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _FeatureCard(
              icon: Icons.dashboard,
              title: 'Dashboard',
              subtitle: 'Business insights',
              onTap: () => context.go('/dashboard'),
            ),
            _FeatureCard(
              icon: Icons.receipt_long,
              title: 'Invoices',
              subtitle: 'Manage invoices',
              onTap: () => context.go('/invoices'),
            ),
            _FeatureCard(
              icon: Icons.qr_code,
              title: 'Payments',
              subtitle: 'SGQR & PayNow',
              onTap: () => context.go('/payments'),
            ),
            _FeatureCard(
              icon: Icons.settings,
              title: 'Settings',
              subtitle: 'App preferences',
              onTap: () => context.go('/settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FeatureCard({
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
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
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MinimalDashboardScreen extends StatelessWidget {
  const MinimalDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard, size: 64, color: Colors.blue),
            SizedBox(height: 16),
            Text(
              'Dashboard',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text('Business insights and analytics coming soon...'),
          ],
        ),
      ),
    );
  }
}

class MinimalInvoicesScreen extends StatelessWidget {
  const MinimalInvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'Invoices',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text('Invoice management coming soon...'),
          ],
        ),
      ),
    );
  }
}

class MinimalPaymentsScreen extends StatelessWidget {
  const MinimalPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code, size: 64, color: Colors.purple),
            SizedBox(height: 16),
            Text(
              'Payments',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text('SGQR payment system coming soon...'),
          ],
        ),
      ),
    );
  }
}

class MinimalSettingsScreen extends StatelessWidget {
  const MinimalSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.settings, size: 64, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'Settings',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text('App settings coming soon...'),
          ],
        ),
      ),
    );
  }
}