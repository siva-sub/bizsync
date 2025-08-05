import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'dart:io' show Platform, exit;
import 'navigation/app_router.dart';
import 'core/database/crdt_database_service.dart';
import 'core/database/database_health_service.dart';
import 'core/database/platform_database_factory.dart';
import 'core/storage/database_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'core/constants/app_constants.dart';
import 'core/platform/wayland_helper.dart';
import 'core/utils/mesa_rendering_detector.dart';
import 'core/utils/mesa_rendering_config.dart';
import 'core/theme/theme_service.dart';
import 'core/security/biometric_auth_service.dart';
import 'core/offline/offline_service.dart';
import 'core/feedback/haptic_service.dart';
import 'core/notifications/enhanced_push_notification_service.dart';
import 'core/performance/performance_optimizer.dart';
import 'core/shortcuts/quick_actions_service.dart';
import 'core/desktop/index.dart';
import 'core/config/feature_flags.dart';

void main(List<String> args) async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize feature flags first
  debugPrint('🏳️ Initializing feature flags...');
  final featureFlags = FeatureFlags();
  await featureFlags.initialize();
  debugPrint(
      '✅ Feature flags initialized - Demo data: ${featureFlags.isDemoDataEnabled}');

  // Handle CLI mode first
  if (args.isNotEmpty) {
    final cliService = CLIService();
    await cliService.initialize();

    // Check if running in headless mode
    if (cliService.isHeadlessMode(args)) {
      debugPrint('🖥️ Running in headless mode');

      // Process CLI commands without GUI
      final result = await cliService.processArguments(args);
      if (result.output != null) {
        print(result.output);
      }
      if (result.error != null) {
        print('Error: ${result.error}');
      }

      exit(result.exitCode);
    }
  }

  // Configure Wayland-specific optimizations for Linux
  if (Platform.isLinux) {
    await WaylandHelper.applyOptimizations();
    WaylandHelper.logPlatformInfo();

    // Initialize Mesa rendering configuration
    MesaRenderingConfig().initialize();

    // Print Mesa debug info in debug mode
    if (kDebugMode) {
      MesaRenderingDetector.printDebugInfo();
    }
  }

  // Initialize desktop services for Linux
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    debugPrint('🖥️ Initializing desktop services...');
    try {
      await DesktopServicesManager().initializeAll();
      debugPrint('✅ Desktop services initialized successfully');
    } catch (e) {
      debugPrint('⚠️ Error initializing desktop services: $e');
      // Continue with app startup - desktop features will have limited functionality
    }
  }

  // Initialize mobile-specific services
  debugPrint('📱 Initializing mobile services...');

  try {
    // Initialize theme service first
    final themeService = ThemeService();
    await themeService.initialize();
    debugPrint('✅ Theme service initialized');

    // Initialize biometric authentication
    final biometricService = BiometricAuthService();
    await biometricService.initialize();
    debugPrint('✅ Biometric authentication service initialized');

    // Initialize offline service
    final offlineService = OfflineService();
    await offlineService.initialize();
    debugPrint('✅ Offline service initialized');

    // Initialize haptic feedback service
    final hapticService = HapticService();
    await hapticService.initialize();
    debugPrint('✅ Haptic feedback service initialized');

    // Initialize notification service
    final notificationService = EnhancedPushNotificationService();
    await notificationService.initialize();
    debugPrint('✅ Push notification service initialized');

    // Initialize performance optimizer
    final performanceOptimizer = PerformanceOptimizer();
    await performanceOptimizer.initialize();
    debugPrint('✅ Performance optimizer initialized');

    // Initialize quick actions
    final quickActionsService = QuickActionsService();
    await quickActionsService.initialize();
    debugPrint('✅ Quick actions service initialized');

    debugPrint('📱 All mobile services initialized successfully');
  } catch (e) {
    debugPrint('⚠️ Error initializing mobile services: $e');
    // Continue with app startup - mobile features will have limited functionality
  }

  // Initialize the database services with comprehensive error handling and monitoring
  try {
    debugPrint('🚀 Initializing BizSync database services...');

    // Initialize CRDT Database Service first
    final crdtDatabaseService = CRDTDatabaseService();
    await crdtDatabaseService.initialize();

    // Initialize Basic Database Service
    final basicDatabaseService = DatabaseService();
    await basicDatabaseService.database; // Trigger initialization

    // Perform initial health check
    final healthService = DatabaseHealthService();
    final database = await crdtDatabaseService.database;
    final healthReport = await healthService.performHealthCheck(database);
    
    debugPrint('📊 Initial Database Health Report:');
    debugPrint(healthReport.getStatusSummary());
    
    if (healthReport.hasWarnings && kDebugMode) {
      debugPrint(healthReport.getFormattedReport());
    }

    // Verify both services are working
    await _verifyDatabaseIntegrity(crdtDatabaseService, basicDatabaseService);

    debugPrint('✅ All database services initialized successfully');
    
  } catch (e) {
    debugPrint('❌ Critical error initializing database services: $e');
    
    // Enhanced error analysis
    if (e.toString().contains('PRAGMA journal_mode')) {
      debugPrint('💡 Error appears to be PRAGMA-related - this is now handled automatically');
    }
    if (e.toString().contains('SQLiteDatabase query or rawQuery')) {
      debugPrint('💡 Error appears to be SQLCipher-related - encryption is disabled for compatibility');
    }

    // Attempt recovery with detailed logging
    try {
      debugPrint('🔧 Attempting comprehensive database recovery...');
      await _attemptDatabaseRecovery();
      debugPrint('✅ Database recovery successful');
      
    } catch (recoveryError) {
      debugPrint('❌ Database recovery failed: $recoveryError');
      
      // Log platform information for debugging
      try {
        final platformInfo = await PlatformDatabaseFactory.getDatabaseInfo();
        debugPrint('🔍 Platform Information:');
        platformInfo.forEach((key, value) => debugPrint('  $key: $value'));
      } catch (infoError) {
        debugPrint('⚠️ Could not retrieve platform information: $infoError');
      }
      
      // Continue with app startup but show warning
      if (kDebugMode) {
        debugPrint('⚠️  App will start with limited functionality');
        debugPrint('💡 Consider checking device compatibility and available storage');
      }
    }
  }

  // Configure system UI for professional appearance
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Set preferred orientations for desktop/tablet
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Configure error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint('Flutter Error: ${details.exceptionAsString()}');
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('Platform Error: $error');
      debugPrint('Stack: $stack');
    }
    return true;
  };

  runApp(const ProviderScope(child: BizSyncApp()));
}

