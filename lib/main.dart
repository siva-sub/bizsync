import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'dart:io' show Platform;
import 'navigation/app_router.dart';
import 'core/database/crdt_database_service.dart';
import 'core/storage/database_service.dart';
import 'core/platform/wayland_helper.dart';
import 'core/utils/mesa_rendering_detector.dart';
import 'core/utils/mesa_rendering_config.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
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
  
  // Initialize the database services with comprehensive error handling
  try {
    debugPrint('🚀 Initializing BizSync database services...');
    
    // Initialize CRDT Database Service first
    final crdtDatabaseService = CRDTDatabaseService();
    await crdtDatabaseService.initialize();
    
    // Initialize Basic Database Service
    final basicDatabaseService = DatabaseService();
    await basicDatabaseService.database; // Trigger initialization
    
    // Verify both services are working
    await _verifyDatabaseIntegrity(crdtDatabaseService, basicDatabaseService);
    
    debugPrint('✅ All database services initialized successfully');
    
  } catch (e) {
    debugPrint('❌ Critical error initializing database services: $e');
    
    // Attempt recovery
    try {
      debugPrint('🔧 Attempting database recovery...');
      await _attemptDatabaseRecovery();
      debugPrint('✅ Database recovery successful');
    } catch (recoveryError) {
      debugPrint('❌ Database recovery failed: $recoveryError');
      // Continue with app startup but show warning
      if (kDebugMode) {
        debugPrint('⚠️  App will start with limited functionality');
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
  CRDTDatabaseService crdtService, 
  DatabaseService basicService
) async {
  try {
    // Test basic operations
    final db = await crdtService.database;
    
    // Check if customers table exists and is accessible
    final customerCount = await db.rawQuery('SELECT COUNT(*) as count FROM customers');
    debugPrint('✓ Customers table accessible, found ${customerCount.first['count']} records');
    
    // Check CRDT customers table
    final crdtCustomerCount = await db.rawQuery('SELECT COUNT(*) as count FROM customers_crdt');
    debugPrint('✓ CRDT customers table accessible, found ${crdtCustomerCount.first['count']} records');
    
  } catch (e) {
    debugPrint('⚠️  Database integrity check failed: $e');
    throw Exception('Database tables not accessible: $e');
  }
}

/// Attempt database recovery by forcing table creation
Future<void> _attemptDatabaseRecovery() async {
  try {
    // Force create tables in both services
    final crdtService = CRDTDatabaseService();
    await crdtService.initialize();
    await crdtService.forceCreateTables();
    
    final basicService = DatabaseService();
    await basicService.forceCreateTables();
    
    // Verify recovery worked
    await _verifyDatabaseIntegrity(crdtService, basicService);
    
  } catch (e) {
    throw Exception('Database recovery failed: $e');
  }
}

class BizSyncApp extends ConsumerWidget {
  const BizSyncApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'BizSync - Professional Business Management',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: ThemeMode.system,
      routerConfig: AppRouter.router,
      builder: (context, child) => WaylandOptimizedWidget(
        child: ResponsiveBreakpoints.builder(
          child: child!,
          breakpoints: [
            const Breakpoint(start: 0, end: 450, name: MOBILE),
            const Breakpoint(start: 451, end: 800, name: TABLET),
            const Breakpoint(start: 801, end: 1920, name: DESKTOP),
            const Breakpoint(start: 1921, end: double.infinity, name: '4K'),
          ],
        ),
      ),
    );
  }

  ThemeData _buildLightTheme() {
    // Professional business color scheme - Blue/White/Gray
    const primaryColor = Color(0xFF1565C0); // Professional blue
    const surfaceColor = Color(0xFFFAFAFA); // Light gray background
    const errorColor = Color(0xFFD32F2F); // Professional red
    
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      primary: primaryColor,
      secondary: const Color(0xFF424242), // Dark gray
      surface: surfaceColor,
      error: errorColor,
    );

    final baseTheme = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      fontFamily: 'Roboto',
      
      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: MesaRenderingDetector.getAdjustedElevation(1),
        shadowColor: MesaRenderingDetector.getAdjustedShadowColor(Colors.black12),
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1565C0),
        ),
        toolbarHeight: 64,
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        elevation: MesaRenderingDetector.getAdjustedElevation(2),
        shadowColor: MesaRenderingDetector.getAdjustedShadowColor(Colors.black12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: Colors.white,
      ),
      
      // Data Table Theme
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F5F5)),
        headingTextStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Color(0xFF424242),
        ),
        dataTextStyle: const TextStyle(
          fontSize: 14,
          color: Color(0xFF616161),
        ),
        horizontalMargin: 16,
        columnSpacing: 24,
      ),
      
      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: MesaRenderingDetector.getAdjustedElevation(2),
          shadowColor: MesaRenderingDetector.getAdjustedShadowColor(Colors.black26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: errorColor),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        filled: true,
        fillColor: Colors.white,
      ),
      
      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: MesaRenderingDetector.getAdjustedElevation(6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
    
    // Apply Mesa safe theme if needed
    return MesaRenderingConfig().applySafeTheme(baseTheme);
  }

  ThemeData _buildDarkTheme() {
    const primaryColor = Color(0xFF42A5F5); // Lighter blue for dark theme
    const surfaceColor = Color(0xFF121212); // Dark surface
    const errorColor = Color(0xFFEF5350); // Lighter red for dark theme
    
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      primary: primaryColor,
      secondary: const Color(0xFFBBBBBB), // Light gray for dark theme
      surface: surfaceColor,
      error: errorColor,
    );

    final baseTheme = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      fontFamily: 'Roboto',
      
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: MesaRenderingDetector.getAdjustedElevation(1),
        shadowColor: MesaRenderingDetector.getAdjustedShadowColor(Colors.black26),
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF42A5F5),
        ),
        toolbarHeight: 64,
      ),
      
      cardTheme: CardThemeData(
        elevation: MesaRenderingDetector.getAdjustedElevation(2),
        shadowColor: MesaRenderingDetector.getAdjustedShadowColor(Colors.black26),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: const Color(0xFF1E1E1E),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        filled: true,
        fillColor: const Color(0xFF2E2E2E),
      ),
      
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: MesaRenderingDetector.getAdjustedElevation(6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
    
    // Apply Mesa safe theme if needed
    return MesaRenderingConfig().applySafeTheme(baseTheme);
  }
}


