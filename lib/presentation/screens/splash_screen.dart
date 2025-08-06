import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/crdt_database_service.dart';
import '../../core/database/platform_database_factory.dart';
import '../../core/services/notification_service.dart';
import '../../features/sync/services/p2p_sync_service.dart';
import '../../features/backup/services/backup_service.dart';
import '../../features/onboarding/providers/onboarding_provider.dart';
import '../../core/utils/mesa_rendering_detector.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _progressController;
  late Animation<double> _logoAnimation;
  late Animation<double> _progressAnimation;

  String _statusText = 'Initializing BizSync...';
  double _progress = 0.0;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeApp();
  }

  void _setupAnimations() {
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _logoAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _logoController.forward();
    _progressController.forward();
  }

  Future<void> _initializeApp() async {
    try {
      // Step 1: Initialize Onboarding Service
      _updateStatus('Initializing app...', 0.1);
      await _initializeOnboarding();

      // Step 2: Initialize Database
      _updateStatus('Setting up database...', 0.3);
      await _initializeDatabase();

      // Step 3: Initialize Core Services
      _updateStatus('Loading services...', 0.6);
      await _initializeCoreServices();

      // Step 4: Complete initialization
      _updateStatus('Ready to go!', 1.0);

      // Wait a moment to show completion
      await Future.delayed(const Duration(milliseconds: 500));

      // Navigate based on onboarding status
      if (mounted) {
        await _navigateToAppropriateScreen();
      }
    } catch (e) {
      _handleInitializationError(e);
    }
  }

  Future<void> _initializeOnboarding() async {
    try {
      final onboardingNotifier = ref.read(onboardingStateProvider.notifier);
      await onboardingNotifier.initialize();
      await Future.delayed(const Duration(milliseconds: 200));
    } catch (e) {
      debugPrint('Onboarding service initialization failed: $e');
      // Continue with default state
    }
  }

  Future<void> _initializeDatabase() async {
    try {
      // Check database platform compatibility first
      final dbInfo = await PlatformDatabaseFactory.getDatabaseInfo();
      debugPrint('Database Info: $dbInfo');

      // Update status to show database type
      final dbType =
          dbInfo['encryption_available'] ? 'encrypted' : 'unencrypted';
      _updateStatus('Setting up $dbType database...', 0.25);

      final databaseService = CRDTDatabaseService();
      await databaseService.initialize();

      _updateStatus('Database ready', 0.3);
      await Future.delayed(const Duration(milliseconds: 200));
    } catch (e) {
      // Enhanced error message with platform information
      final dbInfo = await PlatformDatabaseFactory.getDatabaseInfo();
      throw Exception('Database initialization failed: $e\n\n'
          'Platform: ${dbInfo['platform']}\n'
          'Database type: ${dbInfo['database_type']}\n'
          'Encryption available: ${dbInfo['encryption_available']}\n'
          '${dbInfo['fallback_reason'] != null ? 'Reason: ${dbInfo['fallback_reason']}' : ''}');
    }
  }

  Future<void> _initializeCoreServices() async {
    try {
      // Initialize services in parallel for better performance
      await Future.wait([
        _initializeNotifications(),
        _initializeSyncServices(),
        _initializeBackupServices(),
      ]);
    } catch (e) {
      debugPrint('Some services failed to initialize: $e');
      // Continue with app startup
    }
  }

  Future<void> _initializeNotifications() async {
    try {
      final notificationService = NotificationService();
      await notificationService.initialize();
    } catch (e) {
      debugPrint('Notification setup failed: $e');
    }
  }

  Future<void> _initializeSyncServices() async {
    try {
      final syncService = P2PSyncService();
      await syncService.initialize();
    } catch (e) {
      debugPrint('Sync service setup failed: $e');
    }
  }

  Future<void> _initializeBackupServices() async {
    try {
      final backupService = BackupService();
      await backupService.initialize();
      await backupService.scheduleAutomaticBackups();
    } catch (e) {
      debugPrint('Backup service setup failed: $e');
    }
  }

  Future<void> _navigateToAppropriateScreen() async {
    final isOnboardingCompleted = ref.read(isOnboardingCompletedProvider);

    if (isOnboardingCompleted) {
      context.go('/');
    } else {
      context.go('/onboarding/welcome');
    }
  }

  void _updateStatus(String status, double progress) {
    if (mounted) {
      setState(() {
        _statusText = status;
        _progress = progress;
      });
    }
  }

  void _handleInitializationError(dynamic error) {
    if (mounted) {
      setState(() {
        _hasError = true;
        _errorMessage = error.toString();
        _statusText = 'Initialization failed';
      });
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // App Logo and Title
              AnimatedBuilder(
                animation: _logoAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _logoAnimation.value,
                    child: Column(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow:
                                MesaRenderingDetector.shouldDisableShadows
                                    ? []
                                    : [
                                        BoxShadow(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.3),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                          ),
                          child: Icon(
                            Icons.business_center,
                            size: 60,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'BizSync',
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Offline-First Business Management',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onBackground
                                        .withOpacity(0.7),
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),

              const Spacer(flex: 1),

              // Progress Section
              if (_hasError) ...[
                // Error State
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Initialization Failed',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _hasError = false;
                            _progress = 0.0;
                          });
                          _initializeApp();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Normal Loading State
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return Column(
                      children: [
                        // Progress Bar
                        Container(
                          width: double.infinity,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: _progress,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.primary,
                                    Theme.of(context).colorScheme.secondary,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Status Text
                        Text(
                          _statusText,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onBackground
                                        .withOpacity(0.8),
                                  ),
                        ),
                        const SizedBox(height: 8),

                        // Progress Percentage
                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    );
                  },
                ),
              ],

              const Spacer(flex: 2),

              // Footer
              Text(
                'Version 1.0.0',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onBackground
                          .withOpacity(0.5),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