/// Verify database integrity and force table creation if needed
Future<void> _verifyDatabaseIntegrity(
    CRDTDatabaseService crdtService, DatabaseService basicService) async {
  try {
    // Test basic operations
    final db = await crdtService.database;

    // Check if customers table exists and is accessible
    final customerCount =
        await db.rawQuery('SELECT COUNT(*) as count FROM customers');
    debugPrint(
        '✓ Customers table accessible, found ${customerCount.first['count']} records');

    // Check CRDT customers table
    final crdtCustomerCount =
        await db.rawQuery('SELECT COUNT(*) as count FROM customers_crdt');
    debugPrint(
        '✓ CRDT customers table accessible, found ${crdtCustomerCount.first['count']} records');
  } catch (e) {
    debugPrint('⚠️  Database integrity check failed: $e');
    throw Exception('Database tables not accessible: $e');
  }
}

/// Attempt comprehensive database recovery with health monitoring
Future<void> _attemptDatabaseRecovery() async {
  try {
    debugPrint('🔧 Starting comprehensive database recovery...');
    
    // Step 1: Use health service for automated recovery
    final healthService = DatabaseHealthService();
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final crdtPath = join(documentsDirectory.path, AppConstants.databaseName);
    
    final recoverySuccess = await healthService.attemptRecovery(crdtPath);
    if (!recoverySuccess) {
      throw Exception('Automated recovery failed');
    }
    
    // Step 2: Reinitialize services
    final crdtService = CRDTDatabaseService();
    await crdtService.initialize();
    
    final basicService = DatabaseService();
    await basicService.database; // Trigger initialization
    
    // Step 3: Perform health check
    final database = await crdtService.database;
    final healthReport = await healthService.performHealthCheck(database);
    
    debugPrint('📊 Recovery Health Report:');
    debugPrint(healthReport.getFormattedReport());
    
    if (!healthReport.isHealthy) {
      throw Exception('Post-recovery health check failed: ${healthReport.getStatusSummary()}');
    }
    
    // Step 4: Verify basic functionality
    await _verifyDatabaseIntegrity(crdtService, basicService);
    
    debugPrint('✅ Database recovery completed successfully');
    
  } catch (e) {
    debugPrint('❌ Database recovery failed: $e');
    throw Exception('Database recovery failed: $e');
  }
}

class BizSyncApp extends ConsumerWidget {
  const BizSyncApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeService = ref.watch(themeServiceProvider);

    return PerformanceMonitor(
      showOverlay: kDebugMode,
      child: MaterialApp.router(
        title: 'BizSync - Professional Business Management',
        debugShowCheckedModeBanner: false,
        theme: themeService.createLightTheme(),
        darkTheme: themeService.createDarkTheme(),
        themeMode: themeService.themeMode,
        routerConfig: AppRouter.router,
        builder: (context, child) => QuickActionHandler(
          onQuickAction: (actionType) {
            // Handle quick actions - this could navigate to appropriate screens
            debugPrint('Quick action received: $actionType');
          },
          child: DesktopWrapper(
            child: WaylandOptimizedWidget(
              child: ResponsiveBreakpoints.builder(
                child: child!,
                breakpoints: [
                  const Breakpoint(start: 0, end: 450, name: MOBILE),
                  const Breakpoint(start: 451, end: 800, name: TABLET),
                  const Breakpoint(start: 801, end: 1920, name: DESKTOP),
                  const Breakpoint(
                      start: 1921, end: double.infinity, name: '4K'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
